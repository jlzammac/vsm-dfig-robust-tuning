# Section 4.1.3 — Is the linear surrogate fitness good enough?

**Section 4.1.3** · six percentages, no figure and no table.

**Status: `verified`.** The paper states the ordering — the purely linear
design is better than the hybrid one on the nonlinear objectives at both
operating points — and no percentages. The ordering reproduces under two
different generation-loss events (executed 2026-09-24 and 2026-09-25). The six
percentages of earlier drafts are event-dependent and are not claimed.

---

## Why this file exists

Section 4.1.3 is the justification for the central methodological choice of the
paper: the genetic algorithm evaluates a **linear** surrogate fitness, not the
nonlinear model. It is the reason the optimisation takes 21.5 h instead of
weeks.

The claim carries six numbers and no figure or table, so it is easy to overlook
when checking that everything in the paper is reproducible. It is listed here
for that reason.

## What is claimed

For Phase 1 a **hybrid** fitness was also run. It kept `J1` and `J2` and added
three objectives evaluated on the full nonlinear model inside the optimisation
loop:

| | Objective |
|---|---|
| (a) | integral of absolute error of the frequency deviation |
| (b) | peak rate of change of frequency over the first 500 ms |
| (c) | frequency nadir deviation |

Both designs were then re-evaluated under identical nonlinear conditions at two
operating points. **The purely linear design is better on all three nonlinear
objectives at both points**, with the hybrid worse by:

| Operating point | (a) | (b) | (c) |
|---|---|---|---|
| designated | 11.6 % | 40.0 % | 6.6 % |
| optimisation | 11.2 % | 41.3 % | 6.4 % |

The conclusion is that evaluating the nonlinear model inside the loop buys
nothing measurable and costs a great deal of time.

**This is a counter-intuitive result and it is the interesting part.** The
hybrid fitness optimises the nonlinear objectives directly and still loses on
them. Treat a reproduction that shows the hybrid winning as a signal to check
the setup before concluding the paper is wrong — but see the caveat below,
because there is one input this repository cannot yet pin down.

## What the comparison does and does not cover

It compares the two **selected** designs — the compromise solution of each
Pareto front — not the nonlinear-best member of either front. And it covers one
of the five phases, not all five.

Both limits are properties of the experiment and Section 4.1.3 states them. A
reproduction that compares front members rather than selected designs is
answering a different question.

## Procedure

```matlab
cd CONFIGURATION
CONFIG_POWER_SYSTEM              % RUN_MODE = 0, CONTROL_TYPE = 2
COMPARE_HYBRID_VS_LINEAR
```

Four nonlinear runs — two designs × two operating points — at a 7 s horizon.
Budget an hour or more.

Both designs are versioned, so nothing here requires re-running the GA:

| File | Design |
|---|---|
| `RESULTS/CONTROL/LIN_MODEL_PDS_OPT_BIOBJ.mat` | Phase 1, linear surrogate only |
| `RESULTS/CONTROL/LIN_MODEL_PDS_OPT_HYBRID.mat` | Phase 1, hybrid fitness |

## The two operating points

Section 4.1.1's pair, and **neither implies the other**:

| | Specified by | P | Voltage | SCR |
|---|---|---|---|---|
| designated | the **source** voltage | 0.7 pu | `\|v_g\| = 1` pu | 1 |
| optimisation | the **PCC** voltage | 0.8 pu | `V_pcc = 0.975` pu | 1 |

See [`00_setup.md`](00_setup.md), including the label drift between nominal and
realised dispatch.

## Configuration

**Design configuration** — no limiting, no protection. As every result outside
Section 6.3. See [`00_setup.md`](00_setup.md).

---

## The one input that is declared rather than recovered

`CONFIGURATION/COMPARE_HYBRID_VS_LINEAR.m` is a **reconstruction**. The original
driver could not be read back from storage, and the script was rebuilt from its
sibling `COMPARE_BASELINE_VS_V4.m` for structure — **that file is not shipped
here**, since it drives the superseded v4 design and reproduces nothing in this
paper — from `PLOT_SCOPE_SIM.m` for
the scope channel map, and from the description in Section 4.1.3 for the
specification.

