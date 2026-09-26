# Table 3 — Baseline design specifications

**Section 2.5** · the frequency-domain specifications the coordinated design is
built from, and the time-domain set it replaced.

**Status: `verified`.** Every value read from the source at the line cited.

---

## Where the numbers live

Declared as constants at the head of
[`CONFIGURATION/CONFIG_POWER_SYSTEM.m`](../CONFIGURATION/CONFIG_POWER_SYSTEM.m).
There is no script to run: these are inputs, not results.

## Frequency-response specifications — the baseline of the paper

`CONTROL_TYPE = 2`. Lines 305–313.

| Loop | Phase margin `φ_m` | Crossover `ω_o` |
|---|---|---|
| VSMP | 67.2° | 8.07 rad/s |
| VSMQ | — | 2.0 rad/s |
| RSC d / q | 65.7° / 65.7° | 2184 / 2184 rad/s |
| VDC | 65.5° | 109.9 rad/s |
| GSC d / q | 65.7° / 65.7° | 2184 / 2184 rad/s |

**VSMQ carries no phase margin, and that is not an omission.** Its margin is
already fixed by the droop structure, which is why Section 4.1.2 optimises only
its crossover frequency. Six loops carry a phase-margin specification, not
seven, and that six is what the feasibility test of Section 4.1.4 counts.

## Time-response specifications — the design this one replaced

`CONTROL_TYPE = 1`. Lines 246–278. Retained because Figure 5 shows the
eigenvalues it produces, as the contrast against the coordinated design.

| Loop | 2 % settling time | Damping ratio |
|---|---|---|
| VSMP | 1 s | `1/sqrt(2)` |
| VSMQ | 2 s | droop `D_Q` = 900 VAr/V |
| RSC | 4 ms | `1/sqrt(2)` |
| VDC | 80 ms | `1/sqrt(2)` |
| GSC | 4 ms | `1/sqrt(2)` |

This is the **TRD** design of Figure 5: tuned loop by loop, ignoring
intra-machine interactions. The **CFRD** baseline of Figure 6 accounts for them.

> **A naming inconsistency in the paper.** Section 3.3 introduces the
> coordinated design as **FRD** while the rest of the text calls it **CFRD**.
> They are the same design. This repository uses CFRD, and the saved file is
> `RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat`.

## The reuse check, and why it can silently give you the wrong design

`CONTROL_REDESIGN = false` makes `CONFIG_POWER_SYSTEM` load a saved design
instead of recomputing it. Before reusing one it compares the saved
specifications against the constants above — lines 580–596 — and redesigns if
any differ.

**The comparison is not complete.** For the frequency-response set it checks
only VSMP `Fm` and `wo`, and VDC `Fm` and `wo`. It does **not** check the RSC or
GSC specifications.

So: edit `FRD_SPECS.RSC.wo` or `FRD_SPECS.GSC.Fm`, leave `CONTROL_REDESIGN =
false`, and the run will silently reuse a design built from the old values. If
you change any inner-loop specification, set `CONTROL_REDESIGN = true` for that
run.

## What the baseline achieves, and where it does not

The specifications above are targets. Table 6 reports what the design actually
realises, and Section 5.2 records that five of the six specified loops land
slightly **below** target — an interaction penalty, bounded: every realised
margin stays within 4.8° of target, none falls below 55°, and all six remain
inside the `[50°, 90°]` band that defines feasibility.

The one quantity the baseline does not hold across the envelope is its VSM
active-power margin, which moves 8.61° between grid-strength endpoints, from
67.28° to 58.67°. The optimised design moves by at most 1.76°. That contrast is
the whole argument of the paper, and it is visible by comparing this table
against Table 6.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/CONFIG_POWER_SYSTEM.m` | `FRD_SPECS` and `TRD_SPECS` |
| `CONTROL/CONTROL_DESIGN_FR.m` | Coordinated frequency-response design |
| `CONTROL/CONTROL_DESIGN_TR.m` | Time-response design |
| `RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat` | The saved CFRD baseline |
| `RESULTS/CONTROL/LIN_MODEL_TRD_DESIGN.mat` | The saved TRD design |

## See also

[`tab05_optimized_params.md`](tab05_optimized_params.md) — the same quantities
after optimisation · [`tab06_achieved_margins.md`](tab06_achieved_margins.md) —
what is realised rather than specified.
