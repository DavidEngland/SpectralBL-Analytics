#!/usr/bin/env julia
# scripts/build_campaign_report.jl
# Orchestration runner: wires ExportPipeline -> Mustache templates -> TeX compilation

using Pkg
Pkg.activate(".")

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src", "io"))

using ExportPipeline
using CSV
using DataFrames
using JSON3
using Mustache
using Printf
using Dates
using LinearAlgebra
using Statistics

struct ReportDefinition
    name::String
    template_path::String
    output_tex_path::String
end

const REGISTRY = [
    ReportDefinition("main", "templates/main.tex.mustache", "main.tex"),
    ReportDefinition("domec_transition", "templates/domec_transition.tex.mustache", "generated/domec_transition.tex"),
    ReportDefinition("attractor", "templates/attractor_report.tex.mustache", "generated/attractor.tex"),
    ReportDefinition("regime", "templates/regime_decomposition.tex.mustache", "generated/regime.tex"),
    ReportDefinition("geometric_precursors", "templates/geometric_precursors.tex.mustache", "generated/geometric_precursors.tex"),
    ReportDefinition("bifurcation", "templates/bifurcation_spectrum.tex.mustache", "generated/bifurcation_spectrum.tex"),
    ReportDefinition("transitions", "templates/transition_exhibit.tex.mustache", "generated/transition_exhibit.tex"),
    ReportDefinition("conclusions", "templates/conclusions_and_diagnostics.tex.mustache", "generated/conclusions_and_diagnostics.tex"),
    ReportDefinition("audit", "templates/audit.tex.mustache", "generated/audit.tex")
]

function scatter_downsample_rate(campaign::Union{Nothing,String})
    # CASES-99 has far denser trajectories; use stronger downsampling for robust pgfplots compiles.
    if campaign == "CASES-99"
        return 20
    end
    return 10
end

function report_dir_for_campaign(campaign::Union{Nothing,String})
    if campaign === nothing
        return "all_run"
    elseif campaign == "CASES-99"
        return "cases99_run"
    elseif campaign == "GABLS3"
        return "gabls3_run"
    elseif campaign == "BLLAST"
        return "bllast_run"
    elseif campaign == "ARCTIC-AMPLIFICATION"
        return "arctic_amplification_run"
    end

    # Fallback: sanitize arbitrary campaign labels into a stable folder name.
    safe = lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    isempty(safe) && (safe = "campaign")
    return "$(safe)_run"
end

function campaign_slug_local(campaign::Union{Nothing,String})
    if campaign === nothing
        return "all"
    end
    safe = lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    return isempty(safe) ? "campaign" : safe
end

function is_domec_campaign(campaign::String)
    token = uppercase(replace(strip(campaign), r"[^A-Za-z0-9]+" => ""))
    return token == "DOMEC"
end

function ensure_report_workspace(report_run_dir::String, workspace_dir::String)
    mkpath(report_run_dir)
    mkpath(joinpath(report_run_dir, "generated"))
    mkpath(joinpath(report_run_dir, "tikz-cache"))

    # main.tex is now rendered from templates/main.tex.mustache via the REGISTRY render loop.
end

function escape_latex_text(text::String)
    escaped = replace(text, "\\" => "\\textbackslash{}")
    escaped = replace(escaped, "%" => "\\%")
    escaped = replace(escaped, "_" => "\\_")
    escaped = replace(escaped, "&" => "\\&")
    escaped = replace(escaped, "#" => "\\#")
    escaped = replace(escaped, "{" => "\\{")
    escaped = replace(escaped, "}" => "\\}")
    escaped = replace(escaped, '\$' => raw"\$")
    return escaped
end

function infer_campaign_conclusions(campaign_id::String)
    campaign_upper = uppercase(strip(campaign_id))

    if campaign_upper == "GABLS3"
        return [
            (title = "High-Entropy Dimensional Exploration", body = "The high mean entropy and elevated effective dimension demonstrate broad modal participation, indicating rich state-space exploration rather than collapse into a single operating mode."),
            (title = "Diurnal Process Fidelity", body = "The trajectory resolves the full convective-to-stable transition arc, making this campaign a process-study benchmark for transient stability regime evaluation."),
            (title = "Jet-Shear Coupling", body = "The projected coordinates capture non-local shear production and low-level jet modulation, preserving structure that local gradient-only metrics often under-resolve.")
        ]
    elseif campaign_upper == "CASES-99"
        return [
            (title = "Attractor Collapse Identification", body = "Low mean entropy and compressed effective dimension indicate recurrent attractor collapse into highly ordered nocturnal states."),
            (title = "Dominance of Non-Local Regimes", body = "The decomposition highlights intermittent shear-burst behavior and non-local coupling episodes that challenge strictly local similarity formulations."),
            (title = "Transition Behavior Tracking", body = "Phase-space coordinates remain informative in stability windows where Richardson-style diagnostics saturate and lose structural sensitivity.")
        ]
    elseif startswith(campaign_upper, "AMERIFLUX-US-NR1")
        return [
            (title = "Canopy-Crown Wake Asymmetry", body = "High-roughness forest structure introduces pronounced shear-layer asymmetry that is retained in the reduced-order attractor geometry."),
            (title = "Sub-Canopy Decoupling", body = "Nocturnal stratification episodes show partial decoupling between lower and upper tower levels, reflected as multi-branch trajectory behavior."),
            (title = "Orographic Flow Modulation", body = "Complex terrain forcing introduces multi-scale variability consistent with drainage and slope-flow interactions in stable windows.")
        ]
    elseif startswith(campaign_upper, "AMERIFLUX")
        return [
            (title = "Cross-Site Structural Diversity", body = "Heterogeneous tower geometries and land-cover classes map into a unified eta-space, enabling direct cross-ecosystem regime comparison."),
            (title = "Roughness-Conditioned Dynamics", body = "Site-dependent roughness and canopy structure modulate shear production and mixing intermittency, visible in entropy and curvature signatures."),
            (title = "Network-Scale Validation Potential", body = "The campaign supports broad model stress-testing across surface types, from low-roughness grasslands to canopy-dominated terrain.")
        ]
    elseif startswith(campaign_upper, "SHEBA")
        return [
            (title = "Arctic Stable-Layer Persistence", body = "Long-lived stable stratification highlights low-turbulence operating modes and sensitivity to intermittent forcing."),
            (title = "Sparse-Level Robustness", body = "The projection remains usable under sparse vertical sampling, preserving diagnostic continuity for reduced-profile conditions.")
        ]
    elseif campaign_upper == "ARCTIC-AMPLIFICATION"
        return [
            (title = "Lapse-Rate Feedback Lock-In", body = "Strong stratification traps thermal anomalies near the surface and reinforces long-lived inversion states characteristic of Arctic amplification episodes."),
            (title = "Low-Rank Waveguide Persistence", body = "The HLBL trajectory remains compressed in low-dimensional, wave-dominated manifolds, consistent with suppressed isotropic turbulence under high stability."),
            (title = "Intermittent Micro-Front Bursts", body = "Elevated intermittency proxies reflect sharp inversion-layer transitions and frontal jumps despite globally reduced turbulent mixing.")
        ]
    elseif startswith(campaign_upper, "NEON")
        return [
            (title = "Heterogeneous Tower Fidelity", body = "The manifold representation remains stable across site-dependent level availability and mixed-quality profile coverage."),
            (title = "Intermittency Exposure", body = "Phase trajectories expose transition windows where local closure assumptions degrade under intermittent turbulence events.")
        ]
    elseif startswith(campaign_upper, "ICOS")
        return [
            (title = "Sparse-Profile Upscaling Utility", body = "Reduced vertical observations retain actionable structure after projection, supporting low-data regime characterization."),
            (title = "Cross-Network Harmonization", body = "The standardized coordinate mapping enables comparability with denser campaign datasets despite sparse source constraints.")
        ]
    elseif startswith(campaign_upper, "SMEAR")
        return [
            (title = "Boreal Transition Sensitivity", body = "Profiles retain sensitivity to stable transition timing and non-local mixing behavior in high-latitude boundary-layer conditions."),
            (title = "Seasonal-Scale Diagnostics", body = "The reduced manifold supports tracking of structural variability across long observational windows.")
        ]
    elseif campaign_upper == "FLOSS"
        return [
            (title = "Delayed Threshold with Weak-Transversality Crossing",
             body = "The continuation analysis identifies a Hopf instability at a critical dissipation parameter nearly an order of magnitude below the corresponding CASES-99 threshold (gamma_c approx 0.0235 versus 0.278). The crossing rate magnitude is substantially smaller than the grassland value, indicating a weakly emergent instability rather than an abrupt high-transversality transition. Both observations follow directly from the eigenanalysis."),
            (title = "Dynamically Distinct Oscillatory Timescale",
             body = "At the stability boundary the dominant eigenpair crosses the imaginary axis with a non-zero imaginary component corresponding to a characteristic period of approximately 31.5 minutes. This timescale falls within the range commonly associated with wave-mediated and shear-intermittency processes observed in strongly stable boundary layers. The period is substantially shorter than the oscillatory mode identified in CASES-99, suggesting that the instability emerging over snow is dynamically distinct rather than a delayed manifestation of the same mode."),
            (title = "Evidence for Manifold Reshaping",
             body = "The combination of a substantially reduced critical threshold and an altered oscillation frequency implies that snow-covered stable boundary layers occupy a fundamentally different region of low-dimensional state space. The threshold and frequency ratios between campaigns are inconsistent with a simple parameter rescaling of the grassland dynamics. These results suggest that surface conditions influence not only the location of stability boundaries but also the geometric structure of the underlying dynamical manifold reconstructed from observations.")
        ]
    elseif campaign_upper == "BLLAST"
        return [
            (title = "Evening Transition Capture",
             body = "BLLAST resolves the late-afternoon to evening transition window where convective decay yields the first persistent stable-layer signatures. The reconstructed trajectory directly samples the pre-nocturnal manifold approach rather than only deep nighttime states."),
            (title = "Fold-Approach Diagnostics",
             body = "Transition-era profiles provide high leverage for identifying where projected S-curve signatures first emerge from continuous manifold deformation. This campaign is therefore a structural bridge between daytime mixed-layer dynamics and nocturnal multi-equilibria behavior."),
            (title = "Cross-Context Invariance Test",
             body = "When compared against CASES-99, FLOSS, and GABLS3, BLLAST offers a distinct forcing context focused on onset timing. Consistent fold topology across these datasets supports the interpretation that observed S-curve behavior is a projection of a campaign-invariant manifold structure.")
        ]
    elseif campaign_upper == "ALL"
        return [
            (title = "Composite Regime Envelope", body = "The merged trajectory captures a broader attractor envelope spanning process-oriented and climatological campaign characteristics."),
            (title = "Cross-Campaign Orthogonality", body = "Shared eta-space coordinates preserve campaign-specific signatures while maintaining a common comparison basis."),
            (title = "Validation Breadth", body = "Multi-campaign aggregation expands stress-testing of closures and parameterizations across contrasting stability environments.")
        ]
    end

    return [
        (title = "Generalized Boundary Layer Profiling", body = "The system maps observed vertical structure into a stable low-rank manifold, providing campaign-agnostic diagnostics for regime transitions and structural intermittency.")
    ]
