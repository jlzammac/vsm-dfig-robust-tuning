# Fig. 13 — Nonlinear response to a grid voltage sag

**Section 6.2** · symmetric sag, 20 % depth, 150 ms, at `SCR = 1`.

**Status: `verified`.** Executed end to end from a clean mirror on 2026-09-23.
**All three quantitative claims of Section 6.2 reproduce**: the 27.5 % DC-link
reduction at 27.2 %, the frequency agreement at 0.13 %, and the ~2 % voltage
agreement at 1.64 % on the filtered trace. Absolutes to better than 1 %. The
measurements are at the end of this file, along with one correction under
discussion that would break the third.

---

## Configuration and procedure

Design configuration, `RUN_MODE = 4`, `CONTROL_TYPE = 2`. Operating point
`P = 0.7` pu, PCC 1.0 pu, `SCR = 1`.

**This figure is the one `RUN_PAPER_V6_NL_VALIDATION` actually produces** — its
second perturbation, emitted as `nl_voltage_dip.pdf`:

```matlab
cd CONFIGURATION
CONFIG_POWER_SYSTEM              % RUN_MODE = 0 first, to get LIN_MODEL
RUN_PAPER_V6_NL_VALIDATION       % Phase 1 sets up the blocks, Phase 2 compares
```

Its **first** perturbation is a `P_ref` step carried over from a different
paper, and is **not** Section 6.1. See
[`fig12_nl_generation_loss.md`](fig12_nl_generation_loss.md), which states what
does produce Section 6.1.

> `COMPARE_BASELINE_VS_V6.m`, which Phase 2 runs, is a **reconstruction**. Its
> only copy was lost and it was rebuilt from its sibling
> `COMPARE_BASELINE_VS_V4.m` (**not shipped** — it drives the superseded v4
> design and reproduces nothing in this paper), from the specification in
> `RUN_PAPER_V6_NL_VALIDATION.m`, and from the channel map in
> `PLOT_SCOPE_SIM.m`. Its header says so.

**Measured runtime**: 1040.0 s for this perturbation per design, so about 35
minutes for the pair, plus the same again for the `P_ref` step the pipeline runs
first and this figure does not need.

```matlab
pertConfig.sag_depth      = 0.20;
pertConfig.sag_start_time = 0.5;
pertConfig.sag_duration   = 0.15;
```

## Where the sag is applied, and why 20 % is not 20 %

**`sag_depth = 0.20` scales the grid source, which sits behind the Thevenin
impedance.** It is not a 20 % drop at the PCC.

Measured: the PCC falls to **0.9190 pu raw** (0.9517 on the filtered trace that
is drawn) from a pre-event 1.0029 — an **8.4 % drop at the PCC for a 20 % drop
at the source**.

At `SCR = 1` the impedance is large and the farm keeps injecting current
throughout the event, so the PCC sits far above the source. The current text
says *"approximately 0.95 pu"*, which agrees with the filtered trace. Without
stating **where** the sag is applied, the 20 % and the 0.95 look contradictory.

> The submitted version said the PCC fell to 0.8 pu. That was corrected in the
> revision. If you are working from an older draft, check this first.

## Expected values

| Quantity | Baseline | Optimised | Change |
|---|---|---|---|
| Peak `\|Δu_dc\|`, DFIG 1 | 8.187e-2 pu | 5.94e-2 pu | −27.5 % |
| Peak `\|Δu_dc\|`, DFIG 3 | 6.460e-2 pu | 5.66e-2 pu | −12.4 % |
| Frequency excursion | — | — | < 0.2 % between designs |

**The two machine pairs differ by 21.1 %** — 8.187e-2 against 6.460e-2 pu on the
baseline. Within each pair the difference is exact zero to the bit. The cause is
in Table 1: G3 and G4 sit behind exactly twice the transformer impedance of G1
and G2. See [`tab01_benchmark_params.md`](tab01_benchmark_params.md).

The optimised design enters the ±0.5 % band at `t = 1.40` s; the baseline does
not enter it within the window at all. As in Figure 12, the decay is the result
and the peak understates it.

### One way the reconstruction's conventions differ from the published ones

The values above come from the archived traces, measured under the published
conventions. `COMPARE_BASELINE_VS_V6` uses the same event instant and window,
but not the same start for the peaks, and that difference is stated here rather
than discovered:

| | Published | The reconstruction |
|---|---|---|
| Event instant | `t = 0.500` s | `t = 0.500` s |
| Peaks measured from | `t = 0.5005` s — the first 0.5 ms excluded | the event instant, **nothing excluded** |
| Evaluation window ends | `t = 3.010` s | `t = 3.010` s |

The exclusion is the one to watch. `COMPUTE_PERTURBATION_METRICS` takes
`idx_post = t >= t_pert` with no offset, so a peak taken from it **includes the
switching transient at sag inception**. For this event that transient is half a
millisecond long and the published offset is correspondingly small, so the
effect is minor — but it is not zero, and for the **generation-loss** event the
published offset is 5 ms and the breaker transient reaches 0.74 and 3.22 pu
filtered, which would dominate any peak that included it.

**So: quote the values in the table above, which are measured under the
published conventions.** A reconstruction run will land near them and not on
them, and this difference is why.

