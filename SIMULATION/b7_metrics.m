function summary = b7_metrics(results, traces, tag, SCR, P, r_src, dur, Thor, Vpcc_pre, tFault)
%B7_METRICS Per-run quantities of Table 10, computed from one campaign run.
%
% DESCRIPTION:
%   Produces every column of Table 10 of the paper, decomposed into the three
%   intervals a fault study must separate: the equilibrium the plant occupies
%   before the event, what the converters do during it, and whether and to what
%   state the plant returns after clearance.
%
%   The recovery criterion is the one fixed before the campaign was run, not one
%   chosen by looking at the traces. A point recovers when, for every machine and
%   at every instant from T_REC after clearance to the end of the run, the rotor
%   speed is within 2 % of its pre-fault value and the terminal voltage is at or
%   above 0.90 pu. The run must also complete without the model-validity guard
%   activating.
%
%   ADMISSIBILITY IS NOT DECIDED BY DEPTH. It is decided by whether the DC-link
%   voltage reaches the 0.50 pu division guard of Section 2.2. How far u_dc falls
%   depends on dispatch and grid strength as well as on the retained voltage, so
%   a retained voltage alone does not decide it and the screen is applied run by
%   run. Table 10 contains admissible runs deeper than the excluded one.
%
% INPUTS:
%   results  - Struct returned by RUN_PERTURBATION_SIM.
%   traces   - Struct written by b7_point, holding Vs_machines and V_pcc.
%   tag      - Run identifier.
%   SCR, P, r_src, dur, Thor - The run specification.
%   Vpcc_pre - Nominal pre-fault PCC voltage [pu], 0.975 for this campaign.
%   tFault   - Fault inception [s].
%
% OUTPUT:
%   summary - Struct with the fields listed under "Table 10 columns" below.
%
% SEE ALSO: b7_point, b7_campaign

% Criterion constants, fixed before the campaign (Section 6.3.1).
T_REC        = 1.25;    % s after clearance from which the criterion applies
SPEED_TOL    = 0.02;    % rotor speed must return within 2 % of pre-fault
V_RECOVER    = 0.90;    % pu terminal voltage required from T_REC onwards
VDC_GUARD    = 0.50;    % pu, the division guard of Section 2.2
RSC_I_LIMIT  = 1.074;   % pu, the RSC current-setpoint limit

% SCOPE_SIM channels, from the map in PLOT_SCOPE_SIM.m.
CH_VDC        = [3 2];
CH_RSC_ID     = [7 3];
CH_RSC_IQ     = [7 4];
CH_SPEED_ROT  = [13 1];
CH_ANG_PCC    = [12 1];

t        = traces.t(:);
tClear   = tFault + dur;
pre      = t < tFault;
during   = t >= tFault & t <= tClear;
% TWO DIFFERENT POST-CLEARANCE WINDOWS, AND CONFLATING THEM IS AN ERROR.
%
%   afterClear  from the instant of clearance. This is where the PEAKS are
%               measured: the largest post-clearance transmission angle and the
%               largest rotor-speed excursion both occur within a few hundred
%               milliseconds of clearance.
%   post        from T_REC after clearance. This is the RECOVERY CRITERION
%               window only: whether every machine has returned to within 2 %
%               of pre-fault speed and to 0.90 pu terminal voltage.
%
% Measuring the peaks on the criterion window misses them entirely, because it
% starts 1.25 s after the peak has passed. Measured: it returned 16.13 deg for
% a published 19.0 deg and 0.0055 pu for a published 0.0094 pu on the
% SCR = 3, P = 0.8 pu run.
afterClear = t >= tClear;
post       = t >= tClear + T_REC;

Vs   = traces.Vs_machines;      % [nSamples x nDFIG]
Vpcc = traces.V_pcc;
if size(Vs,1) ~= numel(t), Vs = Vs.'; end
if isvector(Vpcc), Vpcc = Vpcc(:); elseif size(Vpcc,1) ~= numel(t), Vpcc = Vpcc.'; end
Vpcc1 = Vpcc(:,1);

