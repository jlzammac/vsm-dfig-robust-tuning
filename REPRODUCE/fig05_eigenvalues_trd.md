# Fig. 5 — Eigenvalues of the design that ignores intra-machine interactions

**Section 3.3** · the TRD design, plotted as damping angle against damped
natural frequency.

**Status: `verified`.** Per-band minima re-derived on 2026-09-23 by
`COMPUTE_PERBAND_DAMPING` over the saved designs: **0.02818 / 0.03554 /
0.25321** against a published 0.0282 / 0.0355 / 0.2532. Exact to every digit
the paper prints.

---

## What the figure shows

The 80 eigenvalues of the linearised four-machine system after a controller
design tuned **loop by loop**, assuming each inner loop is fast and decoupled
enough to be invisible to the loop above. That is the TRD design. Figure 6 shows
the same system after the coordinated design that accounts for the interactions.

Drawn at the **designated** operating point: `P = 0.7` pu per DFIG,
`|v_g| = 1` pu, `SCR = 1`. Note this is specified by the **source** voltage, not
the PCC voltage. See [`00_setup.md`](00_setup.md).

## Reading the axes

`ζ = sin(α)` is the damping coefficient, so `α = 90°` means the eigenvalue is
real. Only the member with `Im(λ) > 0` of each complex-conjugate pair is
plotted.

Bands are delimited by `|Im(λ)|`, the damped natural frequency, **not** by the
modulus `|λ|`:

| Band | Range | Physical content |
|---|---|---|
| LF | `ω ≤ 100` rad/s | Grid-coupled modes, P–Q cross-coupling through the network impedance, slow voltage regulation |
| MF | `100 < ω ≤ 500` rad/s | Swing modes governed by the VSM virtual inertia and the synchronising torque coefficient |
| HF | `500 < ω ≤ 3000` rad/s | Current-loop dynamics interacting with grid impedance and converter filter resonances |

The two delimiters differ by `sqrt(1-ζ²)`, below half a per cent for the lightly
damped modes that govern the constraints of Section 4.1.4. The distinction only
matters for well-damped modes, where it reaches some 12 % at the `ζ ≈ 0.47` of
the HF band.

**The synchronising torque coefficient is the VSM's, not a physical synchronous
machine's.** It is `∂P/∂δ` at the operating point across the network impedance,
`K = V_pcc · V_g · cos δ / X` — the electrical stiffness of the VSM-to-grid
link.

## Spurious modes are excluded, and they are not physical

Eigenvalues with `|Im(λ)| > 3000` rad/s are classified as spurious and dropped.
They are associated with the numerical shunt elements `R_n = 100` pu and
`C_n = 1e-3` pu of Table 1, which exist in the Simulink implementation only to
avoid the series connection of two inductances. They do not represent physical
line characteristics.

If your eigenvalue count differs from the paper's, check this filter before
anything else: it is the difference between 80 eigenvalues and 80 eigenvalues
plus a cloud of numerical artefacts.

Real eigenvalues are tracked separately as aperiodic modes.

## Procedure

In `CONFIGURATION/CONFIG_POWER_SYSTEM.m`:

```matlab
RUN_MODE     = 0;    % single operating point
CONTROL_TYPE = 1;    % TIME-response design — this is the TRD
```

`CONTROL_TYPE = 1`, not 2. Using 2 gives the coordinated design of Figure 6.

Then plot from `LIN_MODEL.eigenvalues`, or load the saved design:

```matlab
load RESULTS/CONTROL/LIN_MODEL_TRD_DESIGN.mat
```

which is versioned in this repository.

## Expected values

The red dot marks the least-damped eigenvalue in each band. Per-band minima at
the designated operating point, from Section 5.3.3:

```
TRD   0.0282 / 0.0355 / 0.2532      (LF / MF / HF)
CFRD  0.0306 / 0.0958 / 0.4719
```

**The gap between those two rows is what accounting for intra-machine
interactions buys.** It is not the benefit of the genetic algorithm — that is a
separate quantity, measured at a different operating point, and Section 5.3.3 is
explicit that the two are reported side by side rather than divided into one
another because they are evaluated at different points.

The largest gain is in the MF band, which is where the swing modes live.

## Files

| File | Role |
|---|---|
| `CONTROL/CONTROL_DESIGN_TR.m` | The time-response design |
| `ANALYSIS/EIGEN_CALC.m` | Eigenvalues, bands, participation factors |
| `ANALYSIS/COMPUTE_PERBAND_DAMPING.m` | Per-band minima |
| `RESULTS/CONTROL/LIN_MODEL_TRD_DESIGN.mat` | Saved TRD design |

## See also

[`fig06_eigenvalues_frd.md`](fig06_eigenvalues_frd.md) — the same system with
the coordinated design · [`fig09_eigenvalues_ga.md`](fig09_eigenvalues_ga.md) —
after optimisation.