Measured with the reconstruction from a clean clone on 2026-09-25, event at
0.5 s: `|Δu_dc|` of DFIG 1 goes from **0.0814** to **0.0590** pu, **−27.5 %**,
against the published 8.187e-2 → 5.94e-2, −27.5 %. The PCC falls to **0.9190**
pu raw. The change reproduces exactly. The absolutes are about 0.6 % lower
because the reconstruction measures its peaks from the event instant.

---

## Measured: the reconstruction executed end to end, 2026-09-23

Four nonlinear runs — two designs × two perturbations — on R2026a from a clean
mirror. 66 minutes of wall clock. Against the three quantitative claims of
Section 6.2:

| Claim | Published | Measured here | |
|---|---|---|---|
| Peak `\|Δu_dc\|` reduced by | **27.5 %** | **27.2 %** | ✔ 0.3 pp |
| Frequency excursions differ by | < 0.2 % | **0.13 %** | ✔ |
| Peak voltage deviation agrees to | about 2 % | **1.64 %** filtered | ✔ |

All three reproduce. The third only on the **filtered** trace, which is what the
sentence is about — on the raw signal it is 5.7 %. Worked through below.

And the absolute DC-link values, against the archived traces:

| | Archived | Measured | Error |
|---|---|---|---|
| Baseline peak `\|Δu_dc\|` | 8.187e-2 pu | 8.120e-2 pu | −0.8 % |
| Optimised peak `\|Δu_dc\|` | 5.94e-2 pu | 5.914e-2 pu | −0.4 % |

**The headline claim of Section 6.2 reproduces**, from a reconstructed driver,
to better than one per cent on the absolutes and 0.3 percentage points on the
reduction.

### The voltage claim is a FILTERED figure, and it is correct

The raw signal gives 5.7 %, not 2 %. Rather than leave that as a discrepancy it
was measured both ways, applying the published display filter — 4th-order
Butterworth, 1 kHz, zero phase — to the saved traces:

| | Baseline | Optimised | Change |
|---|---|---|---|
| PCC nadir, **raw** | 0.9258 | 0.9216 | |
| deviation, raw | 0.0743 | 0.0785 | **+5.67 %** |
| PCC nadir, **filtered** | 0.9509 | 0.9501 | |
| deviation, filtered | 0.0491 | 0.0499 | **+1.64 %** |

**+1.64 % against a claimed "about 2 %". The published sentence is right**, and
it is a statement about the filtered trace — which is consistent, because the
same sentence's *"approximately 0.95 pu"* is the **filtered** nadir, 0.9509
measured here, and not the raw 0.9258.

Section 6.1 uses the filtered trace in the same way: 0.0175 → 0.0300 pu. See
[`fig12_nl_generation_loss.md`](fig12_nl_generation_loss.md).

### One quantity the paper does not report, and it is the mechanism

```
peak i_GSCq    baseline 0.039952    optimised 0.054246    +35.8 %
```

**The optimised design draws 35.8 % more GSC q-axis current during the sag.**
Both values sit far below the 0.34 pu GSC rating, so nothing is violated. It is
the other side of the faster DC-link regulation that the 67.4 % VDC bandwidth
increase delivers.

## Both axes are excited

As Section 6.2 states, the sag removes active power as well as raising reactive
power. Measured on the baseline run:

| Quantity | Pre-event | During the sag | Change |
|---|---|---|---|
| Machine `P` | 0.7282 pu | 0.4566 pu | **−37.3 %** |
| Grid-side `P` | −0.6647 pu | −0.4655 pu | −30 % |
| Machine `Q` | 0.2692 pu | 0.5752 pu | **+114 %** |

Net active-energy deficit over the 150 ms: **−0.0185 pu·s**, which is what
moves the frequency. On clearance `P` overshoots to 0.8208 pu at `t = 0.70` s.
The two designs respond almost identically, differing by less than 0.2 % in
frequency excursion.

## The virtual impedance acts on both axes

Section 6.2 calls the parameters *"Q-axis virtual impedance"*. There is no Q
axis. The reference is formed as

```
irdq_ref = 1/Lm · (Fs_ref − Lv·it_dq − Ls·is_dq)
```

where `it_dq` is the **complete dq phasor**, so `Lv` multiplies real and
imaginary parts alike. In the linear analysis it is written as two equations,
one per axis, both carrying `Lv`. It is a virtual inductance inside the stator
flux reference of the VSMQ loop, acting on both axes.

The virtual resistance is zero, so any statement about the virtual impedance in
this figure concerns `L_v` alone — see
[`tab05_optimized_params.md`](tab05_optimized_params.md).

## The panel (c) defect

As in Figure 12, and worse here: colour carries the machine pair, line style the
design, and the axis is fixed at `[0.90, 1.10]` for a phenomenon that fits in
0.16 pu. The two pairs oscillate almost in phase, so they overlap. The baseline
is not missing from panel (c) — it is underneath.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/RUN_PAPER_V6_NL_VALIDATION.m` | Two-phase driver; **this figure is its second perturbation** |
| `CONFIGURATION/COMPARE_BASELINE_VS_V6.m` | Reconstructed; runs both designs |
| `SIMULATION/RUN_PERTURBATION_SIM.m` | The harness |
| `SIMULATION/COMPUTE_PERTURBATION_METRICS.m` | The metrics, including `nadir_V = results.Vpcc` |
| `ANALYSIS/CHECK_RAW_VS_FILTERED_PCC.m` | The raw-against-filtered measurement above |

## See also

[`tab11_scr_sweep.md`](tab11_scr_sweep.md) — the same two disturbances across
grid strength.
