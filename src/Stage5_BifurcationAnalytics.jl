module Stage5_BifurcationAnalytics

using LinearAlgebra
using JSON3
using Random

export DiscoveredSystem,
    n_states,
    ContinuationConfig,
       load_system_from_json,
       evaluate_rhs,
       compute_jacobian,
       eigenspectrum_metrics,
       generate_seed_points,
       newton_equilibrium,
    find_equilibria,
    trace_continuation_branch

struct DiscoveredSystem
    A::Matrix{Float64}
    H::Array{Float64,3}
end

struct ContinuationConfig
    gamma_min::Float64
    gamma_max::Float64
    gamma_steps::Int
    sweep_direction::Symbol
    scale_target::Symbol
    linear_indices::Vector{Int}
    forcing::Vector{Float64}
    hopf_eps::Float64
end

function solve_branch_point(
    sys::DiscoveredSystem,
    z_seed::Vector{Float64},
    gamma::Float64,
    cfg::ContinuationConfig;
    max_iter::Int=50,
    tol::Float64=1e-8,
)
    sol = newton_equilibrium(
        sys,
        z_seed;
        max_iter=max_iter,
        tol=tol,
        gamma=gamma,
        continuation_config=cfg,
    )

    if !sol.converged
        return (
            converged=false,
            divergence=(sol.reason == "divergence_blowup" || state_is_divergent(sol.z)),
            gamma=gamma,
            z=sol.z,
            residual_norm=sol.residual_norm,
            iterations=sol.iterations,
            reason=sol.reason,
            eigenvalues=ComplexF64[],
            max_real_eig=NaN,
            is_stable=false,
            bifurcation_tag=(sol.reason == "divergence_blowup" || state_is_divergent(sol.z)) ? "Divergence_Blowup" : "newton_failed",
        )
    end

    if state_is_divergent(sol.z)
        return (
            converged=false,
            divergence=true,
            gamma=gamma,
            z=sol.z,
            residual_norm=sol.residual_norm,
            iterations=sol.iterations,
            reason="divergence_blowup",
            eigenvalues=ComplexF64[],
            max_real_eig=NaN,
            is_stable=false,
            bifurcation_tag="Divergence_Blowup",
        )
    end

    J = compute_jacobian(sys, sol.z, gamma, cfg)
    metrics = eigenspectrum_metrics(J; hopf_eps=cfg.hopf_eps)
    vals = ComplexF64.(metrics.eigenvalues)
    if eigvals_are_divergent(vals)
        return (
            converged=false,
            divergence=true,
            gamma=gamma,
            z=sol.z,
            residual_norm=sol.residual_norm,
            iterations=sol.iterations,
            reason="divergence_blowup",
            eigenvalues=vals,
            max_real_eig=NaN,
            is_stable=false,
            bifurcation_tag="Divergence_Blowup",
        )
    end

    return (
        converged=true,
        divergence=false,
        gamma=gamma,
        z=sol.z,
        residual_norm=sol.residual_norm,
        iterations=sol.iterations,
        reason="converged",
        eigenvalues=vals,
        max_real_eig=metrics.spectral_abscissa,
        is_stable=metrics.is_stable,
        bifurcation_tag="none",
    )
end

function refine_divergence_boundary(
    sys::DiscoveredSystem,
    stable_row,
    divergence_row,
    cfg::ContinuationConfig;
    max_iter::Int=50,
    tol::Float64=1e-8,
    refine_steps::Int=8,
    gamma_tol::Float64=1e-4,
)
    refined_stable = stable_row
    refined_divergence = divergence_row
    inserted_rows = NamedTuple[]

    for _ in 1:refine_steps
        if abs(refined_divergence.gamma - refined_stable.gamma) <= gamma_tol
            break
        end

        gamma_mid = 0.5 * (refined_stable.gamma + refined_divergence.gamma)
        mid_seed = refined_stable.z
        mid = solve_branch_point(sys, mid_seed, gamma_mid, cfg; max_iter=max_iter, tol=tol)

        if mid.converged && !mid.divergence
            row = (
                gamma=mid.gamma,
                z=mid.z,
                max_real_eig=mid.max_real_eig,
                is_stable=mid.is_stable,
                bifurcation_tag="refine_stable",
                converged=true,
                residual_norm=mid.residual_norm,
                eigenvalues=mid.eigenvalues,
                predictor_seed=mid_seed,
            )
            push!(inserted_rows, row)
            refined_stable = row
        else
            refined_divergence = (
                gamma=mid.gamma,
                z=mid.z,
                max_real_eig=NaN,
                is_stable=false,
                bifurcation_tag="Divergence_Blowup",
                converged=false,
                residual_norm=mid.residual_norm,
                eigenvalues=mid.eigenvalues,
                predictor_seed=mid_seed,
            )
        end
    end

    return inserted_rows, refined_divergence
