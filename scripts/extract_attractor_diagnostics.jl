# scripts/extract_attractor_diagnostics.jl
using Pkg
Pkg.activate(".")

# Ensure local source directory is within load paths
push!(LOAD_PATH, joinpath(pwd(), "src"))

using IngestionFormatters
using AttractorDiagnostics
using CSV
using DataFrames
using Dates
using LinearAlgebra
using Printf
using Statistics
using JSON3

include("DiagnosticsBaseline.jl")
using .DiagnosticsBaseline

function height_token(z::Float64)
    rounded = round(z; digits=1)
    s = @sprintf("%.1f", rounded)
    return replace(s, "." => "_")
end

function all_campaign_heights()
    configs = [get_campaign_geometry(c) for c in (:CASES_99, :GABLS3, :ARCTIC_AMPLIFICATION, :FLOSS, :BLLAST)]
    vals = sort(unique(vcat([cfg.tower_heights for cfg in configs]...)))
    return Float64.(vals)
end

function compute_ri_g_profile_proxy(tower_heights::Vector{Float64}, tower_vector::Vector{Float64}, eta3::Float64)
    n = min(length(tower_heights), length(tower_vector))
    if n < 2
        return fill(NaN, n)
    end

    z = tower_heights[1:n]
    u = tower_vector[1:n]

    du_dz = zeros(Float64, n)
    du_dz[1] = (u[2] - u[1]) / max(z[2] - z[1], 1e-6)
    for i in 2:(n - 1)
        du_dz[i] = (u[i + 1] - u[i - 1]) / max(z[i + 1] - z[i - 1], 1e-6)
    end
    du_dz[end] = (u[end] - u[end - 1]) / max(z[end] - z[end - 1], 1e-6)

    shear = abs.(du_dz)
    shear_scale = max(median(shear), 1e-3)
    zmax = max(maximum(z), 1e-3)
    stability_base = 0.15 .+ 0.60 .* (z ./ zmax)
    intermittency = 0.05 * clamp(abs(eta3) / 20.0, 0.0, 2.0)

    ri = stability_base ./ (1.0 .+ (shear ./ shear_scale) .^ 2) .+ intermittency
    ri = clamp.(ri, -0.5, 2.5)
    return ri
end

function parse_campaign_arg(arg::String)
    normalized = uppercase(strip(arg))
    if normalized == "ALL"
        return [:CASES_99, :GABLS3, :ARCTIC_AMPLIFICATION, :FLOSS, :BLLAST]
    elseif normalized in ("CASES-99", "CASES_99")
        return [:CASES_99]
    elseif normalized == "GABLS3"
        return [:GABLS3]
    elseif normalized in ("ARCTIC-AMPLIFICATION", "ARCTIC_AMPLIFICATION", "ARCTIC")
        return [:ARCTIC_AMPLIFICATION]
    elseif normalized in ("FLOSS", "FLOSS_I", "FLOSS-I", "FLOSS_II", "FLOSS-II")
        return [:FLOSS]
    elseif normalized == "BLLAST"
        return [:BLLAST]
    end
    error("Unsupported campaign selector: $(arg). Use ALL, CASES-99, GABLS3, ARCTIC-AMPLIFICATION, FLOSS, or BLLAST.")
end

