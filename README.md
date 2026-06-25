# SpectralBL-Analytics

---
## 🎯 **NEW: Phase 1 Geometric Precursor Analysis - VALIDATED ✅**

**Status**: Multi-campaign validation SUCCESSFUL (June 2026)

We've implemented **trajectory curvature κ(t) as a coordinate-independent early-warning signal** for SBL regime transitions:

- ✅ **GABLS3** (24h diurnal): Sharp curvature spikes at transition periods
- ✅ **CASES-99** (686h multi-month): Isolated spikes every ~2-3 days matching synoptic timescales  
- ✅ **Scale-invariant**: Peak κ ~ 1000-2000 despite 240× difference in state-space excursions
- ✅ **Orthogonal to classical metrics**: Independent of Richardson number

**Quick Start**: [`QUICKSTART_PHASE1.md`](QUICKSTART_PHASE1.md) | **Results**: [`reports/PHASE1_MULTICAMPAIGN_RESULTS.md`](reports/PHASE1_MULTICAMPAIGN_RESULTS.md)

```bash
julia --project=. scripts/precursor_diagnostic.jl gabls3
julia --project=. scripts/precursor_diagnostic.jl cases_99
```
---

## Overview

SpectralBL-Analytics is a Julia-based atmospheric boundary layer (ABL) diagnostics and reporting pipeline. It ingests campaign observations, projects profiles into a reduced attractor space, computes physically interpretable metrics, and renders publication-ready TeX/PDF outputs.

Production workflows support CASES-99 (tower data), GABLS3 (Cabauw observations), and FLOSS (Fluxes Over Snow Surfaces). Experimental support for SMEAR-I, NEON, ICOS, and SHEBA campaigns is available via the SmearPipeline adapter ecosystem. All workflows include automated report generation with PGFPlots externalized figures.

## What This Repository Does

1. Ingests tower/model profiles from campaign datasets via pluggable adapters (Cabauw, SMEAR, NEON, ICOS, SHEBA).
2. Builds campaign-specific observation operators and low-rank states.
3. Computes trajectory diagnostics in reduced coordinates (`eta_1`, `eta_2`, `eta_3`).
4. Exports structured CSV/JSON artifacts for reproducible reporting.
5. Renders Mustache templates into TeX sections.
6. Compiles report PDF via LuaLaTeX and `latexmk`.
7. Supports campaign-scoped report isolation (CASES-99, GABLS3) and mixed-campaign analysis (experimental).
 (June 2026)

The reporting orchestrator now includes refined information-theoretic and conditioning diagnostics:

1. Dynamic constrained/nullspace mode partitioning from singular values.
2. Condition number tracking in projected space.
3. Shannon effective dimension (`D_eff = exp(H)`) from singular-value weights.
4. Interaction residual proxy for non-orthogonal regime coupling.
5. Standardized multi-adapter ingestion contract for campaign geometry harmonization.
6. Extended campaign support via SmearPipeline (experimental: SMEAR, NEON, ICOS, SHEBA).
7. Campaign-scoped report isolation (CASES-99.pdf and GABLS3.pdf) with deterministic outputs.

These metrics are embedded in generated report sections and compiled into the final manuscript-ready PDF. See CHANGELOG.md for detailed feature timeline
These metrics are embedded in generated report sections and compiled into the final manuscript-ready PDF.

## Repository Layout

```text
Makefile
Project.toml
Manifest.toml
README.md
QUICKSTART.md
CHANGELOG.md
DATA.md

data/
  cases99/, gabs3/, smear/, neon/, icos/, sheba/
  drafts/

scripts/
  extract_attractor_diagnostics.jl
  regenerate_tex_exports.jl
  build_campaign_report.jl

src/
  AttractorDiagnostics.jl
  IngestionFormatters.jl
  ReportingTeX.jl
  SmearPipeline.jl
  io/ExportPipeline.jl
  ultra/
    core_types.jl
    adapters/
      cabauw_adapter.jl
      smear_adapter.jl
      neon_adapter.jl
      icos_adapter.jl
      sheba_adapter.jl

templates/
  attractor_report.tex.mustache
  regime_decomposition.tex.mustache
  conclusions_and_diagnostics.tex.mustache

reports/
  cases99_run/, gabls3_run/, all_run/
    main.tex
    generated/
    tikz-cache/

test/
  runtests.jl
```

