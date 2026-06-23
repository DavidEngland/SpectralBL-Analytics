# `test/` Suite: Rigorous Physical & Algebraic Regressions

This directory contains the verification pipeline for validating the mathematical consistency and geometric integrity of your Boundary Layer identification engine. The tests systematically ensure that conservation laws, structural configurations, and rank-reduction steps remain accurate across refactors.

---

## 📐 Test Suite Topography & Coverage Map

The verification pipeline is segmented into five core operational checks:

```
[runtests.jl Entry Point]
       │
       ├─► 1. Campaign Configurations ──► Validates site roughness ($z_{0m}, z_{0h}$) & elevations
       ├─► 2. Observation Operators ────► Enforces unity partitions & boundary log-law constraints
       ├─► 3. Low-Rank Inversions ──────► Verifies dimensional consistency of Ridge/Tikhonov mappings
       ├─► 4. Information Theory ───────► Assesses Singular Value Entropy ($\mathcal{H}$) limits
       └─► 5. Chebyshev Aliasing ───────► Guards against cross-talk & pointer aliasing mutations

```

---

## 🧪 Functional Regression Breakdowns

### 1. Site Metadata Validation (`Campaign Configuration Layouts`)

* **Objective:** Verifies that physical boundary details (aerodynamic roughness lengths $z_{0m}$, spatial displacements $d$, and exact measurement levels) map perfectly to standard historical experiments (e.g., CASES-99, GABLS3).
* **Defensive Edge Case:** Throws an explicit `ErrorException` when an unconfigured target name is passed to ensure bad configuration keys fail loudly before entering the pipelines.

### 2. Conservative Mapping Constraints (`Observation Operator Physics Enforcements`)

* **Objective:** Validates the interpolation/projection operator $A \in \mathbb{R}^{M \times N}$ mapping the target computational grid to physical mast locations.
* **Conservation Law (Unity Partition):** Every row $i$ in the observation matrix must sum identically to $1.0$:

$$\sum_{j=1}^{N} A_{i,j} = 1.0 \quad \forall i \in \{1, \dots, M\}$$



This constraint guarantees that no artificial momentum or heat sinks are introduced purely via spatial interpolation.
* **Log-Law Local Bounds:** For sensors positioned close to the ground (e.g., $1.5\text{m}$ target levels sitting below the first grid layer boundary), the matrix must drop long-range structural elements to zero ($\sum A_{1, 3:\text{end}} = 0.0$), relying exclusively on the adjacent local surface nodes.

### 3. Subspace Coordinate Dimensionality (`Mathematical Low-Rank Inversions`)

* **Objective:** Confirms the structural validity of the structural-fitting functions.
* **Details:** Simulates a localized Ridge regression step ($A U_r \eta \approx b$) with an $L_2$ Tikhonov parameter ($\lambda = 10^{-4}$), proving that solving for the compressed coordinate state correctly drops the solution dimension down to the low-rank tracking value ($r = 3$).

### 4. Thermodynamic Order & Disruption (`Information Theory Diagnostics`)

* **Objective:** Evaluates the accuracy of the **Singular Value Entropy** ($\mathcal{H}$) calculations used to detect chaotic structural collapse in boundary layers under Arctic Amplification.
* **Physical Limits:** * Compares a uniform energy distribution (maximum disorder/mixing, maximizing $\mathcal{H}$) against a heavily stratified singular component state (highly organized, minimizing $\mathcal{H}$).
* Checks that an extreme stratified singular state asymptotically reaches a clean zero-entropy limit: $\mathcal{H} \approx 0.0$.



### 5. Memory Layout Integrity (`Chebyshev Group Aliasing Regression`)

* **Objective:** Protects the system against structural variable leakage or pointer mutations when passing complex polynomial vectors through the `ChebyshevResidualEngine`.
* **Details:** Mutating fields within a result structural packet (e.g., manually changing array values in `result.a`) must not overwrite or corrupt independent tracking parameters (`result.b`, `result.c`, `result.d`). This ensures memory fields remain strictly separated.

---

## 🏃 Driving Test Execution

To trigger the complete testing hierarchy directly from the terminal root, run:

```bash
julia --project=. test/runtests.jl

```

Alternatively, invoke the suite from within an active Julia REPL session:

```julia
using Pkg
Pkg.test()

```