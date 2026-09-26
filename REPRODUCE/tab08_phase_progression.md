# Table 8 — Phase-by-phase fitness and damping progression

**Section 5.5** · what each of the five optimisation phases contributed.

**Status: `verified`.** The whole phase chain re-derived on 2026-09-23 by
`COMPUTE_PERBAND_DAMPING` over the saved designs. Measurements below.

---

## Measured, 2026-09-23

Per-band minimum damping of every stored design, all at the optimisation
operating point (`P = 0.8` pu, `V_pcc = 0.975` pu, `SCR = 1`) except the two
marked:

| Design | Phase | `ζ_LF` | `ζ_MF` | `ζ_HF` |
|---|---|---|---|---|
| `LIN_MODEL_TRD_DESIGN` | — (designated OP) | 0.02818 | 0.03554 | 0.25321 |
| `LIN_MODEL_FRD_DESIGN` | — (designated OP) | 0.03062 | 0.09582 | 0.47192 |
| `LIN_MODEL_FRD_OPT` | baseline | 0.02889 | 0.09589 | 0.47104 |
| `LIN_MODEL_PDS_OPT_BIOBJ` | 1 | 0.02942 | 0.09760 | 0.52100 |
| `LIN_MODEL_QDS_OPT_BIOBJ` | 2 | 0.02941 | 0.10039 | 0.63207 |
| `LIN_MODEL_PCP_OPT_BIOBJ` | 3 | 0.02952 | 0.10081 | 0.52133 |
| `LIN_MODEL_QCP_OPT_BIOBJ` | 4 | 0.02952 | 0.10081 | 0.52133 |
| `LIN_MODEL_VI_OPT_BIOBJ` | 5 | 0.02953 | 0.10068 | 0.52174 |

Like-for-like, baseline → optimised at the same operating point:

| Band | Published | Measured | |
|---|---|---|---|
| LF | 0.0289 → 0.0295, +2.2 % | 0.02889 → 0.02953, **+2.19 %** | ✔ |
| MF | 0.0959 → 0.1007, +5.0 % | 0.09589 → 0.10068, **+5.00 %** | ✔ |
| HF | 0.4710 → 0.5217, +10.8 % | 0.47104 → 0.52174, **+10.76 %** | ✔ |

All three bands reproduce to the digits the paper prints. Measured again on
2026-09-25 from a clean clone.

### The two claims of this file, checked independently

- **Phase 4 returns a bit-identical spectrum.** The census's own provenance
  check reports `LIN_MODEL_QCP_OPT_BIOBJ` and `LIN_MODEL_PCP_OPT_BIOBJ` as
  *"different files but their eigenvalues agree to the last bit"*. Confirmed
  without being looked for.
- **Phase 3 moves `ζ_MF` from 0.0976 to 0.1008.** Measured: Phase 1 gives
  0.09760 and Phase 3 gives 0.10081. Note that Phase 3 inherits from **Phase 1,
  not Phase 2** — `INIT_STEP = 1` in the distributed configuration, which skips
  QDS. Reading the chain as 1→2→3 makes this number look wrong.

### The baseline file

`LIN_MODEL_FRD_OPT.mat` is the CFRD baseline **re-designed** at the optimisation
operating point (`P = 0.8`, `V_pcc = 0.975`, `SCR = 1`), which is how
`CONFIG_POWER_SYSTEM` creates it with `INIT_STEP = 0`. It is the file every row
of the like-for-like table is measured against, and the ITAE normalisation of
the optimiser. It differs from `LIN_MODEL_FRD_DESIGN`, the baseline at the
designated point, in its gains, not only in its operating point.

## Procedure

Every phase's intermediate design is versioned here, so the table can be
assembled without re-running the genetic algorithm:

```matlab
cd CONFIGURATION
GEN_PAPER_V6_FIGURES     % PART A prints the phase-by-phase table data
```

It reads, in order:

```
LIN_MODEL_FRD_DESIGN.mat        baseline
LIN_MODEL_PDS_OPT_BIOBJ.mat     Ph.1  P-controller specifications
LIN_MODEL_QDS_OPT_BIOBJ.mat     Ph.2  Q-controller specifications
LIN_MODEL_PCP_OPT_BIOBJ.mat     Ph.3  2-DOF weights, P group
LIN_MODEL_QCP_OPT_BIOBJ.mat     Ph.4  2-DOF weights, Q group
LIN_MODEL_VI_OPT_BIOBJ.mat      Ph.5  virtual impedance
```

