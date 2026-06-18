#!/usr/bin/env julia
# scripts/stage5_summary.jl
using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using JSON3
using Printf

function campaign_slug(campaign::String)
    safe = lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    return isempty(safe) ? "campaign" : String(safe)
end

function parse_args(args::Vector{String})
    campaign = "CASES-99"
    manifest_json = ""
    branch_csv = ""
    output_json = ""

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--campaign"
            i += 1
            campaign = args[i]
        elseif a == "--manifest-json"
            i += 1
            manifest_json = args[i]
        elseif a == "--branch-csv"
            i += 1
            branch_csv = args[i]
        elseif a == "--output-json"
            i += 1
            output_json = args[i]
        else
            error("Unknown argument: $(a)")
        end
        i += 1
    end

    slug = campaign_slug(campaign)
    if isempty(manifest_json)
        manifest_json = joinpath("data", "outputs", "stage5_stability_manifest_$(slug).json")
    end
    if isempty(branch_csv)
        branch_csv = joinpath("data", "outputs", "stage5_bifurcation_branches_$(slug).csv")
    end
    if isempty(output_json)
        output_json = joinpath("data", "outputs", "stage5_summary_$(slug).json")
    end

    return (
        campaign = campaign,
        manifest_json = manifest_json,
        branch_csv = branch_csv,
        output_json = output_json,
    )
end

function finite_or_missing(x)
    if x isa Number
        f = Float64(x)
        return isfinite(f) ? f : missing
    end
    return missing
end

function get_column(df::DataFrame, name::Symbol)
    sname = String(name)
    if name in names(df)
        return df[!, name]
    elseif sname in names(df)
        return df[!, sname]
    end
    return nothing
end

function to_float_vec(col)
    col === nothing && return Float64[]
    out = Vector{Float64}(undef, length(col))
    for i in eachindex(col)
        v = col[i]
        if v isa Number
            out[i] = Float64(v)
        else
            p = tryparse(Float64, string(v))
            out[i] = p === nothing ? NaN : p
        end
    end
    return out
end

function to_bool_vec(col)
    col === nothing && return Bool[]
    out = Vector{Bool}(undef, length(col))
    for i in eachindex(col)
        v = col[i]
        if v isa Bool
            out[i] = v
        else
            out[i] = lowercase(strip(string(v))) in ("true", "1", "t", "yes")
        end
    end
    return out
end

function dominant_imag_from_branch_row(row)
    if !haskey(row, "eigenvalues")
        return missing
    end

    eigs = row["eigenvalues"]
    isempty(eigs) && return missing

    best_real = -Inf
    best_imag = missing
    for eig in eigs
        if !(haskey(eig, "real") && haskey(eig, "imag"))
            continue
        end
        re = finite_or_missing(eig["real"])
        im = finite_or_missing(eig["imag"])
        if re === missing || im === missing
            continue
        end
        if re > best_real
            best_real = re
            best_imag = abs(im)
        end
    end
    return best_imag
end

function estimate_max_imag_from_manifest(continuation, gamma_target)
    if !haskey(continuation, "branch")
        return missing
    end

    rows = continuation["branch"]
    isempty(rows) && return missing

    best_idx = 0
    best_dist = Inf
    for (i, row) in enumerate(rows)
        if !haskey(row, "gamma")
            continue
        end
        g = finite_or_missing(row["gamma"])
        if g === missing
            continue
        end
        d = abs(g - gamma_target)
        if d < best_dist
            best_dist = d
            best_idx = i
        end
    end

    best_idx == 0 && return missing
    return dominant_imag_from_branch_row(rows[best_idx])
end

