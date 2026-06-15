"""
SmearPipeline.jl
================
Julia data pipeline for SmartSMEAR API → Parquet → Chebyshev spectral analysis.

Targets: Hyytiälä (SMEAR-II) and Värriö (SMEAR-I)
Focus:   Vertical profile spectral fingerprinting for PBL science

Dependencies (add to Project.toml):
    HTTP, CSV, DataFrames, Dates, Arrow, DuckDB,
    ApproxFun, Statistics, JSON3, Logging, ProgressMeter
"""

module SmearPipeline

include("ultra/core_types.jl")
include("ultra/spectral_engine.jl")
include("ultra/stability.jl")
include("ultra/forcing.jl")
include("ultra/adapters/cabauw_adapter.jl")
include("ultra/adapters/smear_adapter.jl")
include("ultra/adapters/neon_adapter.jl")
include("ultra/adapters/icos_adapter.jl")

# ─────────────────────────────────────────────
# VARRIÖ (STATION 1) CONSTANTS
# ─────────────────────────────────────────────

const VAR_VARS = Dict(
    # Temperature profile (°C) -- likely SmartSMEAR variable names
    :T_2m  => "VAR_META.T2",
    :T_4m  => "VAR_META.T4",
    :T_6_6m => "VAR_META.T66",
    :T_9m  => "VAR_META.T9",
    :T_15m => "VAR_META.T15",
    # Wind speed (optional, for future use)
    :WS_2m  => "VAR_META.WS2",
    :WS_4m  => "VAR_META.WS4",
    :WS_6_6m => "VAR_META.WS66",
    :WS_9m  => "VAR_META.WS9",
    :WS_15m => "VAR_META.WS15",
    # Wind direction (optional)
    :WD_2m  => "VAR_META.WD2",
    :WD_4m  => "VAR_META.WD4",
    :WD_6_6m => "VAR_META.WD66",
    :WD_9m  => "VAR_META.WD9",
    :WD_15m => "VAR_META.WD15",
)

const VAR_HEIGHTS = Dict(
    :T => [2.0, 4.0, 6.6, 9.0, 15.0],
    :WS => [2.0, 4.0, 6.6, 9.0, 15.0],
    :WD => [2.0, 4.0, 6.6, 9.0, 15.0],
)

using HTTP
using CSV
using DataFrames
using Dates
using Arrow          # Parquet-compatible columnar storage
using DuckDB
using ApproxFun
using LinearAlgebra
using Statistics
using JSON3
using Logging
using ProgressMeter

using .CoreTypes: AbstractObservationalTower, ProfileMetadata, MeteorologicalProfile, StandardizedBLObservation
using .UltraForcing: generate_scm_forcing
using .UltraStability: classify_stability

export fetch_smear_tiled, store_parquet, load_parquet,
       build_vertical_profiles, chebyshev_fingerprint,
    batch_fingerprint, open_duckdb_store,
    build_standardized_vertical_observations, standardize_profile,
    ProfileTuple,
    forcing_from_smear_row,
    AbstractObservationalTower,
    ProfileMetadata,
    MeteorologicalProfile,
    StandardizedBLObservation,
    generate_scm_forcing,
    CabauwTower,
    extract_temperature_profiles,
    extract_temperature_observations,
    extract_neon_profile,
    extract_neon_observations,
    upscale_sparse_icos_profile,
    upscale_sparse_icos_observation

const ProfileTuple = NamedTuple{(:datetime, :heights, :values, :n_obs, :zeta, :ustar), Tuple{DateTime, Vector{Float64}, Vector{Float64}, Int, Float64, Float64}}

const CabauwTower = CabauwAdapter.CabauwTower

extract_temperature_profiles(df::DataFrame, tower::CabauwTower=CabauwTower()) =
    CabauwAdapter.extract_temperature_profiles(df, tower)

extract_temperature_observations(
    df::DataFrame,
    tower::CabauwTower=CabauwTower();
    campaign::String="GABLS3",
    z0m::Float64=0.15,
) = CabauwAdapter.extract_temperature_observations(df, tower; campaign, z0m)

