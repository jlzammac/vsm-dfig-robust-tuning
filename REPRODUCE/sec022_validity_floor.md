# Section 2.2 — Where the averaged model stops being valid

**Section 2.2** · the fault-depth floor, measured by bisection and reported as a
result.

**Status: `verified`.** Both ends of the published bracket executed on
2026-09-25: the guard stays off at 0.677 pu and fires at 0.670 pu.

---

## Why this is a result and not a disclaimer

`u_dc` is floored at 0.50 pu in the denominator of `i_dc = P_dc/u_dc`. **That
guard does not keep the model valid — it marks where the model stops being
valid.** Wherever it is active the trajectory is an artefact of the guard, and
no quantitative claim in the paper rests on that region.

A paper that states such a guard and never says where it bites has told the
reader nothing checkable. Measuring it is what turns a caveat into a number.

There is a second guard of the same kind — `|u_dqs|` floored at 0.10 pu in the
denominator of the GSC power-to-current reference map. Both are inactive at
every operating point in the paper and invisible to the linearisation.

## Configuration

**Verification configuration — all three enables armed.** This is a property of
the verification model, not of the design model, and the campaign behind it is
run armed because that is the configuration in which any large-signal event of
this depth would be simulated.

Along with [`fig14_nl_fault_4dfig.md`](fig14_nl_fault_4dfig.md) and
[`tab10_fault_phases.md`](tab10_fault_phases.md), this is one of the few places
in the repository that uses it. See [`00_setup.md`](00_setup.md).

## Procedure

Bisect on the depth of a 150 ms symmetric event at the worst-case operating
point. The criterion is that **the 0.50 pu guard never activates at any instant
of the run** — not that the run completes, and not that `u_dc` stays positive.

`b7_metrics` already records it, so the test is one field:

```matlab
summary.guard_active     % true if u_dc <= 0.50 pu at any instant
summary.guard_fraction   % what fraction of the run was inside the guard
summary.guard_t_min      % when the minimum occurred, s after clearance
```

The bisection is over **retained PCC voltage**, which is what the result is
quoted in. Each candidate depth needs its own source fraction, because the two
are not proportional:

```matlab
addpath SIMULATION
root = pwd;  % repository root
lo = 0.60; hi = 0.75;                     % brackets the published 0.677
for k = 1:6
    Vt   = (lo + hi)/2;
    r    = b7_calibrate_depth(root, 'floor', 1, 0.8, Vt, 0.15, 3.0, 0.975);
    s    = b7_point('floor', 1, 0.8, r, 0.15, 3.0);
    if s.guard_active, lo = Vt; else, hi = Vt; end   % guard fired -> too deep
    fprintf('V_ret %.4f  guard %d\n', s.PCC_ret, s.guard_active);
end
```

**Note the nesting.** `b7_calibrate_depth` is itself a bisection — on source
fraction, to hit a target PCC voltage — so each outer step costs a full inner
calibration. Budget accordingly, and keep `maxIter` modest on the inner loop.

`guard_t_min` is worth watching as you go: **the guard can be reached well after
clearance**, so a run that looks survivable during the fault can still be
excluded. That is why `b7_metrics` tests the whole run and not the fault window.

## Expected result

| | Retained PCC voltage |
|---|---|
| Model satisfies the criterion down to | **0.677 pu** |
| Fails at the next bracket point | **0.670 pu** |

Measured, 2026-09-25 (`SCR = 1`, `P = 0.8` pu, pre-fault `V_pcc = 0.975` pu,
150 ms fault):

| Target | Source retained | PCC retained | Guard active | Fraction of run in guard |
|---|---|---|---|---|
| 0.677 pu | 0.36605 | 0.6767 pu | **no** | 0 |
| 0.670 pu | 0.35516 | 0.6689 pu | **yes** | 0.25 % |

Referred to the 0.975 pu pre-fault PCC voltage, 0.677 pu is a retained 0.694 —
a symmetric sag of about **31 %**.

**Two weaker criteria were specified alongside and neither discriminates**,
which is worth knowing before you adopt one of them by mistake:

- *A run completes without solver error.* It always does — the guard itself
  keeps the division finite.
- *`u_dc` remains positive.* It always does — the diode clamp enforces it.

Only the guard-activation criterion separates admissible from inadmissible.

## The 0.677 pu does not transfer to other operating points

This is the misreading to avoid. The criterion is a condition on `u_dc`, and how
deep an event drives `u_dc` depends on the **dispatch and the grid strength** as
well as on the retained voltage. A retained voltage alone does not decide
admissibility.

So the campaign of Section 6.3 is screened **run by run against the guard
itself**, never against 0.677 pu. Table 10 accordingly contains admissible runs
deeper than that value, and one excluded run that is shallower. That is not an
inconsistency; it is what screening against the right quantity looks like.

## Where the voltage is measured — part of the specification

The sag is applied by scaling the grid source **behind** the Thevenin impedance.
At `SCR = 1` that impedance is large and the farm keeps injecting current
throughout, so the PCC sits far above the source.

> A source retained fraction of **0.25** leaves the PCC at **0.596 pu**.

**Every retained voltage quoted in the paper is a PCC value.** Reading one of
them as a source fraction will put you off by a factor of more than two at this
grid strength.

---

## The floor resists being lowered, and the reason is structural

Three forms of the derate were measured, all in the armed verification model:

| Derate keyed on | Floor |
|---|---|
| none — neither clamp nor derate | 0.677 pu |
| the machine **terminal voltage** | 0.664 pu |
| the **DC-link voltage** | 0.677 pu |

The terminal voltage is an **algebraic** quantity that stays depressed for as
long as the fault is applied, so a derate keyed on it engages early but
**latches** — suppressing the rotor voltage command de-excites a machine that is
magnetised from the rotor.

The DC-link voltage is a capacitor **state**. It moves the wrong way first,
troughs **10.8 ms** after inception, and recovers while the fault is still
applied, so a derate keyed on it self-releases but arrives too late.

> **The variable that anticipates the collapse is the one that latches. The
> variable that self-releases is the one that arrives too late.**

Which of the two happens follows from **whether the quantity is a state**, not
from the tuning. No amount of re-tuning either form escapes it. This is why
converter protection in hardware latches by design, and why a crowbar is a
*requirement* for deep-fault work with a model of this class rather than a
refinement of it.

### Why the DC-link form is kept anyway

It removes the latch and the integrator windup that came with it:

> peak RSC current-loop integrator magnitude falls from a range reaching
> **23.4** to a flat **0.75** at every depth tested.

A flat 0.75 at every depth is the signature of a mechanism that releases. A
range reaching 23.4 is the signature of one that does not.

## What this bounds in the paper

The Future Work item on adding a crowbar rests on this measurement: a crowbar is
what would lower the floor, and this file is the statement of what the floor
currently is and why a derate cannot move it.

## Files

| File | Role |
|---|---|
| `SIMULATION/b7_arm_mechanisms.m` | Arms the three enables in a mirror |
| `SIMULATION/b7_calibrate_depth.m` | The bisection |
| `SIMULATION/b7_point.m` | One run |
| `SIMULATION/b7_metrics.m` | Records `u_dc` minimum and guard activation |

## See also

[`00_setup.md`](00_setup.md) — the two configurations and the derate derivation ·
[`tab10_fault_phases.md`](tab10_fault_phases.md) — the run-by-run screening
