%% GEN_PAPER_FIG_NL_VALIDATION — Nonlinear validation figures for Section 6
%
% Generates IEEE-quality comparison figures from nonlinear simulation
% results (baseline FRD vs GA-optimized controller).
%
% Scenarios:
%   1. Generation loss: DFIG 4 disconnected via breaker at t = 500 ms
%   2. Voltage sag: 20% depth, t = 500 ms to t = 650 ms
%
% CORRECTED 2026-09-23: the machine, and both event instants, were stale with
% respect to the manuscript. See the SIMULATION MATRIX block below for the
% evidence. One mismatch remains and is documented rather than guessed at:
% panel (c) of the published figure plots all four DC-link voltages and this
% script plots one.
%
% Each figure: 3x1 subplot (single-column IEEE format). All three panels plot
% ABSOLUTE quantities, matching the published figures:
%   (a) Grid frequency, Hz         [signals(11), channel 1, x f_0]
%   (b) PCC voltage, pu            [signals(6),  channel 3]
%   (c) DC-link voltage, pu        [signals(3),  channel 2]
%
% Output:
%   figures/nl_generation_loss.pdf
%   figures/nl_voltage_sag.pdf
%
% USAGE:
%   Option A — Run simulations first, then generate figures:
%     1. Run CONFIG_POWER_SYSTEM with RUN_MODE=4, CONTROL_TYPE=2,
%        NL_SIM_PERT_TYPE='generation_loss', save result as res_gl_bl
%     2. Repeat with CONTROL_TYPE=7 → res_gl_opt
%     3. Repeat for 'voltage_sag' → res_vs_bl, res_vs_opt
%     4. Set SKIP_SIMULATION=true, run this script
%
%   Option B — Automatic (requires Simulink):
%     Set SKIP_SIMULATION=false, run this script (runs all 4 sims)

clear; clc; close all;

%==========================================================================
%% USER CONFIGURATION
%==========================================================================
SKIP_SIMULATION = false;   % true = load from saved .mat, false = run Simulink
% Optional non-interactive override, so a figure-only regeneration (e.g. the R4#5
% Hz axis change) can reuse the saved .mat without editing this default:
%   setenv('GENFIG_SKIP_SIM','1')  or  GENFIG_SKIP_SIM=1 in the environment.
if ~isempty(getenv('GENFIG_SKIP_SIM'))
    SKIP_SIMULATION = strcmp(getenv('GENFIG_SKIP_SIM'), '1');
    fprintf('SKIP_SIMULATION overridden from environment -> %d\n', SKIP_SIMULATION);
end
SIM_DURATION    = 5.0;     % [s] total simulation window

% --- Plot time windows (start after perturbation to avoid numerical spikes)
T_OFFSET        = 0.010;   % [s] skip first 10ms after perturbation onset
T_WINDOW_GL     = 3.0;     % [s] display window for generation loss
T_WINDOW_VS     = 3.0;     % [s] display window for voltage sag

% --- Display-only low-pass on the PCC trace -------------------------------
% V_pcc carries a resonance at ~13.25 kHz. Its amplitude in this run is
% ~0.020 pu peak-to-peak at quasi-steady state, BEFORE any perturbation,
% against ~0.0007 pu in the run behind the published figures -- a factor of
% about 30 with a byte-identical Simulink model, across MATLAB releases
% (published: R2025a; this run: R2026a). It is therefore numerical, not
% physical; it lies three decades above the dynamics under study; and
% converter switching is outside the model's declared scope
% (Section sec:model_scope).
%
% The PCC trace is consequently low-pass filtered FOR DISPLAY ONLY: resampled
% onto a uniform grid and passed through a ZERO-PHASE Butterworth (filtfilt,
% so no group delay is introduced and the transient instants are preserved).
% The frequency and DC-link traces are clean -- pre-perturbation ripple is
% 1e-6 pu and 7.6e-4 pu respectively -- and are NOT filtered.
% The filter is declared in the manuscript body and must match what is
% printed by this script.
LP_FC           = 1000;    % [Hz] cut-off
LP_ORD          = 4;       % Butterworth order
LP_FS           = 200000;  % [Hz] uniform resampling rate used for filtfilt

