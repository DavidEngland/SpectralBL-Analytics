using Test
using Pkg

# Force activation of local project environment
Pkg.activate(".")
push!(LOAD_PATH, joinpath(pwd(), "src"))

using IngestionFormatters
using AttractorDiagnostics
import ChebyshevResidualEngine
using LinearAlgebra

@testset "SpectralBL Analytics Regression Suite" begin

    @testset "Campaign Configuration Layouts" begin
        cases = get_campaign_geometry(:CASES_99)
        gabls = get_campaign_geometry(:GABLS3)

        @test cases.z0m == 0.03
        @test gabls.z0m == 0.1
        @test cases.d == 0.0
        @test length(cases.tower_heights) == 7
        @test length(gabls.tower_heights) == 4

        # Guard rail against unconfigured campaigns
        @test_throws ErrorException get_campaign_geometry(:UNKNOWN_CAMPAIGN)
    end

    @testset "Observation Operator (A) Physics Enforcements" begin
        pfem_grid = [0.0, 2.0, 5.0, 10.0, 20.0, 50.0] # 6 nodes
        config = get_campaign_geometry(:CASES_99)   # 7 heights

        A = build_observation_operator(pfem_grid, config)

        # Test 1: Structural Dimensions (m heights x n nodes)
        @test size(A) == (7, 6)

        # Test 2: Unity Partition (Rows must sum to 1.0 for conservation)
        for i in 1:size(A, 1)
            @test sum(A[i, :]) ≈ 1.0 atol=1e-6
        end

        # Test 3: Log-Law Boundary Condition Edge Case
        # The lowest level (1.5m) is below the first element thickness (2.0m).
        # It must exclusively utilize the first two surface nodes.
        @test A[1, 1] > 0.0
        @test A[1, 2] > 0.0
        @test sum(A[1, 3:end]) == 0.0
    end

    @testset "Mathematical Low-Rank Inversions" begin
        # Fast sanity check on dimensions of ridge regression
        A = rand(7, 6)
        U_r = rand(6, 3) # Rank-3 subspace
        b = rand(7)
        lambda = 1e-4

        eta_hat = ridge_fit(A, U_r, b, lambda)
        @test length(eta_hat) == 3
    end

    @testset "Information Theory Diagnostics" begin
        # Entropy of flat distribution (maximum uncertainty)
        S_flat = [1.0, 1.0, 1.0]
        H_flat = calculate_sv_entropy(S_flat)

        # Entropy of highly stratified singular state
        S_stratified = [100.0, 0.0, 0.0]
        H_stratified = calculate_sv_entropy(S_stratified)

        @test H_flat > H_stratified
        @test H_stratified ≈ 0.0 atol=1e-6
    end

    @testset "Chebyshev Group Aliasing Regression" begin
        result = ChebyshevResidualEngine.fit_chebyshev_residuals([1.0, 2.0, 3.0, 4.0])

        old_b1 = result.b[1]
        old_c1 = result.c[1]
        old_d1 = result.d[1]

        result.a[1] = old_b1 + 123.456

        @test result.b[1] == old_b1
        @test result.c[1] == old_c1
        @test result.d[1] == old_d1
        @test result.a[1] != result.b[1]
    end

end