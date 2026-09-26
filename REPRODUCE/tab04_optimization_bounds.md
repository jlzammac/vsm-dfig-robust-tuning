# Table 4 — Optimisation bounds for the decision variables

**Section 4.1.2** · the box the genetic algorithm searches in.

**Status: `verified`.** Bounds read from the source; the integer encoding and
its consequence checked against the optimiser.

---

## Where the numbers live

[`OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m`](../OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m),
around line 406. There is no script to run: these are inputs.

## The bounds

| Group | Variable | Lower | Upper |
|---|---|---|---|
| Frequency-domain | `φ_m`, all loops | 50° | 90° |
| | `ω_o` VSMP | 5 rad/s | 25 rad/s |
| | `ω_o` VSMQ | 0.1 rad/s | 2.0 rad/s |
| | `ω_o` RSCd/q | 500 rad/s | 2500 rad/s |
| | `ω_o` VDC | 50 rad/s | 300 rad/s |
| | `ω_o` GSCd/q | 500 rad/s | 2500 rad/s |
| 2-DOF and damping | `D_d`-on-error flag | 0 | 1 |
| | `b`, all loops | 0.5 | 1.5 |
| Virtual impedance | `L_v` | 0 pu | 0.15 pu |

The virtual resistance `R_v` is fixed at 0 and is not a decision variable:
`OPTIMIZER.m` pins its slot with `lb = ub = 0`. That leaves 20 decision
variables.

## The phase-margin bound is the feasibility test

`[50°, 90°]` is not a comfort margin around the baseline. It is the same
interval the feasibility test of Section 4.1.4 uses: a candidate is admissible
when **all six phase-margin-specified loops** realise a margin inside it. The
bound and the constraint are the same number, so a candidate cannot be
in-bounds and infeasible on margin at the same time.

Six loops, not seven: VSMQ carries no phase-margin specification because the
droop structure fixes it. See
[`tab03_baseline_specs.md`](tab03_baseline_specs.md).

## Everything is encoded as an integer, and that has a visible consequence

Decision variables are integers within these bounds, to make the GA efficient
while keeping the search space physically meaningful. Phase margins are carried
as tenths of a degree — `500` to `900` for 50° to 90°, per the comment at
`OPTIMIZER.m:271`.

**This is why the damping constraints carry a 0.99 factor.** Section 4.1.4
requires

```
ζ_min,b(x) ≥ 0.99 · ζ_min,b(baseline)      b ∈ {LF, MF, HF}
Re(λ_real)_min(x) ≥ 0.99 · Re(λ_real)_min(baseline)
```

The 0.99 absorbs the micro-perturbation the integer encode–decode introduces,
while still rejecting genuine eigenvalue degradation. Remove it and the
baseline itself can fail its own constraint on a rounding difference.

## Bounds are enforced by the solver, not by clamping

Two comments in the source say so explicitly — `OPTIMIZER.m:258` and `:382`:
*"No clamping — bounds are enforced by lb/ub in GA, not here."*

If you add clamping you will change the search, because `gamultiobj` treats a
clamped value as a distinct candidate from a rejected one.

## Two modes that move the bounds at run time

**Refinement.** With `refinementConfig.enabled = true` the bounds tighten to ±
a factor of the current design (`OPTIMIZER.m:426–438`). The table above is the
full-range search; a refinement run searches a box around an incumbent and its
results are not comparable to a full-range run.

**Re-optimisation.** With `newPopulation = false` the bounds are widened if
necessary so they include the current parameter values (`OPTIMIZER.m:451`). A
re-optimisation can therefore search outside this table.

Both are off for the published results. If you are reproducing Table 5, leave
them off.

## What the search found inside this box

Worth reading against Table 5. The optimiser did not push to the bounds: the
VSMP phase margin settles at 84.9° against a 90° ceiling, its crossover at
5.90 rad/s against a 5 rad/s floor. Only `L_v` sits near its starting value rather than
at an extreme.

A solution pinned to a bound would mean the box is the binding constraint rather
than the plant. None is.

## Files

| File | Role |
|---|---|
| `OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m` | Bounds, integer encoding, solver call |
| `CONFIGURATION/CONFIG_POWER_SYSTEM.m` | `OPT_SEQUENCE`, `RUN_MODE = 3` |

## See also

[`tab05_optimized_params.md`](tab05_optimized_params.md) — what the search
returned · [`tab08_phase_progression.md`](tab08_phase_progression.md) — what
each phase contributed.
