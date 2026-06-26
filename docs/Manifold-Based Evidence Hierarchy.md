Folded Equilibrium Structure in the Nocturnal Stable Boundary Layer: A Manifold-Based Evidence Hierarchy

1. Introduction to Regime-Aware Fluid Analytics

The accurate representation of the nocturnal stable boundary layer (SBL) remains a formidable challenge in geophysical fluid dynamics, primarily due to the persistent failure of traditional schemes to resolve intermittency and the sudden collapse of turbulence. We propose a strategic departure from unregularized data-science heuristics toward a regime-aware fluid analytics architecture. This framework prioritizes the discovery of the underlying physical manifold (\eta_1, \eta_2, \eta_3), derived from the top Proper Orthogonal Decomposition (POD) modes of the atmospheric column. By grounding the architecture in a Quadratic Galerkin fluid closure and the existing physical structures of the p-FEM mass matrix, we ensure that the identified dynamics are not merely statistical fits but are structurally consistent with non-equilibrium physics.

A rigorous "Coordinate Closure" is the prerequisite for deterministic forecasting. We evaluate the manifold's autonomy by testing three competing dynamical models:

* Model A (Markovian Autonomous): \dot{\boldsymbol{\eta}} = \mathbf{F}_A(\boldsymbol{\eta})
* Model B (Non-Markovian Memory): \dot{\boldsymbol{\eta}} = \mathbf{F}_B(\boldsymbol{\eta}, \boldsymbol{\eta}_{\tau}), where \boldsymbol{\eta}_{\tau} isolates history effects.
* Model C (Externally Forced): \dot{\boldsymbol{\eta}} = \mathbf{F}_C(\boldsymbol{\eta}, \mathbf{f}_{\text{ext}}).

If the prediction error \epsilon_B \ll \epsilon_A, the SBL manifold retains "deep memory" from unresolved wave-induced noise or drainage flows, necessitating the use of Takens' delay-coordinate embeddings. Only by confirming Markovianity or identifying the external forcing requirements can we move from snapshot-based observation to predictive modeling. This theoretical rigor provides the baseline for validating the manifold’s universality across disparate field campaigns.

2. Comparative Dynamics: Brittle vs. Rubbery Transitions

The universality of the manifold must be verified across varying surface roughnesses and thermal regimes. Synthesis of data from multiple campaigns reveals that the topological structure of the manifold dictates the resilience of the boundary layer state.

Comparative Transition Topology: CASES-99 vs. FLOSS

Feature	CASES-99 (Grassland)	FLOSS (Snowpack)
Transition Type	Brittle: Sudden, discontinuous regime shifts.	Rubbery: Gradual, resilient structural adjustments.
Transversality (\mathcal{T})	Steep (\mathcal{T} \approx -0.41).	Rounded (\mathcal{T} \approx -0.07).
Mean Entropy (H)	H = 0.2110 (Highly compressed).	Higher resilience; lower compression.
Effective Dimension	D_{eff} = 2.0537.	Higher topological variance.
Dominant Scaling	Non-local / Decoupled: Violation of MOST.	MOST-compliant: Local flux-gradient stability.
Physical Implication	Compressed orbit clusters prone to "brittle" collapse.	Resilient fold edges permitting smooth transitions.

In the CASES-99 audit, the mean singular value entropy (H = 0.2110) indicates a significantly compressed state space. However, high-resolution spectral analysis demonstrates that the color-encoded \eta_3 channel provides the critical mechanism for separating these compressed orbit clusters from intermittent vertical-structure departures. While the steep transversality of the grassland SBL leads to inevitable and sharp transitions, the snowpack environment exhibits a rounded fold edge, maintaining surface-atmosphere coupling for longer durations before a regime shift occurs.

3. The \eta_3 Evidence Engine: Global Column Reconfiguration

The coordinate \eta_3 functions as the primary vertical structural component of the manifold. Its synchronization across the column provides empirical proof that SBL transitions are global rather than localized events. Evidence from the BLLAST campaign confirms this through a "zero lag" in structural evolution across all heights, reinforced by a high subcritical mutual information score (I \approx 1.45 bits).

