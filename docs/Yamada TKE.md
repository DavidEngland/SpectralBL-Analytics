The 1.5-order turbulence closure based on **Yamada (1983)** is an atmospheric boundary layer parameterization. It models eddy diffusivities using a prognostic equation for **Turbulent Kinetic Energy (TKE)** and diagnostic **master length scales**, determining momentum and scalar mixing directly from local vertical gradients and stability.

### Core Framework
The Yamada (1983) scheme—an extension of the classic **Mellor and Yamada (1974, 1982)** hierarchy—computes vertical turbulent fluxes using gradient-diffusion (K-theory):
- For momentum: $\overline{u'w'} = -K_m \frac{\partial U}{\partial z}$ and $\overline{v'w'} = -K_m \frac{\partial V}{\partial z}$
- For scalars (potential temperature/humidity): $\overline{w'\theta'} = -K_h \frac{\partial \Theta}{\partial z}$

The eddy diffusion coefficients $K_m$ and $K_h$ are defined as:
$$K_m = l q S_m$$
$$K_h = l q S_h$$

Where:
* $l$ is the turbulent master length scale.
* $q = \sqrt{2 \times \text{TKE}}$ is the turbulent velocity scale (with $\text{TKE} = \frac{1}{2}(u'^2 + v'^2 + w'^2)$).
* $S_m$ and $S_h$ are stability functions that depend on local vertical wind shear and buoyancy.

### Prognostic Equation for TKE
Instead of diagnosing turbulence directly from the mean state (like zero- or first-order schemes), the 1.5-order approach evaluates TKE explicitly by solving the prognostic transport equation:
$$\frac{\partial (\text{TKE})}{\partial t} = \frac{\partial}{\partial z} \left( K_q \frac{\partial (\text{TKE})}{\partial z} \right) + \mathcal{P}_s + \mathcal{P}_b - \varepsilon$$

Where:
* $\mathcal{P}_s = K_m \left[ \left(\frac{\partial U}{\partial z}\right)^2 + \left(\frac{\partial V}{\partial z}\right)^2 \right]$ represents shear production.
* $\mathcal{P}_b = -\frac{g}{\overline{\theta_v}} K_h \frac{\partial \overline{\theta_v}}{\partial z}$ is the buoyancy production/destruction (where $\theta_v$ is virtual potential temperature).
* $\varepsilon$ is the TKE dissipation rate, typically parameterized as $\varepsilon = \frac{q^3}{B_1 l}$ ($B_1$ being an empirical closure constant).

### Stability Functions ($S_m$, $S_h$)
Yamada (1983) formulates the stability functions by retaining the algebraic simplifications of the second-moment Reynolds stress equations, factoring in the **gradient Richardson number** ($Ri$):
$$Ri = \frac{\frac{g}{\overline{\theta_v}} \frac{\partial \overline{\theta_v}}{\partial z}}{\left(\frac{\partial U}{\partial z}\right)^2 + \left(\frac{\partial V}{\partial z}\right)^2}$$

Under highly stable or convective conditions, Yamada's parameterization evaluates the coefficients non-linearly to prevent numerical singularities, modifying the turbulent exchange compared to older Level 2.0 schemes.

### Applications and Limitations
- **Used extensively** in mesoscale modeling (e.g., in atmospheric models like **LMDZ** and various WRF boundary layer parameterizations like **MYNN**) to simulate diurnal atmospheric boundary layer cycles.
- **Limitation**: Like many local K-gradient schemes, it can artificially suppress mixing in heavily convective boundary layers where large eddies drive non-local, counter-gradient transport.

---

\subsection{Geometric regularization of local turbulence closures}

The structural limitations of classical 1.5-order closures—such as the \citet{yamada1983} scheme—stem from their strict dependence on the local gradient Richardson number $\Rig$. Once stratification becomes supercritical ($\Rig > \Ric$), the traditional algebraic stability functions $S_m(\Rig)$ and $S_h(\Rig)$ collapse monotonically toward an artificial zero or a negligible residual value. This diagnostic blindness forces the prognostic transport equation for Turbulent Kinetic Energy (TKE) into a permanent, premature decay state, as local shear production $\mathcal{P}_s$ is decoupled from the column's macroscale evolution.

To overcome this localized breakdown without discarding the underlying $K$-theory architecture, we introduce a non-local geometric scaling operator $\Phi$ constructed from the continuous manifold coordinates. Because the higher-order vertical structural curvature mode $\eta_3$ remains dynamically active past local saturation thresholds—registering the non-local profile warping and low-level jet acceleration that act as the structural shadow of the imminent fold—we regularize Yamada's local stability functions via a composite scaling formulation:
\begin{equation}
\widetilde{S}_{m,h} = S_{m,h}(\Rig) \cdot \Phi(\eta_3, \kappa_f),
\end{equation}
where the geometric supervisor function $\Phi$ is defined as:
\begin{equation}
\Phi(\eta_3, \kappa_f) = 1 + \beta_1 \cdot \exp\left( -\frac{\eta_3^2}{\sigma_\eta^2} \right) \cdot \left[ 1 - \tanh\left( \beta_2 \, \kappa_f \right) \right]^{-1}.
\end{equation}
Here, $\beta_1$ and $\beta_2$ are campaign-specific empirical constants, $\sigma_\eta$ represents a characteristic modal variance scale, and $\kappa_f = |d^2\eta_3/d\eta_1^2|$ is the fold-proximal curvature indicator.

Physically, when the boundary layer resides on the flat, resilient portions of the coupled sheet, $\kappa_f \to 0$ and $\eta_3$ variations remain small, reducing $\Phi \to 1$ and returning control to Yamada's local gradient physics. However, as the trajectory approaches a critical topological cliff, the rapid inflation of global curvature $\eta_3$ and the sharp spikes in fold proximity $\kappa_f$ mathematically scale the stability functions upward. This non-local regularization dynamically sustains a baseline level of turbulent exchange proportional to the integrated stress accumulation of the entire column. By using the unfolded manifold coordinates to supervise the local closure, the parameterized ABL is prevented from undergoing numerical flickering or premature collapse, preserving the continuous, intermittent orbital dynamics observed across the field campaigns.