vdc   = local_chan(results, CH_VDC);
wr    = local_chan(results, CH_SPEED_ROT);
irD   = local_chan(results, CH_RSC_ID);
irQ   = local_chan(results, CH_RSC_IQ);
ang   = local_chan(results, CH_ANG_PCC);
% Rotor-current magnitude. The per-unit convention of this codebase carries a
% 1/sqrt(3) on power and current magnitudes: LINEAR_ANALYSIS computes power as
% real(v.*conj(i))/sqrt(3) and reactive current references as
% sqrt(3)*Q_ref./Vs. The dq components logged by the scope therefore give a
% physical magnitude of hypot(id,iq)/sqrt(3), referred to the stator base
% current I_b of Table 1 against which the 1.074 pu RSC rating is quoted.
%
% Measured: omitting the factor returns 1.864 pu on the SCR = 1, P = 0.8 pu run
% against a published 1.084 pu; including it returns 1.076 pu, which is 0.7 %
% from the published value and sits just above the 1.074 pu setpoint exactly as
% Section 6.3.1 describes.
ir    = hypot(irD, irQ) / sqrt(3);

summary = struct();
summary.tag   = tag;
summary.spec  = struct('SCR',SCR,'P',P,'r_src',r_src,'dur',dur,'Thor',Thor, ...
                       'Vpcc_nominal_pre',Vpcc_pre,'t_fault',tFault,'t_clear',tClear);

%% Table 10 columns — pre-fault
summary.PCC_pre = mean(Vpcc1(pre));

% Pre-fault transmission angle. Section 6.3.1 obtains it from the lossless
% relation sin(delta) = P / (V_pcc * V_g * SCR), which is the expression the
% operating-point initialisation itself solves. Reported alongside the angle
% the simulation logs, so that a disagreement is visible rather than hidden.
sinDelta = P / (Vpcc_pre * 1.0 * SCR);
if abs(sinDelta) <= 1
    summary.delta_pre = asind(sinDelta);
else
    summary.delta_pre = NaN;    % beyond the static transfer capability
end
summary.delta_pre_logged = mean(ang(pre));

%% Table 10 columns — during fault
%
% THE INCEPTION TRANSIENT IS EXCLUDED, AND THAT IS NOT A CONVENIENCE.
% Fault inception excites a switching transient lasting roughly the first fifth
% of the window. Measured on this campaign's SCR = 1, P = 0.8 pu run, the PCC
% voltage swings between 0.627 and 1.099 pu over that stretch and then settles
% at 0.92-0.94 pu. The "retained voltage" a grid code defines, and the quantity
% Table 10 reports, is the sustained level, not the instantaneous minimum of a
% numerical transient: taking the minimum returns 0.627 pu where the sustained
% level is 0.934 pu against a published 0.929 pu.
%
% The retained voltage is therefore the MEDIAN over the settled part of the
% window. A median is used rather than a mean because it is insensitive to the
% ringing that persists at reduced amplitude after inception.
SETTLE_FRACTION = 0.20;    % of the fault window discarded as inception transient

idxDuring = find(during);
if numel(idxDuring) > 10
    nSkip     = max(1, round(SETTLE_FRACTION * numel(idxDuring)));
    idxSettle = idxDuring(nSkip:end);
else
    idxSettle = idxDuring;
end
settled = false(size(t));
settled(idxSettle) = true;

summary.PCC_ret        = median(Vpcc1(settled));
summary.PCC_ret_min    = min(Vpcc1(during));      % including the transient
summary.Vs_ret         = median(min(Vs(settled,:), [], 2));
summary.vdc_min        = min(vdc(during | post | pre));
summary.ir_peak        = max(ir(settled));
summary.ir_peak_incl_transient = max(ir(during));
summary.ir_over_limit  = summary.ir_peak > RSC_I_LIMIT;
summary.settle_fraction_discarded = SETTLE_FRACTION;

% The validity gate. Applied over the WHOLE run, not only during the fault:
% the guard can be reached well after clearance.
summary.vdc_min_run    = min(vdc);
summary.guard_active   = any(vdc <= VDC_GUARD);
summary.guard_fraction = nnz(vdc <= VDC_GUARD) / numel(vdc);
if summary.guard_active
    [~, iG] = min(vdc);
    summary.guard_t_min = t(iG) - tClear;   % s after clearance
else
    summary.guard_t_min = NaN;
