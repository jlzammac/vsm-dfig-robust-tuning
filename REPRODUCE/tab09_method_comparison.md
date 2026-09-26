# Table 9 — Comparison of three tuning approaches

**Section 5.6** · the coordinated design, the five-phase GA, and a VSM
power-loop tuning rule of the class standard in the grid-forming literature.

**Status: `verified`.** The rule sweep was executed from a clean clone on
2026-09-23 at the optimisation operating point. Measurements below.

---

## The three approaches

| Approach | What it tunes | Everything else |
|---|---|---|
| Coordinated frequency-response design [16] | all loops, at one operating point | — |
| Five-phase GA, this paper | specifications for all loops | — |
| VSM power-loop rule | `H` and `D_d` only, against a target damping ratio for the power loop | **left at the baseline design** |

**"Its own scope" means `H` and `D_d`.** The rule is not a whole-plant method
and is not applied as one: the inner current, DC-link and reactive loops keep
the gains of the CFRD baseline of Section 2.5. That is what "their existing
design" refers to.

## Common footing

All three are evaluated on the **same** four-machine model, at the **same**
operating point — `P = 0.8` pu per DFIG, `V_pcc = 0.975` pu, `SCR = 1` — and
through the **same** feasibility test: each of the six phase-margin-specified
loops must realise a margin inside `[50°, 90°]`.

Without all three being the same, the comparison means nothing.

## Cost is in fitness evaluations, not wall-clock

One evaluation is a complete design-and-linearisation pass on the four-machine
model.

Wall-clock time depends on the processor, the number of parallel workers and the
MATLAB release — none of which are properties of the method. Fitness evaluations
are, and the three methods differ by orders of magnitude in that unit.

## The result is a null result, and it is the useful part

The power-loop rule produces **no admissible design on this plant**. Both
branches of its sweep fail, and they fail differently:

| Branch | `H` swept over | `ζ` of the VSM power-loop mode | vs the 0.707 target |
|---|---|---|---|
| baseline `D_d` retained | `[0.1, 100]` s | 0.0285 – 0.0289 | misses by a factor of 24 |
| `D_d = 0` | `[0.1, 100]` s | 0.0113 – 0.0289, a factor of 2.56 | misses by more |

- With the baseline `D_d` retained, three orders of magnitude in `H` move the
  target quantity in its **fourth decimal**. No value on the grid is
  meaningfully distinguishable from any other.
- On neither branch does the virtual inertia have the authority to bring the
  mode near 0.707. The branch a rule of this class actually uses — no lead term,
  `D_d = 0` — is the one on which `H` moves it at all, and even there the range
  tops out at the same 0.0289.

The mode in question is the least-damped low-frequency mode, at **17.6 rad/s**.

**And the designs the rule produces fail the feasibility test outright**, which
is the cleaner statement of the same failure:

| Design | VSM active-power loop phase margin | The 50° floor |
|---|---|---|
| `D_d = 0` | 16.73° | fails |
| baseline `D_d`, `H` moved | 29.92° | fails |

Every other design in this paper satisfies that floor.

**The mechanism.** The lead action of `D_d` is what supplies phase at the
crossover, so a rule that sets it from a damping target alone is structurally
incompatible with a specification expressed in phase margin. The two are not
alternative parameterisations of the same requirement.

The mode identification is checked rather than assumed: it reproduces the
independently stored damping ratio and natural frequency of that mode to zero
relative error.

## Measured, 2026-09-23

Sweeping `H` over `[0.1, 100]` s on a six-point logarithmic grid, at
`P = 0.8` pu, `V_pcc = 0.975` pu, `SCR = 1`, with everything else held at the
baseline:

| Branch | `ζ` range | Factor | Published |
|---|---|---|---|
| baseline `D_d` retained | **0.0288 – 0.0290** | 1.01 | 0.0285 – 0.0289 |
| `D_d = 0` | **0.0113 – 0.0290** | **2.58** | 0.0113 – 0.0289, factor 2.56 |

The mode comes out at **17.56 rad/s** against a published 17.6, and the target
`ζ = 0.707` is missed by a **factor of 24.4** against a published 24.

The `0.0113` lower bound is exact. The small differences elsewhere are grid
resolution — six points here against whatever grid produced the published
range — not disagreement.

**What the first row shows is the null result itself.** Three orders of
magnitude in `H` move `ζ` by one per cent, in the fourth decimal. There is no
value of `H` on that grid meaningfully different from any other, which is what
"the rule produces no admissible design" means in practice.

On the `D_d = 0` branch `H` does move it — and the movement is at the top of the
range: at `H = 100` s the mode drops to `ζ = 0.0113` at **2.77 rad/s**, having
migrated down in frequency. That is the branch a rule of this class actually
uses, and it moves the mode in the wrong direction.

> **The two phase margins of the next section were not reproduced here.** The
> 16.73° and 29.92° are *realised* margins of the rule's designs;
> `CONTROL_DESIGN.VSMP.frdMargins` returns the *specified* margin, which is
> 67.55° for both branches and is the same at every operating point. Computing
> the realised margin is the same separate calculation Table 6 needs — see
> [`tab06_achieved_margins.md`](tab06_achieved_margins.md).

## A third reason, from the source literature rather than measured here

Rules of this class carry a quantitative validity condition. The neglected term
scales with `δ_n = I_n / I_SC`, the ratio of rated to short-circuit current, and
the condition requires `δ_n ≤ 0.1`.

**At the `SCR = 1` benchmark of this paper `δ_n = 1`** — an order of magnitude
above the value that justifies discarding the term. The weak-grid regime studied
here lies outside the stated validity of the design procedure itself,
independently of how any particular rule of this class is implemented.

## The determinism control

The comparison is exactly reproducible: the same design and the same realised
margins were returned bit-identically by **four independent MATLAB processes**.
Without that control, a null result is indistinguishable from a flaky one.

## Cost, in the unit that is a property of the method

| Method | Fitness evaluations |
|---|---|
| Power-loop rule sweep | 12 |
| Five-phase GA | seven runs of 80 over at most 25 generations — an upper bound of 1.4 × 10⁴ |

Three orders of magnitude apart, which is the comparison worth making. Wall-clock
time is not, for the reason given above.

## What the comparison does not establish

It is evidence about **this benchmark and this class of rule**. It is not a
general ranking of tuning methods, and Section 5.6 says so.

It also does not measure what the optimisation costs relative to other ways of
arriving at a design — that is a separate question. What the like-for-like
comparison establishes is what the optimisation **adds**.

## Procedure

The rule sweep is cheap — 12 evaluations — and is driven from the same
`RUN_MODE = 1` endpoint analysis as Table 6, with `H` and `D_d` swept over the
declared grid while the rest of the design is held at the baseline.

The GA column is Table 5, already versioned here. The CFRD column is
`LIN_MODEL_FRD_DESIGN.mat`.

## Files

| File | Role |
|---|---|
| `RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat` | The coordinated design |
| `RESULTS/CONTROL/LIN_MODEL_VI_OPT_BIOBJ.mat` | The GA design |
| `CONTROL/CONTROL_DESIGN_FR.m` | Margin computation for the feasibility test |

## See also

[`tab05_optimized_params.md`](tab05_optimized_params.md) ·
[`tab08_phase_progression.md`](tab08_phase_progression.md)
