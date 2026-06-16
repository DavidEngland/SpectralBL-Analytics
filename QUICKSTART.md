# QuickStart

This guide runs SpectralBL-Analytics from campaign processing through report compilation, including the High-Latitude Boundary Layer (HLBL) Arctic path.

## 1. Prerequisites

1. Julia 1.12+
2. TeX Live tools: `lualatex`, `latexmk`
3. Campaign files present under `data/{campaign_name}/` (see Data Organization below)

## 2. Initialize Environment

```bash
make init
```

## 3. Run Full Operational Sweep

Standard mid-latitude pipeline:

```bash
make purge
make process CAMPAIGN=GABLS3
make tex
make report CAMPAIGN=GABLS3
make compile-report
```

Shortcut targets:

```bash
make cabauw-report     # GABLS3/Cabauw full flow
make cases99-report    # CASES-99 full flow
make gabls3-report     # GABLS3 full flow
```

### High-Latitude Boundary Layer (HLBL) / Arctic Amplification

```bash
# 1) Synthetic verification suite + generated TeX snippets
make arctic-hlbl-synthetic

# 2) Native SHEBA-backed Arctic report flow
make arctic-report

# 3) Markdown monitoring card + acceptance guard evaluation
make compile-cards CAMPAIGN=arctic_hlbl

# 4) One-command end-to-end Arctic workflow
make arctic-finalize
```

Campaign notes:

- Extraction/report compile targets use `CAMPAIGN=CASES-99|GABLS3|ARCTIC-AMPLIFICATION|ALL`
- Card compiler accepts aliases such as `arctic_hlbl` and `ARCTIC-AMPLIFICATION`

## 4. Primary Outputs

1. Master trajectory records: `data/drafts/trajectories/trajectory_master.csv`
2. Arctic trajectories: `data/outputs/regime_trajectories_arctic_amplification.csv`
3. CASES trajectories: `data/outputs/regime_trajectories_cases_99.csv`
4. Arctic scatter table: `data/outputs/regime_scatterplots_arctic_amplification.csv`
5. CASES scatter table: `data/outputs/regime_scatterplots_cases_99.csv`
6. Manifest: `data/outputs/report_manifest.json`
7. Generated Arctic snippets:
   - `drafts/sections/generated/arctic_params.tex`
   - `drafts/sections/generated/table_arctic_synoptic.tex`
8. Arctic monitoring card: `reports/arctic_amplification_run/campaign_summary_card.md`
9. Final PDFs:
   - `reports/cases99_run/CASES-99.pdf`
   - `reports/gabls3_run/GABLS3.pdf`
   - `reports/arctic_amplification_run/ARCTIC-AMPLIFICATION.pdf`

## 5. Run Report Layer Only (No Re-extraction)

```bash
make report CAMPAIGN=GABLS3
make compile-report CAMPAIGN=GABLS3
```

For Arctic card-only refresh after outputs are present:

```bash
make compile-cards CAMPAIGN=arctic_hlbl
```

## 6. Data Organization

```text
data/
  cases99/
    raw/*.nc or raw/*.csv
    stations.json
  gabs3/
    gabls3_scm_cabauw_obs_v33.nc
  sheba/
    processed/sheba_input.csv
  outputs/
    regime_trajectories_*.csv
    regime_scatterplots_*.csv
    report_manifest.json
  drafts/
    trajectories/
      trajectory_master.csv
```

Key notes:

- Raw datasets are generally git-ignored for size/privacy.
- Metadata and generated manuscript artifacts are tracked where applicable.

## 7. Trajectory CSV Schema

Common required fields for reporting/diagnostics:

- `campaign`
- `eta_1`, `eta_2`, `eta_3`
- `sv_entropy`
- `time_value` (recommended; guard logic falls back to row-window if missing)

Additional fields are preserved and may be campaign-specific.

## 8. Verify Compile Health

```bash
cd reports/arctic_amplification_run
rg -n -F -e "LaTeX Warning" -e "Package pgfplots Error" -e "Undefined control sequence" main.log
```

Then run regression tests:

```bash
make test
```

## 9. Troubleshooting

### Campaign/Extraction Issues

1. Missing file errors:
   - Verify campaign data exists under `data/` expected paths.
   - Run `make test` to validate baseline config health.
2. Campaign token confusion:
   - Use `ARCTIC-AMPLIFICATION` for extraction/report pipeline targets.
   - Use `arctic_hlbl` (or `ARCTIC-AMPLIFICATION`) for `make compile-cards`.

### Report/TeX Issues

1. Undefined control sequence:
   - Run `make purge`, then rerun `make arctic-finalize`.
2. Empty PGFPlots figures:
   - Verify corresponding `data/outputs/regime_scatterplots_*.csv` file has rows.

### Arctic Guard Issues

1. Guard reports `FAIL`:
   - Inspect `reports/arctic_amplification_run/campaign_summary_card.md`.
   - Re-run synthetic generation (`make arctic-hlbl-synthetic`) and then `make compile-cards CAMPAIGN=arctic_hlbl`.
2. Guard reports `SKIPPED`:
   - Confirm `drafts/sections/generated/table_arctic_synoptic.tex` exists or ensure native trajectory table has sufficient columns for fallback estimation.
