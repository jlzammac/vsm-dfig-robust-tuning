# Table 7 — Step-response indices

**Section 5.2** · overshoot and settling for the closed-loop step responses.

**Status: `verified`.** Endpoint analysis executed from a clean clone on
2026-09-23 for both designs. The DC-link headline reproduces exactly:
**109.9 → 184.0 rad/s, +67.4 %**. Measured loop specifications below.

---

## The operating point, which is the whole caveat

**Table 7 is computed at the optimisation operating point** — `P = 0.8` pu per
DFIG, `V_pcc = 0.975` pu, `SCR = 1`.

Figure 11 is **not**. It is drawn at `P = 0.7` pu with a PCC voltage of 1.0 pu,
and it additionally reports a grid strength the table does not.

Section 5.4 is explicit that the two must not be mixed: *"the overshoot and
settling figures of Table 7 are not available to certify panel (a) either,
because that table is computed at the optimisation operating point and this
figure is not."* Sections 3.3 and 2.4 make the same point generally — sets
computed at different operating points are never pooled within a comparison.

If you take one number from this table and one from Figure 11 and compare them,
you are comparing two operating points and attributing the difference to the
design.

## Procedure

```matlab
RUN_MODE     = 1;    % endpoints
CONTROL_TYPE = 2;
```

then

```matlab
cd CONFIGURATION
GEN_PAPER_V6_FIGURES     % prints the table data and writes the step figure
```

`GEN_PAPER_V6_FIGURES` requires `LIN_MODEL_FRD_DESIGN.mat` plus all the BIOBJ
intermediates, all versioned here, and the envelope sweep data for its per-band
panels. For the step indices alone the endpoints suffice.

## What the indices are computed on

The complementary sensitivity `T(s) = G(s)/(1 + G(s))` of each loop, under a
unit step. `G(s)` is the open-loop transfer function; its construction is in
reference [16] of the paper.

The four loops reported are those with the largest parameter changes: VSMP, VDC,
RSCd, GSCd.

## Expected behaviour

The headline is the DC link, and it is the one small-signal change that shows up
directly in a large-signal result:

```
VDC crossover   109.9 -> 184.0 rad/s      +67.4 %
```

That is what produces the DC-link improvement of Sections 6.1 and 6.2 — a
33.1 % peak reduction under generation loss and 27.5 % under the sag, and more
importantly the faster decay: the optimised design enters the ±0.5 % band at
1.05 s and 1.40 s respectively, while the baseline does not enter it within the
window in either test.

**A check that costs nothing:** reproduce this table, then look at the DC-link
panels of Figures 12 and 13. If the bandwidth increase is there and the decay
improvement is not, something between the design and the nonlinear model has
changed.

## A property that is structural, not optimised

Both designs converge to the same steady state at each grid strength. That does
**not** follow from the optimisation: the steady-state droop of the VSM
active-power loop is set by `D_p`, which is not a decision variable of this
study and appears in neither Table 4 nor Table 5. The optimiser cannot move it.

If your two designs settle at different values, `D_p` has been changed upstream.

## Files

| File | Role |
|---|---|
| `CONFIGURATION/GEN_PAPER_V6_FIGURES.m` | Prints the indices |
| `CONFIGURATION/GEN_PAPER_FIG_STEP_ENDPOINTS.m` | The endpoint step figure |
| `PLOT_FILES/PLOT_LIN_MODEL_COMP.m` | Step-response plotting |

## See also

[`fig11_step_response_comparison.md`](fig11_step_response_comparison.md) — drawn
at a **different** operating point · [`tab06_achieved_margins.md`](tab06_achieved_margins.md)

## Measured, 2026-09-23, from a clean clone

`RUN_MODE = 1` at both `CONTROL_TYPE = 2` (CFRD baseline) and `CONTROL_TYPE = 7`
(GA-optimised), reading `CONTROL_DESIGN.<loop>.frdMargins`:

| Loop | Baseline `F_m` / `ω_o` | Optimised `F_m` / `ω_o` |
|---|---|---|
| VSMP | 67.55° / 8.0 rad/s | 83.42° / 5.9 rad/s |
| VSMQ | 104.30° / 2.0 | 107.68° / 2.0 |
| RSC | 65.75° / 2184.0 | 55.66° / 1829.2 |
| **VDC** | **65.50° / 109.9** | **58.20° / 184.0** |
| GSC | 65.70° / 2184.0 | 60.14° / 2061.0 |

> **VDC crossover: 109.9 → 184.0 rad/s = +67.4 %.** Published: 109.9 → 184.0,
> +67.4 %. Exact.

The optimised VDC phase margin of **58.20°** is the *specified* 58.2° of
Section 5.3.3, reproduced to the digit.

**These are the specified margins, not the achieved ones.** `frdMargins` comes
out of the design stage and is identical at all eight endpoints, which is what
tells you it is a specification. Table 6's *achieved* margins are the realised
values at each operating point and are a separate computation — see
[`tab06_achieved_margins.md`](tab06_achieved_margins.md).

Note also that the optimisation **lowers** three margins (RSC, VDC, GSC) while
raising VSMP. That is the intended trade: bandwidth bought with margin, inside
the `[50°, 90°]` feasibility window. Every optimised loop above stays in it.
