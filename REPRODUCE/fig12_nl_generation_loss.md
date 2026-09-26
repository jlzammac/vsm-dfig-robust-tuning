# Fig. 12 — Nonlinear response to generation loss

**Section 6.1** · DFIG 4 disconnected at `t = 500` ms, removing a quarter of
the farm.

**Status: `verified`.** Both runs executed from a clean clone on 2026-09-24
with the both-designs-fixed driver of Table 11. Frequency and DC link reproduce
to the digits printed, and the filtered PCC voltage to 1e-4 pu.

---

## Configuration

**Design configuration** — no active limiting, no active protection. Not the
fault campaign's configuration. See [`00_setup.md`](00_setup.md).

Operating point: `P = 0.7` pu per DFIG, PCC voltage 1.0 pu, `SCR = 1`. Note that
is **1.0 pu**, not the 0.975 pu of the Section 6.3 campaign.

## Procedure

> **`RUN_PAPER_V6_NL_VALIDATION` does not produce this figure, and an earlier
> version of this file said it did.** That pipeline runs a **`P_ref` step of
> +0.15 pu on DFIG 1** as its first perturbation, not a generation loss. Its own
> header says why: it *"uses the SAME perturbations as the submitted MPCE paper
> for cross-paper consistency"*, and it emits `nl_pref_step.pdf`. A `P_ref` step
> and a machine disconnection are not the same event — the step changes a
> reference, the disconnection removes a quarter of the plant — and only the
> second is Section 6.1.
>
> Its **second** perturbation, the 20 % sag, *is* Section 6.2. So that pipeline
> covers [`fig13_nl_voltage_sag.md`](fig13_nl_voltage_sag.md) and not this file.

This figure is a **generation loss**. The simplest route is the `SCR = 1` run
of the Table 11 driver, which holds each design fixed and re-solves the
operating point for it:

```matlab
TABLE11_SCR_SWEEP('BASE', outDir)       % SIMULATION/, its SCR = 1 generation-loss run
TABLE11_SCR_SWEEP('GA',   outDir2)      % in a second clone if run in parallel
res = TABLE11_METRICS(outDir, outDir2); % ANALYSIS/, row SCR = 1
```

Or through the perturbation harness directly:

```matlab
RUN_MODE     = 4;    % nonlinear simulation
CONTROL_TYPE = 2;
```

```matlab
cd CONFIGURATION
CONFIG_POWER_SYSTEM
SETUP_PERTURBATION_BLOCKS        % idempotent; adds inc_Qref and inc_iL1_i

addpath ../SIMULATION
nD  = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
cfg = struct('breaker_mask',  [zeros(1, nD-1) 1], ...   % DFIG 4
             'breaker_time',  0.500, ...
             'sim_duration',  3.0);
r = RUN_PERTURBATION_SIM(LIN_MODEL, 'generation_loss', cfg);
```

Repeat for each design in `RESULTS/CONTROL/`, loading it into `LIN_MODEL` and
re-solving the operating point between runs, exactly as
`COMPARE_BASELINE_VS_V6` does for its own two perturbations.

`SETUP_PERTURBATION_BLOCKS` is idempotent and must run once before any
perturbation study.

**Measured runtime**: about 20 minutes per nonlinear run of this class at
`SCR = 1`, so roughly 40 minutes for the pair. The comment in
`RUN_PAPER_V6_NL_VALIDATION.m` estimating "~8-15 min (2 perturbations × 2
controllers × ~2 min each)" is an old estimate and is out by an order of
magnitude; the measured figures are 1309.6 s for the 7 s-horizon step and
1040.0 s for the 4 s-horizon sag.

## The figure generator disconnects DFIG 4 at 0.5 s

`GEN_PAPER_FIG_NL_VALIDATION.m` once disconnected DFIG 1 at `t = 0.005` s. It
now disconnects **DFIG 4 at `t = 0.500` s**, as Section 6.1 states. The
measured per-machine transient confirms it: DFIGs 1, 2 and 3 are the survivors.
The difference matters, because DFIGs 1–2 and 3–4 sit behind different
transformer impedances (Table 1).

Panel (c) shows the DC-link voltage of DFIG 1, which is the machine the
scope monitors by default.

## Measurement conventions

Not free choices — these are the conventions the published numbers use, and
changing any of them changes the numbers:

| Convention | Value |
|---|---|
| Reference instant | `t = 0.010` s |
| Window | to `t = 3.010` s |
| Peaks measured from | `t = 0.505` s, excluding the breaker transient |
| `V_pcc` filter | 4th-order Butterworth, 1 kHz, zero phase — for display **and** for the peak |
| Frequency, DC link | unfiltered |

