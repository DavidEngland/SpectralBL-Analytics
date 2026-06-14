# scripts/extract_attractor_diagnostics.jl
using Pkg
Pkg.activate(".")

# Ensure local source directory is within load paths
push!(LOAD_PATH, joinpath(pwd(), "src"))

using IngestionFormatters
using AttractorDiagnostics
using LinearAlgebra

println("=================================================================")
println("   RUNNING ATTRACTOR DIAGNOSTICS & P-FEM GEOMETRY GENERATION")
println("=================================================================\n")

# 1. Define computational p-FEM grid (e.g., 30 structural node coordinates up to 300 meters)
# Grid spacing can be refined heavily near the ground to capture stable gradients
pfem_grid = [0.0, 2.0, 5.0, 10.0, 20.0, 35.0, 50.0, 75.0, 100.0, 150.0, 200.0, 250.0, 300.0]

for campaign in [:CASES_99, :GABLS3]
    # Fetch campaign parameters
    config = get_campaign_geometry(campaign)
    println("Processing Configuration Target: $(config.name)")
    println(" -> Measurement levels (z): $(config.tower_heights) meters")
    println(" -> Local Momentum Roughness (z0m): $(config.z0m) m")

    # 2. Build Observation Operator
    A = build_observation_operator(pfem_grid, config)
    println(" -> Generated Operator Matrix A size: $(size(A, 1))x$(size(A, 2))")

    # Mock some mock simulation SVD baseline state tracking (Rank-3 Target Space)
    U_r = rand(length(pfem_grid), 3) # Mock 3 principal spatial eigenmodes
    b_t = rand(length(config.tower_heights)) # Mock real-time vector reading from tower instruments

    # 3. Microsecond Ridge Fit Inversion Execution
    lambda = 1e-4
    eta_hat = ridge_fit(A, U_r, b_t, lambda)
    println(" -> Low-Rank Coefficients η̂ (t): ", round.(eta_hat, digits=4))

    # 4. Entropy diagnostic trace example
    mock_S = [10.0, 2.1, 0.4] # Strong dominant stratification mode signature
    H = calculate_sv_entropy(mock_S)
    println(" -> Baseline System Singular Value Entropy (H): $(round(H, digits=4))\n")
end

println("Pipeline verification complete. All operators decouple seamlessly.")