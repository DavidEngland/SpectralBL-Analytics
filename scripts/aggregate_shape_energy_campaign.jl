#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using ArgParse
using CSV
using DataFrames
using Dates
using Statistics
using Printf

const METRIC_COLS = [:E_g, :E_kappa, :E_j, :R]

function col_symbols(df::DataFrame)
    return Symbol.(names(df))
end

function has_col(df::DataFrame, c::Symbol)
    return c in col_symbols(df)
end

function build_parser()
    settings = ArgParseSettings(description="Aggregate campaign-level shape-energy diagnostics")
    @add_arg_table settings begin
        "--shape-csv"
            help = "Input shape-energy CSV from compute_shape_energy_profiles.jl"
            arg_type = String
            required = true
        "--trajectory-csv"
            help = "Optional trajectory CSV for campaign/regime metadata"
            arg_type = String
            default = ""
        "--output-prefix"
            help = "Output file prefix (writes *_hourly_medians.csv, *_daily_medians.csv, *_regime_distribution.csv)"
            arg_type = String
            required = true
        "--ri-coupled-threshold"
            help = "Ri threshold for coupled_sheet classification"
            arg_type = Float64
            default = 0.25
        "--ri-fold-threshold"
            help = "Ri threshold for fold_proximal classification"
            arg_type = Float64
            default = 0.40
    end
    return settings
end

function find_matching_col(df::DataFrame, candidates::Vector{Symbol})
    for c in candidates
        if has_col(df, c)
            return c
        end
    end
    return nothing
end

function numeric_column(x)
    x === missing && return missing
    if x isa Number
        return Float64(x)
    end
    v = tryparse(Float64, string(x))
    return v === nothing ? missing : v
end

function resolve_time_seconds(v)
    if v === missing
        return missing
    end
    if v isa Number
        return Float64(v)
    end

    s = strip(string(v))
    if isempty(s)
        return missing
    end

    num = tryparse(Float64, s)
    if num !== nothing
        return num
    end

    dt = try
        DateTime(s)
    catch
        nothing
    end

    if dt === nothing
        return missing
    end

    return Float64(Dates.datetime2unix(dt))
end

function compute_ri_mean!(df::DataFrame)
    if has_col(df, :ri_mean)
        return
    end

    ri_cols = [c for c in names(df) if startswith(String(c), "ri_g_")]
    if isempty(ri_cols)
        df[!, :ri_mean] = fill(missing, nrow(df))
        return
    end

    ri_mean = Vector{Union{Missing,Float64}}(undef, nrow(df))
    for i in 1:nrow(df)
        vals = Float64[]
        for c in ri_cols
            v = numeric_column(df[i, c])
            if v !== missing && isfinite(v)
                push!(vals, v)
            end
        end
        ri_mean[i] = isempty(vals) ? missing : mean(vals)
    end
    df[!, :ri_mean] = ri_mean
end

function classify_phase(ri::Union{Missing,Float64}, coupled_th::Float64, fold_th::Float64)
    if ri === missing || !isfinite(ri)
        return "unknown"
    elseif ri <= coupled_th
        return "coupled_sheet"
    elseif ri <= fold_th
        return "fold_proximal"
    else
        return "decoupled_sheet"
    end
end

function add_time_bins!(df::DataFrame)
    time_col = find_matching_col(df, [:time_value, :time, :timestamp])
    if time_col === nothing
        error("No time column found. Expected one of: time_value, time, timestamp")
    end

    tsec = Vector{Union{Missing,Float64}}(undef, nrow(df))
    for i in 1:nrow(df)
        tsec[i] = resolve_time_seconds(df[i, time_col])
    end
    df[!, :time_seconds] = tsec

    finite_times = [t for t in tsec if t !== missing && isfinite(t)]
    isempty(finite_times) && error("No valid time values found for aggregation")

    t0 = minimum(finite_times)

    hour_index = Vector{Union{Missing,Int}}(undef, nrow(df))
    day_index = Vector{Union{Missing,Int}}(undef, nrow(df))
    utc_hour = Vector{Union{Missing,Int}}(undef, nrow(df))
    utc_day = Vector{Union{Missing,String}}(undef, nrow(df))

    for i in 1:nrow(df)
        t = tsec[i]
        if t === missing || !isfinite(t)
            hour_index[i] = missing
            day_index[i] = missing
            utc_hour[i] = missing
            utc_day[i] = missing
            continue
        end

        hour_index[i] = floor(Int, (t - t0) / 3600.0)
        day_index[i] = floor(Int, (t - t0) / 86400.0)

        dt = unix2datetime(round(Int, t))
        utc_hour[i] = Dates.hour(dt)
        utc_day[i] = string(Date(dt))
    end

    df[!, :hour_index] = hour_index
    df[!, :day_index] = day_index
    df[!, :utc_hour] = utc_hour
    df[!, :utc_day] = utc_day