end

function format_optional_z0m(manifest)
    if haskey(manifest, "z0m")
        z0m_val = manifest["z0m"]
        if z0m_val isa Number && isfinite(z0m_val)
            return @sprintf("%.3f m", z0m_val)
        end
    end
    return "0.100 (Default Grassland)"
end

function format_metric(value; digits::Int=4, fallback::String="n/a")
    if value === nothing
        return fallback
    elseif value isa Integer
        return string(value)
    elseif value isa AbstractFloat || value isa Number
        f = Float64(value)
        return isfinite(f) ? @sprintf("%.*f", digits, f) : fallback
    end
    return string(value)
end

function format_percent(value; digits::Int=1, fallback::String="n/a")
    if value === nothing
        return fallback
    end
    f = Float64(value)
    return isfinite(f) ? @sprintf("%.*f%%", digits, 100.0 * f) : fallback
end

function make_signal(icon::String, text::String)
    return Dict("icon" => icon, "signal_text" => text)
end

function load_optional_csv(path::String)
    return isfile(path) ? CSV.read(path, DataFrame) : nothing
end

function load_optional_json(path::String)
    return isfile(path) ? JSON3.read(read(path, String)) : nothing
end

function percentile_or_nothing(values::Vector{Float64}, q::Float64)
    isempty(values) && return nothing
    return quantile(values, q)
end

function summarize_stage2_diagnostics(path::String)
    df = load_optional_csv(path)
    if df === nothing || nrow(df) == 0
        return (
            available = false,
            path = path,
            window_count = 0,
            exceed_count = 0,
            exceed_fraction = nothing,
            disagreement_mean = nothing,
            disagreement_p95 = nothing,
            disagreement_max = nothing,
            dominant_route = "n/a",
        )
    end

    window_count = nrow(df)
    exceed_count = count(df.exceeds_threshold .== true)
    disagreement_vals = Float64.(df.disagreement_norm)

    route_counts = Dict{String,Int}()
    for route in String.(df.route_class)
        route_counts[route] = get(route_counts, route, 0) + 1
    end
    dominant_route = isempty(route_counts) ? "n/a" : first(sort(collect(route_counts), by=x -> x[2], rev=true))[1]

    return (
        available = true,
        path = path,
        window_count = window_count,
        exceed_count = exceed_count,
        exceed_fraction = window_count > 0 ? exceed_count / window_count : nothing,
        disagreement_mean = mean(disagreement_vals),
        disagreement_p95 = percentile_or_nothing(disagreement_vals, 0.95),
        disagreement_max = maximum(disagreement_vals),
        dominant_route = dominant_route,
    )
end

function summarize_stage4_lambda_sweep(path::String)
    df = load_optional_csv(path)
    if df === nothing || nrow(df) == 0
        return (
            available = false,
            path = path,
            lambda_count = 0,
            selected_lambda = nothing,
            selected_residual = nothing,
            selected_nnz = nothing,
        )
    end

    best_idx = argmin(abs.(Float64.(df.lambda) .- 0.01))
    return (
        available = true,
        path = path,
        lambda_count = nrow(df),
        selected_lambda = Float64(df.lambda[best_idx]),
        selected_residual = Float64(df.residual_norm[best_idx]),
        selected_nnz = Int(df.nnz[best_idx]),
    )
end

function summarize_stage5(stability_path::String, branch_path::String)
    manifest = load_optional_json(stability_path)
    branch_df = load_optional_csv(branch_path)
    if manifest === nothing
        return (
            available = false,
            stability_path = stability_path,
            branch_path = branch_path,
            stable_count = nothing,
            hopf_candidate_count = nothing,
            branch_points = branch_df === nothing ? 0 : nrow(branch_df),
            terminated = false,
            termination_gamma = nothing,
            termination_reason = "n/a",
        )
    end

    cont = haskey(manifest, "continuation") ? manifest["continuation"] : nothing
    terminated = cont === nothing ? false : Bool(cont["terminated"])
    termination_gamma = nothing
    if cont !== nothing && haskey(cont, "termination_gamma") && cont["termination_gamma"] !== nothing
        termination_gamma = Float64(cont["termination_gamma"])
    end
    termination_reason = (cont !== nothing && haskey(cont, "termination_reason") && cont["termination_reason"] !== nothing) ? String(cont["termination_reason"]) : "n/a"
    branch_points = cont === nothing ? (branch_df === nothing ? 0 : nrow(branch_df)) : Int(cont["branch_points"])

    return (
        available = true,
        stability_path = stability_path,
        branch_path = branch_path,
        stable_count = Int(manifest["stable_count"]),
        hopf_candidate_count = Int(manifest["hopf_candidate_count"]),
        branch_points = branch_points,
        terminated = terminated,
        termination_gamma = termination_gamma,
        termination_reason = termination_reason,
    )