end

function state_is_divergent(z::Vector{Float64}; max_norm::Float64=50.0)
    any(isnan, z) && return true
    any(isinf, z) && return true
    !isfinite(norm(z)) && return true
    norm(z) > max_norm && return true
    return false
end

function eigvals_are_divergent(vals)::Bool
    for v in vals
        if isnan(real(v)) || isnan(imag(v)) || isinf(real(v)) || isinf(imag(v))
            return true
        end
    end
    return false
end

n_states(sys::DiscoveredSystem) = size(sys.A, 1)

function parse_state_index(label::AbstractString)
    m = match(r"^dz(\d+)$", strip(label))
    m === nothing && error("Invalid state key: $(label). Expected dz<index>.")
    return parse(Int, m.captures[1])
end

function parse_feature_token(token::AbstractString, n::Int)
    t = strip(token)
    if endswith(t, "_dup0")
        return :dup, 0, 0
    end

    mlin = match(r"^z(\d+)$", t)
    if mlin !== nothing
        j = parse(Int, mlin.captures[1])
        1 <= j <= n || error("Linear feature index out of bounds: $(token)")
        return :lin, j, 0
    end

    mquad = match(r"^z(\d+)\*z(\d+)$", t)
    if mquad !== nothing
        a = parse(Int, mquad.captures[1])
        b = parse(Int, mquad.captures[2])
        (1 <= a <= n && 1 <= b <= n) || error("Quadratic feature index out of bounds: $(token)")
        return :quad, a, b
    end

    error("Unsupported feature token: $(token)")
end

function load_system_from_json(path::String)::DiscoveredSystem
    isfile(path) || error("Stage 4 equation JSON not found: $(path)")
    obj = JSON3.read(read(path, String))

    haskey(obj, "n_states") || error("Missing n_states in Stage 4 JSON: $(path)")
    haskey(obj, "equations") || error("Missing equations in Stage 4 JSON: $(path)")

    n = Int(obj["n_states"])
    A = zeros(Float64, n, n)
    H = zeros(Float64, n, n, n)

    eqs = obj["equations"]
    for (state_key_any, terms_any) in pairs(eqs)
        state_key = String(state_key_any)
        i = parse_state_index(state_key)
        1 <= i <= n || error("State index out of bounds in key $(state_key)")

        for t in terms_any
            haskey(t, "feature") || error("Missing feature field in equation $(state_key)")
            haskey(t, "coefficient") || error("Missing coefficient field in equation $(state_key)")
            feature = String(t["feature"])
            coeff = Float64(t["coefficient"])

            kind, a, b = parse_feature_token(feature, n)
            if kind === :dup
                continue
            elseif kind === :lin
                A[i, a] += coeff
            else
                H[i, a, b] += coeff
            end
        end
    end

    return DiscoveredSystem(A, H)
end

function evaluate_rhs(sys::DiscoveredSystem, z::Vector{Float64})::Vector{Float64}
    n = n_states(sys)
    length(z) == n || error("State dimension mismatch: expected $(n), got $(length(z))")

    dz = sys.A * z
    @inbounds for i in 1:n
        acc = dz[i]
        for j in 1:n, k in 1:n
            acc += sys.H[i, j, k] * z[j] * z[k]
        end
        dz[i] = acc
    end
    return dz
end

function validate_continuation_config(sys::DiscoveredSystem, cfg::ContinuationConfig)
    n = n_states(sys)
    cfg.gamma_steps >= 2 || error("gamma_steps must be >= 2")
    cfg.gamma_max >= cfg.gamma_min || error("gamma_max must be >= gamma_min")
    cfg.sweep_direction in (:ascending, :descending) || error("sweep_direction must be ascending|descending")
    cfg.scale_target in (:linear, :forcing, :both) || error("scale_target must be linear|forcing|both")
    length(cfg.forcing) == n || error("forcing vector length must equal n_states=$(n)")
    for idx in cfg.linear_indices
        1 <= idx <= n || error("linear index out of bounds: $(idx)")
    end
    return nothing
