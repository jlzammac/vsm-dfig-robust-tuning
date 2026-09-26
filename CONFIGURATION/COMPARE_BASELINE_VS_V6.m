%% COMPARE_BASELINE_VS_V6.m
% Nonlinear transient comparison: CFRD baseline vs GA-optimised design.
% Produces the Section 6.1 and 6.2 results of the paper.
%
% RECONSTRUCTED FILE — READ THIS BEFORE TRUSTING ITS OUTPUT
%   The original driver was lost: its only copy sits in cloud storage in a
%   state where the file size is listed but the content cannot be retrieved.
%   This file was rebuilt from three sources that are present and verified:
%     - COMPARE_BASELINE_VS_V4.m, the direct sibling of this script, which
%       supplied the whole structure: controller loading, operating-point
%       recomputation, the perturbation loop, metric collection and figure
%       export. THAT FILE IS NOT SHIPPED HERE: it drives the superseded v4
%       design and reproduces nothing in this paper, so it fails the test
%       that everything in this repository must be necessary to reproduce a
%       published result. It remains in the authors' working tree for anyone
%       auditing this reconstruction.
%     - RUN_PAPER_V6_NL_VALIDATION.m, which specifies what this script must
%       produce: two perturbations, two controllers, the figures named below
%       and the LaTeX rows printed to the console.
%     - PLOT_SCOPE_SIM.m, which is the authoritative SCOPE_SIM channel map.
%   It is functionally equivalent, not byte-identical. The test of whether it
%   is correct is not that it runs: it is that the numbers it prints match the
%   ones published in Sections 6.1 and 6.2. Check them before citing.
%
% PREREQUISITES:
%   1. In CONFIG_POWER_SYSTEM.m set RUN_MODE = 0 and CONTROL_TYPE = 2.
%   2. Run CONFIG_POWER_SYSTEM, which leaves LIN_MODEL in the workspace.
%   3. Run this script from the CONFIGURATION directory.
%
% DESIGN CONFIGURATION:
%   These runs use the design configuration of Section 2.2, with no active
%   limiting and no active protection. That is deliberate and it is what
%   Sections 6.1 and 6.2 report. The symmetric-fault campaign of Section 6.3
%   is the only study that arms the protection mechanisms, and it is driven
%   separately by SIMULATION/b7_campaign.m. The two sets are not comparable
%   and must not be pooled.
%
% PERTURBATIONS:
%   1. P_ref step, +0.15 pu on DFIG 1
%   2. Grid voltage sag, 20 % depth for 150 ms, applied at the grid bus behind
%      the Thevenin impedance. Appreciably less than 20 % reaches the PCC.
%
% OUTPUTS:
%   FIGURES/PAPER_V6/nl_pref_step.pdf        rotor-turbine speed difference
%   FIGURES/PAPER_V6/nl_voltage_dip.pdf      DC-link voltage and GSC q current
%   FIGURES/PAPER_V6/*_overview.pdf          four-panel supplementary figures
%   RESULTS/SIMULATION/COMPARISON_BASELINE_VS_V6/comparison_v6_*.mat
%   Console: metric table and LaTeX rows for the Section 6 tables.
%
% SEE ALSO: RUN_PAPER_V6_NL_VALIDATION, RUN_PERTURBATION_SIM,
%           COMPUTE_PERTURBATION_METRICS, PLOT_SCOPE_SIM

fprintf('\n============================================================\n');
fprintf('  COMPARE_BASELINE_VS_V6 — nonlinear transient comparison\n');
fprintf('  %s\n', datetime('now'));
fprintf('============================================================\n');

%% Prerequisites
if ~exist('LIN_MODEL', 'var')
    error('COMPARE_BASELINE_VS_V6:noModel', ...
          ['LIN_MODEL is not in the workspace. Run CONFIG_POWER_SYSTEM with ' ...
           'RUN_MODE = 0 and CONTROL_TYPE = 2 first.']);
end

addpath(fullfile(fileparts(pwd), 'SIMULATION'));
addpath(fullfile(fileparts(pwd), 'ANALYSIS'));

%% Configuration
results_dir = '../RESULTS/CONTROL/';
nDFIG       = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;

% Controller sets. The GA design is the Phase 5 output of the bi-objective
% workflow of Section 4.2, which is the design reported in Table 5.
controllers = {
    'LIN_MODEL_FRD_DESIGN.mat',   'BASELINE';
    'LIN_MODEL_VI_OPT_BIOBJ.mat', 'GAv6'
};

% SCOPE_SIM channel map, from PLOT_SCOPE_SIM.m. Named rather than inlined so
% that a change in the scope block surfaces here instead of silently plotting
% the wrong quantity.
CH = struct( ...
    'P_DFIG',        [1 2], ...
    'VDC',           [3 2], ...
    'Q_DFIG',        [5 2], ...
    'V_PCC',         [6 3], ...
    'GSC_IQ',        [8 4], ...
    'GRID_FREQ',    [11 1], ...
    'SPEED_ROTOR',  [13 1], ...
    'SPEED_TURBINE',[13 2]);

%% Perturbation scenarios
pertScenarios = struct();

pertScenarios(1).name   = 'pref_step';
pertScenarios(1).label  = 'P_{ref} step (+0.15 pu, DFIG 1)';
pertScenarios(1).field  = 'pref';
pertScenarios(1).config = struct( ...
    'pref_mask',    [1 zeros(1, nDFIG-1)], ...
    'pref_delta',   0.15, ...
    'pref_time',    1.0, ...
    'sim_duration', 7.0, ...
    'eval_window_f',[1.0, 6.0]);

pertScenarios(2).name   = 'voltage_sag';
pertScenarios(2).label  = 'Grid voltage sag (20 %, 150 ms)';
pertScenarios(2).field  = 'v_dip';
pertScenarios(2).config = struct( ...
    'sag_depth',      0.20, ...
    'sag_start_time', 0.5, ...       % as published (Section 6.2, Figure 13)
    'sag_duration',   0.15, ...
    'sim_duration',   3.5, ...
    'eval_window_v',  [0.5, 3.01]);

nPerts = numel(pertScenarios);
nCtrl  = size(controllers, 1);

%% Run
all_metrics = struct();
all_results = struct();

for c = 1:nCtrl
    ctrl_file = controllers{c, 1};
    ctrl_name = controllers{c, 2};

    fprintf('\n============================================================\n');
    fprintf('  CONTROLLER SET: %s  (%s)\n', ctrl_name, ctrl_file);
    fprintf('============================================================\n');

    filepath = fullfile(results_dir, ctrl_file);
    if ~exist(filepath, 'file')
        error('COMPARE_BASELINE_VS_V6:noController', ...
              'Controller file not found: %s', filepath);
    end
    data              = load(filepath);
    fn                = fieldnames(data);
    LIN_MODEL_LOADED  = data.(fn{1});

    % Saved CONTROL, current MODEL. Both designs are therefore evaluated on an
    % identical plant at an identical operating point, which is the condition
    % Section 4.1.3 requires for the comparison to mean anything.
    LIN_MODEL_TEST         = LIN_MODEL;
    LIN_MODEL_TEST.CONTROL = LIN_MODEL_LOADED.CONTROL;

    fprintf('  Recomputing the operating point...\n');
    LIN_MODEL_TEST = LINEAR_ANALYSIS(LIN_MODEL_TEST);

    cd ../BUS_DEFINITIONS
    BusDefinition(LIN_MODEL_TEST.MODEL,   'MODEL_Bus');
    BusDefinition(LIN_MODEL_TEST.CONTROL, 'CONTROL_Bus');
    cd ../CONFIGURATION

    assignin('base', 'CONTROL_INI', LIN_MODEL_TEST.CONTROL);
    assignin('base', 'MODEL_INI',   LIN_MODEL_TEST.MODEL);

    fprintf('  Operating point: V_pcc = %.3f pu, P = %.3f pu/DFIG, SCR = %.1f\n', ...
        LIN_MODEL_TEST.opSpecs.Vp, LIN_MODEL_TEST.opSpecs.P_ref(1), ...
        LIN_MODEL_TEST.MODEL.GRID.PARAM.SCR_grid);

    for p = 1:nPerts
        pName   = pertScenarios(p).name;
        pLabel  = pertScenarios(p).label;
        pConfig = pertScenarios(p).config;
        pField  = pertScenarios(p).field;

        fprintf('\n  [%d/%d] %s\n', p, nPerts, pLabel);
        tStart   = tic;
        results_p = RUN_PERTURBATION_SIM(LIN_MODEL_TEST, pName, pConfig);
        tElapsed = toc(tStart);

        if results_p.success
            metrics_p = COMPUTE_PERTURBATION_METRICS(results_p, pName, pConfig);
            fprintf('    completed in %.1f s\n', tElapsed);
            if isfield(metrics_p, 'IAE_f') && ~isnan(metrics_p.IAE_f)
                fprintf('    IAE_f = %.6f, ITAE_f = %.6f, nadir_f = %.4f\n', ...
                        metrics_p.IAE_f, metrics_p.ITAE_f, metrics_p.nadir_f);
            end
            if isfield(metrics_p, 'IAE_V') && ~isnan(metrics_p.IAE_V)
                fprintf('    IAE_V = %.6f, ITAE_V = %.6f, nadir_V = %.4f\n', ...
                        metrics_p.IAE_V, metrics_p.ITAE_V, metrics_p.nadir_V);
            end
        else
            fprintf('    FAILED: %s\n', results_p.error);
            metrics_p = struct();
        end

        all_metrics.(ctrl_name).(pField) = metrics_p;
        all_results.(ctrl_name).(pField) = results_p;
    end
end

%% Derived quantities the paper quotes but the metric function does not return
% Peak |Delta u_dc| and peak |Delta omega| are read here, on the same window as
% the figures, so that figure and text report one quantity and not two.
derived = struct();
for c = 1:nCtrl
    ctrl_name = controllers{c, 2};
    for p = 1:nPerts
        pField = pertScenarios(p).field;
        r = all_results.(ctrl_name).(pField);
        if ~r.success, continue, end

        vdc   = local_chan(r, CH.VDC);
        wr    = local_chan(r, CH.SPEED_ROTOR);
        wt    = local_chan(r, CH.SPEED_TURBINE);
        igscq = local_chan(r, CH.GSC_IQ);
        t     = r.t(:);

        tEvent = local_event_time(pertScenarios(p).config);
        pre    = t >= tEvent - 0.05 & t < tEvent;   % published reference: the 50 ms before the event
        post   = t >= tEvent;

        d = struct();
        d.peak_dVdc   = max(abs(vdc(post)   - mean(vdc(pre))));
        d.peak_dOmega = max(abs((wr(post)-wt(post)) - mean(wr(pre)-wt(pre))));
        d.peak_igscq  = max(abs(igscq(post) - mean(igscq(pre))));
        derived.(ctrl_name).(pField) = d;
    end
end

%% Comparison table
fprintf('\n\n============================================================\n');
fprintf('  BASELINE vs GA-OPTIMISED — nonlinear transient metrics\n');
fprintf('  V_pcc = %.2f pu, P = %.2f pu/DFIG, SCR = %.1f\n', ...
    LIN_MODEL.opSpecs.Vp, LIN_MODEL.opSpecs.P_ref(1), ...
    LIN_MODEL.MODEL.GRID.PARAM.SCR_grid);
fprintf('============================================================\n\n');

metric_fields = {'IAE_f','ITAE_f','ROCOF','nadir_f','settling_f', ...
                 'IAE_V','ITAE_V','ROCOV','nadir_V','settling_V', ...
                 'IAE_P','IAE_Q'};

for p = 1:nPerts
    pField = pertScenarios(p).field;
    fprintf('--- %s ---\n', pertScenarios(p).label);
    fprintf('%-16s  %14s  %14s  %10s\n', 'Metric','BASELINE','GA-OPTIMISED','Change');
    fprintf('%-16s  %14s  %14s  %10s\n', '------','--------','------------','------');

    m_B = all_metrics.BASELINE.(pField);
    m_G = all_metrics.GAv6.(pField);
    for mf = 1:numel(metric_fields)
        f = metric_fields{mf};
        if isfield(m_B,f) && isfield(m_G,f)
            vB = m_B.(f); vG = m_G.(f);
            if ~isnan(vB) && ~isnan(vG) && abs(vB) > 1e-12
                fprintf('%-16s  %14.6f  %14.6f  %+9.1f%%\n', ...
                        f, vB, vG, (vG-vB)/abs(vB)*100);
            end
        end
    end

    if isfield(derived,'BASELINE') && isfield(derived.BASELINE, pField)
        dB = derived.BASELINE.(pField);
        dG = derived.GAv6.(pField);
        for f = {'peak_dVdc','peak_dOmega','peak_igscq'}
            vB = dB.(f{1}); vG = dG.(f{1});
            if abs(vB) > 1e-12
                fprintf('%-16s  %14.6f  %14.6f  %+9.1f%%\n', ...
                        f{1}, vB, vG, (vG-vB)/abs(vB)*100);
            end
        end
    end
    fprintf('\n');
end

%% LaTeX rows for the Section 6 tables
fprintf('------------------------------------------------------------\n');
fprintf('  LaTeX rows (paste into the Section 6 table)\n');
fprintf('------------------------------------------------------------\n');
for p = 1:nPerts
    pField = pertScenarios(p).field;
    if ~isfield(derived,'BASELINE') || ~isfield(derived.BASELINE, pField), continue, end
    dB = derived.BASELINE.(pField);
    dG = derived.GAv6.(pField);
    fprintf('%% %s\n', pertScenarios(p).label);
    fprintf('$|\\Delta u_{dc}|_{peak}$ (pu) & %.4f & %.4f & %+.1f\\%% \\\\\n', ...
            dB.peak_dVdc, dG.peak_dVdc, (dG.peak_dVdc-dB.peak_dVdc)/abs(dB.peak_dVdc)*100);
    fprintf('$|\\Delta\\omega|_{peak}$ (pu) & %.5f & %.5f & %+.1f\\%% \\\\\n', ...
            dB.peak_dOmega, dG.peak_dOmega, (dG.peak_dOmega-dB.peak_dOmega)/abs(dB.peak_dOmega)*100);
end
fprintf('------------------------------------------------------------\n');

%% Save
fprintf('\nSaving results...\n');
outDir = fullfile('..','RESULTS','SIMULATION','COMPARISON_BASELINE_VS_V6');
if ~exist(outDir,'dir'), mkdir(outDir); end

timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
mFile = fullfile(outDir, sprintf('comparison_v6_%s.mat', timestamp));
save(mFile, 'all_metrics', 'derived', 'pertScenarios', 'controllers');
fprintf('  Metrics: %s\n', mFile);

scope_data = struct();
for c = 1:nCtrl
    ctrl_name = controllers{c,2};
    for p = 1:nPerts
        pField = pertScenarios(p).field;
        if all_results.(ctrl_name).(pField).success
            scope_data.(ctrl_name).(pField).SCOPE_SIM = all_results.(ctrl_name).(pField).SCOPE_SIM;
            scope_data.(ctrl_name).(pField).t         = all_results.(ctrl_name).(pField).t;
        end
    end
end
sFile = fullfile(outDir, sprintf('comparison_v6_SCOPE_%s.mat', timestamp));
save(sFile, 'scope_data', '-v7.3');
fprintf('  Traces: %s\n', sFile);

%% Figures
fprintf('\n============================================================\n');
fprintf('  FIGURES\n');
fprintf('============================================================\n');

fig_dir = fullfile('..','FIGURES','PAPER_V6');
if ~exist(fig_dir,'dir'), mkdir(fig_dir); end

COL_B = [0 0 0];      % baseline, black
COL_G = [0.80 0 0];   % optimised, dark red
LW    = 1.5;

% Each panel spec is ONE ROW of an N-by-4 cell array: {title, ylabel, channel,
% xlim}. The rows are separated by semicolons INSIDE a single pair of braces.
%
% Writing them as {{...} {...}} instead -- a cell of 1-by-4 cells -- builds an
% N-by-1 array whose elements are cells, and the panel loop below indexes
% panels{sp,2}, which then throws "Index in position 2 exceeds array bounds".
% That was the original form here and it reached the figure stage only after
% every simulation had finished, so it cost a full run to find.
headline = {
    'pref',  'nl_pref_step',   {'Rotor-turbine speed difference', '\Delta\omega = \omega_r - \omega_t (pu)', 'domega', [0.8 5.0]}
    'v_dip', 'nl_voltage_dip', {'DC-link voltage',     'u_{dc} (pu)',    CH.VDC,     [0.3 3.0]; ...
                                'GSC q-axis current',  'i_{GSCq} (pu)',  CH.GSC_IQ,  [0.3 3.0]}
};

% Four-panel supplementary figures.
overview = {
    'pref',  'nl_pref_step_overview',   {'DFIG active power',     'P (pu)',         CH.P_DFIG,    [0.8 5.0]; ...
                                         'Grid frequency',        'f (pu)',         CH.GRID_FREQ, [0.8 5.0]; ...
                                         'PCC voltage',           'V_{pcc} (pu)',   CH.V_PCC,     [0.8 5.0]; ...
                                         'DFIG reactive power',   'Q (pu)',         CH.Q_DFIG,    [0.8 5.0]}
    'v_dip', 'nl_voltage_dip_overview', {'PCC voltage',           'V_{pcc} (pu)',   CH.V_PCC,     [0.3 3.0]; ...
                                         'DC-link voltage',       'u_{dc} (pu)',    CH.VDC,       [0.3 3.0]; ...
                                         'Grid frequency',        'f (pu)',         CH.GRID_FREQ, [0.3 3.0]; ...
                                         'DFIG reactive power',   'Q (pu)',         CH.Q_DFIG,    [0.3 3.0]}
};

for spec = [headline; overview]'
    pField  = spec{1};
    figName = spec{2};
    panels  = spec{3};

    if ~all_results.BASELINE.(pField).success || ~all_results.GAv6.(pField).success
        fprintf('  [skipped] %s — a simulation did not complete\n', figName);
        continue
    end
    rB = all_results.BASELINE.(pField);
    rG = all_results.GAv6.(pField);
    n  = size(panels,1);

    fig = figure('Visible','off','Position',[100 100 800 200*n], ...
                 'Color','w','PaperPositionMode','auto');
    for sp = 1:n
        subplot(n,1,sp);
        ttl = panels{sp,1}; ylab = panels{sp,2}; ch = panels{sp,3}; xl = panels{sp,4};

        if ischar(ch) && strcmp(ch,'domega')
            yB = local_chan(rB, CH.SPEED_ROTOR) - local_chan(rB, CH.SPEED_TURBINE);
            yG = local_chan(rG, CH.SPEED_ROTOR) - local_chan(rG, CH.SPEED_TURBINE);
        else
            yB = local_chan(rB, ch);
            yG = local_chan(rG, ch);
        end

        plot(rB.t, yB, 'Color', COL_B, 'LineWidth', LW); hold on
        plot(rG.t, yG, 'Color', COL_G, 'LineWidth', LW, 'LineStyle','--'); hold off
        ylabel(ylab,'FontSize',10);
        title(ttl,'FontSize',11,'FontWeight','bold');
        xlim(xl); grid on; set(gca,'FontSize',9);
        if sp == 1
            legend({'Baseline (CFRD)','GA-optimised'},'FontSize',9,'Location','best');
        end
        if sp == n
            xlabel('Time (s)','FontSize',10);
        end
    end

    exportgraphics(fig, fullfile(fig_dir,[figName '.pdf']), ...
                   'ContentType','vector','BackgroundColor','white');
    savefig(fig, fullfile(fig_dir,[figName '.fig']));
    close(fig);
    fprintf('  [ok] %s.pdf\n', figName);
end

fprintf('\n============================================================\n');
fprintf('  COMPLETE — %d perturbations, %d controllers\n', nPerts, nCtrl);
fprintf('  Figures: FIGURES/PAPER_V6/\n');
fprintf('  Data:    RESULTS/SIMULATION/COMPARISON_BASELINE_VS_V6/\n');
fprintf('============================================================\n');

%% Local functions
function y = local_chan(results, ch)
%LOCAL_CHAN Extract one channel of one scope as a column vector.
% ch is [scopeIndex channelIndex] from the map in PLOT_SCOPE_SIM.m. The scope
% logs either [nChannels x nUnits x nSamples] or [nSamples x nChannels]
% depending on the release, so both layouts are handled.
v = results.SCOPE_SIM.signals(ch(1)).values;
if ndims(v) == 3
    y = squeeze(v(ch(2), 1, :));
else
    y = v(:, ch(2));
end
y = y(:);
end

function tEvent = local_event_time(cfg)
%LOCAL_EVENT_TIME Instant at which the perturbation is applied.
if     isfield(cfg,'pref_time'),      tEvent = cfg.pref_time;
elseif isfield(cfg,'sag_start_time'), tEvent = cfg.sag_start_time;
elseif isfield(cfg,'qref_time'),      tEvent = cfg.qref_time;
elseif isfield(cfg,'load_time'),      tEvent = cfg.load_time;
elseif isfield(cfg,'breaker_time'),   tEvent = cfg.breaker_time;
else,  tEvent = 1.0;
end
end
