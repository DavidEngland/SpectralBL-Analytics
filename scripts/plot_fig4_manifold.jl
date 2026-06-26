#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using Plots
using Statistics

include("manuscript_figure_common.jl")

function build_panel(campaign::String, panel_label::String)
    df, _ = load_campaign_trajectory(campaign)

    eta1 = numeric_column(df, "eta_1")
    eta2 = numeric_column(df, "eta_2")
    eta3 = numeric_column(df, "eta_3")

    ri_col = pick_best_ri_column(df, campaign)
    ri_vals = ri_col === nothing ? fill(NaN, nrow(df)) : numeric_column(df, ri_col)
    ri_log = log10_clip(ri_vals; lo = -2, hi = 2)

    mask = finite_mask([eta1, eta2, eta3])
    x = eta1[mask]
    y = eta2[mask]
    z = eta3[mask]
    c_raw = ri_log[mask]
    c_fill = begin
        finite_vals = filter(isfinite, c_raw)
        isempty(finite_vals) ? 0.0 : median(finite_vals)
    end
    c = [isfinite(v) ? v : c_fill for v in c_raw]

    fit = cusp_fit_scales(x, y, c_raw; lo = -1.0, hi = 1.0)

    p = scatter(
        x,
        y,
        zcolor = c,
        z = z,
        markerstrokewidth = 0,
        markersize = 2.5,
        color = continuous_cmap(:viridis),
        clims = (-2, 2),
        colorbar_title = "log10(Gradient Richardson number) [-]",
        xlabel = "Neutral baseline coordinate [-]",
        ylabel = "Linear stability coordinate [-]",
        zlabel = "Spectral curvature coordinate [-]",
        title = panel_title(panel_label, campaign),
        titlefont = font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
        legend = false,
        camera = (35, 25),
    )

    if !isempty(x)
        zmed = median(z)
        zspread = max(quantile(abs.(z .- zmed), 0.85), 1e-6)

        αr = range(-2.2, 1.2, length = 65)
        ur_pos = range(0.0, 1.25, length = 45)
        ur_neg = range(-1.25, 0.0, length = 45)

        xsurf_pos = [fit.μ1 + fit.s1 * α for u in ur_pos, α in αr]
        ysurf_pos = [fit.μ2 + fit.s2 * (-u^3 - α * u) for u in ur_pos, α in αr]
        zsurf_pos = [zmed + zspread * u for u in ur_pos, α in αr]

        xsurf_neg = [fit.μ1 + fit.s1 * α for u in ur_neg, α in αr]
        ysurf_neg = [fit.μ2 + fit.s2 * (-u^3 - α * u) for u in ur_neg, α in αr]
        zsurf_neg = [zmed + zspread * u for u in ur_neg, α in αr]

        surface!(
            p,
            xsurf_pos,
            ysurf_pos,
            zsurf_pos,
            alpha = 0.18,
            color = :gray65,
            linealpha = 0.10,
            label = "",
        )
        surface!(
            p,
            xsurf_neg,
            ysurf_neg,
            zsurf_neg,
            alpha = 0.18,
            color = :gray45,
            linealpha = 0.15,
            label = "",
        )

        αf = range(-2.0, 0.0, length = 120)
        βf = sqrt.((-4.0 / 27.0) .* (αf .^ 3))
        xf = fit.μ1 .+ fit.s1 .* αf
        yf_up = fit.μ2 .+ fit.s2 .* βf
        yf_dn = fit.μ2 .- fit.s2 .* βf
        zf = fill(zmed, length(αf))
        plot!(p, xf, yf_up, zf, color = :black, linewidth = 1.4, alpha = 0.75, label = "")
        plot!(p, xf, yf_dn, zf, color = :black, linewidth = 1.4, alpha = 0.75, label = "")

        if isfinite(fit.inside_frac)
            annotate!(
                p,
                quantile(x, 0.05),
                quantile(y, 0.95),
                quantile(z, 0.95),
                text("inside cusp: $(round(100 * fit.inside_frac; digits = 1))%", 8, :left, :top, :black),
            )
        end
    end

    return p
end

function main()
    set_publication_defaults!()

    panels = [
        build_panel("CASES-99", "(a)"),
        build_panel("FLOSS", "(b)"),
        build_panel("BLLAST", "(c)"),
        build_panel("GABLS3", "(d)"),
    ]

    plt = plot(panels..., layout = (2, 2), size = (1400, 1100), margin = 8Plots.mm)
    save_figure_pdf(plt, "fig4_manifold.pdf")
end

main()
