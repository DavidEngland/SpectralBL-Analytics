module ExportPipeline

using CSV
using DataFrames
using LinearAlgebra
using Statistics
using JSON3
using Dates
using Printf

export extract_csv_summaries, write_report_manifest

function campaign_slug(campaign::Union{Nothing,String})
    if campaign === nothing
        return "all"
    end
    safe = lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    return isempty(safe) ? "campaign" : safe
end

"""
    extract_csv_summaries(trajectory_csv::String, output_dir::String; downsample_rate::Int=10, campaign::Union{Nothing,String}=nothing)

Read trajectory CSV from extraction pipeline and emit manifest + downsampled tables
ready for Mustache template injection.
"""
function extract_csv_summaries(
    trajectory_csv::String,
    output_dir::String;
    downsample_rate::Int=10,
    campaign::Union{Nothing,String}=nothing,
    refined_metrics::Union{Nothing,NamedTuple}=nothing,
)
    
    if !isfile(trajectory_csv)
        error("Trajectory CSV not found: $(trajectory_csv)")
    end
    
    mkpath(output_dir)
    
    # Load the trajectory table produced by extract_attractor_diagnostics.jl
    df = CSV.read(trajectory_csv, DataFrame)
    
    if campaign !== nothing
        df = filter(:campaign => ==(campaign), df)
        isempty(df) && error("No rows found for campaign=$(campaign) in $(trajectory_csv)")
    end

    slug = campaign_slug(campaign)

    # Extract regime trajectories (full resolution for TeX TikZ plots)
    trajectory_out = joinpath(output_dir, "regime_trajectories_$(slug).csv")
    CSV.write(trajectory_out, select(df, :, Not([:generated_at_utc, :baseline_source])))
    @info "Trajectory table written: $(trajectory_out)"
    
    # Create downsampled scatter table (for faster TikZ rendering)
    idx = 1:downsample_rate:nrow(df)
    scatter_df = df[idx, [:eta_1, :eta_2, :eta_3, :sv_entropy, :campaign, :time_value]]
    scatter_out = joinpath(output_dir, "regime_scatterplots_$(slug).csv")
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
        manifest_path;
        refined_metrics=refined_metrics,
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

function write_report_manifest(
    df::DataFrame,
    campaign::String,
    source_path::String,
    output_path::String;
    refined_metrics::Union{Nothing,NamedTuple}=nothing,
)
    
    mean_entropy = mean(df.sv_entropy)
    mean_eta_mag = mean(sqrt.(df.eta_1.^2 .+ df.eta_2.^2 .+ df.eta_3.^2))
    
    condition_num = refined_metrics === nothing ? NaN : Float64(refined_metrics.condition_number)
    d_eff = refined_metrics === nothing ? NaN : Float64(refined_metrics.d_eff)
    interaction_proxy = refined_metrics === nothing ? "0.000000" : @sprintf("%.6f", Float64(refined_metrics.interaction_residual))
    n_c = refined_metrics === nothing ? 0 : Int(refined_metrics.constrained_modes)
    n_0 = refined_metrics === nothing ? 0 : Int(refined_metrics.nullspace_modes)
    temporal_coverage_seconds = maximum(df.time_value) - minimum(df.time_value)
    temporal_coverage_hours = temporal_coverage_seconds / 3600.0
    mean_eta_1 = mean(df.eta_1)
    mean_eta_2 = mean(df.eta_2)
    mean_eta_3 = mean(df.eta_3)

    manifest = Dict(
        "campaign" => campaign,
        "baseline_version" => df.baseline_version[1],
        "baseline_source" => df.baseline_source[1],
        "generated_at" => string(Dates.now(Dates.UTC)),
        "source_trajectory_csv" => source_path,
        "projection_method" => "SVD / Low-Rank Attractor Decomposition",
        # Canonical keys for downstream report schema.
        "total_samples" => nrow(df),
        "h_mean" => mean_entropy,
        "temporal_coverage" => temporal_coverage_hours,
        "mean_eta_1" => mean_eta_1,
        "mean_eta_2" => mean_eta_2,
        "mean_eta_3" => mean_eta_3,
        "n_c" => n_c,
        "n_0" => n_0,
        "condition_num" => condition_num,
        "d_eff" => d_eff,
        "interaction_proxy" => interaction_proxy,
        # Legacy aliases kept for compatibility with existing consumers.
        "samples" => nrow(df),
        "mean_sv_entropy" => mean_entropy,
        "mean_eta_magnitude" => mean_eta_mag,
        "temporal_coverage_seconds" => temporal_coverage_seconds
    )
    
    write(output_path, JSON3.write(manifest))
    @info "Report manifest written: $(output_path)"
end

end # module
