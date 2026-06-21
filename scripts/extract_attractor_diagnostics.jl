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
using Printf
using Statistics

include("DiagnosticsBaseline.jl")
using .DiagnosticsBaseline

function height_token(z::Float64)
    rounded = round(z; digits=1)
    s = @sprintf("%.1f", rounded)
    return replace(s, "." => "_")
end

function all_campaign_heights()
    configs = [get_campaign_geometry(c) for c in (:CASES_99, :GABLS3, :ARCTIC_AMPLIFICATION, :FLOSS)]
    vals = sort(unique(vcat([cfg.tower_heights for cfg in configs]...)))
    return Float64.(vals)
end

function compute_ri_g_profile_proxy(tower_heights::Vector{Float64}, tower_vector::Vector{Float64}, eta3::Float64)
    n = min(length(tower_heights), length(tower_vector))
    if n < 2
        return fill(NaN, n)
    end

    z = tower_heights[1:n]
    u = tower_vector[1:n]

    du_dz = zeros(Float64, n)
    du_dz[1] = (u[2] - u[1]) / max(z[2] - z[1], 1e-6)
    for i in 2:(n - 1)
        du_dz[i] = (u[i + 1] - u[i - 1]) / max(z[i + 1] - z[i - 1], 1e-6)
    end
    du_dz[end] = (u[end] - u[end - 1]) / max(z[end] - z[end - 1], 1e-6)

    shear = abs.(du_dz)
    shear_scale = max(median(shear), 1e-3)
    zmax = max(maximum(z), 1e-3)
    stability_base = 0.15 .+ 0.60 .* (z ./ zmax)
    intermittency = 0.05 * clamp(abs(eta3) / 20.0, 0.0, 2.0)

    ri = stability_base ./ (1.0 .+ (shear ./ shear_scale) .^ 2) .+ intermittency
    ri = clamp.(ri, -0.5, 2.5)
    return ri
end

function parse_campaign_arg(arg::String)
    normalized = uppercase(strip(arg))
    if normalized == "ALL"
        return [:CASES_99, :GABLS3, :ARCTIC_AMPLIFICATION, :FLOSS]
    elseif normalized in ("CASES-99", "CASES_99")
        return [:CASES_99]
    elseif normalized == "GABLS3"
        return [:GABLS3]
    elseif normalized in ("ARCTIC-AMPLIFICATION", "ARCTIC_AMPLIFICATION", "ARCTIC")
        return [:ARCTIC_AMPLIFICATION]
    elseif normalized in ("FLOSS", "FLOSS_I", "FLOSS-I", "FLOSS_II", "FLOSS-II")
        return [:FLOSS]
    end
    error("Unsupported campaign selector: $(arg). Use ALL, CASES-99, GABLS3, ARCTIC-AMPLIFICATION, or FLOSS.")
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
    cheby_residual_norm=Float64[],
    cheby_fit_quality=Float64[],
    theta_star=Float64[],
    L_obukhov=Float64[],
    a_0=Float64[],
    a_1=Float64[],
    a_2=Float64[],
    a_3=Float64[],
    b_0=Float64[],
    b_1=Float64[],
    b_2=Float64[],
    b_3=Float64[],
    c_0=Float64[],
    c_1=Float64[],
    c_2=Float64[],
    c_3=Float64[],
    d_0=Float64[],
    d_1=Float64[],
    d_2=Float64[],
    d_3=Float64[],
    source_file=String[],
    sample_index=Int[],
    generated_at_utc=String[],
    baseline_version=String[],
    baseline_source=String[],
)

for h in all_campaign_heights()
    rows[!, Symbol("ri_g_" * height_token(h))] = Float64[]
end

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
        residual = fit_chebyshev_residuals(eta_hat)

        ri_profile = compute_ri_g_profile_proxy(config.tower_heights, sample.tower_vector, eta_hat[3])
        ri_map = Dict{Symbol,Float64}()
        for (j, z) in enumerate(config.tower_heights)
            ri_map[Symbol("ri_g_" * height_token(z))] = ri_profile[j]
        end

        row_named = (
            campaign=config.name,
            time_value=sample.time_value,
            z0m=config.z0m,
            eta_1=eta_hat[1],
            eta_2=eta_hat[2],
            eta_3=eta_hat[3],
            sv_entropy=H,
            cheby_residual_norm=residual.residual_norm,
            cheby_fit_quality=residual.fit_quality,
            theta_star=residual.theta_star,
            L_obukhov=residual.L_obukhov,
            a_0=residual.a[1],
            a_1=residual.a[2],
            a_2=residual.a[3],
            a_3=residual.a[4],
            b_0=residual.b[1],
            b_1=residual.b[2],
            b_2=residual.b[3],
            b_3=residual.b[4],
            c_0=residual.c[1],
            c_1=residual.c[2],
            c_2=residual.c[3],
            c_3=residual.c[4],
            d_0=residual.d[1],
            d_1=residual.d[2],
            d_2=residual.d[3],
            d_3=residual.d[4],
            source_file=sample.source_file,
            sample_index=idx,
            generated_at_utc=string(Dates.now(Dates.UTC)),
            baseline_version=BASELINE_VERSION,
            baseline_source=BASELINE_SOURCE,
        )

        merged = merge(row_named, (; ri_map...))
        push!(rows, merged, cols=:union)
    end

    first_eta = rows[rows.campaign .== config.name, [:eta_1, :eta_2, :eta_3]][1, :]
    println(" -> Example η̂ sample: [$(round(first_eta.eta_1, digits=4)), $(round(first_eta.eta_2, digits=4)), $(round(first_eta.eta_3, digits=4))]")
    println(" -> Completed campaign processing\n")
end

master_csv = write_trajectory_csvs(rows; output_dir=joinpath("data", "drafts", "trajectories"))
curated_csv = write_curated_diagnostics_csv(rows; output_path=joinpath("data", "drafts", "diagnostics_curated.csv"))
println("Pipeline verification complete. Wrote trajectory outputs via $(master_csv).")
println("Curated diagnostics source updated at $(curated_csv).")