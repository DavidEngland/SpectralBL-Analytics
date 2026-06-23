# src/AttractorDiagnostics.jl
module AttractorDiagnostics

using LinearAlgebra
using IngestionFormatters: CampaignConfig

include("ChebyshevResidualEngine.jl")

using .ChebyshevResidualEngine

export build_observation_operator, compute_weighted_svd, ridge_fit, calculate_sv_entropy
export ChebyshevResidualResult, chebyshev_basis, fit_chebyshev_residuals

"""
    build_observation_operator(p_fem_grid, config::CampaignConfig; von_karman=0.4)

Builds matrix A (m x n) mapping p-FEM structural nodes down to tower observation heights.
Enforces an inner-layer log-law weighting rule for any heights close to the surface boundary.
"""
function build_observation_operator(p_fem_grid::Vector{Float64}, config::CampaignConfig; von_karman::Float64=0.4)
    m = length(config.tower_heights)
    n = length(p_fem_grid)
    A = zeros(m, n)

    # Define boundary transition boundary (e.g., first element layer thickness)
    surface_layer_threshold = p_fem_grid[2]

    for (i, z_t) in enumerate(config.tower_heights)
        z_effective = z_t - config.d
        if z_effective <= 0.0
            z_effective = 1e-4 # Avoid log(0) singularity traps
        end

        if z_effective <= surface_layer_threshold
            # --- INNER REGION LOG-MAPPING ---
            # Enforce local analytical profile match matching z0m boundary condition
            log_profile_weight = log(z_effective / config.z0m) / log(surface_layer_threshold / config.z0m)

            # Linearly mix or assign directly to the base element boundary nodes
            A[i, 1] = 1.0 - clamp(log_profile_weight, 0.0, 1.0)
            A[i, 2] = clamp(log_profile_weight, 0.0, 1.0)
        else
            # --- STANDARD HIGH-ORDER LINEAR/P-FEM INTERPOLATION ---
            # Locate bounding nodes in the grid
            idx = findlast(x -> x <= z_effective, p_fem_grid)
            if idx === nothing
                # Out of bounds high (Anchor to upper Dirichlet boundary node)
                A[i, end] = 1.0
            elseif idx == n
                A[i, end] = 1.0
            else
                # Classical nodal basis projection
                z_left = p_fem_grid[idx]
                z_right = p_fem_grid[idx+1]
                dx = z_right - z_left

                A[i, idx]   = (z_right - z_effective) / dx
                A[i, idx+1] = (z_effective - z_left) / dx
            end
        end
    end
    return A
end

"""
    compute_weighted_svd(Y, M_half)

Performs an economy SVD on the mass-metric weighted history state ensemble.
"""
function compute_weighted_svd(Y::Matrix{Float64}, M_half::AbstractMatrix{Float64})
    weighted_Y = M_half * Y
    return svd(weighted_Y, full=false)
end

"""
    ridge_fit(A, U_r, b, lambda)

Extremely fast r x r low-rank trajectory inversion.
Solves: η̂ = (RᵀR + λI)⁻¹ Rᵀb where R = A * U_r
"""
function ridge_fit(A::Matrix{Float64}, U_r::Matrix{Float64}, b::Vector{Float64}, lambda::Float64)
    if lambda < 0.0
        throw(DomainError(lambda, "ridge_fit requires lambda >= 0.0"))
    end
    lambda_eff = lambda == 0.0 ? eps(Float64) : lambda

    R = A * U_r
    # Rᵀ * R forms a tiny matrix scaling exclusively with target rank (e.g. 3x3)
    return (R' * R + lambda_eff * I) \ (R' * b)
end

"""
    calculate_sv_entropy(S::Vector{Float64})

Computes Singular Value Entropy (H). Sudden collapses in H indicate
the physical boundary layer shifting from multi-scale turbulence down to a stratified SBL sheet.
"""
function calculate_sv_entropy(S::Vector{Float64})
    total_energy = sum(s -> s * s, S)
    if total_energy == 0.0; return 0.0; end

    entropy = 0.0
    for s in S
        pi = (s * s) / total_energy
        if pi > 0.0
            entropy -= pi * log(pi)
        end
    end
    return entropy
end

end # module