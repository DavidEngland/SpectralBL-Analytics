module AttractorDiagnostics
# Core math engine for metric-weighted thin SVD and Ridge optimization
export compute_weighted_svd, ridge_fit

using LinearAlgebra

function compute_weighted_svd(Y, M_half)
    # Project FEM outputs conserving mass metric inner product: M^(1/2) * Y
    weighted_Y = M_half * Y
    # Economy SVD
    return svd(weighted_Y, full=false)
end

function ridge_fit(A, U_r, b, lambda)
    # Speed optimized ridge mapping for sparse tower configurations
    AU = A * U_r
    return (AU' * AU + lambda * I) \ (AU' * b)
end

end # module
