# Fig. 7 — Per-band stability envelope, baseline

**Section 3.3** · minimum damping per frequency band against dispatched power,
at three grid strengths, for the CFRD baseline.

**Status: `verified`.** Same sweep as Figure 3, executed from a clean clone on
2026-09-23. Every value below reproduces; the measurements are tabulated under
*Expected values*.

---

## What the figure shows

Four panels, drawn at `V_pcc = 0.975` pu for `SCR ∈ {1, 2, 3}`:

| Panel | Quantity |
|---|---|
| (a) | Aperiodic modes, `min \|Re(λ)\|` over real eigenvalues |
| (b) | LF band, `\|Im(λ)\| ≤ 100` rad/s, `min ζ` |
| (c) | MF band, `100 < \|Im(λ)\| ≤ 500` rad/s |
| (d) | HF band, `500 < \|Im(λ)\| ≤ 3000` rad/s |

**This is the figure that motivates the whole paper.** Figure 6 certifies the
baseline at one point; this one shows what that certificate is worth across the
envelope.

## Why 0.975 pu and not 0.95

Section 3.3 states that stability degrades monotonically with decreasing
voltage, so the worst voltage of the envelope is 0.95 pu, not 0.975. The figure
is drawn at 0.975 because that is the voltage the optimisation targets — the
optimisation operating point. The choice is deliberate and it is not the
envelope's worst corner.

## Configuration

**Design configuration.** See [`00_setup.md`](00_setup.md).

## Procedure

```matlab
RUN_MODE     = 2;    % envelope sweep
CONTROL_TYPE = 2;    % CFRD baseline
```

Then the figure script. The sweep is the expensive stage: 225 points, each an
`fsolve` per machine plus a Simulink trim and linearisation. The saved sweep is
1.33 GB and cannot be versioned — see
[`fig11_step_response_comparison.md`](fig11_step_response_comparison.md).

## The reading that matters

At `SCR = 1` and `V_pcc = 0.975` the per-band stability curves **terminate at
`P = 0.8` pu**. That is the last stable operating point at that voltage.

Hold that number next to Section 6.3: the only cell of the sixteen-point fault
campaign that loses synchronism is `SCR = 1, P = 0.8` pu, and it does so at both
fault depths including the shallow one.

**Two analyses that share no computational path place the boundary in the same
place.** One is a linearisation and an eigenvalue classification; the other is a
nonlinear time-domain simulation with converter limiters armed. Neither informs
the other. That agreement is the strongest internal evidence in the paper, and
it is reproducible: run this sweep, note where the curves terminate, then run
`b7_campaign` and see which cell fails.

## Three bands and not one aggregate

The constraint of Section 4.1.4 is per band for a reason stated in the
introduction: a single damping figure aggregated over the spectrum can be
improved comfortably in a band that was never at risk while a fragile band is
left untouched. Panel (a) is separate for the same reason — Section 3.3 shows a
**real** eigenvalue triggering the instability at the power-transfer limit, so
the rightmost real eigenvalue is bounded by its own constraint, equation (10),
rather than folded into a damping ratio.

If you reproduce this with an aggregate damping metric you will not see the
effect the paper is about.

## An older version of this figure exists, and it is not this one

The paper folder carries two files with nearly the same name, and the manuscript
includes the second:

| File | Band labels | Included by the paper |
|---|---|---|
| `baseline_perband_stability_envelope.pdf` | LF `ω ≤ 30`, MF `50 < ω < 500` | **no** |
| `baseline_perband_stability_envelope_4_bis_onlyoffice.pdf` | LF `\|ω\| ≤ 100`, MF `100 < \|ω\| ≤ 500` | **yes** |

The first uses a **superseded band convention** and predates the fix. The
generator in this repository is the current one — `BND_LF_MF = 100`, the
`|ω| ≤ 100` titles, the three line styles and the LaTeX typesetting all match
the published figure — so **running it reproduces what the paper shows**, not
the older file.

If you find the older PDF and think the code disagrees with the paper, that is
why.

### The convention change moves no number

Worth knowing before you worry about it. `COMPUTE_PERBAND_DAMPING.m` carries a
self-check for exactly this: **`LF ≤ 30` and `LF ≤ 100` give identical `ζ_min`
in every band, for every model.** The interval `(30, 100]` never holds the
minimum on this plant, so redrawing the boundary changes the labels and not the
data.

That is why the two PDFs above have visibly identical curves and different
titles.

## Expected values

The prose of Section 3.3 quotes these, all at `SCR = 1` and `V_pcc = 0.975` pu:

| Quantity | Published | **Measured 2026-09-23** |
|---|---|---|
| Distance to the boundary at `P = 0.4` pu | 0.028 | **0.0282** |
| Distance to the boundary at `P = 1.2` pu | about 0.010 | **0.0099** (`SCR = 2`), **0.0103** (`SCR = 3`) |
| `ζ_min` at `P = 0.4` pu | 0.036 | **0.03595** |
| `ζ_min` at `P = 0.8` pu | 0.029 | **0.02892** |
| `ζ_min,HF` at the last stable point, `P = 0.8` pu | 0.469 | **0.46938** |

**Panel (a)'s 0.028 → 0.010 is not read along the `SCR = 1` curve**, which
terminates at `P = 0.8`. It is read along `SCR = 2` or `3`, which reach
`P = 1.2`. Measured, `|Re(λ)|` falls 0.0282 · 0.0268 · 0.0250 · 0.0230 · 0.0206
· 0.0182 · 0.0155 · 0.0128 · 0.0099 across `P = 0.4 … 1.2` at `SCR = 2`. The
three curves are nearly coincident in that panel, which is why the figure looks
like one line.

And the `SCR = 1` curve stopping at `P = 0.8` is the result, not a gap in the
data: that is the last stable point.

## The 0.0291 against 0.0289 — read this before concluding something is wrong

At `P = 0.8` pu, `V_pcc = 0.975` pu, `SCR = 1`, the paper reports that **the
sweep gives `ζ_min,LF = 0.0291` while the saved model gives `0.0289`**, and
treats the gap as two linearisation runs not landing on bit-identical states.

**Re-run here, the sweep gives `0.02892`** — which agrees with the saved model
(0.02889) to the fourth decimal, not with the published 0.0291. So the effect is real but it is *run-to-run*, and
this run happens to fall on the saved-model value rather than on the other side.

The practical consequence is the same either way, and is why this section
exists: **a fourth-decimal difference between two linearisations of the same
nominal point is expected and is not a defect.** Do not chase it.

This is the single most likely place for a replicator to conclude the paper
contradicts itself, because each number has its own natural home and neither
home mentions the other: the sweep value belongs to this figure, and 0.0289
belongs to [`tab08_phase_progression.md`](tab08_phase_progression.md) as the
Phase-0 baseline of the descent chain.

**Which to use:** for anything comparing designs, use the saved-model value —
the whole progression in Table 8 is computed that way, and mixing a sweep value
into that chain introduces a difference that is provenance, not physics. For
anything reading the envelope, use the sweep.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/CONFIG_POWER_SYSTEM.m` | The sweep |
| `ANALYSIS/COMPUTE_PERBAND_DAMPING.m` | Per-band minima |
| `CONFIGURATION/GEN_PAPER_FIG7_ROBUST_ENVELOPE.m` | Draws the optimised counterpart |

## See also

[`fig10_robust_perband_envelope.md`](fig10_robust_perband_envelope.md) — the
same figure after optimisation ·
[`tab10_fault_phases.md`](tab10_fault_phases.md) — the nonlinear campaign that
lands on the same corner.
