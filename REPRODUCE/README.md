# Reproducing the results of the paper

> **Multi-Objective Optimisation for Robust Control of VSM-DFIG Wind Farms in Weak Grids**

One file per result. Each file states, for that figure or table alone: the section of the paper
it belongs to, the model configuration it requires, the switch settings, the script to run, the
expected runtime, the output file and the expected values. If a `verified` result does not
reproduce, check your setup against [`00_setup.md`](00_setup.md) before anything else.

Read [`00_setup.md`](00_setup.md) first. The status column records, for each result, whether its
procedure has been re-executed here from a clean clone and whether it reproduces the published
values. Where it does not, the file says what differs and, where known, why.

## Status legend

- **`verified`** — the procedure has been executed end to end from a clean clone of this
  repository and reproduces the published values. Where the agreement is not exact, the file
  quantifies it and states the cause.
- **`partial`** — some of the result reproduces and some does not. The file states which is
  which and why.
- **`gap`** — the procedure as stated does not produce the published result. The file says what
  does reproduce, what does not, and what the correct path would be.
- **`drafted`** — the procedure is written from the source that produced the published result,
  and its prerequisites are present and checked, but it has not been re-executed here. The
  distinction is about this repository's own verification record, not about whether the result
  can be obtained.

## Figures

| Paper | Result | File | Status |
|---|---|---|---|
| Fig. 1 | Benchmark one-line diagram (§2.1) | `fig01_system_diagram.md` | verified |
| Fig. 2 | Hierarchical control structure (§2.1) | `fig02_control_architecture.md` | verified |
| Fig. 3 | Baseline stability map (§3.2) | `fig03_baseline_stability_map.md` | verified |
| Fig. 4 | Transmission angle vs power and SCR (§3.2) | `fig04_baseline_line_angle.md` | verified |
| Fig. 5 | Eigenvalues, TRD design (§3.3) | `fig05_eigenvalues_trd.md` | verified |
| Fig. 6 | Eigenvalues, CFRD baseline (§3.3) | `fig06_eigenvalues_frd.md` | verified |
| Fig. 7 | Per-band stability envelope, baseline (§3.3) | `fig07_baseline_perband_envelope.md` | verified |
| Fig. 8 | Five-phase optimisation workflow (§4.2) | `fig08_optimization_workflow.md` | verified |
| Fig. 9 | Eigenvalues, GA-optimised (§5.3) | `fig09_eigenvalues_ga.md` | verified |
| Fig. 10 | Per-band stability envelope, optimised (§5.4) | `fig10_robust_perband_envelope.md` | verified |
| Fig. 11 | Step-response comparison at both endpoints (§5.4) | `fig11_step_response_comparison.md` | verified |
| Fig. 12 | Nonlinear response to generation loss (§6.1) | `fig12_nl_generation_loss.md` | verified |
| Fig. 13 | Nonlinear response to a grid voltage sag (§6.2) | `fig13_nl_voltage_sag.md` | verified |
| Fig. 14 | Fault response across grid strength, all machines (§6.3) | `fig14_nl_fault_4dfig.md` | verified |

Figures 1, 2 and 8 are drawings rather than computed results. Their files state what the drawing
must show to be correct and check each element against the code, which is the only sense in which
a diagram can be verified.

## Tables

| Paper | Result | File | Status |
|---|---|---|---|
| Table 1 | Benchmark electrical parameters (§2.3) | `tab01_benchmark_params.md` | verified |
| Table 2 | External grid dynamic model (§2.4) | `tab02_grid_params.md` | verified |
| Table 3 | Baseline design specifications (§2.5) | `tab03_baseline_specs.md` | verified |
| Table 4 | Optimisation bounds for decision variables (§4.1.2) | `tab04_optimization_bounds.md` | verified |
| Table 5 | Baseline and GA-optimised design specifications (§5.1) | `tab05_optimized_params.md` | verified |
| Table 6 | Achieved loop margins (§5.2) | `tab06_achieved_margins.md` | verified |
| Table 7 | Step-response indices (§5.2) | `tab07_step_indices.md` | verified |
| Table 8 | Phase-by-phase fitness and damping progression (§5.5) | `tab08_phase_progression.md` | verified |
| Table 9 | Comparison of three tuning approaches (§5.6) | `tab09_method_comparison.md` | verified |
| Table 10 | Pre-, during- and post-fault decomposition (§6.3) | `tab10_fault_phases.md` | verified |
| Table 11 | Disturbance response across grid strength (§6.4) | `tab11_scr_sweep.md` | verified |

## Claims with no figure and no table

Three sets of numbers in the paper belong to neither list above, and are easy to
miss for exactly that reason. Each matters out of proportion to its size.

| Paper | Result | File | Status |
|---|---|---|---|
| §2.2 | Where the averaged model stops being valid — the fault-depth floor | `sec022_validity_floor.md` | verified |
| §4.1.3 | Hybrid vs linear surrogate fitness — six percentages | `sec0413_hybrid_fitness.md` | verified |
| §5.7 | Sensitivity to the solver seed | `sec057_seed_sensitivity.md` | verified |

- **§2.2** bounds every large-signal claim in the paper: it is the measurement
  that says how deep a fault the model may be asked about at all.
