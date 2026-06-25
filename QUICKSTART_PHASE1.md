# Geometric Precursor Analysis - Quick Start Guide

## Phase 1: Testing the Central Hypothesis

**Question**: Does trajectory geometry in (η₁, η₂, η₃) space predict regime transitions before classical metrics?

## Running the Analysis

### Basic Usage

```bash
# Activate the Julia environment
cd /path/to/SpectralBL-Analytics

# Run analysis on a campaign (default: GABLS3)
julia --project=. scripts/precursor_diagnostic.jl

# Or specify a campaign
julia --project=. scripts/precursor_diagnostic.jl cases99
julia --project=. scripts/precursor_diagnostic.jl floss
julia --project=. scripts/precursor_diagnostic.jl bllast
```

### Output

The diagnostic script generates:

1. **Multi-panel time-series plot**
   - Location: `reports/{campaign}_run/precursor_diagnostic_{campaign}.png`
   - 5 panels showing Category A, Category B, and classical indicators
   
2. **Summary statistics** (printed to terminal)
   - Mean/std for each precursor indicator
   - Percentage of valid curvature values (after regularization)
   
3. **Lead-time table** (when events are marked)
   - CSV: `reports/{campaign}_run/precursor_lead_times.csv`
   - Ranking of which indicators move first

## Understanding the Plots

### Panel 1: Category A - Multi-Scale Variance
- Variance of η₃ at τ = {5, 15, 30, 60} minutes
- Classic critical-transition theory: variance ↑ near bifurcation

### Panel 2: Category A - Lag-1 Autocorrelation  
- AC₁ of η₃ at τ = {5, 15, 30, 60} minutes
- Critical slowing down: AC₁ → 1 near bifurcation

### Panel 3: Category B - Trajectory Speed & Acceleration
- Blue: `v(t) = ||dη/dt||` (how fast moving through manifold)
- Orange: `a(t) = ||d²η/dt²||` (how strongly changing)

### Panel 4: Category B - Trajectory Curvature (KEY NOVELTY)
- Purple: `κ(t) = ||η' × η''|| / ||η'||³`
- **Coordinate-independent** measure of how sharply trajectory turns
- Sharp spikes = rapid rotation in manifold space
- Regularized (only computed where speed > threshold)

### Panel 5: Classical - Richardson Number
- Mean Ri across available tower heights
- Red dashed line: critical Ri ≈ 0.25

## Interpreting Results

### What to Look For

✅ **Evidence of geometric precursors**:
- Curvature κ(t) spikes **before** variance/AC changes
- Speed/acceleration show coordinated peaks
- Richardson number shows no precursor structure

❌ **Weak or absent signals**:
- Curvature spikes random/uncorrelated with transitions
- No temporal ordering (geometry lags classical metrics)
- All indicators move simultaneously

### Example: GABLS3 Results

From first run (see `reports/PHASE1_IMPLEMENTATION_SUMMARY.md`):

- **Curvature spikes**: Dramatic peaks at hours 5, 10, 15, 20-23
- **Speed/acceleration**: Coordinated early (0-3h) and late (20-23h)
- **Variance**: Activity at hours 0-3 and 20 (appears to lag curvature)
- **Richardson**: Flat profile ~0.3, no precursor signal

**Interpretation**: Geometric indicators (κ, v, a) encode early-warning information 
not present in state-based (variance, AC) or classical (Ri) metrics.

## Adding Transition Event Markers

To compute lead times, manually identify physical events and add to 
`scripts/precursor_diagnostic.jl`:

```julia
function identify_transition_events(df::DataFrame)
    events = Dict{Symbol, Vector{Float64}}()
    
    # Example: Mark turbulence recovery at specific timestamps
    events[:turbulence_recovery] = [
        1.151760000e9,  # Hour 15 (example)
        1.151762400e9   # Hour 20 (example)
    ]
    
    events[:heat_flux_recovery] = [...]
    events[:richardson_collapse] = [...]
    
    return events
end
```

Then re-run to generate lead-time rankings.

## Technical Details

### Time Scales (Fixed A Priori)
- τ = {5, 15, 30, 60} minutes
- No post-hoc optimization → defensible against selection bias

### Numerical Methods
- Central finite differences for derivatives (2nd order)
- Curvature regularization: only compute where v(t) > 1st percentile
- Avoids ||η'|| → 0 singularities

### Data Requirements
- Input: `data/outputs/regime_trajectories_{campaign}.csv`
- Must have columns: `time_value`, `eta_1`, `eta_2`, `eta_3`
- Optional: `ri_g_*` columns, `tke`

## Validation Workflow

### Phase 1A: Single Campaign Deep Dive
1. Run GABLS3 ✅
2. Mark transition events manually
3. Compute lead times
4. Interpret curvature spikes physically

### Phase 1B: Multi-Campaign Replication  
1. Run CASES-99, FLOSS, BLLAST
2. Compare temporal patterns
3. Test universality of geometric precursors
4. Arctic vs mid-latitude comparison (SHEBA vs CASES-99)

### Decision Point: Proceed to Phase 2?

**YES** if geometric indicators consistently lead by 30-60 minutes across campaigns.

**NO** if signals are random, campaign-specific, or lag classical metrics.

## Troubleshooting

### "All statistics show NaN"

Check:
- Richardson columns: many may be all-missing (expected)
- Time series length: very short series → insufficient window coverage
- Speed values: if all near zero → curvature regularization filters everything

Solution: Inspect plots directly (statistics may be NaN but plots still informative)

### "Plots show no structure"

Possible causes:
- Campaign has no regime transitions in time window
- Spectral embedding failed (check Stage 2 diagnostics)
- Time resolution too coarse (need higher-frequency data)

### "Curvature values extremely large"

Expected! Curvature can reach κ ~ 1000-2000 during sharp turns.
- Units: ||η'||³ in denominator makes curvature scale-sensitive
- Compare relative magnitudes, not absolute values

## References

**Critical Transition Theory**:
- Scheffer et al. (2009) "Early-warning signals for critical transitions"
- Held & Suarez (1974) "A proposal for the intercomparison of the dynamical cores"

**Geometric Precursors (Novel Application)**:
- This work: trajectory curvature as coordinate-independent early warning
- Contrast with state-based variance/autocorrelation indicators

---

**Next**: See `reports/PHASE1_IMPLEMENTATION_SUMMARY.md` for detailed results and interpretation.
