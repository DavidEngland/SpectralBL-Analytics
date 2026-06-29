#!/usr/bin/env julia
# scripts/plot_fig4_manifold.jl
using Pkg
Pkg.activate(".")

using Plots
using Statistics

include("manuscript_figure_common.jl")

function camera_for_campaign(campaign::String)
    if campaign == "CASES-99"
        return (32, 20)
    elseif campaign == "FLOSS"
        return (40, 24)
    elseif campaign == "BLLAST"
        return (28, 18)
    elseif campaign == "GABLS3"
        return (52, 26)
    end
    return (35, 22)
end

function build_panel(campaign::String, panel_label::String)
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

    c_fill = begin
        finite_vals = filter(isfinite, c_raw)
        isempty(finite_vals) ? 0.0 : median(finite_vals)
    end
    c = [isfinite(v) ? v : c_fill for v in c_raw]

    fit = cusp_fit_scales(x, y, c_raw; lo=-1.0, hi=1.0)

    npts = length(x)
    point_size = npts <= 250 ? 7.2 : (npts <= 1500 ? 5.2 : 3.5)
    point_alpha = npts <= 250 ? 0.96 : 0.86

    zmin = minimum(z)
    zmax = maximum(z)
    zspan = max(zmax - zmin, 1e-6)
    zshadow = zmin - 0.08 * zspan

    p = scatter(
        x,
        y,
        zcolor=c,
        z=z,
        markerstrokewidth=0.2,
        markerstrokealpha=0.30,
        markersize=point_size,
        markeralpha=point_alpha,
        color=continuous_cmap(:viridis),
        clims=(-2, 2),
        colorbar_title="log10(Ri_g) [-]",
        xlabel="eta_1",
        ylabel="eta_2",
        zlabel="eta_3",
        title=panel_title(panel_label, campaign),
        titlefont=font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
        legend=false,
        aspect_ratio=:auto,
        camera=camera_for_campaign(campaign),
        widen=true,
        xguidefontsize=9,
        yguidefontsize=9,
        zguidefontsize=9,
        xtickfontsize=8,
        ytickfontsize=8,
        ztickfontsize=8,
        guidefontrotation=12,
        left_margin=8Plots.mm,
        right_margin=8Plots.mm,
        top_margin=6Plots.mm,
        bottom_margin=8Plots.mm,
    )

    # Subtle depth cue: keep the floor projection extremely light to avoid darkening print output.
    scatter!(
        p,
        x,
        y,
        z=fill(zshadow, npts),
        markercolor=:gray45,
        markersize=max(point_size - 1.0, 1.8),
        markerstrokewidth=0,
        markeralpha=0.035,
        label="",
    )

    if !isempty(x)
        zmed = median(z)
        zspread = max(quantile(abs.(z .- zmed), 0.85), 1e-6)

        αr = range(-2.2, 1.2, length=65)
        ur_pos = range(0.0, 1.25, length=45)
        ur_neg = range(-1.25, 0.0, length=45)

        xsurf_pos = [fit.μ1 + fit.s1 * α for u in ur_pos, α in αr]
        ysurf_pos = [fit.μ2 + fit.s2 * (-u^3 - α * u) for u in ur_pos, α in αr]
        zsurf_pos = [zmed + zspread * u for u in ur_pos, α in αr]

        xsurf_neg = [fit.μ1 + fit.s1 * α for u in ur_neg, α in αr]
        ysurf_neg = [fit.μ2 + fit.s2 * (-u^3 - α * u) for u in ur_neg, α in αr]
        zsurf_neg = [zmed + zspread * u for u in ur_neg, α in αr]

        # Optimized: Force linewidth=0 to prevent wireframe meshes from overlaying point markers
        surface!(
            p,
            xsurf_pos,
            ysurf_pos,
            zsurf_pos,
            alpha=0.030,
            color=:gray88,
            linewidth=0,
            linealpha=0.0,
            label="",
        )
        surface!(
            p,
            xsurf_neg,
            ysurf_neg,
            zsurf_neg,
            alpha=0.024,
            color=:gray78,
            linewidth=0,
            linealpha=0.0,
            label="",
        )

        αf = range(-2.0, 0.0, length=120)
        βf = sqrt.((-4.0 / 27.0) .* (αf .^ 3))
        xf = fit.μ1 .+ fit.s1 .* αf
        yf_up = fit.μ2 .+ fit.s2 .* βf
        yf_dn = fit.μ2 .- fit.s2 .* βf
        zf = fill(zmed, length(αf))

        # Medium-contrast fold curves optimized for print/PDF readability.
        plot!(p, xf, yf_up, zf, color=:midnightblue, linewidth=1.9, alpha=0.92, label="")
        plot!(p, xf, yf_dn, zf, color=:midnightblue, linewidth=1.9, alpha=0.92, label="")

        # Ground-plane shadow of fold edges for depth cue.
        plot!(p, xf, yf_up, fill(zshadow, length(xf)), color=:gray45, linewidth=0.9, alpha=0.14, linestyle=:dot, label="")
        plot!(p, xf, yf_dn, fill(zshadow, length(xf)), color=:gray45, linewidth=0.9, alpha=0.14, linestyle=:dot, label="")

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

    # Repaint colored observations last so surfaces never wash out campaign color structure.
    scatter!(
        p,
        x,
        y,
        z=z,
        zcolor=c,
        color=continuous_cmap(:viridis),
        clims=(-2, 2),
        markersize=point_size + 0.2,
        markerstrokewidth=0.18,
        markerstrokealpha=0.20,
        markeralpha=0.84,
        label="",
    )

    return p
end

function save_interactive_html(filename::String="fig4_manifold_interactive.html")
    try
        plotlyjs()
        set_publication_defaults!()
        p_int = plot(
            build_panel("CASES-99", "(a)"),
            build_panel("FLOSS", "(b)"),
            build_panel("BLLAST", "(c)"),
            build_panel("GABLS3", "(d)"),
            layout=(2, 2),
            size=(2200, 1600),
            margin=8Plots.mm,
        )
        outpath = joinpath(figures_dir(), filename)
        savefig(p_int, outpath)
        @info("Saved interactive figure", outpath = outpath)
    catch err
        @warn("Interactive HTML export skipped", error = sprint(showerror, err))
    finally
        gr()
    end
end

function main()
    set_publication_defaults!()

    panels = [
        build_panel("CASES-99", "(a)"),
        build_panel("FLOSS", "(b)"),
        build_panel("BLLAST", "(c)"),
        build_panel("GABLS3", "(d)"),
    ]

    plt = plot(
        panels...,
        layout=(2, 2),
        size=(2400, 1800),
        margin=10Plots.mm,
        left_margin=10Plots.mm,
        right_margin=10Plots.mm,
        top_margin=8Plots.mm,
        bottom_margin=10Plots.mm,
    )
    save_figure_pdf(plt, "fig4_manifold.pdf")
    save_interactive_html()
end

main()