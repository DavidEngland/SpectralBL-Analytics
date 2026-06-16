# src/IngestionFormatters.jl
module IngestionFormatters

using LinearAlgebra
using NCDatasets
using CSV
using DataFrames
using Dates
using Statistics

export CampaignConfig, get_campaign_geometry, load_campaign_samples, inspect_netcdf_vertical_coverage

"""
    CampaignConfig

Holds rigid tower heights, physical displacements, and aerodynamic anchors
for an experimental domain.
"""
struct CampaignConfig
    name::String
    tower_heights::Vector{Float64} # Physical measurement levels (z)
    z0m::Float64                  # Aerodynamic roughness length for momentum
    z0h::Float64                  # Aerodynamic roughness length for heat
    d::Float64                    # Displacement height coordinate shift
end

struct CampaignSample
    source_file::String
    time_value::Float64
    tower_vector::Vector{Float64}
    grid_vector::Vector{Float64}
end

function get_campaign_geometry(campaign::Symbol)
    if campaign == :CASES_99
        # 60m main tower classic levels (e.g., 1.5m, 5m, 10m, 20m, 30m, 40m, 50m, 55m)
        return CampaignConfig("CASES-99", [1.5, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0], 0.03, 0.003, 0.0)
    elseif campaign == :GABLS3
        # Cabauw tower heights: 10m, 60m, 100m, 180m
        return CampaignConfig("GABLS3", [10.0, 60.0, 100.0, 180.0], 0.15, 0.015, 0.0)
    elseif campaign == :ARCTIC_AMPLIFICATION
        # Arctic stable-boundary layer surrogate heights (SHEBA-informed near-surface coverage)
        return CampaignConfig("ARCTIC-AMPLIFICATION", [2.5, 10.0, 20.0, 40.0, 80.0], 0.01, 0.001, 0.0)
    else
        error("Unknown campaign target configuration: ", campaign)
    end
end

"""
    load_campaign_samples(campaign, pfem_grid; data_root="data", rank=3)

Load campaign netCDF observations and return a low-rank basis and time-indexed
measurement samples ready for attractor diagnostics.
"""
function load_campaign_samples(campaign::Symbol, pfem_grid::Vector{Float64}; data_root::String="data", rank::Int=3)
    config = get_campaign_geometry(campaign)

    if campaign == :GABLS3
        data_path = joinpath(data_root, "gabs3", "gabls3_scm_cabauw_obs_v33.nc")
        samples = read_gabls_netcdf(data_path, config, pfem_grid)
    elseif campaign == :CASES_99
        cases_dir = joinpath(data_root, "ncar_eol_dee0099881")
        nc_paths = sort(filter(p -> endswith(p, ".nc"), readdir(cases_dir; join=true)))
        samples = CampaignSample[]
        for path in nc_paths
            append!(samples, read_cases_netcdf(path, config, pfem_grid))
        end
    elseif campaign == :ARCTIC_AMPLIFICATION
        data_path = joinpath(data_root, "sheba", "processed", "sheba_input.csv")
        samples = read_arctic_sheba_csv(data_path, config, pfem_grid)
    else
        error("Unknown campaign target configuration: ", campaign)
    end

    isempty(samples) && error("No usable samples found for campaign $(campaign).")

    Y = hcat([s.grid_vector for s in samples]...)
    centered_Y = Y .- mean(Y; dims=2)
    svd_result = svd(centered_Y; full=false)
    target_rank = min(rank, size(svd_result.U, 2))
    U_r = svd_result.U[:, 1:target_rank]
    if target_rank < rank
        U_r = hcat(U_r, zeros(size(U_r, 1), rank - target_rank))
    end

    return U_r, samples
end

