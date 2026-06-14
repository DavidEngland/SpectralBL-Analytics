# src/IngestionFormatters.jl
module IngestionFormatters

export CampaignConfig, get_campaign_geometry

"""
    CampaignConfig

Holds rigid tower heights, physical displacements, and aerodynamic anchors
for an experimental domain.
"""
struct CampaignConfig
    name::String
    tower_heights::Vector{Float64} # Physical measurement levels (z)
    z0m::Float64                  # Aerodynamic roughness length for momentum
    z0h::Float64                  # Aerodynamic roughness length for heat
    d::Float64                    # Displacement height coordinate shift
end

function get_campaign_geometry(campaign::Symbol)
    if campaign == :CASES_99
        # 60m main tower classic levels (e.g., 1.5m, 5m, 10m, 20m, 30m, 40m, 50m, 55m)
        return CampaignConfig("CASES-99", [1.5, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0], 0.03, 0.003, 0.0)
    elseif campaign == :GABLS3
        # Cabauw tower tall configurations (e.g., up to 200m)
        return CampaignConfig("GABLS3", [10.0, 20.0, 40.0, 80.0, 120.0, 200.0], 0.15, 0.015, 0.0)
    else
        error("Unknown campaign target configuration: ", campaign)
    end
end

end # module