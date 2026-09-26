# 00 — Setup

Read this before any other file in `REPRODUCE/`.

## Requirements

Verified on the configuration below. Earlier releases are untested.

| Component | Verified |
|---|---|
| MATLAB | R2026a Update 4 (macOS, Apple silicon) |
| Simulink | R2026a |
| Control System Toolbox | required |
| Simulink Control Design | required — `operspec`, `findop`, `linearize` |
| Global Optimization Toolbox | required — `gamultiobj` |
| Optimization Toolbox | required — `fsolve` |
| Stateflow | required — the model's MATLAB Function blocks |

The model file is stored in R2025a format, so R2025a should open it, but nothing
in this repository has been run on that release.

Check your installation before starting:

```matlab
for t = {'Simulink','Control_Toolbox','Simulink_Control_Design', ...
         'GADS_Toolbox','Optimization_Toolbox','Stateflow'}
    fprintf('%-28s %d\n', t{1}, license('test', t{1}));
end
```

## First run

```matlab
cd CONFIGURATION
CONFIG_POWER_SYSTEM
```

With the settings as distributed — `RUN_MODE = 0`, `CONTROL_TYPE = 2` — this
solves the operating point and linearises. **Measured: 1.25 s.** It should end with

```
maxErrFsolve : ~5e-9        operating-point solve converged
ssModel      : 80 states
stability    : 1
lineAngle    : 44.427       transmission angle at the designated point
```

If it fails before that, stop and fix it: nothing else in `REPRODUCE/` will work.

## The three switches

`CONFIG_POWER_SYSTEM.m` is the single driver. Its behaviour is set by constants
at the head of the file, which you edit before running.

| Switch | Values |
|---|---|
| `RUN_MODE` | 0 operating point · 1 linear analysis at endpoints · 2 linear analysis over the envelope · 3 GA optimisation · 4 nonlinear simulation · 5 optimum design sequence |
| `CONTROL_TYPE` | 1 time-response design (TRD) · 2 frequency-response design (CFRD, the baseline) · 3–7 GA variants |
| `OPT_SEQUENCE` | Optimisation phases to run, `[1 2 3 4 5]` for Phases 1–5 of Section 4.2 |

Every file in `REPRODUCE/` states the values it needs.

## Two model configurations, and they must never be mixed

Section 2.2 of the paper distinguishes them, and so does this repository.

**Design configuration** — no active limiting, no active protection. This is the
model as distributed. It produces the optimisation and every small-signal result:
Sections 3, 4, 5, 6.1, 6.2 and 6.4.

**Verification configuration** — converter current limiters, DC-link chopper and
RSC voltage derate armed. Used only by the symmetric-fault campaign of Section
6.3.

The three master enables are literal constants inside two MATLAB Function blocks:

| Enable | Block | Distributed value |
|---|---|---|
| `LIM_EN` | `POWER_SYSTEM_FULL/CONTROL` | 0 |
| `RSCBLK_EN` | `POWER_SYSTEM_FULL/CONTROL` | 0 |
| `CHOP_EN` | `POWER_SYSTEM_FULL/DFIG` | 0 |

The DC-link diode clamp has no enable and applies unconditionally, which is why
Section 2.2 names four mechanisms but three enables.

Arming them requires editing the model, so `SIMULATION/b7_arm_mechanisms.m`
**mirrors the whole repository** and edits the mirror. Do not arm the
distributed model. If you do, every small-signal result in this repository
changes.

The check is two sweeps, and the first is the control for the second:

| Sweep | Result |
|---|---|
| Mechanisms **disarmed**, re-linearised at all 225 points | eigenvalues, the seven loop margins and all fourteen designed gains reproduced to **exactly zero difference**, at each of the **223** points where the operating-point solve converges |
| All three enables **set**, same 223 points | **72 points move.** Of those, **51 cross from stable to unstable**, and the largest entrywise difference in `A` is **3.51 × 10⁶** |

The denominator is 223, not 225: two points are where the operating-point solve
does not converge, and a point with no equilibrium has nothing to re-linearise.
See [`fig03_baseline_stability_map.md`](fig03_baseline_stability_map.md).

The first sweep is what makes the second mean anything. Without it, "72 points
move" could be run-to-run noise in the linearisation. Exactly zero difference
over 223 points establishes that it is not.

**The movement is structured by dispatched power, not scattered**, and knowing
where it starts is what makes the rest of this comprehensible:

| Region | Effect of arming |
|---|---|
| `P ≤ 0.7` pu | every point **bit-identical** |
| `P = 0.8` pu on the weakest grid | movement begins |
| above that | spreads as power rises |