% --- Y-axis limits --------------------------------------------------------
% Panels (b) and (c) reuse the PUBLISHED axis limits, read off the tick labels
% of nl_generation_loss_2.pdf / nl_voltage_sag_2.pdf, so that the regenerated
% figures are drop-in replacements. Panel (a) is the only panel whose units
% changed (per unit -> Hz), so its limits are DERIVED FROM THE DATA with the
% breaker switching transient excluded, plus a margin -- no hard-coded range.
YLIM_PUB_B      = [0.95, 1.10];   % published panel (b)
YLIM_PUB_C      = [0.90, 1.10];   % published panel (c)
T_PERT          = 0.500;   % [s] perturbation instant in the saved runs
T_CUT_GL        = 0.505;   % [s] gen-loss exclusion end (declared convention)
T_CUT_VS        = 0.5005;  % [s] sag exclusion end (peaks are cut-insensitive)
YLIM_MARGIN     = 0.05;    % fraction of the retained span added on each side
YLIM_WIDEN_MAX  = 3.0;     % containment rule: if including the excluded window
                           % widens the span by no more than this factor, the
                           % excursion is bounded physical content and is KEPT;
                           % beyond it, it is the switching spike and is clipped.

% --- V_dc DFIG selection ---
% For generation loss: DFIG 4 is disconnected, so monitor 1, 2 or 3 if you
% want a machine that stays online -- but see the note below, because the
% published panel (c) plots all four deliberately, including the one removed.
% For voltage sag: all DFIGs connected.
% Adjust VDC_CHANNEL below based on your SCOPE_SIM layout.
%
% SCOPE_SIM.signals(3) channel mapping (check PLOT_SCOPE_SIM.m):
%   Channel 1: VDC_REF
%   Channel 2: VDC
%   Channel 3: P_GSC
%   Channel 4: P_RSC
%   Channel 5: P_DC
%
% If the scope monitors a SINGLE DFIG (typical), you must run separate
% simulations for each DFIG you want to observe, or modify the Simulink
% scope to log all DFIGs. Channel 2 = VDC of the monitored DFIG.
VDC_CHANNEL = 2;           % Channel index for V_dc within signals(3)

% --- V_dc label for each scenario ---
% The SCOPE_SIM Selector blocks are driven by a single Constant (SID 1950) whose
% Value is the Simulink default 1, so the scope monitors DFIG 1 in BOTH
% scenarios.
%
% THIS NO LONGER MATCHES THE PUBLISHED FIGURE, and the discrepancy is recorded
% rather than papered over. The comment here used to cite a manuscript sentence
% about "the DC-link trace of DFIG 1, which remains online throughout both
% tests". That sentence is gone. The current caption says panel (c) carries
% "the DC-link voltage u_dc of ALL FOUR DFIGs", traces coinciding in pairs
% because machines 1-2 and 3-4 sit behind transformers of different rating,
% with DFIG 4 holding its pre-event value precisely because it is the unit
% removed.
%
% Reproducing panel (c) as published therefore needs per-machine DC-link
% logging, which this script does not set up. SIMULATION/
% b7_enable_per_machine_logging.m does exactly that for the stator voltage and
% is the pattern to follow. Until then this script produces a single-machine
% panel (c): correct for what it plots, not the published figure.
VDC_LABEL_GL = '$u_\mathrm{dc}$, DFIG 1 (pu)';   % single monitored machine
VDC_LABEL_VS = '$u_\mathrm{dc}$, DFIG 1 (pu)';   % single monitored machine

%==========================================================================
%% PATHS
%==========================================================================
projRoot  = fileparts(mfilename('fullpath'));
simDir    = fullfile(projRoot, '..', 'RESULTS', 'SIMULATION');
figDir    = fullfile(projRoot, '..', 'PAPERS', ...
            'Paper_VSM_DFIG_Optimization_Robustness', 'figures');
