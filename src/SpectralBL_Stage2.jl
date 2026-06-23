# src/SpectralBL_Stage2.jl
module SpectralBL_Stage2

using LinearAlgebra
using Statistics

include("RegimeClassifier.jl")
include("DelayEstimator.jl")
include("WSINDyOperators.jl")

using .RegimeClassifier
using .DelayEstimator
using .WSINDyOperators

export AttractorState,
       DelayDiagnostics,
       Stage2Packet,
       classify_regime,
       estimate_delay,
       estimate_delay_details,
       finite_difference,
       compute_wsindy_operator,
       compute_tikhonov_operator,
       verify_operators,
       process_stage2_window,
       build_takens_state

struct Stage2Packet
    campaign::String
    window_start::Int
    window_end::Int
    time_start::Float64
    time_end::Float64
    var_R::Float64
    var_Omega::Float64
    route_class::String
    tau_linear::Int
    tau_ami::Union{Missing, Int}
    selected_tau::Int
    selection_reason::String
    disagreement_norm::Float64
    is_valid::Bool
    failure_reason::String
    wsindy_norm::Float64
    tikhonov_norm::Float64
end

"""
    build_takens_state(eta, tau)

Constructs the time-delay embedded phase space matrix. Optimized to perform zero heap allocations in loop.
"""
function build_takens_state(eta::Matrix{Float64}, tau::Int)
    n, m = size(eta)
    if tau <= 0
        return copy(eta)
    end
    if n <= 2 * tau + 1
        error("Window too short for requested Takens delay.")
    end

    rows = n - 2 * tau
    Z = Matrix{Float64}(undef, rows, 3 * m)

    # OPTIMIZED: Use in-place broadcasting and views to drop allocation overhead completely
    for i in 1:rows
        Z[i, 1:m] .= @view eta[i + 2 * tau, :]
        Z[i, m + 1:2 * m] .= @view eta[i + tau, :]
        Z[i, 2 * m + 1:3 * m] .= @view eta[i, :]
    end
    return Z
end

"""
    process_stage2_window(...) -> Stage2Packet

Main pipeline driver execution window transforming low-rank trajectories into regularized SINDy operators.
"""
function process_stage2_window(
    eta::Matrix{Float64},
    times::Vector{Float64},
    campaign::String,
    window_start::Int,
    window_end::Int;
    var_threshold::Float64=0.15,
    gamma_crit::Float64=0.5,
    lambda_wsindy::Float64=1e-6,
    lambda_tikh::Float64=1e-3,
)
    n, m = size(eta)
    m >= 2 || error("Stage 2 requires at least two modal columns.")
    length(times) == n || error("times length must match eta rows.")

    # OPTIMIZED: Replaced slicing with views to protect memory performance
    eta1_view = @view eta[:, 1]
    eta2_view = @view eta[:, 2]

    state = classify_regime(eta1_view, eta2_view; var_threshold=var_threshold)
    diagnostics = estimate_delay_details(eta1_view, state)

    var_R = n > 1 ? Statistics.var(state.R) : 0.0
    var_Omega = n > 1 ? Statistics.var(state.Omega) : 0.0
    route_class = state.is_stationary ? "stationary_markovian" : "intermittent_conditional_ami"

    selected_tau = diagnostics.selected_tau
    max_feasible_tau = max(0, fld(n - 3, 2))
    if selected_tau > max_feasible_tau
        selected_tau = 0
    end

    # Phase Space Reconstruction
    Z = build_takens_state(eta, selected_tau)
    dZ = finite_difference(Z)

    # Parallel System Identification Path Discovery
    Xi_wsindy = compute_wsindy_operator(Z, dZ; lambda=lambda_wsindy)
    Xi_tikh = compute_tikhonov_operator(Z, dZ; lambda=lambda_tikh)
    disagreement = verify_operators(Xi_wsindy, Xi_tikh; gamma_crit=gamma_crit)

    is_valid = all(isfinite, Xi_wsindy) && all(isfinite, Xi_tikh)
    failure_reason = is_valid ? "" : "non-finite operator entries"

    packet = Stage2Packet(
        campaign,
        window_start,
        window_end,
        times[1],
        times[end],
        var_R,
        var_Omega,
        route_class,
        diagnostics.tau_linear,
        diagnostics.tau_ami,
        selected_tau,
        diagnostics.selection_reason,
        disagreement,
        is_valid,
        failure_reason,
        LinearAlgebra.norm(Xi_wsindy),
        LinearAlgebra.norm(Xi_tikh),
    )

    return packet
end

end # module