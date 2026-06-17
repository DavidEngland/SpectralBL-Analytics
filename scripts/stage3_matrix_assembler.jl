#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using LinearAlgebra
using SparseArrays
using Statistics
using Serialization
using JSON3
using Printf

"""
Build delay-augmented state matrix for one window using exact τ from Stage 2 packet.
Returns matrix with 9 columns: [eta(t), eta(t-τ), eta(t-2τ)].
"""
function takens_embed_eta(eta::Matrix{Float64}, tau::Int)
    n, m = size(eta)
    m == 3 || error("Expected eta matrix with 3 columns.")
    tau > 0 || error("Takens embedding requires tau > 0.")

    rows = n - 2 * tau
    rows >= 2 || error("Window too short for Takens embedding with tau=$(tau).")

    Z = Matrix{Float64}(undef, rows, 9)
    for i in 1:rows
        Z[i, 1:3] = eta[i + 2 * tau, :]
        Z[i, 4:6] = eta[i + tau, :]
        Z[i, 7:9] = eta[i, :]
    end
    return Z
end

function finite_difference_rows(X::Matrix{Float64})
    n, d = size(X)
    n >= 2 || error("Need at least two rows to form derivative matrix.")
    dX = X[2:end, :] .- X[1:end-1, :]
    return X[1:end-1, :], dX
end

