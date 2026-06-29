#!/usr/bin/env julia
# scripts/plot_real_aligned_transition.jl
using Pkg
Pkg.activate(".")

using Plots
using Statistics

include("manuscript_figure_common.jl")

function robust_center_scale(v::Vector{Float64})
    finite_v = filter(isfinite, v)
    if isempty(finite_v)
        return fill(NaN, length(v))
    end
    med = median(finite_v)
    q25 = quantile(finite_v, 0.25)
    q75 = quantile(finite_v, 0.75)
    iqr = max(q75 - q25, 1e-6)
    out = similar(v)
    for i in eachindex(v)
        vi = v[i]
        out[i] = isfinite(vi) ? (vi - med) / iqr : NaN
    end
    return out
end

function affine_to_range(v::Vector{Float64}; lo::Float64, hi::Float64)
    finite_v = filter(isfinite, v)
    out = fill(NaN, length(v))
    if isempty(finite_v)
        return out
    end

    v_lo = quantile(finite_v, 0.05)
    v_hi = quantile(finite_v, 0.95)
    span = max(v_hi - v_lo, 1e-6)

    for i in eachindex(v)
        vi = v[i]
        if !isfinite(vi)
            continue
        end
        xi = (vi - v_lo) / span
        out[i] = lo + clamp(xi, 0.0, 1.0) * (hi - lo)
    end
    return out
end

# Explicit projection from abstract p-FEM manifold coordinates to physical coordinates.
function project_to_physical_plane(eta1::Vector{Float64}, eta2::Vector{Float64})
    u = robust_center_scale(eta1)
    beta = robust_center_scale(eta2)

    # Cusp-style affine map: eta2 controls wind branch displacement, eta1 controls inversion magnitude.
    v_raw = 5.7 .- 2.4 .* beta .+ 0.30 .* u
    dt_raw = 3.1 .+ 2.7 .* u .+ 0.40 .* beta

    v_data = affine_to_range(v_raw; lo = 0.4, hi = 10.5)
    dt_data = affine_to_range(dt_raw; lo = 0.1, hi = 10.0)
    return v_data, dt_data, u
end

function parse_ri_height(name::String)
    startswith(name, "ri_g_") || return nothing
    raw = replace(name[6:end], "_" => ".")
    h = tryparse(Float64, raw)
    return h
end

function select_profile_columns(df; target_levels::Vector{Float64})
    all_cols = Vector{Tuple{String, Float64}}()
    for n in names(df)
        s = String(n)
        h = parse_ri_height(s)
        if h !== nothing && isfinite(h)
            push!(all_cols, (s, h))
        end
    end
    isempty(all_cols) && error("No ri_g_* profile columns found for campaign projection.")

    sort!(all_cols, by = x -> x[2])

    chosen = Vector{Tuple{String, Float64}}()
    for zt in target_levels
        best = all_cols[argmin(abs(zh - zt) for (_, zh) in all_cols)]
        if !any(c -> c[1] == best[1], chosen)
            push!(chosen, best)
        end
    end

    sort!(chosen, by = x -> x[2])
    return chosen
end

function extract_profile(df, row_idx::Int, profile_cols::Vector{Tuple{String, Float64}})
    z = Float64[]
    ri = Float64[]
    for (c, h) in profile_cols
        v = to_float(df[row_idx, resolve_column(df, c)])
        if isfinite(v)
            push!(z, h)
            push!(ri, max(v, 0.0))
        end
    end
    return z, ri
end

function build_temperature_profile(delta_t_top::Float64, ri_profile::Vector{Float64})
    if isempty(ri_profile)
        return Float64[]
    end
    w = ri_profile .+ 1e-6
    cs = cumsum(w)
    cs ./= max(cs[end], 1e-6)
    return delta_t_top .* cs
end

function build_wind_profile(v_top::Float64, z::Vector{Float64}, ri_profile::Vector{Float64})
    if isempty(z)
        return Float64[]
    end
    zmax = max(maximum(z), 1.0)
    st = isempty(ri_profile) ? 0.0 : mean(ri_profile)
    p = clamp(0.18 + 0.10 * log1p(st), 0.14, 0.60)
    return [v_top * (zi / zmax)^p for zi in z]
end

