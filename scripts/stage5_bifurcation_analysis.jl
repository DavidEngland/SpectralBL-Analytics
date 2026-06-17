#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

push!(LOAD_PATH, joinpath(pwd(), "src"))

using CSV
using DataFrames
using JSON3
using Printf
using Stage5_BifurcationAnalytics

function parse_args(args::Vector{String})
    stage4_json = joinpath("data", "outputs", "stage4_production_equations_cases_99.json")
    output_json = joinpath("data", "outputs", "stage5_stability_manifest.json")
    output_csv = joinpath("data", "outputs", "stage5_equilibria_cases_99.csv")
    continuation_csv = joinpath("data", "outputs", "stage5_bifurcation_branches_cases_99.csv")
    seed_count = 64
    seed_scale = 0.5
    max_iter = 50
    tol = 1e-8
    dedup_tol = 1e-4
    hopf_eps = 1e-3
    gamma_min = 0.5
    gamma_max = 1.5
    gamma_steps = 25
    refine_steps = 8
    refine_gamma_tol = 1e-4
    sweep_direction = "ascending"
    scale_target = "linear"
    linear_indices = "1,2,3,4,5,6,7,8,9"
    forcing_values = ""

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--stage4-json"
            i += 1; stage4_json = args[i]
        elseif a == "--output-json"
            i += 1; output_json = args[i]
        elseif a == "--output-csv"
            i += 1; output_csv = args[i]
        elseif a == "--continuation-csv"
            i += 1; continuation_csv = args[i]
        elseif a == "--seed-count"
            i += 1; seed_count = parse(Int, args[i])
        elseif a == "--seed-scale"
            i += 1; seed_scale = parse(Float64, args[i])
        elseif a == "--max-iter"
            i += 1; max_iter = parse(Int, args[i])
        elseif a == "--tol"
            i += 1; tol = parse(Float64, args[i])
        elseif a == "--dedup-tol"
            i += 1; dedup_tol = parse(Float64, args[i])
        elseif a == "--hopf-eps"
            i += 1; hopf_eps = parse(Float64, args[i])
        elseif a == "--gamma-min"
            i += 1; gamma_min = parse(Float64, args[i])
        elseif a == "--gamma-max"
            i += 1; gamma_max = parse(Float64, args[i])
        elseif a == "--gamma-steps"
            i += 1; gamma_steps = parse(Int, args[i])
        elseif a == "--refine-steps"
            i += 1; refine_steps = parse(Int, args[i])
        elseif a == "--refine-gamma-tol"
            i += 1; refine_gamma_tol = parse(Float64, args[i])
        elseif a == "--sweep-direction"
            i += 1; sweep_direction = args[i]
        elseif a == "--scale-target"
            i += 1; scale_target = args[i]
        elseif a == "--linear-indices"
            i += 1; linear_indices = args[i]
        elseif a == "--forcing-values"
            i += 1; forcing_values = args[i]
        else
            error("Unknown argument: $(a)")
        end
        i += 1
    end

    return (
        stage4_json=stage4_json,
        output_json=output_json,
        output_csv=output_csv,
        continuation_csv=continuation_csv,
        seed_count=seed_count,
        seed_scale=seed_scale,
        max_iter=max_iter,
        tol=tol,
        dedup_tol=dedup_tol,
        hopf_eps=hopf_eps,
        gamma_min=gamma_min,
        gamma_max=gamma_max,
        gamma_steps=gamma_steps,
        refine_steps=refine_steps,
        refine_gamma_tol=refine_gamma_tol,
        sweep_direction=sweep_direction,
        scale_target=scale_target,
        linear_indices=linear_indices,
        forcing_values=forcing_values,
    )
end

function parse_int_list(v::String)
    s = strip(v)
    isempty(s) && return Int[]
    return [parse(Int, strip(x)) for x in split(s, ",") if !isempty(strip(x))]
end

function parse_float_list(v::String)
    s = strip(v)
    isempty(s) && return Float64[]
    return [parse(Float64, strip(x)) for x in split(s, ",") if !isempty(strip(x))]
end

function to_scale_target(v::String)
    low = lowercase(strip(v))
    if low in ("linear",)
        return :linear
    elseif low in ("forcing",)
        return :forcing
    elseif low in ("both",)
        return :both
    end
    error("Unsupported --scale-target value: $(v). Use linear|forcing|both.")
end

function to_sweep_direction(v::String)
    low = lowercase(strip(v))
    if low in ("ascending", "up", "forward")
        return :ascending
    elseif low in ("descending", "down", "backward", "reverse")
        return :descending
    end
    error("Unsupported --sweep-direction value: $(v). Use ascending|descending.")
end

function complex_to_dict(v)
    return Dict(
        "real" => real(v),
        "imag" => imag(v),
        "abs" => abs(v),
    )
end