The mechanism is specific: **above `P = 0.8` pu the current limiter clamps in
steady state**, so the linearisation is taken about a different equilibrium. It
is not that the mechanisms add dynamics; it is that they move the point the
dynamics are linearised about.

So each mechanism can be demonstrably inert at a given point while the set of
them wrecks the envelope. The derate at the designated operating point is the
clean example: the DC-link voltage there is exactly 1 pu on all four machines,
0.744 band-widths above the upper edge `VDCBLK_HI`, so the blend argument is
saturated and its derivative with respect to `u_dc` is exactly zero.
Re-linearising with the derate armed reproduces `A` and `B` to zero difference
over all sixteen switch combinations tested.

The diode clamp is likewise inert there — it refuses discharge below 0.05 pu,
and at the operating point it has zero derivative as well as zero value.

**Arming them is safe nowhere, but the reason it is unsafe is not the same at
every point**, and below `P = 0.7` pu there is no reason at all.

Why a whole mirror and not just a copy of the `.slx`: `LINEAR_ANALYSIS` changes
into `../SIMULINK` and opens the model by name, so the model path is fixed
relative to the repository root. A copy placed anywhere else is not the file
that gets simulated. This was observed here — arming a detached copy reported
three of three enables armed and then ran the unarmed model, giving a peak rotor
current of 2.12 pu against a 1.074 pu limiter setpoint.

### What the three mechanisms are set to

Section 2.2 describes the mechanisms; it does not tabulate their settings. They
are local constants inside the two function blocks, and this is where to read
them from. Nothing here is tuned to the results: every value is either a machine
rating or derived from one.

**Converter current limiters** (`LIM_EN`), rating-circle clamps on the current
references, not on the measured currents:

| | Value | Origin |
|---|---|---|
| `I_RSC_MAX` | 1.074 pu on `I_b` | the benchmark machine; direct derivation at the model rated point gives 1.0742 pu |
| `I_GSC_MAX` | 0.34 pu on `I_b` | the GSC is sized for slip power, not full power |

The two axes are not treated symmetrically, and which one gets priority differs
between the converters: the RSC clamps `d` first and gives `q` the remaining
room, the GSC clamps `q` first. That asymmetry is a design decision about which
quantity to protect and it is recorded in the block.

**DC-link chopper** (`CHOP_EN`), a hysteretic braking resistor:

| | Value |
|---|---|
| Engage | `V_dc ≥ 1.10` pu = 1320 V |
| Release | `V_dc ≤ 1.05` pu = 1260 V |
| `R_CHOP` | 2.42 pu = 1.6567 Ω |
| Rated dissipation | 0.50 pu = 1.05 MW at `S_b = 2.1034 MVA` |

`R_CHOP` is not picked: it is `VDC_CHOP_ON² / P_chop_rated = 1.10²/0.50 = 2.42`.
The 1.05 pu release leaves 5 % headroom above nominal so that normal transients
never reach it.

**RSC voltage derate** (`RSCBLK_EN`), and this one is worth reading in full
because it is the mechanism most likely to be reimplemented wrongly.

It is keyed on the **DC-link voltage, not the terminal voltage**, and both band
edges are derived from one line rather than chosen. With SVPWM a two-level
bridge synthesises at most `V_dc/√2` of line-to-line rms, so on the rotor base
(`U_r,open = 2070 V`) the converter capability is

```
V_cap(V_dc) = V_dc · 1200/(√2·2070) = 0.409917 · V_dc     [pu, rotor base]
```

Both edges are that line solved against a rotor-voltage demand the model already
quantifies:

| Edge | Demand | Value |
|---|---|---|
| `VDCBLK_LO` | the irreducible back-EMF, `E_r = \|s\|·\|F_s\|·L_m/L_s = 0.152225` pu | 0.371357 pu |
| `VDCBLK_HI` | the full design-slip rotor voltage, 0.30 pu = 621 V | 0.731856 pu |

`|s| = 0.1575228` is **read from the stored operating point** — DFIG state 5,
rotor speed 1.1575228 — not assumed.

Below `VDCBLK_LO` the bridge cannot synthesise even the machine's own back-EMF,
so the averaged model's core assumption — `v_r` imposed exactly as commanded —
is not approximately false there but definitively false. Above `VDCBLK_HI` the
converter has full design authority and the command passes through untouched.

**Keying it on the terminal voltage instead closes a positive feedback loop
through the plant and latches with no state at all**: blocking the RSC removes
the DFIG's excitation, so `V_s` falls further, which deepens the derate.
Measured with that keying, 200 ms after clearance the derate factor was still
0.0000 and the DC link sat at 0.0505 pu and never returned. Keying on `V_dc`
inverts the sign and makes the derate self-releasing. If you reimplement this
against terminal voltage, the cells that recover in Figure 14 will not.

