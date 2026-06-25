# AI Agent Instructions: SpectralBL-Analytics

## Project Overview

Julia-based atmospheric boundary layer analysis pipeline for regime transition detection using geometric precursors. Ingests tower observations from campaigns (CASES-99, GABLS3, FLOSS, BLLAST), projects to reduced coordinates, discovers sparse dynamics via WSINDy/STLS, performs bifurcation analysis, and generates publication-ready TeX/PDF reports.

**Recent Focus** (June 2026): Phase 1 geometric precursor validation using trajectory curvature κ(t) as coordinate-independent early-warning signal.

## Essential Commands

```bash
# Initialize Julia environment (first time only)
make init

# Run tests
make test

# Core pipeline for a campaign (replace CAMPAIGN_NAME)
make stage2-pipeline CAMPAIGN=CASES-99
make stage3-assemble CAMPAIGN=CASES-99
make stage4-discover CAMPAIGN=CASES-99
make stage5-stability CAMPAIGN=CASES-99

# Generate and compile reports
make cases99-report    # CASES-99.pdf
make gabls3-report     # GABLS3.pdf
make floss-report      # FLOSS.pdf
make bllast-report     # BLLAST.pdf

# Phase 1 geometric precursor diagnostics
julia --project=. scripts/precursor_diagnostic.jl cases_99
julia --project=. scripts/precursor_diagnostic.jl gabls3

# Clean outputs
make clean             # Remove generated files
make purge             # Deep clean (including binaries)
```

## Pipeline Architecture (Stages 2-5)

**Stage 2** ([stage2_pipeline.jl](scripts/stage2_pipeline.jl))  
→ Reads trajectory CSV with required columns: `campaign`, `eta_1`, `eta_2`, `eta_3`, `time_value`  
→ Classifies regimes (stationary/chaotic via polar variance)  
→ Estimates time-delay τ, builds Takens embedding `Z`  
→ Computes WSINDy/Tikhonov operators  
→ Outputs: Binary Stage2Packet files

**Stage 3** ([stage3_matrix_assembler.jl](scripts/stage3_matrix_assembler.jl))  
→ Assembles global matrices `Z_global` and `dZ_global` from Stage 2 packets  
→ Outputs: Binary matrix files

**Stage 4** ([stage4_sparse_regression.jl](scripts/stage4_sparse_regression.jl))  
→ Builds polynomial library `Theta(Z)`  
→ Runs STLS (Sequential Thresholded Least Squares) for sparse ODE discovery  
→ Outputs: JSON with discovered system coefficients

**Stage 5** ([stage5_bifurcation_analysis.jl](scripts/stage5_bifurcation_analysis.jl))  
→ Newton solver finds equilibria  
→ Continuation methods trace bifurcation branches over parameter sweeps  
→ Outputs: Bifurcation diagrams and stability analysis

**Dependencies**: Each stage requires outputs from previous stages. Run sequentially or use combined targets.

## Julia Code Conventions

**Performance Patterns** (critical for large datasets):
- Use `@view`/`@views` for zero-allocation array slicing
- In-place broadcasting with `.=` operator
- Pre-allocate matrices before loops
- Avoid type instabilities in hot paths

**Naming Conventions**:
- Functions: `snake_case` (e.g., `classify_regime`, `estimate_delay`)
- Structs/Modules: `PascalCase` (e.g., `Stage2Packet`, `RegimeClassifier`)
- Parameters: Descriptive snake_case (e.g., `gamma_min`, `window_size`)

**Module Organization**:
- Each module in `src/` exports specific public API
- Internal helpers remain unexported
- Use explicit imports (avoid `using Module: *`)

**Data Flow**:
- Struct-based data passing with explicit field typing
- Intermediate results: binary (Serialization.jl) or JSON3
- Deterministic output formatting for reproducibility

## Campaign-Specific Parameters

Configured in [Makefile](Makefile):

