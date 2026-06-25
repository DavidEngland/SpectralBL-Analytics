#!/usr/bin/env julia
# scripts/precursor_diagnostic.jl
#
# Phase 1: Geometric Precursor Analysis - CENTRAL SCIENTIFIC TEST
#
# This script answers the critical question: "Which signal moves first?"
#
# Tests whether trajectory geometry in (η₁, η₂, η₃) space predicts regime
# transitions before classical metrics (Ri, TKE) or state-based indicators (η₃ thresholds).
#
# Usage:
#   julia scripts/precursor_diagnostic.jl [campaign_name]
#
# Example:
#   julia scripts/precursor_diagnostic.jl gabls3

using Pkg
Pkg.activate(".")

using DataFrames
using CSV
using Statistics
using StatsBase: percentile
using Plots
using Printf

# Add src to load path
push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using GeometricPrecursors

"""
    identify_transition_events(df::DataFrame)

Identifies physical transition events in the time series.

Returns a Dict with event markers:
- `:turbulence_recovery` - when turbulence resumes
- `:heat_flux_recovery` - when surface heat flux increases
- `:richardson_collapse` - when Ri drops below critical threshold
"""
function identify_transition_events(df::DataFrame)
    events = Dict{Symbol, Vector{Float64}}()
    
    # Placeholder: In real analysis, these would be detected from actual data
    # For now, return empty vectors (user will need to customize based on campaign)
    events[:turbulence_recovery] = Float64[]
    events[:heat_flux_recovery] = Float64[]
    events[:richardson_collapse] = Float64[]
    
    println("\n⚠️  NOTE: Transition event detection not yet implemented.")
    println("   Manual inspection of time series needed to identify:")
    println("   - Turbulence recovery events")
    println("   - Heat flux recovery events")
    println("   - Richardson number collapse events")
    println("   These markers should be added to this function for full analysis.\n")
    
    return events
end

"""
    compute_lead_times(results::PrecursorResults, events::Dict, threshold_percentile::Float64=90.0)

Computes lead time for each precursor indicator relative to physical events.

Lead time = how many minutes before event does indicator exceed threshold?

Returns DataFrame with lead times for each indicator × event combination.
"""
function compute_lead_times(results::PrecursorResults, events::Dict; threshold_percentile::Float64=90.0)
    lead_times = DataFrame(
        Indicator = String[],
        Category = String[],
        Event = String[],
        LeadTime_min = Float64[],
        Threshold = Float64[]
    )
    
    # Define thresholds for each indicator (e.g., 90th percentile = "anomalous")
    indicators = [
        ("Var_5", results.var_5, "A"),
        ("Var_15", results.var_15, "A"),
        ("Var_30", results.var_30, "A"),
        ("Var_60", results.var_60, "A"),
        ("AC1_5", results.ac1_5, "A"),
        ("AC1_15", results.ac1_15, "A"),
        ("AC1_30", results.ac1_30, "A"),
        ("AC1_60", results.ac1_60, "A"),
        ("Speed", results.speed, "B"),
        ("Acceleration", results.acceleration, "B"),
        ("Curvature", results.curvature, "B"),
        ("Ri_mean", results.ri_mean, "Classical")
    ]
    
    for (event_name, event_times) in events
        if isempty(event_times)
            continue
        end
        
        for (ind_name, signal, category) in indicators
            valid_signal = signal[.!isnan.(signal)]
            if isempty(valid_signal)
                continue
            end
            
            threshold = percentile(valid_signal, threshold_percentile)
            
            # For each event, find earliest exceedance
            for event_time in event_times
                # Look backward from event
                idx = findlast(t -> t <= event_time, results.time)
                if idx === nothing
                    continue
                end
                
                # Find first exceedance before event
                for i in idx:-1:1
                    if !isnan(signal[i]) && signal[i] > threshold
                        lead_time_sec = event_time - results.time[i]
                        lead_time_min = lead_time_sec / 60.0
                        
                        push!(lead_times, (ind_name, category, string(event_name), lead_time_min, threshold))
                        break
                    end
                end
            end
        end
    end
    
    return lead_times
end

