# Fig. 14 — Fault response across grid strength, every machine reported

**Section 6.3** · four panels, one per grid strength, four machine terminal
voltages in each.

**Status: `verified`.** The procedure below has been executed from a clean clone
and reproduces the published quantities to the agreement tabulated at the end.

---

## What the figure shows

A 150 ms symmetric fault at `P = 0.8` pu per machine, plotted at
`SCR ∈ {1, 1.5, 2, 3}`. Each panel carries the terminal voltage `|u_dqs|` of all
four DFIGs. Machines 1–2 and 3–4 sit behind step-up transformers of different
short-circuit ratio, so the traces coincide in pairs and the two pairs separate.

Panel (a), `SCR = 1`, is the only cell that loses synchronism, and it does so at
both fault depths including the shallower one.

## Configuration

**Verification configuration** — the three protection mechanisms armed. This is
the only result in the paper that uses it. See [`00_setup.md`](00_setup.md).
Its numbers are not interchangeable with anything from Sections 3, 5, 6.1, 6.2
or 6.4, and the two sets must not be pooled.

Pre-fault PCC voltage `V_pcc = 0.975` pu — the optimisation operating point, not
the 1.0 pu of Sections 6.1 and 6.2. The pre-fault angles cannot be reproduced
without this.

## Procedure

```matlab
addpath SIMULATION
T = b7_campaign('Points', 'figure14');
```

That runs the four points of the figure. For the whole Table 10 matrix use
`b7_campaign()` with no arguments.

Each point writes two files to `RESULTS/B7_CAMPAIGN/`:

| File | Contents |
|---|---|
| `b7_<tag>_traces.mat` | Full state trajectories, including `Vs_machines` as `[nSamples × 4]` |
| `b7_<tag>_summary.mat` | The Table 10 quantities |

**The traces are written before any metric is computed.** That ordering is
deliberate: the campaign that produced the published figure kept the metrics and
discarded the trajectories, which is why this figure had to be reconstructed.

## The four runs

| Panel | tag | SCR | P | source retained | duration | horizon |
|---|---|---|---|---|---|---|
| (a) | `m_S1_P0.8_V90` | 1 | 0.8 | 0.73064 | 0.15 s | 3.0 s |
| (b) | `m_S1.5_P0.8_V90` | 1.5 | 0.8 | 0.74868 | 0.15 s | 3.0 s |
| (c) | `m_S2_P0.8_V90` | 2 | 0.8 | 0.78953 | 0.15 s | 3.0 s |
| (d) | `m_S3_P0.8_V90` | 3 | 0.8 | 0.83352 | 0.15 s | 3.0 s |

`source retained` is the fraction of the **Thevenin source** voltage kept during
the fault, not the retained PCC voltage. The fault is applied by scaling the
source behind `Z_grid`; the retained PCC voltage is a result. The two are not
proportional, and one source fraction leaves a different PCC voltage at each
SCR, which is why each point carries its own.

## Per-machine traces — read this if the figure comes out wrong

`SCOPE_SIM` carries **no** per-machine data. All fifteen of its signal groups
have a unit dimension of 1, verified on completed runs. The published figure
cannot have been drawn from that logging configuration, so the campaign must
have added logging of its own.

`b7_enable_per_machine_logging` restores it, in the mirror only, by turning on
port logging for the DFIG subsystem. `b7_fetch_per_machine` reads the result
back from the Simulink Data Inspector, because the logs return inside the
`SimulationOutput` object and `RUN_PERTURBATION_SIM` does not hand that object
back.

Two release details, both found by running rather than by reading:

- In R2026a `DataLogging` is a property of the output **port**, not of the line.
- The logged signals do not reach the base workspace.

If logging fails, `b7_point` warns and sets `traces.per_machine = false` rather
than plotting one machine four times. Check that flag before drawing.

## Expected values

Panel (a), `m_S1_P0.8_V90`, measured on this repository against Table 10:

| Quantity | Obtained | Published | Error |
|---|---|---|---|
| Pre-fault transmission angle | 55.1362° | 55.1° | +0.1 % |
| Retained PCC voltage | 0.9351 pu | 0.929 pu | +0.7 % |
| DC-link minimum | 0.7663 pu | 0.766 pu | +0.0 % |
| Peak rotor current | 1.0762 pu | 1.084 pu | −0.7 % |
| Maximum post-clearance angle | 179.99° | 179.9° | +0.1 % |
| Rotor-speed excursion | 0.1454 | 0.1454 | +0.0 % |
| Outcome | Loss of synchronism | Loss of synchronism | — |
| `V_post/V_pre` | 0.4152 | 0.358 | **+16.0 %** |

