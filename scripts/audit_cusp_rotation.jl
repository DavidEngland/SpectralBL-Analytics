#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using Printf

include("manuscript_figure_common.jl")

function inside_fraction_scaled(eta1, eta2, ri_log, s1, s2; lo=-1.0, hi=1.0)
    mask = isfinite.(eta1) .& isfinite.(eta2) .& isfinite.(ri_log) .& (ri_log .>= lo) .& (ri_log .<= hi)
    a = eta1[mask]
    b = eta2[mask]
    if isempty(a)
        return (inside = NaN, n = 0)
    end
    α = a ./ s1
    β = b ./ s2
    Δ = 4.0 .* (α .^ 3) .+ 27.0 .* (β .^ 2)
    return (inside = mean(Δ .<= 0.0), n = length(a))
end

function inside_fraction_rotated(eta1, eta2, ri_log, s1, s2, theta; lo=-1.0, hi=1.0)
    mask = isfinite.(eta1) .& isfinite.(eta2) .& isfinite.(ri_log) .& (ri_log .>= lo) .& (ri_log .<= hi)
    a = eta1[mask]
    b = eta2[mask]
    if isempty(a)
        return (inside = NaN, n = 0)
    end
    cs = cos(theta)
    sn = sin(theta)
    α = (a ./ s1) .* cs .+ (b ./ s2) .* sn
    β = -((a ./ s1) .* sn) .+ (b ./ s2) .* cs
    Δ = 4.0 .* (α .^ 3) .+ 27.0 .* (β .^ 2)
    return (inside = mean(Δ .<= 0.0), n = length(a))
end

function campaign_data(campaign)
    df, _ = load_campaign_trajectory(campaign)
    eta1 = numeric_column(df, "eta_1")
    eta2 = numeric_column(df, "eta_2")
    ri_col = pick_best_ri_column(df, campaign)
    ri_vals = ri_col === nothing ? fill(NaN, nrow(df)) : numeric_column(df, ri_col)
    ri_log = log10_clip(ri_vals; lo = -2.0, hi = 2.0)
    return eta1, eta2, ri_log, ri_col
end

function main()
    println("=== Cusp Audit (band: -1 <= log10(Ri_g) <= 1) ===")

    cases_eta1, cases_eta2, cases_ri_log, _ = campaign_data("CASES-99")
    cases_scale = cusp_fit_scales(cases_eta1, cases_eta2, cases_ri_log; lo = -1.0, hi = 1.0)
    cases_rot = cusp_fit_rotated_scales(cases_eta1, cases_eta2, cases_ri_log; lo = -1.0, hi = 1.0)

    @printf("CASES shared scales: s1=%.4f, s2=%.4f\n", cases_scale.s1, cases_scale.s2)
    @printf("CASES shared rotated: s1=%.4f, s2=%.4f, theta=%.2f deg\n", cases_rot.s1, cases_rot.s2, rad2deg(cases_rot.theta))

    println("\nCampaign | ri_col | n | shared_scale | per_scale | shared_rot | per_rot | per_rot_theta_deg")
    println("---------|--------|---|--------------|-----------|------------|---------|------------------")

    for campaign in CAMPAIGN_ORDER
        eta1, eta2, ri_log, ri_col = campaign_data(campaign)

        per_scale_fit = cusp_fit_scales(eta1, eta2, ri_log; lo = -1.0, hi = 1.0)
        per_rot_fit = cusp_fit_rotated_scales(eta1, eta2, ri_log; lo = -1.0, hi = 1.0)

        shared_scale = inside_fraction_scaled(eta1, eta2, ri_log, cases_scale.s1, cases_scale.s2; lo = -1.0, hi = 1.0)
        own_scale = inside_fraction_scaled(eta1, eta2, ri_log, per_scale_fit.s1, per_scale_fit.s2; lo = -1.0, hi = 1.0)

        shared_rot = inside_fraction_rotated(eta1, eta2, ri_log, cases_rot.s1, cases_rot.s2, cases_rot.theta; lo = -1.0, hi = 1.0)
        own_rot = inside_fraction_rotated(eta1, eta2, ri_log, per_rot_fit.s1, per_rot_fit.s2, per_rot_fit.theta; lo = -1.0, hi = 1.0)

        @printf(
            "%s | %s | %d | %.4f | %.4f | %.4f | %.4f | %.2f\n",
            campaign,
            String(ri_col),
            own_rot.n,
            shared_scale.inside,
            own_scale.inside,
            shared_rot.inside,
            own_rot.inside,
            rad2deg(per_rot_fit.theta),
        )
    end
end

main()
