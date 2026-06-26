#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using Plots

include("manuscript_figure_common.jl")

function velocity_and_tau(t::Vector{Float64}, x::Vector{Float64}, y::Vector{Float64}, z::Vector{Float64})
    n = length(t)
    v = fill(NaN, n)
    tau = fill(NaN, n)

    for i in 2:n
        dt = t[i] - t[i - 1]
        if !(isfinite(dt) && abs(dt) > eps())
            continue
        end
        dx = x[i] - x[i - 1]
        dy = y[i] - y[i - 1]
        dz = z[i] - z[i - 1]
        if !(isfinite(dx) && isfinite(dy) && isfinite(dz))
            continue
        end
        vv = sqrt(dx * dx + dy * dy + dz * dz) / abs(dt)
        v[i] = vv
        tau[i] = vv > 0 ? 1.0 / vv : NaN
    end

    return v, tau
end

function main()
    set_publication_defaults!()

    campaign = "BLLAST"
    df, _ = load_campaign_trajectory(campaign)
    panel_b, _ = load_transition_panel_b(campaign)
    panel_c, _ = load_transition_panel_c(campaign)

    t = numeric_column(df, "time_value")
    eta1 = numeric_column(df, "eta_1")
    eta2 = numeric_column(df, "eta_2")
    eta3 = numeric_column(df, "eta_3")

    t0 = infer_transition_time(panel_c)
    trel = normalize_time_minutes(t, t0)

    v, tau = velocity_and_tau(t, eta1, eta2, eta3)

    cx = has_column(panel_b, "z1") ? numeric_column(panel_b, "z1") : numeric_column(panel_b, "eta_1")
    cy = has_column(panel_b, "z2") ? numeric_column(panel_b, "z2") : numeric_column(panel_b, "eta_2")
    d_f = nearest_distance_to_curve(eta1, eta2, cx, cy)

    m1 = finite_mask([trel, v])
    m2 = finite_mask([d_f, tau])

    p1 = plot(
        trel[m1],
        v[m1],
        color = :black,
        xlabel = "Time relative to transition breakout, t - t_0 [min]",
        ylabel = "State-space kinematic speed, v(t) [s^-1]",
        title = panel_title("(a)", "Kinematic Slowing Near Fold Approach"),
        titlefont = font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
        legend = false,
    )

    p2 = scatter(
        d_f[m2],
        tau[m2],
        color = :darkred,
        markersize = 3,
        xlabel = "Shortest distance to fold boundary, d_f [-]",
        ylabel = "Inverse tracking metric, tau = 1/v(t) [s]",
        title = panel_title("(b)", "Inverse-Speed Divergence Near Fold Edge"),
        titlefont = font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
        legend = false,
    )

    plt = plot(p1, p2, layout = (1, 2), size = (1400, 560), margin = 8Plots.mm)
    save_figure_pdf(plt, "fig7_slowing_down.pdf")
end

main()