extract_neon_profile(
    df::DataFrame,
    prefix::String,
    heights::Vector{Float64};
    reference_height::Float64=10.0,
) = NEONAdapter.extract_neon_profile(df, prefix, heights; reference_height)

extract_neon_observations(
    df::DataFrame,
    prefix::String,
    heights::Vector{Float64};
    campaign::String="NEON",
    z0m::Float64=NaN,
    min_levels::Int=2,
    reference_height::Float64=10.0,
) = NEONAdapter.extract_neon_observations(
    df,
    prefix,
    heights;
    campaign,
    z0m,
    min_levels,
    reference_height,
)

upscale_sparse_icos_profile(
    dt::DateTime,
    z_low::Float64,
    z_high::Float64,
    v_low::Float64,
    v_high::Float64,
    ustar::Float64,
    L::Float64;
    target_levels::Vector{Float64}=[2.0, 5.0, 10.0, 20.0, 40.0],
    stability_correction::Symbol=:none,
) = ICOSAdapter.upscale_sparse_icos_profile(
    dt,
    z_low,
    z_high,
    v_low,
    v_high,
    ustar,
    L;
    target_levels,
    stability_correction,
)

upscale_sparse_icos_observation(
    dt::DateTime,
    z_low::Float64,
    z_high::Float64,
    v_low::Float64,
    v_high::Float64,
    ustar::Float64,
    L::Float64;
    campaign::String="ICOS-Upscaled",
    z0m::Float64=NaN,
    target_levels::Vector{Float64}=[2.0, 5.0, 10.0, 20.0, 40.0],
    stability_correction::Symbol=:none,
) = ICOSAdapter.upscale_sparse_icos_observation(
    dt,
    z_low,
    z_high,
    v_low,
    v_high,
    ustar,
    L;
    campaign,
    z0m,
    target_levels,
    stability_correction,
)

# ─────────────────────────────────────────────
# 1. CONSTANTS & STATION METADATA
# ─────────────────────────────────────────────

const SMEAR_BASE = "https://smear-backend-avaa-smear-prod.2.rahtiapp.fi"
const TIMEOUT_S  = 120   # seconds before retry
const MAX_RETRY  = 5
const TILE_DAYS  = 7     # request window size to avoid API timeout

"""
Variable tables for SMEAR-II Hyytiälä.
Keys are semantic names; values are the API tablevariable strings.

Heights for CO₂ / O₃ profile at HYY: 4.2, 8.4, 16.8, 33.6, 67.2 m
Heights for temperature profile:      2, 4, 8, 16, 32, 67 m
"""
const HYY_VARS = Dict(
    # CO₂ profile (μmol mol⁻¹)
    :co2_4m   => "HYY_EDDY233.CO2_4",
    :co2_8m   => "HYY_EDDY233.CO2_8",
    :co2_17m  => "HYY_EDDY233.CO2_17",
    :co2_34m  => "HYY_EDDY233.CO2_34",
    :co2_67m  => "HYY_EDDY233.CO2_67",
    # O₃ profile (ppb) — slow-response sensors
    :o3_4m    => "HYY_META.O3_4",
    :o3_8m    => "HYY_META.O3_8",
    :o3_16m   => "HYY_META.O3_16",
    :o3_32m   => "HYY_META.O3_32",
    # Temperature profile (°C)
    :T_2m     => "HYY_META.T42",
    :T_4m     => "HYY_META.T84",
    :T_8m     => "HYY_META.T168",
    :T_16m    => "HYY_META.T336",
    :T_32m    => "HYY_META.T504",
    :T_67m    => "HYY_META.T672",
    # Stability / flux metadata
    :ustar    => "HYY_EDDY233.u_star",
    :L_obukhov => "HYY_EDDY233.MO_length",       # Obukhov length (m)
    :H_flux   => "HYY_EDDY233.H",        # Sensible heat flux (W m⁻²)
    :LE_flux  => "HYY_EDDY233.LE",       # Latent heat flux (W m⁻²)
    :wind_spd => "HYY_META.WSP_1",
    :wind_dir => "HYY_META.WDP_1",
)

