module CoreTypes

using Dates

export AbstractObservationalTower, ProfileMetadata, MeteorologicalProfile

abstract type AbstractObservationalTower end

struct ProfileMetadata
    timestamp::DateTime
    friction_velocity::Float64
    obukhov_length::Float64
    reference_height::Float64
    canopy_displacement::Float64
end

struct MeteorologicalProfile
    metadata::ProfileMetadata
    heights::Vector{Float64}
    values::Vector{Float64}
end

end # module CoreTypes
