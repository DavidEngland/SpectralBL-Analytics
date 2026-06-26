#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using Plots
using Printf

include("manuscript_figure_common.jl")

function campaign_marker(campaign::String)
    markers = Dict(
        "CASES-99" => :circle,
        "FLOSS" => :diamond,
        "BLLAST" => :rect,
        "GABLS3" => :utriangle,
    )
    return get(markers, campaign, :circle)
end

function campaign_color(campaign::String)
    colors = Dict(
        "CASES-99" => :blue,
        "FLOSS" => :darkgreen,
        "BLLAST" => :firebrick,
        "GABLS3" => :purple,
    )
    return get(colors, campaign, :black)
end

function collect_campaign_points(campaign::String)
    df, _ = load_campaign_trajectory(campaign)
    curve_df, _ = load_transition_panel_b(campaign)

    x = numeric_column(df, "eta_1")
    y = numeric_column(df, "eta_2")
    eta3 = abs.(numeric_column(df, "eta_3"))

    cx = has_column(curve_df, "z1") ? numeric_column(curve_df, "z1") : numeric_column(curve_df, "eta_1")
    cy = has_column(curve_df, "z2") ? numeric_column(curve_df, "z2") : numeric_column(curve_df, "eta_2")
    d_f = nearest_distance_to_curve(x, y, cx, cy)

    m = finite_mask([d_f, eta3])
    d = d_f[m]
    e = eta3[m]

    m2 = (d .> 0) .& (e .> 0)
    return d[m2], e[m2]
end

function main()
    set_publication_defaults!()

    all_d = Float64[]
    all_e = Float64[]
    per_campaign = Dict{String, Tuple{Vector{Float64}, Vector{Float64}}}()

    for campaign in CAMPAIGN_ORDER
        d, e = collect_campaign_points(campaign)
        per_campaign[campaign] = (d, e)
        append!(all_d, d)
        append!(all_e, e)
    end

    fit = linear_fit_with_ci(log10.(all_d), log10.(all_e))
    pexp = -fit.slope
    pexp_ci = fit.slope_ci

    p = plot(
        xscale = :log10,
        yscale = :log10,
        xlabel = "Shortest Euclidean distance to fold line, d_f [-]",
        ylabel = "Spectral curvature coordinate magnitude [-]",
        title = "Universal Scaling Collapse Across Four Campaigns",
        legend = :topright,
    )

    for campaign in CAMPAIGN_ORDER
        d, e = per_campaign[campaign]
        scatter!(
            p,
            d,
            e,
            marker = campaign_marker(campaign),
            markersize = 4,
            color = campaign_color(campaign),
            alpha = 0.8,
            label = campaign,
        )
    end

    if isfinite(fit.intercept) && isfinite(fit.slope)
        xmin = minimum(all_d)
        xmax = maximum(all_d)
        xr = exp10.(range(log10(xmin), log10(xmax), length = 120))
        yr = exp10.(fit.intercept .+ fit.slope .* log10.(xr))
        plot!(p, xr, yr, color = :black, linewidth = 2.2, label = "power-law fit")

        txt = @sprintf("p = %.3f ± %.3f (95%% CI)\\nN = %d", pexp, pexp_ci, fit.n)
        annotate!(p, xmax, maximum(all_e), text(txt, 9, :right, :top, :black))
    end

    save_figure_pdf(p, "fig8_universal_collapse.pdf")
end

main()
