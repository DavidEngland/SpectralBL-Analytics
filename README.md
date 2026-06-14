# SpectralBL-Analytics

A unified, geometry-aware diagnostic and reporting framework for `SpectralBL`. This repository ingests high-order $p$-FEM boundary layer simulation outputs and multi-height sparse tower observation profiles, projecting highly nonlinear regime transitions onto a low-dimensional attractor space.

The analytics engine is designed to be case-agnostic, allowing seamless replication, diagnostic extraction, and automated manuscript asset generation across multiple observational campaigns (e.g., CASES-99, GABLS3).

---

## 🔬 Core Methodology

Instead of evaluating independent, static profiles through traditional linear regressions—which blur the structural dynamics of the Stable Boundary Layer (SBL)—this framework treats the boundary layer as a low-dimensional dynamical system that continuously expands, contracts, and "breathes" through the diurnal cycle.

### 1. Metric-Consistent Low-Rank Projection
To isolate this structure without introducing computational overhead, we implement an economy Singular Value Decomposition (SVD) directly within the $p$-FEM mass metric ($M^{1/2}Y$). This preserves the physical inner product induced by the finite-element mass matrix, ensuring that modal energy rankings remain physically meaningful and are not distorted by numerical weighting or grid spacing choices.

### 2. Time-Varying Ridge Optimization
Sparse, irregular tower profiles ($b$) are mapped to the low-rank subspace via an adaptive observation operator ($A$) that embeds surface roughness ($z_{0,m}, z_{0,h}$) and displacement height ($d$) boundary constraints. The reduced-state coordinates $\eta$ are obtained at microsecond speeds per time step by solving:

$$\min_{\eta} \|A U_r \eta - b\|_2^2 + \lambda \|\eta\|_2^2$$

---

## 📈 Geometric Diagnostics

Once the atmospheric state is projected into the reduced coordinate space $(\eta_1, \eta_2, \eta_3)$, the engine extracts three primary scalar metrics to map regime transitions:

*   **Singular Value Entropy ($H$):** The Shannon entropy computed from the normalized singular value spectrum, measuring the effective dimensionality and structural complexity of the evolving boundary layer.
*   **Phase Curvature ($\kappa$):** Quantifies abrupt directional changes in attractor motion, highlighting rapid stability transitions, frontal passages, and low-level jet (LLJ) decay.
*   **Attractor Spin ($\Omega$):** A signed rotational phase metric ($\Omega = \eta_1 \dot{\eta}_2 - \eta_2 \dot{\eta}_1$) that identifies the direction of attractor rotation. The sign of $\Omega$ effectively separates shear-driven turbulence breakouts from radiatively driven boundary layer collapses.

---

## 📋 Campaign Execution Matrix

The framework scales effortlessly from minimum 5-height tower configurations up to highly dense vertical model grids, as the thin SVD operation keeps downstream optimization costs fixed.

| Campaign Target | Data Signature | Physical Focus | Status |
| :--- | :--- | :--- | :--- |
| **CASES_99** | 6-Level Tower | Stable Boundary Layer (SBL) / Inversions | 🟢 Production Ready |
| **GABLS3** | Dense Model/Tower | Diurnal Cycle & Low-Level Jet (LLJ) | ⚙️ Active Integration |
| **FLOSS_II** | Multi-height Profile | Shallow Cold Pools | ⏳ Ingestion Setup |
| **SHEBA** | Arctic Ice Profile | Strongly Stratified Polar Boundary Layer | ⏳ Ingestion Setup |

---

## 🚀 Quick Start & Workflow

### 1. Environment Setup
Initialize the analytics environment and pull down presentation-layer dependencies:
```bash
julia --project="." -e 'using Pkg; Pkg.instantiate()'