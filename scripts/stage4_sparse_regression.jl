#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

push!(LOAD_PATH, joinpath(pwd(), "src"))

using CSV
using DataFrames
using JSON3
using Printf
using Stage4_SparseRegression

function parse_bool(v::String)
    low = lowercase(strip(v))
    if low in ("1", "true", "yes", "on")
        return true
    elseif low in ("0", "false", "no", "off")
        return false
    end
    error("Invalid bool value: $(v)")
end

function parse_args(args::Vector{String})
    stage3_bin = joinpath("data", "outputs", "stage3_closure_cases_99.bin")
    output_json = joinpath("data", "outputs", "stage4_discovered_equations.json")
    output_json_provided = false
    mode = "calibrate"
    lambda_threshold = 1e-3
    lambda_provided = false
    max_iter = 25
    library_mode = "contract90"

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--stage3-bin"
            i += 1; stage3_bin = args[i]
        elseif a == "--output-json"
            i += 1; output_json = args[i]
            output_json_provided = true
        elseif a == "--mode"
            i += 1; mode = args[i]
        elseif a == "--lambda"
            i += 1; lambda_threshold = parse(Float64, args[i])
            lambda_provided = true
        elseif a == "--max-iter"
            i += 1; max_iter = parse(Int, args[i])
        elseif a == "--library-mode"
            i += 1; library_mode = args[i]
        else
            error("Unknown argument: $(a)")
        end
        i += 1
    end

    return (
        stage3_bin=stage3_bin,
        output_json=output_json,
        output_json_provided=output_json_provided,
        mode=mode,
        lambda_threshold=lambda_threshold,
        lambda_provided=lambda_provided,
        max_iter=max_iter,
        library_mode=library_mode,
    )
end

function mode_symbol(mode::String)
    low = lowercase(strip(mode))
    if low in ("contract90", "contract")
        return :contract90
    elseif low in ("unique", "unique_quad", "unique_quad_with_const")
        return :unique_quad_with_const
    end
    error("Unsupported library mode: $(mode)")
end

function geometric_lambdas(lo::Float64=1e-5, hi::Float64=1e-1, n::Int=9)
    vals = Float64[]
    for k in 0:(n - 1)
        t = k / max(1, n - 1)
        push!(vals, 10.0 ^ (log10(lo) + t * (log10(hi) - log10(lo))) )
    end
    return vals
end

function choose_pareto_knee(sweep::Vector{NamedTuple})
    # Normalize axes and select minimal distance to origin in (residual, density).
    residuals = [s.residual_norm for s in sweep]
    nnz_vals = [Float64(s.nnz) for s in sweep]

    rmin, rmax = extrema(residuals)
    zmin, zmax = extrema(nnz_vals)

    best_idx = 1
    best_score = Inf
    for i in eachindex(sweep)
        rn = (residuals[i] - rmin) / (rmax - rmin + 1e-12)
        zn = (nnz_vals[i] - zmin) / (zmax - zmin + 1e-12)
        score = rn^2 + zn^2
        if score < best_score
            best_score = score
            best_idx = i
        end
    end
    return best_idx
end

function extract_selected_lambda(manifest_obj)
    candidate_keys = ("selected_lambda", "optimal_lambda", "pareto_knee_lambda")
    for key in candidate_keys
        if haskey(manifest_obj, key)
            return Float64(manifest_obj[key]), key
        end
    end
    return nothing, nothing
end