end

function ensure_metrics_present(df::DataFrame)
    missing_cols = [String(c) for c in METRIC_COLS if !has_col(df, c)]
    isempty(missing_cols) || error("Missing required metric columns: $(join(missing_cols, ", "))")
end

function with_numeric_metrics(df::DataFrame)
    out = copy(df)
    for c in METRIC_COLS
        out[!, c] = [numeric_column(v) for v in out[!, c]]
    end
    return out
end

function group_medians(df::DataFrame, group_col::Symbol)
    grouped = groupby(df, group_col)

    rows = DataFrame()
    rows[!, group_col] = Int[]
    rows[!, :n_samples] = Int[]
    for c in METRIC_COLS
        rows[!, Symbol(string(c) * "_median")] = Float64[]
    end

    for g in grouped
        idx = g[1, group_col]
        vals = Dict{Symbol,Float64}()
        n_valid = 0

        for c in METRIC_COLS
            finite_vals = Float64[]
            for v in g[!, c]
                if v !== missing && isfinite(v)
                    push!(finite_vals, v)
                end
            end
            vals[c] = isempty(finite_vals) ? NaN : median(finite_vals)
            n_valid = max(n_valid, length(finite_vals))
        end

        push!(rows[!, group_col], idx)
        push!(rows.n_samples, n_valid)
        for c in METRIC_COLS
            push!(rows[!, Symbol(string(c) * "_median")], vals[c])
        end
    end

    sort!(rows, group_col)
    return rows
end

function write_regime_distribution(df::DataFrame, output_path::String)
    grouped = groupby(df, :regime)
    out = DataFrame(regime=String[], count=Int[], fraction=Float64[])

    total = nrow(df)
    for g in grouped
        n = nrow(g)
        push!(out, (String(g[1, :regime]), n, total == 0 ? NaN : n / total))
    end

    sort!(out, :count, rev=true)
    CSV.write(output_path, out)
end

function main()
    args = parse_args(ARGS, build_parser())

    shape_csv = args["shape-csv"]
    trajectory_csv = args["trajectory-csv"]
    output_prefix = args["output-prefix"]
    ri_coupled = args["ri-coupled-threshold"]
    ri_fold = args["ri-fold-threshold"]

    shape = CSV.read(shape_csv, DataFrame)
    ensure_metrics_present(shape)

    # Keep only successful metric rows if status is available.
    if has_col(shape, :status)
        shape = shape[shape.status .== "ok", :]
    end

    if !isempty(trajectory_csv)
        traj = CSV.read(trajectory_csv, DataFrame)

        join_on = if has_col(shape, :time_value) && has_col(traj, :time_value)
            :time_value
        elseif has_col(shape, :row_index) && has_col(traj, :sample_index)
            :row_index
        else
            nothing
        end

        if join_on === :time_value
            shape = leftjoin(shape, traj, on=:time_value, makeunique=true)
        elseif join_on === :row_index
            rename!(traj, :sample_index => :row_index)
            shape = leftjoin(shape, traj, on=:row_index, makeunique=true)
        end
    end

    shape = with_numeric_metrics(shape)
    compute_ri_mean!(shape)

    if has_col(shape, :campaign)
        shape[!, :campaign_name] = string.(shape[!, :campaign])
    else
        shape[!, :campaign_name] = fill("UNKNOWN", nrow(shape))
    end

    shape[!, :regime] = [classify_phase(v, ri_coupled, ri_fold) for v in shape.ri_mean]

    add_time_bins!(shape)

    valid_time = shape[(shape.hour_index .!== missing) .& (shape.day_index .!== missing), :]

    hourly = group_medians(valid_time, :hour_index)
    daily = group_medians(valid_time, :day_index)

    if !isempty(valid_time)
        hourly[!, :campaign] = fill(String(valid_time[1, :campaign_name]), nrow(hourly))
        daily[!, :campaign] = fill(String(valid_time[1, :campaign_name]), nrow(daily))
    end

    out_dir = dirname(output_prefix)
    mkpath(out_dir)

    hourly_path = output_prefix * "_hourly_medians.csv"
    daily_path = output_prefix * "_daily_medians.csv"
    regime_path = output_prefix * "_regime_distribution.csv"

    CSV.write(hourly_path, hourly)
    CSV.write(daily_path, daily)
    write_regime_distribution(valid_time, regime_path)

    @printf("Wrote %s\n", hourly_path)
    @printf("Wrote %s\n", daily_path)
    @printf("Wrote %s\n", regime_path)
end

main()
