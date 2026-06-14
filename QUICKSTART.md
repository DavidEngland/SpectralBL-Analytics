# QuickStart

This guide runs the full SpectralBL-Analytics pipeline from raw campaign processing to compiled PDF report.

## 1. Prerequisites

1. Julia 1.12+
2. TeX Live tools: `lualatex`, `latexmk`
3. Campaign files present under `data/`

## 2. Initialize Environment

```bash
make init
```

## 3. Run Full Operational Sweep

```bash
make purge
make process
make tex
make report
make compile-report
```

Shortcut for the canonical Cabauw/GABLS3 report path:

```bash
make cabauw-report
```

This shortcut forces `CAMPAIGN=GABLS3` so report artifacts are Cabauw-only.

Dedicated report targets:

```bash
make cases99-report
make gabls3-report
```

## 4. Primary Outputs

1. Master trajectory CSV:
   `data/drafts/trajectories/trajectory_master.csv`
2. Report tables:
   1. `data/outputs/regime_trajectories.csv`
   2. `data/outputs/regime_scatterplots.csv`
3. Manifest:
   `data/outputs/report_manifest.json`
4. Rendered TeX sections:
   1. `reports/cases99_run/generated/attractor.tex`
   2. `reports/cases99_run/generated/regime.tex`
5. Final report PDF:
   `reports/cases99_run/CASES-99.pdf` for CASES-99 runs
   `reports/gabls3_run/GABLS3.pdf` for GABLS3 runs
   `reports/all_run/main.pdf` for mixed `CAMPAIGN=ALL` runs

## 5. Run Just Report Layer (No Re-extraction)

```bash
make report
make compile-report
```

## 6. Use a Custom Trajectory CSV

```bash
make report TRAJECTORY_CSV=data/drafts/trajectories/trajectory_master.csv
```

Note: `make report` expects a CSV produced by the extraction stage. Do not pass a `.nc` file directly.

Use campaign scoping when needed:

```bash
make process CAMPAIGN=GABLS3
make report CAMPAIGN=GABLS3
```

## 7. Verify Compile Health

```bash
cd reports/cases99_run
rg -n -F -e "LaTeX Warning" -e "Package pgfplots Error" -e "Undefined control sequence" main.log
```

Expected: no blocking errors; minor `Overfull \\hbox` warnings may still appear.

## 8. Troubleshooting

1. Stale figures or references:
   Run `make purge` then re-run full sweep.
2. Missing data file errors in PGFPlots:
   Confirm `data/outputs/regime_scatterplots.csv` exists and has rows.
3. Empty/invalid metrics:
   Check `trajectory_master.csv` contains `eta_*` columns and finite values.
