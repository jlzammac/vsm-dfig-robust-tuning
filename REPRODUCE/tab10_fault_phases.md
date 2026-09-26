# Table 10 — Pre-fault, during-fault and post-fault decomposition

**Section 6.3.1** · sixteen points, decomposed into the three intervals a fault
study must separate.

**Status: `verified`.** Executed from a clean clone. Agreement is tabulated
below, quantity by quantity, for one cell that recovers and one that does not.

---

## Procedure

```matlab
addpath SIMULATION
T = b7_campaign();            % all sixteen points
writetable(T, 'table10.csv')  % b7_campaign writes this anyway
```

One point on its own:

```matlab
s = b7_point('m_S1_P0.8_V90', 1, 0.8, 0.73064, 0.15, 3.0);
```

Configuration: **verification**, the three protection mechanisms armed. Pre-fault
PCC voltage 0.975 pu. See [`00_setup.md`](00_setup.md).

## The matrix

`SCR ∈ {1, 1.5, 2, 3}` × `P ∈ {0.4, 0.8}` pu/DFIG × two fault depths. Every run
is a 150 ms symmetric event with a 3 s horizon.

| tag | SCR | P | source retained | target retained PCC |
|---|---|---|---|---|
| `m_S1_P0.4_V90` | 1 | 0.4 | 0.67469 | 0.90 |
| `m_S1_P0.4_V70` | 1 | 0.4 | *calibrated* | 0.70 |
| `m_S1_P0.8_V90` | 1 | 0.8 | 0.73064 | 0.90 |
| `m_S1_P0.8_V70` | 1 | 0.8 | 0.40638 | 0.70 |
| `m_S1.5_P0.4_V90` | 1.5 | 0.4 | 0.75633 | 0.90 |
| `m_S1.5_P0.4_V70` | 1.5 | 0.4 | 0.34934 | 0.70 |
| `m_S1.5_P0.8_V90` | 1.5 | 0.8 | 0.74868 | 0.90 |
| `m_S1.5_P0.8_V70` | 1.5 | 0.8 | 0.51558 | 0.70 |
| `m_S2_P0.4_V90` | 2 | 0.4 | 0.79453 | 0.90 |
| `m_S2_P0.4_V70` | 2 | 0.4 | 0.47591 | 0.70 |
| `m_S2_P0.8_V90` | 2 | 0.8 | 0.78953 | 0.90 |
| `m_S2_P0.8_V70` | 2 | 0.8 | 0.57320 | 0.70 |
| `m_S3_P0.4_V90` | 3 | 0.4 | 0.84801 | 0.90 |
| `m_S3_P0.4_V70` | 3 | 0.4 | 0.57297 | 0.70 |
| `m_S3_P0.8_V90` | 3 | 0.8 | 0.83352 | 0.90 |
| `m_S3_P0.8_V70` | 3 | 0.8 | 0.62943 | 0.70 |

`source retained` is the fraction of the **Thevenin source** voltage kept during
the fault. It is not the retained PCC voltage. The fault is applied by scaling
the source behind `Z_grid`; the retained PCC voltage is a result. The two are
not proportional, and one source fraction leaves a different PCC voltage at each
grid strength, which is why every point carries its own.

The deep event at `SCR = 1, P = 0.4` pu has no stored fraction in the campaign
record. `b7_campaign` calibrates it by bisection against the target retained PCC
voltage, which is how all the others were obtained. It is not invented.

## The deep `P = 0.4` row is not depth-matched, and this is worth knowing before you compare across it

The `target retained PCC` column above says 0.70 for all four deep points. The
retained voltages Table 10 actually reports for that row do not:

| SCR | `V_ret` published | Campaign record | Outcome |
|---|---|---|---|
| 1 | 0.679 pu | 0.6795 | Voltage shortfall |
| 1.5 | **0.613 pu** | 0.6126 | Voltage shortfall |
| 2 | 0.663 pu | 0.6632 | Voltage shortfall |
| 3 | **0.686 pu** | 0.6865 | Recovers |

