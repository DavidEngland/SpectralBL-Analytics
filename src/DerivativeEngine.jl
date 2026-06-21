# src/DerivativeEngine.jl
module DerivativeEngine

using CSV
using DataFrames
using JSON3

export Stage4CoefficientModel, load_stage4_model, analytical_profile_available, build_ri_g_profile_grid

struct Stage4CoefficientModel
    n_states::Int
    equations::Dict{String,Any}
end

function load_stage4_model(stage4_json_path::String)
    if !isfile(stage4_json_path)
        return nothing
    end
    obj = JSON3.read(read(stage4_json_path, String))
    n_states = haskey(obj, "n_states") ? Int(obj["n_states"]) : 0
    equations = haskey(obj, "equations") ? Dict{String,Any}(pairs(obj["equations"])) : Dict{String,Any}()
    return Stage4CoefficientModel(n_states, equations)
end

function analytical_profile_available(stage4_json_path::String)
    model = load_stage4_model(stage4_json_path)
    return model !== nothing && model.n_states > 0 && !isempty(model.equations)
end

"""
    build_ri_g_profile_grid(; stage4_json_path, branch_csv_path, z_min=0.0, z_max=200.0, z_step=1.0)

Scaffold for future analytical inverse-map implementation. Returns an empty DataFrame for now.
This placeholder keeps pipeline interfaces stable while MVP profile mode uses persisted ri_g_* columns.
"""
function build_ri_g_profile_grid(; stage4_json_path::String, branch_csv_path::String, z_min::Float64=0.0, z_max::Float64=200.0, z_step::Float64=1.0)
    return DataFrame(gamma=Float64[], height_z=Float64[], ri_g=Float64[])
end

end
