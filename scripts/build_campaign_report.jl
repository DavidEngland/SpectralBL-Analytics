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
    ReportDefinition("regime", "templates/regime_decomposition.tex.mustache", "generated/regime.tex")
]

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
function execute_orchestration(trajectory_csv::String, workspace_dir::String)
    
    if !isfile(trajectory_csv)
        error("Trajectory CSV not found: $(trajectory_csv)")
    end
    
    data_out_dir = joinpath(workspace_dir, "data", "outputs")
    report_run_dir = joinpath(workspace_dir, "reports", "cases99_run")
    
    # 1. Extract raw trajectory matrices down to structural tables
    @info "==> Extracting CSV summaries and computing manifest..."
    export_result = extract_csv_summaries(trajectory_csv, data_out_dir; downsample_rate=10)
    
    # 2. Parse the fresh JSON manifest context metrics
    manifest_file = joinpath(data_out_dir, "report_manifest.json")
    manifest = JSON3.read(read(manifest_file, String))

    # 2b. Compute refined Phase 1.5 diagnostics directly from active trajectory table
    df_master = CSV.read(trajectory_csv, DataFrame)
    refined = compute_refined_metrics(df_master)
    
    # 3. Create execution directories
    mkpath(joinpath(report_run_dir, "generated"))
    mkpath(joinpath(report_run_dir, "tikz-cache"))
    
    @info "==> Rendering Mustache templates..."
    
    # 4. Generate portable .tex components
    for report in REGISTRY
        
        full_tex_target = joinpath(report_run_dir, report.output_tex_path)
        
        # Compute data paths relative to main.tex directory (report_run_dir),
        # since TeX resolves table paths from the compiler working directory.
        rel_traj = relpath(export_result.trajectory_csv, report_run_dir)
        rel_scat = relpath(export_result.scatter_csv, report_run_dir)
        
        # Assemble token dictionary from manifest + computed metrics
        tokens = Dict(
            "campaign_name"           => manifest["campaign"],
            "campaign_id"             => lowercase(manifest["campaign"]),
            "campaign"                => manifest["campaign"],
            "baseline_version"        => manifest["baseline_version"],
            "baseline_source"         => manifest["baseline_source"],
            "samples"                 => string(manifest["samples"]),
            "mean_entropy"            => @sprintf("%.3f", manifest["mean_sv_entropy"]),
            "mean_eta_1"              => @sprintf("%.3f", export_result.mean_eta1),
            "mean_eta_2"              => @sprintf("%.3f", export_result.mean_eta2),
            "mean_eta_3"              => @sprintf("%.3f", export_result.mean_eta3),
            "temporal_coverage_hours" => @sprintf("%.1f", manifest["temporal_coverage_seconds"] / 3600.0),
            "csv_trajectory_path"     => rel_traj,
            "csv_scatter_path"        => rel_scat,
            "mean_D_eff"              => @sprintf("%.4f", refined.d_eff),
            "constrained_modes"       => string(refined.constrained_modes),
            "nullspace_modes"         => string(refined.nullspace_modes),
            "condition_number"        => isfinite(refined.condition_number) ? @sprintf("%.2f", refined.condition_number) : "inf",
            "interaction_residual"    => @sprintf("%.6f", refined.interaction_residual)
        )
        
        @info "Rendering template: $(report.name) -> $(full_tex_target)"
        open(full_tex_target, "w") do io
            template_content = read(report.template_path, String)
            Mustache.render(io, template_content, tokens)
        end
    end
    
    @info "==> All Mustache templates rendered successfully!"
    @info "==> Report components ready at: $(joinpath(report_run_dir, "generated"))"
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
        Usage: julia scripts/build_campaign_report.jl <trajectory_csv_path>
        
        Example:
          julia scripts/build_campaign_report.jl data/drafts/diagnostories/trajectory_master.csv
        """)
    end
    
    csv_path = ARGS[1]
    workspace_root = pwd()  # Use current working directory (should be project root)
    
    execute_orchestration(csv_path, workspace_root)
    
end
