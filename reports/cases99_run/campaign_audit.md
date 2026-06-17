# Campaign Performance Audit: CASES-99

Date: 2026-06-17T16:57:40.192 | Auditor: Spectral-Analytics Engine

## 1. Executive Dashboard

| Metric | Value | Target | Variance |
| :--- | :--- | :--- | :--- |
| Total Samples | 6538 | &gt;=1000 | observed |
| Temporal Coverage | 685.9 h | &gt;=24 h | observed |
| Mean Singular Value Entropy | 0.2110 | contextual | compressed |
| Effective Dimension | 2.0537 | &gt;1.5 | above floor |
| Condition Number | 6.85 | &lt;100 | within |
| Stage 2 Threshold Exceedance Rate | n&#x2F;a | &lt;25.0% | n&#x2F;a |
| Stable Equilibria &#x2F; Hopf Candidates | n&#x2F;a | &gt;=1 &#x2F; 0+ | n&#x2F;a |

### Status Summary

[OK] Low-rank basis remained numerically usable with condition number 6.85 and 0 exported nullspace modes.
[INFO] Campaign mean entropy registered at H_mean = 0.2110 with effective dimension D_eff = 2.0537.
[INFO] Stage 5 stability scan did not report a terminal divergence boundary.

---

## 2. Direct Observations & Facts

### Positive Findings

- The exported low-rank basis remained fully constrained with 3 constrained modes and 0 nullspace modes.
- The projection condition number stayed at 6.85, which is below the audit stress threshold of 100.
- Stage 5 stability artifacts were not available for this run.

### Negative Findings

- Stage 2 disagreement exceeded threshold in 0 of 0 windows (n/a).
- The maximum Stage 2 disagreement norm reached 0.0000, indicating localized route-selection ambiguity.
- No Stage 5 divergence boundary was recorded in the current artifact set.

### Neutral Findings

- Campaign-mean reduced coordinates were (0.583, 0.289, -0.080).
- Stage 4 lambda sweep artifact was not available for summary.
- The dominant Stage 2 routing label was n/a, which should be interpreted as the prevailing operator path rather than a regime proof by itself.

---

## 3. Risks & Monitoring Items

- Threshold exceedance rate remains elevated at n/a, so window-level disagreement can accumulate without moving campaign means substantially.
- Stage 5 boundary localization is incomplete when continuation artifacts are absent.
- Mean entropy 0.2110 indicates a compressed campaign average, which can conceal short-duration burst structure unless the exhibit-level traces are reviewed.

---

\newpage

## 4. Visual Exhibits

### Spectral Orthogonality Projection

```tex
\begin{center}
\begin{tikzpicture}
\begin{axis}[width=0.82\textwidth,height=0.48\textwidth,xlabel={$\eta_1$},ylabel={$\eta_2$},grid=major,colormap/plasma,colorbar,point meta=explicit]
\addplot[only marks,scatter,scatter src=explicit] table[col sep=comma,x=eta_1,y=eta_2,meta=eta_3] {../../data/outputs/regime_scatterplots_cases_99.csv};
\end{axis}
\end{tikzpicture}
\end{center}
```

**Figure 1:** This projection plots eta_1 against eta_2 and encodes eta_3 as the color channel, preserving the low-rank geometry and the vertical structural component in one view. The exhibit is intended to show whether the reduced manifold is dominated by tight recurrent clusters or whether structurally distinct departures remain visible outside the mean state. For CASES-99 style runs, this chart is most useful for confirming that compression in campaign-mean entropy does not erase intermittent vertical-structure events.

**Key Signal:** *Color-encoded eta_3 separates compressed orbit clusters from vertical-structure departures.*

\newpage

### Stage 2 Disagreement Window Monitor

```tex
\begin{center}
\begin{tikzpicture}
\begin{axis}[width=0.82\textwidth,height=0.38\textwidth,xlabel={window start},ylabel={disagreement norm},grid=major]
\addplot+[thick,mark=none] table[col sep=comma,x=window_start,y=disagreement_norm] {../../data/outputs/stage2_diagnostics_cases_99.csv};
\end{axis}
\end{tikzpicture}
\end{center}
```

**Figure 2:** This chart traces disagreement_norm by window_start across the campaign and exposes whether threshold exceedances are concentrated in a few episodes or distributed across much of the archive. High disagreement windows indicate that the conditional delay-routing and operator comparison logic are flagging ambiguous structure rather than cleanly separable regimes. For an audit reader, this is the fastest exhibit for assessing how much of the run should be treated as transition-dominated rather than operationally settled.

**Key Signal:** *Window-level disagreement shows whether route selection uncertainty is isolated or persistent.*

\newpage

### Stage 4 Lambda Sweep

```tex
\begin{center}
\begin{tikzpicture}
\begin{axis}[width=0.82\textwidth,height=0.38\textwidth,xlabel={$\lambda$},ylabel={residual norm},xmode=log,grid=major]
\addplot+[mark=*] table[col sep=comma,x=lambda,y=residual_norm] {../../data/outputs/stage4_lambda_sweep.csv};
\end{axis}
\end{tikzpicture}
\end{center}
```

**Figure 3:** This exhibit plots residual_norm against lambda across the Stage 4 sparse-regression sweep and is used to identify the transition from modest sparsification to aggressive structure loss. The useful reading is not the absolute residual alone but the point where nonzero term count collapses faster than residual increases. In practice, this chart documents whether the selected sparse model sits on a stable elbow or on an over-threshold pruning edge.

**Key Signal:** *Residual increase versus nnz collapse reveals the sparsification elbow.*

\newpage

### Stage 5 Stability Margin Branch

```tex
\begin{center}
\begin{tikzpicture}
\begin{axis}[width=0.82\textwidth,height=0.38\textwidth,xlabel={$\gamma$},ylabel={max real eig},grid=major]
\addplot+[mark=*] table[col sep=comma,x=gamma,y=max_real_eig] {../../data/outputs/stage5_bifurcation_branches_cases_99.csv};
\end{axis}
\end{tikzpicture}
\end{center}
```

**Figure 4:** This continuation branch plots gamma against the maximum real eigenvalue exported by the Stage 5 stability scan. It provides a compact view of how close the traced equilibrium branch is to losing local stability and where continuation stops due to divergence. When the branch stays negative but terminates abruptly, the operational interpretation is that the model validity envelope closes before a smooth Hopf-style crossing is observed.

**Key Signal:** *The maximum real eigenvalue branch shows the distance to the stability fence and the terminal divergence point.*

\newpage


---

\newpage

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
- **Trajectory Source:** ../../data/outputs/regime_trajectories_cases_99.csv
- **Scatter Source:** ../../data/outputs/regime_scatterplots_cases_99.csv
- **Stage 2 Diagnostics Source:** ../../data/outputs/stage2_diagnostics_cases_99.csv
- **Stage 4 Lambda Sweep Source:** ../../data/outputs/stage4_lambda_sweep.csv
- **Stage 5 Branch Source:** ../../data/outputs/stage5_bifurcation_branches_cases_99.csv