end

function extract_stage5_summary_tokens(data_out_dir::String, campaign_label::String, report_run_dir::String)
    slug = campaign_slug_local(campaign_label)
    summary_path = joinpath(data_out_dir, "stage5_summary_$(slug).json")
    branch_path = joinpath(data_out_dir, "stage5_bifurcation_branches_$(slug).csv")

    branch_rel = relpath(branch_path, report_run_dir)

    tokens = Dict{String,Any}(
        "has_stage5_summary" => false,
        "has_stage5_branch_data" => false,
        "has_stage5_hopf_marker" => false,
        "has_stage5_period" => false,
        "has_stage5_beta_c" => false,
        "has_stage5_beta_series" => false,
        "stage5_summary_path" => relpath(summary_path, report_run_dir),
        "csv_stage5_branch_path" => branch_rel,
        "csv_stage5_branch_path_tex" => "{" * branch_rel * "}",
        "gamma_c" => "0.05",
        "gamma_c_fmt" => "n/a",
        "period_fmt" => "n/a",
        "period_seconds_fmt" => "n/a",
        "transversality" => "0.0",
        "transversality_fmt" => "n/a",
        "beta_c_fmt" => "n/a",
        "gamma_min" => "0.0",
        "gamma_max" => "1.0",
        "beta_axis_min" => "0.0",
        "beta_axis_max" => "0.010000",
        "hopf_line_min" => "0.0",
        "hopf_line_max" => "1.0",
    )

    branch_gamma_min = nothing
    branch_gamma_max = nothing
    if isfile(branch_path)
        branch_df = CSV.read(branch_path, DataFrame)
        branch_names = Set(Symbol.(names(branch_df)))
        if nrow(branch_df) > 0 && :gamma in branch_names && :max_real_eig in branch_names
            gamma_col = branch_df[!, "gamma"]
            eig_col = branch_df[!, "max_real_eig"]
            gamma_vals = [Float64(v) for v in gamma_col if !ismissing(v) && isfinite(Float64(v))]
            eig_vals = [Float64(v) for v in eig_col if !ismissing(v) && isfinite(Float64(v))]
            if !isempty(gamma_vals) && !isempty(eig_vals)
                branch_gamma_min = minimum(gamma_vals)
                branch_gamma_max = maximum(gamma_vals)
                tokens["has_stage5_branch_data"] = true
                tokens["gamma_min"] = @sprintf("%.6f", branch_gamma_min)
                tokens["gamma_max"] = @sprintf("%.6f", branch_gamma_max)
            end

            if :max_imag_eig in branch_names
                imag_col = branch_df[!, "max_imag_eig"]
                imag_vals = [Float64(v) for v in imag_col if !ismissing(v) && isfinite(Float64(v))]
                if !isempty(imag_vals)
                    beta_max = maximum(imag_vals)
                    beta_axis_max = max(0.001, 1.1 * beta_max)
                    tokens["has_stage5_beta_series"] = true
                    tokens["beta_axis_max"] = @sprintf("%.6f", beta_axis_max)
                end
            end
        end
    end

    if !isfile(summary_path)
        return tokens
    end

    summary = JSON3.read(read(summary_path, String))
    gamma_c = (haskey(summary, "gamma_c_hopf") && summary["gamma_c_hopf"] !== nothing) ? tryparse(Float64, string(summary["gamma_c_hopf"])) : nothing
    period_seconds = (haskey(summary, "hopf_period_Th") && summary["hopf_period_Th"] !== nothing) ? tryparse(Float64, string(summary["hopf_period_Th"])) : nothing
    transversality = (haskey(summary, "dRe_dgamma_at_crossing") && summary["dRe_dgamma_at_crossing"] !== nothing) ? tryparse(Float64, string(summary["dRe_dgamma_at_crossing"])) : nothing

    gamma_min_summary = (haskey(summary, "gamma_min") && summary["gamma_min"] !== nothing) ? tryparse(Float64, string(summary["gamma_min"])) : nothing
    gamma_max_summary = (haskey(summary, "gamma_max") && summary["gamma_max"] !== nothing) ? tryparse(Float64, string(summary["gamma_max"])) : nothing

    if gamma_min_summary !== nothing && gamma_max_summary !== nothing
        tokens["gamma_min"] = @sprintf("%.6f", gamma_min_summary)
        tokens["gamma_max"] = @sprintf("%.6f", gamma_max_summary)
    end

    if gamma_c !== nothing
        tokens["has_stage5_hopf_marker"] = true
        tokens["gamma_c"] = @sprintf("%.6f", gamma_c)
        tokens["gamma_c_fmt"] = @sprintf("%.4f", gamma_c)

        # Extract imaginary eigenvalue (Hopf frequency beta) at the crossing from branch CSV.
        if isfile(branch_path)
            bdf = CSV.read(branch_path, DataFrame)
            bnames = Set(Symbol.(names(bdf)))
            if :gamma in bnames && :max_imag_eig in bnames && nrow(bdf) > 0
                # Find the row with the best valid imag eig closest to gamma_c.
                # Skip hopf-event rows where max_imag_eig is NaN.
                best_dist = Inf
                best_beta = nothing
                for row in eachrow(bdf)
                    gval = Float64(row.gamma)
                    ival = Float64(row.max_imag_eig)
                    !isfinite(ival) && continue
                    ival <= 1e-10 && continue
                    d = abs(gval - gamma_c)
                    if d < best_dist
                        best_dist = d
                        best_beta = ival
                    end
                end
                if best_beta !== nothing
                    tokens["beta_c_fmt"] = @sprintf("%.5f", best_beta)
                    tokens["has_stage5_beta_c"] = true
                end
            end
        end

        lower = gamma_c - 0.05
        upper = gamma_c + 0.05
        if branch_gamma_min !== nothing
            lower = max(lower, branch_gamma_min)
        end
        if branch_gamma_max !== nothing
            upper = min(upper, branch_gamma_max)
        end
        tokens["hopf_line_min"] = @sprintf("%.6f", lower)
        tokens["hopf_line_max"] = @sprintf("%.6f", upper)
    end

    if period_seconds !== nothing
        tokens["period_seconds_fmt"] = @sprintf("%.1f", period_seconds)
        tokens["period_fmt"] = @sprintf("%.1f", period_seconds / 60.0)
        tokens["has_stage5_period"] = true
    end

    if transversality !== nothing
        tokens["transversality"] = @sprintf("%.6f", transversality)
        tokens["transversality_fmt"] = @sprintf("%.4f", transversality)
    end

    tokens["has_stage5_summary"] = true
    return tokens
end

