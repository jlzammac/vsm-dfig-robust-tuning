# Running the optimisation from scratch

**Not a paper result.** This is the procedure for someone who wants to re-run the
five-phase optimisation itself rather than reproduce a published number from the
saved designs.

**Status: `verified`.** Phase 1 was run end to end from a clean clone on
2026-09-23 — population built, individuals evaluated across parallel workers,
margin constraint applied, and **the result written to disk**:
`RESULTS/GA_OPTIMIZATION/GAM_PDS_BIOBJ.mat`, its Pareto figure, and
`FIGURES/GA_MULTIOBJECTIVE/PDS/`.
What is *not* claimed is that a fresh run returns the published gains — see
[`sec057_seed_sensitivity.md`](sec057_seed_sensitivity.md), which is the
paper's own measurement of how much the seed moves the answer.

---

## You do not need this to reproduce the paper

Every design the paper reports is versioned in `RESULTS/CONTROL/`. Sections 5
and 6 reproduce in minutes from those files. **Re-running the GA is a 21.5 h
operation that will not return bit-identical gains**, because the algorithm is
stochastic.

Run it if you want to study the method. Do not run it to check a number.

## The distributed settings are NOT the full workflow

This is the thing to catch before starting a 21.5 h job. As shipped:

```matlab
OPT_SEQUENCE = [3 4 5];   % Phases 3-5 only
INIT_STEP    = 1;         % starting from the Phase 1 result
```

That is the **v6 path**, which deliberately skips Phase 2 (QDS) and starts from
the stored PDS design. It is what produced the published design, and it is not a
five-phase run.

For the complete workflow from the baseline:

```matlab
RUN_MODE     = 3;           % GA optimisation
CONTROL_TYPE = 2;           % start from the CFRD baseline
OPT_SEQUENCE = [1 2 3 4 5];
INIT_STEP    = 0;           % start from the FRD baseline design
```

`INIT_STEP = 0` also creates `RESULTS/CONTROL/LIN_MODEL_FRD_OPT.mat` — the
CFRD baseline re-designed at the optimisation operating point — if it is not
already there. It is shipped, so that step is a no-op on a clean clone.

## One phase per session is the recommendation, and it is a good one

The file's own banner says so. Each phase inherits from the previous:

| Phase | `OPT_SEQUENCE` | `INIT_STEP` | Inherits from |
|---|---|---|---|
| 1 PDS | `[1]` | 0 | the CFRD baseline |
| 2 QDS | `[2]` | 1 | the PDS result |
| 3 PCP | `[3]` | 2 | the QDS result |
| 4 QCP | `[4]` | 3 | the PCP result |
| 5 VI | `[5]` | 4 | the QCP result |

Phases later in an `OPT_SEQUENCE` always inherit from the previous entry in that
sequence, so `INIT_STEP` only sets the starting point of the **first** one.

**Note the published path is `[3 4 5]` from `INIT_STEP = 1`, i.e. Phase 3
inherits from Phase 1, not Phase 2.** If you reproduce Table 8 and read the
chain as 1→2→3, its Phase 3 numbers will look wrong. See
[`tab08_phase_progression.md`](tab08_phase_progression.md).

## Budget

```matlab
GA_OPTIMIZATION_PopulationSize = 80;
GA_OPTIMIZATION_maxTime        = 5;    % hours, per phase
GA_OPTIMIZATION_numWorkers     = 4;
```

Each phase stops at 25 generations **or** 5 hours, whichever comes first.
Section 5.1 reports Phases 1 and 2 hitting the wall-clock limit rather than the
generation count, so the 2000-evaluation cap is a cap and not a spend.

Four workers is the documented optimum for a population of 80.

## What a running phase looks like

```
PDS | LB|Gen 1/25 | Ind 1/6 | SEQ | S=1 | fval=[7.88e+03 7.69e+02]
PDS | LB|Gen 1/25 | Ind 3/6 | W3  | S=0 | fval=[1.00e+06 1.00e+06]
```

`S=1` is a feasible individual with a real fitness pair. `S=0` with
`fval = [1e6 1e6]` is the **penalty**, and in generation 1 most individuals get
it — random designs usually violate the `[50°, 90°]` phase-margin window of
Section 4.1.4.

**A screen full of `1e6` early on is the constraint working, not a failure.**

### Telling a rejection from a crash

They look identical on screen, because `fprintf` does not reach the client from
inside a `parfor`. The code writes worker exceptions to a file instead:

```
/tmp/ga_worker_errors.log
```

**If that file does not exist, there were no errors** and every `1e6` is a
genuine constraint rejection. If it does exist, read it: the entries carry the
worker id, the message and the failing function.

That distinction is worth knowing before you conclude a 21.5 h run produced
nothing.

## ⚠ The GA OVERWRITES the published designs. Protect them first.

**Measured.** A five-minute smoke run of Phase 1 replaced
`RESULTS/CONTROL/LIN_MODEL_PDS_OPT_BIOBJ.mat`:

```
shipped     ce8e5a14012dd00e073b893c5d9bd5c6
after       70e5edfa53c76d04cde232f5c66076d1
```

Those files are the reference every published number is checked against. A run
you started to see how the GA works will silently destroy them, and a later
`verified` check will then compare against your run instead of against the
paper.

**Before starting anything:**

```bash
git status RESULTS/CONTROL          # confirm clean
```

**After, to get the published designs back:**

```bash
git checkout RESULTS/CONTROL
```

They are versioned precisely so this is a one-line recovery. Work in a scratch
clone if you would rather not think about it:

```bash
git clone <url> ga-experiment && cd ga-experiment
```

`LIN_MODEL_FRD_OPT.mat` is **not** overwritten — `INIT_STEP = 0` only creates it
when absent, and it is shipped.

## Where the output goes

`RESULTS/CONTROL/LIN_MODEL_<PHASE>_OPT_<VARIANT>.mat`, where `<VARIANT>` is
`BIOBJ`, `HYBRID` or `LITAE` depending on the fitness. **Every design in the
paper is `BIOBJ`.**

That suffix is load-bearing: `CONTROL_TYPE = 3…7` ask for the plain
`LIN_MODEL_<PHASE>_OPT.mat`, and the loader resolves the variant when the plain
name is absent. If you run with a non-default fitness and then select
`CONTROL_TYPE = 7`, check which file it resolved — it prints the resolution.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/CONFIG_POWER_SYSTEM.m` | `RUN_MODE = 3` and every setting above |
| `OPTIMIZATION/SEQUENCE/OPT_CD_SEQ.m` | The phase sequence |
| `OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m` | Bounds, encoding, fitness, constraints |
| `OPTIMIZATION/GA_MULTIOBJECTIVE/GEN_LIN_MODEL_PARETO.m` | Front extraction |

## See also

[`fig08_optimization_workflow.md`](fig08_optimization_workflow.md) — what the
five phases are and what each contributes ·
[`tab04_optimization_bounds.md`](tab04_optimization_bounds.md) — the decision
variables and their bounds ·
[`sec057_seed_sensitivity.md`](sec057_seed_sensitivity.md) — how much a fresh
run can differ
