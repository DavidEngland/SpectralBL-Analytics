#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using Plots

include("manuscript_figure_common.jl")

function gaussian_kernel(window_size::Int)
    w = max(window_size, 3)
    if iseven(w)
        w += 1
    end
    h = (w - 1) ÷ 2
    sigma = max(w / 3, 1.0)
    k = [exp(-0.5 * (i / sigma)^2) for i in -h:h]
    return k ./ sum(k)
end

function smooth_series(v::Vector{Float64}; window_size::Int = 7)
    k = gaussian_kernel(window_size)
    h = (length(k) - 1) ÷ 2
    out = similar(v)
    for i in eachindex(v)
        num = 0.0
        den = 0.0
        for j in -h:h
            idx = clamp(i + j, firstindex(v), lastindex(v))
            vij = v[idx]
            if isfinite(vij)
                w = k[j + h + 1]
                num += w * vij
                den += w
            end
        end
        out[i] = den > 0 ? num / den : NaN
    end
    return out
end

function smooth_second_derivative(y::Vector{Float64}, t::Vector{Float64}; window_size::Int = 7)
    ys = smooth_series(y; window_size = window_size)
    finite_t = filter(isfinite, t)
    dt = length(finite_t) >= 2 ? median(diff(finite_t)) : 1.0
    dt = isfinite(dt) && abs(dt) > eps() ? abs(dt) : 1.0

    d2 = fill(NaN, length(ys))
    for i in 2:(length(ys)-1)
        if isfinite(ys[i - 1]) && isfinite(ys[i]) && isfinite(ys[i + 1])
            d2[i] = (ys[i + 1] - 2 * ys[i] + ys[i - 1]) / (dt * dt)
        end
    end
    return d2
end

function main()
    set_publication_defaults!()

    campaign = "CASES-99"
    df, _ = load_campaign_trajectory(campaign)
    tc_df, _ = load_transition_panel_c(campaign)

    tvals = numeric_column(df, "time_value")
    t0 = infer_transition_time(tc_df)
    tmin = normalize_time_minutes(tvals, t0)

    eta3 = numeric_column(df, "eta_3")

    ri_col = pick_ri_low_column(df, campaign)
    ri_low = ri_col === nothing ? fill(NaN, nrow(df)) : numeric_column(df, ri_col)
    ri_bulk = ri_mean_series(df)

    flux_proxy, flux_label = pick_flux_proxy(df)

    mask_top = finite_mask([tmin, eta3])
    mask_mid = finite_mask([tmin, ri_low])
    mask_bulk = finite_mask([tmin, ri_bulk])
    mask_bot = finite_mask([tmin, flux_proxy])

    onset_ri = begin
        thr = 0.25
        inds = findall(i -> isfinite(ri_low[i]) && ri_low[i] >= thr, eachindex(ri_low))
        isempty(inds) ? 0.0 : tmin[first(inds)]
    end

    onset_eta = begin
        d2 = smooth_second_derivative(eta3, tmin; window_size = 7)
        valid = finite_mask([tmin, d2])
        if any(valid)
            absd2 = abs.(d2[valid])
            thr = quantile(absd2, 0.88)
            tv = tmin[valid]
            dv = d2[valid]
            search_inds = eachindex(tv)
            if isfinite(onset_ri)
                bounded = findall(i -> tv[i] <= onset_ri, eachindex(tv))
                if !isempty(bounded)
                    search_inds = bounded
                end
            end
            hit = findfirst(i -> abs(dv[i]) >= thr, search_inds)
            if hit !== nothing
                tv[search_inds[hit]]
            else
                tv[argmax(abs.(dv))]
            end
        else
            0.0
        end
    end

    p1 = plot(
        tmin[mask_top],
        eta3[mask_top],
        color = :black,
        xlabel = "",
        ylabel = "Third manifold mode (spectral curvature) [-]",
        title = panel_title("(a)", "Spectral Curvature Inflation"),
        titlefont = font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
        legend = false,
    )

    p2 = plot(
        tmin[mask_mid],
        ri_low[mask_mid],
        color = :blue,
        label = "Ri_g (low-level)",
        xlabel = "",
        ylabel = "Richardson number [-]",
        title = panel_title("(b)", "Local vs Bulk Stability"),
        titlefont = font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
    )
    plot!(p2, tmin[mask_bulk], ri_bulk[mask_bulk], color = :darkgreen, linestyle = :dash, label = "Ri_b proxy")
    hline!(p2, [0.25], color = :gray35, linestyle = :dot, label = "Ri_c = 0.25")

    p3 = plot(
        tmin[mask_bot],
        flux_proxy[mask_bot],
        color = :firebrick,
        xlabel = "Time relative to transition breakout, t - t_0 [min]",
        ylabel = flux_label,
        title = panel_title("(c)", "Surface Coupling Proxy"),
        titlefont = font(11, "Computer Modern", :black, :hcenter, :vcenter, 0.0),
        legend = false,
    )

    lead_minutes = onset_ri - onset_eta
    ann_text = @sprintf("Delta t_eta onset = %.1f min\\nRi_g crossing = %.1f min", onset_eta, onset_ri)
    tx = any(mask_top) ? maximum(tmin[mask_top]) : 0.0
    ty = any(mask_top) ? maximum(eta3[mask_top]) : 0.0
    annotate!(p1, tx, ty, text(ann_text, 8, :right, :top, :black))

    accent = :slategray4
    vline!(p1, [onset_eta], color = accent, linestyle = :dash, linewidth = 1.6)
    vline!(p2, [onset_ri], color = accent, linestyle = :dash, linewidth = 1.6)
    vline!(p2, [onset_eta], color = accent, linestyle = :dot, linewidth = 1.2)

    if any(mask_mid)
        ytop = maximum(ri_low[mask_mid])
        yb = ytop + 0.08 * max(abs(ytop), 1.0)
        plot!(p2, [onset_eta, onset_ri], [yb, yb], color = accent, linewidth = 2.0, label = "")
        plot!(p2, [onset_eta, onset_eta], [yb - 0.03, yb + 0.03], color = accent, linewidth = 2.0, label = "")
        plot!(p2, [onset_ri, onset_ri], [yb - 0.03, yb + 0.03], color = accent, linewidth = 2.0, label = "")
        annotate!(p2, (onset_eta + onset_ri) / 2, yb + 0.03, text(@sprintf("Delta t_eta ≈ %.1f min", lead_minutes), 9, :center, :bottom, accent))
    end

    plt = plot(p1, p2, p3, layout = (3, 1), size = (1100, 1200), margin = 8Plots.mm, link = :x)
    save_figure_pdf(plt, "fig6_shadow_timeseries.pdf")
end

main()
