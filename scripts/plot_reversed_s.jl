#!/usr/bin/env julia
# scripts/plot_reversed_s.jl
using Pkg
Pkg.activate(".")

using Plots

include("manuscript_figure_common.jl")

"""
    generate_cusp_reversed_s(arch::String; npts=200)

Generate an idealized cusp-manifold cross-section projected into the
observational plane: mean wind speed V versus inversion strength Delta T.
"""
function generate_cusp_reversed_s(arch::String; npts::Int = 200)
    if arch == "Brittle"
        alpha = -1.2
        vr = 6.5
    else
        alpha = -0.3
        vr = 6.2
    end

    u_vals = range(-1.6, 1.6, length = npts)
    beta_vals = [u^3 + alpha * u for u in u_vals]

    wind = [7.5 - 2.0 * b for b in beta_vals]
    inversion = [3.0 + 3.5 * u for u in u_vals]
    ri_proxy = [1.5 * u + 0.2 for u in u_vals]

    return wind, inversion, ri_proxy, collect(u_vals), vr, alpha
end

function build_reversed_s_panel(arch::String, title_label::String, campaign::String)
    wind, inv, ri, u, vr, alpha = generate_cusp_reversed_s(arch)

    db_du = [3 * ui^2 + alpha for ui in u]

    coupled_mask = (db_du .>= 0.0) .& (u .< 0.0)
    decoupled_mask = (db_du .>= 0.0) .& (u .> 0.0)
    transitional_mask = db_du .< 0.0

    p = plot(
        xlabel = "Mean Wind Speed V [m s^-1]",
        ylabel = "Inversion Strength Delta T [K]",
        title = "$(title_label) $(campaign) ($(arch) Archetype)",
        titlefont = font(11, "Computer Modern"),
        legend = :topright,
        grid = :x,
        gridalpha = 0.16,
        minorgrid = false,
        framestyle = :box,
        widen = true,
        size = (800, 600),
        left_margin = 7Plots.mm,
        right_margin = 7Plots.mm,
        top_margin = 5Plots.mm,
        bottom_margin = 7Plots.mm,
    )

    plot!(
        p,
        wind[transitional_mask],
        inv[transitional_mask],
        color = :gray50,
        linestyle = :dash,
        linewidth = 2.0,
        label = "Middle Branch (Transitional)",
    )

    scatter!(
        p,
        wind[coupled_mask],
        inv[coupled_mask],
        zcolor = ri[coupled_mask],
        color = continuous_cmap(:viridis),
        clims = (-2, 2),
        markersize = 5.5,
        markerstrokewidth = 0.2,
        label = "Lower Branch (Coupled)",
    )

    scatter!(
        p,
        wind[decoupled_mask],
        inv[decoupled_mask],
        zcolor = ri[decoupled_mask],
        color = continuous_cmap(:viridis),
        clims = (-2, 2),
        markersize = 5.5,
        markerstrokewidth = 0.2,
        colorbar_title = "log10(Ri_g) proxy",
        label = "Upper Branch (Decoupled)",
    )

    vline!(
        p,
        [vr],
        color = :crimson,
        linewidth = 1.5,
        linestyle = :dot,
        label = "V_r (Fold Edge)",
    )

    if arch == "Brittle"
        annotate!(p, vr + 0.3, 1.8, text("up eta_3 curvature accumulation", 8, :left, :crimson))
    else
        annotate!(p, vr + 0.3, 2.4, text("eta_3 resilient buffering", 8, :left, :blue))
    end

    return p
end

function main()
    set_publication_defaults!()

    p1 = build_reversed_s_panel("Brittle", "(a)", "CASES-99 / Santa Maria")
    p2 = build_reversed_s_panel("Rubbery", "(b)", "FLOSS II / Polar Test")

    # Full-page variants for manuscript/report layouts that prefer one panel per page.
    save_figure_pdf(plot(p1, size=(1200, 850), margin=8Plots.mm), "fig9a_reversed_s_brittle.pdf")
    save_figure_pdf(plot(p2, size=(1200, 850), margin=8Plots.mm), "fig9b_reversed_s_rubbery.pdf")

    plt = plot(
        p1,
        p2,
        layout = (1, 2),
        size = (1600, 650),
        margin = 6Plots.mm,
    )

    save_figure_pdf(plt, "fig9_reversed_s_shadows.pdf")
    @info "Reversed-S transition framework plots successfully generated."
end

main()
