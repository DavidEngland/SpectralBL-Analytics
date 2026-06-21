# Folded Equilibrium Structure in the Nocturnal Stable Boundary Layer

## Subtitle
A geometric interpretation of regime transitions and Richardson criticality across CASES-99, FLOSS, and GABLS3

## Central Thesis
The nocturnal stable boundary layer is organized by a low-dimensional folded equilibrium surface. Classical transition markers, including the apparent critical Richardson threshold, appear as geometric signatures of air-column evolution across this surface rather than as purely local closure triggers.

## Audience and Framing Strategy
- Lead with long-standing atmospheric puzzles: multiple equilibria, hysteresis, intermittency, and LLJ-mediated transitions.
- Present manifold topology as an explanatory framework for observed boundary-layer behavior, not as an abstract mathematical endpoint.
- Keep mathematics visible but subordinate: methods are the measurement instrument, physics is the claim.

## Draft Abstract (Writing-Ready)
Stable boundary layers exhibit long-recognized multiple equilibria, hysteresis, and intermittency that remain difficult to unify under local closure perspectives. Across CASES-99, FLOSS, and GABLS3, we reconstruct a low-dimensional atmospheric state surface and find a consistent folded equilibrium geometry whose branch structure organizes observed regime transitions. The apparent critical Richardson threshold emerges as a local symptom of fold-proximal column evolution, reframing classical stability criteria within a physically testable geometric framework.

## Section 1. Multiple Equilibria in the Stable Boundary Layer

### Section objective
Establish that atmospheric observations have long indicated non-uniqueness and path dependence in nocturnal boundary-layer states under comparable external forcing.

### Core narrative points
- Historical observations support multiple equilibria in strongly stable nights.
- Reversed-S transition behavior is repeatedly observed in stable-regime diagnostics.
- Hysteresis appears during forcing ramps and recovery, indicating memory effects.
- Intermittency is structured and recurrent, not random measurement noise.

### Reviewer-preemption sentence
The key unresolved question is not whether transitions occur, but why they repeatedly organize along structured branches rather than diffuse scatter.

### Bridge sentence to Section 2
This motivates a non-local view in which the full column state, not a single-level metric, is the natural object of analysis.

### Historical context and truncation limits (McNider lineage)
Early multiple-equilibria studies showed that coupling a prognostic near-surface temperature equation to a truncated boundary-layer closure yields a nonlinear algebraic steady-state system with a multi-valued, reversed S-shaped response under geostrophic forcing. In that framework, dual stable branches are separated by an intermediate unstable branch, providing a physically grounded explanation for hysteresis and abrupt regime switching.

### Continuity statement from classical S-curves to this manuscript
The present framework is positioned as a spatially continuous realization of that original hypothesis. The S-curve is no longer restricted to a single-level diagnostic relationship; it becomes the projected geometry of the full atmospheric column on a folded equilibrium manifold inferred from multi-level observations.

## Section 2. Reconstruction of the Atmospheric State Surface

### Section objective
Show that CASES-99, FLOSS, and GABLS3 each admit a compact state description with coherent branch topology across physically disparate environments.

### Core narrative points
- CASES-99 contributes dense nocturnal transition sampling over open grassland.
- FLOSS contributes high-altitude, snow-influenced, low-thermal-inertia forcing heterogeneity.
- GABLS3 contributes controlled, idealized structure for topology sanity-checking.
- A consistent low-dimensional topology across all three argues against campaign-specific artifact explanations.

### Explicit artifact-defense paragraph seed
A likely criticism is that low-rank structure could be an artifact of projection choice. The cross-campaign persistence of topology is the central rebuttal: if similar folded branch geometry appears across contrasting surface energy budgets and measurement contexts, then the structure reflects an intrinsic dynamical property of the stable boundary layer rather than an SVD-specific quirk.

### Metric-consistency paragraph seed (mass-matrix defense)
To preempt projection-artifact criticism more directly, the coordinate construction should be stated in a metric-consistent inner product induced by the p-FEM mass matrix M. Without mass weighting, modal coordinates can inherit tower-spacing and sampling-geometry bias; with the M-weighted inner product, the reduced coordinates are tied to physically meaningful energy and profile structure, not arbitrary sensor placement. This distinction is central: the manifold is not merely a convenient low-rank fit, but a physically grounded measurement of atmospheric column state.

### Formal equation block for Section 2 (mass-matrix inner product)
Let phi_i(z) denote p-FEM basis functions and M the corresponding mass matrix with entries

