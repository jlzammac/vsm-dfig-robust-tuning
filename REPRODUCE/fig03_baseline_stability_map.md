# Fig. 3 — Baseline stability map

**Section 3.2** · binary stable / not-stable classification over the
operational envelope.

**Status: `verified`.** Sweep executed from a clean clone on 2026-09-23,
2 min 38 s on 8 workers. **223 of 225 converge, 202 stable, 23 not** — and the
per-SCR split comes out **24/45 · 43/45 · 45/45 · 45/45 · 45/45**, exactly as
published, with every failure at `SCR ≤ 1.5`.

---

## What the figure shows

Each of the 225 envelope combinations classified by eigenvalue as stable or
not, for the CFRD baseline.

```
V_pcc ∈ {0.95, 0.975, 1.0, 1.025, 1.05} pu
P     ∈ {0.4 … 1.2} pu per DFIG
SCR   ∈ {1, 1.5, 2, 2.5, 3}
```

## Configuration

**Design configuration.** Arming the protection mechanisms moves 72 of the 223 convergent
points and flips 51 from stable to unstable, so do not. See
[`00_setup.md`](00_setup.md).

## Procedure

In `CONFIGURATION/CONFIG_POWER_SYSTEM.m`:

```matlab
RUN_MODE     = 2;    % linear analysis over the envelope
CONTROL_TYPE = 2;    % CFRD baseline
```

The sweep writes to `RESULTS/LINEAR_ANALYSIS/` with `SWEEP_FRD` in the name.
Cost: 225 points, each an `fsolve` per machine plus a Simulink trim and
linearisation. Use `parfor` if available.

## The count, and the two points that are not instabilities

**23 of 225 are not stable**, all at `SCR ≤ 1.5` and high power transfer — so
**both designs are stable at the same 202 points, none gained by the
optimisation and none lost.**

Per grid strength:

| SCR | Stable |
|---|---|
| 1 | 24 / 45 |
| 1.5 | 43 / 45 |
| 2, 2.5, 3 | 45 / 45 each |

Every failure is at `SCR ≤ 1.5`, and almost all of them at `SCR = 1`. That
concentration is the point of the figure: the envelope is not uniformly
difficult, it is difficult in one corner, and that corner is where the
optimisation is aimed.

**The 202 is an abstract-level claim** — that the optimisation gains no
operating point and loses none — so a reproduction that returns a different
count is worth resolving before going further.

**Two of those 23 are points where the operating-point solve does not
converge.** They are counted as inadmissible, not as demonstrated dynamic
instabilities. That is why the stable and not-stable counts partition the full
225 rather than 223.

The harness enforces the distinction: `b7_build_operating_point` refuses to
simulate a point whose solve residual exceeds `1e-6`, raising an error rather
than producing a trajectory. A non-converged operating point has no dynamics to
classify.

## The invariant worth checking

**The optimised design produces an identical map.** Section 5.4 reports the same
23 points, the same `SCR ≤ 1.5` corner, the same two non-converged.

That identity is the paper's own evidence that **the unstable region is set by
the physical transmission capacity of the network and not by controller
tuning**. It is the claim Figure 3 exists to support, and it is checkable
without re-deriving anything: run the sweep for both designs and compare the two
maps. If they differ, the sweep is wrong before the design is.

## Why the boundary sits where it does

The static transfer capability per machine is `P_max = V_pcc · V_g · SCR` in the
per-unit convention of this benchmark, with `sin δ = P / P_max`. At `SCR = 1`
and `V_pcc = 0.975` pu that capability is 0.975 pu per machine, so dispatching
0.8 pu places the plant at `sin δ = 0.82` of it before anything else happens.

The boundary is an angle limit, not a damping limit, and Section 3.3 shows a
**real** eigenvalue crossing at the power-transfer limit — which is why
constraint (10) of Section 4.1.4 bounds the rightmost real eigenvalue
separately from the per-band damping ratios.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/CONFIG_POWER_SYSTEM.m` | The sweep, `RUN_MODE = 2` |
| `ANALYSIS/LINEAR_ANALYSIS.m` | Per-point solve, linearisation, stability flag |
| `ANALYSIS/EIGEN_CALC.m` | Eigenvalue classification |

## See also

[`fig04_baseline_line_angle.md`](fig04_baseline_line_angle.md) — the
transmission angle behind the boundary ·
[`fig07_baseline_perband_envelope.md`](fig07_baseline_perband_envelope.md) — the
same sweep resolved per frequency band.
