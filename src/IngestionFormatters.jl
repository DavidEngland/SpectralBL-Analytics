# src/IngestionFormatters.jl
module IngestionFormatters

using LinearAlgebra
using NCDatasets
using Dates
using Statistics

export CampaignConfig, get_campaign_geometry, load_campaign_samples

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
        # Cabauw tower tall configurations (e.g., up to 200m)
        return CampaignConfig("GABLS3", [10.0, 20.0, 40.0, 80.0, 120.0, 200.0], 0.15, 0.015, 0.0)
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
        z_values = read_variable(ds, [:zf, :zt, :z, :height, :zh])
        u_values = read_variable(ds, [:u, :U])
        time_values = read_variable(ds, [:time])

        z_mat = to_level_time_matrix(z_values)
        u_mat = to_level_time_matrix(u_values)

        n_time = min(size(z_mat, 2), size(u_mat, 2), length(time_values))
        out = CampaignSample[]

        for t in 1:n_time
            z_t = Vector{Float64}(z_mat[:, t])
            u_t = Vector{Float64}(u_mat[:, t])

            valid = isfinite.(z_t) .& isfinite.(u_t)
            if count(valid) < 2
                continue
            end

            z_valid = z_t[valid]
            u_valid = u_t[valid]

            z_sorted, u_sorted = sort_pairs(z_valid, u_valid)

            tower_vector = interpolate_profile(z_sorted, u_sorted, config.tower_heights)
            grid_vector = interpolate_profile(z_sorted, u_sorted, pfem_grid)

            if !all(isfinite, tower_vector) || !all(isfinite, grid_vector)
                continue
            end

            push!(out, CampaignSample(path, normalize_time_value(time_values[t]), tower_vector, grid_vector))
        end

        return out
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