end

%% Table 10 columns — post-fault
if any(post)
    wr_pre = mean(wr(pre));

    % Peaks: from clearance.
    summary.delta_max = max(abs(ang(afterClear)));

    % Rotor-speed excursion. Table 10 reports it RELATIVE to the pre-fault
    % speed, not as an absolute difference in per unit. The pre-fault speed is
    % about 1.157 pu, so the two differ by that factor, and reporting the
    % absolute value leaves a constant +15 % bias against the published column.
    %
    % Measured, absolute against relative against published:
    %   SCR = 1, P = 0.8   0.1681   0.14529   published 0.1454
    %   SCR = 3, P = 0.8   0.0108   0.00933   published 0.0094
    %
    % The relative form is also what the recovery criterion of Section 6.3.1 is
    % written in: the machine must return to within 2 % OF ITS pre-fault speed.
    summary.dwr_abs = max(abs(wr(afterClear) - wr_pre));
    summary.dwr_max = summary.dwr_abs / abs(wr_pre);
    summary.dwr_rel = summary.dwr_max;
    summary.wr_pre  = wr_pre;

    % Criterion quantities: from clearance + T_REC.
    summary.Vs_min_post = min(min(Vs(post,:), [], 1));
    summary.dwr_rel_criterion = max(abs(wr(post) - wr_pre)) / abs(wr_pre);

    % End-of-window ratio.
    summary.Vpost_Vpre = mean(Vpcc1(t >= t(end)-0.05)) / summary.PCC_pre;
else
    [summary.delta_max, summary.dwr_max, summary.dwr_rel, ...
     summary.Vpost_Vpre, summary.Vs_min_post] = deal(NaN);
end

%% Outcome
% Order matters. Exclusion is tested first: a run outside the model's valid
% range is reported as excluded and never as a failure to ride through, which
% is the distinction the guard exists to enforce.
if summary.guard_active
    summary.outcome = 'Excluded';
    summary.outcome_reason = sprintf( ...
        ['u_dc reached the %.2f pu validity guard (active over %.1f %% of the ' ...
         'run, minimum %.3f pu). Outside the model''s valid range; reported as ' ...
         'excluded, not as a failure.'], ...
        VDC_GUARD, 100*summary.guard_fraction, summary.vdc_min_run);

elseif summary.delta_max >= 90 || ~isfinite(summary.delta_max)
    summary.outcome = 'Loss of synchronism';
    summary.outcome_reason = sprintf( ...
        'Transmission angle reached %.1f deg and did not return.', summary.delta_max);

elseif summary.dwr_rel_criterion > SPEED_TOL
    summary.outcome = 'Speed shortfall';
    summary.outcome_reason = sprintf( ...
        'Rotor speed stayed %.2f %% from its pre-fault value, above the %.0f %% criterion.', ...
        100*summary.dwr_rel_criterion, 100*SPEED_TOL);

elseif summary.Vs_min_post < V_RECOVER
    summary.outcome = 'Voltage shortfall';
    summary.outcome_reason = sprintf( ...
        ['Angle and speed recover, but at least one machine terminal voltage ' ...
         'fell to %.4f pu after t_clear + %.2f s, below the %.2f pu level.'], ...
        summary.Vs_min_post, T_REC, V_RECOVER);

else
    summary.outcome = 'Recovers';
    summary.outcome_reason = sprintf( ...
        ['Every machine within %.0f %% of pre-fault speed and at or above ' ...
         '%.2f pu terminal voltage from t_clear + %.2f s onwards.'], ...
        100*SPEED_TOL, V_RECOVER, T_REC);
end

summary.criterion = struct('T_REC',T_REC,'SPEED_TOL',SPEED_TOL, ...
                           'V_RECOVER',V_RECOVER,'VDC_GUARD',VDC_GUARD, ...
                           'RSC_I_LIMIT',RSC_I_LIMIT);
end

function y = local_chan(results, ch)
%LOCAL_CHAN One channel of one scope, as a column vector, first unit.
v = results.SCOPE_SIM.signals(ch(1)).values;
if ndims(v) == 3
    y = squeeze(v(ch(2), 1, :));
else
    y = v(:, ch(2));
end
y = y(:);
end
