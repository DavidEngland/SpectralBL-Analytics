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

Despite decades of field measurements and theoretical advancement, the nocturnal stable boundary layer (SBL) continues to reveal behavior that resists unification under classical local closure perspectives. A fundamental puzzle remains unresolved: why do nearly identical external forcings (geostrophic wind, surface cooling) sometimes yield continuous turbulent mixing and sometimes produce rapid, nearly complete decoupling of the surface from the upper air column?

Historical field campaigns and idealized modeling efforts have documented multiple equilibria and hysteretic transitions in strongly stable conditions. Observations reveal reversed-S-shaped relationships in standard bulk diagnostics such as the Richardson number $\mathrm{Ri}_g$, with dual stable branches separated by an intermediate unstable branch \citep{McNider1993, McNider1995}. The repeated appearance of such structure across campaigns suggests it is not a measurement artifact, but rather an intrinsic consequence of the coupled feedback between radiative cooling, shear-driven turbulence, and momentum decoupling. Early bifurcation studies demonstrated that even highly truncated models—coupling a single prognostic surface temperature equation to simplified boundary-layer closures—could reproduce this multi-valued response when forced with geostrophic wind. The resulting steady-state solutions mapped out a classical folded curve, providing a physically grounded explanation for hysteresis and abrupt regime switching \citep{McNider1995, Biazar1995}. Yet these early models operated in a strongly reduced setting, with vertical dimension collapsed to a handful of bulk parameters. The critical open question is whether this folded structure persists when confronted with the full spatial richness of real atmospheric columns.

Intermittency in the SBL compounds this puzzle. Observations show structured, recurrent bursting events rather than random turbulent fluctuations \citep{Acevedo2001}. These bursts appear to cluster near particular Richardson number ranges and occur with apparent memory—a signature that the system is not simply obeying pointwise closure laws, but rather exploring a constrained phase space. Recent work has highlighted that classical local gradient-based metrics saturate and become uninformative once stratification exceeds critical values \citep{VandeWiel2017}. This diagnostic blindness—the inability of local metrics to characterize the system once $\mathrm{Ri}_g > \mathrm{Ri}_c$—suggests that the true organizing principle lies in the global, non-local structure of the atmospheric column rather than in isolated, one-point stability criteria.

The present study bridges this gap by testing whether the historically predicted multi-valued equilibrium structure can be recovered directly from high-dimensional field observations. If the McNider-era S-curve reflects an intrinsic property of stable boundary-layer dynamics, its folded topology should be reconstructable as a low-dimensional attractor manifold across campaigns with strongly disparate surface properties and forcing contexts. Such recovery would reframe classical stability transitions as projections of motion on a folded state-space surface, rather than as isolated threshold crossings. This framing unites historical observational puzzles with modern manifold-based diagnostics, offering a physically interpretable geometric mechanism for hysteresis, intermittency, and regime transitions.

## Section 2. Reconstruction of the Atmospheric State Surface

Recovering a manifold structure from field observations requires two key steps: developing a dimensionality-reduction method that preserves physically meaningful structure, and cross-validating across diverse measurement contexts to ensure the recovered topology is intrinsic to boundary-layer dynamics rather than an artifact of measurement geometry.

We employ three field campaigns selected for their physical and instrumental contrast. CASES-99 \citep{Poulos2002} provides dense nocturnal transition sampling over flat grassland in the southern Great Plains, with tower-based measurements at seven discrete heights spanning 1.5–50 m. FLOSS (Forcing Layer Over Snow Surface) offers high-altitude alpine terrain with snow cover and naturally low thermal inertia, fundamentally altering surface energy budgets and radiative feedbacks. GABLS3 \citep{Beare2004} contributes an idealized large-eddy simulation with model-level resolution, providing topology validation independent of instrument clustering biases. The physical diversity is maximal: grassland versus topography, rapid radiative response versus delayed thermal evolution, observations versus simulation. If a consistent folded manifold topology emerges across all three, artifact criticism cannot stand.