# Measurement heights (m) for each profile variable group
const HYY_HEIGHTS = Dict(
    :co2 => [4.2, 8.4, 16.8, 33.6, 67.2],
    :o3  => [4.0, 8.0, 16.0, 32.0],
    :T   => [4.2, 8.4, 16.8, 33.6, 67.2],
)

# ─────────────────────────────────────────────
# 2. API FETCHING — TILED WITH RETRY
# ─────────────────────────────────────────────

"""
    fetch_smear_tiled(tablevars, start_dt, end_dt; aggregation, quality, tile_days)

Fetch a set of tablevariable strings from the SmartSMEAR API over a date range,
breaking the request into tiles of `tile_days` to avoid server timeouts.

Returns a single merged DataFrame with a parsed `DateTime` column.

# Arguments
- `tablevars`: Vector of tablevariable strings, e.g. ["HYY_EDDY233.CO2_4", ...]
- `start_dt`:  DateTime (UTC)
- `end_dt`:    DateTime (UTC)
- `aggregation`: "NONE" | "30MIN" | "60MIN" (default "NONE" = raw)
- `quality`:   "ANY" | "GOOD" (default "ANY")
- `tile_days`: size of each API request window (default 7)
"""
function fetch_smear_tiled(
    tablevars::Vector{String},
    start_dt::DateTime,
    end_dt::DateTime;
    aggregation::String = "NONE",
    quality::String     = "ANY",
    tile_days::Int      = TILE_DAYS,
)
    tiles = _build_tiles(start_dt, end_dt, tile_days)
    @info "Fetching $(length(tablevars)) variables over $(length(tiles)) tiles"

    frames = DataFrame[]
    @showprogress "Fetching tiles..." for (t_start, t_end) in tiles
        df = _fetch_tile(tablevars, t_start, t_end; aggregation, quality)
        isnothing(df) || push!(frames, df)
    end

    isempty(frames) && error("All tiles returned empty — check variable names and date range")

    result = vcat(frames...; cols=:union)
    _parse_datetime!(result)
    sort!(result, :datetime)
    return result
end

function _build_tiles(start_dt::DateTime, end_dt::DateTime, tile_days::Int)
    tiles = Tuple{DateTime,DateTime}[]
    t = start_dt
    while t < end_dt
        t_next = min(t + Day(tile_days), end_dt)
        push!(tiles, (t, t_next))
        t = t_next
    end
    return tiles
end

function _fetch_tile(
    tablevars::Vector{String},
    start_dt::DateTime,
    end_dt::DateTime;
    aggregation::String,
    quality::String,
)
    from_str = Dates.format(start_dt, "yyyy-mm-ddTHH:MM:SS")
    to_str   = Dates.format(end_dt,   "yyyy-mm-ddTHH:MM:SS")

    # SmartSMEAR expects repeated tablevariable query keys (not comma-joined values).
    params = String[]
    for tv in tablevars
        push!(params, "tablevariable=$(tv)")
    end
    push!(params, "from=$(from_str)")
    push!(params, "to=$(to_str)")
    push!(params, "quality=$(quality)")
    push!(params, "aggregation=$(aggregation)")
    url = "$(SMEAR_BASE)/search/timeseries/csv?" * join(params, "&")

    for attempt in 1:MAX_RETRY
        try
            resp = HTTP.get(url; readtimeout=TIMEOUT_S)
            if resp.status == 200 && length(resp.body) > 50
                df = CSV.read(resp.body, DataFrame; missingstring=["", "NaN", "NA"])
                @debug "Tile $(from_str) → $(to_str): $(nrow(df)) rows"
                return df
            else
                @warn "Empty response for tile $(from_str), attempt $attempt"
            end
        catch e
            @warn "Fetch error (attempt $attempt): $e"
            sleep(2^attempt)   # exponential backoff
        end
    end
    @error "Tile $(from_str) → $(to_str) failed after $(MAX_RETRY) attempts"
    return nothing
end