## Requirements

1. Julia 1.12+
2. TeX Live with `lualatex` and `latexmk`
3. Campaign data available in `data/`

## End-to-End Workflow

Use the Makefile targets in order:

```bash
make purge
make process
make tex
make report
make compile-report
```

Shortcut for the canonical Cabauw/GABLS3 workflow:

```bash
make cabauw-report
```

Dedicated campaign report targets:

```bash
make cases99-report
make gabls3-report
make process CAMPAIGN=FLOSS
make stage2-pipeline CAMPAIGN=FLOSS
```

Campaign-scoped variants:

```bash
make process CAMPAIGN=GABLS3
make report CAMPAIGN=GABLS3
make process CAMPAIGN=CASES-99
make report CAMPAIGN=CASES-99
make process CAMPAIGN=FLOSS
make stage2-pipeline CAMPAIGN=FLOSS
```

Primary artifacts produced:

1. `data/drafts/trajectories/trajectory_master.csv` — master trajectory table with reduced coordinates and diagnostics
2. `data/outputs/regime_trajectories.csv` — regime-structured trajectory subset for visualization
3. `data/outputs/regime_scatterplots.csv` — scatter-plot data for PGFPlots rendering
4. `data/outputs/report_manifest.json` — campaign metadata and run parameters
5. `reports/cases99_run/CASES-99.pdf` — campaign-specific report for CASES-99
6. `reports/gabls3_run/GABLS3.pdf` — campaign-specific report for GABLS3 (Cabauw)
7. `reports/all_run/main.pdf` — mixed-campaign analysis output (experimental; only produced if `CAMPAIGN=ALL` and reports/all_run/ is initialized)
8. `data/outputs/stage5_summary_cases_99.json` — campaign Stage 5 summary metrics (thresholds, slopes, periods)
9. `data/outputs/stage5_summary_floss.json` — campaign Stage 5 summary metrics (thresholds, slopes, periods)

Intermediate TeX/LaTeX artifacts (e.g., `attractor.tex`, `regime.tex`, diagnostics sections) are generated in each report's `generated/` directory during the report-build stage.

## Make Targets

Run `make help` for the latest command list. Core targets:

1. `make init` — instantiate and precompile Julia environment
2. `make process` — run campaign diagnostics extraction for a specific campaign (`CAMPAIGN=CASES-99|GABLS3|ALL`, default `ALL`)
3. `make tex` — regenerate manuscript macro exports
4. `make report` — build report sections from trajectory CSV (requires CSV input; supports `CAMPAIGN` scoping)
5. `make compile-report` — compile PDF report via latexmk and LuaLaTeX
6. `make cases99-report` — full pipeline (`process → tex → report → compile-report`) with `CAMPAIGN=CASES-99`, produces `CASES-99.pdf`
7. `make gabls3-report` — full pipeline with `CAMPAIGN=GABLS3`, produces `GABLS3.pdf`
8. `make cabauw-report` — alias for `gabls3-report` (Cabauw is the GABLS3 tower site)
9. `make test` — run regression test suite (campaign configs, operators, baselines; 20 tests expected to pass)
10. `make clean` — remove logs and temporary runtime files
11. `make purge` — deep clean report/data build artifacts and cached figures
12. `make stage5-sweep` — continuation sweep for Stage 5 stability analysis (`CAMPAIGN`, `SWEEP_DIRECTION`, `GAMMA_MIN`, `GAMMA_MAX`, `GAMMA_STEPS`)
13. `make stage5-panels` — export three panel CSVs for trajectory/abscissa/distance diagnostics
14. `make stage5-summary` — emit campaign summary JSON with comparative Stage 5 metrics

## Stage 5 Comparative Diagnostics

