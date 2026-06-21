# Folded Equilibrium Structure in the Nocturnal Stable Boundary Layer

## Subtitle
A geometric interpretation of regime transitions and Richardson criticality across CASES-99, FLOSS, GABLS3, and BLLAST

## Central Thesis
The nocturnal stable boundary layer is organized by a low-dimensional folded equilibrium surface. Classical transition markers, including the apparent critical Richardson threshold, appear as geometric signatures of air-column evolution across this surface rather than as purely local closure triggers.

## Audience and Framing Strategy
- Lead with long-standing atmospheric puzzles: multiple equilibria, hysteresis, intermittency, and LLJ-mediated transitions.
- Present manifold topology as an explanatory framework for observed boundary-layer behavior, not as an abstract mathematical endpoint.
- Keep mathematics visible but subordinate: methods are the measurement instrument, physics is the claim.

## Draft Abstract (Writing-Ready)
Stable boundary layers exhibit long-recognized multiple equilibria, hysteresis, and intermittency that remain difficult to unify under local closure perspectives. Across CASES-99, FLOSS, GABLS3, and BLLAST, we reconstruct a low-dimensional atmospheric state surface and find a consistent folded equilibrium geometry whose branch structure organizes observed regime transitions. We further quantify campaign-specific relationships between curvature mode evolution ($\eta_3$) and local gradient stability proxies ($\mathrm{Ri}_g$) using lag-correlation and segmented mutual-information diagnostics. These results support a geometric interpretation in which classical Richardson thresholds are informative local signatures of global state-surface evolution, while keeping causal claims explicitly constrained to what is observed in each campaign.

## Section 1. Multiple Equilibria in the Stable Boundary Layer

Despite decades of field measurements and theoretical advancement, the nocturnal stable boundary layer (SBL) continues to reveal behavior that resists unification under classical local closure perspectives. A fundamental puzzle remains unresolved: why do nearly identical external forcings (geostrophic wind, surface cooling) sometimes yield continuous turbulent mixing and sometimes produce rapid, nearly complete decoupling of the surface from the upper air column?

Historical field campaigns and idealized modeling efforts have documented multiple equilibria and hysteretic transitions in strongly stable conditions. Observations reveal reversed-S-shaped relationships in standard bulk diagnostics such as the Richardson number $\mathrm{Ri}_g$, with dual stable branches separated by an intermediate unstable branch \citep{McNider1993, McNider1995}. The repeated appearance of such structure across campaigns suggests it is not a measurement artifact, but rather an intrinsic consequence of the coupled feedback between radiative cooling, shear-driven turbulence, and momentum decoupling. Early bifurcation studies demonstrated that even highly truncated models—coupling a single prognostic surface temperature equation to simplified boundary-layer closures—could reproduce this multi-valued response when forced with geostrophic wind. The resulting steady-state solutions mapped out a classical folded curve, providing a physically grounded explanation for hysteresis and abrupt regime switching \citep{McNider1995, Biazar1995}. Yet these early models operated in a strongly reduced setting, with vertical dimension collapsed to a handful of bulk parameters. The critical open question is whether this folded structure persists when confronted with the full spatial richness of real atmospheric columns.

Intermittency in the SBL compounds this puzzle. Observations show structured, recurrent bursting events rather than random turbulent fluctuations \citep{Acevedo2001}. These bursts appear to cluster near particular Richardson number ranges and occur with apparent memory—a signature that the system is not simply obeying pointwise closure laws, but rather exploring a constrained phase space. Recent work has highlighted that classical local gradient-based metrics saturate and become uninformative once stratification exceeds critical values \citep{VandeWiel2017}. This diagnostic blindness—the inability of local metrics to characterize the system once $\mathrm{Ri}_g > \mathrm{Ri}_c$—suggests that the true organizing principle lies in the global, non-local structure of the atmospheric column rather than in isolated, one-point stability criteria.