"""Parse SmartSMEAR's timestamp columns (Year, Month, Day, Hour, Minute, Second) 
into a single Julia DateTime column."""
function _parse_datetime!(df::DataFrame)
    if all(c -> c in names(df), ["Year","Month","Day","Hour","Minute","Second"])
        df.datetime = DateTime.(
            Int.(df.Year), Int.(df.Month), Int.(df.Day),
            Int.(df.Hour), Int.(df.Minute), Int.(df.Second)
        )
        select!(df, Not(["Year","Month","Day","Hour","Minute","Second"]))
    else
        error("Expected SMEAR timestamp columns not found. Got: $(names(df))")
    end
end

# ─────────────────────────────────────────────
# 3. STORAGE — PARQUET VIA ARROW
# ─────────────────────────────────────────────

"""
    store_parquet(df, path)

Write a DataFrame to a Parquet file using Arrow.jl.
Creates parent directories as needed.
"""
function store_parquet(df::DataFrame, path::String)
    mkpath(dirname(path))
    Arrow.write(path, df; compress=:zstd)
    sz = filesize(path) / 1024
    @info "Stored $(nrow(df)) rows → $path ($(round(sz, digits=1)) KB)"
end

"""
    load_parquet(path) → DataFrame

Load a Parquet file written by `store_parquet`.
"""
function load_parquet(path::String)::DataFrame
    return DataFrame(Arrow.Table(path))
end

# ─────────────────────────────────────────────
# 4. DUCKDB ANALYTICAL STORE
# ─────────────────────────────────────────────

"""
    open_duckdb_store(db_path) → DuckDB.DB

Open (or create) a DuckDB database. Tables are registered lazily from Parquet files.

Usage:
    db = open_duckdb_store("data/smear.duckdb")
    register_parquet_table(db, "co2_raw", "data/co2_raw.parquet")
    df = query(db, "SELECT * FROM co2_raw WHERE L_obukhov < -100 LIMIT 100")
"""
function open_duckdb_store(db_path::String)
    mkpath(dirname(db_path))
    return DuckDB.open(db_path)
end

function register_parquet_table(db::DuckDB.DB, table_name::String, parquet_path::String)
    DuckDB.execute(db, """
        CREATE OR REPLACE VIEW $(table_name) AS
        SELECT * FROM read_parquet('$(parquet_path)')
    """)
    @info "Registered DuckDB view: $(table_name) → $(parquet_path)"
end

function query(db::DuckDB.DB, sql::String)::DataFrame
    return DataFrame(DuckDB.execute(db, sql))
end

# ─────────────────────────────────────────────
# 5. VERTICAL PROFILE CONSTRUCTION
# ─────────────────────────────────────────────

"""
    build_vertical_profiles(df, tracer; heights, col_prefix, window_minutes)

Extract 30-minute median vertical profiles from a raw DataFrame.

Returns a Vector of NamedTuples:
    (datetime, heights, values, n_obs, zeta, ustar)

# Arguments
- `tracer`:         :co2 | :o3 | :T
- `heights`:        vector of measurement heights in metres
- `col_prefix`:     column name prefix matching DataFrame columns
- `window_minutes`: averaging window (default 30)
"""
function build_vertical_profiles(
    df::DataFrame,
    tracer::Symbol;
    heights::Vector{Float64}  = HYY_HEIGHTS[tracer],
    col_names::Vector{String} = _default_colnames(tracer),
    window_minutes::Int       = 30,
)
    # Validate columns exist
    missing_cols = filter(c -> !(c in names(df)), col_names)
    isempty(missing_cols) || error("Missing columns: $missing_cols")

    # Add 30-min window key
    df_copy = copy(df)
    df_copy.window = floor.(df_copy.datetime, Minute(window_minutes))

    profiles = ProfileTuple[]

    for (win, grp) in pairs(groupby(df_copy, :window))
        vals = Float64[]
        valid = true

        for col in col_names
            med = _nanmedian(grp[!, col])
            if isnan(med)
                valid = false; break
            end
            push!(vals, med)
        end

        valid || continue

        # Stability parameter ζ = z_ref / L_obukhov (reference height = 23m canopy top)
        l_col = _first_present_col(grp, [:L_obukhov, Symbol("VAR_EDDY.MO_length")])
        u_col = _first_present_col(grp, [:ustar, Symbol("VAR_EDDY.u_star")])

        zeta = isnothing(l_col) ? NaN : begin
            L = _nanmedian(grp[!, l_col])
            isnan(L) || abs(L) < 1e-9 ? NaN : 23.0 / L
        end
        ustar = isnothing(u_col) ? NaN : _nanmedian(grp[!, u_col])

        L_val = abs(zeta) > 1.0e-12 ? 23.0 / zeta : NaN
        meta = ProfileMetadata(win.window, ustar, L_val, 23.0, 0.0)
        prof = MeteorologicalProfile(meta, heights, vals)
        push!(profiles, ProfileTuple(SmearAdapter.profile_to_legacy(prof, nrow(grp))))
    end

    @info "Built $(length(profiles)) $(tracer) profiles from $(nrow(df)) raw rows"
    return profiles
