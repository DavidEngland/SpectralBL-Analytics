#!/usr/bin/env julia
# scripts/plot_aligned_transition.jl
using Pkg
Pkg.activate(".")

using Plots

include("manuscript_figure_common.jl")

"""
    generate_coupled_profiles(state::String; nz=50)

Generate idealized boundary-layer profiles linked to manifold branch states.
"""
function generate_coupled_profiles(state::String; nz::Int = 50)
    z = range(0.0, 100.0, length = nz)

    if state == "Coupled"
        u = [3.0 + 4.5 * (zi / 100.0)^0.25 for zi in z]
        theta = [290.0 + 1.0 * (zi / 100.0) for zi in z]
    elseif state == "Decoupled"
        u = [0.5 + 6.0 * (zi / 100.0)^0.5 for zi in z]
        theta = [282.0 + 9.0 * (zi / 100.0)^0.20 for zi in z]
    else
        u = [1.5 + 5.5 * (zi / 100.0)^0.35 for zi in z]
        theta = [287.0 + 4.0 * (zi / 100.0)^0.25 for zi in z]
    end

    return collect(z), u, theta
end

function main()
    set_publication_defaults!()

    z_c, u_c, th_c = generate_coupled_profiles("Coupled")
    z_d, u_d, th_d = generate_coupled_profiles("Decoupled")
    z_t, u_t, th_t = generate_coupled_profiles("Transitional")

    # Panel A: thermal profile frame.
    p_temp = plot(
        ylabel = "Height z [m]",
        xlabel = "Potential Temp theta [K]",
        title = "(a) Column Thermal Stratification",
        titlefont = font(10, "Computer Modern"),
        legend = :topleft,
        framestyle = :box,
        grid = :both,
        gridalpha = 0.12,
    )
    plot!(p_temp, th_c, z_c, color = :seagreen4, linewidth = 2.5, label = "Coupled Sheet")
    plot!(p_temp, th_t, z_t, color = :gray45, linestyle = :dash, linewidth = 2.0, label = "Transitional")
    plot!(p_temp, th_d, z_d, color = :goldenrod3, linewidth = 2.5, label = "Decoupled Sheet")

    # Panel B: projected observational shadow in Delta T vs V plane.
    u_vals = range(-1.6, 1.6, length = 200)
    beta_vals = [ui^3 - 1.2 * ui for ui in u_vals]
    wind_curve = [7.5 - 2.0 * b for b in beta_vals]
    inv_curve = [3.0 + 3.5 * ui for ui in u_vals]
    ri_proxy = [1.5 * ui + 0.2 for ui in u_vals]

    db_du = [3 * ui^2 - 1.2 for ui in u_vals]
    c_mask = (db_du .>= 0.0) .& (u_vals .< 0.0)
    d_mask = (db_du .>= 0.0) .& (u_vals .> 0.0)
    t_mask = db_du .< 0.0

    p_scatter = plot(
        xlabel = "Mean Wind Speed V [m s^-1]",
        ylabel = "Inversion Strength Delta T [K]",
        title = "(b) Observational Mapping Shadow",
        titlefont = font(10, "Computer Modern"),
        legend = :topright,
        framestyle = :box,
        grid = :both,
        gridalpha = 0.12,
    )
    plot!(p_scatter, wind_curve, inv_curve, color = :gray85, linewidth = 1.0, label = "")
    plot!(
        p_scatter,
        wind_curve[t_mask],
        inv_curve[t_mask],
        color = :gray45,
        linestyle = :dash,
        linewidth = 2.2,
        label = "Unstable Fold",
    )
    scatter!(
        p_scatter,
        wind_curve[c_mask],
        inv_curve[c_mask],
        zcolor = ri_proxy[c_mask],
        color = continuous_cmap(:viridis),
        clims = (-2, 2),
        markersize = 5.0,
        markerstrokewidth = 0.1,
        label = "Obs: Coupled",
    )
    scatter!(
        p_scatter,
        wind_curve[d_mask],
        inv_curve[d_mask],
        zcolor = ri_proxy[d_mask],
        color = continuous_cmap(:viridis),
        clims = (-2, 2),
        markersize = 5.0,
        markerstrokewidth = 0.1,
        colorbar_title = "log10(Ri_g)",
        label = "Obs: Decoupled",
    )
    vline!(p_scatter, [6.5], color = :crimson, linewidth = 1.2, linestyle = :dot, label = "V_r Threshold")

    # Panel C: wind profile frame aligned under V-axis.
    p_wind = plot(
        xlabel = "Mean Wind Speed V [m s^-1]",
        ylabel = "Height z [m]",
        title = "(c) Kinematic Profile Realization",
        titlefont = font(10, "Computer Modern"),
        legend = false,
        framestyle = :box,
        grid = :both,
        gridalpha = 0.12,
    )
    plot!(p_wind, u_c, z_c, color = :seagreen4, linewidth = 2.5)
    plot!(p_wind, u_t, z_t, color = :gray45, linestyle = :dash, linewidth = 2.0)
    plot!(p_wind, u_d, z_d, color = :goldenrod3, linewidth = 2.5)
    vline!(p_wind, [6.5], color = :crimson, linewidth = 1.2, linestyle = :dot)

    # Panel D: empty spacer for strict alignment geometry.
    p_blank = plot(framestyle = :none, grid = false, xaxis = false, yaxis = false)

    plt = plot(
        p_temp,
        p_scatter,
        p_blank,
        p_wind,
        layout = (2, 2),
        size = (1500, 1300),
        widths = [0.35, 0.65],
        heights = [0.65, 0.35],
        margin = 6Plots.mm,
        left_margin = 8Plots.mm,
        bottom_margin = 8Plots.mm,
    )

    save_figure_pdf(plt, "fig10_aligned_profiles.pdf")
    @info "Aligned profile-scatter matrix figure generated successfully."
end

main()
