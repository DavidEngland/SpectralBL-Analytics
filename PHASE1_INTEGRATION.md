# Phase 1 Integration Guide

## Quick Reference

### Running Precursor Analysis

```bash
# Single campaign
make phase1-gabls3
make phase1-cases_99
make phase1-floss
make phase1-bllast

# All campaigns at once
make phase1-all
```

**Outputs**: 
- Plots: `reports/{campaign}_run/precursor_diagnostic_{campaign}.png`
- Summary: `reports/PHASE1_ALL_CAMPAIGNS.md`

---

## Adding to Existing Reports (3 Options)

### Option 1: Standalone Viewing (Fastest - DONE)
Just open the PNG files directly from `reports/`. No integration needed.

**Status**: ✅ All 4 campaigns already have plots generated

---

### Option 2: Include in Existing TeX Reports (Easy)

Add to your campaign-specific TeX file (e.g., in `reports/gabls3_run/main.tex`):

```latex
\section{Geometric Precursor Analysis}

\begin{figure}[htbp]
    \centering
    \includegraphics[width=\textwidth]{precursor_diagnostic_gabls3.png}
    \caption{Multi-panel geometric precursor time series. Trajectory curvature 
    $\kappa(t)$ (Panel 4) shows sharp spikes marking regime transitions, 
    orthogonal to classical Richardson number (Panel 5).}
    \label{fig:precursor}
\end{figure}
```

Then recompile:
```bash
make gabls3-report  # or cases99-report, floss-report, bllast-report
```

---

### Option 3: Mustache Template (For Automated Generation)

**Template created**: `templates/geometric_precursors.tex.mustache`

To use in automated reports:
1. Modify `scripts/build_campaign_report.jl` to include precursor data in JSON manifest
2. Add `{{> geometric_precursors}}` to `templates/main.tex.mustache`
3. Rebuild with `make {campaign}-report`

**JSON data needed**:
```json
{
  "campaign_name": "GABLS3",
  "duration_hours": "23.8",
  "duration_days": "1.0",
  "n_samples": "144",
  "timestep_minutes": "10.0",
  "eta3_min": "-0.074",
  "eta3_max": "0.210",
  "mean_speed": "6.1e-5",
  "precursor_plot_path": "precursor_diagnostic_gabls3.png",
  "campaign_slug": "gabls3",
  "peak_curvature": "2000",
  "has_curvature_spikes": true,
  "richardson_behavior": "flat at Ri ~ 0.3 with no precursor structure"
}
```

---

## Current Status: Phase 1 Complete ✅

### What We Have

**Code**:
- ✅ `src/GeometricPrecursors.jl` - Full analysis module
- ✅ `scripts/precursor_diagnostic.jl` - Automated diagnostic runner
- ✅ Makefile targets: `make phase1-all`, etc.

**Documentation**:
- ✅ `QUICKSTART_PHASE1.md` - User guide
- ✅ `reports/PHASE1_IMPLEMENTATION_SUMMARY.md` - GABLS3 first results
- ✅ `reports/PHASE1_MULTICAMPAIGN_RESULTS.md` - Cross-campaign validation
- ✅ `reports/PHASE1_ALL_CAMPAIGNS.md` - 4-campaign summary
- ✅ `SESSION_SUMMARY.md` - Complete session log

**Results**:
- ✅ GABLS3: 5 curvature spikes over 24h
- ✅ CASES-99: ~12 spikes over 686h (synoptic frequency)
- ✅ FLOSS: **Spectacular** κ ~ 10,000 spike cluster at hours 9000-11000
- ✅ BLLAST: Low-energy regime (afternoon-only data)

**Template Infrastructure**:
- ✅ `templates/geometric_precursors.tex.mustache` - Ready for automated reports
- ⚠️ Not yet wired into `build_campaign_report.jl` (optional enhancement)

---

## Recommendation: Use Option 1 or 2

**Option 1** (current state): View PNG files directly
- ✅ **Fastest** - already done
- ✅ **Sufficient** for Phase 1 validation and paper writing
- ✅ **Flexible** - easy to include in manuscripts/presentations

**Option 2** (manual TeX): Add figure to existing reports
- ✅ **Easy** - just 5 lines of LaTeX
- ✅ **Immediate** - no scripting needed
- ✅ **Integrates** with existing campaign PDFs

**Option 3** (full automation): Wire mustache template
- ⚠️ **Overkill** for current needs
- ⚠️ Requires modifying `build_campaign_report.jl`
- ✅ **Future-proof** if generating hundreds of campaign reports

---

## Bottom Line

**For Phase 1 validation**: You're done. The PNGs contain all the scientific results you need.

**For paper writing**: Copy the plots into your manuscript figures. The template is there if you want automated LaTeX generation later.

**For integration**: If you want the plots in your existing GABLS3.pdf or CASES-99.pdf reports, just add the `\includegraphics` line (Option 2) and rerun `make gabls3-report`.

---

*The mustache template and Makefile targets are ready, but not required for Phase 1 completion.*