end

function effective_linear(sys::DiscoveredSystem, cfg::ContinuationConfig, gamma::Float64)
    Aeff = copy(sys.A)
    if cfg.scale_target in (:linear, :both)
        for idx in cfg.linear_indices
            Aeff[:, idx] .*= gamma
        end
    end
    return Aeff
end

function effective_forcing(sys::DiscoveredSystem, cfg::ContinuationConfig, gamma::Float64)
    if cfg.scale_target in (:forcing, :both)
        return gamma .* cfg.forcing
    end
    return zeros(Float64, n_states(sys))
end

function evaluate_rhs(sys::DiscoveredSystem, z::Vector{Float64}, gamma::Float64, cfg::ContinuationConfig)::Vector{Float64}
    validate_continuation_config(sys, cfg)

    n = n_states(sys)
    length(z) == n || error("State dimension mismatch: expected $(n), got $(length(z))")

    Aeff = effective_linear(sys, cfg, gamma)
    forcing = effective_forcing(sys, cfg, gamma)

    dz = Aeff * z
    dz .+= forcing
    @inbounds for i in 1:n
        acc = dz[i]
        for j in 1:n, k in 1:n
            acc += sys.H[i, j, k] * z[j] * z[k]
        end
        dz[i] = acc
    end
    return dz
end

function compute_jacobian(sys::DiscoveredSystem, z::Vector{Float64})::Matrix{Float64}
    n = n_states(sys)
    length(z) == n || error("State dimension mismatch: expected $(n), got $(length(z))")

    J = copy(sys.A)
    @inbounds for i in 1:n, j in 1:n
        acc = J[i, j]
        for k in 1:n
            acc += (sys.H[i, j, k] + sys.H[i, k, j]) * z[k]
        end
        J[i, j] = acc
    end
    return J
end

function compute_jacobian(sys::DiscoveredSystem, z::Vector{Float64}, gamma::Float64, cfg::ContinuationConfig)::Matrix{Float64}
    validate_continuation_config(sys, cfg)

    n = n_states(sys)
    length(z) == n || error("State dimension mismatch: expected $(n), got $(length(z))")

    J = effective_linear(sys, cfg, gamma)
    @inbounds for i in 1:n, j in 1:n
        acc = J[i, j]
        for k in 1:n
            acc += (sys.H[i, j, k] + sys.H[i, k, j]) * z[k]
        end
        J[i, j] = acc
    end
    return J
end

function eigenspectrum_metrics(J::Matrix{Float64}; hopf_eps::Float64=1e-3)
    vals = eigvals(J)
    unstable = count(v -> real(v) > 0.0, vals)
    oscillatory = any(v -> abs(imag(v)) > hopf_eps, vals)
    near_axis_pairs = count(v -> abs(real(v)) <= hopf_eps && abs(imag(v)) > hopf_eps, vals)
    stable = unstable == 0
    return (
        eigenvalues = vals,
        spectral_abscissa = maximum(real.(vals)),
        unstable_mode_count = unstable,
        oscillatory = oscillatory,
        near_axis_pairs = near_axis_pairs,
        hopf_candidate = near_axis_pairs >= 2,
        is_stable = stable,
    )
end

function generate_seed_points(n::Int; seed_count::Int=64, seed_scale::Float64=0.5, rng_seed::Int=42)
    seed_count >= 1 || error("seed_count must be >= 1")
    seed_scale > 0 || error("seed_scale must be positive")

    seeds = Vector{Vector{Float64}}()
    push!(seeds, zeros(Float64, n))

    # Add axis seeds first for reproducibility and coverage.
    for j in 1:n
        length(seeds) >= seed_count && break
        v = zeros(Float64, n)
        v[j] = seed_scale
        push!(seeds, v)

        length(seeds) >= seed_count && break
        vneg = zeros(Float64, n)
        vneg[j] = -seed_scale
        push!(seeds, vneg)
    end

    rng = MersenneTwister(rng_seed)
    while length(seeds) < seed_count
        push!(seeds, seed_scale .* randn(rng, n))
    end

    return seeds
end