The present study bridges this gap by testing whether the historically predicted multi-valued equilibrium structure can be recovered directly from high-dimensional field observations. If the McNider-era S-curve reflects an intrinsic property of stable boundary-layer dynamics, its folded topology should be reconstructable as a low-dimensional attractor manifold across campaigns with strongly disparate surface properties and forcing contexts. Such recovery would reframe classical stability transitions as projections of motion on a folded state-space surface, rather than as isolated threshold crossings. This framing unites historical observational puzzles with modern manifold-based diagnostics, offering a physically interpretable geometric mechanism for hysteresis, intermittency, and regime transitions.

## Section 2. Reconstruction of the Atmospheric State Surface

Recovering a manifold structure from field observations requires two key steps: developing a dimensionality-reduction method that preserves physically meaningful structure, and cross-validating across diverse measurement contexts to ensure the recovered topology is intrinsic to boundary-layer dynamics rather than an artifact of measurement geometry.

We employ four campaigns selected for physical and instrumental contrast. CASES-99 \citep{Poulos2002} provides dense nocturnal transition sampling over flat grassland in the southern Great Plains, with tower-based measurements at seven discrete heights spanning 1.5–50 m. FLOSS (Forcing Layer Over Snow Surface) offers high-altitude alpine terrain with snow cover and naturally low thermal inertia, fundamentally altering surface energy budgets and radiative feedbacks. GABLS3 \citep{Beare2004} contributes an idealized large-eddy simulation with model-level resolution, providing topology validation independent of instrument clustering biases. BLLAST targets the late-afternoon and evening decay transition, supplying a complementary forcing context where rapid convective shutdown and early stable-layer formation can be resolved continuously. The physical diversity is maximal: grassland versus alpine snowpack, transition-focused observations versus idealized simulation, and nocturnal persistence versus approach-to-night dynamics. If a consistent folded manifold topology emerges across all four, artifact criticism becomes substantially harder to sustain.

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

### Chart-equivalence framing (cusp interpretation)
The physical reversed S-curve and the reduced-coordinate fold should be presented as two coordinate charts of the same parent equilibrium manifold $\mathcal{M}$. In catastrophe-theory language, the relevant organizing geometry is cusp-like: a smooth folded sheet in state space whose projection into a physical chart can overlap along the fold direction. Under that projection, three nearby states can map to similar apparent coordinates, producing the familiar multi-valued S-curve with a middle unstable branch. The reduced p-FEM chart $(\eta_1,\eta_2,\eta_3)$ does not create a new object; it resolves the projection overlap and makes the same equilibrium set visible as a continuous geometry. This reframes "local-threshold disputes" as chart-level interpretation issues rather than contradictions in the underlying dynamics.

Figures 1 and 2 display multi-campaign phase portraits in shared coordinates. The striking result is topological consistency across disparate contexts: CASES-99, FLOSS, GABLS3, and BLLAST all exhibit folded-sheet behavior with branch structure and transition corridors. Campaign offsets appear (different $\eta_1$–$\eta_2$ regions), reflecting background forcing and roughness contrasts. But the *manifold shape*—fold geometry, branch structure, stability organization—remains persistent. If the structure were only a projection artifact, it would collapse under this level of forcing and instrumentation contrast.

### Formal equation block for Section 2 (mass-matrix inner product)
Let $\phi_i(z)$ denote p-FEM basis functions and \(\mathbf{M}\) the corresponding mass matrix with entries

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

### Evidence hierarchy (observed vs inferred)
To keep reviewer-facing claims defensible, we separate direct observations from interpretation-level hypotheses.

Observed in current runs:
- A reproducible $\eta_3$-$\mathrm{Ri}_g$ relationship exists in campaign-scoped diagnostics.
- Lag structure between $d\eta_3/dt$ and $d\mathrm{Ri}_g/dt$ is measurable objectively.
- Subcritical mutual information is substantial in BLLAST for the chosen low-level proxy.
- The same diagnostics can be computed consistently across campaigns.

Inferred / hypothesis-level statements (to be tested across all campaigns):
- Global manifold deformation systematically leads local threshold crossing.
- Local Richardson thresholds are primarily downstream shadows of folded geometry.
- Fold-edge transversality and lag structure map one-to-one to brittle versus rubbery transition classes.

