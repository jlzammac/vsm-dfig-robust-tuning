# Fig. 4 — Transmission angle against dispatched power and grid strength

**Section 3.2** · the angle across `Z_grid` as power and SCR vary.

**Status: `verified`.** The relation is closed-form and has been checked against
the model's own solve at three operating points.

---

## What the figure shows

The pre-fault transmission angle between the PCC and the Thevenin source, as a
function of dispatched power, for each grid strength. It is the physical
quantity behind the stability boundary of Figure 3.

## The relation

In the per-unit convention of this benchmark, the static transfer capability per
machine is

```
P_max = V_pcc · V_g · SCR
sin δ = P / P_max
```

This is not a post-hoc approximation. **It is the expression the operating-point
initialisation itself solves** — `ANALYSIS/LINEAR_ANALYSIS.m:253`:

```matlab
GRID_delta = asin(Pline .* Lg_pu ./ Vp ./ Vgrid * sqrt(3));
```

with `Pline = sum(P_ref)`. The caption's phrase about the lossless
approximation therefore describes the model's own solve, not a simpler stand-in
for a more accurate power flow computed elsewhere. There is no such other
computation.

## Checked against the model

Three operating points, closed-form against what `LINEAR_ANALYSIS` returns in
`LIN_MODEL.lineAngle`:

| Operating point | Closed form | Model | |
|---|---|---|---|
| `P = 0.7`, `V_pcc = 1.0`, `SCR = 1` | 44.43° | 44.427° | ✅ |
| `P = 0.8`, `V_pcc = 0.975`, `SCR = 1` | 55.14° | 55.136° | ✅ |
| `P = 0.8`, `V_pcc = 0.975`, `SCR = 3` | 15.87° | 15.873° | ✅ |

Agreement to three decimals by two independent routes.

## What the figure is really showing

At `SCR = 1` and `V_pcc = 0.975` pu the capability is 0.975 pu per machine.
Dispatching 0.8 pu puts the plant at `sin δ = 0.82` of it, an angle of 55.1°,
**before any disturbance is applied**. That is the pre-fault state of the only
cell in the Section 6.3 campaign that loses synchronism, and Table 10 shows it
losing synchronism at both fault depths including the shallow one.

The figure is therefore not a curiosity about steady state. It is the reason the
fault campaign fails where it fails: **the pre-fault angle, not the depth of the
event, is what the loss-of-synchronism rows follow.**

## A caveat that matters when comparing against the paper's labels

The angle is obtained from the lossless relation while the line current is
computed with `R_g` at `X/R = 10`. The two do not close, so the realised
dispatch differs from the nominal label — 0.845 pu realised against 0.800
nominal at the optimisation point, measured. The angle itself is consistent with
the *label*; the power that flows is slightly higher. See
[`00_setup.md`](00_setup.md).

**And the 90° of the lossless relation is not this branch's true maximum.**
Carrying the resistance that `X/R = 10` implies moves the maximum of the
sending-end power to **95.7° and 1.035 pu** on this branch.

The consequence for reading the figure: 90° is a reference line, not a limit,
and the curves are entitled to pass it. What ends the curves is the eigenvalue
constraint, which bites first. A reproduction that treats 90° as the transfer
limit will look for an instability at the wrong place.

## Procedure

No separate script. The angle comes out of the same envelope sweep as Figure 3:

```matlab
RUN_MODE     = 2;
CONTROL_TYPE = 2;
```

Or, for a single point, read `LIN_MODEL.lineAngle` after any `RUN_MODE = 0` run.

To reproduce the curve without simulating anything:

```matlab
SCR = [1 1.5 2 3];  P = 0.4:0.01:1.2;  Vpcc = 0.975;  Vg = 1;
delta = asind(P(:) ./ (Vpcc*Vg*SCR));   % NaN where P exceeds capability
```

The `NaN` region is exactly the infeasible corner of Figure 3.

## Files

| File | Role |
|---|---|
| `ANALYSIS/LINEAR_ANALYSIS.m` | Line 253, the angle solve |
| `CONFIGURATION/update_grid_impedances.m` | `L_g`, `R_g` per SCR |

## See also

[`fig03_baseline_stability_map.md`](fig03_baseline_stability_map.md) ·
[`tab10_fault_phases.md`](tab10_fault_phases.md) — where this angle decides the
outcome.