"""
    plot_precursor_time_series(results::PrecursorResults, events::Dict, campaign::String)

Generates multi-panel time-series plots showing all precursor indicators
with vertical markers for physical transition events.

This is the central diagnostic plot answering: "Which signal moves first?"
"""
function plot_precursor_time_series(results::PrecursorResults, events::Dict, campaign::String; output_dir::String="reports")
    # Convert time to hours for readability
    time_hours = (results.time .- results.time[1]) ./ 3600.0
    
    # Create output directory if needed
    mkpath(output_dir)
    
    println("\nGenerating time-series plots...")
    
    # Panel 1: Category A - Variance at multiple scales
    p1 = plot(time_hours, results.var_5, label="Var τ=5min", alpha=0.7, lw=2)
    plot!(time_hours, results.var_15, label="Var τ=15min", alpha=0.7, lw=2)
    plot!(time_hours, results.var_30, label="Var τ=30min", alpha=0.7, lw=2)
    plot!(time_hours, results.var_60, label="Var τ=60min", alpha=0.7, lw=2)
    title!("Category A: Multi-Scale Variance (η₃)")
    xlabel!("Time (hours)")
    ylabel!("Variance")
    
    # Panel 2: Category A - Autocorrelation at multiple scales
    p2 = plot(time_hours, results.ac1_5, label="AC₁ τ=5min", alpha=0.7, lw=2)
    plot!(time_hours, results.ac1_15, label="AC₁ τ=15min", alpha=0.7, lw=2)
    plot!(time_hours, results.ac1_30, label="AC₁ τ=30min", alpha=0.7, lw=2)
    plot!(time_hours, results.ac1_60, label="AC₁ τ=60min", alpha=0.7, lw=2)
    title!("Category A: Lag-1 Autocorrelation (η₃)")
    xlabel!("Time (hours)")
    ylabel!("AC₁")
    hline!([1.0], ls=:dash, color=:red, label="Critical slowing (AC₁→1)")
    
    # Panel 3: Category B - Geometric indicators
    p3 = plot(time_hours, results.speed, label="Speed v(t)", alpha=0.7, lw=2, color=:blue)
    plot!(twinx(), time_hours, results.acceleration, label="Acceleration a(t)", alpha=0.7, lw=2, color=:orange)
    title!("Category B: Trajectory Speed & Acceleration")
    xlabel!("Time (hours)")
    ylabel!("Speed ||dη/dt||", color=:blue)
    
    # Panel 4: Category B - Curvature (the key novelty)
    p4 = plot(time_hours, results.curvature, label="Curvature κ(t)", alpha=0.7, lw=2, color=:purple)
    title!("Category B: Trajectory Curvature (COORDINATE-INDEPENDENT)")
    xlabel!("Time (hours)")
    ylabel!("κ = ||η'×η''|| / ||η'||³")
    
    # Panel 5: Classical metrics for comparison
    p5 = plot(time_hours, results.ri_mean, label="Mean Ri", alpha=0.7, lw=2, color=:darkgreen)
    title!("Classical: Richardson Number")
    xlabel!("Time (hours)")
    ylabel!("Ri")
    hline!([0.25], ls=:dash, color=:red, label="Critical Ri ≈ 0.25")
    
    # Add event markers to all panels
    for (event_name, event_times) in events
        if !isempty(event_times)
            event_hours = (event_times .- results.time[1]) ./ 3600.0
            for eh in event_hours
                vline!(p1, [eh], ls=:dashdot, color=:black, alpha=0.5, label="")
                vline!(p2, [eh], ls=:dashdot, color=:black, alpha=0.5, label="")
                vline!(p3, [eh], ls=:dashdot, color=:black, alpha=0.5, label="")
                vline!(p4, [eh], ls=:dashdot, color=:black, alpha=0.5, label="")
                vline!(p5, [eh], ls=:dashdot, color=:black, alpha=0.5, label="")
            end
        end
    end
    
    # Combine into multi-panel figure
    combined = plot(p1, p2, p3, p4, p5, layout=(5,1), size=(1200, 1400), 
                   margin=5Plots.mm, legend=:outertopright)
    
    output_file = joinpath(output_dir, "precursor_diagnostic_$(campaign).png")
    savefig(combined, output_file)
    println("✓ Saved: $output_file")
    
    return combined
end

