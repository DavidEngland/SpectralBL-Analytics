#!/usr/bin/env julia
using Pkg
Pkg.activate(".")

using CSV
using DataFrames
using JSON3
using Statistics
using Printf

function campaign_slug(campaign::String)
    safe = lowercase(replace(campaign, r"[^A-Za-z0-9]+" => "_"))
    safe = strip(safe, '_')
    return isempty(safe) ? "campaign" : String(safe)
end

function parse_args(args::Vector{String})
    campaign = "CASES-99"
    output_dir = joinpath("data", "outputs")
    trajectory_csv = joinpath("data", "drafts", "trajectories", "trajectory_master.csv")
    branch_csv = ""
    summary_json = ""
    profile_mode = "persisted"

    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--campaign"
            i += 1
            campaign = args[i]
        elseif a == "--output-dir"
            i += 1
            output_dir = args[i]
        elseif a == "--trajectory-csv"
            i += 1
            trajectory_csv = args[i]
        elseif a == "--branch-csv"
            i += 1
            branch_csv = args[i]
        elseif a == "--summary-json"
            i += 1
            summary_json = args[i]
        elseif a == "--profile-mode"
            i += 1
            profile_mode = lowercase(strip(args[i]))
        else
            error("Unknown argument: $(a)")
        end
        i += 1
    end

    slug = campaign_slug(campaign)
    if isempty(branch_csv)
        branch_csv = joinpath("data", "outputs", "stage5_bifurcation_branches_$(slug).csv")
    end
    if isempty(summary_json)
        summary_json = joinpath("data", "outputs", "stage5_summary_$(slug).json")
    end

    return (
        campaign = campaign,
        slug = slug,
        output_dir = output_dir,
        trajectory_csv = trajectory_csv,
        branch_csv = branch_csv,
        summary_json = summary_json,
        profile_mode = profile_mode,
    )
end

function safe_float(x)
    if x isa Number
        f = Float64(x)
        return isfinite(f) ? f : nothing
    end
    parsed = tryparse(Float64, string(x))
    if parsed === nothing || !isfinite(parsed)
        return nothing
    end
    return parsed
end

function normalize_campaign_name(name)
    if name === nothing
        return nothing
    end
    raw = uppercase(strip(String(name)))
    if raw in ("CASES-99", "CASES_99")
        return "CASES-99"
    elseif raw == "GABLS3"
        return "GABLS3"
    elseif raw in ("ARCTIC-AMPLIFICATION", "ARCTIC_AMPLIFICATION", "ARCTIC")
        return "ARCTIC-AMPLIFICATION"
    elseif raw in ("FLOSS", "FLOSS_I", "FLOSS-II", "FLOSS_II", "FLOSS-I")
        return "FLOSS"
    elseif raw == "BLLAST"
        return "BLLAST"
    end
    return String(name)
end

function panel_ab_status(branch_df::DataFrame)
    if nrow(branch_df) == 0
        return "empty_branch_csv"
    end

    have_a = ("gamma" in names(branch_df)) && ("max_real_eig" in names(branch_df))
    have_b = all(c -> c in names(branch_df), ["gamma", "z1", "z2", "z3"])

    if !have_a && !have_b
        return "missing_panel_a_and_panel_b_columns"
    elseif !have_a
        return "missing_panel_a_columns"
    elseif !have_b
        return "missing_panel_b_columns"
    end

    return "ok"
end

function load_campaign_trajectory(path::String, campaign::String)
    if !isfile(path)
        return DataFrame()
    end
    df = CSV.read(path, DataFrame)
    if !("campaign" in names(df))
        return DataFrame()
    end

    target = normalize_campaign_name(campaign)
    normalized = [normalize_campaign_name(v) for v in df[!, "campaign"]]
    mask = map(v -> v == target, normalized)
    subset = df[mask, :]
    return subset
end

function build_panel_a(branch_df::DataFrame)
    if nrow(branch_df) == 0
        return DataFrame(gamma=Float64[], max_real_eig=Float64[])
    end

    if !(("gamma" in names(branch_df)) && ("max_real_eig" in names(branch_df)))
        return DataFrame(gamma=Float64[], max_real_eig=Float64[])
    end

    out = DataFrame(gamma=Float64[], max_real_eig=Float64[])
    for row in eachrow(branch_df)
        g = safe_float(row.gamma)
        r = safe_float(row.max_real_eig)
        if g !== nothing && r !== nothing
            push!(out, (g, r))
        end
    end
    return out
end

