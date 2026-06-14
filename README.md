# SpectralBL-Analytics

SpectralBL-Analytics is a Julia-based atmospheric boundary layer (ABL) diagnostics and reporting pipeline. It ingests campaign observations, projects profiles into a reduced attractor space, computes physically interpretable metrics, and renders publication-ready TeX/PDF outputs.

The current production workflow supports CASES-99 and GABLS3 and includes automated report generation with PGFPlots externalized figures.

## What This Repository Does

1. Ingests tower/model profiles from campaign datasets.
2. Builds campaign-specific observation operators and low-rank states.
3. Computes trajectory diagnostics in reduced coordinates (`eta_1`, `eta_2`, `eta_3`).
4. Exports structured CSV/JSON artifacts for reproducible reporting.
5. Renders Mustache templates into TeX sections.
6. Compiles report PDF via LuaLaTeX and `latexmk`.

## Phase 1.5 Highlights

The reporting orchestrator now includes refined information-theoretic and conditioning diagnostics:

1. Dynamic constrained/nullspace mode partitioning from singular values.
2. Condition number tracking in projected space.
3. Shannon effective dimension (`D_eff = exp(H)`) from singular-value weights.
4. Interaction residual proxy for non-orthogonal regime coupling.

These metrics are embedded in generated report sections and compiled into the final manuscript-ready PDF.

## Repository Layout

```text
Makefile
Project.toml
Manifest.toml
README.md
QUICKSTART.md
CHANGELOG.md

data/
  gabs3/
  ncar_eol_dee0099881/
  drafts/

scripts/
  extract_attractor_diagnostics.jl
  regenerate_tex_exports.jl
  build_campaign_report.jl

src/
  AttractorDiagnostics.jl
  IngestionFormatters.jl
  ReportingTeX.jl
  io/ExportPipeline.jl

templates/
  attractor_report.tex.mustache
  regime_decomposition.tex.mustache

reports/cases99_run/
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
```

Campaign-scoped variants:

```bash
make process CAMPAIGN=GABLS3
make report CAMPAIGN=GABLS3
make process CAMPAIGN=CASES-99
make report CAMPAIGN=CASES-99
```

Artifacts produced:

1. `data/drafts/trajectories/trajectory_master.csv`
2. `data/outputs/regime_trajectories.csv`
3. `data/outputs/regime_scatterplots.csv`
4. `data/outputs/report_manifest.json`
5. `reports/cases99_run/generated/attractor.tex`
6. `reports/cases99_run/generated/regime.tex`
7. `reports/cases99_run/CASES-99.pdf` for `CAMPAIGN=CASES-99`
8. `reports/gabls3_run/GABLS3.pdf` for `CAMPAIGN=GABLS3`
9. `reports/all_run/main.pdf` for mixed (`CAMPAIGN=ALL`) runs

## Make Targets

Run `make help` for the latest command list. Core targets:

1. `make init` - instantiate and precompile Julia environment
2. `make process` - run campaign diagnostics extraction
3. `make tex` - regenerate manuscript macro exports
4. `make report` - build report sections from trajectory CSV (expects `.csv`, not `.nc`; supports `CAMPAIGN=GABLS3|CASES-99|ALL`, default `ALL`)
5. `make compile-report` - compile PDF report
6. `make cabauw-report` - run `process -> tex -> report -> compile-report` with `CAMPAIGN=GABLS3`
7. `make cases99-report` - run full pipeline with `CAMPAIGN=CASES-99` and emit `CASES-99.pdf`
8. `make gabls3-report` - run full pipeline with `CAMPAIGN=GABLS3` and emit `GABLS3.pdf`
9. `make clean` - remove logs and temporary runtime files
10. `make purge` - deep clean report/data build artifacts

## Notes on Scientific Interpretation

The generated report includes:

1. Attractor trajectory interpretation in reduced phase space.
2. Information-theoretic manifold complexity diagnostics.
3. Regime-structure and orthogonality analysis.
4. Non-orthogonal coupling residual accounting.

For operator usage details and practical command examples, see `QUICKSTART.md`.

## Troubleshooting

1. If TeX references look stale, run `make purge` before recompiling.
2. If PGFPlots figures do not update, clear `reports/cases99_run/tikz-cache/` via `make purge`.
3. If extraction fails, verify required campaign files exist under `data/`.

## Status

Production-tested workflow currently compiles cleanly with non-blocking typography warnings only (`Overfull \\hbox` in dense lines).
