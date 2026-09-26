# Table 5 — Baseline and GA-optimised design specifications

**Section 5.1** · every decision variable, before and after.

**Status: `verified`.** The optimised values are read from the saved Phase 5
design held in this repository, not transcribed from the paper.

---

## Where the numbers live

Both designs are versioned:

| File | Column |
|---|---|
| `RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat` | Baseline |
| `RESULTS/CONTROL/LIN_MODEL_VI_OPT_BIOBJ.mat` | GA-optimised |

Read them without running anything:

```matlab
B = load('RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat');
G = load('RESULTS/CONTROL/LIN_MODEL_VI_OPT_BIOBJ.mat');
fb = fieldnames(B); fg = fieldnames(G);
disp(B.(fb{1}).CONTROL_DESIGN)
disp(G.(fg{1}).CONTROL_DESIGN)
```

## Re-running the optimisation instead

```matlab
RUN_MODE     = 3;           % GA optimisation
OPT_SEQUENCE = [1 2 3 4 5]; % Phases 1-5
```

**21.5 h measured, on four workers** — that is the figure Section 5.1 reports
and the one to quote. The script's own banner says *"WARNING: ~25h total.
Recommended: one phase per session."*, which is a conservative estimate rather
than a measurement; the two are not in conflict. The phase-by-phase route it
recommends is in the header of `CONFIG_POWER_SYSTEM.m`:

```
Phase 1 (PDS): OPT_SEQUENCE=[1], INIT_STEP=0   uses the CFRD baseline
Phase 2 (QDS): OPT_SEQUENCE=[2], INIT_STEP=1   uses the PDS result
Phase 3 (PCP): OPT_SEQUENCE=[3], INIT_STEP=2
Phase 4 (QCP): OPT_SEQUENCE=[4], INIT_STEP=3
Phase 5 (VI):  OPT_SEQUENCE=[5], INIT_STEP=4
```

Each phase's intermediate design is versioned here, so any phase can be run on
its own without repeating the ones before it.

**A re-run will not return bit-identical gains.** The GA is stochastic.
Section 5.7 measures the spread: J1 varies ±10.8 % and J2 ±40.9 % across seeds
— but measured at one tenth of the published budget, at which **no seed
converges**, so those figures do not transfer to the published budget. If you
need Table 5 exactly, load the saved design.

## The design

| Parameter | Baseline | Optimised | Δ |
|---|---|---|---|
| **VSM outer loops** | | | |
| `φ_m` VSMP | 67.2° | 84.9° | +26.3 % |
| `ω_o` VSMP | 8.07 rad/s | 5.90 rad/s | −26.9 % |
| `H` | 15.59 s | 32.32 s | **+107 %** |
| `D_d` | 0.156 | 0.388 | +148 % |
| `ω_o` VSMQ | 2.00 rad/s | 2.00 rad/s | 0 |
| **Inner loops, d axis** | | | |
| `φ_m` RSCd | 65.7° | 52.6° | −19.9 % |
| `ω_o` RSCd | 2184 rad/s | 1737 rad/s | −20.5 % |
| `b` RSCd | 1.00 | 1.00 | 0 |
| `φ_m` GSCd | 65.7° | 60.4° | −8.1 % |
| `ω_o` GSCd | 2184 rad/s | 2061 rad/s | −5.6 % |
| `b` GSCd | 1.00 | 0.65 | −35.0 % |
| **Inner loops, q axis** | | | |
| `φ_m` RSCq | 65.7° | 66.2° | +0.8 % |
| `ω_o` RSCq | 2184 rad/s | 2352 rad/s | +7.7 % |
| `b` RSCq | 1.00 | 1.01 | +1.0 % |
| `φ_m` GSCq | 65.7° | 63.4° | −3.5 % |
| `ω_o` GSCq | 2184 rad/s | 2352 rad/s | +7.7 % |
| `b` GSCq | 1.00 | 0.97 | −3.0 % |
| **DC link** | | | |
| `φ_m` VDC | 65.5° | 58.2° | −11.1 % |
| `ω_o` VDC | 109.9 rad/s | 184.0 rad/s | +67.4 % |
| `b` VDC | 1.00 | 0.88 | −12.0 % |
| **Virtual impedance and damping** | | | |
| `L_v` | 0.065 pu | 0.066 pu | +1.4 % |
| `D_d`-on-error flag | 1 | 1 | 0 |

