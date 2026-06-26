#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using Plots

include("manuscript_figure_common.jl")

function pick_critical_point(x::Vector{Float64}, y::Vector{Float64}, ri_log::Vector{Float64}, cx::Vector{Float64}, cy::Vector{Float64})
    mask = finite_mask([x, y])
    if count(mask) < 5
        return (0.0, 0.0)
    end

    d = nearest_distance_to_curve(x, y, cx, cy)
    cands = findall(i -> mask[i] && isfinite(d[i]) && isfinite(ri_log[i]) && abs(ri_log[i]) <= 0.35, eachindex(x))
    if isempty(cands)
        cands = findall(i -> mask[i] && isfinite(d[i]), eachindex(x))
    end
    if isempty(cands)
        xv = x[mask]
        yv = y[mask]
        return (median(xv), median(yv))
    end

    idx = cands[argmin(d[cands])]
    return (x[idx], y[idx])
end

function archetype_panel(campaign::String, panel_label::String, tval::Float64, class_label::String, extra_note::String = "")
    df, _ = load_campaign_trajectory(campaign)
    curve_df, _ = load_transition_panel_b(campaign)

    eta1 = numeric_column(df, "eta_1")
    eta2 = numeric_column(df, "eta_2")
    ri_col = pick_best_ri_column(df, campaign)
    ri_vals = ri_col === nothing ? fill(NaN, nrow(df)) : numeric_column(df, ri_col)
    ri_log = log10_clip(ri_vals; lo = -2, hi = 2)

    base_mask = finite_mask([eta1, eta2])
    x = eta1[base_mask]
    y = eta2[base_mask]
    c = ri_log[base_mask]
    has_ri = any(isfinite, c)

    p = if has_ri
        scatter(
            x,
            y,
            marker_z = c,
            markersize = 3,
            markerstrokewidth = 0,
            color = continuous_cmap(:cividis),
            clims = (-2, 2),
            colorbar_title = "log10(Gradient Richardson number) [-]",
            xlabel = "Neutral baseline coordinate [-]",
            ylabel = "Linear stability coordinate [-]",
            title = panel_title(panel_label, campaign),
            titlefont = font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
            legend = false,
        )
    else
        scatter(
            x,
            y,
            markersize = 3,
            markerstrokewidth = 0,
            color = :steelblue,
            xlabel = "Neutral baseline coordinate [-]",
            ylabel = "Linear stability coordinate [-]",
            title = panel_title(panel_label, campaign),
            titlefont = font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
            legend = false,
        )
    end

    cx = has_column(curve_df, "z1") ? numeric_column(curve_df, "z1") : numeric_column(curve_df, "eta_1")
    cy = has_column(curve_df, "z2") ? numeric_column(curve_df, "z2") : numeric_column(curve_df, "eta_2")
    cmask = finite_mask([cx, cy])
    if any(cmask)
        plot!(p, cx[cmask], cy[cmask], linewidth = 2.0, color = :black, alpha = 0.8, label = "")
    end

    if !isempty(x)
        x0, y0 = pick_critical_point(eta1, eta2, ri_log, cx, cy)
        span = campaign == "FLOSS" ? (quantile(x, 0.10), quantile(x, 0.90)) : (quantile(x, 0.20), quantile(x, 0.72))
        xline = range(span[1], span[2], length = 90)
        yline = y0 .+ tval .* (xline .- x0)
        plot!(p, xline, yline, color = :black, linestyle = :dash, linewidth = 2.2, alpha = 0.9, label = "")
        scatter!(p, [x0], [y0], color = :black, markersize = 4, markerstrokewidth = 0, label = "")
    end

    ann = @sprintf("T = %.2f\\n%s", tval, class_label)
    xleft = isempty(x) ? 0.0 : minimum(x)
    xright = isempty(x) ? 1.0 : maximum(x)
    ytop = isempty(y) ? 1.0 : maximum(y)
    ybot = isempty(y) ? 0.0 : minimum(y)
    annotate!(p, xleft, ytop, text(ann, 9, :left, :top, :black))

    if !isempty(extra_note)
        annotate!(p, xright, ybot, text(extra_note, 8, :right, :bottom, :black))
    end

    if campaign == "CASES-99" && !isempty(x)
        θ = range(0.35 * pi, 1.05 * pi, length = 120)
        xw = quantile(x, 0.24)
        yw = quantile(y, 0.80)
        rx = 0.14 * (maximum(x) - minimum(x))
        ry = 0.11 * (maximum(y) - minimum(y))
        xa = xw .+ rx .* cos.(θ)
        ya = yw .+ ry .* sin.(θ)
        plot!(p, xa, ya, color = :gray35, linewidth = 1.4, alpha = 0.65, arrow = :arrow, label = "")
        annotate!(p, xw + 1.05 * rx, yw + 0.55 * ry, text("T_H ≈ 83 min", 8, :left, :bottom, :gray25))
    end

    return p
end

function main()
    set_publication_defaults!()

    p1 = archetype_panel("CASES-99", "(a)", -0.41, "Brittle Fold", "Mesoscale rolling clock: T_H ≈ 83 min")
    p2 = archetype_panel("FLOSS", "(b)", -0.07, "Rubbery Fold")

    plt = plot(p1, p2, layout = (1, 2), size = (1400, 560), margin = 8Plots.mm)
    save_figure_pdf(plt, "fig5_archetypes.pdf")
end

main()
