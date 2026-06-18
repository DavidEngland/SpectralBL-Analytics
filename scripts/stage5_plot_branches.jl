#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using JSON3
using LinearAlgebra
using Printf

function campaign_slug(campaign::String)
    safe = lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    return isempty(safe) ? "campaign" : String(safe)
end

function parse_args(args::Vector{String})
    campaign = "CASES-99"
    output_dir = joinpath("data", "outputs")
    branch_csv = ""
    manifest_json = ""
    prefix = "stage5_panel"

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--campaign"
            i += 1
            campaign = args[i]
        elseif a == "--branch-csv"
            i += 1
            branch_csv = args[i]
        elseif a == "--manifest-json"
            i += 1
            manifest_json = args[i]
        elseif a == "--output-dir"
            i += 1
            output_dir = args[i]
        elseif a == "--prefix"
            i += 1
            prefix = args[i]
        else
            error("Unknown argument: $(a)")
        end
        i += 1
    end

    slug = campaign_slug(campaign)
    if isempty(branch_csv)
        branch_csv = joinpath("data", "outputs", "stage5_bifurcation_branches_$(slug).csv")
    end
    if isempty(manifest_json)
        manifest_json = joinpath("data", "outputs", "stage5_stability_manifest_$(slug).json")
    end

    return (
        campaign = campaign,
        slug = slug,
        output_dir = output_dir,
        branch_csv = branch_csv,
        manifest_json = manifest_json,
        prefix = prefix,
    )
end

function z_columns(df::DataFrame)
    cols = Symbol[]
    for c in names(df)
        s = String(c)
        if occursin(r"^z\d+$", s)
            push!(cols, Symbol(s))
        end
    end
    return sort(cols; by = c -> parse(Int, String(c)[2:end]))
end

function finite_or_missing(x)
    if x isa Number
        f = Float64(x)
        return isfinite(f) ? f : missing
    end
    return missing
end

function compute_state_norm(df::DataFrame, zcols::Vector{Symbol})
    norms = Vector{Union{Missing, Float64}}(undef, nrow(df))
    for r in 1:nrow(df)
        vals = Float64[]
        good = true
        for c in zcols
            v = df[r, c]
            if !(v isa Number) || !isfinite(Float64(v))
                good = false
                break
            end
            push!(vals, Float64(v))
        end
        norms[r] = good ? norm(vals) : missing
    end
    return norms
end

function export_trajectory_panel(branch_df::DataFrame)
    if nrow(branch_df) == 0
        return DataFrame(
            row_index = Int[],
            gamma = Float64[],
            state_norm = Float64[],
            z1 = Float64[],
            z2 = Float64[],
            z3 = Float64[],
            is_stable = Bool[],
            bifurcation_tag = String[],
        )
    end

    zcols = z_columns(branch_df)
    if isempty(zcols)
        error("Branch CSV is missing z-columns (expected z1, z2, ...).")
    end

    rows = Vector{NamedTuple}(undef, nrow(branch_df))
    state_norm = compute_state_norm(branch_df, zcols)

    for r in 1:nrow(branch_df)
        z1 = length(zcols) >= 1 ? finite_or_missing(branch_df[r, zcols[1]]) : missing
        z2 = length(zcols) >= 2 ? finite_or_missing(branch_df[r, zcols[2]]) : missing
        z3 = length(zcols) >= 3 ? finite_or_missing(branch_df[r, zcols[3]]) : missing

        rows[r] = (
            row_index = r,
            gamma = finite_or_missing(branch_df[r, :gamma]),
            state_norm = state_norm[r],
            z1 = z1,
            z2 = z2,
            z3 = z3,
            is_stable = hasproperty(branch_df, :is_stable) ? Bool(branch_df[r, :is_stable]) : missing,
            bifurcation_tag = hasproperty(branch_df, :bifurcation_tag) ? string(branch_df[r, :bifurcation_tag]) : "none",
        )
    end

    return DataFrame(rows)
end

function export_abscissa_panel(branch_df::DataFrame)
    if nrow(branch_df) == 0
        return DataFrame(
            row_index = Int[],
            gamma = Float64[],
            max_real_eig = Float64[],
            spectral_margin = Float64[],
            is_stable = Bool[],
            bifurcation_tag = String[],
        )
    end

    if !hasproperty(branch_df, :max_real_eig)
        error("Branch CSV is missing max_real_eig column.")
    end

    rows = Vector{NamedTuple}(undef, nrow(branch_df))
    for r in 1:nrow(branch_df)
        max_real = finite_or_missing(branch_df[r, :max_real_eig])
        rows[r] = (
            row_index = r,
            gamma = finite_or_missing(branch_df[r, :gamma]),
            max_real_eig = max_real,
            spectral_margin = max_real === missing ? missing : -max_real,
            is_stable = hasproperty(branch_df, :is_stable) ? Bool(branch_df[r, :is_stable]) : missing,
            bifurcation_tag = hasproperty(branch_df, :bifurcation_tag) ? string(branch_df[r, :bifurcation_tag]) : "none",
        )
    end
    return DataFrame(rows)