function build_panel_b(branch_df::DataFrame)
    needed = ["z1", "z2", "z3", "gamma"]
    if nrow(branch_df) == 0 || any(c -> !(c in names(branch_df)), needed)
        return DataFrame(gamma=Float64[], z1=Float64[], z2=Float64[], z3=Float64[], max_imag_eig=Float64[])
    end

    has_imag = "max_imag_eig" in names(branch_df)
    out = DataFrame(gamma=Float64[], z1=Float64[], z2=Float64[], z3=Float64[], max_imag_eig=Float64[])
    for row in eachrow(branch_df)
        g = safe_float(row.gamma)
        z1 = safe_float(row.z1)
        z2 = safe_float(row.z2)
        z3 = safe_float(row.z3)
        β = has_imag ? safe_float(row.max_imag_eig) : nothing
        if g !== nothing && z1 !== nothing && z2 !== nothing && z3 !== nothing
            push!(out, (g, z1, z2, z3, β === nothing ? NaN : β))
        end
    end
    return out
end

function select_transition_window(traj_df::DataFrame)
    needed = ["time_value", "eta_1", "eta_2", "eta_3"]
    if nrow(traj_df) == 0 || any(c -> !(c in names(traj_df)), needed)
        return DataFrame(source_index=Int[], time_value=Float64[], eta_1=Float64[], eta_2=Float64[], eta_3=Float64[], phase=String[])
    end

    rows = Vector{NamedTuple}()
    for (idx, row) in enumerate(eachrow(traj_df))
        t = safe_float(row.time_value)
        e1 = safe_float(row.eta_1)
        e2 = safe_float(row.eta_2)
        e3 = safe_float(row.eta_3)
        if t !== nothing && e1 !== nothing && e2 !== nothing && e3 !== nothing
            push!(rows, (source_index=idx, time_value=t, eta_1=e1, eta_2=e2, eta_3=e3, abs_eta_3=abs(e3)))
        end
    end

    if isempty(rows)
        return DataFrame(source_index=Int[], time_value=Float64[], eta_1=Float64[], eta_2=Float64[], eta_3=Float64[], phase=String[])
    end

    tmp = DataFrame(rows)
    peak_idx = argmax(tmp.abs_eta_3)

    lo = max(1, peak_idx - 6)
    hi = min(nrow(tmp), peak_idx + 6)
    window = tmp[lo:hi, :]

    phase = String[]
    for i in 1:nrow(window)
        if i < peak_idx - lo + 1
            push!(phase, "pre")
        elseif i == peak_idx - lo + 1
            push!(phase, "peak")
        else
            push!(phase, "post")
        end
    end

    out = DataFrame(
        source_index = Int.(window.source_index),
        time_value = Float64.(window.time_value),
        eta_1 = Float64.(window.eta_1),
        eta_2 = Float64.(window.eta_2),
        eta_3 = Float64.(window.eta_3),
        phase = phase,
    )

    sort!(out, :time_value)
    return out
end

function build_panel_c(traj_df::DataFrame)
    window = select_transition_window(traj_df)
    if nrow(window) == 0
        return DataFrame(time_value=Float64[], eta_1=Float64[], eta_2=Float64[], eta_3=Float64[], phase=String[])
    end

    return DataFrame(
        time_value = Float64.(window.time_value),
        eta_1 = Float64.(window.eta_1),
        eta_2 = Float64.(window.eta_2),
        eta_3 = Float64.(window.eta_3),
        phase = String.(window.phase),
    )
end

function parse_ri_g_height(col_name::String)
    startswith(col_name, "ri_g_") || return nothing
    raw = col_name[6:end]
    candidate = replace(raw, "_" => ".")
    h = tryparse(Float64, candidate)
    return h
end

function ri_g_profile_columns(traj_df::DataFrame)
    cols = Vector{Tuple{Symbol,Float64}}()
    for n in names(traj_df)
        s = String(n)
        h = parse_ri_g_height(s)
        if h !== nothing && isfinite(h)
            push!(cols, (Symbol(n), h))
        end
    end
    sort!(cols, by=x -> x[2])
    return cols
end

function build_panel_c_profile(traj_df::DataFrame)
    window = select_transition_window(traj_df)
    nrow(window) == 0 && return DataFrame(ri_g=Float64[], height_z=Float64[], phase=String[], time_value=Float64[])

    ri_cols = ri_g_profile_columns(traj_df)
    length(ri_cols) < 3 && return DataFrame(ri_g=Float64[], height_z=Float64[], phase=String[], time_value=Float64[])

    rows = Vector{NamedTuple}()
    for row in eachrow(window)
        src_idx = Int(row.source_index)
        for (col, z) in ri_cols
            ri = safe_float(traj_df[src_idx, col])
            if ri !== nothing
                push!(rows, (ri_g=ri, height_z=z, phase=String(row.phase), time_value=Float64(row.time_value)))
            end
        end
    end

    isempty(rows) && return DataFrame(ri_g=Float64[], height_z=Float64[], phase=String[], time_value=Float64[])

    out = DataFrame(rows)
    sort!(out, [:time_value, :height_z])
    return out
