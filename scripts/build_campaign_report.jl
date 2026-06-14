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
    ReportDefinition("conclusions", "templates/conclusions_and_diagnostics.tex.mustache", "generated/conclusions_and_diagnostics.tex")
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
    end

    # Fallback: sanitize arbitrary campaign labels into a stable folder name.
    safe = lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    isempty(safe) && (safe = "campaign")
    return "$(safe)_run"
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
        
        # Assemble token dictionary from manifest + computed metrics
        tokens = Dict(
            "campaign_name"           => manifest["campaign"],
            "campaign_id"             => lowercase(manifest["campaign"]),
            "campaign"                => manifest["campaign"],
            "is_gabls3"               => manifest["campaign"] == "GABLS3",
            "is_cases99"              => manifest["campaign"] == "CASES-99",
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
