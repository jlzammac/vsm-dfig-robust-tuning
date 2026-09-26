# Fig. 9 — Eigenvalues of the GA-optimised design

**Section 5.3.3** · the optimised design, on the same axes as Figures 5 and 6.

**Status: `verified`.** Re-derived on 2026-09-23 by `COMPUTE_PERBAND_DAMPING`.
The optimised design's per-band minima at the optimisation operating point are
**0.02953 / 0.10068 / 0.52174**, and the like-for-like gains against the
baseline at the same point are tabulated in
[`tab08_phase_progression.md`](tab08_phase_progression.md).

---

## What the figure shows

The 80 eigenvalues of the four-machine system with the GA-optimised controller
of Table 5, at the **same operating point as Figures 5 and 6** — the designated
point, `P = 0.7` pu per DFIG, `|v_g| = 1` pu, `SCR = 1` — and on identical axes.

The three figures are drawn to be read as a sequence: TRD, CFRD, optimised.

## Procedure

```matlab
RUN_MODE     = 0;
CONTROL_TYPE = 2;
```

then load the Phase 5 design over the baseline control:

```matlab
D = load('RESULTS/CONTROL/LIN_MODEL_VI_OPT_BIOBJ.mat');
f = fieldnames(D);
LIN_MODEL.CONTROL = D.(f{1}).CONTROL;
LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL);
```

That pattern — saved `CONTROL` merged onto the current `MODEL`, then re-solve —
is how every comparison script in this repository obtains a controller. It keeps
the plant and operating point identical between designs, which is the condition
the comparison needs.

The saved design is versioned here, so the 21.5 h optimisation does not have to be
re-run.

## Two quantities that must not be divided into one another

This is the trap in reproducing Section 5.3.3, and it is worth stating before
the numbers.

| Comparison | Measured at | Where |
|---|---|---|
| TRD → CFRD, what coordination buys | **designated** point, `P = 0.7`, `\|v_g\| = 1` | Figures 5 and 6 |
| CFRD → GA, what optimisation buys | **optimisation** point, `P = 0.8`, `V_pcc = 0.975` | Table 8 |

They are evaluated at **different operating points**. Section 5.3.3 reports them
side by side rather than dividing one into the other for exactly that reason. A
combined "total improvement" figure formed by multiplying them is not a quantity
this study measures.

Figure 9 sits at the designated point, with Figures 5 and 6. Table 8 sits at the
optimisation point. Do not carry a number across.

## Expected values

Per-band minimum damping at the designated point:

```
TRD   0.0282 / 0.0355 / 0.2532      (LF / MF / HF)
CFRD  0.0306 / 0.0958 / 0.4719
```

Figure 9 shows the optimised design at that same point. Section 5.4 reports its
behaviour across the envelope: within the stable region the rightmost eigenvalue
sits more firmly in the left half-plane, LF and HF damping improve at the
weak-grid endpoint, and MF damping rises across all SCR values.

## What changed in the design, and what did not

From Table 5, the parameters that move most:

| Parameter | Baseline | Optimised | Change |
|---|---|---|---|
| `φ_m` VSMP | 67.2° | 84.9° | +26.3 % |
| `ω_o` VSMP | 8.07 rad/s | 5.90 rad/s | −26.9 % |
| `H` | 15.59 s | 32.32 s | **+107 %** |
| `D_d` | 0.156 | 0.388 | +148 % |
| `ω_o` VDC | 109.9 rad/s | 184.0 rad/s | +67.4 % |
| `ω_o` VSMQ | 2.00 rad/s | 2.00 rad/s | **0** |

The VSM power loop is where the optimisation acts: more phase margin, lower
crossover, doubled virtual inertia. The inner current loops move by single-digit
percentages and the VSMQ crossover does not move at all — it sits at its bound.

**A caution about the doubled inertia.** `H` is a control gain, not a measured
mechanical inertia. Treating it as additive to the grid's `H_g` predicts a 45 %
improvement in rate of change of frequency where the linearised model gives
5.5 %. See [`tab02_grid_params.md`](tab02_grid_params.md).

The virtual impedance is the inductance `L_v` alone; the virtual resistance is
zero and is not a design variable. See
[`tab05_optimized_params.md`](tab05_optimized_params.md).

## Files

| File | Role |
|---|---|
| `RESULTS/CONTROL/LIN_MODEL_VI_OPT_BIOBJ.mat` | The Phase 5 design of Table 5 |
| `ANALYSIS/EIGEN_CALC.m` | Eigenvalues and bands |
| `CONFIGURATION/GEN_PAPER_V6_FIGURES.m` | Per-band and eigenvalue comparison figures |

## See also

[`fig05_eigenvalues_trd.md`](fig05_eigenvalues_trd.md) ·
[`fig06_eigenvalues_frd.md`](fig06_eigenvalues_frd.md) ·
[`tab05_optimized_params.md`](tab05_optimized_params.md)
