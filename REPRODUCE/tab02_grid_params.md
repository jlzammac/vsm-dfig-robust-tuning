# Table 2 — External grid dynamic model

**Section 2.4** · governor, turbine and swing equation behind the Thevenin
impedance.

**Status: `verified`.** Values read from the source; the steady-state property
below is checked against the paper's own equation.

---

## What this is, and what it is not

The external grid is **not** a static Thevenin source. Behind `Z_grid` the
frequency of the equivalent grid voltage is a state, driven by a first-order
speed governor, a second-order turbine and a swing equation. Table 1 carries the
grid **impedance**; this table carries its **dynamics**. They are independent
and set in different places.

Everything here is in per unit of the farm base `S_b,grid = 4·S_b = 8.41 MVA`,
not the single-machine base.

## Parameters

| Parameter | Symbol | Value |
|---|---|---|
| Governor time constant | `T_gov` | 0.2 s |
| Turbine time constant 1 | `T_tb1` | 0.3 s |
| Turbine time constant 2 | `T_tb2` | 7 s |
| Damping / droop coefficient | `D_eq` | 20 pu |
| Grid inertia constant | `H_g` | 5 s |
| Grid power base | `S_b,grid` | 8.41 MVA |

Read them as the model loads them:

```matlab
cd CONFIGURATION
CONFIG_POWER_SYSTEM
disp(LIN_MODEL.MODEL.GRID.PARAM)
disp(LIN_MODEL.MODEL.GRID.BASE)
```

## The one property that explains the Section 6.1 result

`D_eq` appears **twice** in the model: once inside the governor loop, where it
acts as primary-frequency droop, and once directly in the swing equation, where
it acts as load damping. The turbine has unit static gain, so the two
contributions **add** and the steady state is

```
Δω_g = ΔP / D_eq
```

with `D_eq = 20` pu — a 5 % droop on the farm base.

**The consequence: the steady-state frequency deviation after a power imbalance
is fixed by `D_eq` alone and is completely independent of the wind-farm
controller.** No tuning in this paper can move it.

That is why the frequency benefit reported in Section 6.1 is modest in absolute
terms, and it is worth checking when reproducing: losing one machine dispatched
at 0.7 pu is an imbalance of `0.7/4 = 0.175` pu on the farm base, so the
asymptotic deviation is `0.175/20 = 8.75e-3` pu, **437.5 mHz**. Section 6.1
reads 225 mHz off a 3 s window, which is about half of where the event is
heading. A peak quoted from that window without stating the window is not a
measurement.

If your run settles anywhere other than 437.5 mHz for that disturbance, `D_eq`
or the farm base has changed.

## What the controller can and cannot move

Measured on the full linearisation, taking the transfer from the active-load
input at the PCC to the grid-frequency state and applying the same unit step to
both designs:

| Quantity | Change, optimised against baseline |
|---|---|
| Steady-state frequency deviation | unchanged to within 0.04 % — fixed by `D_eq` |
| Peak excursion | improves 11.8 %, timing delayed from 2.44 to 3.07 s |
| Initial rate of change of frequency | improves 5.5 % |

The optimised design reshapes the transient. It cannot move the endpoint.

**Two absolute values, because the ratios above cannot be checked without
them.** Everything in that table is a ratio and therefore independent of the
step size; these two are not, and are the only numbers in this section a
replicator can use to confirm they applied the same step:

| | Value |
|---|---|
| Baseline undershoot | −2.373 × 10⁻³ pu |
| Final value | +1.649 × 10⁻³ pu |

The undershoot is **past** the final value and of opposite sign, so this peak is
a transient overshoot rather than an approach to the endpoint. If your peak and
your final value have the same sign, the step you applied is not this one.

**Do not express this as an equivalent inertia added to `H_g`.** The `H` of the
VSM active-power loop is a control gain, not a measured mechanical inertia.
Treating them as additive predicts a 45 % improvement in rate of change of
frequency where the linearised model gives 5.5 %.

## Files

| File | Role |
|---|---|
| `MODEL/CONFIG_MODEL.m` | Grid dynamic parameters and base |
| `ANALYSIS/LINEAR_ANALYSIS.m` | Governor, turbine and swing states in the linearisation |

## See also

[`tab01_benchmark_params.md`](tab01_benchmark_params.md) — the grid **impedance**,
which is recomputed per SCR and is a different thing from these dynamics.
