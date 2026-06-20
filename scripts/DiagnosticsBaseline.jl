module DiagnosticsBaseline

using CSV
using DataFrames
using Dates
using Printf
using Statistics

export BASELINE_VERSION,
       BASELINE_SOURCE,
       write_trajectory_csvs,
    write_curated_diagnostics_csv,
       load_master_trajectory,
       clean_diagnostics_frame,
       diagnostics_summary,
       diagnostics_summary_macros,
       tex_provenance_comments

const BASELINE_VERSION = "v0.1"
const BASELINE_SOURCE = "spectralbl-attractor"

function write_trajectory_csvs(df::DataFrame; output_dir::String="data/drafts/trajectories")
    required = ["campaign", "time_value", "eta_1", "eta_2", "eta_3", "sv_entropy", "source_file", "sample_index", "generated_at_utc", "baseline_version", "baseline_source"]
    ensure_columns(df, required)

    mkpath(output_dir)
    master_path = joinpath(output_dir, "trajectory_master.csv")
    CSV.write(master_path, df)

    for campaign in unique(df.campaign)
        sub = filter(:campaign => ==(campaign), df)
        campaign_key = lowercase(replace(String(campaign), "-" => "_"))
        campaign_path = joinpath(output_dir, "trajectory_$(campaign_key).csv")
        CSV.write(campaign_path, sub)
    end

    return master_path
end

function write_curated_diagnostics_csv(df::DataFrame; output_path::String=joinpath("data", "drafts", "diagnostics_curated.csv"))
    required = ["campaign", "time_value", "eta_1", "eta_2", "eta_3", "sv_entropy", "source_file"]
    ensure_columns(df, required)

    curated = select(df, [:campaign, :time_value, :source_file])
    curated.D_eff = sqrt.(df.eta_1 .^ 2 .+ df.eta_2 .^ 2 .+ df.eta_3 .^ 2)
    curated.F_W = copy(df.sv_entropy)
    curated.chi_N = abs.(df.eta_3) ./ (abs.(df.eta_1) .+ abs.(df.eta_2) .+ 1e-8)
    if all(c -> c in names(df), ["theta_star", "L_obukhov", "cheby_residual_norm", "cheby_fit_quality"])
        curated.theta_star = copy(df.theta_star)
        curated.L_obukhov = copy(df.L_obukhov)
        curated.cheby_residual_norm = copy(df.cheby_residual_norm)
        curated.cheby_fit_quality = copy(df.cheby_fit_quality)
    end

    mkpath(dirname(output_path))
    CSV.write(output_path, curated)
    return output_path
end

function load_master_trajectory(data_dir::String)
    curated_path = joinpath(data_dir, "drafts", "diagnostics_curated.csv")
    if !isfile(curated_path)
        error("Missing curated diagnostics CSV at $(curated_path)")
    end
    return CSV.read(curated_path, DataFrame), curated_path
end

function clean_diagnostics_frame(raw_df::DataFrame)
    required = ["D_eff", "F_W", "chi_N"]
    missing_cols = [c for c in required if !(c in names(raw_df))]
    if !isempty(missing_cols)
        return raw_df, DataFrame(), 0, missing_cols
    end

    finite_mask = map(eachrow(raw_df)) do r
        isfinite(Float64(r.D_eff)) && isfinite(Float64(r.F_W)) && isfinite(Float64(r.chi_N))
    end

    clean_df = raw_df[finite_mask, :]
    dropped_rows = nrow(raw_df) - nrow(clean_df)
    filter_info = DataFrame(metric=["D_eff", "F_W", "chi_N"], status=["finite", "finite", "finite"])

    return clean_df, filter_info, dropped_rows, String[]
end

function diagnostics_summary(clean_df::DataFrame; early_count::Int=3024)
    samples = nrow(clean_df)
    split_idx = clamp(early_count, 1, samples)
    early_df = clean_df[1:split_idx, :]
    late_df = split_idx < samples ? clean_df[split_idx+1:end, :] : clean_df[split_idx:split_idx, :]

    return (
        samples=samples,
        d_eff=(mean=mean(clean_df.D_eff), early=mean(early_df.D_eff), late=mean(late_df.D_eff)),
        f_w=(mean=mean(clean_df.F_W), early=mean(early_df.F_W), late=mean(late_df.F_W)),
        chi_n=(mean=mean(clean_df.chi_N), early=mean(early_df.chi_N), late=mean(late_df.chi_N)),
    )
end

function diagnostics_summary_macros(clean_df::DataFrame; early_count::Int=3024)
    summary = diagnostics_summary(clean_df; early_count=early_count)
    macros = Dict{String, String}()

    macros["dEffMean"] = @sprintf("%.2f", summary.d_eff.mean)
    macros["dEffEarly"] = @sprintf("%.2f", summary.d_eff.early)
    macros["dEffLate"] = @sprintf("%.2f", summary.d_eff.late)

    macros["fWMean"] = @sprintf("%.3f", summary.f_w.mean)
    macros["fWEarly"] = @sprintf("%.3f", summary.f_w.early)
    macros["fWLate"] = @sprintf("%.3f", summary.f_w.late)

    macros["chiNMean"] = @sprintf("%.3f", summary.chi_n.mean)
    macros["chiNEarly"] = @sprintf("%.3f", summary.chi_n.early)
    macros["chiNLate"] = @sprintf("%.3f", summary.chi_n.late)

    macros["diagnosticSamples"] = string(summary.samples)
    return macros
end

function tex_provenance_comments(samples::Int, source_path::String)
    generated_at = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    return [
        "% Baseline-Version: $(BASELINE_VERSION)",
        "% Baseline-Source: $(BASELINE_SOURCE)",
        "% Samples-Used: $(samples)",
        "% Curated-CSV: $(source_path)",
        "% Generated-UTC: $(generated_at)",
    ]
end

function ensure_columns(df::DataFrame, cols::Vector{String})
    missing_cols = [c for c in cols if !(c in names(df))]
    if !isempty(missing_cols)
        error("Missing required columns: $(join(missing_cols, ", "))")
    end
end

end # module
