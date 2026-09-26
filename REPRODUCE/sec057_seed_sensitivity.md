# Section 5.7 — Sensitivity to the solver seed

**Section 5.7** · the workflow repeated end to end at five seeds. No figure, no
table.

**Status: `verified`** from the five seed runs' own outputs, which this
repository ships. Every number in Section 5.7 comes out of
`ANALYSIS/SEED_STUDY_SUMMARY.m` exactly (executed 2026-09-26). Re-running the
five workflows themselves is the expensive part — 35 GA runs, about 3 h per
seed — and has not been repeated here.

## Check the published numbers (seconds)

```matlab
SEED_STUDY_SUMMARY      % ANALYSIS/, reads RESULTS/SEED_STUDY/seed<k>_final_front.mat
```

Each file is the Pareto front returned by the last GA run (Phase 5) of one
seed. Every front is degenerate — all members share the same objective values
and the same 20 effective parameters — so its first member represents it.

---

## Why this is in the paper at all

It is the paper's own declaration of reproducibility exposure, and the Abstract
sells it as one of three qualifying results. A reader who checks the Abstract's
claims arrives here, so it needs a procedure.

## What was varied, and what was not

The whole workflow — **all seven GA runs** — repeated at five independent seeds,
with everything held fixed except the solver seed **and the evaluation budget**.

**The fitness is deterministic**, so the spread that results is the variability
of the *solver*, with no simulation noise in it. That is what makes the number
interpretable at all.

## The reduced budget, which everything below is conditioned on

| | Population | Generation cap | Evaluations per phase-run |
|---|---|---|---|
| Seed study | 20 | 10 | **200** |
| Published design | 80 | 25 | cap of 2000 |

**The tenfold budget ratio is an upper bound on the ratio of effort, not a
measurement of it**, because the published 2000 is a cap that Phases 1 and 2
never reach — they are stopped by the wall-clock limit first.

## Re-running the study (hours)

```matlab
cd CONFIGURATION
% RUN_MODE = 3, CONTROL_TYPE = 2, OPT_SEQUENCE = [1 2 3 4 5]
% population 20, generation cap 10, one run per seed
```

Seven GA runs per seed — the five phases with the P–Q cycle iterated twice —
times five seeds.

## Expected result

| Seed | `J1` | `J2` |
|---|---|---|
| 1 | 0.8095 | 0.8578 |
| 2 | **0.7607** | **0.6155** |
| 3 | 0.8427 | 0.8672 |
| 4 | 0.8314 | 0.8406 |
| 5 | 0.7806 | 0.7032 |

Taking the range as a percentage of the smallest value:

> **`J1` varies by 10.8 %, `J2` by 40.9 %.**
> Between any two seeds, **13 to 17 of the 20 design parameters differ.**

## The finding that was not anticipated

Section 5.5 identifies certain parameters as *free* — a front can vary them at
no objective cost. Those parameters do move across seeds:

| Parameter | Across the five seeds |
|---|---|
| `b_VDC` | 0.85, 1.00, 1.02, 1.13, 1.18 |
| `b_GSCd` | **1.00 in all five**, although free by the same test, and although the published design uses 0.65 |

**The freedom a front exposes and the freedom a seed exercises are not the same
set.** That is reported because it was not expected, and it is the part of this
subsection most worth reproducing: it is a statement about how the search
behaves, not about the design.

The `b_VDC` spread is the one with physical consequence, and `b_VDC` is a parameter Section 5.3 shows
matters.

## The comparison the paper makes pre-emptively

**Seed 2 reaches `J1 = 0.7607` and `J2 = 0.6155`, both below the published 0.764
and 0.650**, at one tenth of the budget.

That run has not converged either, **so it does not establish a better design.**
What it establishes is that the published point is **not a unique attractor of
the search** — which is the sharpest available statement of the exposure this
subsection exists to declare, and the reason it is reported rather than left for
a reader to find.

---

## The qualification matters as much as the number

**At this budget no seed converges.** Every run exhausts its evaluations at
generation 9 of 10.

**These figures measure seed variability at the reduced budget only.**

It is tempting to read them as an upper bound on the spread at the published
budget, on the ground that unconverged runs lie further apart than converged
ones would. **Nothing here establishes that**, and the paper does not claim it.
Seeds may improve by different amounts with more budget.

So if you quote ±10.8 % and ±40.9 %, quote the budget with them. Detached from
the budget they are not a property of the method.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/CONFIG_POWER_SYSTEM.m` | `RUN_MODE`, `OPT_SEQUENCE`, GA settings |
| `OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m` | Population, generation cap, seeding |
| `OPTIMIZATION/SEQUENCE/OPT_CD_SEQ.m` | The seven-run sequence |

## See also

[`tab08_phase_progression.md`](tab08_phase_progression.md) — the published
descent chain these seeds are compared against ·
[`fig08_optimization_workflow.md`](fig08_optimization_workflow.md) — the
published budget
