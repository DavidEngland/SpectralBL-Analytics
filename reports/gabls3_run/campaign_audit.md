# Campaign Performance Audit: GABLS3

Date: 2026-06-17T17:21:56.410 | Auditor: Spectral-Analytics Engine

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
- The projection condition number stayed at 4.37, which is below the audit stress threshold of 100.
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

# Appendix: Methodology & Technical Explanations

### A. Core Performance Metrics

The primary campaign-style performance indicators are mathematically defined as:

$$CTR = \frac{\text{Clicks}}{\text{Impressions}}$$

$$CPA = \frac{\text{Spend}}{\text{Conversions}}$$

$$ROAS = \frac{\text{Total Revenue Generated}}{\text{Total Campaign Spend}}$$

The primary spectral diagnostics used in this audit are:

$$H = -\sum_{i=1}^{r} p_i \log p_i$$

$$D_{\mathrm{eff}} = e^{H}$$

$$\kappa = \sigma_{\max} / \sigma_{\min}$$

$$R_{\mathrm{exceed}} = \frac{1}{W} \sum_{w=1}^{W} \mathbf{1}\{\mathrm{disagreement\_norm}_w > \tau\}$$


### B. Statistical Evaluation & Significance

To isolate performance signal from short-window noise, a two-tailed Z-test can be expressed as:

$$Z = \frac{(\hat{p}_1 - \hat{p}_2) - 0}{\sqrt{\hat{p}(1-\hat{p})\left(\frac{1}{n_1} + \frac{1}{n_2}\right)}}$$

Findings should be rejected unless they cross the threshold of $\alpha = 0.05$.

### C. Attribution Methodology

- **Model:** Deterministic manifold audit with campaign-scoped artifact attribution
- **Lookback Window:** campaign-window
- **Pixel Logic:** Not applicable; diagnostics are derived from trajectory and stability artifacts rather than ad-pixel events.

### D. Data Quality Controls

- **Anomaly Detection:** Outliers exceeding $3\sigma$ from the moving median were scrubbed.
- **Bot Traffic Filter:** Not applicable; source is scientific trajectory data, not web traffic.
- **Trajectory Source:** ../../data/outputs/regime_trajectories_gabls3.csv
- **Scatter Source:** ../../data/outputs/regime_scatterplots_gabls3.csv
- **Stage 2 Diagnostics Source:** ../../data/outputs/stage2_diagnostics_gabls3.csv
- **Stage 4 Lambda Sweep Source:** ../../data/outputs/stage4_lambda_sweep.csv
- **Stage 5 Branch Source:** ../../data/outputs/stage5_bifurcation_branches_gabls3.csv
