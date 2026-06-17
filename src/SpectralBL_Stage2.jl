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
    for i in 1:rows
        Z[i, 1:m] = eta[i + 2 * tau, :]
        Z[i, m + 1:2 * m] = eta[i + tau, :]
        Z[i, 2 * m + 1:3 * m] = eta[i, :]
    end
    return Z
end

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

    state = classify_regime(eta[:, 1], eta[:, 2]; var_threshold=var_threshold)
    diagnostics = estimate_delay_details(eta[:, 1], state)

    var_R = n > 1 ? Statistics.var(state.R) : 0.0
    var_Omega = n > 1 ? Statistics.var(state.Omega) : 0.0
    route_class = state.is_stationary ? "stationary_markovian" : "intermittent_conditional_ami"

    selected_tau = diagnostics.selected_tau
    max_feasible_tau = max(0, fld(n - 3, 2))
    if selected_tau > max_feasible_tau
        selected_tau = 0
    end

    Z = build_takens_state(eta, selected_tau)
    dZ = finite_difference(Z)

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