end

function parse_json(path::String)
    return JSON3.read(read(path, String))
end

function dmin_from_branch_row(row)
    eigvals = haskey(row, "eigenvalues") ? row["eigenvalues"] : nothing
    if eigvals !== nothing
        reals = Float64[]
        for eig in eigvals
            if haskey(eig, "real")
                rv = eig["real"]
                if rv isa Number && isfinite(Float64(rv))
                    push!(reals, abs(Float64(rv)))
                end
            end
        end
        if !isempty(reals)
            return (minimum(reals), "manifest_eigs", length(reals))
        end
    end

    if haskey(row, "max_real_eig")
        max_real = row["max_real_eig"]
        if max_real isa Number && isfinite(Float64(max_real))
            return (abs(Float64(max_real)), "fallback_abscissa", 0)
        end
    end

    return (missing, "missing", 0)
end

function export_distance_panel(manifest)
    if !haskey(manifest, "continuation") || !haskey(manifest["continuation"], "branch")
        error("Manifest JSON is missing continuation.branch payload.")
    end

    rows_json = manifest["continuation"]["branch"]
    rows = NamedTuple[]

    if isempty(rows_json)
        return DataFrame(
            row_index = Int[],
            gamma = Float64[],
            d_min = Float64[],
            max_real_eig = Float64[],
            is_stable = Bool[],
            converged = Bool[],
            bifurcation_tag = String[],
            distance_source = String[],
            eigenvalue_count = Int[],
        )
    end

    for (i, row) in enumerate(rows_json)
        d_min, distance_source, eig_count = dmin_from_branch_row(row)

        gamma = haskey(row, "gamma") ? finite_or_missing(row["gamma"]) : missing
        max_real = haskey(row, "max_real_eig") ? finite_or_missing(row["max_real_eig"]) : missing
        is_stable = haskey(row, "is_stable") ? Bool(row["is_stable"]) : missing
        converged = haskey(row, "converged") ? Bool(row["converged"]) : missing
        tag = haskey(row, "bifurcation_tag") ? string(row["bifurcation_tag"]) : "none"

        push!(rows, (
            row_index = i,
            gamma = gamma,
            d_min = d_min,
            max_real_eig = max_real,
            is_stable = is_stable,
            converged = converged,
            bifurcation_tag = tag,
            distance_source = distance_source,
            eigenvalue_count = eig_count,
        ))
    end

    return DataFrame(rows)
end

function run_stage5_panel_exports(; campaign::String, slug::String, output_dir::String, branch_csv::String, manifest_json::String, prefix::String)
    isfile(branch_csv) || error("Branch CSV not found: $(branch_csv). Run make stage5-sweep CAMPAIGN=$(campaign) first.")
    isfile(manifest_json) || error("Manifest JSON not found: $(manifest_json). Run make stage5-sweep CAMPAIGN=$(campaign) first.")

    branch_df = CSV.read(branch_csv, DataFrame)
    manifest = parse_json(manifest_json)

    trajectory_panel = export_trajectory_panel(branch_df)
    abscissa_panel = export_abscissa_panel(branch_df)
    distance_panel = export_distance_panel(manifest)

    mkpath(output_dir)
    trajectory_out = joinpath(output_dir, "$(prefix)_trajectory_$(slug).csv")
    abscissa_out = joinpath(output_dir, "$(prefix)_abscissa_$(slug).csv")
    distance_out = joinpath(output_dir, "$(prefix)_distance_$(slug).csv")

    CSV.write(trajectory_out, trajectory_panel)
    CSV.write(abscissa_out, abscissa_panel)
    CSV.write(distance_out, distance_panel)

    println("Stage 5 diagnostic panel CSVs written:")
    println("  trajectory: $(trajectory_out)")
    println("  abscissa:   $(abscissa_out)")
    println("  distance:   $(distance_out)")
    println(@sprintf("Rows: trajectory=%d abscissa=%d distance=%d", nrow(trajectory_panel), nrow(abscissa_panel), nrow(distance_panel)))
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_args(ARGS)
    run_stage5_panel_exports(; args...)
end