$$
M_{ij} = \int_{z_{min}}^{z_{max}} \phi_i(z)\,\phi_j(z)\,dz.
$$

Define the physically weighted inner product for coefficient vectors a and b by

$$
\langle a, b \rangle_M = a^\top M b,
\qquad
\|a\|_M^2 = a^\top M a.
$$

The reduced coordinates eta_k are then obtained from an M-orthonormal basis \{v_k\} such that

$$
v_i^\top M v_j = \delta_{ij},
\qquad
\eta_k = v_k^\top M x,
$$

where x is the reconstructed column-state coefficient vector. This makes eta_k invariant to sampling geometry under the p-FEM metric and interpretable as physical state coordinates rather than purely algebraic projection coefficients.

### Figure plan
- Figure 1: Multi-campaign phase portraits in shared low-rank coordinates.
- Figure 2: Campaign overlays showing branch similarity and campaign-dependent offsets.

## Section 3. Geometric Origin of Stability Transitions

### Section objective
Demonstrate that catastrophic transitions align with fold geometry and that Richardson-threshold crossings are localized manifestations of global state-surface evolution.

### Core narrative points
- The equilibrium surface contains folded branch structure with distinct stability sheets.
- Transition events correspond to branch jumps near fold-proximal trajectories.
- Local Richardson exceedance aligns with geometric tipping behavior of the full column.
- Causal direction is geometric-to-local: column reconfiguration first, local threshold crossing second.

### Causality precision sentence
The crossing of Ri_c is interpreted as a localized symptom of global manifold collapse, not an isolated one-point trigger that independently causes the transition.

### Brittle versus rubbery fold geometry (campaign comparison seed)
Transversality, quantified by d alpha divided by d gamma at the stability crossing, provides a campaign-level geometric descriptor of fold-edge sharpness. In CASES-99, steeper transversality indicates a brittle fold geometry, where small parametric displacement can trigger rapid branch departure and catastrophic transition. In FLOSS, shallower transversality indicates a rubbery fold geometry, where trajectories can linger near marginal stability with weak wave-shedding before full branch escape. This contrast reframes campaign differences as geometric material properties of the same folded state surface.

### Figure plan
- Figure 3: Bifurcation branch map with transition markers and termination annotations.
- Figure 4 (focal): Ri_g(z,gamma) matrix with explicit Ri_c = 0.25 reference contour/line, highlighting supercritical wedge emergence near the fold.

## Section 4. Physical Interpretation of Regime Dynamics

### Section objective
Translate geometric diagnostics into process language familiar to boundary-layer meteorology.

### Core narrative points
- Coupled regime: shear production and turbulence maintain near-surface connection.
- Transitional regime: resilience decreases, intermittency increases, sensitivity rises.
- Decoupled regime: near-surface suppression persists while elevated shear structures evolve.
- LLJ intensification is branch-dependent and tied to reduced frictional coupling.
- Shear bursting occurs as episodic reconnection events during branch-proximal excursions.

### Eta_3 and intermittency mechanism paragraph seed
When the system resides on the decoupled sheet, frictional isolation permits continued LLJ shear accumulation aloft. This drives growth in vertical structural curvature (tracked by eta_3), increasing profile distortion until a branch-proximal snapback event produces a transient shear burst and partial recoupling. Intermittency thus appears as a cyclic geometric process rather than stochastic collapse-and-restart.

### Eta_3 as structural shadow of the fold (Ri-curvature bridge)
Eta_3 should be introduced explicitly as a curvature-sensitive precursor that remains informative when local Richardson diagnostics saturate near criticality. While gradient Richardson thresholds can become blunt once supercritical conditions are reached, eta_3 continues to register profile warping and localized steepening, acting as the structural shadow cast by proximity to the fold. This creates a direct bridge to Ri-curvature interpretation: classical stability diagnostics identify where turbulence is vulnerable, whereas eta_3 reveals how the column geometry is deforming toward transition.

### Intermittency as orbital dynamics (attractor spin seed)
Intermittency can be framed as deterministic orbital motion on the folded attractor using attractor spin Omega. The radiative branch-drift phase follows a clockwise loop associated with progressive stratification and shear accumulation, while burst-driven breakout follows a counter-clockwise mechanical excursion associated with transient recoupling. This interpretation replaces collapse-and-restart language with a continuous phase-space cycle that can be diagnosed and compared across campaigns.

### Translation table (in-paper box)
- Folded manifold -> Multiple atmospheric equilibria.
- Fold proximity -> Reduced resilience and heightened intermittency.
- Branch jump -> Rapid regime transition.
- Hysteresis loop -> Path-dependent atmospheric evolution.
- Curvature growth -> Approach to turbulence collapse and decoupling.