"""
    main(campaign::String)

Main execution function for Phase 1 geometric precursor diagnostic.

This is the CENTRAL SCIENTIFIC TEST:
- If geometric indicators (Category B) consistently lead physical transitions,
  we've proven the manifold captures dynamical structure.
- If not, reassess before scaling to 50+ campaigns.
"""
function main(campaign::String="gabls3")
    println("="^70)
    println("Phase 1: Geometric Precursor Analysis - CENTRAL SCIENTIFIC TEST")
    println("="^70)
    println("Campaign: $(uppercase(campaign))")
    println("Question: Which signal moves first?")
    println()
    
    # Locate trajectory file
    data_dir = joinpath(@__DIR__, "..", "data", "outputs")
    trajectory_file = joinpath(data_dir, "regime_trajectories_$(campaign).csv")
    
    if !isfile(trajectory_file)
        error("Trajectory file not found: $trajectory_file\n" *
              "Available campaigns: cases_99, gabls3, floss, bllast")
    end
    
    println("Loading trajectory data...")
    println("  File: $trajectory_file")
    
    # Compute all precursor indicators
    # Time scales: τ = [5, 15, 30, 60] minutes (fixed a priori)
    tau_minutes = [5, 15, 30, 60]
    results = analyze_precursors(trajectory_file; tau_minutes=tau_minutes)
    
    # Identify transition events (manual for now)
    events = identify_transition_events(CSV.read(trajectory_file, DataFrame))
    
    # Compute lead times
    if !isempty(events) && any(!isempty(v) for v in values(events))
        println("\nComputing lead times...")
        lead_times = compute_lead_times(results, events)
        
        if nrow(lead_times) > 0
            println("\n" * "="^70)
            println("LEAD TIME RANKING (minutes before physical transition)")
            println("="^70)
            println(lead_times)
            
            # Save results
            output_dir = joinpath(@__DIR__, "..", "reports", "$(campaign)_run")
            mkpath(output_dir)
            CSV.write(joinpath(output_dir, "precursor_lead_times.csv"), lead_times)
            println("\n✓ Saved lead time table")
        else
            println("\n⚠️  No lead times computed (events not yet marked)")
        end
    end
    
    # Generate diagnostic plots
    output_dir = joinpath(@__DIR__, "..", "reports", "$(campaign)_run")
    plot_precursor_time_series(results, events, campaign; output_dir=output_dir)
    
    # Summary statistics
    println("\n" * "="^70)
    println("PRECURSOR SUMMARY STATISTICS")
    println("="^70)
    
    println("\nCategory A: Critical-Transition Indicators")
    println(@sprintf("  Var (τ=15min):  mean=%.4f, std=%.4f", 
                    mean(skipmissing(results.var_15)), std(skipmissing(results.var_15))))
    println(@sprintf("  AC₁ (τ=15min):  mean=%.4f, std=%.4f", 
                    mean(skipmissing(results.ac1_15)), std(skipmissing(results.ac1_15))))
    
    println("\nCategory B: Geometric Indicators (NOVELTY CLAIM)")
    println(@sprintf("  Speed v(t):     mean=%.4e, std=%.4e", 
                    mean(skipmissing(results.speed)), std(skipmissing(results.speed))))
    println(@sprintf("  Acceleration:   mean=%.4e, std=%.4e", 
                    mean(skipmissing(results.acceleration)), std(skipmissing(results.acceleration))))
    println(@sprintf("  Curvature κ(t): mean=%.4e, std=%.4e (%.1f%% valid)", 
                    mean(skipmissing(results.curvature)), std(skipmissing(results.curvature)),
                    100.0 * sum(.!isnan.(results.curvature)) / length(results.curvature)))
    
    println("\nClassical Metrics")
    println(@sprintf("  Mean Ri:        mean=%.4f, std=%.4f", 
                    mean(skipmissing(results.ri_mean)), std(skipmissing(results.ri_mean))))
    
    println("\n" * "="^70)
    println("NEXT STEPS")
    println("="^70)
    println("1. Manually identify transition events in the time series")
    println("2. Update identify_transition_events() with event timestamps")
    println("3. Re-run to compute lead times")
    println("4. If Category B (geometric) leads Category A & classical metrics:")
    println("   → PROCEED to Phases 2-6 (multi-site validation)")
    println("5. If no consistent geometric precursor signal:")
    println("   → REASSESS project direction before scaling to 50+ campaigns")
    println()
    
    return results
end

# Parse command line argument
if length(ARGS) >= 1
    campaign = ARGS[1]
else
    campaign = "gabls3"  # Default to GABLS3 for first diagnostic
end

# Run analysis
results = main(campaign)
