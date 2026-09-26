# Table 11 — Disturbance response across grid strength

**Section 6.4** · the two disturbances of Sections 6.1 and 6.2, repeated at all
four grid strengths.

**Status: `verified`** against the corrected table sent to the co-author on
2026-09-26 (below). Two faults of the original sweep were found and fixed:
the baseline controller had been **re-designed at each grid strength** instead
of held fixed as Section 6.4 states, and the PCC voltage was measured
**unfiltered**, so its peak was mostly numerical ripple. Diagnosed from the
original run logs and files.

---

## Why this table exists

Sections 6.1 and 6.2 are evaluated at `SCR = 1` alone — the weakest condition of
the declared envelope, and the point the controller was optimised at. That is
the worst case, but it is a single point, and **a design offered for weak grids
should be shown across the range it claims** rather than at the one point most
favourable to it.

## Configuration

**Design configuration**, as Sections 6.1 and 6.2. Not the fault campaign's
armed configuration. See [`00_setup.md`](00_setup.md).

## Procedure

```matlab
TABLE11_SCR_SWEEP('BASE', outDir)       % SIMULATION/, 8 runs
TABLE11_SCR_SWEEP('GA',   outDir2)      % in a second clone if run in parallel
res = TABLE11_METRICS(outDir, outDir2); % ANALYSIS/
```

The same two disturbances as
[`fig12_nl_generation_loss.md`](fig12_nl_generation_loss.md) and
[`fig13_nl_voltage_sag.md`](fig13_nl_voltage_sag.md), repeated at
`SCR ∈ {1, 1.5, 2, 3}`, for both designs.

The driver runs the `SCR = 1` row as well, at the same operating point as the
other three (P = 0.7 pu, V_pcc = 1.0 pu), so the whole table comes from one
procedure. Its `SCR = 1` row is the check that the sweep is anchored on
Figures 12 and 13.

## Measurement conventions

Identical to Figure 12 and 13, and they must be:

| Convention | Value |
|---|---|
| Reference | the sample at `t = 0.010` s, the settled pre-disturbance state |
| Peaks measured from | `t = 0.505` s (generation loss), `t = 0.5005` s (sag) |
| Window | to `t = 3.010` s |
| PCC voltage | filtered as drawn: resampled to 10 µs, zero-phase 4th-order Butterworth at 1 kHz |
| Solver grid | each series on its own |

`ANALYSIS/TABLE11_METRICS.m` implements exactly these.

**Why the PCC voltage is filtered.** The averaged model's PCC voltage carries a
fast numerical ripple (the band visible before the event in Figure 12(b)).
Unfiltered, its peak is mostly that ripple — 0.054 against 0.018 pu for the
baseline under generation loss — and it depends on where the variable-step
solver places its samples, so two identical runs give different peaks (0.0643
and 0.0616 pu for the optimised design). Filtered as the figures are, the run
behind Figure 12 and a fresh run agree to 1e-4 pu.

## Expected result

The table under *Measured, both controllers fixed* below. The version printed in
the paper before its correction differs in the `SCR = 1.5`–`3` rows, for the
reason given there.

## What was wrong with the first version of this table

**The baseline was re-designed at each grid strength.** The original sweep ran
each case through `CONFIG_POWER_SYSTEM` with the grid strength overridden. For
the baseline (`CONTROL_TYPE = 2`) the saved design failed the compatibility
check against the new SCR, and the configuration **re-designed the CFRD
controller at that SCR** — every baseline run logs `INCOMPATIBLE: Grid SCR
mismatch … Redesigning and REPLACING saved design`. The GA design
(`CONTROL_TYPE = 7`) was not re-designed. Those rows compared a baseline
re-tuned for each grid against a fixed GA design. A controller is not re-tuned
when the grid changes, and `TABLE11_SCR_SWEEP.m` holds both designs fixed. The
GA frequency and DC-link values of the original runs reproduce to the digit.

**The PCC voltage was measured unfiltered** — see *Measurement conventions*.