end

function load_summary(path::String)
    if !isfile(path)
        return nothing
    end
    return JSON3.read(read(path, String))
end

function summary_gamma(summary)
    summary === nothing && return nothing
    if haskey(summary, "gamma_c_hopf")
        return safe_float(summary["gamma_c_hopf"])
    end
    if haskey(summary, "closest_to_axis_gamma")
        return safe_float(summary["closest_to_axis_gamma"])
    end
    return nothing
end

function summary_period_minutes(summary)
    summary === nothing && return nothing
    if haskey(summary, "hopf_period_Th")
        sec = safe_float(summary["hopf_period_Th"])
        if sec !== nothing && sec > 0.0
            return sec / 60.0
        end
    end
    return nothing
end

function gamma_samples_from_panel_a(panel_a::DataFrame)
    if nrow(panel_a) == 0 || !(:gamma in Symbol.(names(panel_a)))
        return Float64[]
    end
    vals = [Float64(g) for g in panel_a.gamma if isfinite(Float64(g))]
    sort!(vals)
    return unique(vals)
end

function phase_profile_means(window::DataFrame, traj_df::DataFrame, ri_cols::Vector{Tuple{Symbol,Float64}})
    profiles = Dict{String,Dict{Float64,Float64}}()
    for phase_name in ("pre", "peak", "post")
        sub = filter(:phase => ==(phase_name), window)
        if nrow(sub) == 0
            continue
        end
        d = Dict{Float64,Float64}()
        for (col, z) in ri_cols
            vals = Float64[]
            for row in eachrow(sub)
                src_idx = Int(row.source_index)
                ri = safe_float(traj_df[src_idx, col])
                if ri !== nothing
                    push!(vals, ri)
                end
            end
            if !isempty(vals)
                d[z] = mean(vals)
            end
        end
        if !isempty(d)
            profiles[phase_name] = d
        end
    end
    return profiles
end

function interpolate_profile(pre_v::Float64, peak_v::Float64, post_v::Float64, gamma::Float64, g_min::Float64, g_mid::Float64, g_max::Float64)
    epsv = 1e-9
    if gamma <= g_mid
        t = (gamma - g_min) / (max(g_mid - g_min, epsv))
        return (1.0 - t) * pre_v + t * peak_v
    end
    t = (gamma - g_mid) / (max(g_max - g_mid, epsv))
    return (1.0 - t) * peak_v + t * post_v
end

function build_panel_c_profile_matrix(traj_df::DataFrame, panel_a::DataFrame, gamma_critical)
    window = select_transition_window(traj_df)
    nrow(window) == 0 && return DataFrame(gamma=Float64[], height_z=Float64[], ri_g=Float64[])

    ri_cols = ri_g_profile_columns(traj_df)
    length(ri_cols) < 3 && return DataFrame(gamma=Float64[], height_z=Float64[], ri_g=Float64[])

    gammas = gamma_samples_from_panel_a(panel_a)
    length(gammas) < 3 && return DataFrame(gamma=Float64[], height_z=Float64[], ri_g=Float64[])

    profiles = phase_profile_means(window, traj_df, ri_cols)
    all_profile = Dict{Float64,Float64}()
    for (col, z) in ri_cols
        vals = Float64[]
        for row in eachrow(window)
            ri = safe_float(traj_df[Int(row.source_index), col])
            ri !== nothing && push!(vals, ri)
        end
        if !isempty(vals)
            all_profile[z] = mean(vals)
        end
    end
    isempty(all_profile) && return DataFrame(gamma=Float64[], height_z=Float64[], ri_g=Float64[])

    pre_p = get(profiles, "pre", all_profile)
    peak_p = get(profiles, "peak", all_profile)
    post_p = get(profiles, "post", all_profile)

    g_min = minimum(gammas)
    g_max = maximum(gammas)
    g_mid = gamma_critical === nothing ? median(gammas) : clamp(Float64(gamma_critical), g_min, g_max)

    rows = Vector{NamedTuple}()
    for g in gammas
        for (_, z) in ri_cols
            pre_v = get(pre_p, z, get(all_profile, z, NaN))
            peak_v = get(peak_p, z, pre_v)
            post_v = get(post_p, z, peak_v)
            if isfinite(pre_v) && isfinite(peak_v) && isfinite(post_v)
                ri = interpolate_profile(pre_v, peak_v, post_v, g, g_min, g_mid, g_max)
                push!(rows, (gamma=g, height_z=z, ri_g=ri))
            end
        end
    end

    isempty(rows) && return DataFrame(gamma=Float64[], height_z=Float64[], ri_g=Float64[])
    out = DataFrame(rows)
    sort!(out, [:gamma, :height_z])
    return out
