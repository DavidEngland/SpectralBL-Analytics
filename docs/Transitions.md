# Transition Report Module

This document tracks the in-repo transition-report implementation.

## Current Status

Implemented in this pass:

- Added `scripts/generate_transition_assets.jl`.
- Added `templates/transition_exhibit.tex.mustache`.
- Wired `stage5-transitions` into `Makefile`.
- Updated report orchestration in `scripts/build_campaign_report.jl`.
- Included transition section in `templates/main.tex.mustache`.

## What the Generator Produces

For each campaign slug, the generator writes:

- `data/outputs/transition_panel_a_<slug>.csv`
- `data/outputs/transition_panel_b_<slug>.csv`
- `data/outputs/transition_panel_c_<slug>.csv`
- `data/outputs/transition_assets_<slug>.json`

Panel semantics (v1):

- Panel A: Stage 5 stability envelope (`gamma`, `max_real_eig`).
- Panel B: Continuation branch manifold projection (`z1`, `z2`, `z3`).
- Panel C: Local transition window in campaign trajectory (`eta_3` over `time_value`).

## Build Integration

New target:

- `make stage5-transitions CAMPAIGN=<campaign>`

Report now depends on this target:

- `make report CAMPAIGN=<campaign>`

The transition exhibit template is rendered as:

- `reports/<campaign_run>/generated/transition_exhibit.tex`

and included by `main.tex.mustache`.

## Execution Example

1. `make process CAMPAIGN=CASES-99`
2. `make stage5-sweep CAMPAIGN=CASES-99` (optional but recommended)
3. `make stage5-summary CAMPAIGN=CASES-99` (optional but recommended)
4. `make report CAMPAIGN=CASES-99`
5. `make compile-report CAMPAIGN=CASES-99`

## Notes

- The transition generator is resilient to missing Stage 5 files.
- If branch/summary artifacts are missing, report rendering degrades gracefully and emits a placeholder note in the transition section.
- v1 uses existing dependencies only (`CSV`, `DataFrames`, `JSON3`, `Mustache`) and does not require new plotting packages.