function summarize_stage5(; campaign::String, manifest_json::String, branch_csv::String, output_json::String)
    isfile(manifest_json) || error("Missing manifest JSON: $(manifest_json)")
    isfile(branch_csv) || error("Missing branch CSV: $(branch_csv)")

    manifest = JSON3.read(read(manifest_json, String))
    continuation = manifest["continuation"]
    branch_df = CSV.read(branch_csv, DataFrame)

    n_rows = nrow(branch_df)

    gamma_col = to_float_vec(get_column(branch_df, :gamma))
    max_real_col = to_float_vec(get_column(branch_df, :max_real_eig))
    stable_col = to_bool_vec(get_column(branch_df, :is_stable))

    gamma_min = n_rows > 0 ? minimum(gamma_col) : missing
    gamma_max = n_rows > 0 ? maximum(gamma_col) : missing
    max_real_min = n_rows > 0 ? minimum(max_real_col) : missing
    max_real_max = n_rows > 0 ? maximum(max_real_col) : missing

    stable_rows = n_rows > 0 ? count(==(true), stable_col) : 0
    unstable_rows = n_rows > 0 ? count(==(false), stable_col) : 0

    first_positive_gamma = missing
    first_positive_max_real = missing
    if n_rows > 0
        positive_idx = findall(>(0.0), max_real_col)
        if !isempty(positive_idx)
            i0 = minimum(positive_idx)
            first_positive_gamma = finite_or_missing(gamma_col[i0])
            first_positive_max_real = finite_or_missing(max_real_col[i0])
        end
    end

    closest_gamma = missing
    closest_max_real = missing
    closest_is_stable = missing
    closest_max_imag = missing
    dRe_dgamma = missing
    i_closest = 0
    if n_rows > 0
        i_closest = argmin(abs.(max_real_col))
        closest_gamma = finite_or_missing(gamma_col[i_closest])
        closest_max_real = finite_or_missing(max_real_col[i_closest])
        if !isempty(stable_col)
            closest_is_stable = stable_col[i_closest]
        end

        imag_col = get_column(branch_df, :max_imag_eig)
        if imag_col !== nothing
            imag_float = to_float_vec(imag_col)
            closest_max_imag = finite_or_missing(imag_float[i_closest])
        elseif closest_gamma !== missing
            closest_max_imag = estimate_max_imag_from_manifest(continuation, closest_gamma)
        end

        if n_rows > 2 && 1 < i_closest < n_rows
            Δreal = max_real_col[i_closest + 1] - max_real_col[i_closest - 1]
            Δgamma = gamma_col[i_closest + 1] - gamma_col[i_closest - 1]
            if isfinite(Δreal) && isfinite(Δgamma) && abs(Δgamma) > 1e-12
                dRe_dgamma = Δreal / Δgamma
            end
        end

        if dRe_dgamma === missing && n_rows > 1
            for i in 2:n_rows
                r_prev = max_real_col[i - 1]
                r_cur = max_real_col[i]
                g_prev = gamma_col[i - 1]
                g_cur = gamma_col[i]
                if !(isfinite(r_prev) && isfinite(r_cur) && isfinite(g_prev) && isfinite(g_cur))
                    continue
                end
                crossed = (r_prev <= 0.0 && r_cur > 0.0) || (r_prev >= 0.0 && r_cur < 0.0)
                if crossed
                    Δreal = r_cur - r_prev
                    Δgamma = g_cur - g_prev
                    if abs(Δgamma) > 1e-12
                        dRe_dgamma = Δreal / Δgamma
                    end
                    break
                end
            end
        end
    end

    hopf_events = haskey(continuation, "hopf_events") ? continuation["hopf_events"] : Any[]
    gamma_c = missing
    if !isempty(hopf_events)
        first_event = hopf_events[1]
        if haskey(first_event, "gamma")
            gamma_c = finite_or_missing(first_event["gamma"])
        end
    end

    summary = Dict(
        "campaign" => campaign,
        "manifest_json" => manifest_json,
        "branch_csv" => branch_csv,
        "terminated" => Bool(continuation["terminated"]),
        "termination_reason" => String(continuation["termination_reason"]),
        "termination_gamma" => haskey(continuation, "termination_gamma") ? continuation["termination_gamma"] : nothing,
        "branch_points_manifest" => Int(continuation["branch_points"]),
        "hopf_event_count_manifest" => Int(continuation["hopf_event_count"]),
        "branch_rows_csv" => n_rows,
        "stable_rows" => stable_rows,
        "unstable_rows" => unstable_rows,
        "gamma_min" => gamma_min,
        "gamma_max" => gamma_max,
        "max_real_eig_min" => max_real_min,
        "max_real_eig_max" => max_real_max,
        "first_positive_gamma" => first_positive_gamma,
        "first_positive_max_real" => first_positive_max_real,
        "closest_to_axis_gamma" => closest_gamma,
        "closest_to_axis_max_real" => closest_max_real,
        "closest_to_axis_max_imag" => closest_max_imag,
        "hopf_period_Th" => (closest_max_imag !== missing && closest_max_imag > 0.0) ? (2π / abs(closest_max_imag)) : missing,
        "dRe_dgamma_at_crossing" => dRe_dgamma,
        "closest_to_axis_is_stable" => closest_is_stable,
        "gamma_c_hopf" => gamma_c,
    )

    mkpath(dirname(output_json))
    write(output_json, JSON3.write(summary))

    println("Stage 5 summary written: $(output_json)")
    println(@sprintf("campaign=%s branch_rows=%d stable=%d unstable=%d hopf_events=%d", campaign, n_rows, stable_rows, unstable_rows, Int(continuation["hopf_event_count"])))
    println(@sprintf("gamma_range=[%.6g, %.6g] max_real_range=[%.6g, %.6g]", coalesce(gamma_min, NaN), coalesce(gamma_max, NaN), coalesce(max_real_min, NaN), coalesce(max_real_max, NaN)))
    if gamma_c !== missing
        println(@sprintf("gamma_c_hopf=%.12g", gamma_c))
    end

    return summary
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_args(ARGS)
    summarize_stage5(; args...)
end
