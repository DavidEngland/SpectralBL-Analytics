module SmearAdapter

using DataFrames
using Dates
using ..CoreTypes

export profile_from_legacy, profile_to_legacy

function profile_from_legacy(
    datetime::DateTime,
    heights::Vector{Float64},
    values::Vector{Float64},
    zeta::Float64,
    ustar::Float64;
    reference_height::Float64=23.0,
    canopy_displacement::Float64=0.0,
)
    L = abs(zeta) > 1.0e-12 ? reference_height / zeta : NaN
    meta = ProfileMetadata(datetime, ustar, L, reference_height, canopy_displacement)
    return MeteorologicalProfile(meta, heights, values)
end

function profile_to_legacy(prof::MeteorologicalProfile, n_obs::Int)
    zeta = isfinite(prof.metadata.obukhov_length) && abs(prof.metadata.obukhov_length) > 1.0e-12 ?
           prof.metadata.reference_height / prof.metadata.obukhov_length : NaN
    return (
        datetime = prof.metadata.timestamp,
        heights = prof.heights,
        values = prof.values,
        n_obs = n_obs,
        zeta = zeta,
        ustar = prof.metadata.friction_velocity,
    )
end

end # module SmearAdapter