end

"""
    standardize_profile(profile; campaign="SMEAR", z0m=NaN, robust_for_eta3=nothing)

Convert a legacy profile tuple into the campaign-agnostic standardized observation
payload used by unified ingestion adapters.
"""
function standardize_profile(
    profile::ProfileTuple;
    campaign::String="SMEAR",
    z0m::Float64=NaN,
    reference_height::Float64=23.0,
    robust_for_eta3::Union{Nothing,Bool}=nothing,
)
    return SmearAdapter.standardized_from_legacy(
        profile.datetime,
        profile.heights,
        profile.values,
        profile.zeta,
        profile.ustar;
        campaign,
        reference_height,
        z0m,
        robust_for_eta3,
    )
end

"""
    build_standardized_vertical_observations(df, tracer; kwargs...)

Build legacy profile tuples and immediately normalize them into the standardized
intermediate observation payload.
"""
function build_standardized_vertical_observations(
    df::DataFrame,
    tracer::Symbol;
    campaign::String="SMEAR",
    z0m::Float64=NaN,
    reference_height::Float64=23.0,
    robust_for_eta3::Union{Nothing,Bool}=nothing,
    heights::Vector{Float64}=HYY_HEIGHTS[tracer],
    col_names::Vector{String}=_default_colnames(tracer),
    window_minutes::Int=30,
)
    profiles = build_vertical_profiles(
        df,
        tracer;
        heights,
        col_names,
        window_minutes,
    )

    return [
        standardize_profile(
            p;
            campaign,
            z0m,
            reference_height,
            robust_for_eta3,
        ) for p in profiles
    ]
end

function _default_colnames(tracer::Symbol)
    tracer == :co2 && return ["HYY_EDDY233.CO2_4","HYY_EDDY233.CO2_8",
                               "HYY_EDDY233.CO2_17","HYY_EDDY233.CO2_34","HYY_EDDY233.CO2_67"]
    tracer == :o3  && return ["HYY_META.O3_4","HYY_META.O3_8",
                               "HYY_META.O3_16","HYY_META.O3_32"]
    tracer == :T   && return ["HYY_META.T42","HYY_META.T84","HYY_META.T168",
                               "HYY_META.T336","HYY_META.T672"]
    error("Unknown tracer: $tracer")
end

function _nanmedian(v)
    vals = Float64[]
    for x in v
        ismissing(x) && continue
        push!(vals, Float64(x))
    end
    return isempty(vals) ? NaN : median(vals)
end

function _first_present_col(df, candidates::Vector{Symbol})
    for col in candidates
        col in propertynames(df) && return col
    end
    return nothing
end

# ─────────────────────────────────────────────
# 6. CHEBYSHEV SPECTRAL FINGERPRINT
# ─────────────────────────────────────────────

