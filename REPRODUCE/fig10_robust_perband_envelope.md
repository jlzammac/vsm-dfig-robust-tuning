# Fig. 10 — Per-band stability envelope, GA-optimised design

**Section 5.4** · minimum damping per frequency band against dispatched power,
at three grid strengths.

**Status: `verified`.** Optimised sweep executed from a clean clone on
2026-09-23. **202 of 225 stable — the same 202 as the baseline**, with the same
per-SCR split (24/45 · 43/45 · 45/45 · 45/45 · 45/45): none gained by the
optimisation and none lost, which is the Section 5.2 claim the Abstract repeats.
Per-band minima at the optimisation point measured **0.02953 / 0.10068 /
0.52174**.

---

## What the figure shows

The same structure as Fig. 7, which carries the baseline, but computed on the
GA-optimised controller sweep. Four panels:

| Panel | Quantity |
|---|---|
| (a) | Aperiodic modes, `min \|Re(λ)\|` over real eigenvalues |
| (b) | LF band, `\|Im(λ)\| ≤ 100` rad/s, minimum damping |
| (c) | MF band, `100 < \|Im(λ)\| ≤ 500` rad/s |
| (d) | HF band, `500 < \|Im(λ)\| ≤ 3000` rad/s |

Each panel plots against dispatched power for `SCR ∈ {1, 2, 3}`, at the PCC
voltage fixed below.

## Configuration

**Design configuration.** No active limiting, no active protection — the model
as distributed. Do not arm the mechanisms: re-linearising the envelope with them
armed moves 72 of the 223 convergent points and flips 51 from stable to unstable. See
[`00_setup.md`](00_setup.md).

**The paper includes `robust_stability_envelope_4_bis_onlyoffice.pdf`, not the
plain `robust_stability_envelope.pdf` sitting beside it.** The plain file uses
a superseded band convention (`LF ≤ 30`, `MF 50–500 rad/s`); the generator here
is the current one and reproduces the published labels. The distinction, and
why the convention change moves no number, is in
[`fig07_baseline_perband_envelope.md`](fig07_baseline_perband_envelope.md) —
this figure is its optimised counterpart and inherits the same point.

## Procedure

Two stages. The sweep is the expensive one.

**Stage 1 — the envelope sweep.** In `CONFIGURATION/CONFIG_POWER_SYSTEM.m`:

```matlab
RUN_MODE     = 2;    % linear analysis over the operational envelope
CONTROL_TYPE = 2;    % then load the GA design, see below
```

The sweep covers the 225 combinations of Section 5.2:

```
V_pcc ∈ {0.95, 0.975, 1.0, 1.025, 1.05} pu
P     ∈ {0.4 … 1.2} pu per DFIG
SCR   ∈ {1, 1.5, 2, 2.5, 3}
```

Two of the 225 do not converge and are counted as inadmissible rather than as
demonstrated instabilities, which is why the stable and not-stable counts
partition the full 225.

**Stage 2 — the figure.**

```matlab
cd CONFIGURATION
GEN_PAPER_FIG7_ROBUST_ENVELOPE
```

Output: `FIGURES/robust_stability_envelope.pdf`, written with `exportgraphics`
in vector form.

## The voltage the figure is drawn at

```matlab
target_vpcc = 0.975;   % GEN_PAPER_FIG7_ROBUST_ENVELOPE.m, line 54
```

`V_pcc = 0.975` pu, the optimisation operating point. Section 3.3 notes that
stability degrades monotonically with decreasing voltage, so this is not the
worst voltage of the envelope — 0.95 pu is. The figure is drawn at the voltage
the optimisation targeted, not at the envelope's worst corner.

**On what `V_pcc` means here.** The PCC is a PV bus: dispatched power and PCC
voltage magnitude are imposed, the Thevenin source is the slack at 1 pu, and the
transmission angle and the reactive power are solved. `|v_g| = 1` pu throughout.
Sweeping `V_pcc` is therefore sweeping a voltage the plant is required to hold,
with the reactive dispatch as the dependent variable — it is not a sweep of
grid-side voltage. See [`00_setup.md`](00_setup.md).

## Prerequisites

`RESULTS/CONTROL/LIN_MODEL_VI_OPT_BIOBJ.mat`, the Phase 5 output of the
bi-objective workflow, which is the design of Table 5. Versioned in this
repository, so the GA does not have to be re-run.

## Cost

The 225-point sweep dominates. It runs `LINEAR_ANALYSIS` once per point:
an `fsolve` per machine, a Simulink trim and a linearisation. Budget accordingly
and prefer the parallel path if `parfor` is available — `CONFIG_POWER_SYSTEM`
takes the worker ID through to `LINEAR_ANALYSIS` for exactly that reason.

## Expected result

From Section 5.4: within the stable region the rightmost eigenvalue sits more
firmly in the left half-plane, LF and HF damping improve at the weak-grid
endpoint, and MF damping rises across all SCR values.

The binary stability map is **identical** to the baseline's (Fig. 3): 23 of the
225 points are not stable, all at `SCR ≤ 1.5` and high power transfer, two of
them being the non-converged points. That identity is the paper's own evidence
that the unstable region is set by the physical transmission capacity of the
network and not by controller tuning — so if your sweep returns a different
count, suspect the sweep before suspecting the design.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/CONFIG_POWER_SYSTEM.m` | The sweep, `RUN_MODE = 2` |
| `CONFIGURATION/GEN_PAPER_FIG7_ROBUST_ENVELOPE.m` | Draws the figure |
| `ANALYSIS/LINEAR_ANALYSIS.m` | Per-point solve and linearisation |
| `ANALYSIS/COMPUTE_PERBAND_DAMPING.m` | Per-band minima |

## See also

[`fig07_baseline_perband_envelope.md`](fig07_baseline_perband_envelope.md) — the
same figure for the baseline, which this one is meant to be read against.