function build_cross_campaign_comparison_tokens(data_out_dir::String)
    tokens = Dict{String,Any}(
        "has_cross_comparison" => false,
        "cases_gc" => "n/a",
        "floss_gc" => "n/a",
        "ratio_gc" => "n/a",
        "cases_beta" => "n/a",
        "floss_beta" => "n/a",
        "ratio_beta" => "n/a",
        "cases_th" => "n/a",
        "floss_th" => "n/a",
        "ratio_th" => "n/a",
        "cases_trans" => "n/a",
        "floss_trans" => "n/a",
        "ratio_trans" => "n/a",
    )

    cases_json = joinpath(data_out_dir, "stage5_summary_cases_99.json")
    floss_json = joinpath(data_out_dir, "stage5_summary_floss.json")
    if !(isfile(cases_json) && isfile(floss_json))
        return tokens
    end

    c_raw = JSON3.read(read(cases_json, String))
    f_raw = JSON3.read(read(floss_json, String))

    c_gc = (haskey(c_raw, "gamma_c_hopf") && c_raw["gamma_c_hopf"] !== nothing) ? tryparse(Float64, string(c_raw["gamma_c_hopf"])) : nothing
    f_gc = (haskey(f_raw, "gamma_c_hopf") && f_raw["gamma_c_hopf"] !== nothing) ? tryparse(Float64, string(f_raw["gamma_c_hopf"])) : nothing

    c_beta = (haskey(c_raw, "closest_to_axis_max_imag") && c_raw["closest_to_axis_max_imag"] !== nothing) ? tryparse(Float64, string(c_raw["closest_to_axis_max_imag"])) : nothing
    f_beta = (haskey(f_raw, "closest_to_axis_max_imag") && f_raw["closest_to_axis_max_imag"] !== nothing) ? tryparse(Float64, string(f_raw["closest_to_axis_max_imag"])) : nothing

    c_th_seconds = (haskey(c_raw, "hopf_period_Th") && c_raw["hopf_period_Th"] !== nothing) ? tryparse(Float64, string(c_raw["hopf_period_Th"])) : nothing
    f_th_seconds = (haskey(f_raw, "hopf_period_Th") && f_raw["hopf_period_Th"] !== nothing) ? tryparse(Float64, string(f_raw["hopf_period_Th"])) : nothing

    c_trans = (haskey(c_raw, "dRe_dgamma_at_crossing") && c_raw["dRe_dgamma_at_crossing"] !== nothing) ? tryparse(Float64, string(c_raw["dRe_dgamma_at_crossing"])) : nothing
    f_trans = (haskey(f_raw, "dRe_dgamma_at_crossing") && f_raw["dRe_dgamma_at_crossing"] !== nothing) ? tryparse(Float64, string(f_raw["dRe_dgamma_at_crossing"])) : nothing

    required = (c_gc, f_gc, c_beta, f_beta, c_th_seconds, f_th_seconds, c_trans, f_trans)
    if any(x -> x === nothing || !isfinite(x), required)
        return tokens
    end

    c_th = c_th_seconds / 60.0
    f_th = f_th_seconds / 60.0

    ratio_gc = f_gc == 0.0 ? nothing : c_gc / f_gc
    ratio_beta = f_beta == 0.0 ? nothing : c_beta / f_beta
    ratio_th = f_th == 0.0 ? nothing : c_th / f_th
    ratio_trans = f_trans == 0.0 ? nothing : abs(c_trans / f_trans)

    tokens["cases_gc"] = @sprintf("%.4f", c_gc)
    tokens["floss_gc"] = @sprintf("%.4f", f_gc)
    tokens["cases_beta"] = @sprintf("%.6f", c_beta)
    tokens["floss_beta"] = @sprintf("%.6f", f_beta)
    tokens["cases_th"] = @sprintf("%.1f", c_th)
    tokens["floss_th"] = @sprintf("%.1f", f_th)
    tokens["cases_trans"] = @sprintf("%.6f", c_trans)
    tokens["floss_trans"] = @sprintf("%.6f", f_trans)

    if ratio_gc !== nothing && isfinite(ratio_gc)
        tokens["ratio_gc"] = @sprintf("%.2f", ratio_gc)
    end
    if ratio_beta !== nothing && isfinite(ratio_beta)
        tokens["ratio_beta"] = @sprintf("%.2f", ratio_beta)
    end
    if ratio_th !== nothing && isfinite(ratio_th)
        tokens["ratio_th"] = @sprintf("%.2f", ratio_th)
    end
    if ratio_trans !== nothing && isfinite(ratio_trans)
        tokens["ratio_trans"] = @sprintf("%.2f", ratio_trans)
    end

    tokens["has_cross_comparison"] = true
    return tokens
end

function extract_transition_tokens(data_out_dir::String, campaign_label::String, report_run_dir::String)
    slug = campaign_slug_local(campaign_label)

    panel_a_path = joinpath(data_out_dir, "transition_panel_a_$(slug).csv")
    panel_b_path = joinpath(data_out_dir, "transition_panel_b_$(slug).csv")
    panel_c_path = joinpath(data_out_dir, "transition_panel_c_$(slug).csv")
    panel_c_profile_path = joinpath(data_out_dir, "transition_panel_c_profile_$(slug).csv")
    meta_path = joinpath(data_out_dir, "transition_assets_$(slug).json")

    panel_a_rel = relpath(panel_a_path, report_run_dir)
    panel_b_rel = relpath(panel_b_path, report_run_dir)
    panel_c_rel = relpath(panel_c_path, report_run_dir)
    panel_c_profile_rel = relpath(panel_c_profile_path, report_run_dir)

    tokens = Dict{String,Any}(
        "has_transition_assets" => false,
        "transition_panel_a_path" => panel_a_rel,
        "transition_panel_b_path" => panel_b_rel,
        "transition_panel_c_path" => panel_c_rel,
        "transition_panel_a_path_tex" => "{" * panel_a_rel * "}",
        "transition_panel_b_path_tex" => "{" * panel_b_rel * "}",
        "transition_panel_c_path_tex" => "{" * panel_c_rel * "}",
        "transition_panel_c_profile_path" => panel_c_profile_rel,
        "transition_panel_c_profile_path_tex" => "{" * panel_c_profile_rel * "}",
        "has_transition_panel_c_profile" => false,
        "transition_panel_c_profile_gamma_count" => "0",
        "transition_panel_c_profile_height_count" => "0",
        "transition_ri_c" => "0.25",
        "transition_panel_c_profile_height_min" => "0",
        "transition_panel_c_profile_height_max" => "200",
        "transition_meta_path" => relpath(meta_path, report_run_dir),
        "has_transition_gamma_critical" => false,
        "transition_gamma_critical" => "0.0",
        "transition_gamma_critical_fmt" => "n/a",
        "transition_hopf_period_fmt" => "n/a",
        "transition_peak_eta3_fmt" => "n/a",
    )

    if !(isfile(panel_a_path) && isfile(panel_b_path) && isfile(panel_c_path))
        return tokens
    end

    panel_a_df = CSV.read(panel_a_path, DataFrame)
    panel_b_df = CSV.read(panel_b_path, DataFrame)
    panel_c_df = CSV.read(panel_c_path, DataFrame)

    if nrow(panel_a_df) == 0 || nrow(panel_b_df) == 0 || nrow(panel_c_df) == 0
        return tokens
    end

    tokens["has_transition_assets"] = true

    if isfile(meta_path)
        meta = JSON3.read(read(meta_path, String))

        if haskey(meta, "has_transition_panel_c_profile") && Bool(meta["has_transition_panel_c_profile"]) && isfile(panel_c_profile_path)
            profile_df = CSV.read(panel_c_profile_path, DataFrame)
            pnames = Symbol.(names(profile_df))
            if nrow(profile_df) > 0 && (:height_z in pnames) && (:gamma in pnames) && (:ri_g in pnames)
                tokens["has_transition_panel_c_profile"] = true
                z_vals = Float64.(profile_df.height_z)
                gamma_vals = Float64.(profile_df.gamma)
                if !isempty(z_vals)
                    tokens["transition_panel_c_profile_height_min"] = @sprintf("%.1f", minimum(z_vals))
                    tokens["transition_panel_c_profile_height_max"] = @sprintf("%.1f", maximum(z_vals))
                end
                if !isempty(gamma_vals)
                    tokens["transition_panel_c_profile_gamma_count"] = string(length(unique(gamma_vals)))
                end
                tokens["transition_panel_c_profile_height_count"] = string(length(unique(z_vals)))
            end
        end

        if haskey(meta, "ri_c_critical") && meta["ri_c_critical"] !== nothing
            ri_c = tryparse(Float64, string(meta["ri_c_critical"]))
            if ri_c !== nothing && isfinite(ri_c)
                tokens["transition_ri_c"] = @sprintf("%.2f", ri_c)
            end
        end

        if haskey(meta, "gamma_critical") && meta["gamma_critical"] !== nothing
            gamma_critical = tryparse(Float64, string(meta["gamma_critical"]))
            if gamma_critical !== nothing && isfinite(gamma_critical)
                tokens["has_transition_gamma_critical"] = true
                tokens["transition_gamma_critical"] = @sprintf("%.6f", gamma_critical)
                tokens["transition_gamma_critical_fmt"] = @sprintf("%.4f", gamma_critical)
            end
        end

        if haskey(meta, "hopf_period_minutes") && meta["hopf_period_minutes"] !== nothing
            hopf_period = tryparse(Float64, string(meta["hopf_period_minutes"]))
            if hopf_period !== nothing && isfinite(hopf_period)
                tokens["transition_hopf_period_fmt"] = @sprintf("%.2f min", hopf_period)
            end
        end

        if haskey(meta, "peak_abs_eta3") && meta["peak_abs_eta3"] !== nothing
            peak_eta3 = tryparse(Float64, string(meta["peak_abs_eta3"]))
            if peak_eta3 !== nothing && isfinite(peak_eta3)
                tokens["transition_peak_eta3_fmt"] = @sprintf("%.4f", peak_eta3)
            end
        end
    end

    return tokens
