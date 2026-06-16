# scripts/extract_attractor_diagnostics.jl
using Pkg
Pkg.activate(".")

# Ensure local source directory is within load paths
push!(LOAD_PATH, joinpath(pwd(), "src"))

using IngestionFormatters
using AttractorDiagnostics
using DataFrames
using Dates
using LinearAlgebra

include("DiagnosticsBaseline.jl")
using .DiagnosticsBaseline

function parse_campaign_arg(arg::String)
    normalized = uppercase(strip(arg))
    if normalized == "ALL"
        return [:CASES_99, :GABLS3, :ARCTIC_AMPLIFICATION]
    elseif normalized in ("CASES-99", "CASES_99")
        return [:CASES_99]
    elseif normalized == "GABLS3"
        return [:GABLS3]
    elseif normalized in ("ARCTIC-AMPLIFICATION", "ARCTIC_AMPLIFICATION", "ARCTIC")
        return [:ARCTIC_AMPLIFICATION]
    end
    error("Unsupported campaign selector: $(arg). Use ALL, CASES-99, GABLS3, or ARCTIC-AMPLIFICATION.")
end

println("=================================================================")
println("   RUNNING ATTRACTOR DIAGNOSTICS & P-FEM GEOMETRY GENERATION")
println("=================================================================\n")

# 1. Define computational p-FEM grid (e.g., 30 structural node coordinates up to 300 meters)
# Grid spacing can be refined heavily near the ground to capture stable gradients
pfem_grid = [0.0, 2.0, 5.0, 10.0, 20.0, 35.0, 50.0, 75.0, 100.0, 150.0, 200.0, 250.0, 300.0]

rows = DataFrame(
    campaign=String[],
    time_value=Float64[],
    z0m=Float64[],
    eta_1=Float64[],
    eta_2=Float64[],
    eta_3=Float64[],
    sv_entropy=Float64[],
    source_file=String[],
    sample_index=Int[],
    generated_at_utc=String[],
    baseline_version=String[],
    baseline_source=String[],
)

campaign_selector = length(ARGS) >= 1 ? ARGS[1] : "ALL"
campaigns_to_run = parse_campaign_arg(campaign_selector)
println("Campaign selector: $(campaign_selector)")

for campaign in campaigns_to_run
    # Fetch campaign parameters
    config = get_campaign_geometry(campaign)
    println("Processing Configuration Target: $(config.name)")
    println(" -> Measurement levels (z): $(config.tower_heights) meters")
    println(" -> Local Momentum Roughness (z0m): $(config.z0m) m")

    # 2. Build Observation Operator
    A = build_observation_operator(pfem_grid, config)
    println(" -> Generated Operator Matrix A size: $(size(A, 1))x$(size(A, 2))")

    # 3. Load real campaign observations and derive low-rank basis from profiles
    U_r, samples = load_campaign_samples(campaign, pfem_grid; data_root="data", rank=3)
    println(" -> Loaded $(length(samples)) valid samples from campaign netCDF source(s)")

    lambda = 1e-4
    for (idx, sample) in enumerate(samples)
        eta_hat = ridge_fit(A, U_r, sample.tower_vector, lambda)
        H = calculate_sv_entropy(abs.(eta_hat))

        push!(rows, (
            config.name,
            sample.time_value,
            config.z0m,
            eta_hat[1],
            eta_hat[2],
            eta_hat[3],
            H,
            sample.source_file,
            idx,
            string(Dates.now(Dates.UTC)),
            BASELINE_VERSION,
            BASELINE_SOURCE,
        ))
    end

    first_eta = rows[rows.campaign .== config.name, [:eta_1, :eta_2, :eta_3]][1, :]
    println(" -> Example η̂ sample: [$(round(first_eta.eta_1, digits=4)), $(round(first_eta.eta_2, digits=4)), $(round(first_eta.eta_3, digits=4))]")
    println(" -> Completed campaign processing\n")
end

master_csv = write_trajectory_csvs(rows; output_dir=joinpath("data", "drafts", "trajectories"))
curated_csv = write_curated_diagnostics_csv(rows; output_path=joinpath("data", "drafts", "diagnostics_curated.csv"))
println("Pipeline verification complete. Wrote trajectory outputs via $(master_csv).")
println("Curated diagnostics source updated at $(curated_csv).")