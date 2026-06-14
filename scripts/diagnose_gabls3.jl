#!/usr/bin/env julia
using NCDatasets

ds = NCDataset("data/gabs3/gabls3_scm_cabauw_obs_v33.nc")
z_full = ds["zf"][:, :]
u_full = ds["u"][:, :]

config_heights = [10.0, 20.0, 40.0, 80.0, 120.0, 200.0]

println("GABLS3 Diagnostic Report")
println(repeat("=", 50))

valid_counts = 0
for t in 1:size(u_full, 2)
    z_t = map(v -> ismissing(v) ? NaN : Float64(v), z_full[:, t])
    u_t = map(v -> ismissing(v) ? NaN : Float64(v), u_full[:, t])
    valid_mask = isfinite.(z_t) .& isfinite.(u_t)
    if count(valid_mask) >= 2
        valid_counts += 1
    end
end

println("Time steps with ≥2 finite (z, u) pairs: $(valid_counts) / 144")
println("\nFirst 5 passing time steps:")
n_checked = 0
for t in 1:144
    z_t = map(v -> ismissing(v) ? NaN : Float64(v), z_full[:, t])
    u_t = map(v -> ismissing(v) ? NaN : Float64(v), u_full[:, t])
    valid_mask = isfinite.(z_t) .& isfinite.(u_t)
    n_valid = count(valid_mask)
    
    if n_valid >= 2
        n_checked += 1
        z_valid = z_t[valid_mask]
        u_valid = u_t[valid_mask]
        z_min, z_max = extrema(z_valid)
        can_interp = all(h >= z_min && h <= z_max * 1.1 for h in config_heights)
        println("  t=$(t): $(n_valid) pairs, z∈[$(round(z_min,digits=1)), $(round(z_max,digits=1))], interp=$(can_interp)")
        if n_checked >= 5
            break
        end
    end
end

close(ds)