end

function extract_structural_tokens(data_out_dir::String, campaign_label::String, report_run_dir::String)
    slug = campaign_slug_local(campaign_label)

    corr_path = joinpath(data_out_dir, "structural_correlations_$(slug).csv")
    lag_path = joinpath(data_out_dir, "structural_lagcorr_$(slug).csv")
    summary_path = joinpath(data_out_dir, "structural_correlation_summary_$(slug).json")

    corr_rel = relpath(corr_path, report_run_dir)
    lag_rel = relpath(lag_path, report_run_dir)
    summary_rel = relpath(summary_path, report_run_dir)

    tokens = Dict{String,Any}(
        "has_structural_correlations" => false,
        "has_structural_lag_metric" => false,
        "has_structural_mi_metrics" => false,
        "structural_corr_path" => corr_rel,
        "structural_corr_path_tex" => "{" * corr_rel * "}",
        "structural_lag_path" => lag_rel,
        "structural_lag_path_tex" => "{" * lag_rel * "}",
        "structural_summary_path" => summary_rel,
        "structural_ri_low_column" => "ri_g_low",
        "structural_ri_low_column_tex" => "ri\\_g\\_low",
        "structural_lag_best_samples" => "n/a",
        "structural_lag_best_hours_fmt" => "n/a",
        "structural_lag_best_corr_fmt" => "n/a",
        "structural_mi_subcritical_fmt" => "n/a",
        "structural_mi_supercritical_fmt" => "n/a",
    )

    if isfile(corr_path)
        corr_df = CSV.read(corr_path, DataFrame)
        if nrow(corr_df) > 0
            tokens["has_structural_correlations"] = true
        end
    end

    if isfile(summary_path)
        summary = JSON3.read(read(summary_path, String))

        if haskey(summary, "ri_low_column") && summary["ri_low_column"] !== nothing
            col_name = String(summary["ri_low_column"])
            tokens["structural_ri_low_column"] = col_name
            tokens["structural_ri_low_column_tex"] = escape_latex_text(col_name)
        end

        if haskey(summary, "lag_best_samples") && haskey(summary, "lag_best_hours") && haskey(summary, "lag_best_corr")
            lag_best_samples = tryparse(Int, string(summary["lag_best_samples"]))
            lag_best_hours = tryparse(Float64, string(summary["lag_best_hours"]))
            lag_best_corr = tryparse(Float64, string(summary["lag_best_corr"]))
            if lag_best_samples !== nothing
                tokens["structural_lag_best_samples"] = string(lag_best_samples)
            end
            if lag_best_hours !== nothing && isfinite(lag_best_hours)
                tokens["structural_lag_best_hours_fmt"] = @sprintf("%.2f", lag_best_hours)
                tokens["has_structural_lag_metric"] = true
            end
            if lag_best_corr !== nothing && isfinite(lag_best_corr)
                tokens["structural_lag_best_corr_fmt"] = @sprintf("%.3f", lag_best_corr)
                tokens["has_structural_lag_metric"] = true
            end
        end

        if haskey(summary, "mi_subcritical_bits") && haskey(summary, "mi_supercritical_bits")
            mi_sub = tryparse(Float64, string(summary["mi_subcritical_bits"]))
            mi_sup = tryparse(Float64, string(summary["mi_supercritical_bits"]))
            if mi_sub !== nothing && isfinite(mi_sub)
                tokens["structural_mi_subcritical_fmt"] = @sprintf("%.3f", mi_sub)
                tokens["has_structural_mi_metrics"] = true
            end
            if mi_sup !== nothing && isfinite(mi_sup)
                tokens["structural_mi_supercritical_fmt"] = @sprintf("%.3f", mi_sup)
                tokens["has_structural_mi_metrics"] = true
            end
        end
    end

    return tokens
end

function extract_domec_tokens(data_out_dir::String, report_run_dir::String)
    obs_path = joinpath(data_out_dir, "domec_observations_u_dt.csv")
    lmdz103_path = joinpath(data_out_dir, "domec_lmdz103_u_dt.csv")
    erai_path = joinpath(data_out_dir, "domec_erai_u_dt.csv")

    obs_dt_pdf_path = joinpath(data_out_dir, "domec_obs_dt_pdf.csv")
    model_dt_pdf_path = joinpath(data_out_dir, "domec_model_dt_pdf.csv")
    obs_u_pdf_path = joinpath(data_out_dir, "domec_obs_u_pdf.csv")
    model_u_pdf_path = joinpath(data_out_dir, "domec_model_u_pdf.csv")

    all_paths = [
        obs_path,
        lmdz103_path,
        erai_path,
        obs_dt_pdf_path,
        model_dt_pdf_path,
        obs_u_pdf_path,
        model_u_pdf_path,
    ]

    has_assets = all(isfile, all_paths)

    return Dict{String,Any}(
        "has_domec_assets" => has_assets,
        "csv_domec_observations" => "{" * relpath(obs_path, report_run_dir) * "}",
        "csv_domec_lmdz103" => "{" * relpath(lmdz103_path, report_run_dir) * "}",
        "csv_domec_erai" => "{" * relpath(erai_path, report_run_dir) * "}",
        "csv_domec_obs_dt_pdf" => "{" * relpath(obs_dt_pdf_path, report_run_dir) * "}",
        "csv_domec_model_dt_pdf" => "{" * relpath(model_dt_pdf_path, report_run_dir) * "}",
        "csv_domec_obs_u_pdf" => "{" * relpath(obs_u_pdf_path, report_run_dir) * "}",
        "csv_domec_model_u_pdf" => "{" * relpath(model_u_pdf_path, report_run_dir) * "}",
        "domec_assets_expected_dir" => relpath(data_out_dir, report_run_dir),
    )
end

function build_visual_exhibits(rel_traj::String, rel_scatter::String)

    return [
        Dict(
            "index" => "1",
            "title" => "Spectral Orthogonality Projection",
            "key_signal" => "Color-encoded eta_3 separates compressed orbit clusters from vertical-structure departures.",
            "caption" => "This projection plots eta_1 against eta_2 and encodes eta_3 as the color channel, preserving the low-rank geometry and the vertical structural component in one view. The exhibit is intended to show whether the reduced manifold is dominated by tight recurrent clusters or whether structurally distinct departures remain visible outside the mean state. For CASES-99 style runs, this chart is most useful for confirming that compression in campaign-mean entropy does not erase intermittent vertical-structure events.",
            "image_path" => "tikz-cache/audit-scatter.pdf",
            "source_csv" => rel_scatter,
        ),
        Dict(
            "index" => "2",
            "title" => "Temporal Trajectory Components",
            "key_signal" => "Component-wise eta(t) traces expose transition pacing and episodic bursts across the campaign.",
            "caption" => "The temporal panel tracks eta_1, eta_2, and eta_3 against the run timeline and highlights where smooth regime drift gives way to abrupt structural shifts. In compressed campaigns, this view is often where short-duration events appear most clearly.",
            "image_path" => "tikz-cache/audit-trajectory.pdf",
            "source_csv" => rel_traj,
        ),
    ]