The rotor-speed excursion is **relative** to the pre-fault speed. Taken as an
absolute difference in per unit it reads 0.1681, a constant +15.6 % across every
cell in the table. A bias identical in every cell is a definition, not scatter.
See [`tab10_fault_phases.md`](tab10_fault_phases.md).

Per-machine pre-fault terminal voltage, recovered independently:

```
G1  1.0189    G2  1.0189    G3  1.0688    G4  1.0688
```

G1 and G2 coincide, G3 and G4 coincide, and the pairs separate by 0.0499 pu.
That is the structure Section 6.3 reports and attributes to the collector. The
paper quotes a 0.0534 pu between-pair gap during the fault at `SCR = 1`.

## The one quantity that carries a wider tolerance

Six of the seven quantities reproduce to better than 1 %. `V_post/V_pre` comes
out 16 % high. **That has an identified cause, and it is a property of the
event rather than a defect of the repository or of the paper.**

Look at which quantities agree and which does not:

| Measured | Agreement |
|---|---|
| Before the fault — transmission angle, PCC voltage | 0.1 % |
| During the fault — retained voltage, DC-link minimum, peak rotor current | 0.0–0.7 % |
| **After loss of synchronism** — final voltage ratio | 16 % |

The split is not arbitrary. Panel (a) is the cell that **loses synchronism**:
the transmission angle crosses 90° and does not return. Everything measured
before that happens is a determinate trajectory and reproduces to a tenth of a
percent. `V_post/V_pre` is measured after it, on a trajectory that has diverged.

### How far it has diverged, measured

The logged transmission angle is wrapped to `[−180°, 180°]`, so panel (a) looks
like an angle oscillating against the limit. Unwrapped, it is not oscillating:

```
  net pole slips over the 3 s horizon      4.98
  unwrapped angle at t = 3 s            1849.0 deg
  slip rate, last 2.5 s                   1.99 slips/s
  slip rate, last 0.5 s                   4.56 slips/s
```

**The slip rate is rising, not falling.** The machine is accelerating away, and
the slip count is a function of the horizon rather than a property of the event:

| If the horizon were | Unwrapped final angle | Net slips |
|---|---|---|
| 1.0 s | 59.6° | 0.01 |
| 1.5 s | 104.9° | 0.14 |
| 2.0 s | 88.2° | 0.09 |
| 2.5 s | 1030.3° | 2.71 |
| 3.0 s | 1849.0° | 4.98 |

So do not quote a pole-slip count for panel (a) without quoting the horizon
with it — at 2.0 s the angle has not completed a single slip, and at 3.0 s it
has completed five.

### `δ_max` means two different things in two places

This is the one to be careful about, because both numbers are published and they
differ by a factor of six.

| Source | `δ_max` for `m_S1_P0.8_V90` | Measured on |
|---|---|---|
| **Table 10** | 179.9° | the **wrapped** angle |
| **2026-09-01 campaign record** | 1129° | the **unwrapped** angle |

The campaign record reports unwrapped angles throughout — `m_S1_P0.8_V70` at
5061° and the excluded `m_S1.5_P0.8_V70` at 3058° are the other two four-figure
entries. Table 10 reports the wrapped quantity, which saturates just under 180°
the first time a machine goes over the top.

**Neither is wrong, but they are not the same measurement and must not be
compared.** If you are checking Table 10 against the campaign record and find a
factor of six on this column, that is why.

It also explains a feature of Table 10 that would otherwise look like a
coincidence: **both loss-of-synchronism rows sit at essentially exactly 180°**
(179.9 and 180.0). They are not two events that happened to peak at the same
place. They are two events that both went over the top, reported through a
quantity that cannot exceed 180.

### And the unwrapped value is not reproducible either

The run above gives 1849° against the campaign's 1129° for the same cell.

Two candidate causes and **the archive does not distinguish them**: the campaign
record does not state its simulation horizon, and the horizon table above shows
1129° would correspond to about 2.55 s, so a shorter horizon would account for
it exactly. But so would ordinary run-to-run trajectory difference after
divergence, which is the same mechanism that makes `V_post/V_pre` indeterminate.

So do not read either figure as a measurement of how far this machine goes. The
statement that survives is the qualitative one — it goes over the top and keeps
going — and the outcome, which both runs give identically.