## Determinism

**Model checksum.** The published results used `POWER_SYSTEM_FULL.slx` with
md5 `04fba8fce3bf38c5600f2f894fe3d6b0`, 84 blocks and 3 subsystems. The copy in
this repository has had its document metadata cleared of two author usernames
and has md5 `a62ae9d3963e7a92bd0d776dd3b60418`. All 36 other archive entries are
byte-identical: only `metadata/coreProperties.xml` differs. Block and subsystem
counts are unchanged and were verified by loading it.

**Running the model rewrites it.** `POWER_SYSTEM_FULL.slx` is stored in R2025a format. The
first time R2026a opens and saves it, Simulink rewrites the file and leaves a
`POWER_SYSTEM_FULL.slx.r2025a` backup next to it — measured, the md5 goes from
`a62ae9d3963e7a92bd0d776dd3b60418` to `9d8bd55e746462947c0e2d8610ba8ed6`. A format rewrite,
not a model change. Take your checksum before the first run, and `git checkout
SIMULINK/POWER_SYSTEM_FULL.slx` to get the shipped file back.

**The genetic algorithm is stochastic.** Seeds are fixed and stated per result.
Section 5.7 of the paper reports the measured sensitivity to the solver seed:
J1 varies by ±10.8 % and J2 by ±40.9 % across seeds, measured at one tenth of
the published budget, at which no seed converges. Those figures do not transfer
to the published budget.

**Saved designs.** `RESULTS/CONTROL/` holds the designs the paper reports, so
Sections 5 and 6 reproduce in minutes rather than re-running the 21.5 h
optimisation. Re-running the GA from scratch will not return bit-identical
gains.

## Per-unit convention

| Quantity | Base |
|---|---|
| Voltage | `U_b = 690 V`, line-to-line rms |
| Current | `I_b = 1760 A`, phase rms |
| Power | `S_b = sqrt(3)·U_b·I_b = 2.1034 MVA` |
| Impedance | `Z_b = U_b/I_b = 0.3920 Ω` |
| Inductance | `L_b = Z_b/ω_b = 1.2479 mH`, `f_0 = 50 Hz` |

This base is `sqrt(3)` times the star phase-impedance base of the reference
textbook, so every per-unit impedance here is `1/sqrt(3)` of the corresponding
value there.

**The factor propagates to the code.** Power is computed as
`real(v.*conj(i))/sqrt(3)` throughout, and current magnitudes likewise:
`hypot(id,iq)/sqrt(3)`. Omitting it on the rotor current returns 1.864 pu where
the correct value is 1.076 pu. If a quantity you compute is out by a factor near
1.732, this is why.

## Operating points

Two carry names in the paper, and **neither implies the other**.

| | Specified by | P | Voltage | SCR |
|---|---|---|---|---|
| Designated | the **source** voltage | 0.7 pu | `\|v_g\| = 1` pu | 1 |
| Optimisation | the **PCC** voltage | 0.8 pu | `V_pcc = 0.975` pu | 1 |

`|v_g| = 1 pu` in every result in the paper. The PCC is treated as a **PV bus**:
dispatched power and PCC voltage magnitude are imposed, the Thevenin source is
the slack, and the transmission angle and the **reactive power** are solved. The
farm's reactive dispatch is a dependent variable of that specification, not a
free parameter.

**A known label drift.** The initialisation obtains the transmission angle from
the lossless relation while the line current uses `R_g` with `X/R = 10`. The two
do not close, so the realised power differs from the nominal label:

| Operating point | Nominal | Realised, measured |
|---|---|---|
| Designated | 0.700 pu/DFIG | 0.729–0.734 pu |
| Optimisation | 0.800 pu/DFIG | 0.845 pu |

The equilibrium is self-consistent — `P_ref` is overwritten with the achieved
value — but it is not at the dispatch the label states. Expect this when
comparing against the paper's operating-point labels.

## Where results are written

| Path | Contents |
|---|---|
| `RESULTS/CONTROL/` | Saved control designs. Versioned. |
| `RESULTS/SIMULATION/` | Nonlinear run output. Not versioned. |
| `RESULTS/B7_CAMPAIGN/` | Section 6.3 campaign, traces and summaries. Not versioned. |
| `FIGURES/` | Generated figures. Not versioned. |
| `TEMP/` | Run logs. Not versioned. |

Everything not versioned is regenerated by the procedures in this directory.