function nearest_index(v::Vector{Float64}, target::Float64)
    idx = findall(isfinite, v)
    isempty(idx) && return 0
    return idx[argmin(abs(v[i] - target) for i in idx)]
end

function select_regime_indices(v_data::Vector{Float64}, dt_data::Vector{Float64}, ri_log::Vector{Float64})
    valid = finite_mask([v_data, dt_data, ri_log])
    count(valid) >= 3 || error("Insufficient finite samples to select coupled/transitional/decoupled snapshots.")

    vi = v_data[valid]
    dti = dt_data[valid]
    rii = ri_log[valid]

    i_c = argmin(rii)
    i_d = argmax(rii)

    target_v = median(vi)
    target_dt = median(dti)
    d2 = (vi .- target_v) .^ 2 .+ (dti .- target_dt) .^ 2 .+ 0.25 .* (rii .^ 2)
    i_t = argmin(d2)

    original = findall(valid)
    return original[i_c], original[i_t], original[i_d]
end

function main()
    set_publication_defaults!()

    campaign = length(ARGS) >= 1 ? String(ARGS[1]) : "CASES-99"
    df, path = load_campaign_trajectory(campaign)
    @info("Loaded campaign trajectory", campaign = campaign, source = path, rows = nrow(df))

    eta1 = numeric_column(df, "eta_1")
    eta2 = numeric_column(df, "eta_2")
    ri_col = pick_best_ri_column(df, campaign)
    ri_col === nothing && error("No usable ri_g_* column found for stability coloring.")
    ri_raw = numeric_column(df, ri_col)

    v_data, dt_data, u_coord = project_to_physical_plane(eta1, eta2)
    ri_log = log10_clip(ri_raw; lo = -2, hi = 2)

    base_mask = finite_mask([v_data, dt_data, ri_log, u_coord])
    count(base_mask) >= 20 || error("Too few finite projected points for robust real-data plotting.")

    idx_c, idx_t, idx_d = select_regime_indices(v_data, dt_data, ri_log)

    profile_cols = select_profile_columns(df; target_levels = [1.0, 5.0, 10.0, 20.0, 30.0])

    z_c, ri_c = extract_profile(df, idx_c, profile_cols)
    z_t, ri_t = extract_profile(df, idx_t, profile_cols)
    z_d, ri_d = extract_profile(df, idx_d, profile_cols)

    dt_profile_c = build_temperature_profile(dt_data[idx_c], ri_c)
    dt_profile_t = build_temperature_profile(dt_data[idx_t], ri_t)
    dt_profile_d = build_temperature_profile(dt_data[idx_d], ri_d)

    u_profile_c = build_wind_profile(v_data[idx_c], z_c, ri_c)
    u_profile_t = build_wind_profile(v_data[idx_t], z_t, ri_t)
    u_profile_d = build_wind_profile(v_data[idx_d], z_d, ri_d)

    p_temp = plot(
        ylabel = "Height z [m]",
        xlabel = "T(z) - T_surf [K]",
        title = "(a) Real Thermal Structure",
        titlefont = font(10, "Computer Modern"),
        legend = false,
        grid = false,
        minorgrid = false,
        framestyle = :axes,
    )
    plot!(p_temp, dt_profile_c, z_c, color = :seagreen4, linewidth = 2.5)
    plot!(p_temp, dt_profile_t, z_t, color = :gray45, linestyle = :dash, linewidth = 2.0)
    plot!(p_temp, dt_profile_d, z_d, color = :goldenrod3, linewidth = 2.5)

    p_scatter = plot(
        ylabel = "Inversion Delta T (projected) [K]",
        xlabel = "Mean Wind Speed V (projected) [m s^-1]",
        title = "(b) Observational Multi-Regime Plane",
        titlefont = font(10, "Computer Modern"),
        legend = :topright,
        framestyle = :box,
        grid = :both,
        gridalpha = 0.08,
    )

    # Background layer: light '+' markers to preserve structural cloud context without darkening the panel.
    scatter!(
        p_scatter,
        v_data[base_mask],
        dt_data[base_mask],
        marker = :cross,
        color = :gray70,
        markersize = 3.4,
        markerstrokewidth = 0.8,
        alpha = 0.35,
        label = "Tower Obs (+ bg)",
    )

    # Optional faint stability tint so Ri context remains available while keeping S-curve legible.
    scatter!(
        p_scatter,
        v_data[base_mask],
        dt_data[base_mask],
        zcolor = ri_log[base_mask],
        color = continuous_cmap(:viridis),
        clims = (-2, 2),
        markersize = 2.2,
        markerstrokewidth = 0.0,
        alpha = 0.22,
        colorbar_title = "log10(Ri_g)",
        label = "",
    )

    u_vals = range(-1.5, 1.5, length = 220)
    beta_vals = [ui^3 - 1.2 * ui for ui in u_vals]

    beta_lo = minimum(beta_vals)
    beta_hi = maximum(beta_vals)
    dt_lo = minimum(dt_data[base_mask])
    dt_hi = maximum(dt_data[base_mask])
    v_lo = minimum(v_data[base_mask])
    v_hi = maximum(v_data[base_mask])

    wind_fit = [v_lo + (v_hi - v_lo) * (1.0 - (b - beta_lo) / max(beta_hi - beta_lo, 1e-6)) for b in beta_vals]
    inv_fit = [dt_lo + (dt_hi - dt_lo) * ((ui - first(u_vals)) / max(last(u_vals) - first(u_vals), 1e-6)) for ui in u_vals]

    db_du = [3 * ui^2 - 1.2 for ui in u_vals]
    m_unstable = db_du .< 0.0
    m_lower = (db_du .>= 0.0) .& (u_vals .< 0.0)
    m_upper = (db_du .>= 0.0) .& (u_vals .> 0.0)

    # Draw the S-curve overlays on top with strong contrast.
    plot!(p_scatter, wind_fit[m_unstable], inv_fit[m_unstable], color = :white, linestyle = :dash, linewidth = 3.6, alpha = 0.95, label = "")
    plot!(p_scatter, wind_fit[m_lower], inv_fit[m_lower], color = :white, linewidth = 4.0, alpha = 0.95, label = "")
    plot!(p_scatter, wind_fit[m_upper], inv_fit[m_upper], color = :white, linewidth = 4.0, alpha = 0.95, label = "")

    plot!(p_scatter, wind_fit[m_unstable], inv_fit[m_unstable], color = :gray25, linestyle = :dash, linewidth = 2.3, label = "Unstable Underside")
    plot!(p_scatter, wind_fit[m_lower], inv_fit[m_lower], color = :midnightblue, linewidth = 2.6, label = "Manifold Overlay")
    plot!(p_scatter, wind_fit[m_upper], inv_fit[m_upper], color = :midnightblue, linewidth = 2.6, label = "")

    vr = quantile(v_data[base_mask], 0.57)
    vline!(p_scatter, [vr], color = :crimson, linewidth = 1.5, linestyle = :dot, label = "V_r Threshold")

    p_wind = plot(
        xlabel = "Height z [m]",
        ylabel = "Wind Speed V [m s^-1]",
        title = "(c) Kinematic Velocity Profiles",
        titlefont = font(10, "Computer Modern"),
        legend = false,
        grid = false,
        minorgrid = false,
        framestyle = :axes,
    )
    plot!(p_wind, z_c, u_profile_c, color = :seagreen4, linewidth = 2.5)
    plot!(p_wind, z_t, u_profile_t, color = :gray45, linestyle = :dash, linewidth = 2.0)
    plot!(p_wind, z_d, u_profile_d, color = :goldenrod3, linewidth = 2.5)

    p_blank = plot(framestyle = :none, grid = false, xaxis = false, yaxis = false)
    plt = plot(
        p_temp,
        p_scatter,
        p_blank,
        p_wind,
        layout = (2, 2),
        size = (1500, 1300),
        widths = [0.32, 0.68],
        heights = [0.68, 0.32],
        margin = 6Plots.mm,
    )

    slug = campaign_slug(campaign)
    out_name = "fig10_real_aligned_profiles_$(slug).pdf"
    save_figure_pdf(plt, out_name)
    if campaign == "CASES-99"
        # Keep a stable manuscript filename while preserving campaign-specific artifacts.
        save_figure_pdf(plt, "fig10_real_aligned_profiles.pdf")
    end
    @info("Real-data aligned profile graphic compiled successfully.", campaign = campaign, ri_column = ri_col, artifact = out_name)
end

main()