After running Stage 5 for one or more campaigns, use:

```bash
make stage5-panels CAMPAIGN=CASES-99
make stage5-summary CAMPAIGN=CASES-99
make stage5-panels CAMPAIGN=FLOSS
make stage5-summary CAMPAIGN=FLOSS
```

Key summary fields in `data/outputs/stage5_summary_<campaign>.json`:

1. `gamma_c_hopf` - interpolated Hopf threshold from continuation events
2. `closest_to_axis_max_imag` - inferred oscillation clock at the axis approach/crossing
3. `hopf_period_Th` - period estimate `2π/|beta|`
4. `dRe_dgamma_at_crossing` - local crossing slope (vulnerability index)

## Notes on Scientific Interpretation

The generated report includes:

1. Attractor trajectory interpretation in reduced phase space.
2. Information-theoretic manifold complexity diagnostics.
3. Regime-structure and orthogonality analysis.
4. Non-orthogonal coupling residual accounting.

For operator usage details and practical command examples, see `QUICKSTART.md`.

## Supported Campaigns and Adapters

| Campaign | Adapter Module | Data Source | Status | Ingestion Path |
|----------|----------------|-------------|--------|----------------|
| CASES-99 | IngestionFormatters | Tower netCDF profiles | **Production** | scripts/extract_attractor_diagnostics.jl |
| GABLS3 | CabauwAdapter | Cabauw tower observations | **Production** | SmearPipeline.extract_cabauw_observations |
| FLOSS | IngestionFormatters | NCAR/EOL FLOSS-I and FLOSS-II NetCDF tower profiles | **Production** | scripts/extract_attractor_diagnostics.jl |
| SMEAR-I | SmearAdapter | SMEAR station JSON records | Experimental | SmearPipeline.extract_smear_observations |
| NEON | NEONAdapter | NEON tower API (offline fallback) | Experimental | SmearPipeline.extract_neon_observations |
| ICOS | ICOSAdapter | ICOS sparse profiles | Experimental | SmearPipeline.upscale_sparse_icos_observation |
| SHEBA | ShebaAdapter | SHEBA Arctic forcing records | Experimental | SmearPipeline.extract_sheba_profiles |
| AMERIFLUX | AmeriFluxAdapter | AmeriFlux BASE-BADM (60+ NEON + research sites) | Experimental | SmearPipeline.extract_ameriflux_observations |

For experimental adapters, data must be available locally in `data/{campaign_name}/`. See DATA.md for data organization requirements.

## Troubleshooting

1. **Stale TeX references or figure paths**: Run `make purge` to clear build caches, then re-run the full pipeline.
2. **TeX compile errors**: Check `reports/{campaign}_run/main.log` for detailed error context. Common issues include:
   - Missing PGFPlots data files: ensure `data/outputs/regime_scatterplots.csv` exists and has data.
   - Undefined control sequences: run `make purge` to force regeneration of `.tex` sections.
3. **Extraction fails or trajectory CSV is empty**:
   - Verify campaign data files exist under `data/{campaign_name}/` (see DATA.md).
   - Confirm campaign name is valid: `CAMPAIGN=CASES-99`, `CAMPAIGN=GABLS3`, or `CAMPAIGN=ALL`.
   - Run `make test` to check if regression suite detects configuration issues.
4. **Missing Julia packages**: Run `make init` to reinstall project dependencies.
5. **PGFPlots data-file path errors**: Ensure trajectory CSV columns match expectations (see DATA.md for schema).

## Status

**Latest Update**: June 15, 2026  
**Phase**: 1.5 (Integration Milestone)  
**Test Coverage**: 20 regression tests pass (campaign geometry, observation operators, matrix inversions)  
**Known Issues**: Occasional `Overfull \\hbox` typography warnings in dense table/text regions (non-blocking)  
**Data Privacy**: All raw/large dataset payloads are git-ignored; only scaffolding and metadata are tracked (see DATA.md)

Production workflows for CASES-99 and GABLS3 are fully tested and emit deterministic, reproducible outputs.
