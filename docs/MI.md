In the computational pipeline, the **Mutual Information (MI)** bits are computed directly from the joint and marginal probability density functions (PDFs) of your empirical data streams—specifically, the continuous vertical column curvature ($\eta_3$) and your chosen near-surface local stability proxy ($\mathrm{Ri}_g$).

Because the relationship between a global manifold fold and a localized gradient trigger is highly non-linear, standard linear correlation coefficients collapse or misrepresent the dynamics. Mutual Information acts as a non-linear metric of statistical dependence, measuring exactly how many **bits of information** about the global column state are locked inside the local sensor measurement.

Here is exactly how those numbers are harvested, calculated, and split within the code.

---

## 🧮 The Mathematical Pipeline

To extract $I(\eta_3; \mathrm{Ri}_g)$, the pipeline performs a non-parametric estimation of the continuous probability distributions:

1. **Kernel Density Estimation (KDE) or Grid Binning:** The pipeline takes the synchronized time series of $\eta_3(t)$ and $\mathrm{Ri}_g(t)$ and constructs a 2D joint probability distribution $p(\eta_3, \mathrm{Ri}_g)$, alongside their individual marginal distributions $p(\eta_3)$ and $p(\mathrm{Ri}_g)$.
2. **The Shannon Entropy Integration:** It then evaluates the expected value of the pointwise mutual information over the data envelope:

$$I(\eta_3; \mathrm{Ri}_g) = \sum_{\eta_3} \sum_{\mathrm{Ri}_g} p(\eta_3, \mathrm{Ri}_g) \log_2 \left( \frac{p(\eta_3, \mathrm{Ri}_g)}{p(\eta_3)p(\mathrm{Ri}_g)} \right)$$

Because the logarithm is base-2 ($\log_2$), the resulting unit is explicitly **bits**.

* A score of **0 bits** means the local gradient and global profile shape are completely independent (pure white noise).
* A high score (like **$1.90\text{ bits}$** in FLOSS or **$1.45\text{ bits}$** in BLLAST) means knowing the local Richardson number eliminates a massive amount of uncertainty regarding where the entire air-column is positioned on the underlying folded manifold.

---

## ✂️ Why the Subcritical vs. Supercritical Split?

The pipeline doesn't just calculate one global MI score; it segments the calculation based on the classical threshold boundary ($\mathrm{Ri}_c = 0.25$). This is where the physical geometry of the manifold sheets becomes visible:

### 1. Subcritical MI ($I_{\le 0.25}$)

This looks at data points where the local boundary layer is still technically coupled ($\mathrm{Ri}_g \le 0.25$).

* **The Physical Meaning:** It measures the strength of the **structural precursor shadow**.
* The high values here ($1.45$ to $1.90\text{ bits}$) prove that as the surface layer cools, the local gradient matches the global warping of the column. They are deforming together as a unified object on the active sheet.

### 2. Supercritical MI ($I_{> 0.25}$)

This looks at data points after the local gradient crosses the critical threshold ($\mathrm{Ri}_g > 0.25$) and enters traditionally laminar or "collapsed" conditions.

* **The Physical Meaning:** This differentiates a **brittle fold** from a **rubbery fold**.
* In **CASES-99**, this returns `NaN` or near-zero because the fold is brittle; the surface layer snaps away instantly, destroying the local-to-global informational link.
* In **FLOSS**, it retains a high score ($1.45\text{ bits}$), proving that the fold is rubbery. Even though local sensors say the air is super-critical and non-turbulent, the local gradients and global column shapes continue to communicate structurally because the trajectory is lingering near the fold edge.

In short, these bits aren't an abstract data-science abstraction—they are an exact physical measurement of how tightly the local "shadow" tracks the multi-dimensional manifold across different environments.