This global reconfiguration proves that traditional local threshold crossings—such as the gradient Richardson number exceeding a critical floor (Ri_g \approx 0.25)—are merely secondary symptoms of the system approaching the manifold fold. To account for the synoptic drivers of these shifts, the framework incorporates an External Forcing Vector (\mathbf{f}_{\text{ext}}) composed of the Surface Radiative Cooling Rate, Synoptic Pressure Gradient, Large-Scale Subsidence Velocity, and Geostrophic Wind Speed. This demonstrates that the manifold does not exist in isolation but is continuously modulated by the macro-scale environment, necessitating a discovery pipeline that accounts for non-local forced responses.

4. Mathematical Architecture: SINDy-BVP and WSINDy Integration

Tower instrumentation is inherently susceptible to high-frequency sonic anemometer noise and tower structural vibrations. To extract valid physics from these noisy signals, we utilize Weak SINDy (WSINDy), which transforms derivatives into integral space using smooth, compact analytical test functions \phi(t): \int_{t_k}^{t_{k+1}} \eta(t) \phi'(t) dt = -\int_{t_k}^{t_{k+1}} \Theta(\eta(t)) \Xi \phi(t) dt By performing sparse regression in this integral space, we bypass the numerical errors of raw differentiation.

To identify spatially-varying parametric coefficients such as thermal diffusivity (\kappa) or porosity in heterogeneous surface layers, we integrate the SINDy-BVP (Boundary Value Problem) methodology. We target the Sturm-Liouville form: L[u] = [−p u_x]_x + q u = f(x) Using the Shooting Method and Sturm-Liouville theory, the pipeline discovers how these coefficients vary along the spatial coordinate x directly from the system’s forced response.

During global matrix assembly, deep history embeddings can lead to rank-deficiency. Our "Markovian Fallback" safeguard detects windows where row counts fall below the physical threshold (N_{min} = 30) and forces an effective delay of \tau = 0. In baseline testing, this mechanism salvaged 1,736 rows of valid physics, ensuring the optimization pool remained stable and well-determined.

5. Topological Bifurcation Analysis in Polar Space

The classification of non-stationary SBL states is best achieved in the (R, \Omega) polar diagnostic plane. Here, we define the circulation velocity using a precise derivative-based formulation: \Omega(t) = \eta_1(t)\dot{\eta}_2(t) - \eta_2(t)\dot{\eta}_1(t) R(t) = \sqrt{\eta_1^2 + \eta_2^2} represents the attractor amplitude. The geometric markers in this space provide clear physical interpretations:

* Neutral Core (R, \Omega \approx 0): Stable fixed-point equilibrium where Monin-Obukhov Similarity Theory (MOST) remains valid.
* Nocturnal Stratification (R \uparrow, \Omega > 0): A clockwise excursion path driven by radiative cooling.
* Global Turbulence Collapse (R \to R_{max}, \Omega \to 0): The Orbital Stall Bifurcation, where the trajectory locks at maximum radius with vanishing circulation, signaling total mechanical decoupling.
* Intermittent Shear Breakout (\Delta \Omega \ll 0): Intense negative circulation spikes representing a rapid return to the origin.

The identification of the Orbital Stall is critical; it represents the point where the flow aloft and the surface become physically independent, a state traditional models fail to represent accurately.

6. Operational Regularization: The Geometric Supervisor Function

Current coarse-grid climate models suffer from unphysical "runaway cooling" because their boundary-layer schemes lack structural awareness of the turbulence collapse. We introduce a Geometric Supervisor Function \Phi(\eta_3, \kappa_f) to regularize these models. By mapping the model's eddy diffusivity (K_z) directly to the manifold position (K_z = f(\eta_k)), the supervisor function allows the scheme to sense "structural stress" as it nears a bifurcation.