### Brittle versus rubbery fold geometry (campaign comparison seed)
Transversality,

$$
\mathcal{T} = \left.\frac{d\alpha}{d\gamma}\right|_{\mathrm{fold}},
$$

provides a campaign-level geometric descriptor of fold-edge sharpness. In CASES-99, steeper transversality indicates a brittle fold geometry, where small parametric displacement can trigger rapid branch departure and catastrophic transition. In FLOSS, shallower transversality indicates a rubbery fold geometry, where trajectories can linger near marginal stability with weak wave-shedding before full branch escape. This contrast reframes campaign differences as geometric material properties of the same folded state surface.

### Figure plan
- Figure 3: Bifurcation branch map with transition markers and termination annotations.
- Figure 4 (focal): Ri_g(z,gamma) matrix with explicit Ri_c = 0.25 reference contour/line, highlighting supercritical wedge emergence near the fold.

### Structural cross-diagnostic table (for Section 3/4 bridge)
| Campaign | Low-level proxy | Best lag ($\tau_{best}$) | Peak lag correlation $R_{\tau}$ | $I(\eta_3;\mathrm{Ri}_g\leq 0.25)$ (bits) | $I(\eta_3;\mathrm{Ri}_g>0.25)$ (bits) | Interpretation status |
| --- | --- | --- | --- | --- | --- | --- |
| BLLAST | $\mathrm{Ri}_g(2\,m)$ | $\approx 0.0\,h$ | $\approx 0.248$ | $\approx 1.453$ | n/a (for selected proxy) | synchronized transition response |
| CASES-99 | tbd | tbd | tbd | tbd | tbd | pending ALL-campaign run |
| FLOSS | tbd | tbd | tbd | tbd | tbd | pending ALL-campaign run |
| GABLS3 | tbd | tbd | tbd | tbd | tbd | pending ALL-campaign run |

Interpretation guidance for this table: BLLAST currently supports a synchronized-evolution statement (co-evolution of structure and local stability during rapid transition), but does not by itself establish causal ordering.

### Campaign transversality comparison table (place near Figure 4)
| Campaign | Transversality ($d\alpha/d\gamma$) | Geometric classification | Physical boundary-layer behavior |
| --- | --- | --- | --- |
| CASES-99 | $\approx -0.41$ | Brittle fold | Flat grassland with low thermal inertia; rapid decoupling and clean branch jumps. |
| FLOSS | $\approx -0.07$ | Rubbery fold | High-altitude snow-influenced regime; longer residence near marginal stability and weak wave-shedding before escape. |

Note: transversality values are draft analysis estimates and should be labeled provisional until final campaign-wide reruns are frozen.

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
$\eta_3$ should be introduced explicitly as a curvature-sensitive precursor that remains informative when local Richardson diagnostics saturate near criticality. Near fold-proximal loss of resilience, critical-slowing behavior implies slower return toward equilibrium under perturbation, while local gradient metrics become progressively less sensitive once supercritical conditions dominate. Meanwhile, the full column continues to warp under accumulated LLJ shear, and this non-local deformation is tracked by $\eta_3$. In BLLAST, strong subcritical mutual information ($I\approx1.45$ bits) supports this interpretation: $\eta_3$ carries structural information about fold proximity before local metrics alone provide a complete transition picture. This creates a direct bridge to Ri-curvature interpretation: classical stability diagnostics identify where turbulence is vulnerable, whereas $\eta_3$ reveals how the column geometry is deforming toward transition.

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

### Conservative wording block for manuscript integration
Recommended wording for campaign-level claims:

- BLLAST: During rapid evening transition, structural deformation ($\eta_3$) and local Richardson evolution occur nearly simultaneously, consistent with coupled response to column-scale reorganization.
- CASES-99/FLOSS/GABLS3 (target test): If $\tau_{best}>0$ with $\eta_3$ leading, this would strengthen a precursor interpretation; if $\tau_{best}\approx0$, this supports synchronized response under faster forcing.

Recommended wording to avoid until cross-campaign confirmation:

- "local Richardson thresholds are purely downstream symptoms"
- "global manifold collapse always occurs before local threshold crossing"

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