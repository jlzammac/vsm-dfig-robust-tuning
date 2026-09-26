# Table 6 — Achieved loop margins at both grid-strength endpoints

**Section 5.2** · what the design realises, against what Table 3 and Table 5
specify.

**Status: `verified`.** Executed from a clean clone on 2026-09-25. All 28
phase margins at both endpoints reproduce the published values to the two
decimals printed.

---

## Specified against realised

Table 5 lists what was **asked for**. This table lists what the coordinated
design **delivered**, at `SCR = 1` and `SCR = 3`. The two differ, and the
difference is the subject of Section 5.2.

## Procedure

No sweep and no simulation. Both designs, both endpoints, from the saved designs:

```matlab
run ANALYSIS/TABLE6_ENDPOINT_MARGINS.m    % a few minutes
```

For each design — baseline `LIN_MODEL_FRD_OPT`, optimised
`LIN_MODEL_VI_OPT_BIOBJ` — the design is held fixed and the plant is
re-linearised at `SCR = 1` and at `SCR = 3`, with `P = 0.8` pu and
`V_pcc = 0.975` pu unchanged. Each loop is then measured with its own set-point
weight forced to 1 (one degree of freedom), one loop at a time, by
`ANALYSIS/LOOP_MARGINS.m`. The script compares its `SCR = 1` optimised column
against the published one as a control. Output:
`RESULTS/CONTROL/TABLE6_ENDPOINT_MARGINS.txt`.

**Do not read the margins stored in a design file.** `frdMargins` is written by
`CONTROL_DESIGN_FR` while it designs, and nothing refreshes it afterwards:
`LINEAR_ANALYSIS` computes no margins, and Phases 3–5 of the optimisation never
call `CONTROL_DESIGN_FR`. The margins stored in the optimised design are the
ones left by Phase 2, and `RUN_MODE = 1` only carries them through. That is why
this table needs its own script.

## Measured, 2026-09-25

Phase margin in degrees:

| Loop | Baseline `SCR = 1` | Baseline `SCR = 3` | Optimised `SCR = 1` | Optimised `SCR = 3` |
|---|---|---|---|---|
| VSMP | 67.28 | 58.67 | 83.52 | 81.76 |
| VSMQ | 112.94 | 93.59 | 107.68 | 93.24 |
| RSC d | 65.71 | 63.06 | 55.69 | 54.13 |
| RSC q | 65.70 | 63.56 | 65.22 | 63.88 |
| VDC | 65.50 | 65.08 | 57.24 | 56.35 |
| GSC d | 65.70 | 64.10 | 60.14 | 58.59 |
| GSC q | 65.70 | 64.41 | 58.61 | 57.53 |

Control against the published optimised column at `SCR = 1`: largest difference
0.0031°.

## What to expect

**Five of six specified loops land slightly below target.** Section 5.2 reads
that as an interaction penalty rather than scatter, and is careful with the
evidence:

- Against a null in which each loop is equally likely to overshoot or
  undershoot, five of six in one direction carries a two-sided sign-test
  probability of `14/64 ≈ 0.22`. **The pattern alone does not exclude chance.**
- What supports the reading is the mechanism: the optimiser explores
  specification sets whose loop bandwidths are further apart than the
  baseline's, and the wider that separation, the less of each requested response
  a single coordinated design can simultaneously deliver.

**The load-bearing statement is the bound, not the pattern:**

```
every realised phase margin within 4.8° of target
no loop below 55°
all six specified loops inside [50°, 90°]
```

Those three are what the feasibility claim rests on. Check them first.

Deviations by loop, from Section 5.2: the VSM active-power loop by 1.38°, the
RSC q-axis and DC-link loops by about 1° each, the GSC d-axis loop by 0.26°. The
RSC d-axis loop alone **exceeds** its specification, by +3.09° and +5.6 % in
margin and crossover.

## The endpoint comparison, which is the point of the table

Every loop of both designs loses margin as the grid stiffens, because a smaller
network impedance raises loop gain. **What separates the designs is how much.**

| | Movement across endpoints |
|---|---|
| Baseline, VSM active power | **8.61°**, from 67.28° to 58.67° |
| Optimised, worst loop | **at most 1.76°** |

All six specified loops of the optimised design stay inside `[50°, 90°]` at
`SCR = 3`, the smallest being the RSC d-axis current loop at 54.13°.

**This is a property the damping constraints do not guarantee.** Constraints (9)
and (10) of Section 4.1.4 bound per-band damping and the rightmost real
eigenvalue; they imply nothing about a loop margin. That feasibility at one
endpoint was not purchased by surrendering it at the other had to be
**measured**, and this table is that measurement.

## A related check, elsewhere

Section 5.3.3 reports the same kind of measurement for the DC-link loop
specifically: the specified 58.2° of Table 5 becomes 57.24° at `SCR = 1` and
56.35° at `SCR = 3`, and no specified loop of the optimised design leaves
`[50°, 90°]` at either endpoint. That the reduced DC-link margin remains
adequate does not follow from the eigenvalue constraints either — it is measured
too.

## Six loops, not seven

VSMQ carries no phase-margin specification because the droop structure fixes it.
The feasibility test counts six. See
[`tab03_baseline_specs.md`](tab03_baseline_specs.md).

## Files

| File | Role |
|---|---|
| `ANALYSIS/TABLE6_ENDPOINT_MARGINS.m` | **The procedure.** Both designs, both endpoints |
| `ANALYSIS/LOOP_MARGINS.m` | Margin of each loop from the current linearisation, no redesign |
| `CONTROL/CONTROL_DESIGN_FR.m` | The design procedure; `LOOP_MARGINS` reproduces its margin block |

## See also

[`tab03_baseline_specs.md`](tab03_baseline_specs.md) ·
[`tab05_optimized_params.md`](tab05_optimized_params.md)


---

## Why the optimised design misses its specifications by up to 4.8°

The baseline meets its specifications almost exactly; the optimised design does
not. Measured, the cause is the way the optimised design is obtained, not an
interaction between loops:

- The baseline is designed with **three iterations** of the CFRD procedure
  (`FRD_N_iter = 3`) and one-degree-of-freedom controllers.
- Inside the optimisation each candidate is designed with **a single CFRD
  pass**; later phases change parameters of loops designed in earlier ones —
  the set-point weights in Phases 3 and 4, `L_v` in Phase 5 — without
  redesigning them; and the final design uses **two-degree-of-freedom**
  set-point weights.
- Re-designing all seven loops from the final specifications with
  one-degree-of-freedom controllers, the largest deviation falls from 0.60° to
  0.10°, 0.016°, 0.003° and 0.001° over successive iterations. With the actual
  set-point weights, four loops converge, RSC q stays at about −2° and GSC q
  does not converge.

Force `designOrder = [7 3 4 6 1 2 5]` if you repeat this: the saved optimised
design carries `designOrder = [3 6 2]`, and re-designing with it touches only
those three loops.