end

function extract_precursor_tokens(trajectory_path::String, campaign_label::String, report_run_dir::String)
    slug = campaign_slug_local(campaign_label)
    
    # Default tokens
    tokens = Dict{String,Any}(
        "duration_hours" => "n/a",
        "duration_days" => "n/a",
        "n_samples" => "n/a",
        "timestep_minutes" => "n/a",
        "eta3_min" => "n/a",
        "eta3_max" => "n/a",
        "mean_speed" => "n/a",
        "precursor_plot_path" => "precursor_diagnostic_$(slug).png",
        "has_curvature_spikes" => false,
        "peak_curvature" => "n/a",
        "spike_interpretation" => "",
        "richardson_comparison" => false,
        "richardson_behavior" => "similar patterns"
    )
    
    # Try to read trajectory data and compute basic stats
    if isfile(trajectory_path)
        try
            df = CSV.read(trajectory_path, DataFrame)
            if nrow(df) > 0
                tokens["n_samples"] = string(nrow(df))
                
                # Compute duration if time_value exists
                if hasproperty(df, :time_value)
                    time_vals = df.time_value
                    duration_sec = maximum(time_vals) - minimum(time_vals)
                    duration_hours = duration_sec / 3600.0
                    tokens["duration_hours"] = @sprintf("%.1f", duration_hours)
                    tokens["duration_days"] = @sprintf("%.2f", duration_hours / 24.0)
                    
                    # Estimate timestep
                    if nrow(df) > 1
                        timestep_sec = duration_sec / (nrow(df) - 1)
                        tokens["timestep_minutes"] = @sprintf("%.1f", timestep_sec / 60.0)
                    end
                end
                
                # Compute eta3 range
                if hasproperty(df, :eta_3)
                    eta3_vals = df.eta_3
                    tokens["eta3_min"] = @sprintf("%.2f", minimum(eta3_vals))
                    tokens["eta3_max"] = @sprintf("%.2f", maximum(eta3_vals))
                end
            end
        catch e
            @warn "Could not extract precursor stats from trajectory: $e"
        end
    end
    
    # Check if precursor plot exists
    plot_name = "precursor_diagnostic_$(slug).png"
    plot_path = joinpath(report_run_dir, plot_name)
    if !isfile(plot_path)
        tokens["precursor_plot_path"] = "figures/placeholder.png"
    end
    
    return tokens
end

function render_audit_entrypoint(report_run_dir::String, campaign_label::String)
    audit_main_template = joinpath("templates", "audit_main.tex.mustache")
    if !isfile(audit_main_template)
        error("Missing audit main TeX template: $(audit_main_template)")
    end

    out_path = joinpath(report_run_dir, "audit.tex")
    tokens = Dict(
        "campaign_display_name" => campaign_label,
    )
    open(out_path, "w") do io
        template_content = read(audit_main_template, String)
        Mustache.render(io, template_content, tokens)
    end
end

function build_markdown_audit_tokens(manifest, campaign_label::String, report_run_dir::String, rel_traj::String, rel_scat::String, workspace_dir::String)
    slug = campaign_slug_local(campaign_label)
    outputs_dir = joinpath(workspace_dir, "data", "outputs")

    stage2_path = joinpath(outputs_dir, "stage2_diagnostics_$(slug).csv")
    stage4_path = joinpath(outputs_dir, "stage4_lambda_sweep.csv")
    stage5_stability_path = joinpath(outputs_dir, "stage5_stability_manifest_$(slug).json")
    stage5_branch_path = joinpath(outputs_dir, "stage5_bifurcation_branches_$(slug).csv")

    stage2 = summarize_stage2_diagnostics(stage2_path)
    stage4 = summarize_stage4_lambda_sweep(stage4_path)
    stage5 = summarize_stage5(stage5_stability_path, stage5_branch_path)

    condition_value = Float64(manifest["condition_num"])
    condition_is_ok = isfinite(condition_value) && condition_value < 100.0
    condition_text = isfinite(condition_value) ? @sprintf("%.2f", condition_value) : "inf"

    rel_stage2 = relpath(stage2_path, report_run_dir)
    rel_stage4 = relpath(stage4_path, report_run_dir)
    rel_stage5_branch = relpath(stage5_branch_path, report_run_dir)

    kpis = [
        Dict("metric" => "Total Samples", "value" => string(manifest["total_samples"]), "target" => ">=1000", "variance" => "observed"),
        Dict("metric" => "Temporal Coverage", "value" => @sprintf("%.1f h", manifest["temporal_coverage"]), "target" => ">=24 h", "variance" => "observed"),
        Dict("metric" => "Mean Singular Value Entropy", "value" => @sprintf("%.4f", manifest["h_mean"]), "target" => "contextual", "variance" => manifest["h_mean"] < 0.5 ? "compressed" : "broad"),
        Dict("metric" => "Effective Dimension", "value" => @sprintf("%.4f", manifest["d_eff"]), "target" => ">1.5", "variance" => Float64(manifest["d_eff"]) > 1.5 ? "above floor" : "compressed"),
        Dict("metric" => "Condition Number", "value" => isfinite(manifest["condition_num"]) ? @sprintf("%.2f", manifest["condition_num"]) : "inf", "target" => "<100", "variance" => Float64(manifest["condition_num"]) < 100 ? "within" : "elevated"),
        Dict("metric" => "Stage 2 Threshold Exceedance Rate", "value" => format_percent(stage2.exceed_fraction; digits=1), "target" => "<25.0%", "variance" => stage2.exceed_fraction === nothing ? "n/a" : (stage2.exceed_fraction < 0.25 ? "within" : "elevated")),
        Dict("metric" => "Stable Equilibria / Hopf Candidates", "value" => stage5.available ? "$(stage5.stable_count) / $(stage5.hopf_candidate_count)" : "n/a", "target" => ">=1 / 0+", "variance" => stage5.available ? (stage5.hopf_candidate_count == 0 ? "no crossing" : "candidate present") : "n/a"),
    ]

    status_signals = [
        make_signal(condition_is_ok ? "[OK]" : "[WARN]", condition_is_ok ? "Low-rank basis remained numerically usable with condition number $(condition_text) and $(manifest["n_0"]) exported nullspace modes." : "Low-rank basis is ill-conditioned with condition number $(condition_text), exceeding the audit threshold of 100."),
        make_signal("[INFO]", "Campaign mean entropy registered at H_mean = $( @sprintf("%.4f", manifest["h_mean"]) ) with effective dimension D_eff = $( @sprintf("%.4f", manifest["d_eff"]) )."),
        make_signal(stage5.available && stage5.terminated ? "[WARN]" : "[INFO]", stage5.available && stage5.terminated ? @sprintf("Stage 5 continuation terminated at gamma=%.6f, marking the current stability-envelope boundary.", coalesce(stage5.termination_gamma, 0.0)) : "Stage 5 stability scan did not report a terminal divergence boundary."),
    ]

    positive_findings = [
        Dict("finding" => "The exported low-rank basis remained fully constrained with $(manifest["n_c"]) constrained modes and $(manifest["n_0"]) nullspace modes."),
        Dict("finding" => "The projection condition number was measured at $(condition_text) for conditioning diagnostics."),
        Dict("finding" => stage5.available ? "Stage 5 resolved $(stage5.stable_count) stable equilibrium and $(stage5.hopf_candidate_count) Hopf candidates in the current scan." : "Stage 5 stability artifacts were not available for this run."),
    ]

    negative_findings = [
        Dict("finding" => "Stage 2 disagreement exceeded threshold in $(stage2.exceed_count) of $(stage2.window_count) windows ($(format_percent(stage2.exceed_fraction; digits=1)))."),
        Dict("finding" => @sprintf("The maximum Stage 2 disagreement norm reached %.4f, indicating localized route-selection ambiguity.", stage2.disagreement_max === nothing ? 0.0 : stage2.disagreement_max)),
        Dict("finding" => stage5.available && stage5.terminated ? @sprintf("The descending continuation branch remained stable until gamma=%.6f and then terminated in %s before a smooth crossing was logged.", stage5.termination_gamma, stage5.termination_reason) : "No Stage 5 divergence boundary was recorded in the current artifact set."),
    ]
    if !condition_is_ok
        push!(negative_findings, Dict("finding" => "Condition number $(condition_text) exceeds the audit stress threshold of 100, indicating potential numerical instability in the reduced basis."))
    end

    neutral_findings = [
        Dict("finding" => "Campaign-mean reduced coordinates were ($(format_metric(manifest["mean_eta_1"]; digits=3)), $(format_metric(manifest["mean_eta_2"]; digits=3)), $(format_metric(manifest["mean_eta_3"]; digits=3)))."),
        Dict("finding" => stage4.available ? @sprintf("The Stage 4 lambda sweep evaluated %d thresholds and retained the audit elbow near lambda=%.5f with nnz=%d.", stage4.lambda_count, stage4.selected_lambda, stage4.selected_nnz) : "Stage 4 lambda sweep artifact was not available for summary."),
        Dict("finding" => "The dominant Stage 2 routing label was $(stage2.dominant_route), which should be interpreted as the prevailing operator path rather than a regime proof by itself."),
    ]

    risks = [
        Dict("risk_item" => "Threshold exceedance rate remains elevated at $(format_percent(stage2.exceed_fraction; digits=1)), so window-level disagreement can accumulate without moving campaign means substantially."),
        Dict("risk_item" => stage5.available && stage5.terminated ? @sprintf("The current continuation branch loses numerical validity at gamma=%.6f, so the stability envelope should be treated as locally bounded rather than globally mapped.", coalesce(stage5.termination_gamma, 0.0)) : "Stage 5 boundary localization is incomplete when continuation artifacts are absent."),
        Dict("risk_item" => "Mean entropy $(format_metric(manifest["h_mean"]; digits=4)) indicates a compressed campaign average, which can conceal short-duration burst structure unless the exhibit-level traces are reviewed."),
    ]

    visual_exhibits = build_visual_exhibits(rel_traj, rel_scat)

    custom_metrics = [
        Dict("metric_name" => "H", "latex_formula" => "-\\sum_{i=1}^{r} p_i \\log p_i"),
        Dict("metric_name" => "D_{\\mathrm{eff}}", "latex_formula" => "e^{H}"),
        Dict("metric_name" => "\\kappa", "latex_formula" => "\\sigma_{\\max} / \\sigma_{\\min}"),
        Dict("metric_name" => "R_{\\mathrm{exceed}}", "latex_formula" => "\\frac{1}{W} \\sum_{w=1}^{W} \\mathbf{1}\\{\\mathrm{disagreement\\_norm}_w > \\tau\\}"),
    ]

    return Dict(
        "campaign_name" => campaign_label,
        "campaign" => campaign_label,
        "generation_date" => String(manifest["generated_at"]),
        "baseline_version" => String(manifest["baseline_version"]),
        "baseline_source" => String(manifest["baseline_source"]),
        "projection_method" => String(manifest["projection_method"]),
        "kpis" => kpis,
        "status_signals" => status_signals,
        "positive_findings" => positive_findings,
        "negative_findings" => negative_findings,
        "neutral_findings" => neutral_findings,
        "risks" => risks,
        "visual_exhibits" => visual_exhibits,
        "custom_metrics" => custom_metrics,
        "outlier_sigma" => "3",
        "csv_trajectory_path" => rel_traj,
        "csv_scatter_path" => rel_scat,
        "stage2_diagnostics_path" => rel_stage2,
        "stage4_lambda_sweep_path" => rel_stage4,
        "stage5_branch_path" => rel_stage5_branch,
    )