function quadratic_lift(X::Matrix{Float64})
    n, d = size(X)
    out = Matrix{Float64}(undef, n, d + d * d)
    out[:, 1:d] = X
    for i in 1:n
        v = @view X[i, :]
        out[i, d + 1:end] = vec(v * v')
    end
    return out
end

function canonical_route(route::String)
    low = lowercase(strip(route))
    if occursin("stationary", low)
        return "Stationary"
    end
    return "Intermittent"
end

function parse_bool_flag(v::String)::Bool
    low = lowercase(strip(v))
    if low in ("1", "true", "yes", "y", "on")
        return true
    elseif low in ("0", "false", "no", "n", "off")
        return false
    end
    error("Invalid boolean flag value: $(v)")
end

function inspection_indices(n::Int)
    n <= 0 && return Int[]
    first_idx = collect(1:min(100, n))
    last_start = max(1, n - 99)
    last_idx = collect(last_start:n)
    return unique(vcat(first_idx, last_idx))
end

function write_inspection_csvs(Z_global::Matrix{Float64}, dZ_global::Matrix{Float64}; out_dir::String=joinpath("data", "outputs"))
    idx = inspection_indices(size(Z_global, 1))
    isempty(idx) && return ("", "")

    z_names = [
        :eta1_t, :eta2_t, :eta3_t,
        :eta1_tau, :eta2_tau, :eta3_tau,
        :eta1_2tau, :eta2_2tau, :eta3_2tau,
    ]
    dz_names = Symbol.("d_" .* String.(z_names))

    Z_df = DataFrame(Z_global[idx, :], z_names)
    dZ_df = DataFrame(dZ_global[idx, :], dz_names)

    z_path = joinpath(out_dir, "stage3_inspection_Z.csv")
    dz_path = joinpath(out_dir, "stage3_inspection_dZ.csv")
    CSV.write(z_path, Z_df)
    CSV.write(dz_path, dZ_df)
    return z_path, dz_path
end

function parse_cli_args(args::Vector{String})
    # Backward-compatible positional mode.
    if !any(startswith(a, "--") for a in args)
        packet_csv = length(args) >= 1 ? args[1] : joinpath("data", "outputs", "stage2_packets_cases_99.csv")
        trajectory_csv = length(args) >= 2 ? args[2] : joinpath("data", "drafts", "trajectories", "trajectory_master.csv")
        campaign = length(args) >= 3 ? args[3] : "CASES-99"
        out_prefix = "stage3_closure_" * lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
        out_prefix = String(strip(out_prefix, '_'))
        return (packet_csv=packet_csv, trajectory_csv=trajectory_csv, campaign=campaign, out_prefix=out_prefix, emit_csv=false)
    end

    packet_csv = joinpath("data", "outputs", "stage2_packets_cases_99.csv")
    trajectory_csv = joinpath("data", "drafts", "trajectories", "trajectory_master.csv")
    campaign = "CASES-99"
    out_prefix = ""
    emit_csv = false

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--packet"
            i += 1
            i <= length(args) || error("Missing value for --packet")
            packet_csv = args[i]
        elseif a == "--trajectory"
            i += 1
            i <= length(args) || error("Missing value for --trajectory")
            trajectory_csv = args[i]
        elseif a == "--campaign"
            i += 1
            i <= length(args) || error("Missing value for --campaign")
            campaign = args[i]
        elseif a == "--out-prefix"
            i += 1
            i <= length(args) || error("Missing value for --out-prefix")
            out_prefix = args[i]
        elseif a == "--emit-csv"
            i += 1
            i <= length(args) || error("Missing value for --emit-csv")
            emit_csv = parse_bool_flag(args[i])
        else
            error("Unknown argument: $(a)")
        end
        i += 1
    end

    if isempty(strip(out_prefix))
        out_prefix = "stage3_closure_" * lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
        out_prefix = String(strip(out_prefix, '_'))
    end

    return (
        packet_csv=packet_csv,
        trajectory_csv=trajectory_csv,
        campaign=campaign,
        out_prefix=out_prefix,
        emit_csv=emit_csv,
    )
end

function assemble_stage3_matrices(
    packet_csv::String,
    trajectory_csv::String;
    campaign::String="CASES-99",
    out_prefix::String="stage3_closure_cases_99",
    emit_csv::Bool=false,
    min_rows_embedded::Int=30,
)
    isfile(packet_csv) || error("Stage 2 packet CSV not found: $(packet_csv)")
    isfile(trajectory_csv) || error("Trajectory CSV not found: $(trajectory_csv)")

    packets = CSV.read(packet_csv, DataFrame)
    traj = CSV.read(trajectory_csv, DataFrame)

    has_validity = :validity in Symbol.(names(packets))
    has_is_valid = :is_valid in Symbol.(names(packets))
    if !(has_validity || has_is_valid)
        error("Stage 2 packet file must include validity or is_valid column.")
    end

    valid_mask = has_validity ? packets.validity .== true : packets.is_valid .== true
    packets = packets[valid_mask, :]
    packets = filter(:campaign => ==(campaign), packets)
    nrow(packets) == 0 && error("No valid Stage 2 packets found for campaign=$(campaign).")

    traj = filter(:campaign => ==(campaign), traj)
    nrow(traj) == 0 && error("No trajectory rows found for campaign=$(campaign).")
    sort!(traj, :time_value)

    # Pass 1: determine total rows for pre-allocation.
    total_rows = 0
    local_rows = Int[]
    route_group = String[]
    effective_tau = Int[]
    fallback_applied = Bool[]
    fallback_reason = String[]
    embedded_rows = Int[]

    fallback_count = 0
    for row in eachrow(packets)
        start_i = Int(row.window_start)
        end_i = Int(row.window_end)
        if start_i < 1 || end_i > nrow(traj) || start_i >= end_i
            push!(local_rows, 0)
            push!(route_group, canonical_route(String(row.route_class)))
            push!(effective_tau, 0)
            push!(fallback_applied, true)
            push!(fallback_reason, "invalid_window_bounds")
            push!(embedded_rows, 0)
            fallback_count += 1
            continue
        end

        win_n = end_i - start_i + 1
        original_tau = Int(row.selected_tau)
        route = canonical_route(String(row.route_class))
        route_eff = route
        tau_eff = max(0, original_tau)
        applied = false
        reason = ""

        rows_embed = max(0, win_n - 2 * tau_eff)
        rows_if_embed = max(0, rows_embed - 1)

        rows_here = max(0, win_n - 1)
        if route == "Intermittent" && tau_eff > 0
            if rows_if_embed < min_rows_embedded
                # Preserve physically important windows while avoiding rank-deficient local solves.
                route_eff = "Stationary"
                tau_eff = 0
                rows_here = max(0, win_n - 1)
                applied = true
                reason = "low_rows_markovian_fallback"
                fallback_count += 1
            else
                rows_here = rows_if_embed
            end
        elseif route == "Intermittent" && tau_eff <= 0
            applied = true
            reason = "intermittent_nonpositive_tau_fallback"
            fallback_count += 1
            route_eff = "Stationary"
            tau_eff = 0
        end

        push!(local_rows, rows_here)
        push!(route_group, route_eff)
        push!(effective_tau, tau_eff)
        push!(fallback_applied, applied)
        push!(fallback_reason, reason)
        push!(embedded_rows, rows_embed)
        total_rows += rows_here
    end

    # Group statistics by effective route class for audit summary.
    route_counts = combine(groupby(DataFrame(route_class=route_group), :route_class), nrow => :count)

    total_rows > 0 || error("No usable rows after Stage 3 window feasibility checks.")

    # Pre-allocate global matrices for closure contract.
    # Z_global: rows x 9 state dimensions (stationary rows populate first 3 dims).
    # dZ_global: rows x 9 derivative dimensions.
    Z_global = zeros(Float64, total_rows, 9)
    dZ_global = zeros(Float64, total_rows, 9)

    # Pre-allocate sparse block tracking matrix (diagonal labels by block id).
    I = Int[]
    J = Int[]
    V = Float64[]

    block_meta = DataFrame(
        block_id=Int[],
        original_route_class=String[],
        route_class=String[],
        window_start=Int[],
        window_end=Int[],
        original_tau=Int[],
        selected_tau=Int[],
        embedded_rows=Int[],
        fallback_applied=Bool[],
        fallback_reason=String[],
        row_start=Int[],
        row_end=Int[],
    )

    cursor = 1
    block_id = 0
    for (k, row) in enumerate(eachrow(packets))
        rows_here = local_rows[k]
        rows_here == 0 && continue

        start_i = Int(row.window_start)
        end_i = Int(row.window_end)
        tau_orig = Int(row.selected_tau)
        tau = effective_tau[k]
        route = route_group[k]
        route_orig = canonical_route(String(row.route_class))

        eta_win = Matrix{Float64}(traj[start_i:end_i, [:eta_1, :eta_2, :eta_3]])

        X_local, Y_local = if route == "Stationary" || tau <= 0
            finite_difference_rows(eta_win)
        else
            Z_local = takens_embed_eta(eta_win, tau)
            finite_difference_rows(Z_local)
        end

        nloc = size(X_local, 1)
        row_range = cursor:(cursor + nloc - 1)

        if size(X_local, 2) == 3
            Z_global[row_range, 1:3] = X_local
            dZ_global[row_range, 1:3] = Y_local
        else
            Z_global[row_range, :] = X_local
            dZ_global[row_range, :] = Y_local
        end

        block_id += 1
        for r in row_range
            push!(I, r)
            push!(J, r)
            push!(V, Float64(block_id))
        end

        push!(block_meta, (
            block_id,
            route_orig,
            route,
            start_i,
            end_i,
            tau_orig,
            tau,
            embedded_rows[k],
            fallback_applied[k],
            fallback_reason[k],
            first(row_range),
            last(row_range),
        ))

        cursor += nloc
    end

    block_tracker = sparse(I, J, V, total_rows, total_rows)
    Theta_global = quadratic_lift(Z_global)

    out_dir = joinpath("data", "outputs")
    mkpath(out_dir)

    bin_path = joinpath(out_dir, "$(out_prefix).bin")
    open(bin_path, "w") do io
        serialize(io, Dict(
            "campaign" => campaign,
            "Z_global" => Z_global,
            "dZ_global" => dZ_global,
            "Theta_global" => Theta_global,
            "block_tracker" => block_tracker,
        ))
    end

    block_meta_path = joinpath(out_dir, "$(out_prefix)_blocks.csv")
    route_summary_path = joinpath(out_dir, "$(out_prefix)_route_summary.csv")
    manifest_path = joinpath(out_dir, "$(out_prefix)_manifest.json")

    CSV.write(block_meta_path, block_meta)
    CSV.write(route_summary_path, route_counts)

    manifest = Dict(
        "campaign" => campaign,
        "packet_source" => packet_csv,
        "trajectory_source" => trajectory_csv,
        "rows" => total_rows,
        "state_dim" => 9,
        "theta_dim" => size(Theta_global, 2),
        "blocks" => nrow(block_meta),
        "fallback_count" => fallback_count,
        "fallback_rate" => nrow(block_meta) > 0 ? fallback_count / nrow(block_meta) : 0.0,
        "min_rows_embedded" => min_rows_embedded,
        "binary_path" => bin_path,
        "block_meta_path" => block_meta_path,
        "route_summary_path" => route_summary_path,
        "closure_contract" => "dZ = A*Z + H*(Z kron Z)",
    )
    write(manifest_path, JSON3.write(manifest))

    z_inspect_path = ""
    dz_inspect_path = ""
    if emit_csv
        z_inspect_path, dz_inspect_path = write_inspection_csvs(Z_global, dZ_global; out_dir=out_dir)
        if !isempty(z_inspect_path)
            println("Stage 3 inspection state slice written: $(z_inspect_path)")
            println("Stage 3 inspection derivative slice written: $(dz_inspect_path)")
        end
    end

    println("Stage 3 binary matrices written: $(bin_path)")
    println("Stage 3 block metadata written: $(block_meta_path)")
    println("Stage 3 route summary written: $(route_summary_path)")
    println("Stage 3 manifest written: $(manifest_path)")
    println(@sprintf("Global rows=%d, state_dim=%d, theta_dim=%d", total_rows, size(Z_global, 2), size(Theta_global, 2)))

    return bin_path, block_meta_path, route_summary_path, manifest_path
end

if abspath(PROGRAM_FILE) == @__FILE__
    cli = parse_cli_args(ARGS)
    assemble_stage3_matrices(
        cli.packet_csv,
        cli.trajectory_csv;
        campaign=cli.campaign,
        out_prefix=cli.out_prefix,
        emit_csv=cli.emit_csv,
    )
end
