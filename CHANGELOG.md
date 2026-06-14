# Changelog

All notable changes to this repository are documented in this file.

## [2026-06-14] - Phase 1.5 Integration Milestone

### Added
1. Information-theoretic manifold complexity diagnostics in reporting flow.
2. Refined mode accounting metrics:
   1. constrained modes
   2. nullspace modes
   3. projected-space condition number
   4. Shannon effective dimension (`D_eff`)
3. Non-orthogonal coupling proxy metric (`interaction_residual`) rendered in regime section.
4. Production Make targets for report compilation chain:
   1. `report`
   2. `compile-report`
   3. `purge`
5. PGFPlots-based real-data visualizations from generated CSV sources.

### Changed
1. `scripts/build_campaign_report.jl` now computes and injects Phase 1.5 metrics while preserving existing ExportPipeline behavior.
2. `templates/attractor_report.tex.mustache` now includes manifold complexity evaluation subsection.
3. `templates/regime_decomposition.tex.mustache` now includes non-orthogonal scale coupling subsection and assumptions note.
4. TeX preamble hardened for sparse-data plotting resilience.

### Fixed
1. PGFPlots data-file path/rendering issues in generated report sections.
2. Figure reference resolution and missing-control-sequence failures in report compile path.
3. Truncated/malformed README replaced with complete, operational documentation.

## [2026-06-13] - Phase 1 Pipeline Foundation

### Added
1. End-to-end extraction -> manifest -> template render -> TeX compilation pipeline.
2. Campaign ingestion support for CASES-99 and GABLS3.
3. Report templates and compile harness in `reports/cases99_run`.

### Notes
1. Current known non-blocking issue class: occasional `Overfull \\hbox` typography warnings in dense lines.