function sanitize_for_json(x)
    if x isa AbstractDict
        out = Dict{Any,Any}()
        for (k, v) in pairs(x)
            out[k] = sanitize_for_json(v)
        end
        return out
    elseif x isa NamedTuple
        out = Dict{String,Any}()
        for name in keys(x)
            out[String(name)] = sanitize_for_json(getfield(x, name))
        end
        return out
    elseif x isa AbstractVector
        return [sanitize_for_json(v) for v in x]
    elseif x isa AbstractFloat
        if isnan(x)
            return -999.0
        elseif isinf(x)
            return x > 0 ? 999.0 : -999.0
        end
        return x
    else
        return x
    end
end

function write_equilibria_csv(path::String, equilibria)
    mkpath(dirname(path))

    if isempty(equilibria)
        cols = Dict{Symbol,AbstractVector}(
            :equilibrium_id => Int[],
            :residual_norm => Float64[],
            :iterations => Int[],
            :spectral_abscissa => Float64[],
            :unstable_mode_count => Int[],
            :oscillatory => Bool[],
            :near_axis_pairs => Int[],
            :hopf_candidate => Bool[],
            :is_stable => Bool[],
        )
        CSV.write(path, DataFrame(cols))
        return
    end

    rows = Vector{NamedTuple}()
    for eq in equilibria
        z = eq.z
        z_pairs = Pair{Symbol,Float64}[]
        for j in eachindex(z)
            push!(z_pairs, Symbol("z$(j)") => z[j])
        end

        push!(rows, (; 
            equilibrium_id = eq.equilibrium_id,
            residual_norm = eq.residual_norm,
            iterations = eq.iterations,
            spectral_abscissa = eq.spectral_abscissa,
            unstable_mode_count = eq.unstable_mode_count,
            oscillatory = eq.oscillatory,
            near_axis_pairs = eq.near_axis_pairs,
            hopf_candidate = eq.hopf_candidate,
            is_stable = eq.is_stable,
            z_pairs...,
        ))
    end
    CSV.write(path, DataFrame(rows))
end

function write_continuation_csv(path::String, branch_rows, hopf_events, n::Int)
    rows = Vector{NamedTuple}()

    for r in branch_rows
        z_pairs = Pair{Symbol,Float64}[]
        for j in 1:n
            push!(z_pairs, Symbol("z$(j)") => r.z[j])
        end
        push!(rows, (; 
            gamma = r.gamma,
            z_pairs...,
            max_real_eig = r.max_real_eig,
            is_stable = r.is_stable,
            bifurcation_tag = r.bifurcation_tag,
        ))
    end

    for e in hopf_events
        z_pairs = Pair{Symbol,Float64}[]
        for j in 1:n
            push!(z_pairs, Symbol("z$(j)") => e.z[j])
        end
        push!(rows, (; 
            gamma = e.gamma,
            z_pairs...,
            max_real_eig = 0.0,
            is_stable = false,
            bifurcation_tag = e.tag,
        ))
    end

    mkpath(dirname(path))
    CSV.write(path, DataFrame(rows))
end