"""
    chebyshev_fingerprint(heights, values; n_coeffs) → Vector{Float64}

Map a vertical profile (heights, values) onto a Chebyshev basis on [-1, 1]
and return the first `n_coeffs` Chebyshev coefficients.

Coefficient interpretation:
  c[1]  — mean level (DC component)
  c[2]  — linear gradient (bulk vertical transport)
  c[3]  — curvature / stability signature
  c[4]  — higher-order canopy-crown structure

A purely well-mixed neutral profile gives c[2]≈0, c[3]≈0.
A stable profile with surface accumulation gives c[2]>0 (surface enrichment).
"""
function chebyshev_fingerprint(
    heights::Vector{Float64},
    values::Vector{Float64};
    n_coeffs::Int = 4,
    height_mapping::Symbol = :log,
)
    prof = MeteorologicalProfile(
        ProfileMetadata(DateTime(1970, 1, 1), NaN, NaN, 0.0, 0.0),
        heights,
        values,
    )
    return SpectralEngine.chebyshev_fingerprint(prof; n_coeffs, height_mapping)
end

function chebyshev_fingerprint(
    prof::MeteorologicalProfile;
    n_coeffs::Int = 4,
    height_mapping::Symbol = :log,
)
    return SpectralEngine.chebyshev_fingerprint(prof; n_coeffs, height_mapping)
end

"""
    batch_fingerprint(profiles; n_coeffs) → DataFrame

Apply `chebyshev_fingerprint` to a vector of profile NamedTuples 
(as returned by `build_vertical_profiles`).

Returns a DataFrame with columns:
    datetime, c1, c2, c3, c4, zeta, ustar, n_obs, shape_ratio,
    canopy_wake_decay_index, counter_gradient_flag, c2_c3_phase
where `shape_ratio = |c3| / |c2|` is a curvature-to-gradient index.
"""
function batch_fingerprint(
    profiles::Vector{ProfileTuple},
    tracer::Symbol;
    n_coeffs::Int = 4,
    height_mapping::Symbol = :log,
)
    rows = NamedTuple[]
    @showprogress "Fingerprinting $(tracer) profiles..." for p in profiles
        try
            prof = SmearAdapter.profile_from_legacy(
                p.datetime,
                p.heights,
                p.values,
                p.zeta,
                p.ustar;
                reference_height=23.0,
                canopy_displacement=0.0,
            )
            c = chebyshev_fingerprint(prof; n_coeffs, height_mapping)
            shape_ratio = abs(c[2]) > 1e-10 ? abs(c[3]) / abs(c[2]) : NaN
            canopy_wake_decay_index = abs(c[1]) > 1e-10 ? c[4] / c[1] : NaN
            # Flag likely counter-gradient storage in convective regimes.
            counter_gradient_flag = (p.zeta < -0.1) && (c[2] > 0.0)
            c2_c3_phase = atan(c[3], c[2])
            push!(rows, (
                datetime    = p.datetime,
                tracer      = String(tracer),
                c1          = c[1],
                c2          = c[2],
                c3          = c[3],
                c4          = length(c) >= 4 ? c[4] : NaN,
                zeta        = p.zeta,
                ustar       = p.ustar,
                n_obs       = p.n_obs,
                shape_ratio = shape_ratio,
                canopy_wake_decay_index = canopy_wake_decay_index,
                counter_gradient_flag = counter_gradient_flag,
                c2_c3_phase = c2_c3_phase,
            ))
        catch e
            @debug "Skipped profile at $(p.datetime): $e"
        end
    end
    return DataFrame(rows)
end

function batch_fingerprint(
    observations::Vector{StandardizedBLObservation},
    tracer::Symbol;
    n_coeffs::Int=4,
    height_mapping::Symbol=:log,
    reference_height::Float64=23.0,
)
    rows = NamedTuple[]
    @showprogress "Fingerprinting $(tracer) standardized observations..." for obs in observations
        try
            prof = SmearAdapter.profile_from_standardized(obs; reference_height)
            c = chebyshev_fingerprint(prof; n_coeffs, height_mapping)
            zeta = isfinite(obs.L_obukhov) && abs(obs.L_obukhov) > 1.0e-12 ? reference_height / obs.L_obukhov : NaN
            shape_ratio = abs(c[2]) > 1e-10 ? abs(c[3]) / abs(c[2]) : NaN
            canopy_wake_decay_index = abs(c[1]) > 1e-10 ? c[4] / c[1] : NaN
            counter_gradient_flag = (zeta < -0.1) && (c[2] > 0.0)
            c2_c3_phase = atan(c[3], c[2])
            push!(rows, (
                datetime    = obs.datetime,
                campaign    = obs.campaign,
                tracer      = String(tracer),
                c1          = c[1],
                c2          = c[2],
                c3          = c[3],
                c4          = length(c) >= 4 ? c[4] : NaN,
                zeta        = zeta,
                ustar       = obs.ustar,
                n_obs       = obs.n_valid_levels,
                robust_for_eta3 = obs.robust_for_eta3,
                shape_ratio = shape_ratio,
                canopy_wake_decay_index = canopy_wake_decay_index,
                counter_gradient_flag = counter_gradient_flag,
                c2_c3_phase = c2_c3_phase,
            ))
        catch e
            @debug "Skipped standardized observation at $(obs.datetime): $e"
        end
    end
    return DataFrame(rows)
