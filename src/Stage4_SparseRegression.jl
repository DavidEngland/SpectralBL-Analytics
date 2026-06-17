module Stage4_SparseRegression

using LinearAlgebra
using SparseArrays
using Serialization
using JSON3
using Printf

export load_stage3_binary,
       build_library,
       stls_solve,
       run_threshold_sweep,
       export_discovered_equations

function load_stage3_binary(path::String)
    isfile(path) || error("Stage 3 binary not found: $(path)")
    payload = open(path, "r") do io
        deserialize(io)
    end
    haskey(payload, "Z_global") || error("Missing Z_global in stage3 payload")
    haskey(payload, "dZ_global") || error("Missing dZ_global in stage3 payload")
    return payload
end

"""
    build_library(Z; mode=:contract90)

Build function library matrix Theta(Z).
- :contract90 => [Z, vec(Z*Z')] per row (matches current Stage 3 contract)
- :unique_quad_with_const => [1, Z, unique quadratic terms]
"""
function build_library(Z::Matrix{Float64}; mode::Symbol=:contract90)
    n, d = size(Z)
    if mode == :contract90
        Theta = Matrix{Float64}(undef, n, d + d * d)
        Theta[:, 1:d] = Z

        # Keep a 90-column contract for d=9, but only carry unique quadratic content.
        # For cross terms, merge (za*zb, zb*za) into the canonical slot and zero the duplicate slot.
        quad = @view Theta[:, d + 1:end]
        quad .= 0.0
        for a in 1:d
            for b in a:d
                canon_idx = (b - 1) * d + a
                vals = (@view Z[:, a]) .* (@view Z[:, b])
                if a == b
                    quad[:, canon_idx] = vals
                else
                    quad[:, canon_idx] = 2.0 .* vals
                    dup_idx = (a - 1) * d + b
                    quad[:, dup_idx] .= 0.0
                end
            end
        end

        names = String[]
        for j in 1:d
            push!(names, "z$(j)")
        end
        for col in 1:d, row in 1:d
            if row <= col
                push!(names, "z$(row)*z$(col)")
            else
                push!(names, "z$(col)*z$(row)_dup0")
            end
        end
        return Theta, names
    elseif mode == :unique_quad_with_const
        q = d * (d + 1) ÷ 2
        Theta = Matrix{Float64}(undef, n, 1 + d + q)
        Theta[:, 1] .= 1.0
        Theta[:, 2:(1 + d)] = Z
        idx = 1 + d
        names = ["1"]
        append!(names, ["z$(j)" for j in 1:d])
        for a in 1:d
            for b in a:d
                idx += 1
                Theta[:, idx] = Z[:, a] .* Z[:, b]
                push!(names, "z$(a)*z$(b)")
            end
        end
        return Theta, names
    else
        error("Unsupported library mode: $(mode)")
    end
end

function residual_norm!(tmp::Matrix{Float64}, Theta::Matrix{Float64}, Xi::Matrix{Float64}, dZ::Matrix{Float64})
    mul!(tmp, Theta, Xi)
    @inbounds @simd for i in eachindex(tmp)
        tmp[i] -= dZ[i]
    end
    return norm(tmp)
end

function ridge_solve(
    Theta::Matrix{Float64},
    rhs::Union{Vector{Float64}, Matrix{Float64}};
    alpha::Float64=1e-4,
)
    alpha >= 0.0 || error("alpha must be nonnegative")
    G = transpose(Theta) * Theta
    @inbounds for i in 1:size(G, 1)
        G[i, i] += alpha
    end
    return G \ (transpose(Theta) * rhs)
end

"""
    stls_solve(Theta, dZ; lambda_threshold=1e-3, max_iter=20)

Sequential Thresholded Least Squares sparse discovery.
"""
function stls_solve(
    Theta::Matrix{Float64},
    dZ::Matrix{Float64};
    lambda_threshold::Float64=1e-3,
    max_iter::Int=20,
    alpha::Float64=1e-4,
)
    n, m = size(Theta)
    size(dZ, 1) == n || error("Theta and dZ must have same row count.")
    p = size(dZ, 2)

    Xi = ridge_solve(Theta, dZ; alpha=alpha)
    support_prev = falses(m, p)
    tmp = zeros(Float64, n, p)

    converged = false
    iters = 0
    for k in 1:max_iter
        iters = k
        support = abs.(Xi) .>= lambda_threshold

        for j in 1:p
            active = findall(@view support[:, j])
            if isempty(active)
                Xi[:, j] .= 0.0
                continue
            end

            Xi[:, j] .= 0.0
            Xi[active, j] = ridge_solve(Theta[:, active], collect(@view(dZ[:, j])); alpha=alpha)
        end

        if support == support_prev
            converged = true
            break
        end
        support_prev .= support
    end

    res = residual_norm!(tmp, Theta, Xi, dZ)
    nnz_count = count(!iszero, Xi)
    return (
        Xi = Xi,
        residual_norm = res,
        nnz = nnz_count,
        converged = converged,
        iterations = iters,
        lambda_threshold = lambda_threshold,
        alpha = alpha,
    )
end

function run_threshold_sweep(
    Theta::Matrix{Float64},
    dZ::Matrix{Float64},
    lambdas::Vector{Float64};
    max_iter::Int=20,
    alpha::Float64=1e-4,
)
    results = NamedTuple[]
    for lam in lambdas
        sol = stls_solve(Theta, dZ; lambda_threshold=lam, max_iter=max_iter, alpha=alpha)
        push!(results, (
            lambda = lam,
            residual_norm = sol.residual_norm,
            nnz = sol.nnz,
            converged = sol.converged,
            iterations = sol.iterations,
            Xi = sol.Xi,
            alpha = sol.alpha,
        ))
    end
    return results
end

function export_discovered_equations(
    output_json::String,
    Xi::Matrix{Float64},
    feature_names::Vector{String};
    state_prefix::String="dz",
)
    m, p = size(Xi)
    m == length(feature_names) || error("feature_names length must match Xi rows.")

    equations = Dict{String, Any}()
    for j in 1:p
        terms = Vector{Dict{String, Any}}()
        for i in 1:m
            c = Xi[i, j]
            if c != 0.0
                push!(terms, Dict(
                    "feature" => feature_names[i],
                    "coefficient" => c,
                ))
            end
        end
        equations["$(state_prefix)$(j)"] = terms
    end

    mkpath(dirname(output_json))
    write(output_json, JSON3.write(Dict(
        "model" => "Stage4_STLS",
        "n_features" => m,
        "n_states" => p,
        "equations" => equations,
    )))
end

end # module