| Campaign | Window Size | Step Size | Gamma Range | Notes |
|----------|-------------|-----------|-------------|-------|
| **GABLS3** | 64 | 32 | 0.07-1.00 | Short diurnal (24h) |
| **CASES-99** | 256 | 128 | 0.01-1.00 | Multi-month (686h), 200 steps |
| **BLLAST** | 256 | 128 | 0.001-1.00 | Afternoon-focus, 300 steps, ascending sweep |
| **FLOSS** | 256 | 128 | 0.07-1.00 | Long campaign (489 days) |
| **Default** | 256 | 128 | 0.07-1.00 | - |

Override via: `make stage2-pipeline CAMPAIGN=CASES-99 WINDOW_SIZE=128`

## Common Pitfalls

1. **Window sizing errors**: "Too short for Takens delay"  
   → Increase `WINDOW_SIZE` in Makefile or command line  
   → Ensure `WINDOW_SIZE > 3 * estimated_delay`

2. **Missing required columns**: Stage 2 ingestion fails  
   → CSV must have: `campaign`, `eta_1`, `eta_2`, `eta_3`, `time_value`  
   → Check column names exactly (case-sensitive)

3. **Path dependencies**: Scripts assume workspace root as `pwd()`  
   → Always run from repository root  
   → Binary paths use hardcoded defaults (overridable via CLI args)

4. **Stage dependencies**: Running stage N before N-1 completes  
   → Follow sequential order: stage2 → stage3 → stage4 → stage5  
   → Check for output files in `data/outputs/` before proceeding

5. **TeX compilation**: Report generation fails  
   → Requires LuaLaTeX and latexmk installed  
   → Check `reports/*/generated/` for template rendering issues

## Key Files

**Entry Points**:
- [scripts/precursor_diagnostic.jl](scripts/precursor_diagnostic.jl) - Phase 1 geometric precursor analysis
- [scripts/stage2_pipeline.jl](scripts/stage2_pipeline.jl) - Stage 2 orchestrator
- [scripts/build_campaign_report.jl](scripts/build_campaign_report.jl) - Report generation

**Core Modules**:
- [src/AttractorDiagnostics.jl](src/AttractorDiagnostics.jl) - Trajectory curvature and geometric metrics
- [src/Stage4_SparseRegression.jl](src/Stage4_SparseRegression.jl) - STLS sparse discovery
- [src/Stage5_BifurcationAnalytics.jl](src/Stage5_BifurcationAnalytics.jl) - Continuation and equilibria
- [src/RegimeClassifier.jl](src/RegimeClassifier.jl) - Stationary/chaotic classification

**Configuration**:
- [Makefile](Makefile) - All build targets and campaign parameters
- [Project.toml](Project.toml) - Julia dependencies

## Development Workflow

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

**Quick validation**:
```bash
make test              # Unit tests
make purge             # Clean slate
make process           # Run full pipeline
make compile-report    # Generate PDF
```

**When changing reports**:
1. Update token production in [scripts/build_campaign_report.jl](scripts/build_campaign_report.jl)
2. Update template placeholders in `templates/*.mustache`
3. Verify outputs in `reports/*/generated/`
4. Confirm compilation with no TeX errors

**Code changes**:
- Prefer additive changes to data contracts
- Preserve deterministic outputs
- Keep campaign metadata in manifests, not heuristics
- Run full validation pipeline before PR

## Quick Reference

**Documentation**:
- [README.md](README.md) - User-facing workflow overview
- [QUICKSTART_PHASE1.md](QUICKSTART_PHASE1.md) - Geometric precursor quick start
- [CHANGELOG.md](CHANGELOG.md) - Dated feature timeline
- [DATA.md](DATA.md) - Campaign dataset descriptions

**Recent Work** (June 2026):
- Phase 1 multi-campaign validation: [reports/PHASE1_ALL_CAMPAIGNS.md](reports/PHASE1_ALL_CAMPAIGNS.md)
- Geometric precursor results: [reports/PHASE1_MULTICAMPAIGN_RESULTS.md](reports/PHASE1_MULTICAMPAIGN_RESULTS.md)