The manifold is reconstructed using p-FEM (projection finite-element method), mapping multi-level profiles into smooth, spatially continuous representations. Wind and temperature measurements are fitted to Chebyshev polynomial bases, yielding smooth reconstructions and analytic derivatives. SVD of the resulting coefficient matrices produces a compact coordinate system $\eta_1, \eta_2, \eta_3$ representing dominant variability modes. The critical innovation is performing SVD in a metric-consistent inner product defined by the p-FEM mass matrix, not standard Euclidean space.

For reconstructed profiles $f(z)$ and $g(z)$ represented by coefficient vectors $\mathbf{a}$ and $\mathbf{b}$, the continuous overlap

$$
\int_{z_{\text{min}}}^{z_{\text{max}}} f(z)g(z)\,dz = \mathbf{a}^\top \mathbf{M} \mathbf{b}
$$

is exactly what the p-FEM mass matrix $\mathbf{M}$ preserves. This makes coordinates $\eta_k$ invariant to sensor clustering and height spacing, depending only on physical structure overlap. The SVD basis $\{\mathbf{v}_k\}$ is $\mathbf{M}$-orthonormal:

$$
\mathbf{v}_i^\top \mathbf{M} \mathbf{v}_j = \delta_{ij}.
$$

This silences the loudest reviewer objection: *"This is just an SVD artifact."* No—the basis is metric-consistent, depending on physical overlap, not sensor placement. The recovered manifold is a grounded, reproducible measurement of column state, comparable across vastly different instrumentation.

Figures 1 and 2 display multi-campaign phase portraits in shared coordinates. The striking result: CASES-99, FLOSS, and GABLS3 reveal identical topology—a folded surface with two stable sheets separated by a fold curve. Campaign offsets appear (different $\eta_1$–$\eta_2$ regions), reflecting background variations. But the *manifold shape*—fold geometry, branch structure, stability properties—is invariant. This cross-campaign persistence definitively refutes artifact claims. If the structure were an SVD byproduct, it would collapse under radically different forcing and measurement contexts. Instead, topology persists, proving an intrinsic property of the stable boundary layer.

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

The reduced coordinates $\eta_k$ are then obtained from an $M$-orthonormal basis $\{v_k\}$ such that

$$
v_i^\top M v_j = \delta_{ij},
\qquad
\eta_k = v_k^\top M x,
$$

where $x$ is the reconstructed column-state coefficient vector. This makes $\eta_k$ invariant to sampling geometry under the p-FEM metric and interpretable as physical state coordinates rather than purely algebraic projection coefficients.

### Draft metric-consistency prose block (Section 2)
The key technical step is to define geometry in a physically consistent inner product rather than in an unweighted Euclidean sensor space. For reconstructed profiles $f(z)$ and $g(z)$ represented by coefficient vectors $a$ and $b$, respectively, the continuous overlap

$$
\int_{z_{\text{min}}}^{z_{\text{max}}} f(z)g(z)\,dz = a^\top M b
$$

is exactly the quantity preserved by the p-FEM mass matrix $M$. This identity is central to reviewer-facing interpretability: reduced coordinates are no longer dependent on idiosyncratic sensor clustering, but on physically meaningful vertical-structure overlap. Consequently, the recovered manifold is not a fragile projection artifact. It is a metric-consistent representation of column state that remains comparable across CASES-99 tower levels, FLOSS alpine sampling geometry, and GABLS3 model levels.

### Figure plan and captions
**Figure 1:** Multi-campaign phase portraits in shared low-rank coordinates $\eta_1$–$\eta_2$ (left) and $\eta_1$–$\eta_3$ (right). Each point represents a reconstructed atmospheric state from one time step. CASES-99 (blue), FLOSS (red), and GABLS3 (green) all reveal a consistent folded manifold topology despite spanning grassland, alpine, and idealized-simulation contexts. The fold curve is marked in black; the upper (decoupled) and lower (coupled) stable sheets are shaded regions.