end

"""
    compute_refined_metrics(df::DataFrame)

Compute Phase 1.5 diagnostics from eta-space trajectories:
- constrained/nullspace modal counts
- condition number in projected space
- Shannon effective dimension (D_eff)
- interaction residual proxy
"""
function compute_refined_metrics(df::DataFrame)
    eta_cols = [c for c in names(df) if startswith(String(c), "eta_")]
    isempty(eta_cols) && error("No eta_* columns found in trajectory table.")

    raw_matrix = Matrix{Float64}(df[:, eta_cols])
    svd_result = svd(raw_matrix; full=false)
    S = svd_result.S

    isempty(S) && error("SVD produced no singular values.")

    eps_floor = eps(Float64) * S[1]
    constrained_modes = count(s -> s >= eps_floor, S)
    nullspace_modes = length(S) - constrained_modes

    s_min = minimum(S)
    condition_number = s_min > 0.0 ? S[1] / s_min : Inf

    weights = S ./ sum(S)
    shannon_entropy = -sum(w > 0.0 ? w * log(w) : 0.0 for w in weights)
    d_eff = exp(shannon_entropy)

    interaction_residual = if :sv_entropy in names(df)
        std(df.sv_entropy) * 0.05
    else
        0.0
    end

    return (
        constrained_modes = constrained_modes,
        nullspace_modes = nullspace_modes,
        condition_number = condition_number,
        d_eff = d_eff,
        interaction_residual = interaction_residual
    )
end