A **0.073 pu spread** on a nominal 0.70 pu target. The per-point source fraction
was fixed in the campaign record, not re-calibrated to a common retained
voltage, and the caption attributes the spread to the accuracy of that
per-operating-point calibration.

The consequence for reading the row: **the four cells are four slightly
different disturbances, not one disturbance at four grid strengths.** The
`SCR = 1.5` cell sees the deepest event of the four and the `SCR = 3` cell the
shallowest — and the `SCR = 3` cell is the only one that recovers. **Depth and
grid strength are confounded in that row, and the recovery at `SCR = 3` must not
be attributed to grid strength on the strength of it.** The campaign record says
so in those terms.

The `V90` row has no such problem: its retained voltages span 0.8933–0.9028 pu,
a 0.0095 pu spread, and there the comparison across grid strength is clean. Use
that row for the trend.

Reproducing the row exactly requires the archived fractions, which are in
`b7_campaign.m` and do reproduce. What does not exist, and cannot be recovered,
is a common depth — it was never imposed.

## The outcome balance

Across the sixteen points, as Table 10 and Section 6.3 both report:

| Outcome | Count |
|---|---|
| Recovers | 10 |
| Voltage shortfall | 3 |
| Loss of synchronism | 2 |
| Excluded | 1 |
| | **16** |

The two losses of synchronism are the two cells at `SCR = 1, P = 0.8` pu —
both depths of the single cell with a 55.1° pre-fault angle. The single
non-recovery at `SCR ≥ 2` is a voltage shortfall, at `P = 0.4` pu and a retained
0.663 pu.

If your campaign returns a different balance, compare the outcome test order
below before suspecting the model: the three voltage shortfalls become
"recovers" if the 0.90 pu terminal-voltage test is omitted, and the one
exclusion becomes a failure to ride through if the guard is tested last instead
of first.

> **If you have seen the balance quoted as 10 · 2 · 3 · 2, that is the same
> campaign counted over a different set and it is not a disagreement.** The
> 2026-09-01 record reads: *"All 16 grid points ran, plus the probe: 10 recover ·
> 2 first-swing pull-out · 3 voltage-only shortfall · 2 excluded."* The
> seventeenth run is `probe_S1_P0.4_deep`, a deliberate out-of-range probe at a
> retained 0.4893 pu, and it is the second exclusion. **Table 10 reports the
> sixteen grid points only**, so it carries one exclusion and sums to 16.
>
> Neither count is wrong. Quote 16 when citing Table 10, and say "plus the
> probe" if you mean the campaign.

`b7_campaign()` runs the sixteen grid points. The probe is not part of the
matrix, and it is not needed: it was run to confirm that a point far outside the
validity floor is caught by the guard, which
[`sec022_validity_floor.md`](sec022_validity_floor.md) establishes by bisection
rather than by a single probe.

---

# How each column is defined

**The paper states what was measured. This section states how, to the precision
a reimplementation needs.** Several of these definitions are not recoverable
from the table caption, and getting one wrong produces a consistent bias that
looks like a modelling disagreement and is not. Each one below cost an iteration
to find, and the measured consequence of getting it wrong is given.

## Three windows, and they are not interchangeable

```
        t_fault                t_clear              t_clear + 1.25 s
           |                      |                        |
  pre      |    during fault      |   after clearance      |   criterion
  ---------+----------------------+------------------------+--------------->
```

| Window | Used for |
|---|---|
| `pre` | Pre-fault equilibrium: PCC voltage, transmission angle, rotor speed reference |
| `during` | Retained voltage, peak rotor current |
| `afterClear` | **The peaks**: largest transmission angle, largest speed excursion |
| `post` | **The recovery criterion only**: has every machine returned to within 2 % of pre-fault speed and to 0.90 pu terminal voltage |