function newton_equilibrium(
    sys::DiscoveredSystem,
    z0::Vector{Float64};
    max_iter::Int=50,
    tol::Float64=1e-8,
    min_step::Float64=1e-5,
    gamma::Float64=1.0,
    continuation_config::Union{Nothing,ContinuationConfig}=nothing,
)
    z = copy(z0)
    n = n_states(sys)
    length(z) == n || error("State dimension mismatch for solver seed.")

    rhs = continuation_config === nothing ?
        (x -> evaluate_rhs(sys, x)) :
        (x -> evaluate_rhs(sys, x, gamma, continuation_config))

    jac = continuation_config === nothing ?
        (x -> compute_jacobian(sys, x)) :
        (x -> compute_jacobian(sys, x, gamma, continuation_config))

    for k in 1:max_iter
        if state_is_divergent(z)
            return (converged=false, z=z, residual_norm=Inf, iterations=k, reason="divergence_blowup")
        end

        f = rhs(z)
        res = norm(f)
        if !isfinite(res)
            return (converged=false, z=z, residual_norm=Inf, iterations=k, reason="nonfinite_residual")
        end
        if res <= tol
            return (converged=true, z=z, residual_norm=res, iterations=k, reason="converged")
        end

        J = jac(z)
        δ = try
            J \ f
        catch
            return (converged=false, z=z, residual_norm=res, iterations=k, reason="singular_jacobian")
        end

        if any(!isfinite, δ)
            return (converged=false, z=z, residual_norm=res, iterations=k, reason="nonfinite_step")
        end

        step = 1.0
        accepted = false
        while step >= min_step
            z_trial = z .- step .* δ
            if state_is_divergent(z_trial)
                return (converged=false, z=z_trial, residual_norm=Inf, iterations=k, reason="divergence_blowup")
            end
            f_trial = rhs(z_trial)
            res_trial = norm(f_trial)
            if isfinite(res_trial) && res_trial < res
                z = z_trial
                accepted = true
                break
            end
            step *= 0.5
        end

        if !accepted
            return (converged=false, z=z, residual_norm=res, iterations=k, reason="line_search_failed")
        end

        if norm(step .* δ) <= tol * (1 + norm(z))
            final_res = norm(rhs(z))
            return (converged=final_res <= tol, z=z, residual_norm=final_res, iterations=k, reason="step_tolerance")
        end
    end

    final_res = norm(rhs(z))
    return (converged=final_res <= tol, z=z, residual_norm=final_res, iterations=max_iter, reason="max_iter")
end

function find_equilibria(
    sys::DiscoveredSystem;
    seed_count::Int=64,
    seed_scale::Float64=0.5,
    max_iter::Int=50,
    tol::Float64=1e-8,
    dedup_tol::Float64=1e-4,
    hopf_eps::Float64=1e-3,
)
    seeds = generate_seed_points(n_states(sys); seed_count=seed_count, seed_scale=seed_scale)

    attempts = NamedTuple[]
    eq_points = Vector{Vector{Float64}}()
    eq_meta = NamedTuple[]

    for (idx, seed) in enumerate(seeds)
        sol = newton_equilibrium(sys, seed; max_iter=max_iter, tol=tol)
        push!(attempts, (
            seed_id=idx,
            converged=sol.converged,
            residual_norm=sol.residual_norm,
            iterations=sol.iterations,
            reason=sol.reason,
        ))

        if !(sol.converged && isfinite(sol.residual_norm) && sol.residual_norm <= 10 * tol)
            continue
        end

        duplicate = any(norm(sol.z .- zref) <= dedup_tol for zref in eq_points)
        if duplicate
            continue
        end

        metrics = eigenspectrum_metrics(compute_jacobian(sys, sol.z); hopf_eps=hopf_eps)
        push!(eq_points, sol.z)
        push!(eq_meta, (
            equilibrium_id=length(eq_points),
            z=sol.z,
            residual_norm=sol.residual_norm,
            iterations=sol.iterations,
            eigenvalues=metrics.eigenvalues,
            spectral_abscissa=metrics.spectral_abscissa,
            unstable_mode_count=metrics.unstable_mode_count,
            oscillatory=metrics.oscillatory,
            near_axis_pairs=metrics.near_axis_pairs,
            hopf_candidate=metrics.hopf_candidate,
            is_stable=metrics.is_stable,
        ))
    end

    return (
        attempts=attempts,
        equilibria=eq_meta,
    )
end

function dominant_complex_real(vals::Vector{ComplexF64}; imag_eps::Float64=1e-8)
    complex_vals = [v for v in vals if abs(imag(v)) > imag_eps]
    isempty(complex_vals) && return nothing
    return maximum(real.(complex_vals))