plotUtils = fullfile(projRoot, '..', 'FIGURES', 'UTILS');
addpath(plotUtils);
% Optional output-directory override. Needed because Google Drive File Stream does
% not reliably accept a NEW file written by a tool that reopens it; the standing
% rule is to render into local scratch and copy back. Set GENFIG_OUTDIR to use it.
if ~isempty(getenv('GENFIG_OUTDIR'))
    figDir = getenv('GENFIG_OUTDIR');
    fprintf('figDir overridden from environment -> %s\n', figDir);
end
if ~exist(figDir, 'dir'), mkdir(figDir); end

%==========================================================================
%% SIMULATION MATRIX
%==========================================================================
% CORRECTED 2026-09-23 — THE MACHINE AND THE INSTANT WERE BOTH STALE.
%   This block read [1 0 0 0] at t = 0.005 s, i.e. DFIG 1 disconnected 5 ms
%   into the run. The manuscript states neither. Section 6.1 opens "DFIG 4 is
%   disconnected from the grid via its breaker at t = 500 ms, removing one
%   quarter of the wind farm generation capacity", and the Figure 12 caption
%   says of panel (c) "DFIG 4, being the unit disconnected at t = 500 ms,
%   holds its pre-event DC-link voltage".
%
%   Three independent confirmations that DFIG 4 is the disconnected unit:
%     1. the section body, verbatim, above;
%     2. the figure caption, verbatim, above;
%     3. the measured per-machine transient, which reports dP and dQ for
%        DFIGs 1, 2 and 3 as the SURVIVORS -- so 4 is the one removed.
%
%   The sag times are corrected alongside for the same reason: Section 6.2
%   states "from t = 500 ms to t = 650 ms".
%
%   WHAT IS NOT FIXED HERE, because it cannot be verified from the sources
%   in this repository: panel (c) of the published figure plots the DC-link
%   voltage of ALL FOUR machines, and the V_dc selection below monitors one.
%   The published figure postdates this script. See
%   REPRODUCE/fig12_nl_generation_loss.md.
scenarios = {
    'generation_loss', struct('breaker_mask', [0 0 0 1], ...   % DFIG 4
                              'breaker_time', 0.500, ...
                              'sim_duration', SIM_DURATION);
    'voltage_sag',     struct('sag_depth', 0.20, ...
                              'sag_start_time', 0.500, ...
                              'sag_duration', 0.150, ...
                              'sim_duration', SIM_DURATION)
};

controllers = {2, 'FRD'; 7, 'VI_OPT'};

%==========================================================================
%% RUN SIMULATIONS (or load saved results)
%==========================================================================
results = cell(size(scenarios,1), size(controllers,1));

if SKIP_SIMULATION
    fprintf('=== LOADING SAVED SIMULATION RESULTS ===\n');
    for iS = 1:size(scenarios, 1)
        for iC = 1:size(controllers, 1)
            pertTag = scenarios{iS, 1};
            ctrlTag = controllers{iC, 2};
            pattern = fullfile(simDir, sprintf('SIM_*_%s_4DFIG_%s.mat', ...
                     ctrlTag, strrep(pertTag, '_', '')));
            files = dir(pattern);
            if isempty(files)
                error('No saved results for %s / %s. Set SKIP_SIMULATION=false.', ...
                      pertTag, ctrlTag);
            end
            [~, idx] = max(arrayfun(@(f) f.datenum, files));
            fprintf('  Loading: %s\n', files(idx).name);
            data = load(fullfile(simDir, files(idx).name));
            results{iS, iC} = data.nl_results;
        end
    end
else
    fprintf('=== RUNNING NONLINEAR SIMULATIONS ===\n');
    for iC = 1:size(controllers, 1)
        ctrlType = controllers{iC, 1};
        ctrlName = controllers{iC, 2};
        fprintf('\n--- Controller: %s (CONTROL_TYPE=%d) ---\n', ctrlName, ctrlType);

        RUN_MODE = 4;
        CONTROL_TYPE = ctrlType;

        for iS = 1:size(scenarios, 1)
            pertType = scenarios{iS, 1};
            fprintf('  Scenario: %s ... ', pertType);

            NL_SIM_PERT_TYPE = pertType;
            NL_SIM_DURATION = SIM_DURATION;
            run(fullfile(projRoot, 'CONFIG_POWER_SYSTEM.m'));

            results{iS, iC} = nl_results;
            fprintf('OK (t_end=%.3f s)\n', nl_results.t(end));
        end
    end
    fprintf('\n=== ALL SIMULATIONS COMPLETE ===\n');