- **§4.1.3** is the justification for evaluating a **linear** surrogate inside
  the genetic algorithm, which is what makes the optimisation take 21.5 h rather
  than weeks.
- **§5.7** is the paper's own declaration of reproducibility exposure, and the
  Abstract sells it as one of three qualifying results.

## Running the optimisation itself

Every design the paper reports is versioned in `RESULTS/CONTROL/`, so nothing below is needed to
reproduce a published number. But the option to re-run the five-phase optimisation from scratch
**does exist**, and [`run_the_optimisation.md`](run_the_optimisation.md) is the procedure.

Read it before starting: **the distributed settings are `OPT_SEQUENCE = [3 4 5]` with
`INIT_STEP = 1`** — the v6 path that skips Phase 2 — not a five-phase run. That is a 21.5 h
distinction to discover afterwards.

## The paper's figure files carry suffixes, and the plain name is not always the one used

The manuscript includes files named `..._2.pdf`, `..._3.pdf` and
`..._4_bis_onlyoffice.pdf`, and in several cases a plain-named file sits beside
them. **The plain name is sometimes a superseded artefact.** Checked, figure by
figure:

| Published file | Plain-named neighbour | Difference |
|---|---|---|
| `baseline_perband_stability_envelope_4_bis_onlyoffice.pdf` | exists | **superseded band convention** — LF `≤ 30` instead of `≤ 100` |
| `robust_stability_envelope_4_bis_onlyoffice.pdf` | exists | same |
| `step_response_comparison_2.pdf` | exists | re-export; same data, same panels |
| `nl_generation_loss_2.pdf` | — | the generator writes this name |

**The code in this repository produces the published versions**, not the
superseded ones. If you find a plain-named PDF whose labels disagree with the
code, that file is the older one.

## Two configurations, and they must not be pooled

Everything in Sections 3, 5, 6.1, 6.2 and 6.4 uses the **design configuration**: no current
limiting, no chopper, no derate. Only Section 6.3 — Figure 14 and Table 10 — uses the
**verification configuration**, with three protection mechanisms armed.

Numbers from the two configurations are not interchangeable. Running Section 6.3 with the
distributed switch settings, or Section 6.1 with the mechanisms armed, produces a coherent result
that is not the published one. [`00_setup.md`](00_setup.md) states the switches and how to set
them.

## Raw or filtered — the one distinction that decides several numbers

The PCC voltage is filtered (4th-order Butterworth, 1 kHz, zero phase), for display and for
every PCC number the paper quotes. Measuring the raw trace instead is the most efficient way to
conclude the paper is inconsistent when it is not.

| Quantity | Raw | Filtered | The paper quotes |
|---|---|---|---|
| §6.2 retained PCC voltage | 0.9258 | 0.9509 | "approximately 0.95 pu" — **filtered** |
| §6.2 agreement between designs, peak deviation | 5.67 % | **1.64 %** | "about 2 %" — **filtered** |
| §6.1 PCC peak deviation pair | 0.054 → 0.061 (mostly ripple) | 0.0175 → 0.0300, +71.2 % | **filtered** |

All three are filtered-trace figures. Unfiltered, the PCC peak is dominated by
the fast numerical ripple of the averaged model and changes between identical
runs with the solver's sample placement, which is why Table 11 and Section 6.1
compare the filtered trace. See [`tab11_scr_sweep.md`](tab11_scr_sweep.md).

## Where agreement is not exact, and why

Two quantities do not reproduce to round-off, and in both cases the cause is identified rather
than tolerated:

- **Table 10, the post-fault voltage ratio of the cell that loses synchronism.** After a pole
  slip the terminal voltage is not a settled quantity, so a ratio taken over any finite window
  depends on where the window falls relative to the slip. The recovering cells reproduce this
  column to 0.0 %. [`tab10_fault_phases.md`](tab10_fault_phases.md) gives the measured window
  and the resulting spread.
- **The four deep `P = 0.4` points of Table 10** are not depth-matched to each other: the
  retained PCC voltage across that row spans 0.6126–0.6865 pu. The source-side fraction was
  fixed per point, not calibrated to a common retained voltage, so the row compares four
  slightly different disturbances. The archived fractions are in the campaign file and reproduce
  exactly; what does not exist is a common depth.

Neither affects a conclusion drawn in the paper, and both are stated in the files that carry the
affected numbers.

## Runtime

The five-phase optimisation is **21.5 h on four parallel workers**, and is not needed to
reproduce any published number: the resulting designs are versioned in `RESULTS/CONTROL/`. Every
other result is minutes to about half an hour. Each file states its own.

Two runtime figures circulate and they are not the same thing:

| | Figure | What it is |
|---|---|---|
| Paper, §5.1 | **21.5 h** | measured, four workers, M3 Max |
| `CONFIG_POWER_SYSTEM.m:87` | ~25 h | the script's own conservative warning, an estimate |

Quote 21.5 h. Where a file says "about 25 h" it is repeating the script's banner, not
contradicting the paper.

Two different parallel counts also circulate, and conflating them is easy: the **GA** ran on four
workers, while the **225-point envelope sweep** of `RUN_MODE = 2` uses eight. They are different
runs.