## What the shape of this table says

**The action is in the VSM power loop.** More phase margin, lower crossover,
doubled inertia, 2.5× the transient damping. Everything else moves by single or
low-double digits.

**The d/q asymmetry in the inner loops is real and deliberate.** RSCd loses
20 % of its crossover while RSCq gains 8 %. Section 5.3.3 states the condition
under which that is safe: the inner loops must remain much faster than the
outer ones, which at 1737 rad/s against 5.90 rad/s they comfortably are.

**Nothing is pinned to a bound.** `φ_m` VSMP reaches 84.9° against a 90°
ceiling and `ω_o` VSMP 5.90 against a 5 rad/s floor. The exception is `ω_o` VSMQ
at exactly 2.00 rad/s, which is its upper bound — the only variable the box
constrains.

**Five of six realised margins land slightly below target.** Section 5.2 reads
that as an interaction penalty rather than scatter, and is careful about the
evidence: a two-sided sign test gives `14/64 ≈ 0.22`, so the pattern alone does
not exclude chance. What supports the reading is the mechanism, and the
load-bearing statement is the bound — every realised margin within 4.8° of
target, none below 55°, all six inside `[50°, 90°]`.

## The virtual resistance is zero

The virtual impedance is the inductance `L_v` alone. The virtual resistance
`R_v` is fixed at 0 and is not a decision variable: Phase 5 optimises `L_v`
only, and `OPTIMIZER.m` pins the `R_v` slot with `lb = ub = 0`.

This is also a property of the model, not only of the optimiser settings. The
linear analysis has no term for `R_v` — the line that would read it,
`LINEAR_ANALYSIS.m:187`, is commented out — so the spectrum does not depend on
it. `ANALYSIS/RV_CONNECTIVITY_TEST.m` checks that by relinearising the design
with `R_v` swept over two orders of magnitude:

```matlab
% from CONFIGURATION, after CONFIG_POWER_SYSTEM with RUN_MODE = 0
OUT = RV_CONNECTIVITY_TEST(LIN_MODEL);
```

```
  R_v [pu]     max|dlambda|     max|dA_ij|       min damping
  --------------------------------------------------------------
  0.0000       0                0                0.01240708
  0.0066       0                0                0.01240708
  0.0500       0                0                0.01240708
  0.5000       0                0                0.01240708

  VERDICT: R_v is NOT connected.
```

Exact equality, not a tolerance. As a control, moving `L_v` by 5 % shifts the
eigenvalues by 101.58 rad/s, so the harness does detect a change in the virtual
impedance when there is one.

## A consequence worth carrying forward

The 67.4 % VDC bandwidth increase is what produces the DC-link improvement
reported in Sections 6.1 and 6.2. That is the one place where a small-signal
design change shows up directly in a large-signal result, and it is checkable:
reproduce Table 5, then check the DC-link traces of Figures 12 and 13.

## Files

| File | Role |
|---|---|
| `RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat` | Baseline |
| `RESULTS/CONTROL/LIN_MODEL_*_OPT_BIOBJ.mat` | Phases 1-5 |
| `OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m` | The GA |
| `CONFIGURATION/GEN_PAPER_V6_FIGURES.m` | Prints the phase-by-phase table data |
| `CONFIGURATION/VERIFY_TABLE_III.m` | Reads the tabulated values back out of the saved designs |
| `ANALYSIS/RV_CONNECTIVITY_TEST.m` | The `R_v` check above |

## See also

[`tab04_optimization_bounds.md`](tab04_optimization_bounds.md) — the box ·
[`tab06_achieved_margins.md`](tab06_achieved_margins.md) — realised against
specified · [`tab08_phase_progression.md`](tab08_phase_progression.md) — which
phase contributed what.
