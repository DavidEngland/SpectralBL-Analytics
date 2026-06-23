# src/DelayEstimator.jl
module DelayEstimator

using Statistics
using LinearAlgebra

using ..RegimeClassifier: AttractorState

export DelayDiagnostics, estimate_delay, estimate_delay_details

"""
    DelayDiagnostics

Captures routing and delay-selection metadata for Stage 2 handoff.
"""
struct DelayDiagnostics
    tau_linear::Int
    tau_ami::Union{Missing, Int}
    selected_tau::Int
    selection_reason::String
end

function _first_zero_crossing(eta1::AbstractVector{<:Real}, maxlag::Int)::Int
    n = length(eta1)
    n < 3 && return 1

    xc = eta1 .- mean(eta1)
    denom = sum(abs2, xc)
    denom <= eps(Float64) && return 1

    lag_max = min(maxlag, n - 2)
    for lag in 1:lag_max
        left = @view xc[1:(n - lag)]
        right = @view xc[(1 + lag):n]
        corr = dot(left, right) / denom
        if corr <= 0.0
            return lag
        end
    end

    return max(1, lag_max)
end

function _mutual_information(x::AbstractVector{<:Real}, y::AbstractVector{<:Real}; bins::Int=16)::Float64
    n = min(length(x), length(y))
    (n == 0 || bins < 2) && return 0.0

    xv = @view x[1:n]
    yv = @view y[1:n]
    xmin, xmax = extrema(xv)
    ymin, ymax = extrema(yv)

    if xmax == xmin || ymax == ymin
        return 0.0
    end

    hx = zeros(Int, bins)
    hy = zeros(Int, bins)
    hxy = zeros(Int, bins, bins)

    mapbin(v, vmin, vmax) = clamp(floor(Int, ((v - vmin) / (vmax - vmin)) * bins) + 1, 1, bins)

    for i in 1:n
        bx = mapbin(xv[i], xmin, xmax)
        by = mapbin(yv[i], ymin, ymax)
        hx[bx] += 1
        hy[by] += 1
        hxy[bx, by] += 1
    end

    mi = 0.0
    inv_n = 1.0 / n
    for i in 1:bins, j in 1:bins
        cij = hxy[i, j]
        if cij > 0 && hx[i] > 0 && hy[j] > 0
            pij = cij * inv_n
            mi += pij * log((cij * n) / (hx[i] * hy[j]))
        end
    end

    return mi
end

function _optimize_local_ami(eta1::AbstractVector{<:Real}, tau_min::Int, tau_max::Int)::Union{Missing, Int}
    n = length(eta1)
    n < 5 && return missing

    best_tau = missing
    best_mi = Inf

    for tau in tau_min:tau_max
        if tau < 1 || tau >= n - 1
            continue
        end
        x1 = @view eta1[1:(n - tau)]
        x2 = @view eta1[(1 + tau):n]
        mi = _mutual_information(x1, x2)
        if mi < best_mi
            best_mi = mi
            best_tau = tau
        end
    end

    return best_tau
end

"""
    estimate_delay_details(eta1, state; maxlag=...) -> DelayDiagnostics

Tiered delay routing:
1) Stationary windows short-circuit to tau=0.
2) Intermittent windows use first linear zero crossing to define local AMI search.
"""
function estimate_delay_details(
    eta1::AbstractVector{<:Real},
    state::AttractorState;
    maxlag::Int=min(200, max(length(eta1) - 2, 1)),
)::DelayDiagnostics
    max_feasible_tau = max(0, fld(length(eta1) - 3, 2))
    if max_feasible_tau == 0
        return DelayDiagnostics(0, missing, 0, "markovian_short_circuit")
    end

    if state.is_stationary
        return DelayDiagnostics(0, missing, 0, "markovian_short_circuit")
    end

    tau_linear = min(_first_zero_crossing(eta1, maxlag), max_feasible_tau)
    tau_min = max(1, floor(Int, 0.5 * tau_linear))
    tau_max = max(tau_min, min(maxlag, ceil(Int, 2.0 * tau_linear), max_feasible_tau))
    tau_ami = _optimize_local_ami(eta1, tau_min, tau_max)

    if tau_ami === missing
        return DelayDiagnostics(tau_linear, missing, tau_linear, "linear_fallback")
    end

    return DelayDiagnostics(tau_linear, tau_ami, tau_ami, "ami_local_min")
end

"""
    estimate_delay(eta1, state) -> Int

Compatibility helper returning only selected delay.
"""
function estimate_delay(eta1::AbstractVector{<:Real}, state::AttractorState)::Int
    return estimate_delay_details(eta1, state).selected_tau
end

end # module
