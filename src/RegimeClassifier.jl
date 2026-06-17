module RegimeClassifier

using Statistics

export AttractorState, classify_regime

"""
    AttractorState

Window-level attractor descriptors derived from the first two modal coordinates.
"""
struct AttractorState
    R::Vector{Float64}
    Omega::Vector{Float64}
    is_stationary::Bool
end

"""
    classify_regime(eta1, eta2; var_threshold=0.15) -> AttractorState

Compute attractor amplitude and phase coordinates and classify routing behavior.
"""
function classify_regime(
    eta1::Vector{Float64},
    eta2::Vector{Float64};
    var_threshold::Float64=0.15,
)::AttractorState
    length(eta1) == length(eta2) || error("eta1 and eta2 must have identical window length")

    R = sqrt.(eta1 .^ 2 .+ eta2 .^ 2)
    Omega = atan.(eta2, eta1)

    var_R = length(R) > 1 ? var(R) : 0.0
    var_Omega = length(Omega) > 1 ? var(Omega) : 0.0
    is_stationary = (var_R <= var_threshold) && (var_Omega <= var_threshold)

    return AttractorState(R, Omega, is_stationary)
end

end # module
