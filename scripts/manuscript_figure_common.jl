#!/usr/bin/env julia
# scripts/manuscript_figure_common.jl
using CSV
using DataFrames
using LinearAlgebra
using Plots
using Printf
using Statistics

const CAMPAIGN_SLUG = Dict(
    "CASES-99" => "cases_99",
    "FLOSS" => "floss",
    "BLLAST" => "bllast",
    "GABLS3" => "gabls3",
)

const CAMPAIGN_ORDER = ["CASES-99", "FLOSS", "BLLAST", "GABLS3"]

function resolve_column(df::DataFrame, col::AbstractString)
    for n in names(df)
        if String(n) == String(col)
            return n
        end
    end
    return nothing
end

function has_column(df::DataFrame, col::AbstractString)
    return resolve_column(df, col) !== nothing
end

function project_root()
    return normpath(joinpath(@__DIR__, ".."))
end

function outputs_dir()
    return joinpath(project_root(), "data", "outputs")
end

function figures_dir()
    return joinpath(project_root(), "manuscript", "figures")
end

function ensure_figures_dir!()
    mkpath(figures_dir())
end

function set_publication_defaults!()
    gr()
    default(
        dpi = 300,
        grid = true,
        minorgrid = false,
        framestyle = :box,
        gridalpha = 0.10,
        gridlinewidth = 0.35,
        foreground_color_subplot = :black,
        linewidth = 1.8,
        legendfontsize = 8,
        guidefontsize = 10,
        tickfontsize = 8,
        titlefontsize = 10,
        titlefont = font(10, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
        foreground_color_legend = :black,
        legend_background_color = :white,
        markerstrokewidth = 0.0,
        fontfamily = "Computer Modern",
    )
end

function panel_title(tag::AbstractString, label::AbstractString)
    return "$(tag) $(label)"
end

function continuous_cmap(name::Symbol = :viridis)
    return cgrad(name)
end

function campaign_slug(campaign::AbstractString)
    return get(CAMPAIGN_SLUG, String(campaign), lowercase(replace(String(campaign), r"[^A-Za-z0-9]+" => "_")))
end

function load_csv_first(paths::Vector{String})
    for path in paths
        if isfile(path)
            df = CSV.read(path, DataFrame)
            @info("Loaded CSV", path = path, rows = nrow(df), cols = ncol(df))
            return df, path
        end
    end
    error("No readable CSV found. Tried: $(join(paths, ", "))")
end

function load_campaign_trajectory(campaign::String)
    slug = campaign_slug(campaign)
    out_paths = [
        joinpath(outputs_dir(), "regime_trajectories_$(slug).csv"),
        joinpath(outputs_dir(), "regime_trajectories_all.csv"),
    ]
    return load_csv_first(out_paths)
end

function load_transition_panel_b(campaign::String)
    slug = campaign_slug(campaign)
    out_paths = [
        joinpath(outputs_dir(), "transition_panel_b_$(slug).csv"),
        joinpath(outputs_dir(), "transition_panel_b_all.csv"),
        joinpath(outputs_dir(), "stage5_bifurcation_branches_$(slug).csv"),
    ]
    return load_csv_first(out_paths)
end

function load_transition_panel_c(campaign::String)
    slug = campaign_slug(campaign)
    out_paths = [
        joinpath(outputs_dir(), "transition_panel_c_$(slug).csv"),
        joinpath(outputs_dir(), "transition_panel_c_all.csv"),
    ]
    return load_csv_first(out_paths)
end

function pick_ri_low_column(df::DataFrame, campaign::String)
    by_campaign = Dict(
        "BLLAST" => ["ri_g_2_0", "ri_g_1_5", "ri_g_1_0", "ri_g_5_0"],
        "CASES-99" => ["ri_g_5_0", "ri_g_4_0", "ri_g_2_5", "ri_g_2_0"],
        "FLOSS" => ["ri_g_1_0", "ri_g_1_5", "ri_g_2_0", "ri_g_0_5"],
        "GABLS3" => ["ri_g_10_0", "ri_g_5_0", "ri_g_2_0", "ri_g_1_0"],
    )
    candidates = get(by_campaign, campaign, String[])
    all_ri_cols = [String(c) for c in names(df) if startswith(String(c), "ri_g_")]

    for c in candidates
        if c in all_ri_cols
            return c
        end
    end
    return isempty(all_ri_cols) ? nothing : all_ri_cols[1]
end

function pick_best_ri_column(df::DataFrame, campaign::String)
    preferred = String[]
    low = pick_ri_low_column(df, campaign)
    if low !== nothing
        push!(preferred, low)
    end
    append!(preferred, [String(c) for c in names(df) if startswith(String(c), "ri_g_") && String(c) != low])

    best_col = nothing
    best_score = -1
    for c in preferred
        vals = numeric_column(df, c)
        score = count(v -> isfinite(v) && v > 0.0, vals)
        if score > best_score
            best_score = score
            best_col = c
        end
    end
    return best_col
end

function cusp_fit_scales(
    eta1::Vector{Float64},
    eta2::Vector{Float64},
    ri_log::Vector{Float64};
    lo::Float64 = -2.0,
    hi::Float64 = 2.0,
)
    base_mask = finite_mask([eta1, eta2])
    a0 = eta1[base_mask]
    b0 = eta2[base_mask]
    if isempty(a0)
        return (μ1 = 0.0, μ2 = 0.0, s1 = 1.0, s2 = 1.0, inside_frac = NaN)
    end

    μ1 = 0.0
    μ2 = 0.0
    base_s1 = max(quantile(abs.(a0 .- μ1), 0.85), 1e-6)
    base_s2 = max(quantile(abs.(b0 .- μ2), 0.85), 1e-6)

    tmask = base_mask .& isfinite.(ri_log) .& (ri_log .>= lo) .& (ri_log .<= hi)
    if count(tmask) < 40
        return (μ1 = μ1, μ2 = μ2, s1 = base_s1, s2 = base_s2, inside_frac = NaN)
    end

    a = eta1[tmask]
    b = eta2[tmask]
    best_score = -Inf
    best_s1 = base_s1
    best_s2 = base_s2
    best_inside = NaN

    for k1 in range(0.2, 2.2, length = 60), k2 in range(0.2, 2.8, length = 60)
        s1 = base_s1 * k1
        s2 = base_s2 * k2
        α = (a .- μ1) ./ s1
        β = (b .- μ2) ./ s2
        Δ = 4.0 .* (α .^ 3) .+ 27.0 .* (β .^ 2)
        inside = mean(Δ .<= 0.0)
        penalty = 0.08 * (abs(log(k1)) + abs(log(k2)))
        score = inside - penalty
        if score > best_score
            best_score = score
            best_s1 = s1
            best_s2 = s2
            best_inside = inside
        end
    end

    return (μ1 = μ1, μ2 = μ2, s1 = best_s1, s2 = best_s2, inside_frac = best_inside)
end

function cusp_fit_rotated_scales(
    eta1::Vector{Float64},
    eta2::Vector{Float64},
    ri_log::Vector{Float64};
    lo::Float64 = -1.0,
    hi::Float64 = 1.0,
    s1_range::Tuple{Float64, Float64} = (0.5, 12.0),
    s2_range::Tuple{Float64, Float64} = (0.5, 50.0),
    theta_range::Tuple{Float64, Float64} = (-pi / 4, pi / 4),
    s1_steps::Int = 24,
    s2_steps::Int = 24,
    theta_steps::Int = 21,
    max_points::Int = 6000,
)
    mask = isfinite.(eta1) .& isfinite.(eta2) .& isfinite.(ri_log) .& (ri_log .>= lo) .& (ri_log .<= hi)
    if count(mask) < 40
        return (μ1 = 0.0, μ2 = 0.0, s1 = 1.0, s2 = 1.0, theta = 0.0, inside_frac = NaN, n = 0)
    end

    a = eta1[mask]
    b = eta2[mask]
    n_all = length(a)
    if n_all > max_points
        stride = ceil(Int, n_all / max_points)
        idx = 1:stride:n_all
        a = a[idx]
        b = b[idx]
    end

    best_frac = -Inf
    best_s1 = 1.0
    best_s2 = 1.0
    best_theta = 0.0

    s1_grid = range(s1_range[1], s1_range[2], length = s1_steps)
    s2_grid = range(s2_range[1], s2_range[2], length = s2_steps)
    theta_grid = range(theta_range[1], theta_range[2], length = theta_steps)

    for s1 in s1_grid, s2 in s2_grid, θ in theta_grid
        cs = cos(θ)
        sn = sin(θ)
        α = (a ./ s1) .* cs .+ (b ./ s2) .* sn
        β = -((a ./ s1) .* sn) .+ (b ./ s2) .* cs
        Δ = 4.0 .* (α .^ 3) .+ 27.0 .* (β .^ 2)
        frac = mean(Δ .<= 0.0)
        if isfinite(frac) && frac > best_frac
            best_frac = frac
            best_s1 = s1
            best_s2 = s2
            best_theta = θ
        end
    end

    return (
        μ1 = 0.0,
        μ2 = 0.0,
        s1 = best_s1,
        s2 = best_s2,
        theta = best_theta,
        inside_frac = best_frac,
        n = length(a),
    )
end

function cusp_fit_affine_rotated_scales(
    eta1::Vector{Float64},
    eta2::Vector{Float64},
    ri_log::Vector{Float64};
    lo::Float64 = -1.0,
    hi::Float64 = 1.0,
    s1_range::Tuple{Float64, Float64} = (0.5, 12.0),
    s2_range::Tuple{Float64, Float64} = (0.5, 50.0),
    theta_range::Tuple{Float64, Float64} = (-pi / 4, pi / 4),
    s1_steps::Int = 12,
    s2_steps::Int = 12,
    theta_steps::Int = 13,
    mu_steps::Int = 7,
    max_points::Int = 5000,
)
    mask = isfinite.(eta1) .& isfinite.(eta2) .& isfinite.(ri_log) .& (ri_log .>= lo) .& (ri_log .<= hi)
    if count(mask) < 40
        return (μ1 = 0.0, μ2 = 0.0, s1 = 1.0, s2 = 1.0, theta = 0.0, inside_frac = NaN, n = 0)
    end

    a = eta1[mask]
    b = eta2[mask]
    n_all = length(a)
    if n_all > max_points
        stride = ceil(Int, n_all / max_points)
        idx = 1:stride:n_all
        a = a[idx]
        b = b[idx]
    end

    mu1_grid = range(quantile(a, 0.10), quantile(a, 0.90), length = mu_steps)
    mu2_grid = range(quantile(b, 0.10), quantile(b, 0.90), length = mu_steps)
    s1_grid = range(s1_range[1], s1_range[2], length = s1_steps)
    s2_grid = range(s2_range[1], s2_range[2], length = s2_steps)
    theta_grid = range(theta_range[1], theta_range[2], length = theta_steps)

    best_frac = -Inf
    best_mu1 = 0.0
    best_mu2 = 0.0
    best_s1 = 1.0
    best_s2 = 1.0
    best_theta = 0.0

    for μ1 in mu1_grid, μ2 in mu2_grid, s1 in s1_grid, s2 in s2_grid, θ in theta_grid
        cs = cos(θ)
        sn = sin(θ)
        α0 = (a .- μ1) ./ s1
        β0 = (b .- μ2) ./ s2
        α = α0 .* cs .+ β0 .* sn
        β = -(α0 .* sn) .+ β0 .* cs
        Δ = 4.0 .* (α .^ 3) .+ 27.0 .* (β .^ 2)
        frac = mean(Δ .<= 0.0)
        if isfinite(frac) && frac > best_frac
            best_frac = frac
            best_mu1 = μ1
            best_mu2 = μ2
            best_s1 = s1
            best_s2 = s2
            best_theta = θ
        end
    end

    return (
        μ1 = best_mu1,
        μ2 = best_mu2,
        s1 = best_s1,
        s2 = best_s2,
        theta = best_theta,
        inside_frac = best_frac,
        n = length(a),
    )
end

function estimate_neutral_translation_bounds(
    eta1::Vector{Float64},
    eta2::Vector{Float64},
    ri_log::Vector{Float64};
    neutral_band::Float64 = 0.15,
    q::Float64 = 0.95,
    min_eps::Float64 = 0.02,
    max_eps_frac::Float64 = 0.20,
)
    finite_mask0 = isfinite.(eta1) .& isfinite.(eta2)
    n_finite = count(finite_mask0)
    if n_finite == 0
        return (eps1 = min_eps, eps2 = min_eps, n = 0)
    end

    mask = finite_mask0 .& isfinite.(ri_log) .& (abs.(ri_log) .<= neutral_band)
    a = eta1[mask]
    b = eta2[mask]

    if length(a) < 20
        # Fallback: use the near-origin cloud (lowest radius in control plane)
        ia = eta1[finite_mask0]
        ib = eta2[finite_mask0]
        r2 = ia .^ 2 .+ ib .^ 2
        ord = sortperm(r2)
        k = min(length(ord), max(20, round(Int, 0.15 * length(ord))))
        idx = ord[1:k]
        a = ia[idx]
        b = ib[idx]
    end

    all_a = abs.(eta1[finite_mask0])
    all_b = abs.(eta2[finite_mask0])
    cap1 = max(min_eps, max_eps_frac * quantile(all_a, 0.90))
    cap2 = max(min_eps, max_eps_frac * quantile(all_b, 0.90))

    eps1 = min(max(quantile(abs.(a), q), min_eps), cap1)
    eps2 = min(max(quantile(abs.(b), q), min_eps), cap2)
    return (eps1 = eps1, eps2 = eps2, n = length(a))
end

function cusp_fit_bounded_affine_rotated_scales(
    eta1::Vector{Float64},
    eta2::Vector{Float64},
    ri_log::Vector{Float64};
    lo::Float64 = -1.0,
    hi::Float64 = 1.0,
    neutral_band::Float64 = 0.15,
    neutral_q::Float64 = 0.95,
    min_eps::Float64 = 0.05,
    s1_range::Tuple{Float64, Float64} = (0.5, 12.0),
    s2_range::Tuple{Float64, Float64} = (0.5, 50.0),
    theta_range::Tuple{Float64, Float64} = (-pi / 4, pi / 4),
    s1_steps::Int = 12,
    s2_steps::Int = 12,
    theta_steps::Int = 13,
    mu_steps::Int = 7,
    max_points::Int = 5000,
)
    bounds = estimate_neutral_translation_bounds(
        eta1,
        eta2,
        ri_log;
        neutral_band = neutral_band,
        q = neutral_q,
        min_eps = min_eps,
    )

    mask = isfinite.(eta1) .& isfinite.(eta2) .& isfinite.(ri_log) .& (ri_log .>= lo) .& (ri_log .<= hi)
    if count(mask) < 40
        return (
            μ1 = 0.0,
            μ2 = 0.0,
            s1 = 1.0,
            s2 = 1.0,
            theta = 0.0,
            inside_frac = NaN,
            n = 0,
            eps1 = bounds.eps1,
            eps2 = bounds.eps2,
            neutral_n = bounds.n,
        )
    end

    a = eta1[mask]
    b = eta2[mask]
    n_all = length(a)
    if n_all > max_points
        stride = ceil(Int, n_all / max_points)
        idx = 1:stride:n_all
        a = a[idx]
        b = b[idx]
    end

    mu1_grid = range(-bounds.eps1, bounds.eps1, length = mu_steps)
    mu2_grid = range(-bounds.eps2, bounds.eps2, length = mu_steps)
    s1_grid = range(s1_range[1], s1_range[2], length = s1_steps)
    s2_grid = range(s2_range[1], s2_range[2], length = s2_steps)
    theta_grid = range(theta_range[1], theta_range[2], length = theta_steps)

    best_frac = -Inf
    best_mu1 = 0.0
    best_mu2 = 0.0
    best_s1 = 1.0
    best_s2 = 1.0
    best_theta = 0.0

    for μ1 in mu1_grid, μ2 in mu2_grid, s1 in s1_grid, s2 in s2_grid, θ in theta_grid
        cs = cos(θ)
        sn = sin(θ)
        α0 = (a .- μ1) ./ s1
        β0 = (b .- μ2) ./ s2
        α = α0 .* cs .+ β0 .* sn
        β = -(α0 .* sn) .+ β0 .* cs
        Δ = 4.0 .* (α .^ 3) .+ 27.0 .* (β .^ 2)
        frac = mean(Δ .<= 0.0)
        if isfinite(frac) && frac > best_frac
            best_frac = frac
            best_mu1 = μ1
            best_mu2 = μ2
            best_s1 = s1
            best_s2 = s2
            best_theta = θ
        end
    end

    return (
        μ1 = best_mu1,
        μ2 = best_mu2,
        s1 = best_s1,
        s2 = best_s2,
        theta = best_theta,
        inside_frac = best_frac,
        n = length(a),
        eps1 = bounds.eps1,
        eps2 = bounds.eps2,
        neutral_n = bounds.n,
    )
end

function ri_mean_series(df::DataFrame)
    ri_cols = [c for c in names(df) if startswith(String(c), "ri_g_")]
    if isempty(ri_cols)
        return fill(NaN, nrow(df))
    end

    out = Vector{Float64}(undef, nrow(df))
    for i in 1:nrow(df)
        vals = Float64[]
        for c in ri_cols
            v = df[i, c]
            if v isa Number
                fv = Float64(v)
                if isfinite(fv)
                    push!(vals, fv)
                end
            end
        end
        out[i] = isempty(vals) ? NaN : mean(vals)
    end
    return out
end

function to_float(v)
    if v isa Number
        fv = Float64(v)
        return isfinite(fv) ? fv : NaN
    end
    if v isa AbstractString
        parsed = tryparse(Float64, strip(String(v)))
        if parsed !== nothing
            fv = parsed
            return isfinite(fv) ? fv : NaN
        end
    end
    return NaN
end

function numeric_column(df::DataFrame, col::AbstractString)
    colref = resolve_column(df, col)
    if colref === nothing
        return fill(NaN, nrow(df))
    end
    return [to_float(df[i, colref]) for i in 1:nrow(df)]
end

function normalize_time_minutes(time_vals::Vector{Float64}, t0::Float64)
    if !isfinite(t0)
        finite_t = filter(isfinite, time_vals)
        t0 = isempty(finite_t) ? 0.0 : median(finite_t)
    end
    return (time_vals .- t0) ./ 60.0
end

function infer_transition_time(df::DataFrame, time_col::AbstractString = "time_value")
    tcol = resolve_column(df, time_col)
    if tcol === nothing
        return NaN
    end
    tvals = numeric_column(df, time_col)

    phase_col = resolve_column(df, "phase")
    if phase_col !== nothing
        for i in 1:nrow(df)
            phase = lowercase(String(df[i, phase_col]))
            if occursin("post", phase) || occursin("break", phase)
                tv = to_float(df[i, tcol])
                if isfinite(tv)
                    return tv
                end
            end
        end
    end

    finite_t = filter(isfinite, tvals)
    return isempty(finite_t) ? NaN : median(finite_t)
end

function log10_clip(vals::Vector{Float64}; lo::Real = -2.0, hi::Real = 2.0)
    out = similar(vals)
    lo_f = Float64(lo)
    hi_f = Float64(hi)
    for i in eachindex(vals)
        v = vals[i]
        if !(isfinite(v) && v > 0)
            out[i] = NaN
            continue
        end
        lv = log10(v)
        out[i] = clamp(lv, lo_f, hi_f)
    end
    return out
end

function finite_mask(vs::Vector{Vector{Float64}})
    n = length(vs[1])
    mask = trues(n)
    for v in vs
        @assert length(v) == n
        mask .&= isfinite.(v)
    end
    return mask
end

function filter_by_mask(v::Vector{Float64}, mask::BitVector)
    return v[mask]
end

function pick_flux_proxy(df::DataFrame)
    preferred = [
        "h_s", "H_s", "sensible_heat_flux", "momentum_flux",
        "tau", "ustar", "friction_velocity", "surface_flux",
    ]
    for name in preferred
        if has_column(df, name)
            return numeric_column(df, name), "$(name) [SI units]"
        end
    end

    if has_column(df, "sv_entropy")
        return numeric_column(df, "sv_entropy"), "SV entropy proxy [-]"
    end

    return fill(NaN, nrow(df)), "Coupling proxy [-]"
end

function nearest_distance_to_curve(x::Vector{Float64}, y::Vector{Float64}, cx::Vector{Float64}, cy::Vector{Float64})
    d = fill(NaN, length(x))
    curve_mask = finite_mask([cx, cy])
    cxv = cx[curve_mask]
    cyv = cy[curve_mask]
    if isempty(cxv)
        return d
    end

    for i in eachindex(x)
        xi = x[i]
        yi = y[i]
        if !(isfinite(xi) && isfinite(yi))
            continue
        end
        min_d2 = Inf
        for j in eachindex(cxv)
            ddx = xi - cxv[j]
            ddy = yi - cyv[j]
            d2 = ddx * ddx + ddy * ddy
            if d2 < min_d2
                min_d2 = d2
            end
        end
        d[i] = sqrt(min_d2)
    end
    return d
end

function linear_fit_with_ci(x::Vector{Float64}, y::Vector{Float64})
    mask = finite_mask([x, y])
    x1 = x[mask]
    y1 = y[mask]
    n = length(x1)
    if n < 3
        return (intercept = NaN, slope = NaN, slope_ci = NaN, n = n)
    end

    X = hcat(ones(n), x1)
    β = X \ y1
    yhat = X * β
    resid = y1 - yhat

    dof = n - 2
    if dof <= 0
        return (intercept = β[1], slope = β[2], slope_ci = NaN, n = n)
    end

    s2 = sum(resid .^ 2) / dof
    covβ = s2 * inv(transpose(X) * X)
    se_slope = sqrt(max(covβ[2, 2], 0.0))
    tcrit = 1.96
    return (intercept = β[1], slope = β[2], slope_ci = tcrit * se_slope, n = n)
end

function save_figure_pdf(plt, filename::String)
    ensure_figures_dir!()
    outpath = joinpath(figures_dir(), filename)
    savefig(plt, outpath)
    @info("Saved figure", outpath = outpath)
    return outpath
end
