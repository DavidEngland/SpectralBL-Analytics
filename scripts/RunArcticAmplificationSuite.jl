#!/usr/bin/env julia

using Pkg
Pkg.activate(".")

using DataFrames
using Statistics
using Random
using LinearAlgebra

include("../src/SpectralDiagnostics.jl")
include("TexExporter.jl")
using .SpectralDiagnostics
using .TexExporter

struct MockWorkspace
    N::Int
    z_atm::Vector{Float64}
    xi_target::Vector{Float64}
    Dz_atm::Matrix{Float64}
    Manifold_Mass::Matrix{Float64}
    psi_M::Vector{Float64}
    psi_W::Vector{Float64}
    psi_T::Vector{Float64}
    z_0m::Float64
    z_top::Float64
    alpha_stretch::Float64
end

function build_arctic_workspace(N::Int=32)
    d_dim = N + 1
    z_0m = 0.5
    z_top = 80.0
    alpha_stretch = 1.85

    xi = [cos(pi * i / N) for i in 0:N]
    z_atm = z_0m .+ (z_top - z_0m) .* (1.0 .+ xi) ./ 2.0

    dz = zeros(d_dim, d_dim)
    for i in 1:d_dim, j in 1:d_dim
        if i != j
            dz[i, j] = 1.0 / (z_atm[i] - z_atm[j] + 1e-5)
        end
    end
    for i in 1:d_dim
        dz[i, i] = -sum(dz[i, :])
    end

    m_mass = Matrix{Float64}(I, d_dim, d_dim) .* 0.05

    psi_t = [exp(-((z - z_0m) / 12.0)^2) for z in z_atm]
    psi_m = [1.0 - exp(-((z_top - z) / 25.0)^2) for z in z_atm]
    psi_w = 1.0 .- psi_t .- psi_m

    for i in 1:d_dim
        total = psi_t[i] + psi_w[i] + psi_m[i]
        if abs(total) <= eps(Float64)
            psi_t[i] = 1 / 3
            psi_w[i] = 1 / 3
            psi_m[i] = 1 / 3
        else
            psi_t[i] /= total
            psi_w[i] /= total
            psi_m[i] /= total
        end
    end

    return MockWorkspace(N, z_atm, xi, dz, m_mass, psi_m, psi_w, psi_t, z_0m, z_top, alpha_stretch)
end

function run_arctic_amplification_simulation()
    println("Initializing Arctic Amplification HLBL suite...")
    ws = build_arctic_workspace(32)
    rng = MersenneTwister(881)

    days = 1:30
    records = HighFidelityRecord{Float64}[]

    println("Simulating synthetic 30-day synoptic trajectory...")
    for day in days
        aa_phase = (15 <= day <= 22)
        push!(records, compute_arctic_record(ws, day; rng=rng, aa_phase=aa_phase))
    end

    summary_df = summarize_records(records)

    println("Trajectory diagnostics summary:")
    show(stdout, "text/plain", summary_df)
    println()

    generated_dir = joinpath("drafts", "sections", "generated")
    println("Exporting TeX snippets to " * generated_dir)

    export_parameters(ws, joinpath(generated_dir, "arctic_params.tex"))
    export_table(summary_df, joinpath(generated_dir, "table_arctic_synoptic.tex");
        caption="High-Latitude Boundary Layer (HSNBL) modal dimension and wave budget responses during simulated Arctic Amplification window.",
        label="tab:arctic_synoptic",
        digits=3,
    )

    println("Arctic suite execution complete.")
end

run_arctic_amplification_simulation()