function run_stage5(; stage4_json::String, output_json::String, output_csv::String, continuation_csv::String, seed_count::Int, seed_scale::Float64, max_iter::Int, tol::Float64, dedup_tol::Float64, hopf_eps::Float64, gamma_min::Float64, gamma_max::Float64, gamma_steps::Int, refine_steps::Int, refine_gamma_tol::Float64, sweep_direction::String, scale_target::String, linear_indices::String, forcing_values::String)
    sys = load_system_from_json(stage4_json)
    result = find_equilibria(
        sys;
        seed_count=seed_count,
        seed_scale=seed_scale,
        max_iter=max_iter,
        tol=tol,
        dedup_tol=dedup_tol,
        hopf_eps=hopf_eps,
    )

    isempty(result.equilibria) && error("No equilibrium found for continuation seed discovery.")
    seed_eq = result.equilibria[argmin([eq.residual_norm for eq in result.equilibria])]

    n = n_states(sys)
    idx = parse_int_list(linear_indices)
    if isempty(idx)
        idx = collect(1:n)
    end

    forcing_vec = parse_float_list(forcing_values)
    if isempty(forcing_vec)
        forcing_vec = zeros(Float64, n)
    elseif length(forcing_vec) != n
        error("--forcing-values must be empty or provide $(n) comma-separated values.")
    end

    cont_cfg = ContinuationConfig(
        gamma_min,
        gamma_max,
        gamma_steps,
        to_sweep_direction(sweep_direction),
        to_scale_target(scale_target),
        idx,
        forcing_vec,
        hopf_eps,
    )

    branch_result = trace_continuation_branch(
        sys,
        seed_eq.z,
        cont_cfg;
        max_iter=max_iter,
        tol=tol,
        refine_steps=refine_steps,
        refine_gamma_tol=refine_gamma_tol,
    )

    eq_payload = Vector{Dict{String,Any}}()
    for eq in result.equilibria
        push!(eq_payload, Dict(
            "equilibrium_id" => eq.equilibrium_id,
            "state" => collect(eq.z),
            "residual_norm" => eq.residual_norm,
            "iterations" => eq.iterations,
            "spectral_abscissa" => eq.spectral_abscissa,
            "unstable_mode_count" => eq.unstable_mode_count,
            "oscillatory" => eq.oscillatory,
            "near_axis_pairs" => eq.near_axis_pairs,
            "hopf_candidate" => eq.hopf_candidate,
            "is_stable" => eq.is_stable,
            "eigenvalues" => [complex_to_dict(v) for v in eq.eigenvalues],
        ))
    end

    hopf_count = count(eq -> eq.hopf_candidate, result.equilibria)
    stable_count = count(eq -> eq.is_stable, result.equilibria)
    branch_hopf_count = length(branch_result.hopf_events)

    manifest = Dict(
        "model" => "Stage5_BifurcationAnalytics",
        "stage4_json" => stage4_json,
        "n_states" => n_states(sys),
        "seed_count" => seed_count,
        "seed_scale" => seed_scale,
        "max_iter" => max_iter,
        "tol" => tol,
        "dedup_tol" => dedup_tol,
        "hopf_eps" => hopf_eps,
        "attempt_count" => length(result.attempts),
        "equilibrium_count" => length(result.equilibria),
        "stable_count" => stable_count,
        "hopf_candidate_count" => hopf_count,
        "continuation" => Dict(
            "gamma_min" => gamma_min,
            "gamma_max" => gamma_max,
            "gamma_steps" => gamma_steps,
            "refine_steps" => refine_steps,
            "refine_gamma_tol" => refine_gamma_tol,
            "sweep_direction" => sweep_direction,
            "scale_target" => scale_target,
            "linear_indices" => idx,
            "forcing" => forcing_vec,
            "seed_equilibrium_id" => seed_eq.equilibrium_id,
            "branch_points" => length(branch_result.branch),
            "hopf_event_count" => branch_hopf_count,
            "terminated" => branch_result.terminated,
            "termination_gamma" => branch_result.termination_gamma,
            "termination_reason" => branch_result.termination_reason,
            "branch_csv" => continuation_csv,
            "hopf_events" => [Dict("gamma" => e.gamma, "state" => collect(e.z), "tag" => e.tag) for e in branch_result.hopf_events],
            "branch" => [Dict(
                "gamma" => r.gamma,
                "state" => collect(r.z),
                "max_real_eig" => r.max_real_eig,
                "is_stable" => r.is_stable,
                "bifurcation_tag" => r.bifurcation_tag,
                "converged" => r.converged,
                "residual_norm" => r.residual_norm,
                "eigenvalues" => [complex_to_dict(v) for v in r.eigenvalues],
            ) for r in branch_result.branch],
        ),
        "attempts" => [Dict(
            "seed_id" => a.seed_id,
            "converged" => a.converged,
            "residual_norm" => a.residual_norm,
            "iterations" => a.iterations,
            "reason" => a.reason,
        ) for a in result.attempts],
        "equilibria" => eq_payload,
    )

    mkpath(dirname(output_json))
    write(output_json, JSON3.write(sanitize_for_json(manifest)))
    write_equilibria_csv(output_csv, result.equilibria)
    write_continuation_csv(continuation_csv, branch_result.branch, branch_result.hopf_events, n)

    println("Stage 5 stability manifest written: $(output_json)")
    println("Stage 5 equilibria CSV written: $(output_csv)")
    println("Stage 5 continuation branch CSV written: $(continuation_csv)")
    if branch_result.terminated
        println(@sprintf("Stage 5 continuation terminated at gamma=%.6g due to %s", branch_result.termination_gamma, branch_result.termination_reason))
    end
    println(@sprintf("attempts=%d equilibria=%d stable=%d hopf_candidates=%d branch_points=%d hopf_events=%d", length(result.attempts), length(result.equilibria), stable_count, hopf_count, length(branch_result.branch), branch_hopf_count))
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_args(ARGS)
    run_stage5(
        stage4_json=args.stage4_json,
        output_json=args.output_json,
        output_csv=args.output_csv,
        continuation_csv=args.continuation_csv,
        seed_count=args.seed_count,
        seed_scale=args.seed_scale,
        max_iter=args.max_iter,
        tol=args.tol,
        dedup_tol=args.dedup_tol,
        hopf_eps=args.hopf_eps,
        gamma_min=args.gamma_min,
        gamma_max=args.gamma_max,
        gamma_steps=args.gamma_steps,
        refine_steps=args.refine_steps,
        refine_gamma_tol=args.refine_gamma_tol,
        sweep_direction=args.sweep_direction,
        scale_target=args.scale_target,
        linear_indices=args.linear_indices,
        forcing_values=args.forcing_values,
    )
end