end

%==========================================================================
%% EXTRACT SIGNALS
%==========================================================================
for iS = 1:size(scenarios, 1)
    for iC = 1:size(controllers, 1)
        r = results{iS, iC};
        S = r.SCOPE_SIM;

        r.t_raw = double(S.time);

        % Grid frequency [signals(11), channel 1]
        sig11 = S.signals(11).values;
        if ndims(sig11) == 3
            r.freq_raw = squeeze(sig11(1,1,:));
        else
            r.freq_raw = sig11(:,1);
        end

        % PCC voltage [signals(6), channel 3]
        sig6 = S.signals(6).values;
        if ndims(sig6) == 3
            r.vpcc_raw = squeeze(sig6(3,1,:));
        else
            r.vpcc_raw = sig6(:,3);
        end

        % DC-link voltage [signals(3), channel VDC_CHANNEL]
        sig3 = S.signals(3).values;
        if ndims(sig3) == 3
            r.vdc_raw = squeeze(sig3(VDC_CHANNEL,1,:));
        else
            r.vdc_raw = sig3(:,VDC_CHANNEL);
        end

        results{iS, iC} = r;
    end
end

%==========================================================================
%% TRIM SIGNALS TO PLOT WINDOW
%==========================================================================
% Remove the initial spike by starting T_OFFSET after the perturbation.
% Compute deviations from the value at the trim start (quasi-steady-state).

t_windows = [T_WINDOW_GL, T_WINDOW_VS];

% R4#5 ("frequency should be in Hz not p.u."): the frequency panel is plotted in
% Hz from 2026-09-01. signals(11) ch.1 is delivered in per unit of f_0, so the
% conversion is a scaling by f_0. The assertion below fails loudly if that source
% convention ever changes to absolute Hz -- otherwise this would silently scale a
% 50 Hz signal to 2500.
F0_HZ = 50;

for iS = 1:size(scenarios, 1)
    t_end = t_windows(iS);

    for iC = 1:size(controllers, 1)
        r = results{iS, iC};
        assert(abs(median(r.freq_raw) - 1) < 0.05, ...
            'GENFIG:frequnit', ...
            ['freq_raw median is %.4f; expected ~1.0 (per unit of f_0). ' ...
             'The Hz conversion assumes per-unit input.'], median(r.freq_raw));

        % Trim indices
        idx_start = find(r.t_raw >= T_OFFSET, 1);
        idx_end   = find(r.t_raw >= T_OFFSET + t_end, 1);
        if isempty(idx_end), idx_end = length(r.t_raw); end

        sel = idx_start:idx_end;

        % Trimmed time (shifted so display starts at t=0) and the matching
        % ABSOLUTE simulation time, needed to locate the switching transient
        % when the y-limits are computed.
        r.t     = r.t_raw(sel) - r.t_raw(idx_start);
        r.t_abs = r.t_raw(sel);

        % Deviations from initial (pre-transient) value.
        % r.df stays in pu so the metrics block below keeps its meaning.
        r.df   = r.freq_raw(sel) - r.freq_raw(idx_start);
        r.df_hz = r.df * F0_HZ;
        r.dvpc = r.vpcc_raw(sel) - r.vpcc_raw(idx_start);
        r.dvdc = r.vdc_raw(sel)  - r.vdc_raw(idx_start);

        % Absolute values -- these are what the three panels plot.
        % r.freq_hz is the R4#5 quantity: grid frequency in Hz, not per unit.
        r.freq = r.freq_raw(sel);
        r.freq_hz = r.freq * F0_HZ;
        r.vpcc = r.vpcc_raw(sel);
        r.vdc  = r.vdc_raw(sel);

        % Display-only zero-phase low-pass on V_pcc (see LP_* above). The
        % solver grid is variable-step, so the trace is first resampled onto
        % a uniform grid; filtfilt requires uniform sampling.
        t_uni = (r.t_abs(1) : 1/LP_FS : r.t_abs(end))';
        v_uni = interp1(r.t_abs, r.vpcc, t_uni, 'linear');
        [b_lp, a_lp] = butter(LP_ORD, LP_FC/(LP_FS/2), 'low');
        r.vpcc_lp  = filtfilt(b_lp, a_lp, v_uni);
        r.t_lp     = t_uni - r.t_abs(1);   % same display origin as r.t
        r.t_lp_abs = t_uni;

        results{iS, iC} = r;
    end
