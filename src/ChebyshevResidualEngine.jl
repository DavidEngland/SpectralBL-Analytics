# src/ChebyshevResidualEngine.jl
module ChebyshevResidualEngine

using LinearAlgebra
using Statistics

export ChebyshevResidualResult, chebyshev_basis, fit_chebyshev_residuals

struct ChebyshevResidualResult
    coefficients::Vector{Float64}
    residual_norm::Float64
    fit_quality::Float64
    theta_star::Float64
    L_obukhov::Float64
    a::Vector{Float64}
    b::Vector{Float64}
    c::Vector{Float64}
    d::Vector{Float64}
end

function chebyshev_basis(x::AbstractVector{<:Real}, order::Int)
    n = length(x)
    basis = zeros(Float64, n, order + 1)
    if n == 0
        return basis
    end

    basis[:, 1] .= 1.0
    if order >= 1
        basis[:, 2] .= x
    end
    for k in 2:order
        basis[:, k + 1] .= 2.0 .* basis[:, 2] .* basis[:, k] .- basis[:, k - 1]
    end
    return basis
end

function normalize_to_chebyshev_domain(y::AbstractVector{<:Real})
    values = Float64.(y)
    if isempty(values)
        return values
    end
    finite = values[isfinite.(values)]
    if isempty(finite)
        return fill(0.0, length(values))
    end

    lo = minimum(finite)
    hi = maximum(finite)
    if !isfinite(lo) || !isfinite(hi) || hi == lo
        return fill(0.0, length(values))
    end

    return 2.0 .* ((values .- lo) ./ (hi - lo)) .- 1.0
end

function safe_groups(coefficients::Vector{Float64})
    groups = fill(0.0, 4)
    for i in 1:min(4, length(coefficients))
        groups[i] = coefficients[i]
    end
    return groups
end

function fit_chebyshev_residuals(
    eta::AbstractVector{<:Real};
    order::Int=4,
    theta_profile::Union{Nothing,AbstractVector{<:Real}}=nothing,
    u_star::Union{Nothing,Real}=nothing,
    w_theta_flux::Union{Nothing,Real}=nothing,
)
    values = Float64.(eta)
    finite_mask = isfinite.(values)
    finite_values = values[finite_mask]
    if isempty(finite_values)
        zeros_coeffs = zeros(Float64, order + 1)
        return ChebyshevResidualResult(zeros_coeffs, NaN, NaN, NaN, NaN, zeros(4), zeros(4), zeros(4), zeros(4))
    end

    x = normalize_to_chebyshev_domain(finite_values)
    basis = chebyshev_basis(x, order)
    coeffs = basis \ finite_values
    fitted = basis * coeffs
    residual = finite_values .- fitted
    residual_norm = norm(residual) / max(norm(finite_values), eps())
    fit_quality = clamp(1.0 - residual_norm, 0.0, 1.0)

    theta_star = if theta_profile === nothing || isempty(theta_profile)
        NaN
    else
        theta_vals = Float64.(theta_profile)
        theta_finite = theta_vals[isfinite.(theta_vals)]
        isempty(theta_finite) ? NaN : mean(theta_finite)
    end

    if u_star === nothing || w_theta_flux === nothing
        L_obukhov = NaN
    else
        u_star_val = abs(Float64(u_star))
        flux_val = Float64(w_theta_flux)
        if u_star_val <= 0.0 || !isfinite(flux_val)
            L_obukhov = NaN
        else
            kappa = 0.4
            g = 9.81
            theta_ref = isfinite(theta_star) && theta_star != 0.0 ? theta_star : 300.0
            L_obukhov = -(u_star_val^3 * theta_ref) / max(kappa * g * flux_val, eps())
        end
    end

    groups = safe_groups(coeffs)
    return ChebyshevResidualResult(
        coeffs,
        residual_norm,
        fit_quality,
        theta_star,
        L_obukhov,
        copy(groups),
        copy(groups),
        copy(groups),
        copy(groups),
    )
end

end # module