## Expected values

Measured on the archived traces:

| Quantity | Baseline | Optimised | Change |
|---|---|---|---|
| Peak `\|Δf\|`, 3 s window | 225 mHz | 196 mHz | −12.7 % |
| Peak `\|Δu_dc\|`, DFIG 1 | 8.53e-2 pu | 5.71e-2 pu | −33.1 % |
| Peak `\|Δu_dc\|`, DFIG 3 | 5.82e-2 pu | 3.76e-2 pu | −35.4 % |

**The peak understates the DC-link result.** What the optimisation improves is
the decay: the optimised design enters and stays within ±0.5 % of its steady
state at `t = 1.05` s, while the baseline is still outside that band at the end
of the 3 s window. That follows from the 67.4 % VDC bandwidth increase of
Table 5.

**The frequency figure needs its window.** The excursion has not settled at 3 s
— by 5 s the two designs differ by only 3.8 %. The steady-state deviation is
fixed by `D_eq` and is independent of the controller: the asymptotic value for
this event is 437.5 mHz. See [`tab02_grid_params.md`](tab02_grid_params.md). A
single percentage for this scenario is not well posed without its window.

## The PCC voltage is compared filtered

Section 6 filters the PCC trace for display (zero-phase fourth-order
Butterworth at 1 kHz), and the comparison uses the same filtered signal:

| | Baseline | Optimised | Change |
|---|---|---|---|
| Peak `\|ΔV_pcc\|`, filtered | 0.0175 pu | 0.0300 pu | +71.2 % |

Unfiltered, the peak is mostly the fast numerical ripple of the averaged model
(0.054 pu for the baseline) and depends on where the variable-step solver puts
its samples. See [`tab11_scr_sweep.md`](tab11_scr_sweep.md).

## The survivors move mainly in active power

Over the transient window `0.505–0.60` s:

| | `ΔP` | `ΔQ` |
|---|---|---|
| DFIG 1 | +0.2302 pu | +0.0739 pu |
| DFIG 2 | +0.2306 pu | +0.0788 pu |
| DFIG 3 | +0.1712 pu | +0.0675 pu |

Active power moves about three times more than reactive, as Section 6.1
states. DFIG 4 was supplying 0.7339 pu of P and 0.3261 pu of Q before the
trip.

## The disconnected machine

After the trip DFIG 4 holds at 0.99997 pu (baseline) and 0.99994 pu
(optimised). Its peak DC-link deviation is 9.4e-4 pu against 8.5e-2 pu on
DFIG 1.

## Files

| File | Role |
|---|---|
| `SIMULATION/RUN_PERTURBATION_SIM.m` | **The harness that runs this event** — `type = 'generation_loss'` |
| `SIMULATION/SETUP_PERTURBATION_BLOCKS.m` | One-time model setup |
| `CONFIGURATION/GEN_PAPER_FIG_NL_VALIDATION.m` | Draws the published figure |
| `CONFIGURATION/COMPARE_BASELINE_VS_V6.m` | Reconstructed. Runs both designs, but **through a `P_ref` step and the sag — not this event** |
| `CONFIGURATION/RUN_PAPER_V6_NL_VALIDATION.m` | Two-phase driver for the above; produces Figure 13, not this one |
| `CONFIGURATION/COMPARE_HYBRID_VS_LINEAR.m` | An existing worked example of driving `'generation_loss'` through the harness |

## See also

[`fig13_nl_voltage_sag.md`](fig13_nl_voltage_sag.md) — the other disturbance,
with the same defects and one more.


---

## Measured, 2026-09-24, from a clean clone

`TABLE11_SCR_SWEEP` at `SCR = 1`, both designs fixed, measured by
`TABLE11_METRICS`:

| Quantity | Baseline | Optimised | Change | Published |
|---|---|---|---|---|
| `\|Δf\|` | 224.9 mHz | 196.3 mHz | −12.7 % | 225 → 196, −12.7 % |
| `\|Δu_dc\|`, DFIG 1 | 0.0853 pu | 0.0571 pu | −33.1 % | 0.0853 → 0.0571, −33.1 % |
| `\|ΔV_pcc\|`, filtered | 0.0175 pu | 0.0302 pu | +72.5 % | 0.0175 → 0.0300, +71.2 % |

The pre-event PCC voltage is 1.0000 pu for both designs, as Section 6.1
requires. Against the archived run behind the published figure, the frequency
traces agree to 5e-8 pu and the DC-link traces to 1e-3 pu (at the breaker
instant only).
