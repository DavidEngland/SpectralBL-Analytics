#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

push!(LOAD_PATH, joinpath(pwd(), "src"))
using IngestionFormatters

if length(ARGS) < 1
    error("Usage: julia --project='.' scripts/inspect_vertical_coverage.jl <path/to/file.nc>")
end

nc_path = ARGS[1]
stats = inspect_netcdf_vertical_coverage(nc_path)

println("Vertical Coverage Report")
println("========================")
println("File: ", stats.path)
println("Timesteps: ", stats.n_time)
println("Valid (z,u) pairs: min=", stats.min_valid_pairs,
        ", median=", stats.median_valid_pairs,
        ", max=", stats.max_valid_pairs)
println("Timesteps with 0-1 valid pairs: ", stats.one_or_zero_timesteps)
println("Timesteps with exactly 2 valid pairs: ", stats.two_level_timesteps)
println("Timesteps with >=3 valid pairs: ", stats.three_plus_timesteps)
println("Viable for interpolation: ", stats.viable_for_interpolation)
println("Robust for eta_3 interpretation: ", stats.robust_for_eta3)