Re-running the whole sequence is 21.5 h measured, on four workers. Individual phases can be re-run
with `OPT_SEQUENCE = [n]` and the matching `INIT_STEP`.

## The distribution is extremely uneven, and that is the finding

```
Phases 1-2, the P-Q cycle:   -23.5 % in J1    -34.8 % in J2
Total, all five phases:      -23.6 %          -35.0 %
```

**More than 99 % of both reductions is bought by the frequency-domain
specifications of the P- and Q-controller groups alone.** Phases 3 to 5
contribute the remainder.

The practical recommendation in Section 5.5 follows from this and not from a
separate optimisation: for plant of this class the P–Q cycle alone is the
workflow worth running. It reaches the design of Table 5 to within 0.1 % in J1
and 0.2 % in J2 while dispensing with three of the seven GA runs. The saving is
in procedure rather than computer time — Phases 3–5 together account for about
1 h of the 21.5 h total.

## Phase 4 returns a bit-identical spectrum, and the reason is instructive

The design Phase 4 returns and the design it inherited from Phase 3 have
closed-loop spectra agreeing **to the last bit**: the maximum difference over
all 80 eigenvalues is exactly zero. Both objectives and all three per-band
minima are unchanged.

Yet the phase **does** move a decision variable — `b_GSCd`, from 1.00 to 0.65 in
Table 5.

The explanation is that the reactive setpoint `Q_gs^sp` that `b_GSCd` scales is
**zero at every machine and every operating point in this paper**. A weight on a
vanishing reference does not enter the state matrix.

## Phase 3 does the opposite, and that one matters

Phase 3 leaves both objectives unchanged to the digits printed, yet moves
`ζ_MF,min` from 0.0976 to 0.1008 — a 3.3 % gain and the larger part of the 5.0 %
total.

Comparing the two saved designs entry by entry, the only difference is the three
setpoint weights `b_RSCq`, `b_VDC` and `b_GSCq`. Their state matrices
nonetheless differ in **506 of 6400 entries**.

**So the 2-DOF weights are not confined to the reference path in this
implementation**, and equation (1) should not be read as implying that they are.
The mechanism is visible in the architecture of Section 2: the RSC current
setpoints are not exogenous variables but are computed from the measured stator
and line currents, the rotor speed and the VSM frequency — so a weight applied
to that reference sits inside a feedback path and enters the linearisation.

Two of the three can be placed by inspection: `u_dc^sp` is exogenous and
constant, so `b_VDC` multiplies a quantity with no dynamics of its own and does
not enter the state matrix at all. The Phase 3 movement is therefore carried by
`b_RSCq` or `b_GSCq`.

**If you reproduce Phase 3 and see no change, check whether your implementation
routes the setpoint weights through the feedback path.** That is the difference
between a 3.3 % MF damping gain and nothing.

## Phase 5 has a single decision variable

Phase 5 is the virtual-impedance phase, and it optimises the virtual inductance
`L_v` alone; the virtual resistance is fixed at 0. See
[`tab05_optimized_params.md`](tab05_optimized_params.md). One variable against
eight in Phase 1 is part of why it contributes least of the five.

## What Section 5.5 says this table does and does not establish

The table should be read as an **ablation of the workflow**, not as a record of
incremental benefit. Section 5.6 measures incremental benefit separately and at
a different operating point.

A related null result is reported alongside: a monolithic single-stage NSGA-II
search over all 20 design variables at the same budget — 80 individuals, 25
generations, one seed — completed 2000 evaluations in 9.4 h and returned its
starting point unchanged. Of the 1999 candidates evaluated alongside the seed,
580 violated the specification outright, two were unstable, and **1417 were
rejected because the gain-crossover solve inside the margin computation did not
converge**. For those 1417 feasibility was never determined, and some may have
been admissible.

That distinction bounds the claim. The experiment establishes that a
single-stage search at that budget did not improve on its starting point. It
does **not** establish how sparsely admissible the 21-dimensional space is,
because for seven of every ten candidates the question went unanswered.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/GEN_PAPER_V6_FIGURES.m` | Prints the table |
| `RESULTS/CONTROL/LIN_MODEL_*_OPT_BIOBJ.mat` | The five intermediates |
| `OPTIMIZATION/SEQUENCE/OPT_CD_SEQ.m` | The phase sequence |

## See also

[`tab05_optimized_params.md`](tab05_optimized_params.md) ·
[`tab09_method_comparison.md`](tab09_method_comparison.md)