## Measured, both controllers fixed — 2026-09-26

Percentage change from baseline to optimised. Negative is better.

| SCR | Gen. loss `\|Δf\|` | Gen. loss `\|ΔV_pcc\|` | Gen. loss `\|ΔV_dc\|` | Sag `\|Δf\|` | Sag `\|ΔV_pcc\|` | Sag `\|ΔV_dc\|` |
|---|---|---|---|---|---|---|
| 1 † | −12.7 % | +71.2 % | −33.1 % | +0.1 % | +0.6 % | −27.5 % |
| 1.5 | −14.1 % | +43.1 % | −33.1 % | +0.2 % | +1.8 % | −19.9 % |
| 2 | −13.8 % | +34.7 % | −33.0 % | +0.4 % | +1.5 % | −12.3 % |
| 3 | −14.2 % | +22.9 % | −34.0 % | +0.6 % | +0.9 % | −0.8 % |

† The `SCR = 1` row is the pair of runs plotted in Figures 12 and 13, as the
paper states. The driver's own `SCR = 1` runs give the same values except
+72.5 % and +1.4 % for the PCC voltage and −27.1 % for the sag DC link, a
difference in the last digit of peaks taken within a millisecond of a switching
event.

Baseline absolutes, for scale: generation loss `|Δf|` 225, 233, 234, 236 mHz,
filtered `|ΔV_pcc|` 0.018, 0.013, 0.010, 0.007 pu and `|ΔV_dc|` 0.085, 0.075,
0.067, 0.056 pu at `SCR = 1, 1.5, 2, 3`; sag `|Δf|` 79, 73, 70, 65 mHz,
filtered `|ΔV_pcc|` 0.049, 0.072, 0.088, 0.111 pu and `|ΔV_dc|` 0.082, 0.088,
0.094, 0.102 pu.

What the table says:

- **The frequency benefit under generation loss is insensitive** to grid
  strength, −12.7 to −14.2 %.
- **The DC-link benefit under generation loss is flat**, −33.0 to −34.0 %.
- **Under the sag the DC-link advantage decays and vanishes at `SCR = 3`**
  (−27.5, −19.9, −12.3, −0.8 %) without reversing.
- **The PCC voltage under generation loss is adverse at every SCR** and shrinks
  as the grid stiffens (+71.2 → +22.9 %).
- Under the sag, frequency and PCC voltage differ by less than 2 %.
- 12 of the 24 entries are adverse, 8 of them by less than 2 %. No metric
  changes sign across the range.

## The DC-link trend runs opposite between the two disturbances

Worth noticing because it is a physical result and not noise. Under
**generation loss** the baseline `|ΔV_dc|` **falls** as the grid stiffens
(0.085 to 0.056 pu); under the **sag** it **rises** (0.082 to 0.102 pu). A
stiffer grid attenuates the power imbalance of a lost machine, but transmits
more of a source-side voltage event to the farm terminals.

## Files

| File | Role |
|---|---|
| `SIMULATION/TABLE11_SCR_SWEEP.m` | **The driver.** Eight runs per design |
| `ANALYSIS/TABLE11_METRICS.m` | The peaks, under the conventions above |
| `SIMULATION/RUN_PERTURBATION_SIM.m` | The harness the driver calls |
| `SIMULATION/COMPUTE_PERTURBATION_METRICS.m` | The metrics |
| `CONFIGURATION/COMPARE_BASELINE_VS_V6.m` | Reconstructed. Covers the sag half at `SCR = 1` only; its other perturbation is a `P_ref` step, not the generation loss |

**Sixteen nonlinear runs** — two disturbances × two designs × four grid
strengths — at roughly 20 minutes each. Budget five hours, and run it in pieces:
each `(disturbance, design, SCR)` triple is independent.


## See also

[`fig12_nl_generation_loss.md`](fig12_nl_generation_loss.md) ·
[`fig13_nl_voltage_sag.md`](fig13_nl_voltage_sag.md) — the `SCR = 1` rows.
