# Fig. 6 — Eigenvalues of the coordinated baseline design

**Section 3.3** · the CFRD design, on the same axes as Figure 5.

**Status: `verified`.** Per-band minima re-derived on 2026-09-23 by
`COMPUTE_PERBAND_DAMPING`: **0.03062 / 0.09582 / 0.47192** against a published
0.0306 / 0.0958 / 0.4719. Exact to every digit the paper prints.

---

## What the figure shows

The same 80 eigenvalues of the same four-machine system as Figure 5, after the
coordinated frequency-response design that **accounts for** intra-machine
control interactions. Figure 5 ignores them.

Same operating point — designated: `P = 0.7` pu per DFIG, `|v_g| = 1` pu,
`SCR = 1` — and the same axes, so the two figures can be read against each
other directly. That is their purpose.

> **Naming.** Section 3.3 calls this design **FRD**; the rest of the paper calls
> it **CFRD**. Same design. The saved file is `LIN_MODEL_FRD_DESIGN.mat`.

## Procedure

```matlab
RUN_MODE     = 0;
CONTROL_TYPE = 2;    % FREQUENCY-response design — the CFRD baseline
```

Or load the saved design directly:

```matlab
load RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat
```

Versioned here, so the design does not have to be recomputed. If you do
recompute it, note the incomplete reuse check described in
[`tab03_baseline_specs.md`](tab03_baseline_specs.md).

Axes, bands, the `ζ = sin(α)` convention and the spurious-mode filter are all as
in [`fig05_eigenvalues_trd.md`](fig05_eigenvalues_trd.md).

## Expected values

Per-band minimum damping at the designated operating point:

| Band | TRD (Fig. 5) | **CFRD (Fig. 6)** | Change |
|---|---|---|---|
| LF | 0.0282 | **0.0306** | +8.5 % |
| MF | 0.0355 | **0.0958** | +170 % |
| HF | 0.2532 | **0.4719** | +86 % |

That improvement is what coordinating the loops buys. It is **not** the benefit
of the optimisation: that is measured at a different operating point and
tabulated separately in Table 8. Section 5.3.3 is explicit that the two are
reported side by side rather than divided into one another, precisely because
they are evaluated at different points.

## What this design does not hold

Figure 6 is drawn at one operating point, and that is its limitation rather
than its result. The baseline's VSM active-power phase margin moves **8.61°**
across the grid-strength endpoints, from 67.28° at `SCR = 1` to 58.67° at
`SCR = 3`. The optimised design moves by at most 1.76°.

**That contrast is the argument of the paper.** A design certified at one point
says nothing about the next one, and Figure 6 is the certificate at one point.
Figure 7 shows what happens across the envelope.

## Where the least-damped modes sit

Reported by `LINEAR_ANALYSIS` as `stateMinDamping`. On the designated operating
point of this repository, measured:

```
minDamping      0.012407   0.030616
stateMinDamping 'NODE 1 VOLTAGE REAL'   'RSCd INT DFIG 3'
maxRealEig      -0.022647
stateMaxRealEig 'RSCq INT DFIG 4'
```

The least-damped complex mode is dominated by a network node voltage and an RSC
d-axis integrator — a grid-coupled mode, not a converter-internal one. That is
consistent with the LF band being the one the weak grid attacks, and it is why
the optimisation constrains damping **per band** rather than in aggregate: a
single aggregate figure can be improved comfortably in a band that was never at
risk while a fragile band is left untouched.

## Files

| File | Role |
|---|---|
| `CONTROL/CONTROL_DESIGN_FR.m` | The coordinated design |
| `ANALYSIS/EIGEN_CALC.m` | Eigenvalues, bands, participation factors |
| `RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat` | Saved CFRD baseline |

## See also

[`fig05_eigenvalues_trd.md`](fig05_eigenvalues_trd.md) ·
[`fig07_baseline_perband_envelope.md`](fig07_baseline_perband_envelope.md) — the
same design across the envelope rather than at one point.