**`afterClear` and `post` are different windows and conflating them is an
error.** The peaks occur within a few hundred milliseconds of clearance. The
criterion window starts 1.25 s after clearance, by which time the peak has long
passed. Measuring the peaks on the criterion window misses them entirely.

> Measured, `m_S3_P0.8_V90`: taking `delta_max` on the criterion window returns
> 16.13° against a published 19.0°, an apparent −15 % disagreement. On the
> correct window it returns 19.12°, +0.6 %.

## `V_ret` — retained PCC voltage

**The plateau, not the instantaneous minimum.** Fault inception excites a
switching transient lasting roughly the first fifth of the window. `b7_metrics`
discards that fifth and takes the **median** of the remainder. A median rather
than a mean, because ringing persists at reduced amplitude after inception.

> Measured, `m_S1_P0.8_V90`: over the fault window the PCC voltage swings
> between 0.627 and 1.099 pu in the first 20 %, then settles at 0.92–0.94. The
> instantaneous minimum is 0.627 pu. The published value is 0.929 pu. The
> plateau median is 0.935 pu.

## `ir_peak` — peak rotor current

**Carries the `1/sqrt(3)` of the per-unit convention.** Power is computed as
`real(v.*conj(i))/sqrt(3)` throughout this codebase, and the current magnitude
follows the same base: `hypot(id,iq)/sqrt(3)`, referred to `I_b` of Table 1
against which the 1.074 pu RSC rating is quoted.

> Measured, `m_S1_P0.8_V90`: without the factor, 1.864 pu, which would be 74 %
> above the limiter setpoint. With it, 1.076 pu, just above the 1.074 pu
> setpoint exactly as Section 6.3.1 describes. Published 1.084 pu.

Measured on the settled window, for the same reason as `V_ret`.

## `Δω_r,max` — post-clearance rotor-speed excursion

**Relative to the pre-fault speed, not an absolute difference in per unit.**
The pre-fault rotor speed is about 1.157 pu, so the two differ by that factor.

> Measured: the absolute form leaves a **constant +15 % bias in every cell**, in
> both the cell that recovers and the cell that does not. A bias identical
> across cells is a definition, not scatter.
>
> | | absolute | relative | published |
> |---|---|---|---|
> | `m_S1_P0.8_V90` | 0.1681 | 0.1454 | 0.1454 |
> | `m_S3_P0.8_V90` | 0.0108 | 0.0094 | 0.0094 |

The relative form is also what the recovery criterion of Section 6.3.1 is
written in: the machine must return to within 2 % **of its** pre-fault speed.

## `δ_max` — measured on the wrapped angle, and this matters

The logged transmission angle is wrapped to `[−180°, 180°]`, and `δ_max` is the
maximum of that. For every cell that recovers this is simply the peak of the
swing. **For the two cells that lose synchronism it is a saturation**, not a
peak: the angle goes over the top and the wrapped quantity cannot exceed 180.

That is why both loss-of-synchronism rows read 179.9 and 180.0 — not a
coincidence of two events peaking at the same place.

**The 2026-09-01 campaign record reports the same column unwrapped**, and there
the same three cells read 1129°, 5061° and 3058°. Both are published; they are
different measurements and must not be compared. See
[`fig14_nl_fault_4dfig.md`](fig14_nl_fault_4dfig.md), which carries the horizon
dependence of the unwrapped form.

If you compute `δ_max` on an unwrapped angle you will not reproduce Table 10 in
those two rows, and the disagreement will be a factor of six rather than a few
per cent — which is the signature of a definition difference rather than a
modelling one.

## `δ_pre` — pre-fault transmission angle

From the lossless relation `sin δ = P / (V_pcc · V_g · SCR)`, which is the
expression the operating-point initialisation itself solves — not a separate,
more accurate power flow. `b7_metrics` also records `delta_pre_logged`, the
angle the simulation logs, so a disagreement between the two is visible rather
than hidden.

## `Outcome` — and why exclusion is tested first

The order of tests is not cosmetic.