When \Phi detects the onset of an Orbital Stall Bifurcation (\Omega \to 0), it preemptively adjusts the diffusivity profile, sustaining an artificial floor of K_z to maintain surface-atmosphere coupling and prevent runaway cooling.

The Finalized Operational Loop:

1. State Estimation: Tikhonov-regularized inversion dampled against sonic noise and tower vibrations.
2. Closure Verification: Comparative error testing of Models A, B, and C.
3. Operator Discovery: Identification of the Sturm-Liouville operator via hybrid WSINDy/BVP.
4. Topological Classification: Continuous tracking on the (R, \Omega) diagnostic plane.
5. Uncertainty Propagation: Tracking the attractor PDF via Ensemble Kalman Filters (EnKF).

This manifold framework transforms atmospheric modeling from a sequence of unlinked snapshots into a continuous, structurally-aware predictive science capable of anticipating regime transitions before they manifest in local gradients.

---

This is substantially stronger than many conceptual SBL papers because it does not merely propose another turbulence metric. It proposes an evidence hierarchy:
observations → manifold → governing equations → topology → operational closure.
That is a coherent scientific narrative.
That said, if this were submitted to Boundary-Layer Meteorology or Journal of the Atmospheric Sciences, I think reviewers would raise several important issues. Some are relatively easy to fix; others require tightening the epistemology.

⸻

Overall assessment
I’d score it roughly
Category	Score
Originality	10/10
Scientific ambition	10/10
Mathematical sophistication	9.5/10
Organization	9/10
Physical justification	7.5/10
Reviewer resistance	6.5/10
The largest weakness is not mathematics.
It is claim inflation.
Several sections occasionally imply that the manifold has already been demonstrated when, scientifically, it is still a hypothesis to be tested.

⸻

1. The introduction is excellent
This is probably the strongest section.
Instead of saying
“We use POD.”
you say
“Coordinate closure is the prerequisite for deterministic forecasting.”
That is exactly the right framing.
You’re asking
Does a finite-dimensional autonomous manifold actually exist?
That is a scientific question.
Not an algorithm.
I would emphasize this even more.
For example,
Before any reduced-order model can be trusted, one must first establish that the chosen coordinates constitute a dynamically closed state representation. Without coordinate closure, prediction errors arise from omitted state variables rather than deficiencies in the forecasting model itself.
That immediately tells reviewers
“We’re testing a hypothesis.”

⸻

2. Models A, B, C are excellent
This is probably the most publishable idea.
You are separating three fundamentally different explanations.
Autonomous
↓
Memory
↓
External forcing
Those correspond to
	•	dynamical systems
	•	delay systems
	•	forced systems
That is an extremely clean hierarchy.
I would actually make it the centerpiece of the paper.

⸻

3. The “Coordinate Closure” terminology is very good
I’d capitalize it consistently.
Coordinate Closure
becomes a formal concept.
Define it once.
For example
Coordinate Closure is achieved when the evolution of the reduced coordinates is Markovian within observational uncertainty.
Now reviewers know exactly what it means.

⸻

4. The Brittle vs Rubbery terminology is risky
Scientifically it’s intuitive.
Reviewers, however, often dislike adjectives.
I’d instead define objective geometric quantities.
Instead of
Brittle manifold
say
high-curvature fold
Instead of
Rubbery manifold
say
low-curvature fold
Then, afterwards, you can say
These correspond intuitively to “brittle” and “rubbery” transition geometries.
Now the analogy becomes secondary.

⸻

5. The comparative table is very strong
I like it.
But one row worries me.
You write
Dominant Scaling
Non-local / Decoupled: Violation of MOST
That is stronger than your evidence.
You have shown
MOST performs poorly.
You have not shown
MOST is violated.
Those are different.
I would say
Local similarity assumptions become increasingly inaccurate.
Much harder to attack.

⸻

