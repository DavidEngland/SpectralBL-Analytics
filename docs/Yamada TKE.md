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
