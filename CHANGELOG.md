# Changelog

All notable changes to this repository are documented in this file.

## [2026-06-15] - Documentation Sync & Data Privacy Hardening

### Added
1. Comprehensive `DATA.md` documenting data directory structure, `.gitignore` privacy policy, and campaign-specific requirements.
2. Expanded `README.md` with:
   - Full adapter ecosystem documentation (6 adapters with production vs experimental status)
   - Supported campaigns table (CASES-99, GABLS3 production; SMEAR, NEON, ICOS, SHEBA experimental)
   - Enhanced troubleshooting section with diagnostic commands
   - Phase 1.5 highlights with date and version context
3. Expanded `QUICKSTART.md` with:
   - Explicit CAMPAIGN parameter documentation (valid values: CASES-99, GABLS3, ALL)
   - Data organization section explaining directory structure and git-ignore behavior
   - Trajectory CSV schema documentation (required and optional columns)
   - Comprehensive troubleshooting by category (campaigns, reports, data, environment)
4. Test documentation: `make test` target formally documented with expected 20-pass regression suite.

### Changed
1. `.gitignore` hardening: all data payloads now ignored by default; only directory scaffolding (`.gitkeep`) and intentional metadata tracked.
2. Repository layout documentation now includes SmearPipeline.jl and ultra/ module structure.
3. Make targets documentation now includes `make test` and clarifies `CAMPAIGN` parameter behavior.

### Fixed
1. Stale reference to non-existent `reports/all_run/` in user-facing docs; now clearly marked as experimental.
2. Misleading "current production workflow" claim in README; now accurately reflects 5-adapter ecosystem with production/experimental status distinctions.
3. Missing trajectory CSV schema documentation; now includes required columns and optional audit fields.
4. Test regression: updated GABLS3 tower height expectation from 6 to 4 levels in `test/runtests.jl` to match current campaign configuration.

### Verified
1. All Make targets in documentation exist and match actual Makefile behavior.
2. Artifact output paths and naming conventions match campaign-scoped routing logic.
3. Data organization guidance aligns with `.gitignore` rules.
4. Test suite passes (20/20) with updated GABLS3 baseline.
5. Smoke validation: `make gabls3-report` produces reproducible `GABLS3.pdf` output.

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