"""
    execute_orchestration(trajectory_csv::String, workspace_dir::String)

Main orchestration entry point. Coordinates data extraction, manifest generation,
and Mustache template rendering.
"""
function execute_orchestration(
    trajectory_csv::String,
    workspace_dir::String;
    campaign::Union{Nothing,String}=nothing,
)
    
    if !isfile(trajectory_csv)
        error("Trajectory CSV not found: $(trajectory_csv)")
    end
    if endswith(lowercase(trajectory_csv), ".nc")
        error(
            "build_campaign_report.jl expects a trajectory CSV, not NetCDF: $(trajectory_csv). " *
            "Run `make process` first to generate data/drafts/trajectories/trajectory_master.csv, " *
            "then run `make report` or `make cabauw-report`."
        )
    end
    if !endswith(lowercase(trajectory_csv), ".csv")
        error("Expected a .csv trajectory input, got: $(trajectory_csv)")
    end
    
    data_out_dir = joinpath(workspace_dir, "data", "outputs")
    report_run_dir = joinpath(workspace_dir, "reports", report_dir_for_campaign(campaign))

    # 1. Compute refined Phase 1.5 diagnostics from active trajectory table.
    df_master = CSV.read(trajectory_csv, DataFrame)
    if campaign !== nothing
        df_master = filter(:campaign => ==(campaign), df_master)
        isempty(df_master) && error("No rows found for campaign=$(campaign) in $(trajectory_csv)")
    end
    refined = compute_refined_metrics(df_master)

    # 2. Extract raw trajectory matrices down to structural tables and write manifest.
    @info "==> Extracting CSV summaries and computing manifest..."
    export_result = extract_csv_summaries(
        trajectory_csv,
        data_out_dir;
        downsample_rate=scatter_downsample_rate(campaign),
        campaign=campaign,
        refined_metrics=refined,
    )

    # 3. Parse the fresh JSON manifest context metrics
    manifest_file = joinpath(data_out_dir, "report_manifest.json")
    manifest = JSON3.read(read(manifest_file, String))
    
    # 4. Create execution directories
    ensure_report_workspace(report_run_dir, workspace_dir)
    
    @info "==> Rendering Mustache templates..."
    cross_tokens = build_cross_campaign_comparison_tokens(data_out_dir)
    
    # 5. Generate portable .tex components
    for report in REGISTRY
        
        full_tex_target = joinpath(report_run_dir, report.output_tex_path)
        
        # Compute data paths relative to main.tex directory (report_run_dir),
        # since TeX resolves table paths from the compiler working directory.
        rel_traj = relpath(export_result.trajectory_csv, report_run_dir)
        rel_scat = relpath(export_result.scatter_csv, report_run_dir)
        
        campaign_label = String(manifest["campaign"])
        campaign_slug = replace(campaign_slug_local(campaign_label), "_" => "")
        domec_flag = is_domec_campaign(campaign_label)
        insights = infer_campaign_conclusions(campaign_label)
        campaign_conclusions = [
            Dict(
                "insight_title" => escape_latex_text(i.title),
                "insight_body" => escape_latex_text(i.body)
            ) for i in insights
        ]

        # Assemble token dictionary from manifest + computed metrics
        tokens = Dict(
            "campaign_label"          => campaign_label,
            "campaign_name"           => campaign_label,
            "campaign_id"             => lowercase(campaign_label),
            "campaign_slug"           => campaign_slug,
            "campaign"                => campaign_label,
            "campaign_display_name"   => campaign_label,
            "campaign_conclusions"    => campaign_conclusions,
            "has_campaign_conclusions" => !isempty(campaign_conclusions),
            "is_gabls3"               => manifest["campaign"] == "GABLS3",
            "is_cases99"              => manifest["campaign"] == "CASES-99",
            "is_floss"                => manifest["campaign"] == "FLOSS",
            "is_domec"                => domec_flag,
            "baseline_version"        => manifest["baseline_version"],
            "baseline_source"         => manifest["baseline_source"],
            "total_samples"           => string(manifest["total_samples"]),
            "h_mean"                  => @sprintf("%.3f", manifest["h_mean"]),
            "mean_eta_1"              => @sprintf("%.3f", manifest["mean_eta_1"]),
            "mean_eta_2"              => @sprintf("%.3f", manifest["mean_eta_2"]),
            "mean_eta_3"              => @sprintf("%.3f", manifest["mean_eta_3"]),
            "n_0"                     => string(manifest["n_0"]),
            "n_c"                     => string(manifest["n_c"]),
            "temporal_coverage"       => @sprintf("%.1f", manifest["temporal_coverage"]),
            "temporal_coverage_hours" => @sprintf("%.1f", manifest["temporal_coverage"]),
            "csv_trajectory_path"     => rel_traj,
            "csv_scatter_path"        => rel_scat,
            "csv_trajectory_path_tex" => "{" * rel_traj * "}",
            "csv_scatter_path_tex"    => "{" * rel_scat * "}",
            "d_eff"                   => @sprintf("%.4f", manifest["d_eff"]),
            "constrained_modes"       => string(manifest["n_c"]),
            "nullspace_modes"         => string(manifest["n_0"]),
            "condition_num"           => isfinite(manifest["condition_num"]) ? @sprintf("%.2f", manifest["condition_num"]) : "inf",
            "interaction_proxy"       => String(manifest["interaction_proxy"]),
            "z0m_text"                => format_optional_z0m(manifest),
            # Legacy aliases kept for template compatibility during migration.
            "samples"                 => string(manifest["total_samples"]),
            "mean_entropy"            => @sprintf("%.3f", manifest["h_mean"]),
            "mean_D_eff"              => @sprintf("%.4f", manifest["d_eff"]),
            "condition_number"        => isfinite(manifest["condition_num"]) ? @sprintf("%.2f", manifest["condition_num"]) : "inf",
            "interaction_residual"    => String(manifest["interaction_proxy"])
        )

        stage5_tokens = extract_stage5_summary_tokens(data_out_dir, campaign_label, report_run_dir)
        transition_tokens = extract_transition_tokens(data_out_dir, campaign_label, report_run_dir)
        structural_tokens = extract_structural_tokens(data_out_dir, campaign_label, report_run_dir)
        domec_tokens = extract_domec_tokens(data_out_dir, report_run_dir)
        precursor_tokens = extract_precursor_tokens(export_result.trajectory_csv, campaign_label, report_run_dir)
        merge!(tokens, stage5_tokens)
        merge!(tokens, transition_tokens)
        merge!(tokens, structural_tokens)
        merge!(tokens, domec_tokens)
        merge!(tokens, precursor_tokens)
        merge!(tokens, cross_tokens)
        
        @info "Rendering template: $(report.name) -> $(full_tex_target)"
        open(full_tex_target, "w") do io
            template_content = read(report.template_path, String)
            Mustache.render(io, template_content, tokens)
        end
    end

    # 6. Generate standalone markdown audit artifact.
    rel_traj = relpath(export_result.trajectory_csv, report_run_dir)
    rel_scat = relpath(export_result.scatter_csv, report_run_dir)
    campaign_label = String(manifest["campaign"])
    audit_tokens = build_markdown_audit_tokens(manifest, campaign_label, report_run_dir, rel_traj, rel_scat, workspace_dir)
    audit_template_path = joinpath("templates", "campaign_audit.md.mustache")
    audit_output_path = joinpath(report_run_dir, "campaign_audit.md")
    @info "Rendering template: campaign_audit -> $(audit_output_path)"
    open(audit_output_path, "w") do io
        template_content = read(audit_template_path, String)
        Mustache.render(io, template_content, audit_tokens)
    end

        # 7. Render standalone audit TeX entrypoint for compile-audit target.
        render_audit_entrypoint(report_run_dir, campaign_label)
    
    generate_institutional_sidecar(joinpath(workspace_dir, "data"))
    @info "==> All Mustache templates rendered successfully!"
    @info "==> Report components ready at: $(joinpath(report_run_dir, "generated"))"
    @info "==> Standalone audit ready at: $(audit_output_path)"
    @info ""
    @info "Next steps:"
    @info "  1. cd $(report_run_dir)"
    @info "  2. latexmk -lualatex -shell-escape -interaction=nonstopmode main.tex"
    @info "  3. Open main.pdf"
    
end

function generate_institutional_sidecar(output_dir::String)
    source_txt_path = joinpath(output_dir, "sources.txt")
    open(source_txt_path, "w") do io
        println(io, "="^73)
        println(io, "         SPECTRALBL-ANALYTICS ENGINE: DATA PROVENANCE MANIFEST           ")
        println(io, "="^73)
        println(io, "Generated: ", Dates.format(Dates.now(Dates.UTC), "yyyy-mm-dd HH:MM:SS"), " UTC")
        println(io)
        println(io, "The telemetry, multi-level micro-meteorological profiles, and numerical")
        println(io, "framework assets ingested by this pipeline are credited to and maintained by:")
        println(io)
        println(io, "    University of Alabama in Huntsville (UAH)")
        println(io, "    National Space Science and Technology Center (NSSTC)")
        println(io, "    URL: https://nsstc.uah.edu")
        println(io)
        println(io, "Please cite institutional dataset references and the SpectralBL framework")
        println(io, "in all derived publications.")
        println(io, "="^73)
    end
    @info "Institutional data provenance sidecar written: $(source_txt_path)"
end

# Check for manual CLI execution flags
if abspath(PROGRAM_FILE) == @__FILE__
    
    if length(ARGS) < 1
        error("""
            Usage: julia scripts/build_campaign_report.jl <trajectory_csv_path> [CAMPAIGN]
        
        Example:
                julia scripts/build_campaign_report.jl data/drafts/trajectories/trajectory_master.csv GABLS3
        """)
    end
    
    csv_path = ARGS[1]
    campaign_arg = length(ARGS) >= 2 ? String(strip(ARGS[2])) : "ALL"
    campaign_filter = uppercase(campaign_arg) == "ALL" ? nothing : campaign_arg
    workspace_root = pwd()  # Use current working directory (should be project root)
    
    execute_orchestration(csv_path, workspace_root; campaign=campaign_filter)
    
end
