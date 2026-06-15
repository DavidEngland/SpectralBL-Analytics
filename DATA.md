# Data Organization & Privacy

This document describes SpectralBL-Analytics data directory structure, git tracking policy, and requirements for campaign datasets.

## Privacy & Git Tracking Policy

### The Principle

All **raw/large dataset payloads** are **git-ignored** to protect data privacy and avoid repository bloat. Only **directory scaffolding** and **intentional metadata** are tracked.

### What Is Ignored (Not Tracked)

- All files under `data/{campaign_name}/raw/`
- All NetCDF files (`*.nc`)
- All large CSV files with tower observations
- All derived forcing/profile outputs larger than ~1MB

### What Is Tracked (In Git)

- Directory structure (via `.gitkeep` stub files)
- `data/{campaign_name}/stations.json` — tower metadata, coordinates, roughness lengths
- `data/{campaign_name}/*.md` or `*.json` — campaign documentation and lookup tables
- `data/*.md` — data source notes and ingestion guides
- Generated outputs under `data/outputs/` and `data/drafts/` (small, reproducible artifacts)

### Why This Matters

1. **Privacy**: Raw observations from research campaigns often contain proprietary or restricted data.
2. **Size**: Tower data files (especially time series) can exceed 100MB; impractical for git.
3. **Reproducibility**: Outputs (CSV, JSON manifests) are deterministic and smaller; safe to track.
4. **Local Workflow**: Users retain full local copies of data but don't share them publicly.

## Directory Structure

```
data/
  ├── README.md                       # Data sources and ingestion notes
  ├── Continuous Tower APIs.md        # API documentation (if applicable)
  │
  ├── cases99/                        # CASES-99 campaign data (production)
  │   ├── stations.json               # Tower metadata (tracked)
  │   └── raw/                        # Raw observations (ignored; required locally)
  │       └── .gitkeep
  │
  ├── gabls3/                         # GABLS3/Cabauw campaign data (production)
  │   ├── stations.json               # Cabauw tower metadata (tracked)
  │   └── raw/                        # Observation files (ignored; required locally)
  │       └── .gitkeep
  │
  ├── smear/                          # SMEAR-I stations (experimental)
  │   ├── SMEAR_stations.json         # Station inventory (tracked)
  │   ├── var*.json                   # Site-specific records (tracked if small)
  │   └── raw/                        # Profiles or forcing (ignored)
  │       └── .gitkeep
  │
  ├── neon/                           # NEON tower network (experimental)
  │   ├── stations.json               # NEON site metadata (tracked)
  │   └── raw/                        # Tower observations (ignored)
  │       └── .gitkeep
  │
  ├── icos/                           # ICOS network (experimental)
  │   ├── stations.json               # Site metadata (tracked)
  │   ├── processed/                  # Intermediate products (ignored if large)
  │   └── raw/                        # Raw observations (ignored)
  │
  ├── sheba/                          # SHEBA Arctic campaign (experimental)
  │   ├── stations.json               # SHEBA station metadata (tracked)
  │   ├── processed/                  # Processed profiles (ignored if large)
  │   │   └── sheba_input.csv         # Legacy import format (if local)
  │   └── raw/                        # Raw forcing (ignored)
  │       └── .gitkeep
  │
  ├── ameriflux/                      # AmeriFlux BASE-BADM network (experimental)
  │   ├── stations.json               # Per-site metadata (tracked)
  │   ├── base_badm_extracted/        # 60+ extracted CSV files (ignored; locally available)
  │   │   ├── US-ARM/
  │   │   ├── US-xCP/
  │   │   ├── US-NR1/
  │   │   ├── PR-xGU/
  │   │   └── ... (50+ additional sites)
  │   ├── base_badm_mapping.md        # Site registry with DOI refs (tracked)
  │   └── base_badm_mapping.csv       # Site inventory table (tracked)
  │
  ├── drafts/                         # Work-in-progress data
  │   ├── trajectories/
  │   │   └── trajectory_master.csv   # Generated during `make process` (tracked)
  │   └── figures/                    # Figure exports
  │       └── .gitkeep
  │
  └── outputs/                        # Generated reports & manifests
      ├── regime_trajectories.csv     # Regime-labeled trajectory subset (tracked)
      ├── regime_scatterplots.csv     # PGFPlots scatter data (tracked)
      └── report_manifest.json        # Campaign metadata (tracked)
```

## Adding a New Campaign

To onboard a new campaign:

1. **Create campaign directory**:
   ```bash
   mkdir -p data/{campaign_name}/raw
   touch data/{campaign_name}/.gitkeep data/{campaign_name}/raw/.gitkeep
   ```

2. **Add campaign metadata** (`data/{campaign_name}/stations.json`):
   ```json
   {
     "campaign_name": "MY_CAMPAIGN",
     "site_name": "Example Tower Site",
     "n_sites": 1,
     "sites": [
       {
         "id": 1,
         "name": "Tower A",
         "latitude": 45.5,
         "longitude": 10.5,
         "elevation": 100,
         "heights": [1, 5, 10, 25, 50],
         "z0m": 0.5,
         "d_displacement": 0.0
       }
     ]
   }
   ```

