# Table 1 — Benchmark electrical parameters

**Section 2.3** · machine, converter, drivetrain, transformer and collector
parameters of the four-machine wind farm.

**Status: `verified`.** Every value is read from the source at the line cited.
Nothing here is transcribed from the paper.

---

## Where the numbers live

There is no script to run. The table is a listing of
[`MODEL/CONFIG_MODEL.m`](../MODEL/CONFIG_MODEL.m), which is executed by
`CONFIG_POWER_SYSTEM` and populates `LIN_MODEL.MODEL`.

To print them as the model actually loads them:

```matlab
cd CONFIGURATION
CONFIG_POWER_SYSTEM              % RUN_MODE = 0
disp(LIN_MODEL.MODEL.BASE)
disp(LIN_MODEL.MODEL.DFIG.PARAM)
disp(LIN_MODEL.MODEL.GRID.PARAM)
```

Reading the struct is preferable to reading the file: several parameters are
**derived** rather than declared, and the struct holds what the simulation used.

## Per-unit bases

| Quantity | Value | Source |
|---|---|---|
| `U_b` | 690 V, line-to-line rms | `CONFIG_MODEL.m:151` |
| `I_b` | 1760 A, phase rms | `CONFIG_MODEL.m:152` |
| `S_b` | `sqrt(3)·U_b·I_b` ≈ 2.1034 MVA | `CONFIG_MODEL.m:155` |
| `f_0` | 50 Hz | `CONFIG_MODEL.m:159` |
| `Z_b` | `U_b/I_b` = 0.3920 Ω | derived |
| `L_b` | `Z_b/ω_b` = 1.2479 mH | derived |

This base is `sqrt(3)` times the star phase-impedance base of the reference
textbook, so every per-unit impedance here is `1/sqrt(3)` of the corresponding
value there. **The factor propagates into the code**: power is
`real(v.*conj(i))/sqrt(3)` and current magnitudes are `hypot(id,iq)/sqrt(3)`.
See [`00_setup.md`](00_setup.md).

## Farm size

```matlab
nDFIG = 4;    % CONFIG_MODEL.m:174
```

Four machines, 8 MW total. The model is written for any `nDFIG`: two machines
give 4 MW, eight give 16 MW. The paper uses four throughout, and changing it
invalidates every saved design in `RESULTS/CONTROL/`, which were computed for
four.

## The step-up transformers, and why they matter more than they look

The transformers are **deliberately non-uniform**, and they are derived rather
than declared:

```matlab
Lt_H   = Ub^2 / Sb / (2·pi·f0) ./ SCR_transformer      % CONFIG_MODEL.m:216
Rt_Ohm = Lt_H · 2·pi·f0 ./ XR_transformer              % CONFIG_MODEL.m:217
```

So the tabulated quantity is `SCR_transformer` and `XR_transformer` per machine,
and the inductance and resistance follow. `CONFIG_MODEL.m:214-215`:

```matlab
SCR_transformer = [10 10 5 5];
XR_transformer  = [10 10 10 10];
```

| Machines | `SCR_t` | `X_t` | `R_t` | In SI |
|---|---|---|---|---|
| G1, G2 | 10 | 0.05774 pu | 0.005774 pu | 22.6 mΩ, 2.26 mΩ |
| G3, G4 | 5 | 0.11547 pu | 0.011547 pu | 45.3 mΩ, 4.53 mΩ |

**G3 and G4 have exactly twice the impedance of G1 and G2.** The farm is two
machines in duplicate, not four distinct ones — which is why every per-machine
result in the paper comes in two traces and not four.

**This is the single parameter choice that produces the structure of Figure 14.**
Because the two pairs sit behind different impedances, their terminal voltages
separate, and the separation grows as the grid weakens. Measured on this
repository at the pre-fault operating point of the fault campaign:

```
G1  1.0189    G2  1.0189    G3  1.0688    G4  1.0688
```

Identical within each pair, 0.0499 pu between pairs. The paper reports the
during-fault gap as 0.0534, 0.0416, 0.0345 and 0.0263 pu at `SCR = 1, 1.5, 2`
and `3`. If you make the transformers uniform, all four traces collapse onto one
and Section 6.3's first finding disappears.

The same split shows up in the DC-link response. Measured on the archived
voltage-sag traces, baseline design, peak `|Δu_dc|`:

```
G1, G2   8.187e-2 pu        G3, G4   6.460e-2 pu        21.1 % apart
```

**Within each pair the difference is exact zero to the bit**, in both the sag
and the generation-loss runs. One exception is documented and is not physics:
`|D1−D2| = 1.95e-3` in the GA sag case, an artefact of the two simulations
landing on different solver meshes. Do not report it as a difference between
machines.

## The grid Thevenin equivalent

Recomputed per operating point by
[`CONFIGURATION/update_grid_impedances.m`](../CONFIGURATION/update_grid_impedances.m),
not fixed:

```matlab
Lg_H   = Ub^2 / Sb_grid / (2·pi·f0) / SCR
Rg_Ohm = Lg_H · 2·pi·f0 / XR
```

with `XR_grid = 10` (`CONFIG_MODEL.m:347`) and `Sb_grid = 4·S_b = 8.41 MVA`.

At `SCR = 1` this gives `X_g = 0.14434` pu and `R_g = 0.014434` pu on the
single-machine base.

**A consequence worth knowing before you compare against the paper's operating
point labels.** The operating-point initialisation obtains the transmission
angle from the lossless relation while the line current uses `R_g`. The two do
not close, so the realised dispatch differs from the nominal label:

| Operating point | Nominal | Realised, measured |
|---|---|---|
| Designated | 0.700 pu/DFIG | 0.729–0.734 pu |
| Optimisation | 0.800 pu/DFIG | 0.845 pu |

The equilibrium is self-consistent, because `P_ref` is overwritten with the
achieved value, but it is not at the dispatch the label states.

## Turbine data

Aerodynamic parameters come from
[`MODEL/TURBINE_DATA/TurbineData.mat`](../MODEL/TURBINE_DATA/TurbineData.mat),
loaded at `CONFIG_MODEL.m:300`. Six fields: rated turbine power, rated turbine
speed, rated wind speed, turbine radius, air density, and the `C_p` coefficient
matrix.

The pitch angle is held fixed and enters as a constant exogenous input. There is
no pitch regulator: the disturbances studied are electrical events settling
within seconds, while pitch is a rate-limited mechanical action on a far slower
timescale, called on only above rated wind speed. Every operating point in the
envelope is consequently a below-rated equivalent.

## Files

| File | Role |
|---|---|
| `MODEL/CONFIG_MODEL.m` | Every parameter of this table |
| `MODEL/TURBINE_DATA/TurbineData.mat` | Aerodynamic look-up |
| `CONFIGURATION/update_grid_impedances.m` | Grid Thevenin per SCR |

## See also

[`tab02_grid_params.md`](tab02_grid_params.md) — the external grid's dynamic
model, which is separate from its impedance.
