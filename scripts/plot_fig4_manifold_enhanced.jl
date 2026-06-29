#!/usr/bin/env julia
# scripts/plot_fig4_manifold_enhanced.jl
# Improved aesthetics: better lighting, fold emphasis, adaptive surfaces, optional density contours
using Pkg
Pkg.activate(".")

using Plots
using Statistics

include("manuscript_figure_common.jl")

const CAMERA_BY_CAMPAIGN = Dict(
    "CASES-99" => (32, 20),
    "FLOSS" => (40, 24),
    "BLLAST" => (28, 18),
    "GABLS3" => (52, 26),
)

camera_for_campaign(campaign::String) = get(CAMERA_BY_CAMPAIGN, campaign, (35, 22))

Base.@kwdef struct RenderStyle
    point_small::Float64 = 7.2
    point_med::Float64 = 5.2
    point_large::Float64 = 3.5
    point_alpha_small::Float64 = 0.92
    point_alpha_dense::Float64 = 0.80
    shadow_alpha::Float64 = 0.025
    surf_highlight_alpha::Float64 = 0.015
    surf_hi_alpha::Float64 = 0.042
    surf_lo_alpha::Float64 = 0.036
    fold_glow_width::Float64 = 3.2
    fold_main_width::Float64 = 2.25
    fold_glow_alpha::Float64 = 0.24
    fold_main_alpha::Float64 = 0.95
    trajectory_alpha::Float64 = 0.56
    trajectory_width::Float64 = 1.8
end

function point_style(npts::Int, style::RenderStyle)
    if npts <= 250
        return style.point_small, style.point_alpha_small
    elseif npts <= 1500
        return style.point_med, style.point_alpha_dense
    end
    return style.point_large, style.point_alpha_dense
end

function plot_fold_curves!(
    p,
    xf::AbstractVector{<:Real},
    yf_up::AbstractVector{<:Real},
    yf_dn::AbstractVector{<:Real},
    zf_up::AbstractVector{<:Real},
    zf_dn::AbstractVector{<:Real},
    zshadow::Float64,
    style::RenderStyle,
)
    plot!(p, xf, yf_up, zf_up, color=:midnightblue, linewidth=style.fold_glow_width, alpha=style.fold_glow_alpha, label="")
    plot!(p, xf, yf_dn, zf_dn, color=:midnightblue, linewidth=style.fold_glow_width, alpha=style.fold_glow_alpha, label="")

    plot!(p, xf, yf_up, zf_up, color=:mediumblue, linewidth=style.fold_main_width, alpha=style.fold_main_alpha, label="")
    plot!(p, xf, yf_dn, zf_dn, color=:mediumblue, linewidth=style.fold_main_width, alpha=style.fold_main_alpha, label="")

    plot!(p, xf, yf_up, fill(zshadow, length(xf)), color=:gray35, linewidth=1.1, alpha=0.10, linestyle=:dash, label="")
    plot!(p, xf, yf_dn, fill(zshadow, length(xf)), color=:gray35, linewidth=1.1, alpha=0.10, linestyle=:dash, label="")
end