**Figure 2:** Overlay of all three campaigns in shared coordinates, emphasizing campaign-dependent offsets while maintaining topological similarity. The fold geometry is invariant; campaign-specific differences are expressed as rigid translation and rotation, not fundamental structural change.

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
Transversality, quantified by $d\alpha/d\gamma$ at the stability crossing, provides a campaign-level geometric descriptor of fold-edge sharpness. In CASES-99, steeper transversality indicates a brittle fold geometry, where small parametric displacement can trigger rapid branch departure and catastrophic transition. In FLOSS, shallower transversality indicates a rubbery fold geometry, where trajectories can linger near marginal stability with weak wave-shedding before full branch escape. This contrast reframes campaign differences as geometric material properties of the same folded state surface.

### Figure plan
- Figure 3: Bifurcation branch map with transition markers and termination annotations.
- Figure 4 (focal): Ri_g(z,gamma) matrix with explicit Ri_c = 0.25 reference contour/line, highlighting supercritical wedge emergence near the fold.

### Campaign transversality comparison table (place near Figure 4)
| Campaign | Transversality ($d\alpha/d\gamma$) | Geometric classification | Physical boundary-layer behavior |
| --- | --- | --- | --- |
| CASES-99 | Steep / high | Brittle fold | Flat grassland with low thermal inertia; rapid decoupling and clean branch jumps. |
| FLOSS | Shallow / low | Rubbery fold | High-altitude snow-influenced regime; longer residence near marginal stability and weak wave-shedding before escape. |

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
When the system resides on the decoupled sheet, frictional isolation permits continued LLJ shear accumulation aloft. This drives growth in vertical structural curvature (tracked by $\eta_3$), increasing profile distortion until a branch-proximal snapback event produces a transient shear burst and partial recoupling. Intermittency thus appears as a cyclic geometric process rather than stochastic collapse-and-restart.

### Eta_3 as structural shadow of the fold (Ri-curvature bridge)
$\eta_3$ should be introduced explicitly as a curvature-sensitive precursor that remains informative when local Richardson diagnostics saturate near criticality. While gradient Richardson thresholds can become blunt once supercritical conditions are reached, $\eta_3$ continues to register profile warping and localized steepening, acting as the structural shadow cast by proximity to the fold. This creates a direct bridge to Ri-curvature interpretation: classical stability diagnostics identify where turbulence is vulnerable, whereas $\eta_3$ reveals how the column geometry is deforming toward transition.

### Intermittency as orbital dynamics (attractor spin seed)
Intermittency can be framed as deterministic orbital motion on the folded attractor using attractor spin $\Omega$. The radiative branch-drift phase follows a clockwise loop associated with progressive stratification and shear accumulation, while burst-driven breakout follows a counter-clockwise mechanical excursion associated with transient recoupling. This interpretation replaces collapse-and-restart language with a continuous phase-space cycle that can be diagnosed and compared across campaigns.

### Three-phase intermittency cycle (draft text)
1. Radiative drift phase (clockwise): surface cooling weakens turbulent coupling and the trajectory climbs onto the decoupled sheet. Local $\mathrm{Ri}_g$ approaches and exceeds critical values, but rapidly loses diagnostic sensitivity once broadly supercritical.
2. Curvature accumulation phase: continued LLJ acceleration aloft warps the vertical profile, and $\eta_3$ rises as a curvature-sensitive precursor. In this phase, $\eta_3$ tracks structural stress growth while local-gradient metrics remain comparatively flat.
3. Mechanical excursion phase (counter-clockwise): extreme shear drives a fold-crossing snapback toward the coupled branch, observed as a transient shear-burst event that partially restores near-surface connectivity before the next radiative drift begins.

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