3. **Place raw data files** under `data/{campaign_name}/raw/` (these won't be tracked, but are required for extraction).

4. **Register campaign adapter** in `src/IngestionFormatters.jl` or `src/SmearPipeline.jl` depending on whether it uses legacy or standardized pathway.

5. **Test extraction**:
   ```bash
   make process CAMPAIGN=MY_CAMPAIGN
   ```

## Trajectory CSV Schema

The file `data/drafts/trajectories/trajectory_master.csv` is produced by `make process` and consumed by `make report`. It must contain the following columns:

### Required Columns

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `timestamp` | string or float | ISO 8601 datetime or numeric time index | "2020-06-01T12:00:00Z" or 1.0 |
| `campaign` | string | Campaign identifier | "CASES-99" or "GABLS3" |
| `eta_1` | float | First reduced coordinate (attractor projection) | 0.45 |
| `eta_2` | float | Second reduced coordinate | -0.12 |
| `eta_3` | float | Third reduced coordinate (sparse profiles may have NaN) | 0.33 or NaN |
| `n_valid_levels` | int | Number of valid observation heights in profile | 5 |

### Optional Columns

| Column | Type | Description | Use Case |
|--------|------|-------------|----------|
| `robust_for_eta3` | bool | Indicator: is eta3 confident given profile sparsity? | Sparse-profile audit (SHEBA 2-layer, NEON partial levels) |
| `campaign_origin` | string | Data source adapter name | "CabauwAdapter", "SmearAdapter", "NEONAdapter" |
| `stability_class` | string | Brunt-Väisälä derived stability | "unstable", "neutral", "stable" |
| `zL` | float | Monin-Obukhov stability parameter z/L | -0.5 to +10 |
| `ustar` | float | Friction velocity (m/s) | 0.3 |
| Other diagnostic columns | various | Campaign/extraction-specific metrics | —— |

**Note**: Report templates reference only the required columns. Optional columns are preserved for audit trails and future analysis but do not affect PDF output.

## Campaign Metadata (stations.json)

Each campaign must provide a `stations.json` file at `data/{campaign_name}/stations.json`. This file defines:

1. **Tower locations and heights** — used by observation operators
2. **Surface roughness** (z0m, displacement height) — used for stability corrections
3. **Site IDs and names** — used for trajectory labeling and report metadata

### Example: CASES-99

```json
{
  "campaign_name": "CASES-99",
  "n_sites": 5,
  "sites": [
    {
      "id": 1,
      "name": "WCR Flux Tower",
      "latitude": 40.155,
      "longitude": -104.737,
      "elevation": 1655,
      "heights": [1.5, 2.5, 4.5, 8.5, 14.5, 28.5],
      "z0m": 0.1,
      "d_displacement": 0.0
    },
    {
      "id": 2,
      "name": "NCAR Boundary Layer Profiler",
      "latitude": 40.157,
      "longitude": -104.735,
      "elevation": 1653,
      "heights": [10, 25, 50, 100, 200],
      "z0m": 0.1,
      "d_displacement": 0.0
    }
  ]
}
```

### Example: GABLS3 (Cabauw)

```json
{
  "campaign_name": "GABLS3",
  "site_name": "Cabauw",
  "n_sites": 1,
  "sites": [
    {
      "id": 1,
      "name": "Cabauw Tower",
      "latitude": 51.971,
      "longitude": 4.927,
      "elevation": -2,
      "heights": [10, 20, 40, 80, 140, 200],
      "z0m": 0.1,
      "d_displacement": 0.0
    }
  ]
}
```

## AmeriFlux BASE-BADM Ingestion (Experimental)

AmeriFlux is a continental-scale network of 60+ eddy covariance and flux tower sites across North America operated by diverse institutions. The AmeriFlux BASE (Burba and Anderson Standard Exchange) data product provides harmonized half-hourly and hourly measurements in the Flux Processing (FP) Standard, which is compatible with ICOS (Integrated Carbon Observation System).

### Supported Sites

Your local extraction currently includes:
- **10 representative sites** pre-configured in [data/ameriflux/stations.json](data/ameriflux/stations.json)
- **60+ extracted CSV files** in [data/ameriflux/base_badm_extracted/](data/ameriflux/base_badm_extracted/) covering NEON, research, and legacy towers
- Full site registry in [data/ameriflux/base_badm_mapping.md](data/ameriflux/base_badm_mapping.md) with DOI references

### AmeriFlux Measurement Schema (FP Standard)

Half-hourly BASE files contain columns like:
- `TA_1_1_1`, `TA_2_1_1`, ... — Air temperature at heights 1, 2, 3, ... (°C)
- `RH_1_1_1`, `RH_2_1_1`, ... — Relative humidity (%)
- `WS_1_1_1`, `WS_2_1_1`, ... — Wind speed (m/s)
- `WD_1_1_1`, `WD_2_1_1`, ... — Wind direction (°)
- `USTAR` — Friction velocity (m/s)
- `ZL` — Monin-Obukhov stability parameter z/L (dimensionless)
- `PA_1_1_1` — Atmospheric pressure (kPa)
- `TIMESTAMP_START`, `TIMESTAMP_END` — ISO 8601 timestamps (YYYYMMDDHHMM format)

**Missing data indicator**: `-9999` (converted to NaN)

### Running an AmeriFlux Extraction

1. **List available sites**:
   ```bash
   ls data/ameriflux/base_badm_extracted/
   ```

2. **Process one site** (e.g., US-ARM):
   ```bash
   make process CAMPAIGN=AMERIFLUX
   ```
   
   This will iterate through all sites in [data/ameriflux/base_badm_extracted/](data/ameriflux/base_badm_extracted/) and generate a unified `trajectory_master.csv`.

3. **Check extraction results**:
   ```bash
   wc -l data/drafts/trajectories/trajectory_master.csv
   grep "AMERIFLUX" data/drafts/trajectories/trajectory_master.csv | head -5
   ```

4. **Build and compile report**:
   ```bash
   make report CAMPAIGN=AMERIFLUX
   make compile-report
   ```
   
   Output: `reports/ameriflux_run/AMERIFLUX.pdf` (if multi-site analysis enabled)

### Height-by-Site Variability

Unlike CASES-99 and GABLS3, AmeriFlux sites have heterogeneous tower configurations:
- **Grasslands** (e.g., US-ARM, US-xCP): 3–5 levels (2–50 m)
- **Forests** (e.g., US-xHA): 3–4 levels (10–40 m)
- **Arctic tundra** (e.g., US-xTL): 2–4 levels (1–12 m)

The AmeriFluxAdapter dynamically detects available heights and skips profiles with < 3 valid levels (sets `robust_for_eta3 = false`).

### Roughness Length & Displacement Height

The adapter defaults to `z0m = 0.1 m` (grassland) for all sites. For improved accuracy, site-specific values can be added to [data/ameriflux/stations.json](data/ameriflux/stations.json):

```json
{
  "id": "US-xHA",
  "name": "Harvard Forest",
  "z0m": 1.5,
  "d_displacement": 15.0
}
```

### Quality Control Notes

- AmeriFlux sites have varying QC standards. Some include QC flags in the BASE product; consult site-specific BADM metadata for details.
- Sparse profiles (e.g., 2-level observations) are flagged with `robust_for_eta3 = false` and excluded from eta3 projections.
- Stability parameters (ZL, USTAR) are taken directly from the CSV if available; otherwise, defaults are used.

## Local Data Ingestion Workflow

For campaigns with datasets already present locally (or downloaded separately):

1. **Ensure local files are in place**:
   ```bash
   ls -la data/{campaign_name}/raw/
   ```

2. **Verify campaign metadata**:
   ```bash
   jq . data/{campaign_name}/stations.json | head -20
   ```

3. **Run extraction** (no API calls, pure local ingestion):
   ```bash
   make process CAMPAIGN={campaign_name}
   ```

4. **Check trajectory output**:
   ```bash
   wc -l data/drafts/trajectories/trajectory_master.csv
   head -5 data/drafts/trajectories/trajectory_master.csv | cut -d',' -f1-6
   ```

5. **Build report**:
   ```bash
   make report CAMPAIGN={campaign_name}
   make compile-report
   ```

## Public vs. Private Data

### Public/Open Data
- GABLS3 (Cabauw): Available from KNMI, can be tracked if licensing permits.
- NEON: Available via NEON data portal (open, but large).
- ICOS: Available via ICOS Data Portal (open science mandate).

### Restricted/Private Data
- CASES-99: Original tower data restricted to collaboration members.
- SHEBA: Arctic research data with usage restrictions.
- SMEAR: Contact Finnish Meteorological Institute for access.

**Policy**: When in doubt, treat raw data as private and git-ignore it. Document public URLs and acquisition instructions in `data/README.md` instead.

## Troubleshooting Data Ingestion

### "File not found" during extraction
- Check file exists: `ls -la data/{campaign_name}/raw/`
- Verify campaign name spelling matches `stations.json` `campaign_name` field.
- Confirm adapter is implemented and exported in `SmearPipeline.jl`.

### "Trajectory CSV is empty or has one row"
- Verify raw data files contain valid observations.
- Check adapter logs for warnings about skipped profiles.
- Ensure `n_valid_levels` is calculated and non-zero.

### ".gitkeep files appearing in `git status`"
- This is expected and correct; `.gitkeep` preserves directory structure in git.
- They are placeholders with no functional impact and can be safely ignored.

### Data files are large; extraction is slow
- Large NetCDF or CSV files will take time to parse.
- Consider extracting specific time periods or height ranges if available.
- For development, create small test subsets in `data/{campaign_name}/test/`.

## Next Steps

1. **To add a production campaign**: Implement an adapter in `src/ultra/adapters/` and export it via `SmearPipeline.jl`.
2. **To enable a local experimental dataset**: Place files in `data/{campaign_name}/raw/`, add `stations.json`, and test with `make process CAMPAIGN={campaign_name}`.
3. **To publish a campaign workflow**: Document it in `README.md` and update the supported campaigns table.