end

@inline function _row_value(row, candidates, default)
    row_names = propertynames(row)
    for candidate in candidates
        col = candidate isa Symbol ? candidate : Symbol(candidate)
        if col in row_names
            value = row[col]
            ismissing(value) || return value
        end
    end
    return default
end

@inline function _row_float(row, candidates, default)
    value = _row_value(row, candidates, default)
    if value isa Number
        return Float64(value)
    elseif ismissing(value)
        return Float64(default)
    end
    parsed = tryparse(Float64, string(value))
    return isnothing(parsed) ? Float64(default) : parsed
end

"""
    forcing_from_smear_row(row, nz; theta0=273.15, q0=0.001, reference_height=23.0,
                           prescribed_surface_fluxes=true)

Translate an aggregated SMEAR row into a lightweight forcing NamedTuple that
matches the SCMSkeleton `Forcing` field layout. This avoids a hard module
dependency while providing a direct bridge for SCM setup code.
"""
function forcing_from_smear_row(
    row,
    nz::Integer;
    theta0::Real=273.15,
    q0::Real=0.001,
    reference_height::Real=23.0,
    prescribed_surface_fluxes::Bool=true,
)
    h_flux = _row_float(row, [HYY_VARS[:H_flux], "VAR_EDDY.H", :H_flux], 0.0)
    le_flux = _row_float(row, [HYY_VARS[:LE_flux], "VAR_EDDY.LE", :LE_flux], 0.0)
    ustar = _row_float(row, [HYY_VARS[:ustar], "VAR_EDDY.u_star", :ustar], NaN)
    L = _row_float(row, [HYY_VARS[:L_obukhov], "VAR_EDDY.MO_length", :L_obukhov], NaN)
    u_mag = _row_float(row, [HYY_VARS[:wind_spd], "VAR_EDDY.U", VAR_VARS[:WS_2m], :wind_spd], 5.0)
    t_ref_c = _row_float(row, [HYY_VARS[:T_2m], VAR_VARS[:T_2m], "VAR_META.TDRY0", :T_2m], theta0 - 273.15)
    t_ref = t_ref_c > 200.0 ? t_ref_c : t_ref_c + 273.15
    meta = ProfileMetadata(DateTime(1970, 1, 1), ustar, L, Float64(reference_height), 0.0)
    forcing = generate_scm_forcing(
        meta,
        h_flux,
        le_flux,
        u_mag,
        nz;
        prescribed_surface_fluxes=prescribed_surface_fluxes,
    )

    return (
        forcing...,
        air_temperature_ref = t_ref,
        specific_humidity_ref = Float64(q0),
    )
end

# ─────────────────────────────────────────────
# 7. STABILITY REGIME CLASSIFIER
# ─────────────────────────────────────────────

"""
    classify_stability(zeta) → Symbol

Classify Monin-Obukhov stability from ζ = z/L.

    :strongly_stable   ζ > 1.0
    :stable            0.1 < ζ ≤ 1.0
    :near_neutral      |ζ| ≤ 0.1
    :unstable         -1.0 ≤ ζ < -0.1
    :strongly_unstable ζ < -1.0
    :unknown           NaN
"""
function add_stability_class!(df::DataFrame)
    df.stability = classify_stability.(df.zeta)
    return df
end

end # module SmearPipeline