end

function continuation_gammas(cfg::ContinuationConfig)
    if cfg.sweep_direction == :descending
        return collect(range(cfg.gamma_max, cfg.gamma_min; length=cfg.gamma_steps))
    end
    return collect(range(cfg.gamma_min, cfg.gamma_max; length=cfg.gamma_steps))
end

function predictor_state(branch, gamma_prev::Float64, gamma_cur::Float64)
    if length(branch) < 2
        return copy(branch[end].z)
    end
    z_prev = branch[end].z
    z_prev2 = branch[end - 1].z
    gamma_prev2 = branch[end - 1].gamma
    denom = gamma_prev - gamma_prev2
    if abs(denom) < 1e-12
        return copy(z_prev)
    end
    slope = (z_prev .- z_prev2) ./ denom
    return z_prev .+ slope .* (gamma_cur - gamma_prev)
end

function trace_continuation_branch(
    sys::DiscoveredSystem,
    z0::Vector{Float64},
    cfg::ContinuationConfig;
    max_iter::Int=50,
    tol::Float64=1e-8,
    refine_steps::Int=8,
    refine_gamma_tol::Float64=1e-4,
)
    validate_continuation_config(sys, cfg)
    gammas = continuation_gammas(cfg)

    branch = NamedTuple[]
    hopf_events = NamedTuple[]

    prev_complex_growth = nothing
    prev_gamma = nothing
    prev_z = nothing

    for (k, gamma) in enumerate(gammas)
        z_seed = if k == 1
            copy(z0)
        else
            predictor_state(branch, gammas[k - 1], gamma)
        end

        point = solve_branch_point(sys, z_seed, gamma, cfg; max_iter=max_iter, tol=tol)

        if !point.converged
            blowup = point.divergence
            push!(branch, (
                gamma=gamma,
                z=blowup ? point.z : fill(NaN, n_states(sys)),
                max_real_eig=NaN,
                is_stable=false,
                bifurcation_tag=blowup ? "Divergence_Blowup" : "newton_failed",
                converged=false,
                residual_norm=point.residual_norm,
                eigenvalues=point.eigenvalues,
                predictor_seed=z_seed,
            ))
            if blowup
                if !isempty(branch) && length(branch) >= 2
                    inserted_rows, refined_divergence = refine_divergence_boundary(
                        sys,
                        branch[end - 1],
                        branch[end],
                        cfg;
                        max_iter=max_iter,
                        tol=tol,
                        refine_steps=refine_steps,
                        gamma_tol=refine_gamma_tol,
                    )
                    splice!(branch, length(branch):length(branch), inserted_rows)
                    branch[end] = refined_divergence
                    gamma = refined_divergence.gamma
                end
                return (
                    branch=branch,
                    hopf_events=hopf_events,
                    terminated=true,
                    termination_gamma=gamma,
                    termination_reason="Divergence_Blowup",
                )
            end
            continue
        end

        bif_tag = "none"
        curr_growth = dominant_complex_real(point.eigenvalues)

        if prev_complex_growth !== nothing && curr_growth !== nothing && prev_gamma !== nothing && prev_z !== nothing
            if prev_complex_growth < 0.0 && curr_growth >= 0.0 && isfinite(prev_complex_growth) && isfinite(curr_growth)
                denom = curr_growth - prev_complex_growth
                θ = abs(denom) < 1e-12 ? 0.0 : clamp(-prev_complex_growth / denom, 0.0, 1.0)
                gamma_cross = prev_gamma + θ * (gamma - prev_gamma)
                z_cross = prev_z .+ θ .* (point.z .- prev_z)

                push!(hopf_events, (
                    gamma=gamma_cross,
                    z=z_cross,
                    tag="hopf_bifurcation",
                ))
                bif_tag = "hopf_crossing_step"
            end
        end

        push!(branch, (
            gamma=gamma,
            z=point.z,
            max_real_eig=point.max_real_eig,
            is_stable=point.is_stable,
            bifurcation_tag=bif_tag,
            converged=true,
            residual_norm=point.residual_norm,
            eigenvalues=point.eigenvalues,
            predictor_seed=z_seed,
        ))

        prev_complex_growth = curr_growth
        prev_gamma = gamma
        prev_z = point.z
    end

    return (
        branch=branch,
        hopf_events=hopf_events,
        terminated=false,
        termination_gamma=nothing,
        termination_reason="",
    )
end

end # module
