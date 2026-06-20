# Campaign Performance Audit: GABLS3

Date: 2026-06-18T17:42:29.664 | Auditor: Spectral-Analytics Engine

## 1. Executive Dashboard

| Metric | Value | Target | Variance |
| :--- | :--- | :--- | :--- |
| Total Samples | 144 | >=1000 | observed |
| Temporal Coverage | 23.8 h | >=24 h | observed |
| Mean Singular Value Entropy | 0.7549 | contextual | broad |
| Effective Dimension | 2.5398 | >1.5 | above floor |
| Condition Number | 4.37 | <100 | within |
| Stage 2 Threshold Exceedance Rate | n/a | <25.0% | n/a |
| Stable Equilibria / Hopf Candidates | n/a | >=1 / 0+ | n/a |

### Status Summary

[OK] Low-rank basis remained numerically usable with condition number 4.37 and 0 exported nullspace modes.
[INFO] Campaign mean entropy registered at H_mean = 0.7549 with effective dimension D_eff = 2.5398.
[INFO] Stage 5 stability scan did not report a terminal divergence boundary.

---

## 2. Direct Observations & Facts

### Positive Findings

- The exported low-rank basis remained fully constrained with 3 constrained modes and 0 nullspace modes.
- The projection condition number was measured at 4.37 for conditioning diagnostics.
- Stage 5 stability artifacts were not available for this run.

### Negative Findings

- Stage 2 disagreement exceeded threshold in 0 of 0 windows (n/a).
- The maximum Stage 2 disagreement norm reached 0.0000, indicating localized route-selection ambiguity.
- No Stage 5 divergence boundary was recorded in the current artifact set.

### Neutral Findings

- Campaign-mean reduced coordinates were (0.151, 0.076, 0.044).
- Stage 4 lambda sweep artifact was not available for summary.
- The dominant Stage 2 routing label was n/a, which should be interpreted as the prevailing operator path rather than a regime proof by itself.

---

## 3. Risks & Monitoring Items

- Threshold exceedance rate remains elevated at n/a, so window-level disagreement can accumulate without moving campaign means substantially.
- Stage 5 boundary localization is incomplete when continuation artifacts are absent.
- Mean entropy 0.7549 indicates a compressed campaign average, which can conceal short-duration burst structure unless the exhibit-level traces are reviewed.

---

## 4. Visual Exhibits

### Spectral Orthogonality Projection

![Spectral Orthogonality Projection](tikz-cache/audit-scatter.pdf)

**Figure 1:** This projection plots eta_1 against eta_2 and encodes eta_3 as the color channel, preserving the low-rank geometry and the vertical structural component in one view. The exhibit is intended to show whether the reduced manifold is dominated by tight recurrent clusters or whether structurally distinct departures remain visible outside the mean state. For CASES-99 style runs, this chart is most useful for confirming that compression in campaign-mean entropy does not erase intermittent vertical-structure events.

**Key Signal:** *Color-encoded eta_3 separates compressed orbit clusters from vertical-structure departures.*

Source data: ../../data/outputs/regime_scatterplots_gabls3.csv

### Temporal Trajectory Components

![Temporal Trajectory Components](tikz-cache/audit-trajectory.pdf)

**Figure 2:** The temporal panel tracks eta_1, eta_2, and eta_3 against the run timeline and highlights where smooth regime drift gives way to abrupt structural shifts. In compressed campaigns, this view is often where short-duration events appear most clearly.

**Key Signal:** *Component-wise eta(t) traces expose transition pacing and episodic bursts across the campaign.*

Source data: ../../data/outputs/regime_trajectories_gabls3.csv


---

# Appendix: Methodology & Technical Notes

### A. Spectral Diagnostic Definitions

The reduced-order coordinates are obtained by projecting observed vertical profiles onto the empirical low-rank basis:

$$\eta_i(t) = \mathbf{\Phi}_i^T \mathbf{z}(t)$$

where $\mathbf{\Phi}_i$ is the $i$-th empirical basis vector and $\mathbf{z}(t)$ is the state vector assembled from wind speed and temperature profiles at observation time $t$.

The local Jacobian evaluated at a candidate equilibrium $\mathbf{z}^*$ is:

$$J_{ij} = \frac{\partial f_i}{\partial x_j}\Bigg|_{\mathbf{z}^*}$$

Stability is assessed from the eigenspectrum $\lambda = \alpha \pm i\beta$. A Hopf instability is identified when a complex conjugate pair crosses the imaginary axis ($\alpha = 0$, $\beta \neq 0$) as the continuation parameter $\gamma$ varies.

The primary scalar diagnostics derived from the singular value decomposition of the trajectory matrix are:

$$H = -\sum_{i=1}^{r} p_i \log p_i$$

$$D_{\mathrm{eff}} = e^{H}$$

$$\kappa = \sigma_{\max} / \sigma_{\min}$$

$$R_{\mathrm{exceed}} = \frac{1}{W} \sum_{w=1}^{W} \mathbf{1}\{\mathrm{disagreement\_norm}_w > \tau\}$$


### B. Threshold and Exceedance Criteria

Stage 2 routing disagreement is flagged when the operator-selection norm $\|\delta\|$ exceeds a fixed tolerance $\tau$. The exceedance rate $R_{\mathrm{exceed}}$ measures the fraction of analysis windows where this threshold is crossed. An elevated $R_{\mathrm{exceed}}$ indicates that the campaign trajectory does not resolve cleanly into a single dominant routing class, consistent with multi-scale or intermittently stable conditions.

Outliers in the raw profile time series are identified as observations deviating more than $\pm3\sigma$ from the local running median, computed within a sub-hourly smoothing window prior to ingestion.

### C. Projection Method

- **Projection model:** SVD / Low-Rank Attractor Decomposition
- **Baseline version:** v0.1 (spectralbl-attractor)

### D. Artifact Provenance

- **Trajectory source:** ../../data/outputs/regime_trajectories_gabls3.csv
- **Scatter source:** ../../data/outputs/regime_scatterplots_gabls3.csv
- **Stage 2 diagnostics:** ../../data/outputs/stage2_diagnostics_gabls3.csv
- **Stage 4 lambda sweep:** ../../data/outputs/stage4_lambda_sweep.csv
- **Stage 5 branch CSV:** ../../data/outputs/stage5_bifurcation_branches_gabls3.csv