function run_stage4(; stage3_bin::String, output_json::String, output_json_provided::Bool, mode::String, lambda_threshold::Float64, lambda_provided::Bool, max_iter::Int, library_mode::String)
    payload = load_stage3_binary(stage3_bin)
    Z = Matrix{Float64}(payload["Z_global"])
    dZ = Matrix{Float64}(payload["dZ_global"])

    Theta, feature_names = build_library(Z; mode=mode_symbol(library_mode))

    out_dir = joinpath("data", "outputs")
    mkpath(out_dir)

    if lowercase(strip(mode)) == "calibrate"
        lambdas = geometric_lambdas()
        sweep = run_threshold_sweep(Theta, dZ, lambdas; max_iter=max_iter)

        summary = DataFrame(
            lambda=Float64[s.lambda for s in sweep],
            residual_norm=Float64[s.residual_norm for s in sweep],
            nnz=Int[s.nnz for s in sweep],
            converged=Bool[s.converged for s in sweep],
            iterations=Int[s.iterations for s in sweep],
        )
        summary_path = joinpath(out_dir, "stage4_lambda_sweep.csv")
        CSV.write(summary_path, summary)

        best_idx = choose_pareto_knee(sweep)
        chosen = sweep[best_idx]
        export_discovered_equations(output_json, chosen.Xi, feature_names)

        calib_manifest = Dict(
            "mode" => "calibrate",
            "stage3_bin" => stage3_bin,
            "output_json" => output_json,
            "library_mode" => library_mode,
            "selected_lambda" => chosen.lambda,
            "selected_residual_norm" => chosen.residual_norm,
            "selected_nnz" => chosen.nnz,
            "selected_converged" => chosen.converged,
            "lambda_sweep_csv" => summary_path,
        )
        write(joinpath(out_dir, "stage4_calibration_manifest.json"), JSON3.write(calib_manifest))

        println("Stage 4 calibration sweep written: $(summary_path)")
        println("Stage 4 selected model written: $(output_json)")
        println(@sprintf("Selected lambda=%.6g residual=%.5f nnz=%d", chosen.lambda, chosen.residual_norm, chosen.nnz))
        return
    end

    if lowercase(strip(mode)) == "production" && !output_json_provided
        output_json = joinpath(out_dir, "stage4_production_equations_cases_99.json")
    end

    if lowercase(strip(mode)) == "production" && !lambda_provided
        calibration_manifest = joinpath(out_dir, "stage4_calibration_manifest.json")
        fallback_lambda = 0.01
        if isfile(calibration_manifest)
            manifest_obj = JSON3.read(read(calibration_manifest, String))
            selected_lambda, key_name = extract_selected_lambda(manifest_obj)
            if selected_lambda === nothing
                println(stderr, "[stage4] Calibration manifest found at $(calibration_manifest), but no selected lambda key was found (expected one of: selected_lambda, optimal_lambda, pareto_knee_lambda). Falling back to safe baseline lambda=$(fallback_lambda).")
                lambda_threshold = fallback_lambda
            else
                lambda_threshold = selected_lambda
                println(@sprintf("[stage4] Production mode auto-selected lambda=%.6g from %s (%s).", lambda_threshold, calibration_manifest, key_name))
            end
        else
            println(stderr, "[stage4] Calibration manifest not found at $(calibration_manifest). Run `make stage4-calibrate` first; falling back to safe baseline lambda=$(fallback_lambda).")
            lambda_threshold = fallback_lambda
        end
    end

    sol = stls_solve(Theta, dZ; lambda_threshold=lambda_threshold, max_iter=max_iter)
    export_discovered_equations(output_json, sol.Xi, feature_names)

    manifest = Dict(
        "mode" => "production",
        "stage3_bin" => stage3_bin,
        "output_json" => output_json,
        "library_mode" => library_mode,
        "lambda_threshold" => lambda_threshold,
        "residual_norm" => sol.residual_norm,
        "nnz" => sol.nnz,
        "converged" => sol.converged,
        "iterations" => sol.iterations,
    )
    write(joinpath(out_dir, "stage4_production_manifest.json"), JSON3.write(manifest))

    println("Stage 4 discovered equations written: $(output_json)")
    println(@sprintf("lambda=%.6g residual=%.5f nnz=%d converged=%s", lambda_threshold, sol.residual_norm, sol.nnz, string(sol.converged)))
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_args(ARGS)
    run_stage4(
        stage3_bin=args.stage3_bin,
        output_json=args.output_json,
        output_json_provided=args.output_json_provided,
        mode=args.mode,
        lambda_threshold=args.lambda_threshold,
        lambda_provided=args.lambda_provided,
        max_iter=args.max_iter,
        library_mode=args.library_mode,
    )
end
