#!/usr/bin/env julia
# scripts/build_campaign_report.jl
# Orchestration runner: wires ExportPipeline -> Mustache templates -> TeX compilation

using Pkg
Pkg.activate(".")

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src", "io"))

using ExportPipeline
using JSON3
using Mustache
using Printf

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
    
    # 3. Create execution directories
    mkpath(joinpath(report_run_dir, "generated"))
    mkpath(joinpath(report_run_dir, "tikz-cache"))
    
    @info "==> Rendering Mustache templates..."
    
    # 4. Generate portable .tex components
    for report in REGISTRY
        
        full_tex_target = joinpath(report_run_dir, report.output_tex_path)
        
        # Calculate localized relative paths for structural decoupling
        # (so TeX files can find CSV data regardless of compilation CWD)
        rel_traj = relpath(export_result.trajectory_csv, dirname(full_tex_target))
        rel_scat = relpath(export_result.scatter_csv, dirname(full_tex_target))
        
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
            "csv_scatter_path"        => rel_scat
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
