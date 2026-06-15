module UltraForcing

using ..CoreTypes

export generate_scm_forcing

function generate_scm_forcing(
    meta::ProfileMetadata,
    surface_h_flux::Real,
    surface_le_flux::Real,
    base_wind_speed::Real,
    nz::Integer;
    prescribed_surface_fluxes::Bool=true,
)
    zeta_ref = isfinite(meta.obukhov_length) && abs(meta.obukhov_length) > 1.0e-5 ?
               meta.reference_height / meta.obukhov_length : 0.0

    return (
        theta_tendency = zeros(Float64, nz),
        q_tendency = zeros(Float64, nz),
        u_tendency = zeros(Float64, nz),
        v_tendency = zeros(Float64, nz),
        sensible_flux = Float64(surface_h_flux),
        latent_flux = Float64(surface_le_flux),
        shortwave_down = 0.0,
        longwave_down = 0.0,
        air_temperature_ref = NaN,
        specific_humidity_ref = NaN,
        wind_speed_ref = Float64(base_wind_speed),
        surface_pressure = 101325.0,
        friction_velocity = meta.friction_velocity,
        obukhov_length = meta.obukhov_length,
        zeta_reference = zeta_ref,
        reference_height = meta.reference_height,
        prescribed_surface_fluxes = prescribed_surface_fluxes,
    )
end

end # module UltraForcing
