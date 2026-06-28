In the SpectralBL framework, **$p$-FEM (polynomial Finite-Element Method)** regularizes the state estimation process by transforming discrete, sparse, and irregularly spaced observations into a continuous, physically coherent Hilbert space.

The regularization occurs through several distinct mathematical and physical mechanisms:

### **1. Eliminating Discretization Bias via the Mass Matrix**
Traditional Principal Component Analysis (PCA) uses a Euclidean inner product that is sensitive to sensor placement; for instance, sensors clustered near the ground would artificially over-weight that region in the resulting modes. $p$-FEM replaces this with a **metric-consistent inner product** induced by the mass matrix ($\mathbf{M}$):
*   **Physical Weighting:** $\mathbf{M}$ is defined by the overlap of localized shape functions across the vertical domain.
*   **Metric Space:** The framework scales snapshots by the symmetric square root of the mass matrix ($\mathbf{M}^{1/2}$), ensuring that modal energy is measured relative to the **continuous physical mass of the column** rather than the Euclidean norm of the sensor vector.
*   **Coordinate Invariance:** This process yields "mesh-invariant" coordinates ($\eta_k$) that are properties of the atmospheric state itself, remaining consistent whether a campaign uses seven tower levels (CASES-99) or hundreds of model levels (GABLS3).

### **2. Spatial Filtering with $\boldsymbol{\psi}$ Masks**
The leading empirical modes recovered by inverting the mass weighting are known as **$\boldsymbol{\psi}$ masks**. These act as spatial transformation filters that:
*   **Contract Information:** They project high-dimensional profile data into a compact, low-rank coordinate space ($r=3$).
*   **Physical Alignment:** Because they are strictly orthogonal with respect to the continuous column mass, they resolve emergent physical structures—such as bulk inversion growth ($\psi_1$) and shear evolution ($\psi_2$)—matching the governing fluid constraints.

### **3. Regularized Observer Design**
To isolate the coordinates ($\boldsymbol{\eta}$) from imperfect or incomplete field data, $p$-FEM supports a **physics-constrained linear observer**. This process solves a generalized regularized observation problem at every timestep:
$$\min_{\boldsymbol{\eta}} \|\mathbf{A} \mathbf{U}_r \boldsymbol{\eta}(t) - \mathbf{b}(t)\|_2^2 + \lambda \|\boldsymbol{\eta}(t)\|_2^2$$
*   **$\mathbf{A}$ (Sparse Observation Operator):** Maps continuous profiles specifically to the heights where sensors are currently active, allowing the system to handle sensor dropouts or altitude changes.
*   **Tikhonov Regularization ($\lambda$):** Stabilizes the projection against high-frequency instrumental noise and tower structural vibrations.

### **4. Analytic Reconstruction and Smoothness**
Because $p$-FEM fits profiles to polynomial bases (such as Chebyshev), it provides **mathematical smoothness** unattainable via raw finite-difference estimates. This allows the pipeline to analytically reconstruct the entire continuous vertical profile at any height—even those between physical sensors—while supporting stable, high-fidelity diagnostics of the **vertical structural curvature ($\eta_3$)**.