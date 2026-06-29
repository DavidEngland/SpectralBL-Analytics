#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

const ROOT = normpath(joinpath(@__DIR__, ".."))

function run_script(relpath::String; args::Vector{String}=String[])
    full = joinpath(ROOT, relpath)
    println("[manuscript-figures] running ", relpath)
    cmd = `julia --project=. $full $(args...)`
    run(cmd)
end

function main()
    scripts = [
        "scripts/plot_fig4_manifold.jl",
        "scripts/plot_fig5_archetypes.jl",
        "scripts/plot_fig6_shadow_timeseries.jl",
        "scripts/plot_fig7_slowing_down.jl",
        "scripts/plot_fig8_universal_collapse.jl",
        "scripts/plot_reversed_s.jl",
        "scripts/plot_aligned_transition.jl",
    ]

    for s in scripts
        run_script(s)
    end

    for campaign in ["CASES-99", "FLOSS", "BLLAST", "GABLS3"]
        run_script("scripts/plot_real_aligned_transition.jl"; args=[campaign])
    end

    println("[manuscript-figures] done")
end

main()
