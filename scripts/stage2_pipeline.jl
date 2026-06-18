#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

push!(LOAD_PATH, joinpath(pwd(), "src"))

using CSV
using DataFrames
using Printf
using Statistics
using SpectralBL_Stage2

function campaign_slug(campaign::String)
    safe = lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    return isempty(safe) ? "campaign" : safe
end

function canonical_campaign_token(token::String)
    t = uppercase(strip(token))
    if t in ("ARCTIC_HLBL", "ARCTIC-HLBL", "ARCTIC", "ARCTIC_AMPLIFICATION")
        return "ARCTIC-AMPLIFICATION"
    elseif t in ("CASES_99",)
        return "CASES-99"
    elseif t in ("FLOSS_I", "FLOSS-I", "FLOSS_II", "FLOSS-II")
        return "FLOSS"
    end
    return strip(token)
end

function require_columns(df::DataFrame, cols::Vector{Symbol})
    present = Set(Symbol.(names(df)))
    missing_cols = [c for c in cols if !(c in present)]
    if !isempty(missing_cols)
        error("Missing required columns for Stage 2 pipeline: $(join(String.(missing_cols), ", "))")
    end
end

function run_stage2_pipeline(
    trajectory_csv::String;
    campaign::String="ALL",
    window_size::Int=256,
    step_size::Int=128,
    var_threshold::Float64=0.15,
    gamma_crit::Float64=0.5,
)
    isfile(trajectory_csv) || error("Trajectory CSV not found: $(trajectory_csv)")

    df = CSV.read(trajectory_csv, DataFrame)
    require_columns(df, [:campaign, :eta_1, :eta_2, :eta_3])

    if !(:time_value in Set(Symbol.(names(df))))
        df.time_value = collect(1.0:nrow(df))
    end

    selected = uppercase(strip(campaign))
    if selected != "ALL"
        canonical = canonical_campaign_token(campaign)
        df = filter(:campaign => ==(canonical), df)
    end
    if nrow(df) == 0
        available = join(sort(unique(String.(CSV.read(trajectory_csv, DataFrame).campaign))), ", ")
        error("No rows available for Stage 2 processing with campaign=$(campaign). Available campaigns: $(available)")
    end

    sort!(df, [:campaign, :time_value])

    packets = DataFrame(
        campaign=String[],
        window_start=Int[],
        window_end=Int[],
        time_start=Float64[],
        time_end=Float64[],
        var_R=Float64[],
        var_Omega=Float64[],
        route_class=String[],
        tau_linear=Int[],
        tau_ami=Union{Missing, Int}[],
        selected_tau=Int[],
        selection_reason=String[],
        disagreement_norm=Float64[],
        is_valid=Bool[],
        failure_reason=String[],
        wsindy_norm=Float64[],
        tikhonov_norm=Float64[],
    )

    diagnostics = DataFrame(
        campaign=String[],
        window_start=Int[],
        window_end=Int[],
        disagreement_norm=Float64[],
        exceeds_threshold=Bool[],
        route_class=String[],
    )

    for camp in unique(df.campaign)
        sub = filter(:campaign => ==(camp), df)
        eta = Matrix{Float64}(sub[:, [:eta_1, :eta_2, :eta_3]])
        times = Vector{Float64}(sub.time_value)

        n = size(eta, 1)
        if n < window_size
            @warn "Skipping campaign due to insufficient rows for configured window_size." campaign=camp n_rows=n window_size=window_size
            continue
        end

        for start_idx in 1:step_size:(n - window_size + 1)
            end_idx = start_idx + window_size - 1
            eta_w = eta[start_idx:end_idx, :]
            t_w = times[start_idx:end_idx]

            packet = process_stage2_window(
                eta_w,
                t_w,
                String(camp),
                start_idx,
                end_idx;
                var_threshold=var_threshold,
                gamma_crit=gamma_crit,
            )

            push!(packets, (
                packet.campaign,
                packet.window_start,
                packet.window_end,
                packet.time_start,
                packet.time_end,
                packet.var_R,
                packet.var_Omega,
                packet.route_class,
                packet.tau_linear,
                packet.tau_ami,
                packet.selected_tau,
                packet.selection_reason,
                packet.disagreement_norm,
                packet.is_valid,
                packet.failure_reason,
                packet.wsindy_norm,
                packet.tikhonov_norm,
            ))

            push!(diagnostics, (
                packet.campaign,
                packet.window_start,
                packet.window_end,
                packet.disagreement_norm,
                packet.disagreement_norm > gamma_crit,
                packet.route_class,
            ))
        end
    end

    nrow(packets) == 0 && error("No stage2 packets produced. Adjust window_size/step_size or input data.")

    out_dir = joinpath("data", "outputs")
    mkpath(out_dir)
    slug = selected == "ALL" ? "all" : campaign_slug(campaign)

    packet_path = joinpath(out_dir, "stage2_packets_$(slug).csv")
    diag_path = joinpath(out_dir, "stage2_diagnostics_$(slug).csv")
    CSV.write(packet_path, packets)
    CSV.write(diag_path, diagnostics)

    println("Stage 2 packets written: $(packet_path)")
    println("Stage 2 diagnostics written: $(diag_path)")
    println(@sprintf("Windows processed: %d | disagreement mean=%.4f", nrow(packets), mean(packets.disagreement_norm)))

    return packet_path, diag_path
end

if abspath(PROGRAM_FILE) == @__FILE__
    trajectory_csv = length(ARGS) >= 1 ? ARGS[1] : joinpath("data", "drafts", "trajectories", "trajectory_master.csv")
    campaign = length(ARGS) >= 2 ? ARGS[2] : "ALL"
    window_size = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 256
    step_size = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 128

    run_stage2_pipeline(
        trajectory_csv;
        campaign=campaign,
        window_size=window_size,
        step_size=step_size,
    )
end
