# Fig. 11 — Step-response comparison at both grid-strength endpoints

**Section 5.4** · unit-step responses of the closed-loop complementary
sensitivity for the four loops with the largest parameter changes.

**Status: `verified`.** Endpoint analysis executed from a clean clone on
2026-09-23 for both designs. The headline reproduces exactly: the VDC crossover
goes **109.9 → 184.0 rad/s, +67.4 %**, and the optimised VDC phase margin is
**58.20°** against the specified 58.2°. Procedure read from the source; prerequisites identified
and costed. Not yet re-executed.

---

## What the figure shows

The unit-step response of `T(s) = G(s)/(1 + G(s))` for VSMP, VDC, RSCd and
GSCd — the four loops whose parameters move most between the baseline and the
optimised design — at `SCR = 1` and `SCR = 3`.

For each endpoint every voltage and power combination is drawn as a thin curve
and the nominal operating point as a thick one, so the spread across the
envelope is visible rather than represented by a single trace.

`G(s)` is the open-loop transfer function; its construction is in reference [16]
of the paper.

## Configuration

**Design configuration.** See [`00_setup.md`](00_setup.md).

Drawn at `P = 0.7` pu per DFIG with a PCC voltage of 1.0 pu, under both
grid-strength endpoints.

## The prerequisite, and it is the expensive part

The figure script loads two saved envelope sweeps from
`RESULTS/LINEAR_ANALYSIS/`:

| Pattern | Design |
|---|---|
| `LINEAR_ANALYSIS_*_SWEEP_FRD_4DFIG.mat` | Baseline CFRD |
| `LINEAR_ANALYSIS_*_SWEEP_VI_OPT_BIOBJ_*.mat` | GA-optimised |

It picks the most recent match of each.

**These are not in this repository and cannot be.** Measured: **1.33 GB each**,
against a 100 MB per-file hard limit on GitHub. They have to be regenerated.

That is why `RESULTS/CONTROL/` is versioned and the rest of `RESULTS/` is not:
the saved control designs are ~1.7 MB each and save a 21.5 h optimisation, while
the sweeps are gigabytes and save a run that is long but bounded.

## Procedure

**Stage 1 — baseline sweep.** In `CONFIGURATION/CONFIG_POWER_SYSTEM.m`:

```matlab
RUN_MODE     = 2;    % linear analysis over the envelope
CONTROL_TYPE = 2;    % CFRD baseline
```

Run it. The result lands in `RESULTS/LINEAR_ANALYSIS/` with `SWEEP_FRD` in the
name.

**Stage 2 — optimised sweep.** Same `RUN_MODE`, with the GA design loaded
instead. The result carries `SWEEP_VI_OPT_BIOBJ`.

**Stage 3 — the figure.**

```matlab
cd CONFIGURATION
GEN_PAPER_FIG_STEP_ENDPOINTS
```

Output: `FIGURES/step_response_comparison.pdf`.

## Cost

Two full 225-point sweeps. Each point runs an `fsolve` per machine, a Simulink
trim and a linearisation. This is the longest procedure in `REPRODUCE/` after
the genetic algorithm itself. Use the parallel path if `parfor` is available:
`CONFIG_POWER_SYSTEM` passes a worker ID through to `LINEAR_ANALYSIS` for that
purpose.

If you only need the figure and not the sweep data, there is no shortcut. The
thin curves *are* the sweep.

## Expected result

Table 7 of the paper reports the step indices this figure shows. The headline
from Section 5.3.3: the VDC bandwidth rises 67.4 %, from 109.9 to 184.0 rad/s,
and the reduced DC-link phase margin remains adequate — 57.24° at `SCR = 1` and
56.35° at `SCR = 3` against a specified 58.2°, with no specified loop leaving
`[50°, 90°]` at either endpoint.

**One thing this figure does not certify.** Section 5.4 is explicit that the
overshoot and settling figures of Table 7 cannot be used to certify panel (a):
that table is computed at the optimisation operating point and this figure is
not — they differ in dispatch and in PCC voltage, and the figure additionally
reports a grid strength the table does not. Do not mix the two sets.

## A property that does not come from the constraints

Both designs converge to the same steady state at each SCR. That follows from
the structure of the design, not from the optimisation: the steady-state droop
of the VSM active-power loop is set by `D_p`, which is not a decision variable
of this study and appears in neither Table 4 nor Table 5. The optimiser cannot
move it. If your two designs settle at different values, something upstream has
changed `D_p`.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/CONFIG_POWER_SYSTEM.m` | The sweeps, `RUN_MODE = 2` |
| `CONFIGURATION/GEN_PAPER_FIG_STEP_ENDPOINTS.m` | Draws the figure |
| `CONFIGURATION/GEN_PAPER_V6_FIGURES.m` | Also emits a step-response figure, from the full sweep rather than the endpoints |

## See also

[`tab07_step_indices.md`](tab07_step_indices.md) — the numerical indices, and
the operating point they are computed at.
