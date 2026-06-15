module NEONAdapter

using Dates
using DataFrames
using ..CoreTypes: MeteorologicalProfile, ProfileMetadata

export extract_neon_profile

"""
    extract_neon_profile(df, prefix, heights; reference_height=10.0)

Extract timestamped profiles from unstacked NEON-like columns named
`<prefix>_z1`, `<prefix>_z2`, ..., `<prefix>_zN` where N is `length(heights)`.
Rows missing any target level are skipped.
"""
function extract_neon_profile(
    df::DataFrame,
    prefix::String,
    heights::Vector{Float64};
    reference_height::Float64=10.0,
)
    n_levels = length(heights)
    n_levels >= 2 || error("Need at least two heights for a profile")

    col_names = ["$(prefix)_z$(i)" for i in 1:n_levels]
    available = filter(c -> c in names(df), col_names)
    length(available) == n_levels || error("Missing expected NEON profile columns. Found: $(available)")

    datetime_col = :datetime in names(df) ? :datetime : (:timestamp in names(df) ? :timestamp : nothing)
    datetime_col === nothing && error("Expected a datetime/timestamp column in NEON input")

    profiles = MeteorologicalProfile[]
    for row in eachrow(df)
        dt_raw = row[datetime_col]
        dt = dt_raw isa DateTime ? dt_raw : tryparse(DateTime, string(dt_raw))
        dt === nothing && continue

        vals = Float64[]
        valid = true
        for cname in col_names
            v = row[Symbol(cname)]
            if ismissing(v)
                valid = false
                break
            end
            fv = v isa Number ? Float64(v) : something(tryparse(Float64, string(v)), NaN)
            if !isfinite(fv)
                valid = false
                break
            end
            push!(vals, fv)
        end
        valid || continue

        ustar = _row_float(row, [:ustar, :u_star, :friction_velocity], NaN)
        L = _row_float(row, [:L, :L_obukhov, :mo_length], NaN)

        meta = ProfileMetadata(dt, ustar, L, reference_height, 0.0)
        push!(profiles, MeteorologicalProfile(meta, heights, vals))
    end

    return profiles
end

@inline function _row_float(row, candidates::Vector{Symbol}, default::Float64)
    row_names = propertynames(row)
    for col in candidates
        if col in row_names
            value = row[col]
            if value isa Number
                return Float64(value)
            elseif ismissing(value)
                continue
            end
            parsed = tryparse(Float64, string(value))
            parsed === nothing || return parsed
        end
    end
    return default
end

end # module NEONAdapter