function read_gabls_netcdf(path::String, config::CampaignConfig, pfem_grid::Vector{Float64})
    if !isfile(path)
        error("Missing netCDF file: $(path)")
    end

    ds = NCDataset(path)
    try
        # Try tower variables first (zh/uw), then fall back to model levels (zf/u)
        if haskey(ds, "zh") && haskey(ds, "uw")
            z_values = ds["zh"][:, :]
            u_values = ds["uw"][:, :]
        else
            z_values = read_variable(ds, [:zf, :zt, :z, :height])
            u_values = read_variable(ds, [:u, :v, :U])
        end
        time_values = read_variable(ds, [:time])

        z_mat = to_level_time_matrix(z_values)
        u_mat = to_level_time_matrix(u_values)

        n_time = min(size(z_mat, 2), size(u_mat, 2), length(time_values))
        out = CampaignSample[]
        two_level_count = 0
        three_plus_count = 0

        for t in 1:n_time
            z_t = Vector{Float64}(z_mat[:, t])
            u_t = Vector{Float64}(u_mat[:, t])

            valid_pairs = isfinite.(z_t) .& isfinite.(u_t)
            n_valid = count(valid_pairs)
            if n_valid == 2
                two_level_count += 1
            elseif n_valid >= 3
                three_plus_count += 1
            end
            if n_valid < 2
                continue
            end

            z_valid = z_t[valid_pairs]
            u_valid = u_t[valid_pairs]
            z_sorted, u_sorted = sort_pairs(z_valid, u_valid)

            z_min, z_max = extrema(z_sorted)

            # Avoid unphysical extrapolation: trim interpolation targets to observed bounds.
            active_tower_targets = filter(h -> z_min <= h <= z_max, config.tower_heights)
            active_pfem_targets = filter(h -> z_min <= h <= z_max, pfem_grid)

            can_interp_tower = !isempty(active_tower_targets) && all(h -> h >= z_min, active_tower_targets)
            can_interp_grid = !isempty(active_pfem_targets) && all(h -> h >= z_min, active_pfem_targets)

            if !(can_interp_tower && can_interp_grid)
                continue
            end

            tower_vector = interpolate_profile(z_sorted, u_sorted, config.tower_heights)
            grid_vector = interpolate_profile(z_sorted, u_sorted, pfem_grid)

            if !all(isfinite, tower_vector) || !all(isfinite, grid_vector)
                continue
            end

            push!(out, CampaignSample(path, normalize_time_value(time_values[t]), tower_vector, grid_vector))
        end

        if !isempty(out) && two_level_count > three_plus_count
            @warn "Campaign ingestion dominated by 2-level profiles; eta_3 interpretation may be weak." path two_level_count three_plus_count
        end

        return out
    finally
        close(ds)
    end
end

"""
    inspect_netcdf_vertical_coverage(path; z_candidates=..., u_candidates=...)

Inspect vertical profile coverage in a NetCDF file and report whether it has
enough finite (z, u) pairs per timestep for stable low-rank diagnostics.
"""
function inspect_netcdf_vertical_coverage(
    path::String;
    z_candidates::Vector{Symbol}=[:zh, :zf, :zt, :z, :height],
    u_candidates::Vector{Symbol}=[:uw, :u, :U, :v],
)
    if !isfile(path)
        error("Missing netCDF file: $(path)")
    end

    ds = NCDataset(path)
    try
        z_values = read_variable(ds, z_candidates)
        u_values = read_variable(ds, u_candidates)

        z_mat = to_level_time_matrix(z_values)
        u_mat = to_level_time_matrix(u_values)
        n_time = min(size(z_mat, 2), size(u_mat, 2))

        valid_counts = Int[]
        for t in 1:n_time
            z_t = Vector{Float64}(z_mat[:, t])
            u_t = Vector{Float64}(u_mat[:, t])
            push!(valid_counts, count(isfinite.(z_t) .& isfinite.(u_t)))
        end

        two_level = count(==(2), valid_counts)
        three_plus = count(>=(3), valid_counts)
        one_or_zero = count(<=(1), valid_counts)

        return (
            path = path,
            n_time = n_time,
            min_valid_pairs = minimum(valid_counts),
            median_valid_pairs = median(valid_counts),
            max_valid_pairs = maximum(valid_counts),
            two_level_timesteps = two_level,
            three_plus_timesteps = three_plus,
            one_or_zero_timesteps = one_or_zero,
            viable_for_interpolation = three_plus > 0 || two_level > 0,
            robust_for_eta3 = three_plus > 0,
        )
    finally
        close(ds)
    end
end

function read_cases_netcdf(path::String, config::CampaignConfig, pfem_grid::Vector{Float64})
    if !isfile(path)
        error("Missing netCDF file: $(path)")
    end

    ds = NCDataset(path)
    try
        time_values = read_variable(ds, [:time])
        tower_series = read_cases_tower_series(ds)
        n_time = min(length(time_values), size(tower_series, 2))

        out = CampaignSample[]
        for t in 1:n_time
            tower_vector = Vector{Float64}(tower_series[:, t])
            if !all(isfinite, tower_vector)
                continue
            end

            grid_vector = interpolate_profile(config.tower_heights, tower_vector, pfem_grid)
            push!(out, CampaignSample(path, normalize_time_value(time_values[t]), tower_vector, grid_vector))
        end

        return out
    finally
        close(ds)
    end
end