## Section 5. Computational Framework as an Evidence Engine

### Section objective
Document reproducibility and diagnostic traceability while preserving physics-first narrative priority.

### Tone target
This section should read as an analytical validation suite, not a software walkthrough.

### Core narrative points
- p-FEM reconstruction provides smooth, physically coherent vertical profile fields.
- Spectral basis plus SVD embedding yields compact coordinates for branch analysis.
- Continuation analysis localizes stability changes and branch transitions.
- Analytic derivative pathways support continuous Ri_g profile diagnostics.

### Positioning sentence
The p-FEM and continuation pipeline functions as a high-fidelity diagnostic microscope that reveals geometric structure with mathematical smoothness unavailable in raw finite-difference estimates.

## Section-to-Claim Map
- Section 1 claim: Multiple equilibria and reversed S-curves are historically established SBL features, and the McNider truncation framework provides the original bifurcation logic.
- Section 2 claim: These historical S-curve structures are reconstructed from multi-level data as a continuous manifold using an M-weighted p-FEM metric, not a basis artifact.
- Section 3 claim: Transition thresholds align with fold geometry and branch topology, with Ri_c crossing as a local signature of fold-proximal evolution.
- Section 4 claim: LLJ evolution, shear bursting, and decoupling are branch-governed physical consequences.
- Section 5 claim: The computational pipeline is the reproducible evidence path supporting the physics claims.

## Candidate Conclusion Paragraph (Draft)
The principal contribution is a physics result: the nocturnal boundary layer behaves as a folded, low-dimensional equilibrium system whose geometry organizes transition, intermittency, and hysteresis. In this view, classical Richardson criticality is not discarded, but reinterpreted as a local diagnostic of global structural evolution. This framing links long-standing stable-boundary-layer observations to a unifying geometric mechanism that is empirically testable across field campaigns and idealized configurations.

## Candidate References (Working List)

### Atmospheric theory and SBL observations
- Vignon et al. (2017): reversed S-shape and two-regime behavior over Antarctic stable conditions.
- Van de Wiel et al. (2017): minimum-wind sustainable turbulence concepts linked to fold behavior.
- McNider, Tripoli, Pal, and Pielke (1993): multiple equilibria analysis in the nocturnal boundary layer.
- McNider, England, Friedman, and Shi (1995): predictability framework and bifurcation structure of nocturnal SBL states.
- Biazar and McNider (1995): regional-scale bifurcation interpretation for nocturnal boundary-layer forecasting.
- McNider et al. (2012): multiple stable solutions and surface temperature feedbacks in SBL dynamics.
- Derbyshire (1999): boundary-layer decoupling as a physical stability boundary.
- Stull (1988): canonical boundary-layer baseline for local-gradient expectations.
- Acevedo and Fitzjarrald (2001): evening-transition dynamics and rapid decay phase constraints.

### Dynamical systems and bifurcation foundations
- Shirer (1980): Hopf-related dynamics in sheared convection contexts.
- Takens (1981): topology-preserving embedding foundations for reconstructed dynamics.
- Ruelle and Takens (1971): successive Hopf transition route to turbulence.
- Marsden and McCracken (1976): formal Hopf bifurcation theorem treatment.

### Data-driven and reduced-order modeling context
- Brunton et al. (2016): sparse identification of governing dynamics.
- Peherstorfer and Willcox (2016): operator inference and reduced-order model structure.
- Shimizu and Kawahara (2017): low-dimensional turbulence-reproducing systems via machine learning.

### Campaign and intercomparison anchors
- Beare et al. (2004): GABLS LES intercomparison benchmark.
- Poveda-Jaramillo and Puente (1993): early low-dimensional attractor identification in atmospheric flows.

## Immediate Drafting Checklist
1. Write Section 1 opening page with McNider 1993/1995 lineage and local-vs-non-local tension statement.
2. Convert the Section 2 mass-matrix equations into manuscript notation and connect directly to invariance claims.
3. Build Section 2 cross-campaign artifact-defense paragraph around physical contrast of CASES-99, FLOSS, GABLS3.
4. Lock Figure 4 caption language around causality direction: geometric transition first, Ri_c crossing second.
5. Expand Section 4 eta_3 paragraph into a full intermittency mechanism subsection.
6. Add transversality comparison text and table for brittle CASES-99 versus rubbery FLOSS behavior.
7. Keep Section 5 concise and evidence-oriented; reserve implementation details for supplement/appendix.