Everything in that specification is explicit **except the disturbance**. The
paper says both designs were "re-evaluated under identical nonlinear
conditions" and does not name the event.

The script therefore declares it, in one place, and warns at run time:

```matlab
DISTURBANCE = struct( ...
    'type',   'generation_loss', ...
    'config', struct('breaker_mask',  [1 zeros(1, nDFIG-1)], ...
                     'breaker_time',  1.0, ...
                     'sim_duration',  7.0, ...
                     'eval_window_f', [1.0, 6.0]));
ROCOF_WINDOW = 0.5;   % seconds after the event, per Section 4.1.3
```

**Generation loss is not a guess pulled from nothing.** All three objectives are
frequency quantities — integral of frequency error, rate of change of frequency,
frequency nadir — and a nadir and a RoCoF are what a **loss of generation**
produces. A voltage sag does not have a frequency nadir in any useful sense. It
is the same event class as Section 6.1. What is not pinned down is the exact
parameterisation: which machine trips, at what instant, over what horizon, and
over what window the integral runs.

### What follows from that, stated precisely

- **The ordering is the robust part** and is what Section 4.1.3 rests on: the
  linear design better on all three objectives at both points. An ordering that
  holds across a class of frequency events is a far weaker thing to ask of a
  disturbance choice than six percentages to three digits.
- **The six percentages printed by this script are not the six percentages in
  the paper** until the disturbance is confirmed, and must not be substituted
  for them.

### How to close it

Two routes, either of which settles it:

1. **A co-author confirms the disturbance** used for the Section 4.1.3 run.
   That is the direct route and costs nothing.
2. **Identify it by measurement.** The published percentages are distinctive —
   40.0 % and 41.3 % on the RoCoF objective are not values a nearby disturbance
   would return by accident. Run the script under a candidate event; if the six
   numbers land, the candidate is the disturbance. If they do not, that is also
   information, and the next candidate is cheap.

Until one of those happens, this file is `drafted` rather than `verified`, and
that word is doing real work here: the procedure is complete and the designs are
versioned, but one input is an assumption and is labelled as one.

## Measured, under two candidate events

Hybrid worse than linear, by:

| Event | Operating point | (a) IAE | (b) RoCoF | (c) nadir |
|---|---|---|---|---|
| **Published** | designated | 11.6 % | 40.0 % | 6.6 % |
| | optimisation | 11.2 % | 41.3 % | 6.4 % |
| DFIG 1 trips at 1.0 s, 7 s horizon (the script's default) | designated | 20.0 % | 1.0 % | 9.0 % |
| | optimisation | 16.5 % | 0.6 % | 9.0 % |
| DFIGs 1 and 3 trip at 5 ms, 5 s horizon (the hybrid fitness's own event, `OPTIMIZER.m`) | designated | 19.4 % | 82.7 % | 9.4 % |
| | optimisation | 18.1 % | 87.7 % | 9.2 % |

**The ordering is robust to the event**: all twelve measured entries are
positive. The size is not, and RoCoF is the most sensitive — it moves from 1 %
to 88 % between the two events, with the published 40 % between them. Neither
candidate is the published event. Quote the ordering, not the percentages,
until the event is confirmed.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/COMPARE_HYBRID_VS_LINEAR.m` | Reconstructed; the driver |
| `SIMULATION/RUN_PERTURBATION_SIM.m` | The harness |
| `RESULTS/CONTROL/LIN_MODEL_PDS_OPT_BIOBJ.mat` | Linear-surrogate design |
| `RESULTS/CONTROL/LIN_MODEL_PDS_OPT_HYBRID.mat` | Hybrid design |

## See also

[`tab08_phase_progression.md`](tab08_phase_progression.md) — what Phase 1
contributes · [`fig08_optimization_workflow.md`](fig08_optimization_workflow.md)
— where Phase 1 sits
