This new module, `IngestionFormatters`, handles data normalization for your framework. It standardizes disparate field campaign observations (NetCDF, CSV, ASCII) from historical atmospheric boundaries (like CASES-99 or GABLS3) into a unified computational grid (`pfem_grid`).

It then computes an Empirical Orthogonal Function (EOF) basis via Singular Value Decomposition (**SVD**) to extract a low-rank attractor manifold ($\mathbb{U}_r$) for downstream sparse regression.

---

## 🔍 Analytical Foundations & Low-Rank Reduction

The engineering bottleneck when handling multiple heterogeneous field projects is the variability in vertical measurements. Meteorological masts have different physical sensor levels, data frequencies, and formatting structures:

To transform these variables into a unified state space, the module executes a two-phase mathematical reduction:

### 1. Piecewise Linear Interpolation

For every timestamp $t$, raw heights $z_{obs}$ and velocities $u_{obs}$ are extracted, sorted, and mapped to the target grid coordinates using localized weighting:


$$u(z_{target}) = (1 - \theta)v_l + \theta v_r \quad \text{where} \quad \theta = \frac{z_{target} - z_l}{z_r - z_l}$$


To protect against unphysical numerical behavior, extrapolation values near boundaries are capped at the nearest valid sensor reading.

### 2. Empirical Orthogonal Function Separation

Once the uniform data matrix $Y \in \mathbb{R}^{M \times N}$ is assembled across all observations, its spatial rows are centered around their mean values. The low-rank state space representation is then isolated by computing the economy SVD:


$$Y_{centered} = U \Sigma V^T \longrightarrow \mathbb{U}_r = U[:, 1:r]$$


The resulting subspace matrix $\mathbb{U}_r$ forms the low-rank coordinate projection framework used to build your phase space trajectories ($Z$).