end

function main(; campaign::String, slug::String, output_dir::String, trajectory_csv::String, branch_csv::String, summary_json::String, profile_mode::String)
    mkpath(output_dir)

    branch_df = isfile(branch_csv) ? CSV.read(branch_csv, DataFrame) : DataFrame()
    traj_df = load_campaign_trajectory(trajectory_csv, campaign)
    summary = load_summary(summary_json)

    panel_a = build_panel_a(branch_df)
    panel_b = build_panel_b(branch_df)
    panel_c = build_panel_c(traj_df)
    ab_status = panel_ab_status(branch_df)

    panel_a_path = joinpath(output_dir, "transition_panel_a_$(slug).csv")
    panel_b_path = joinpath(output_dir, "transition_panel_b_$(slug).csv")
    panel_c_path = joinpath(output_dir, "transition_panel_c_$(slug).csv")
    panel_c_profile_path = joinpath(output_dir, "transition_panel_c_profile_$(slug).csv")
    meta_path = joinpath(output_dir, "transition_assets_$(slug).json")

    CSV.write(panel_a_path, panel_a)
    CSV.write(panel_b_path, panel_b)
    CSV.write(panel_c_path, panel_c)

    γc = summary_gamma(summary)
    Th = summary_period_minutes(summary)
    peak_eta3 = nrow(panel_c) > 0 ? maximum(abs.(panel_c.eta_3)) : nothing

    panel_c_profile = if profile_mode == "analytical"
        @warn "Analytical profile mode is scaffolded but not yet enabled; falling back to persisted profile columns." campaign=campaign
        build_panel_c_profile_matrix(traj_df, panel_a, γc)
    else
        build_panel_c_profile_matrix(traj_df, panel_a, γc)
    end

    CSV.write(panel_c_profile_path, panel_c_profile)

    gamma_count = nrow(panel_c_profile) > 0 ? length(unique(panel_c_profile.gamma)) : 0
    height_count = nrow(panel_c_profile) > 0 ? length(unique(panel_c_profile.height_z)) : 0

    meta = Dict(
        "campaign" => campaign,
        "slug" => slug,
        "has_transition_assets" => (nrow(panel_a) > 0 && nrow(panel_b) > 0 && nrow(panel_c) > 0),
        "has_transition_panel_c_profile" => (nrow(panel_c_profile) > 0 && gamma_count >= 3 && height_count >= 3),
        "panel_a_csv" => panel_a_path,
        "panel_b_csv" => panel_b_path,
        "panel_c_csv" => panel_c_path,
        "panel_c_profile_csv" => panel_c_profile_path,
        "ri_c_critical" => 0.25,
        "profile_source_mode" => profile_mode,
        "gamma_critical" => γc,
        "hopf_period_minutes" => Th,
        "peak_abs_eta3" => peak_eta3,
        "panel_a_rows" => nrow(panel_a),
        "panel_b_rows" => nrow(panel_b),
        "panel_c_rows" => nrow(panel_c),
        "panel_c_profile_rows" => nrow(panel_c_profile),
        "panel_c_profile_gamma_count" => gamma_count,
        "panel_c_profile_height_count" => height_count,
        "panel_c_profile_height_min" => nrow(panel_c_profile) > 0 ? minimum(panel_c_profile.height_z) : nothing,
        "panel_c_profile_height_max" => nrow(panel_c_profile) > 0 ? maximum(panel_c_profile.height_z) : nothing,
        "panel_ab_status" => ab_status,
        "source_branch_csv" => branch_csv,
        "source_summary_json" => summary_json,
        "source_trajectory_csv" => trajectory_csv,
    )

    write(meta_path, JSON3.write(meta))

    println("Transition assets written:")
    println("  panel_a: $(panel_a_path) [$(nrow(panel_a)) rows]")
    println("  panel_b: $(panel_b_path) [$(nrow(panel_b)) rows]")
    println("  panel_c: $(panel_c_path) [$(nrow(panel_c)) rows]")
    println("  panel_c_profile: $(panel_c_profile_path) [$(nrow(panel_c_profile)) rows]")
    if ab_status != "ok"
        println("  note: Panel A/B source status = $(ab_status)")
    end
    println("  meta:    $(meta_path)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = parse_args(ARGS)
    main(; args...)
end