The same reasoning applies to `V_post/V_pre`, which is the PCC voltage at the
end of the window over its pre-fault value. On a trajectory slipping four to
five times a second and accelerating, the end-of-window value depends on where
the window falls within a slip cycle — and therefore on solver step selection,
tolerances, and the order the algebraic loop resolves in. Two runs of the same
model with different step histories separate on it. **The quantity is not
well-posed to three significant figures, and no implementation of this campaign
can make it so.**

`δ_max` is not affected, because it is measured on the **wrapped** angle and
saturates at 179.99° the first time the machine goes over the top. That is why
it reproduces to +0.1 % while `V_post/V_pre` does not. If you measure `δ_max`
on an unwrapped angle you will get 1849° for this cell, not 179.9°.

What *is* reproducible about panel (a), and what the paper actually claims, is
the outcome: this cell loses synchronism, at both fault depths including the
shallower one, while every cell at `SCR ≥ 2` rides through at both powers and
both depths. That is reproduced exactly, and it is the finding Section 6.3
rests on.

Two consequences for anyone using this repository:

- Quote the pre-fault and during-fault quantities of the loss-of-synchronism
  cells with confidence; they reproduce.
- Read `V_post/V_pre` there as an indication that the plant did not recover,
  which is what it is, and not as a quantity determined to three digits. The
  published value remains correct for the run that produced it.

The cells that recover carry no such caveat: their trajectories never diverge,
and all seven quantities reproduce. See the agreement table for
`m_S3_P0.8_V90` in [`tab10_fault_phases.md`](tab10_fault_phases.md).

**One residual uncertainty, separate from the above.** Section 6.3 never states
which controller it used. It studies one design across grid strengths and is not
a baseline-versus-optimised comparison — that is Section 6.4 — and the text
never names the design. `b7_build_operating_point` loads the GA-optimised design
of Table 5 by assumption, with the reasoning recorded in the file. This was
tested: running the same point against the CFRD baseline changes the
during-fault quantities by less than 0.2 %, so the controller is not what sets
them. A co-author confirming the design would remove the assumption; it would
not change the reasoning above about post-divergence quantities.

## Method notes that matter for the numbers

**Retained voltage is the plateau, not the minimum.** Fault inception excites a
transient over roughly the first fifth of the window: at `SCR = 1, P = 0.8` pu
the PCC voltage swings between 0.627 and 1.099 pu and then settles at 0.92–0.94.
Taking the instantaneous minimum returns 0.627 pu where the sustained level is
0.935 pu. `b7_metrics` discards the first 20 % of the window and takes the
median of the rest.

**Current magnitudes carry the `1/sqrt(3)`** of the per-unit convention. Without
it the peak rotor current reads 1.864 pu instead of 1.076 pu.

**Admissibility is decided by the guard, not by depth.** A run is excluded when
`u_dc` reaches the 0.50 pu division guard of Section 2.2, and that is tested
before any other outcome, so a run outside the model's valid range is reported
as excluded and never as a failure to ride through. How far `u_dc` falls depends
on dispatch and grid strength as well as on the retained voltage, so the screen
is applied run by run. Table 10 contains admissible runs deeper than the
excluded one.

## One source fraction is not stored

The campaign record holds the source fraction for fifteen of the sixteen points.
The deep event at `SCR = 1, P = 0.4` pu has none. `b7_campaign` calibrates it by
bisection against the target retained PCC voltage, which is how all of them were
obtained originally. It is not invented, and it costs a few extra simulations.

## Files

| File | Role |
|---|---|
| `SIMULATION/b7_campaign.m` | Driver over the matrix |
| `SIMULATION/b7_point.m` | One point, traces first then metrics |
| `SIMULATION/b7_arm_mechanisms.m` | Mirrors the repository and arms the three enables |
| `SIMULATION/b7_enable_per_machine_logging.m` | Restores per-machine logging |
| `SIMULATION/b7_fetch_per_machine.m` | Reads the per-machine traces back |
| `SIMULATION/b7_build_operating_point.m` | Assembles and solves the pre-fault point |
| `SIMULATION/b7_metrics.m` | The Table 10 columns |
| `SIMULATION/b7_calibrate_depth.m` | Bisection of source fraction to retained PCC |
| `SIMULATION/b7_cleanup.m` | Removes the armed mirror |

## See also

[`tab10_fault_phases.md`](tab10_fault_phases.md) — the full sixteen-point matrix
and its outcome column.
