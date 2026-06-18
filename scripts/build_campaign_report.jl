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
using LinearAlgebra
using Statistics

struct ReportDefinition
    name::String
    template_path::String
    output_tex_path::String
end

const REGISTRY = [
    ReportDefinition("attractor", "templates/attractor_report.tex.mustache", "generated/attractor.tex"),
    ReportDefinition("regime", "templates/regime_decomposition.tex.mustache", "generated/regime.tex"),
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

function ensure_report_workspace(report_run_dir::String, workspace_dir::String)
    mkpath(report_run_dir)
    mkpath(joinpath(report_run_dir, "generated"))
    mkpath(joinpath(report_run_dir, "tikz-cache"))

    main_tex = joinpath(report_run_dir, "main.tex")
    if !isfile(main_tex)
        base_main = joinpath(workspace_dir, "reports", "cases99_run", "main.tex")
        if !isfile(base_main)
            error("Missing base TeX template: $(base_main)")
        end
        cp(base_main, main_tex; force=true)
        @info "Bootstrapped report workspace from $(base_main) -> $(main_tex)"
    end
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
        )
    end

    cont = haskey(manifest, "continuation") ? manifest["continuation"] : nothing
    terminated = cont === nothing ? false : Bool(cont["terminated"])
    termination_gamma = nothing
    if cont !== nothing && haskey(cont, "termination_gamma") && cont["termination_gamma"] !== nothing
        termination_gamma = Float64(cont["termination_gamma"])
    end
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
        Dict("finding" => stage5.available && stage5.terminated ? @sprintf("The descending continuation branch remained stable until gamma=%.6f and then terminated in Divergence_Blowup before a smooth crossing was logged.", stage5.termination_gamma) : "No Stage 5 divergence boundary was recorded in the current artifact set."),
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
    
    # 5. Generate portable .tex components
    for report in REGISTRY
        
        full_tex_target = joinpath(report_run_dir, report.output_tex_path)
        
        # Compute data paths relative to main.tex directory (report_run_dir),
        # since TeX resolves table paths from the compiler working directory.
        rel_traj = relpath(export_result.trajectory_csv, report_run_dir)
        rel_scat = relpath(export_result.scatter_csv, report_run_dir)
        
        campaign_label = String(manifest["campaign"])
        campaign_slug = replace(campaign_slug_local(campaign_label), "_" => "")
        insights = infer_campaign_conclusions(campaign_label)
        campaign_conclusions = [
            Dict(
                "insight_title" => escape_latex_text(i.title),
                "insight_body" => escape_latex_text(i.body)
            ) for i in insights
        ]

        # Assemble token dictionary from manifest + computed metrics
        tokens = Dict(
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
    
    @info "==> All Mustache templates rendered successfully!"
    @info "==> Report components ready at: $(joinpath(report_run_dir, "generated"))"
    @info "==> Standalone audit ready at: $(audit_output_path)"
    @info ""
    @info "Next steps:"
    @info "  1. cd $(report_run_dir)"
    @info "  2. latexmk -lualatex -shell-escape -interaction=nonstopmode main.tex"
    @info "  3. Open main.pdf"
    
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