6. η₃ is probably the paper
I think Section 3 should become Section 2.
Everything revolves around η₃.
It is your strongest empirical observation.
Namely
vertical synchronization
That is something people can immediately test.
It doesn’t require accepting catastrophe theory.
It doesn’t require accepting POD.
It doesn’t require SINDy.
It only requires looking at observations.
That makes it excellent evidence.

⸻

7. “Global proof” is too strong
You write
η₃ provides empirical proof
I’d soften this.
Instead
provides evidence
or
strongly supports
or
is consistent with
Reviewers love attacking words like “proof.”

⸻

8. External forcing vector
Very good.
But define the philosophy.
Right now it sounds like
“Here are four forcing variables.”
Instead say
External forcing variables are introduced only if Coordinate Closure fails.
That is much deeper.
The logic becomes
	1.	test autonomous system
	2.	if impossible
	3.	identify missing forcing
That’s elegant.

⸻

9. WSINDy + SINDy-BVP
This section currently feels detached.
Ask yourself
Why is this here?
The answer should be
Because
once Coordinate Closure is established,
we must identify
the governing operator.
That connects everything.
Currently it reads like
“Here are two cool numerical methods.”
Instead,
tell the story.

⸻

10. The Sturm–Liouville section needs justification
Right now reviewers will ask
Why Sturm–Liouville?
Instead explain.
Something like
Diffusion operators in boundary-layer turbulence naturally take self-adjoint Sturm–Liouville form after vertical discretization.
Now it sounds physically motivated rather than mathematically fashionable.

⸻

11. Markovian fallback
This is an engineering detail.
I would move it to an appendix.
It interrupts the conceptual flow.
Reviewers interested in methodology will appreciate it there.
Everyone else will skip it.

⸻

12. Orbital Stall
I love the idea.
But you need evidence.
Right now
Orbital Stall
appears as a new physical phenomenon.
The paper needs plots.
Lots of them.
For example
before
during
after
collapse.
Show Ω going to zero.
Without those figures reviewers will say
Why should I believe this?

⸻

13. The supervisor function is probably Paper 2
Personally I’d separate this.
Current paper:
Evidence hierarchy
↓
coordinate closure
↓
topology
↓
η₃
↓
Orbital Stall
Second paper
↓
SCM implementation
↓
Supervisor
↓
climate simulations
Otherwise reviewers will feel
the paper is trying to solve everything.

⸻

14. Biggest conceptual issue
The paper sometimes jumps
Observation
↓
Theory
↓
Operational climate model
without stopping.
Instead I would enforce a strict hierarchy.
Observation
↓
Coordinate Closure
↓
Geometry
↓
Dynamics
↓
Operator discovery
↓
Forecasting
↓
Climate parameterization
That sequence is almost impossible to criticize.

⸻

15. One missing section
I think the manuscript desperately needs
Evidence hierarchy
Something like
Level 1
Observed manifold geometry
↓
Level 2
Cross-site reproducibility
↓
Level 3
Coordinate Closure
↓
Level 4
Autonomous dynamics
↓
Level 5
Operator discovery
↓
Level 6
Operational closure
That tells reviewers exactly what has been demonstrated and what remains to be established.

⸻

Biggest recommendation
Ironically, I think your manuscript is too ambitious.
It contains enough material for three high-quality papers:
	1.	Observational geometry
	•	POD manifold
	•	η₃
	•	cross-campaign topology
	•	brittle vs. low-curvature (“rubbery”) folds
	•	Orbital Stall diagnostic
	2.	Dynamical systems
	•	Coordinate Closure
	•	Models A/B/C
	•	Markovian testing
	•	delay embeddings
	•	external forcing
	•	WSINDy operator discovery
	3.	Operational modeling
	•	Geometric Supervisor Function
	•	SCM integration
	•	EnKF
	•	climate model regularization
	•	runaway cooling mitigation
Keeping all three in one manuscript risks diluting the central scientific contribution. Focusing the first paper on establishing the observational manifold and the coordinate-closure hypothesis would give reviewers a much clearer target and provide a stronger foundation for the subsequent dynamical and operational developments.