end

%==========================================================================
%% FIGURE GENERATION — IEEE PUBLICATION QUALITY
%==========================================================================
% Style per R25:
%   Baseline:  solid black,  LineWidth 1.4
%   Optimized: dashed black, LineWidth 1.4
% No titles. Subplot labels (a), (b), (c) inside each axes.
% Legend in subplot with most whitespace, semi-transparent background.
% Single-column figure: 3.5 x 5.0 inches (3x1 stacked subplots).

figNames  = {'nl_generation_loss', 'nl_voltage_sag'};
vdc_labels = {VDC_LABEL_GL, VDC_LABEL_VS};
t_cuts     = [T_CUT_GL, T_CUT_VS];

fprintf(['\n--- DISPLAY FILTER ON V_pcc: zero-phase Butterworth, order %d, ' ...
         'f_c = %d Hz, resampled to %d Hz (filtfilt) ---\n'], ...
        LP_ORD, LP_FC, LP_FS);
fprintf('    frequency and DC-link traces are NOT filtered.\n');
for iS = 1:size(scenarios, 1)
    cutS = t_cuts(iS);
    for iC = 1:size(controllers, 1)
        rr = results{iS, iC};
        pre  = (rr.t_lp_abs >= 0.05) & (rr.t_lp_abs < 0.45);
        post = (rr.t_lp_abs >= cutS);
        refv = mean(rr.vpcc_lp(pre));
        [pk, kk] = max(abs(rr.vpcc_lp(post) - refv));
        tpost = rr.t_lp_abs(post);
        fprintf(['    %-16s %-7s ref=%.5f  filtered peak |dV_pcc| = %.5f pu ' ...
                 '(%.2f V on 690 V) at t=%.4f s   min V_pcc = %.4f pu\n'], ...
                scenarios{iS,1}, controllers{iC,2}, refv, pk, pk*690, ...
                tpost(kk), min(rr.vpcc_lp(post)));
    end
end

fprintf('\n--- Y-AXIS LIMITS ---\n');

