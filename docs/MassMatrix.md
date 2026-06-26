# Mass Matrix Note for SpectralBL

## Purpose
This note explains what the mass matrix is, why it matters for p-FEM and spectral methods, and how to explain it to atmospheric modelers.

## One-line definition
The mass matrix is the discrete representation of the continuous L2 inner product on the profile function space.

For basis functions phi_i and phi_j,

M_ij = integral_Omega phi_i(x) phi_j(x) dOmega.

For coefficient vectors a and b,

a^T M b approximates integral_Omega f(x) g(x) dOmega,

so M defines the geometry (lengths, angles, overlap) of reduced coordinates.

## Where it comes from
In Galerkin projection, write

u_h(x,t) = sum_i U_i(t) phi_i(x).

Testing against phi_j yields

sum_i M_ji dU_i/dt = RHS_j,

with

M_ji = integral_Omega phi_j phi_i dOmega.

This is why time-dependent reduced systems naturally appear as

M adot = K a + F.

## Why the name mass matrix
In mechanics,

rho d2u/dt2 = div sigma

leads to

M uddot + K u = f,

where M multiplies acceleration and therefore plays the inertia (mass) role. The same algebraic object appears in heat, transport, and atmospheric column dynamics after weak projection.

## Interpretation in one sentence
M_ij measures overlap of basis functions, so diagonal terms are self-contributions and off-diagonal terms are coupling.

## p-FEM and spectral consequences
### 1) Basis choice controls structure
- Non-orthogonal local bases: sparse but non-diagonal M.
- Orthogonal polynomial bases (Legendre, Jacobi variants): diagonal or nearly diagonal M in ideal settings.
- Hierarchical integrated-Legendre style bases: better conditioning, nested p-refinement, often near block-diagonal structure.

### 2) Quadrature choice can diagonalize M
With nodal bases plus Gauss-Lobatto quadrature,

M_ij is approximated by sum_k w_k phi_i(x_k) phi_j(x_k).

At interpolation nodes phi_i(x_k) = delta_ik, so M becomes diagonal in the quadrature metric. This is a key spectral-element efficiency result.

## Geometric view used in SpectralBL
Treat M as a metric tensor on the finite-dimensional profile space.

- Inner product: <u,v>_M = u^T M v
- Norm: ||u||_M^2 = u^T M u
- Orthogonality: u^T M v = 0

This is the exact reason the manuscript emphasizes an M-weighted Hilbert-space inner product: coordinates extracted by SVD in this metric are tied to physical profile overlap, not sensor placement geometry.

## Why this matters for artifact defense
If coordinates are computed in the Euclidean dot product, spacing and clustering of levels can distort modes. If coordinates are computed in the M-weighted inner product, the metric approximates the continuous profile overlap integral and is therefore mesh-aware in a physically meaningful way.

Practical claim:
- Euclidean projection is discretization-sensitive.
- M-weighted projection is physically anchored and substantially more mesh-invariant.

## Two-minute explanation for Dick McNider and mixed audiences
Think of each atmospheric profile as a shape. The mass matrix is the ruler that tells us how much two shapes overlap over height.

If we use the wrong ruler (plain Euclidean dot product), the answer depends too much on where instruments happen to be located. If we use the mass-matrix ruler, we measure overlap in physical height-space, so the leading modes represent the atmosphere, not the instrument layout.

That is why our reduced coordinates are defensible: they inherit physical meaning from the profile inner product, and that is also why they remain informative near transitions where local Richardson diagnostics saturate.

## Suggested slide-ready lines
- The mass matrix is not bookkeeping; it is the geometry of the reduced state space.
- M-weighted SVD gives modes of physical overlap, not modes of sensor placement.
- Near fold transitions, metric-aware coordinates retain structure that local scalar thresholds lose.

## Manuscript appendix pointer
A manuscript-ready appendix draft is available at:

manuscript/sections/appendix_mass_matrix.tex

To include it in main.tex later, add in the back matter:

\appendix
\input{sections/appendix_mass_matrix}

If figures must remain at the end, place the appendix before the bibliography and keep the Figure Suite block where it is now.
