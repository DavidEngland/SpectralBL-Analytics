#!/usr/bin/env julia
# scripts/compute_shape_energy_profiles.jl

using Pkg
Pkg.activate(".")

using ArgParse
using CSV
using DataFrames
using Printf

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using ShapeEnergyDiagnostics

function parse_height_from_name(name::AbstractString)
    # Expected suffix style: *_1_5m, *_10m, etc.
    m = match(r"_([0-9]+(?:_[0-9]+)?)m$", name)
    if m !== nothing
        raw = replace(m.captures[1], "_" => ".")
        return tryparse(Float64, raw)
    end

    # Trajectory proxy profile style: ri_g_0_5, ri_g_10_0, ...
    m2 = match(r"^ri_g_([0-9]+(?:_[0-9]+)?)$", name)
    m2 === nothing && return nothing
    raw2 = replace(m2.captures[1], "_" => ".")
    return tryparse(Float64, raw2)
end

function parse_csv_list(s::AbstractString)
    cleaned = strip(s)
    isempty(cleaned) && return String[]
    return [strip(x) for x in split(cleaned, ",") if !isempty(strip(x))]
end

function parse_float_list(s::AbstractString)
    vals = Float64[]
    for tok in parse_csv_list(s)
        v = tryparse(Float64, tok)
        v === nothing && error("Unable to parse numeric value '$tok' in list: $s")
        push!(vals, v)
    end
    return vals
end

function resolve_profile_columns(df::DataFrame, profile_cols_arg::String, heights_arg::String)
    if !isempty(strip(profile_cols_arg))
        cols = parse_csv_list(profile_cols_arg)
        heights = parse_float_list(heights_arg)
        length(cols) == length(heights) || error("--profile-cols and --heights must have same length")

        missing_cols = [c for c in cols if !(c in names(df))]
        isempty(missing_cols) || error("Missing requested profile columns: $(join(missing_cols, ", "))")

        return cols, heights
    end

    inferred = Tuple{String,Float64}[]
    for nm in names(df)
        h = parse_height_from_name(nm)
        h === nothing && continue
        push!(inferred, (String(nm), h))
    end
    isempty(inferred) && error("No profile columns inferred. Use --profile-cols and --heights explicitly.")

    sort!(inferred, by=x -> x[2])
    return first.(inferred), last.(inferred)
end

function to_finite_float(raw)
    if raw === missing || ismissing(raw)
        return nothing
    end
    if raw isa Number
        v = Float64(raw)
        return isfinite(v) ? v : nothing
    end
    v = tryparse(Float64, string(raw))
    if v === nothing
        return nothing
    end
    return isfinite(v) ? v : nothing
end

function compute_row_metrics(row, profile_cols::Vector{String}, heights::Vector{Float64})
    z = Float64[]
    y = Float64[]

    for (c, h) in zip(profile_cols, heights)
        v = to_finite_float(row[Symbol(c)])
        if v === nothing
            continue
        end
        push!(z, h)
        push!(y, v)
    end

    if length(z) < 5
        return (missing, missing, missing, missing, length(z), "insufficient_levels")
    end

    p = sortperm(z)
    z_sorted = z[p]
    y_sorted = y[p]

    try
        e = compute_shape_energy(y_sorted, z_sorted)
        return (e.E_g, e.E_kappa, e.E_j, e.R, length(z_sorted), "ok")
    catch err
        return (missing, missing, missing, missing, length(z_sorted), sprint(showerror, err))
    end
end

function compute_row_metrics_fast(row_idx::Int, profile_data::Vector, heights::Vector{Float64})
    z = Float64[]
    y = Float64[]

    for (col, h) in zip(profile_data, heights)
        v = to_finite_float(col[row_idx])
        if v === nothing
            continue
        end
        push!(z, h)
        push!(y, v)
    end

    if length(z) < 5
        return (missing, missing, missing, missing, length(z), "insufficient_levels")
    end

    p = sortperm(z)
    z_sorted = z[p]
    y_sorted = y[p]

    try
        e = compute_shape_energy(y_sorted, z_sorted)
        return (e.E_g, e.E_kappa, e.E_j, e.R, length(z_sorted), "ok")
    catch err
        return (missing, missing, missing, missing, length(z_sorted), sprint(showerror, err))
    end
end

function build_parser()
    settings = ArgParseSettings(description="Compute shape-energy metrics from profile CSV rows")
    @add_arg_table settings begin
        "--input"
            help = "Input CSV with profile columns"
            arg_type = String
            required = true
        "--output"
            help = "Output CSV for shape-energy metrics"
            arg_type = String
            required = true
        "--time-col"
            help = "Optional time column copied into output if present"
            arg_type = String
            default = ""
        "--profile-cols"
            help = "Comma-separated profile columns (if omitted, auto-detect *_Xm suffix)"
            arg_type = String
            default = ""
        "--heights"
            help = "Comma-separated heights in meters matching --profile-cols order"
            arg_type = String
            default = ""
    end
    return settings
end

function main()
    args = parse_args(ARGS, build_parser())

    input_path = args["input"]
    output_path = args["output"]
    time_col = args["time-col"]

    @printf("Loading input: %s\n", input_path)
    df = CSV.read(input_path, DataFrame)
    profile_cols, heights = resolve_profile_columns(df, args["profile-cols"], args["heights"])
    profile_syms = Symbol.(profile_cols)
    profile_data = [df[!, s] for s in profile_syms]

    @printf("Using %d profile columns\n", length(profile_cols))

    n_rows = nrow(df)
    out = DataFrame(
        row_index = collect(1:n_rows),
        E_g = Vector{Union{Missing,Float64}}(fill(missing, n_rows)),
        E_kappa = Vector{Union{Missing,Float64}}(fill(missing, n_rows)),
        E_j = Vector{Union{Missing,Float64}}(fill(missing, n_rows)),
        R = Vector{Union{Missing,Float64}}(fill(missing, n_rows)),
        levels_used = zeros(Int, n_rows),
        status = fill("", n_rows)
    )

    if !isempty(time_col) && (time_col in names(df))
        out[!, :time_value] = df[!, Symbol(time_col)]
    end

    for i in 1:n_rows
        Eg, Ek, Ej, Rv, nlev, status = compute_row_metrics_fast(i, profile_data, heights)
        out.E_g[i] = Eg
        out.E_kappa[i] = Ek
        out.E_j[i] = Ej
        out.R[i] = Rv
        out.levels_used[i] = nlev
        out.status[i] = status
    end

    mkpath(dirname(output_path))
    CSV.write(output_path, out)

    n_ok = count(==("ok"), out.status)
    @printf("Wrote %s (%d/%d rows ok)\n", output_path, n_ok, nrow(out))
end

main()
