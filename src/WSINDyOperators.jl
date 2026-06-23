# src/WSINDyOperators.jl
module WSINDyOperators

using LinearAlgebra
using Statistics

export finite_difference,
       compute_wsindy_operator,
       compute_tikhonov_operator,
       verify_operators

"""
    finite_difference(Z, dt=1.0)

Computes temporal derivative trajectories using 2nd-order central differences with 1st-order edge buffers.
"""
function finite_difference(Z::Matrix{Float64}, dt::Float64=1.0)
    n, p = size(Z)
    n < 3 && error("Need at least 3 rows to compute finite-difference derivatives.")

    dZ = zeros(Float64, n, p)
    dZ[1, :] .= (Z[2, :] .- Z[1, :]) ./ dt
    dZ[end, :] .= (Z[end, :] .- Z[end - 1, :]) ./ dt
    for i in 2:(n - 1)
        dZ[i, :] .= (Z[i + 1, :] .- Z[i - 1, :]) ./ (2.0 * dt)
    end
    return dZ
end

function _first_order_regularizer(p::Int)
    if p <= 1
        return zeros(Float64, 1, p)
    end
    L = zeros(Float64, p - 1, p)
    for i in 1:(p - 1)
        L[i, i] = -1.0
        L[i, i + 1] = 1.0
    end
    return L
end

"""
    compute_wsindy_operator(Z, dZ; lambda=1e-6)

Weak path approximation using a smooth test-function weighted projection.
"""
function compute_wsindy_operator(Z::Matrix{Float64}, dZ::Matrix{Float64}; lambda::Float64=1e-6)
    size(Z) == size(dZ) || error("Z and dZ must have matching dimensions.")

    n, p = size(Z)
    t = range(0.0, 1.0; length=n)
    w = @. sin(pi * t)^2 + 1e-6

    # OPTIMIZED: Avoid explicit full-matrix Diagonal allocation via broadcast-scaling
    ZW = Z .* w
    lhs = Z' * ZW + lambda * I
    rhs = ZW' * dZ

    return lhs \ rhs
end

"""
    compute_tikhonov_operator(Z, dZ; lambda=1e-3)

Weighted least-squares with a first-order smoothing regularizer penalizing row jumps.
"""
function compute_tikhonov_operator(Z::Matrix{Float64}, dZ::Matrix{Float64}; lambda::Float64=1e-3)
    size(Z) == size(dZ) || error("Z and dZ must have matching dimensions.")

    n, p = size(Z)
    x = range(0.0, 10.0; length=n)
    weights = [0.2 <= xi <= 9.8 ? 1.0 : 0.2 for xi in x]

    # OPTIMIZED: Avoid explicit full-matrix Diagonal allocation via broadcast-scaling
    ZW = Z .* weights
    L = _first_order_regularizer(p)

    lhs = Z' * ZW + lambda * (L' * L) + 1e-8 * I
    rhs = ZW' * dZ

    return lhs \ rhs
end

"""
    verify_operators(Xi_wsindy, Xi_tikhonov; gamma_crit=0.5) -> Float64

Returns Frobenius norm disagreement and emits warning when above a structural threshold.
"""
function verify_operators(
    Xi_wsindy::AbstractMatrix{<:Real},
    Xi_tikhonov::AbstractMatrix{<:Real};
    gamma_crit::Float64=0.5,
)::Float64
    size(Xi_wsindy) == size(Xi_tikhonov) || error("Operator matrices must have identical shape.")

    # OPTIMIZED: Computed norm directly without copying structural matrices to the heap
    delta = norm(Xi_wsindy .- Xi_tikhonov)
    if delta > gamma_crit
        @warn "Operator disagreement exceeds critical threshold." disagreement=delta gamma_crit=gamma_crit
    end
    return delta
end

end # module