"""
    build_panel_enhanced(campaign, panel_label; show_density=false, surface_quality=:medium)

Enhanced 3D manifold panel with improved aesthetics:
- Better fold curve visibility (thicker, higher contrast)
- Improved surface lighting and transparency
- Optional density contours for stratification
- Adaptive mesh resolution
"""
function build_panel_enhanced(
    campaign::String,
    panel_label::String;
    show_density::Bool=false,
    surface_quality::Symbol=:medium,
)
    style = RenderStyle()
    df, _ = load_campaign_trajectory(campaign)

    eta1 = numeric_column(df, "eta_1")
    eta2 = numeric_column(df, "eta_2")
    eta3 = numeric_column(df, "eta_3")

    ri_col = pick_best_ri_column(df, campaign)
    ri_vals = ri_col === nothing ? fill(NaN, nrow(df)) : numeric_column(df, ri_col)
    ri_log = log10_clip(ri_vals; lo=-2, hi=2)

    mask = finite_mask([eta1, eta2, eta3])
    x = eta1[mask]
    y = eta2[mask]
    z = eta3[mask]
    c_raw = ri_log[mask]
    t_raw = numeric_column(df, "time_value")
    t = t_raw[mask]

    c_fill = begin
        finite_vals = filter(isfinite, c_raw)
        isempty(finite_vals) ? 0.0 : median(finite_vals)
    end
    c = [isfinite(v) ? v : c_fill for v in c_raw]

    fit = cusp_fit_scales(x, y, c_raw; lo=-1.0, hi=1.0)

    npts = length(x)
    point_size, point_alpha = point_style(npts, style)

    zmin = minimum(z)
    zmax = maximum(z)
    zspan = max(zmax - zmin, 1e-6)
    zshadow = zmin - 0.08 * zspan

    # ═══════════════════════════════════════════════════════════════════════
    # MAIN SCATTER PLOT with enhanced styling
    # ═══════════════════════════════════════════════════════════════════════
    p = scatter(
        x,
        y,
        zcolor=c,
        z=z,
        # Enhanced marker aesthetics
        markerstrokewidth=0.3,
        markerstrokealpha=0.40,
        markersize=point_size,
        markeralpha=point_alpha,
        # Print-friendly perceptual map.
        color=continuous_cmap(:viridis),
        clims=(-2, 2),
        colorbar_title="log10(Ri_g)",
        colorbar_tickfontsize=8,
        xlabel="eta_1",
        ylabel="eta_2",
        zlabel="eta_3",
        title=panel_title(panel_label, campaign),
        titlefont=font(12, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
        legend=false,
        aspect_ratio=:auto,
        camera=camera_for_campaign(campaign),
        widen=true,
        xguidefontsize=10,
        yguidefontsize=10,
        zguidefontsize=10,
        xtickfontsize=8,
        ytickfontsize=8,
        ztickfontsize=8,
        guidefontrotation=12,
        left_margin=8Plots.mm,
        right_margin=8Plots.mm,
        top_margin=6Plots.mm,
        bottom_margin=8Plots.mm,
    )

    # ═══════════════════════════════════════════════════════════════════════
    # SHADOW LAYER (very subtle)
    # ═══════════════════════════════════════════════════════════════════════
    scatter!(
        p,
        x,
        y,
        z=fill(zshadow, npts),
        markercolor=:gray40,
        markersize=max(point_size - 1.2, 1.5),
        markerstrokewidth=0,
        markeralpha=style.shadow_alpha,
        label="",
    )

    if !isempty(x)
        zmed = median(z)
        zspread = max(quantile(abs.(z .- zmed), 0.85), 1e-6)

        # ═══════════════════════════════════════════════════════════════════════
        # CUSP SURFACE MESH with improved lighting
        # ═══════════════════════════════════════════════════════════════════════

        # Adaptive resolution based on surface_quality
        α_len, u_len = if surface_quality == :high
            (100, 65)
        elseif surface_quality == :medium
            (65, 45)
        else
            (45, 30)
        end

        αr = range(-2.2, 1.2, length=α_len)
        ur_pos = range(0.0, 1.25, length=u_len)
        ur_neg = range(-1.25, 0.0, length=u_len)

        xsurf_pos = [fit.μ1 + fit.s1 * α for u in ur_pos, α in αr]
        ysurf_pos = [fit.μ2 + fit.s2 * (-u^3 - α * u) for u in ur_pos, α in αr]
        zsurf_pos = [zmed + zspread * u for u in ur_pos, α in αr]
        asurf_pos = [α for u in ur_pos, α in αr]

        xsurf_neg = [fit.μ1 + fit.s1 * α for u in ur_neg, α in αr]
        ysurf_neg = [fit.μ2 + fit.s2 * (-u^3 - α * u) for u in ur_neg, α in αr]
        zsurf_neg = [zmed + zspread * u for u in ur_neg, α in αr]
        asurf_neg = [α for u in ur_neg, α in αr]

        # Lighting cue: white highlight pass before gray surfaces.
        surface!(
            p,
            xsurf_pos,
            ysurf_pos,
            zsurf_pos,
            alpha=style.surf_highlight_alpha,
            color=:white,
            linewidth=0,
            linealpha=0.0,
            label="",
        )
        surface!(
            p,
            xsurf_neg,
            ysurf_neg,
            zsurf_neg,
            alpha=style.surf_highlight_alpha,
            color=:white,
            linewidth=0,
            linealpha=0.0,
            label="",
        )

        # Upper leaf: slightly more opaque with warmer tone
        surface!(
            p,
            xsurf_pos,
            ysurf_pos,
            zsurf_pos,
            fill_z=asurf_pos,
            alpha=style.surf_hi_alpha,
            color=:greys,
            linewidth=0,
            linealpha=0.0,
            label="",
        )

        # Lower leaf: slightly cooler tone
        surface!(
            p,
            xsurf_neg,
            ysurf_neg,
            zsurf_neg,
            fill_z=asurf_neg,
            alpha=style.surf_lo_alpha,
            color=:greys,
            linewidth=0,
            linealpha=0.0,
            label="",
        )

        # ═══════════════════════════════════════════════════════════════════════
        # FOLD CURVES: PRIMARY GEOMETRIC FEATURE (enhanced prominence)
        # ═══════════════════════════════════════════════════════════════════════
        αf = range(-2.0, 0.0, length=150)
        βf = sqrt.((-4.0 / 27.0) .* (αf .^ 3))
        xf = fit.μ1 .+ fit.s1 .* αf
        yf_up = fit.μ2 .+ fit.s2 .* βf
        yf_dn = fit.μ2 .- fit.s2 .* βf
        # Fold heights embedded in the manifold using cusp branch coordinate u.
        uf = sqrt.(max.(0.0, -αf ./ 3.0))
        zf_up = zmed .+ zspread .* uf
        zf_dn = zmed .- zspread .* uf

        plot_fold_curves!(p, xf, yf_up, yf_dn, zf_up, zf_dn, zshadow, style)

        # Time-ordered manifold trajectory overlay.
        tmask = isfinite.(t)
        if count(tmask) > 20
            ord = sortperm(t[tmask])
            xt = x[tmask][ord]
            yt = y[tmask][ord]
            zt = z[tmask][ord]
            step = max(1, Int(floor(length(xt) / 2000)))
            plot!(
                p,
                xt[1:step:end],
                yt[1:step:end],
                zt[1:step:end],
                color=:black,
                linewidth=style.trajectory_width,
                alpha=style.trajectory_alpha,
                label="",
            )
        end

        # ═══════════════════════════════════════════════════════════════════════
        # OPTIONAL: DENSITY CONTOURS on z=zmed plane
        # ═══════════════════════════════════════════════════════════════════════
        if show_density && npts > 50
            try
                # Bin data into grid for density
                x_bins = range(minimum(x), maximum(x), length=18)
                y_bins = range(minimum(y), maximum(y), length=18)
                density = zeros(length(x_bins)-1, length(y_bins)-1)

                for i in 1:length(x_bins)-1
                    for j in 1:length(y_bins)-1
                        count = sum((x_bins[i] .<= x .< x_bins[i+1]) .&
                                   (y_bins[j] .<= y .< y_bins[j+1]))
                        density[i, j] = count
                    end
                end

                # Overlay contour (subtle)
                contour!(
                    p,
                    (x_bins[1:end-1] .+ x_bins[2:end]) / 2,
                    (y_bins[1:end-1] .+ y_bins[2:end]) / 2,
                    density,
                    z=fill(zmed, size(density, 1), size(density, 2)),
                    levels=4,
                    color=:grays,
                    alpha=0.08,
                    linewidth=0.6,
                    label="",
                )
            catch
                # Silently skip if density fails
            end
        end

        # ═══════════════════════════════════════════════════════════════════════
        # ANNOTATION: Quantitative regime indicator
        # ═══════════════════════════════════════════════════════════════════════
        if isfinite(fit.inside_frac)
            annotate!(
                p,
                quantile(x, 0.08),
                quantile(y, 0.92),
                quantile(z, 0.95),
                text(
                    "Inside cusp:\n$(round(100 * fit.inside_frac; digits=0))%",
                    7.5,
                    :left,
                    :top,
                    :black,
                ),
            )
        end
    end

    # ═══════════════════════════════════════════════════════════════════════
    # FINAL PASS: repaint observations so they're never washed out
    # ═══════════════════════════════════════════════════════════════════════
    scatter!(
        p,
        x,
        y,
        z=z,
        zcolor=c,
        color=continuous_cmap(:viridis),
        clims=(-2, 2),
        markersize=point_size + 0.1,
        markerstrokewidth=0.20,
        markerstrokealpha=0.25,
        markeralpha=0.87,
        label="",
    )

    return p
end

"""
    build_panel_2d_projection(campaign, panel_label)

Alternative: 2D manifold projection with improved density visualization
"""
function build_panel_2d_projection(campaign::String, panel_label::String)
    df, _ = load_campaign_trajectory(campaign)

    eta1 = numeric_column(df, "eta_1")
    eta2 = numeric_column(df, "eta_2")

    ri_col = pick_best_ri_column(df, campaign)
    ri_vals = ri_col === nothing ? fill(NaN, nrow(df)) : numeric_column(df, ri_col)
    ri_log = log10_clip(ri_vals; lo=-2, hi=2)

    mask = finite_mask([eta1, eta2])
    x = eta1[mask]
    y = eta2[mask]
    c = ri_log[mask]

    fit = cusp_fit_scales(x, y, c; lo=-1.0, hi=1.0)

    p = scatter(
        x,
        y,
        zcolor=c,
        color=continuous_cmap(:viridis),
        clims=(-2, 2),
        markersize=6.5,
        markerstrokealpha=0.35,
        markerstrokewidth=0.3,
        markeralpha=0.85,
        xlabel="eta_1",
        ylabel="eta_2",
        title=panel_title(panel_label, campaign),
        titlefont=font(11, "Computer Modern", :black),
        legend=false,
        colorbar_title="log10(Ri_g)",
        margin=6Plots.mm,
    )

    # Overlay fold curves
    αf = range(-2.0, 0.0, length=120)
    βf = sqrt.((-4.0 / 27.0) .* (αf .^ 3))
    xf = fit.μ1 .+ fit.s1 .* αf
    yf_up = fit.μ2 .+ fit.s2 .* βf
    yf_dn = fit.μ2 .- fit.s2 .* βf

    plot!(p, xf, yf_up, color=:mediumblue, linewidth=2.2, alpha=0.90, label="")
    plot!(p, xf, yf_dn, color=:mediumblue, linewidth=2.2, alpha=0.90, label="")

    return p
end

function save_enhanced_version()
    set_publication_defaults!()

    panels = [
        build_panel_enhanced("CASES-99", "(a)"; surface_quality=:medium),
        build_panel_enhanced("FLOSS", "(b)"; surface_quality=:medium),
        build_panel_enhanced("BLLAST", "(c)"; surface_quality=:medium),
        build_panel_enhanced("GABLS3", "(d)"; surface_quality=:medium),
    ]

    plt = plot(
        panels...,
        layout=(2, 2),
        size=(2400, 1800),
        margin=10Plots.mm,
    )

    save_figure_pdf(plt, "fig4_manifold_enhanced.pdf")
    # Also write the manuscript-standard filename so Fig. 4 picks up the enhanced rendering.
    save_figure_pdf(plt, "fig4_manifold.pdf")
    @info "Saved enhanced 3D version"
end

function save_2d_projection_version()
    set_publication_defaults!()

    panels = [
        build_panel_2d_projection("CASES-99", "(a)"),
        build_panel_2d_projection("FLOSS", "(b)"),
        build_panel_2d_projection("BLLAST", "(c)"),
        build_panel_2d_projection("GABLS3", "(d)"),
    ]

    plt = plot(
        panels...,
        layout=(2, 2),
        size=(2000, 1600),
        margin=8Plots.mm,
    )

    save_figure_pdf(plt, "fig4_manifold_2d_projection.pdf")
    @info "Saved 2D projection version"
end

function main()
    @info "Building enhanced 3D manifold figure..."
    save_enhanced_version()

    @info "Building 2D projection figure..."
    save_2d_projection_version()
end

main()
