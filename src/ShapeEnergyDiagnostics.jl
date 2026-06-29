module ShapeEnergyDiagnostics

using Statistics
using FFTW

export ShapeEnergyVector,
       compute_shape_energy,
       compute_gradient_energy,
       compute_curvature_energy,
       compute_jerk_energy,
       compute_spectral_roughness

"""
Container for geometric shape-energy diagnostics of a 1D profile.
"""
struct ShapeEnergyVector
    E_g::Float64
    E_kappa::Float64
    E_j::Float64
    R::Float64
end

function _validate_profile(y::AbstractVector{<:Real}, z::AbstractVector{<:Real})
    n = length(y)
    if n != length(z)
        throw(ArgumentError("profile and coordinate vectors must have same length"))
    end
    if n < 5
        throw(ArgumentError("at least 5 samples are required for stable third-derivative estimates"))
    end
    zf = Float64.(z)
    if any(!isfinite, zf)
        throw(ArgumentError("coordinate vector contains non-finite values"))
    end
    if any(diff(zf) .<= 0.0)
        throw(ArgumentError("coordinate vector must be strictly increasing"))
    end
    yf = Float64.(y)
    if any(!isfinite, yf)
        throw(ArgumentError("profile vector contains non-finite values"))
    end
    return yf, zf
end

function _first_derivative(y::Vector{Float64}, z::Vector{Float64})
    n = length(y)
    d = similar(y)

    d[1] = (y[2] - y[1]) / (z[2] - z[1])
    d[n] = (y[n] - y[n - 1]) / (z[n] - z[n - 1])

    @inbounds for i in 2:n-1
        d[i] = (y[i + 1] - y[i - 1]) / (z[i + 1] - z[i - 1])
    end
    return d
end

function _trapz(x::Vector{Float64}, y::Vector{Float64})
    n = length(x)
    acc = 0.0
    @inbounds for i in 1:n-1
        acc += 0.5 * (y[i] + y[i + 1]) * (x[i + 1] - x[i])
    end
    return acc
end

"""
    compute_gradient_energy(profile, z)

Computes gradient energy
E_g = ∫ |f'(z)|^2 dz.
"""
function compute_gradient_energy(profile::AbstractVector{<:Real}, z::AbstractVector{<:Real})
    y, zz = _validate_profile(profile, z)
    y1 = _first_derivative(y, zz)
    return _trapz(zz, y1 .^ 2)
end

"""
    compute_curvature_energy(profile, z)

Computes curvature energy
E_kappa = ∫ kappa(z)^2 dz,
with kappa(z) = f''(z) / (1 + f'(z)^2)^(3/2).
"""
function compute_curvature_energy(profile::AbstractVector{<:Real}, z::AbstractVector{<:Real})
    y, zz = _validate_profile(profile, z)
    y1 = _first_derivative(y, zz)
    y2 = _first_derivative(y1, zz)

    denom = (1.0 .+ y1 .^ 2) .^ 1.5
    kappa = y2 ./ denom

    return _trapz(zz, kappa .^ 2)
end

"""
    compute_jerk_energy(profile, z)

Computes jerk energy
E_j = ∫ |f'''(z)|^2 dz.
"""
function compute_jerk_energy(profile::AbstractVector{<:Real}, z::AbstractVector{<:Real})
    y, zz = _validate_profile(profile, z)
    y1 = _first_derivative(y, zz)
    y2 = _first_derivative(y1, zz)
    y3 = _first_derivative(y2, zz)

    return _trapz(zz, y3 .^ 2)
end

"""
    compute_spectral_roughness(profile)

Computes normalized spectral roughness
R = sum(k^2 * |a_k|^2) / sum(|a_k|^2),
where a_k are one-sided Fourier coefficients of the detrended profile.
"""
function compute_spectral_roughness(profile::AbstractVector{<:Real})
    y = Float64.(profile)
    if any(!isfinite, y)
        throw(ArgumentError("profile vector contains non-finite values"))
    end
    if length(y) < 5
        throw(ArgumentError("at least 5 samples are required for spectral roughness"))
    end

    # Remove affine trend to avoid spurious roughness from non-periodic ramps.
    n_samples = length(y)
    x = collect(1.0:n_samples)
    x_centered = x .- mean(x)
    y_centered = y .- mean(y)

    denom_x = sum(abs2, x_centered)
    slope = denom_x <= eps(Float64) ? 0.0 : sum(x_centered .* y_centered) / denom_x
    intercept = mean(y) - slope * mean(x)
    detrended = y .- (intercept .+ slope .* x)

    centered = detrended .- mean(detrended)
    coeff = rfft(centered)
    power = abs2.(coeff)
    n = length(power)
    k = collect(0:n-1)

    denom = sum(power)
    if denom <= eps(Float64)
        return 0.0
    end

    return sum((k .^ 2) .* power) / denom
end

"""
    compute_shape_energy(profile, z)

Returns full shape-energy diagnostic vector (E_g, E_kappa, E_j, R).
"""
function compute_shape_energy(profile::AbstractVector{<:Real}, z::AbstractVector{<:Real})
    E_g = compute_gradient_energy(profile, z)
    E_kappa = compute_curvature_energy(profile, z)
    E_j = compute_jerk_energy(profile, z)
    R = compute_spectral_roughness(profile)
    return ShapeEnergyVector(E_g, E_kappa, E_j, R)
end

end # module