function read_arctic_sheba_csv(path::String, config::CampaignConfig, pfem_grid::Vector{Float64})
    if !isfile(path)
        error("Missing Arctic/SHEBA CSV file: $(path)")
    end

    df = CSV.read(path, DataFrame)
    existing = Set(String.(names(df)))
    required = ["time", "ws_lo", "ws_hi", "z_lo", "z_hi"]
    missing_cols = [c for c in required if !(c in existing)]
    if !isempty(missing_cols)
        error("SHEBA CSV missing required columns: $(join(missing_cols, ", "))")
    end

    out = CampaignSample[]
    for row in eachrow(df)
        z_lo = Float64(row["z_lo"])
        z_hi = Float64(row["z_hi"])
        ws_lo = Float64(row["ws_lo"])
        ws_hi = Float64(row["ws_hi"])

        if !(isfinite(z_lo) && isfinite(z_hi) && isfinite(ws_lo) && isfinite(ws_hi))
            continue
        end

        z_sorted, u_sorted = sort_pairs([z_lo, z_hi], [ws_lo, ws_hi])

        tower_vector = interpolate_profile(z_sorted, u_sorted, config.tower_heights)
        grid_vector = interpolate_profile(z_sorted, u_sorted, pfem_grid)

        if !all(isfinite, tower_vector) || !all(isfinite, grid_vector)
            continue
        end

        tval = normalize_time_value(row["time"])
        push!(out, CampaignSample(path, tval, tower_vector, grid_vector))
    end

    return out
end

function read_cases_tower_series(ds::NCDataset)
    target_heights = [1.5, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0]
    available = Dict{Float64, String}()
    for name in keys(ds)
        s = String(name)
        m = match(r"^u_(\d+(?:_\d+)?)m$", s)
        if m !== nothing
            height = parse(Float64, replace(m.captures[1], "_" => "."))
            available[height] = s
        end
    end

    isempty(available) && error("No CASES-99 u_*m tower variables found.")
    available_heights = sort(collect(keys(available)))

    series = Vector{Vector{Float64}}()
    for zt in target_heights
        best_h = findmin(abs.(available_heights .- zt))[2]
        matched_h = available_heights[best_h]
        vname = available[matched_h]

        raw_vals = vec(Array(ds[vname][:]))
        vals = map(v -> ismissing(v) ? NaN : Float64(v), raw_vals)
        push!(series, vals)
    end

    n_time = minimum(length(s) for s in series)
    return hcat([s[1:n_time] for s in series]...)'
end

function read_variable(ds::NCDataset, names::Vector{Symbol})
    for name in names
        key = String(name)
        if haskey(ds, key)
            return ds[key][:]
        end
    end
    error("Missing required variable. Tried: $(join(String.(names), ", "))")
end

function to_level_time_matrix(values)
    raw = Array(values)
    arr = map(v -> ismissing(v) ? NaN : Float64(v), raw)
    if ndims(arr) == 1
        return reshape(arr, :, 1)
    elseif ndims(arr) == 2
        return arr
    else
        error("Unsupported variable rank $(ndims(arr)); expected 1D or 2D variable.")
    end
end

function sort_pairs(z::Vector{Float64}, u::Vector{Float64})
    order = sortperm(z)
    z_sorted = z[order]
    u_sorted = u[order]

    dedup_z = Float64[]
    dedup_u = Float64[]
    i = 1
    while i <= length(z_sorted)
        zi = z_sorted[i]
        j = i
        accum = 0.0
        n = 0
        while j <= length(z_sorted) && z_sorted[j] == zi
            accum += u_sorted[j]
            n += 1
            j += 1
        end
        push!(dedup_z, zi)
        push!(dedup_u, accum / n)
        i = j
    end

    return dedup_z, dedup_u
end

function interpolate_profile(z::Vector{Float64}, values::Vector{Float64}, target_z::Vector{Float64})
    out = Vector{Float64}(undef, length(target_z))
    for (i, zt) in enumerate(target_z)
        if zt <= z[1]
            out[i] = values[1]
            continue
        elseif zt >= z[end]
            out[i] = values[end]
            continue
        end

        idx = searchsortedlast(z, zt)
        z_l = z[idx]
        z_r = z[idx + 1]
        v_l = values[idx]
        v_r = values[idx + 1]
        weight = (zt - z_l) / (z_r - z_l)
        out[i] = (1.0 - weight) * v_l + weight * v_r
    end
    return out
end

function normalize_time_value(t)
    if t isa Number
        return Float64(t)
    elseif t isa DateTime
        return Dates.datetime2unix(t)
    else
        s = string(t)
        parsed_dt = tryparse(DateTime, s)
        if parsed_dt !== nothing
            return Dates.datetime2unix(parsed_dt)
        end
        parsed_num = tryparse(Float64, s)
        if parsed_num !== nothing
            return parsed_num
        end
        error("Unsupported time value type: $(typeof(t))")
    end
end

end # module