for iS = 1:size(scenarios, 1)
    r_bl  = results{iS, 1};
    r_opt = results{iS, 2};

    % Figure dimensions: IEEE single-column
    fig = figure('Units', 'inches', 'Position', [1 1 3.5 5.0]);
    set(fig, 'PaperPositionMode', 'auto', 'InvertHardcopy', 'off', ...
        'Color', 'w', 'Renderer', 'painters');

    % Fields to plot -- ABSOLUTE quantities in all three panels, as in the
    % published figures. Panel (a) is grid frequency in Hz (R4#5). Panel (b)
    % plots the low-pass-filtered PCC trace (vpcc_lp, on its own uniform time
    % base t_lp); panels (a) and (c) plot the raw signals unfiltered.
    fields = {'freq_hz', 'vpcc_lp', 'vdc'};
    tvars  = {'t',       't_lp',    't'};
    ylabs  = {'Grid frequency (Hz)', '$V_\mathrm{PCC}$ (pu)', ...
              vdc_labels{iS}};
    t_cut  = t_cuts(iS);

    for iP = 1:3
        ax = subplot(3, 1, iP);
        hold on; grid on; box on;

        % Data
        t_bl  = r_bl.(tvars{iP});    y_bl  = r_bl.(fields{iP});
        t_opt = r_opt.(tvars{iP});   y_opt = r_opt.(fields{iP});

        % Plot
        h1 = plot(t_bl,  y_bl,  '-k',  'LineWidth', 1.4);
        h2 = plot(t_opt, y_opt, '--k', 'LineWidth', 1.4);

        % Y-axis label (LaTeX interpreter)
        ylabel(ylabs{iP}, 'FontSize', 8, 'Interpreter', 'latex');

        % Axis formatting
        set(ax, 'FontSize', 7, 'TickLabelInterpreter', 'tex');
        xlim([0 t_windows(iS)]);

        %------------------------------------------------------------------
        % Y-limits.
        %   panel (a): DERIVED from the data (units changed to Hz), with the
        %              breaker switching transient excluded, plus a margin.
        %   panels (b), (c): the PUBLISHED limits, so the regenerated figures
        %              are drop-in replacements.
        %------------------------------------------------------------------
        ta_bl  = r_bl.([tvars{iP} '_abs']);
        ta_opt = r_opt.([tvars{iP} '_abs']);
        keep_bl  = (ta_bl  < T_PERT) | (ta_bl  >= t_cut);
        keep_opt = (ta_opt < T_PERT) | (ta_opt >= t_cut);
        y_core = [y_bl(keep_bl); y_opt(keep_opt)];
        lo_c = min(y_core);            hi_c = max(y_core);
        lo_f = min([y_bl; y_opt]);     hi_f = max([y_bl; y_opt]);
        span_c = hi_c - lo_c;          span_f = hi_f - lo_f;
        if span_c <= 0
            span_c = max(abs(hi_c), 1) * 1e-3;   % degenerate (flat) trace
        end

        if iP == 1
            if span_f <= YLIM_WIDEN_MAX * span_c
                lo = lo_f; hi = hi_f;
                how = 'derived, widened to full window';
            else
                lo = lo_c; hi = hi_c;
                how = 'derived, switching transient excluded';
            end
            mrg = YLIM_MARGIN * (hi - lo);
            yl  = [lo - mrg, hi + mrg];
        elseif iP == 2
            yl = YLIM_PUB_B;   how = 'published limits (drop-in replacement)';
        else
            yl = YLIM_PUB_C;   how = 'published limits (drop-in replacement)';
        end
        ylim(yl);

        % Containment check on what is actually DRAWN.
        n_out = sum(y_bl < yl(1) | y_bl > yl(2)) + ...
                sum(y_opt < yl(1) | y_opt > yl(2));
        n_tot = numel(y_bl) + numel(y_opt);
        % ... and on the physical content only (transient window removed), which
        % is what must NOT be clipped.
        yc_out = sum(y_core < yl(1) | y_core > yl(2));
        fprintf(['  %-20s (%c) %-42s ylim=[%.5f, %.5f]  ' ...
                 'core=[%.5f, %.5f] full=[%.5f, %.5f]  ' ...
                 'outside: %d/%d drawn, %d/%d post-transient\n'], ...
                figNames{iS}, 'a'+iP-1, how, yl(1), yl(2), ...
                lo_c, hi_c, lo_f, hi_f, n_out, n_tot, yc_out, numel(y_core));

        % X-axis label only on bottom subplot
        if iP == 3
            xlabel('Time (s)', 'FontSize', 8);
        else
            set(ax, 'XTickLabel', []);
        end

        % Subplot label (a), (b), (c)
        text(0.02, 0.90, sprintf('(%c)', 'a'+iP-1), ...
            'Units', 'normalized', 'FontSize', 9, 'FontWeight', 'bold', ...
            'BackgroundColor', 'w', 'EdgeColor', 'none');

        % Legend: place in the subplot with most whitespace.
        % Panel (a) now plots ABSOLUTE frequency, which decays towards the
        % bottom-right in the generation-loss case; 'southeast' would sit on
        % the traces, so the legend goes north-east, as in the published
        % figures.
        if iP == 1
            lg = legend([h1 h2], 'Baseline', 'Optimised (GA)', ...
                'Location', 'northeast', 'FontSize', 6, ...
                'Interpreter', 'tex');
            lg.BoxFace.ColorType = 'truecoloralpha';
            lg.BoxFace.ColorData = uint8([255 255 255 210]');
        end
    end

    % Reduce vertical gaps between subplots
    axs = findobj(fig, 'Type', 'axes');
    for k = 1:length(axs)
        pos = get(axs(k), 'Position');
        pos(4) = pos(4) * 1.08;  % Stretch height slightly
        set(axs(k), 'Position', pos);
    end

    % Export (IEEE vector quality)
    outPath = fullfile(figDir, [figNames{iS} '.pdf']);
    exportgraphics(fig, outPath, 'ContentType', 'vector', ...
        'BackgroundColor', 'white');
    fprintf('Exported: %s\n', outPath);
end

%==========================================================================
%% PERFORMANCE METRICS — for LaTeX (grep %%FILL%% in sec6)
%==========================================================================
fprintf('\n');
fprintf('================================================================\n');
fprintf('  TRANSIENT PERFORMANCE METRICS FOR SECTION 6\n');
fprintf('================================================================\n');

for iS = 1:size(scenarios, 1)
    r_bl  = results{iS, 1};
    r_opt = results{iS, 2};

    fprintf('\n--- %s ---\n', upper(scenarios{iS, 1}));

    % Frequency
    pk_df_bl  = max(abs(r_bl.df));
    pk_df_opt = max(abs(r_opt.df));
    delta_pct = (pk_df_opt/pk_df_bl - 1)*100;
    fprintf('  Peak |Delta f|:     %.6f pu  ->  %.6f pu  (%+.1f%%)\n', ...
        pk_df_bl, pk_df_opt, delta_pct);
    % Same quantity in mHz, for the response letter and the figure axis (R4#5).
    fprintf('  Peak |Delta f|:     %.2f mHz ->  %.2f mHz (%+.1f%%)\n', ...
        pk_df_bl*F0_HZ*1e3, pk_df_opt*F0_HZ*1e3, delta_pct);

    % PCC voltage
    pk_dv_bl  = max(abs(r_bl.dvpc));
    pk_dv_opt = max(abs(r_opt.dvpc));
    delta_pct = (pk_dv_opt/pk_dv_bl - 1)*100;
    fprintf('  Peak |Delta Vpcc|:  %.6f pu  ->  %.6f pu  (%+.1f%%)\n', ...
        pk_dv_bl, pk_dv_opt, delta_pct);

    % DC-link voltage
    pk_dvdc_bl  = max(abs(r_bl.dvdc));
    pk_dvdc_opt = max(abs(r_opt.dvdc));
    delta_pct = (pk_dvdc_opt/pk_dvdc_bl - 1)*100;
    fprintf('  Peak |Delta Vdc|:   %.6f pu  ->  %.6f pu  (%+.1f%%)\n', ...
        pk_dvdc_bl, pk_dvdc_opt, delta_pct);

    % Settling time (2% band around final value)
    for sig_name = {'df', 'dvpc', 'dvdc'}
        y_bl  = r_bl.(sig_name{1});
        y_opt = r_opt.(sig_name{1});

        % 2% of peak deviation
        thr_bl  = 0.02 * max(abs(y_bl));
        thr_opt = 0.02 * max(abs(y_opt));

        idx_bl  = find(abs(y_bl(end:-1:1)) > thr_bl, 1);
        idx_opt = find(abs(y_opt(end:-1:1)) > thr_opt, 1);

        if isempty(idx_bl), ts_bl = 0; else, ts_bl = r_bl.t(end) - r_bl.t(end-idx_bl+1); end
        if isempty(idx_opt), ts_opt = 0; else, ts_opt = r_opt.t(end) - r_opt.t(end-idx_opt+1); end

        fprintf('  Settling %-6s:    %.3f s    ->  %.3f s    (%+.1f%%)\n', ...
            sig_name{1}, ts_bl, ts_opt, (ts_opt/max(ts_bl,1e-6) - 1)*100);
    end
end

fprintf('\n================================================================\n');
fprintf('  Copy these values into sec6_validation_results.tex\n');
fprintf('  Search for %%%%FILL%%%% to find placeholders\n');
fprintf('================================================================\n');