1. **Excluded** — `u_dc` reached the 0.50 pu division guard of Section 2.2 at
   any instant of the run.
2. **Loss of synchronism** — the transmission angle reached 90° and did not
   return.
3. **Speed shortfall** — rotor speed stayed outside 2 % of pre-fault on the
   criterion window.
4. **Voltage shortfall** — angle and speed recover, but a machine terminal
   voltage fell below 0.90 pu on the criterion window.
5. **Recovers**.

**Exclusion is tested before anything else** because a run outside the model's
valid range must be reported as excluded and never as a failure to ride
through. That is the distinction the guard exists to enforce.

**Admissibility is not decided by depth.** It is decided by whether `u_dc`
reaches the guard. How far `u_dc` falls depends on dispatch and grid strength as
well as on the retained voltage, so the screen is applied run by run. Table 10
contains admissible runs deeper than the excluded one: the excluded run sits at
a retained 0.702 pu while four admissible runs sit at 0.613, 0.663, 0.679 and
0.686 pu.

---

## Measured agreement

Two cells, chosen to contrast: one that recovers and one that does not.

| Quantity | `m_S3_P0.8_V90` recovers | `m_S1_P0.8_V90` loses synchronism |
|---|---|---|
| `δ_pre` | −0.2 % | +0.1 % |
| `V_ret` | +0.8 % | +0.7 % |
| `u_dc,min` | +0.0 % | +0.0 % |
| `i_r,peak` | −0.2 % | −0.7 % |
| `δ_max` | +0.6 % | +0.1 % |
| `Δω_r,max` | +0.1 % | +0.0 % |
| `V_post/V_pre` | +0.0 % | **+16.0 %** |
| Outcome | Recovers, as published | Loss of synchronism, as published |
| | **7 of 7** | **6 of 7** |

### The one quantity that does not reproduce, and why

`V_post/V_pre` in the cell that **loses synchronism**.

The contrast localises it exactly. In the cell that recovers, all seven
quantities reproduce, including this one at +0.0 %. The disagreement appears
only where the transmission angle has run to 180° and the machines are out of
step.

That column is the PCC voltage at the end of the window relative to its
pre-fault value. In a cell that recovers, the plant has settled and the ratio is
determinate. In a cell that has lost synchronism, it is read off a trajectory
that has diverged, where the value depends on the integration path taken after
divergence — solver step selection, tolerances, and the order in which the
algebraic loop resolves — rather than on the model. Two runs of the same model
with different step histories separate on it.

**What does reproduce about that cell, and what Section 6.3 actually rests on,
is the outcome**: it loses synchronism, at both fault depths including the
shallower one, while every cell at `SCR ≥ 2` rides through at both powers and
both depths. That is reproduced exactly.

So: for the two loss-of-synchronism cells, quote the pre-fault and during-fault
columns and the outcome. Read `V_post/V_pre` there as an indication that the
plant did not recover, which is what it is, and not as a quantity determined to
three digits.

### One assumption not yet confirmed

Section 6.3 never states which controller it used. It studies one design across
grid strengths and is not a baseline-versus-optimised comparison — that is
Section 6.4 — and the text never names the design.
`b7_build_operating_point` loads the GA-optimised design of Table 5, with the
reasoning recorded in that file.

This was tested rather than assumed away: running the same point against the
CFRD baseline changes the during-fault quantities by less than 0.2 %. The
controller is not what sets them, and the agreement above holds either way.

## Files

| File | Role |
|---|---|
| `SIMULATION/b7_campaign.m` | Driver over the matrix; writes `b7_campaign_table.csv` |
| `SIMULATION/b7_point.m` | One point; traces written before metrics |
| `SIMULATION/b7_metrics.m` | Every column defined above |
| `SIMULATION/b7_calibrate_depth.m` | Bisection of source fraction to retained PCC |

## See also

[`fig14_nl_fault_4dfig.md`](fig14_nl_fault_4dfig.md) — the four traces drawn
from this campaign.