function campaign_slug(name::String)
    safe = lowercase(replace(name, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    return isempty(safe) ? "campaign" : String(safe)
end

function parse_ri_height(col::Symbol)
    name = String(col)
    startswith(name, "ri_g_") || return nothing
    raw = replace(name[6:end], "_" => ".")
    h = tryparse(Float64, raw)
    return h
end

function parse_ri_height(col::AbstractString)
    return parse_ri_height(Symbol(col))
end

function finite_mean(vals::Vector{Float64})
    keep = [v for v in vals if isfinite(v)]
    isempty(keep) && return NaN
    return mean(keep)
end

function as_float_or_nan(x)
    if x === missing
        return NaN
    elseif x isa Number
        return Float64(x)
    end
    v = tryparse(Float64, string(x))
    return v === nothing ? NaN : v
end

function json_nullable(x)
    if x isa Number
        f = Float64(x)
        return isfinite(f) ? f : nothing
    end
    return x
end

function centered_derivative(t::Vector{Float64}, x::Vector{Float64})
    n = min(length(t), length(x))
    n == 0 && return Float64[]
    n == 1 && return [NaN]

    out = fill(NaN, n)
    dt1 = t[2] - t[1]
    out[1] = abs(dt1) < 1e-12 ? NaN : (x[2] - x[1]) / dt1
    for i in 2:(n - 1)
        dt = t[i + 1] - t[i - 1]
        out[i] = abs(dt) < 1e-12 ? NaN : (x[i + 1] - x[i - 1]) / dt
    end
    dtn = t[end] - t[end - 1]
    out[end] = abs(dtn) < 1e-12 ? NaN : (x[end] - x[end - 1]) / dtn
    return out
end

function pearson_corr(x::Vector{Float64}, y::Vector{Float64})
    n = min(length(x), length(y))
    keep = Int[]
    for i in 1:n
        if isfinite(x[i]) && isfinite(y[i])
            push!(keep, i)
        end
    end
    length(keep) < 3 && return NaN

    xv = x[keep]
    yv = y[keep]
    sx = std(xv)
    sy = std(yv)
    (sx <= 0.0 || sy <= 0.0) && return NaN
    return cor(xv, yv)
end

function mutual_information_bits(x::Vector{Float64}, y::Vector{Float64}; bins::Int=16)
    n = min(length(x), length(y))
    xf = Float64[]
    yf = Float64[]
    for i in 1:n
        if isfinite(x[i]) && isfinite(y[i])
            push!(xf, x[i])
            push!(yf, y[i])
        end
    end
    m = length(xf)
    m < 8 && return NaN

    xmin, xmax = extrema(xf)
    ymin, ymax = extrema(yf)
    if !(isfinite(xmin) && isfinite(xmax) && isfinite(ymin) && isfinite(ymax))
        return NaN
    end
    if abs(xmax - xmin) < 1e-12 || abs(ymax - ymin) < 1e-12
        return 0.0
    end

    counts = zeros(Float64, bins, bins)
    for i in 1:m
        bx = clamp(floor(Int, (xf[i] - xmin) / (xmax - xmin) * bins) + 1, 1, bins)
        by = clamp(floor(Int, (yf[i] - ymin) / (ymax - ymin) * bins) + 1, 1, bins)
        counts[bx, by] += 1.0
    end

    pxy = counts ./ m
    px = vec(sum(pxy, dims=2))
    py = vec(sum(pxy, dims=1))

    mi = 0.0
    for i in 1:bins, j in 1:bins
        p = pxy[i, j]
        if p > 0 && px[i] > 0 && py[j] > 0
            mi += p * log2(p / (px[i] * py[j]))
        end
    end
    return mi
end

function lag_correlation_table(t::Vector{Float64}, x::Vector{Float64}, y::Vector{Float64}; max_lag::Int=24)
    lags = Int[]
    corrs = Float64[]

    n = min(length(t), length(x), length(y))
    n < 4 && return DataFrame(lag_samples=Int[], lag_hours=Float64[], correlation=Float64[])

    dt_hours = NaN
    if n > 1
        tu = unique(t[1:n])
        sort!(tu)
        if length(tu) > 1
            dtu = diff(tu)
            dtu_pos = [v for v in dtu if isfinite(v) && v > 0]
            if !isempty(dtu_pos)
                dt_raw = median(dtu_pos)
                # Heuristic: epoch-based time axes are in seconds; convert to hours.
                dt_hours = dt_raw > 600 ? dt_raw / 3600.0 : dt_raw
            end
        end
    end

    for lag in -max_lag:max_lag
        xsub = Float64[]
        ysub = Float64[]
        if lag > 0
            for i in 1:(n - lag)
                push!(xsub, x[i])
                push!(ysub, y[i + lag])
            end
        elseif lag < 0
            k = -lag
            for i in 1:(n - k)
                push!(xsub, x[i + k])
                push!(ysub, y[i])
            end
        else
            xsub = x[1:n]
            ysub = y[1:n]
        end

        push!(lags, lag)
        push!(corrs, pearson_corr(xsub, ysub))
    end

    return DataFrame(
        lag_samples = lags,
        lag_hours = [isfinite(dt_hours) ? lag * dt_hours : NaN for lag in lags],
        correlation = corrs,
    )
end

function classify_phase(ri::Float64)
    if !isfinite(ri)
        return "unknown"
    elseif ri <= 0.25
        return "coupled_sheet"
    elseif ri <= 0.40
        return "fold_proximal"
    end
    return "decoupled_sheet"
end

function write_structural_correlation_outputs(rows::DataFrame, campaigns_to_run::Vector{Symbol}; output_dir::String=joinpath("data", "outputs"))
    mkpath(output_dir)

    summary_rows = DataFrame(
        campaign=String[],
        slug=String[],
        n_samples=Int[],
        ri_low_column=String[],
        lag_best_samples=Int[],
        lag_best_hours=Float64[],
        lag_best_corr=Float64[],
        mi_subcritical_bits=Float64[],
        mi_supercritical_bits=Float64[],
    )

    ri_cols_all = [c for c in names(rows) if startswith(String(c), "ri_g_")]
    if isempty(ri_cols_all)
        return summary_rows
    end

    for campaign in campaigns_to_run
        cname = get_campaign_geometry(campaign).name
        slug = campaign_slug(cname)

        sub = rows[rows.campaign .== cname, :]
        nrow(sub) == 0 && continue
        sort!(sub, :time_value)

        ri_cols = [c for c in ri_cols_all if c in names(sub)]
        if isempty(ri_cols)
            continue
        end

        ri_heights = [(c, parse_ri_height(c)) for c in ri_cols]
        ri_heights = [(c, h) for (c, h) in ri_heights if h !== nothing]
        isempty(ri_heights) && continue
        sort!(ri_heights, by=x -> x[2])

        ri_heights_valid = Tuple{Any,Float64}[]
        for (c, h) in ri_heights
            vals = [as_float_or_nan(v) for v in sub[!, c]]
            if any(isfinite, vals)
                push!(ri_heights_valid, (c, h))
            end
        end
        isempty(ri_heights_valid) && continue

        low_col = ri_heights_valid[1][1]
        low_col_name = String(low_col)

        t = Float64.(sub.time_value)
        eta3 = Float64.(sub.eta_3)
        ri_low = [as_float_or_nan(v) for v in sub[!, low_col]]

        ri_mean = Float64[]
        for i in 1:nrow(sub)
            vals = Float64[]
            for (c, _) in ri_heights_valid
                v = as_float_or_nan(sub[i, c])
                isfinite(v) && push!(vals, v)
            end
            push!(ri_mean, finite_mean(vals))
        end

        deta3_dt = centered_derivative(t, eta3)
        dri_low_dt = centered_derivative(t, ri_low)
        phase = [classify_phase(v) for v in ri_low]

        phase_df = DataFrame(
            campaign = fill(cname, nrow(sub)),
            time_value = t,
            eta_3 = eta3,
            ri_g_low = ri_low,
            ri_g_mean = ri_mean,
            deta3_dt = deta3_dt,
            dri_g_low_dt = dri_low_dt,
            phase = phase,
        )

        corr_df = lag_correlation_table(t, deta3_dt, dri_low_dt; max_lag=24)
        cvals = Float64.(corr_df.correlation)
        best_idx = nothing
        best_abs = -Inf
        for i in 1:length(cvals)
            c = cvals[i]
            if isfinite(c) && abs(c) > best_abs
                best_abs = abs(c)
                best_idx = i
            end
        end

        lag_best_samples = best_idx === nothing ? 0 : Int(corr_df.lag_samples[best_idx])
        lag_best_hours = best_idx === nothing ? NaN : Float64(corr_df.lag_hours[best_idx])
        lag_best_corr = best_idx === nothing ? NaN : Float64(corr_df.correlation[best_idx])

        sub_mask = map(v -> isfinite(v) && v <= 0.25, ri_low)
        sup_mask = map(v -> isfinite(v) && v > 0.25, ri_low)
        eta_sub = eta3[sub_mask]
        ri_sub = ri_low[sub_mask]
        eta_sup = eta3[sup_mask]
        ri_sup = ri_low[sup_mask]
        mi_sub = mutual_information_bits(eta_sub, ri_sub)
        mi_sup = mutual_information_bits(eta_sup, ri_sup)

        phase_path = joinpath(output_dir, "structural_correlations_$(slug).csv")
        lag_path = joinpath(output_dir, "structural_lagcorr_$(slug).csv")
        summary_path = joinpath(output_dir, "structural_correlation_summary_$(slug).json")

        CSV.write(phase_path, phase_df)
        CSV.write(lag_path, corr_df)

        summary_payload = Dict(
            "campaign" => cname,
            "slug" => slug,
            "n_samples" => nrow(sub),
            "ri_low_column" => low_col_name,
            "lag_best_samples" => lag_best_samples,
            "lag_best_hours" => json_nullable(lag_best_hours),
            "lag_best_corr" => json_nullable(lag_best_corr),
            "mi_subcritical_bits" => json_nullable(mi_sub),
            "mi_supercritical_bits" => json_nullable(mi_sup),
            "phase_csv" => phase_path,
            "lagcorr_csv" => lag_path,
        )
        write(summary_path, JSON3.write(summary_payload))

        push!(summary_rows, (
            cname,
            slug,
            nrow(sub),
            low_col_name,
            lag_best_samples,
            lag_best_hours,
            lag_best_corr,
            mi_sub,
            mi_sup,
        ))
    end

    summary_table_path = joinpath(output_dir, "structural_correlation_summary.csv")
    CSV.write(summary_table_path, summary_rows)
    return summary_rows
end

println("=================================================================")
println("   RUNNING ATTRACTOR DIAGNOSTICS & P-FEM GEOMETRY GENERATION")
println("=================================================================\n")

# 1. Define computational p-FEM grid (e.g., 30 structural node coordinates up to 300 meters)
# Grid spacing can be refined heavily near the ground to capture stable gradients
pfem_grid = [0.0, 2.0, 5.0, 10.0, 20.0, 35.0, 50.0, 75.0, 100.0, 150.0, 200.0, 250.0, 300.0]

rows = DataFrame(
    campaign=String[],
    time_value=Float64[],
    z0m=Float64[],
    eta_1=Float64[],
    eta_2=Float64[],
    eta_3=Float64[],
    sv_entropy=Float64[],
    cheby_residual_norm=Float64[],
    cheby_fit_quality=Float64[],
    theta_star=Float64[],
    L_obukhov=Float64[],
    a_0=Float64[],
    a_1=Float64[],
    a_2=Float64[],
    a_3=Float64[],
    b_0=Float64[],
    b_1=Float64[],
    b_2=Float64[],
    b_3=Float64[],
    c_0=Float64[],
    c_1=Float64[],
    c_2=Float64[],
    c_3=Float64[],
    d_0=Float64[],
    d_1=Float64[],
    d_2=Float64[],
    d_3=Float64[],
    source_file=String[],
    sample_index=Int[],
    generated_at_utc=String[],
    baseline_version=String[],
    baseline_source=String[],
)

for h in all_campaign_heights()
    rows[!, Symbol("ri_g_" * height_token(h))] = Float64[]
end

campaign_selector = length(ARGS) >= 1 ? ARGS[1] : "ALL"
campaigns_to_run = parse_campaign_arg(campaign_selector)
println("Campaign selector: $(campaign_selector)")

for campaign in campaigns_to_run
    # Fetch campaign parameters
    config = get_campaign_geometry(campaign)
    println("Processing Configuration Target: $(config.name)")
    println(" -> Measurement levels (z): $(config.tower_heights) meters")
    println(" -> Local Momentum Roughness (z0m): $(config.z0m) m")

    # 2. Build Observation Operator
    A = build_observation_operator(pfem_grid, config)
    println(" -> Generated Operator Matrix A size: $(size(A, 1))x$(size(A, 2))")

    # 3. Load real campaign observations and derive low-rank basis from profiles
    U_r, samples = load_campaign_samples(campaign, pfem_grid; data_root="data", rank=3)
    println(" -> Loaded $(length(samples)) valid samples from campaign netCDF source(s)")

    lambda = 1e-4
    for (idx, sample) in enumerate(samples)
        eta_hat = ridge_fit(A, U_r, sample.tower_vector, lambda)
        H = calculate_sv_entropy(abs.(eta_hat))
        residual = fit_chebyshev_residuals(eta_hat)

        ri_profile = compute_ri_g_profile_proxy(config.tower_heights, sample.tower_vector, eta_hat[3])
        ri_map = Dict{Symbol,Float64}()
        for (j, z) in enumerate(config.tower_heights)
            ri_map[Symbol("ri_g_" * height_token(z))] = ri_profile[j]
        end

        row_named = (
            campaign=config.name,
            time_value=sample.time_value,
            z0m=config.z0m,
            eta_1=eta_hat[1],
            eta_2=eta_hat[2],
            eta_3=eta_hat[3],
            sv_entropy=H,
            cheby_residual_norm=residual.residual_norm,
            cheby_fit_quality=residual.fit_quality,
            theta_star=residual.theta_star,
            L_obukhov=residual.L_obukhov,
            a_0=residual.a[1],
            a_1=residual.a[2],
            a_2=residual.a[3],
            a_3=residual.a[4],
            b_0=residual.b[1],
            b_1=residual.b[2],
            b_2=residual.b[3],
            b_3=residual.b[4],
            c_0=residual.c[1],
            c_1=residual.c[2],
            c_2=residual.c[3],
            c_3=residual.c[4],
            d_0=residual.d[1],
            d_1=residual.d[2],
            d_2=residual.d[3],
            d_3=residual.d[4],
            source_file=sample.source_file,
            sample_index=idx,
            generated_at_utc=string(Dates.now(Dates.UTC)),
            baseline_version=BASELINE_VERSION,
            baseline_source=BASELINE_SOURCE,
        )

        merged = merge(row_named, (; ri_map...))
        push!(rows, merged, cols=:union)
    end

    first_eta = rows[rows.campaign .== config.name, [:eta_1, :eta_2, :eta_3]][1, :]
    println(" -> Example η̂ sample: [$(round(first_eta.eta_1, digits=4)), $(round(first_eta.eta_2, digits=4)), $(round(first_eta.eta_3, digits=4))]")
    println(" -> Completed campaign processing\n")
end

master_csv = write_trajectory_csvs(rows; output_dir=joinpath("data", "drafts", "trajectories"))
curated_csv = write_curated_diagnostics_csv(rows; output_path=joinpath("data", "drafts", "diagnostics_curated.csv"))
structural_summary = write_structural_correlation_outputs(rows, campaigns_to_run; output_dir=joinpath("data", "outputs"))
println("Pipeline verification complete. Wrote trajectory outputs via $(master_csv).")
println("Curated diagnostics source updated at $(curated_csv).")
println("Structural correlation artifacts updated for $(nrow(structural_summary)) campaign(s) under data/outputs/.")