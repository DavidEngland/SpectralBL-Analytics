module ExportPipeline

using CSV
using DataFrames
using LinearAlgebra
using Statistics
using JSON3
using Dates

export extract_csv_summaries, write_report_manifest

"""
    extract_csv_summaries(trajectory_csv::String, output_dir::String; downsample_rate::Int=10)

Read trajectory CSV from extraction pipeline and emit manifest + downsampled tables
ready for Mustache template injection.
"""
function extract_csv_summaries(trajectory_csv::String, output_dir::String; downsample_rate::Int=10)
    
    if !isfile(trajectory_csv)
        error("Trajectory CSV not found: $(trajectory_csv)")
    end
    
    mkpath(output_dir)
    
    # Load the trajectory table produced by extract_attractor_diagnostics.jl
    df = CSV.read(trajectory_csv, DataFrame)
    
    # Extract regime trajectories (full resolution for TeX TikZ plots)
    trajectory_out = joinpath(output_dir, "regime_trajectories.csv")
    CSV.write(trajectory_out, select(df, :, Not([:generated_at_utc, :baseline_source])))
    @info "Trajectory table written: $(trajectory_out)"
    
    # Create downsampled scatter table (for faster TikZ rendering)
    idx = 1:downsample_rate:nrow(df)
    scatter_df = df[idx, [:eta_1, :eta_2, :eta_3, :sv_entropy, :campaign, :time_value]]
    scatter_out = joinpath(output_dir, "regime_scatterplots.csv")
    CSV.write(scatter_out, scatter_df)
    @info "Scatter table written (downsampled 1:$(downsample_rate)): $(scatter_out)"
    
    # Compute summary metrics
    mean_eta1 = mean(df.eta_1)
    mean_eta2 = mean(df.eta_2)
    mean_eta3 = mean(df.eta_3)
    mean_entropy = mean(df.sv_entropy)
    n_samples = nrow(df)
    campaigns = unique(df.campaign)
    
    # Write manifest JSON
    manifest_path = joinpath(output_dir, "report_manifest.json")
    write_report_manifest(
        df,
        String(campaigns[1]),
        trajectory_csv,
        manifest_path
    )
    
    return (
        trajectory_csv = trajectory_out,
        scatter_csv = scatter_out,
        manifest = manifest_path,
        mean_eta1 = mean_eta1,
        mean_eta2 = mean_eta2,
        mean_eta3 = mean_eta3,
        mean_entropy = mean_entropy,
        n_samples = n_samples
    )
end

function write_report_manifest(df::DataFrame, campaign::String, source_path::String, output_path::String)
    
    mean_entropy = mean(df.sv_entropy)
    mean_eta_mag = mean(sqrt.(df.eta_1.^2 .+ df.eta_2.^2 .+ df.eta_3.^2))
    
    manifest = Dict(
        "campaign" => campaign,
        "baseline_version" => df.baseline_version[1],
        "baseline_source" => df.baseline_source[1],
        "generated_at" => string(Dates.now(Dates.UTC)),
        "source_trajectory_csv" => source_path,
        "projection_method" => "SVD / Low-Rank Attractor Decomposition",
        "samples" => nrow(df),
        "mean_sv_entropy" => mean_entropy,
        "mean_eta_magnitude" => mean_eta_mag,
        "temporal_coverage_seconds" => maximum(df.time_value) - minimum(df.time_value)
    )
    
    write(output_path, JSON3.write(manifest))
    @info "Report manifest written: $(output_path)"
end

end # module
