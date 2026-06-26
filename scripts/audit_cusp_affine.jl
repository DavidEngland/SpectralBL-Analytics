#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using Printf

include("manuscript_figure_common.jl")

function inside_fraction_affine(eta1, eta2, ri_log, μ1, μ2, s1, s2, theta; lo=-1.0, hi=1.0)
    mask = isfinite.(eta1) .& isfinite.(eta2) .& isfinite.(ri_log) .& (ri_log .>= lo) .& (ri_log .<= hi)
    a = eta1[mask]
    b = eta2[mask]
    if isempty(a)
        return (inside = NaN, n = 0)
    end
    cs = cos(theta)
    sn = sin(theta)
    α0 = (a .- μ1) ./ s1
    β0 = (b .- μ2) ./ s2
    α = α0 .* cs .+ β0 .* sn
    β = -(α0 .* sn) .+ β0 .* cs
    Δ = 4.0 .* (α .^ 3) .+ 27.0 .* (β .^ 2)
    return (inside = mean(Δ .<= 0.0), n = length(a))
end

function best_mu_on_fixed_rigid(eta1, eta2, ri_log, s1, s2, theta, eps1, eps2; lo=-1.0, hi=1.0)
    mask = isfinite.(eta1) .& isfinite.(eta2) .& isfinite.(ri_log) .& (ri_log .>= lo) .& (ri_log .<= hi)
    a = eta1[mask]
    b = eta2[mask]
    if isempty(a)
        return (inside = NaN, n = 0, μ1 = 0.0, μ2 = 0.0)
    end

    mu1_grid = range(-eps1, eps1, length = 21)
    mu2_grid = range(-eps2, eps2, length = 21)

    best_inside = -Inf
    best_mu1 = 0.0
    best_mu2 = 0.0
    for μ1 in mu1_grid, μ2 in mu2_grid
        v = inside_fraction_affine(a, b, fill(0.0, length(a)), μ1, μ2, s1, s2, theta; lo = -Inf, hi = Inf)
        frac = v.inside
        if isfinite(frac) && frac > best_inside
            best_inside = frac
            best_mu1 = μ1
            best_mu2 = μ2
        end
    end
    return (inside = best_inside, n = length(a), μ1 = best_mu1, μ2 = best_mu2)
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
    println("=== Cusp Audit: scale-only vs rotated vs affine (band: -1 <= log10(Ri_g) <= 1) ===")

    # Shared baseline from CASES-99
    ce1, ce2, cri, _ = campaign_data("CASES-99")
    shared_scale = cusp_fit_scales(ce1, ce2, cri; lo = -1.0, hi = 1.0)
    shared_rot = cusp_fit_rotated_scales(ce1, ce2, cri; lo = -1.0, hi = 1.0)
    shared_aff = cusp_fit_affine_rotated_scales(ce1, ce2, cri; lo = -1.0, hi = 1.0)
    shared_baff = cusp_fit_bounded_affine_rotated_scales(ce1, ce2, cri; lo = -1.0, hi = 1.0)

    @printf("Shared CASES scale: s1=%.4f, s2=%.4f\n", shared_scale.s1, shared_scale.s2)
    @printf("Shared CASES rotated: s1=%.4f, s2=%.4f, theta=%.2f deg\n", shared_rot.s1, shared_rot.s2, rad2deg(shared_rot.theta))
    @printf("Shared CASES affine: mu1=%.4f, mu2=%.4f, s1=%.4f, s2=%.4f, theta=%.2f deg\n", shared_aff.μ1, shared_aff.μ2, shared_aff.s1, shared_aff.s2, rad2deg(shared_aff.theta))
    @printf("Shared CASES bounded affine: mu1=%.4f, mu2=%.4f, s1=%.4f, s2=%.4f, theta=%.2f deg, eps=(%.4f, %.4f), n_neutral=%d\n", shared_baff.μ1, shared_baff.μ2, shared_baff.s1, shared_baff.s2, rad2deg(shared_baff.theta), shared_baff.eps1, shared_baff.eps2, shared_baff.neutral_n)

    println("\nCampaign | ri_col | n | shared_scale | per_scale | shared_rot | per_rot | shared_aff | per_aff | shared_baff | per_baff | mu_only_on_rigid | per_baff_theta_deg | eps1 | eps2")
    println("---------|--------|---|--------------|-----------|------------|---------|------------|---------|-------------|----------|------------------|--------------------|------|------")

    for campaign in CAMPAIGN_ORDER
        e1, e2, rl, ri_col = campaign_data(campaign)

        per_scale = cusp_fit_scales(e1, e2, rl; lo = -1.0, hi = 1.0)
        per_rot = cusp_fit_rotated_scales(e1, e2, rl; lo = -1.0, hi = 1.0)
        per_aff = cusp_fit_affine_rotated_scales(e1, e2, rl; lo = -1.0, hi = 1.0)
        per_baff = cusp_fit_bounded_affine_rotated_scales(e1, e2, rl; lo = -1.0, hi = 1.0)

        sh_scale = inside_fraction_affine(e1, e2, rl, 0.0, 0.0, shared_scale.s1, shared_scale.s2, 0.0; lo = -1.0, hi = 1.0)
        own_scale = inside_fraction_affine(e1, e2, rl, 0.0, 0.0, per_scale.s1, per_scale.s2, 0.0; lo = -1.0, hi = 1.0)

        sh_rot = inside_fraction_affine(e1, e2, rl, 0.0, 0.0, shared_rot.s1, shared_rot.s2, shared_rot.theta; lo = -1.0, hi = 1.0)
        own_rot = inside_fraction_affine(e1, e2, rl, 0.0, 0.0, per_rot.s1, per_rot.s2, per_rot.theta; lo = -1.0, hi = 1.0)

        sh_aff = inside_fraction_affine(e1, e2, rl, shared_aff.μ1, shared_aff.μ2, shared_aff.s1, shared_aff.s2, shared_aff.theta; lo = -1.0, hi = 1.0)
        own_aff = inside_fraction_affine(e1, e2, rl, per_aff.μ1, per_aff.μ2, per_aff.s1, per_aff.s2, per_aff.theta; lo = -1.0, hi = 1.0)

        sh_baff = inside_fraction_affine(e1, e2, rl, shared_baff.μ1, shared_baff.μ2, shared_baff.s1, shared_baff.s2, shared_baff.theta; lo = -1.0, hi = 1.0)
        own_baff = inside_fraction_affine(e1, e2, rl, per_baff.μ1, per_baff.μ2, per_baff.s1, per_baff.s2, per_baff.theta; lo = -1.0, hi = 1.0)
        mu_only_rigid = best_mu_on_fixed_rigid(e1, e2, rl, per_rot.s1, per_rot.s2, per_rot.theta, per_baff.eps1, per_baff.eps2; lo = -1.0, hi = 1.0)

        @printf(
            "%s | %s | %d | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.2f | %.4f | %.4f\n",
            campaign,
            String(ri_col),
            own_aff.n,
            sh_scale.inside,
            own_scale.inside,
            sh_rot.inside,
            own_rot.inside,
            sh_aff.inside,
            own_aff.inside,
            sh_baff.inside,
            own_baff.inside,
            mu_only_rigid.inside,
            rad2deg(per_baff.theta),
            per_baff.eps1,
            per_baff.eps2,
        )
    end
end

main()
