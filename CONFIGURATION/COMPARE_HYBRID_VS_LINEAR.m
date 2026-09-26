%% COMPARE_HYBRID_VS_LINEAR.m
% Is the linear surrogate fitness good enough? The experiment of Section 4.1.3.
%
% RECONSTRUCTED FILE — READ THIS BEFORE TRUSTING ITS OUTPUT
%   The original was lost: its only copy sits in cloud storage in a state where
%   the file size is listed but the content cannot be retrieved. This file was
%   rebuilt from COMPARE_BASELINE_VS_V4.m (not shipped -- it drives the
%   superseded v4 design and reproduces nothing in this paper), from
%   PLOT_SCOPE_SIM.m, which is the authoritative scope channel map, and from
%   the description of the experiment in Section 4.1.3 of the paper.
%
%   ONE THING COULD NOT BE RECOVERED AND IS DECLARED RATHER THAN GUESSED: the
%   paper states that both designs were "re-evaluated under identical nonlinear
%   conditions" but does not name the disturbance used. The disturbance is set
%   in DISTURBANCE below. Until the value is confirmed against the measurement
%   record, the percentages this script prints are NOT the percentages in the
%   paper, and must not be substituted for them. The ordering of the two
%   designs is the robust part of the result; the exact percentages are not.
%
% WHAT SECTION 4.1.3 CLAIMS
%   For Phase 1 a hybrid fitness was also run. It kept J1 and J2 and added
%   three objectives evaluated on the full nonlinear model inside the
%   optimisation loop:
%     (a) integral of absolute error of the frequency deviation,
%     (b) peak rate of change of frequency over the first 500 ms,
%     (c) frequency nadir deviation.
%   Both designs were then re-evaluated under identical nonlinear conditions at
%   two operating points. The purely linear design is better on all three
%   nonlinear objectives at both points. The paper reports the hybrid design as
%   worse by 11.6 %, 40.0 % and 6.6 % at the first point, and by 11.2 %, 41.3 %
%   and 6.4 % at the second.
%
%   The conclusion that follows is that evaluating the nonlinear model inside
%   the optimisation loop buys nothing measurable and costs a great deal of
%   time, which is why every other phase uses the linear surrogate alone.
%
% SCOPE OF THE COMPARISON
%   This compares the two SELECTED designs, the compromise solution of each
%   Pareto front, not the nonlinear-best member of either front. It covers one
%   of the five phases. Both limits are properties of the experiment and are
%   stated in Section 4.1.3.
%
% PREREQUISITES:
%   1. In CONFIG_POWER_SYSTEM.m set RUN_MODE = 0 and CONTROL_TYPE = 2.
%   2. Run CONFIG_POWER_SYSTEM, which leaves LIN_MODEL in the workspace.
%   3. Run this script from the CONFIGURATION directory.
%
% SEE ALSO: COMPARE_BASELINE_VS_V6, RUN_PERTURBATION_SIM, PLOT_SCOPE_SIM

fprintf('\n============================================================\n');
fprintf('  COMPARE_HYBRID_VS_LINEAR — Section 4.1.3 surrogate check\n');
fprintf('  %s\n', datetime('now'));
fprintf('============================================================\n');

if ~exist('LIN_MODEL', 'var')
    error('COMPARE_HYBRID_VS_LINEAR:noModel', ...
          ['LIN_MODEL is not in the workspace. Run CONFIG_POWER_SYSTEM with ' ...
           'RUN_MODE = 0 and CONTROL_TYPE = 2 first.']);
end

addpath(fullfile(fileparts(pwd), 'SIMULATION'));
addpath(fullfile(fileparts(pwd), 'ANALYSIS'));

results_dir = '../RESULTS/CONTROL/';
nDFIG       = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;

%% The two Phase-1 designs
designs = {
    'LIN_MODEL_PDS_OPT_BIOBJ.mat',  'LINEAR';   % linear surrogate only
    'LIN_MODEL_PDS_OPT_HYBRID.mat', 'HYBRID'    % linear plus nonlinear objectives
};

%% The two operating points of Section 4.1.1
% The designated point is specified by the SOURCE voltage; the optimisation
% point by the PCC voltage. They are different conditions and neither implies
% the other.
operatingPoints = struct( ...
    'label', {'designated (P = 0.7 pu, |v_g| = 1 pu, SCR = 1)', ...
              'optimisation (P = 0.8 pu, V_pcc = 0.975 pu, SCR = 1)'}, ...
    'P',     {0.7,   0.8}, ...
    'Vp',    {1.000, 0.975}, ...
    'SCR',   {1,     1});

%% The disturbance — DECLARED, NOT RECOVERED. See the header.
DISTURBANCE = struct( ...
    'type',   'generation_loss', ...
    'config', struct('breaker_mask',  [1 zeros(1, nDFIG-1)], ...
                     'breaker_time',  1.0, ...
                     'sim_duration',  7.0, ...
                     'eval_window_f', [1.0, 6.0]));
ROCOF_WINDOW = 0.5;   % seconds after the event, per Section 4.1.3

CH_GRID_FREQ = [11 1];   % from PLOT_SCOPE_SIM.m

fprintf('\nDisturbance: %s at t = %.2f s, horizon %.1f s\n', ...
        DISTURBANCE.type, DISTURBANCE.config.breaker_time, ...
        DISTURBANCE.config.sim_duration);
fprintf('*** The disturbance is a declared assumption, not a recovered value.\n');
fprintf('*** Confirm it before quoting any percentage from this script.\n');

%% Run
nD  = size(designs, 1);
nOP = numel(operatingPoints);
res = struct();

for o = 1:nOP
    op = operatingPoints(o);
    fprintf('\n============================================================\n');
    fprintf('  OPERATING POINT %d of %d: %s\n', o, nOP, op.label);
    fprintf('============================================================\n');

    for d = 1:nD
        dFile = designs{d,1};
        dName = designs{d,2};

        filepath = fullfile(results_dir, dFile);
        if ~exist(filepath, 'file')
            error('COMPARE_HYBRID_VS_LINEAR:noDesign', ...
                  ['Design file not found: %s\nThe hybrid design is required ' ...
                   'by this experiment and is not part of the main pipeline.'], filepath);
        end
        data    = load(filepath);
        fn      = fieldnames(data);
        LOADED  = data.(fn{1});

        M = LIN_MODEL;
        M.CONTROL          = LOADED.CONTROL;
        M.opSpecs.P_ref    = op.P * ones(1, nDFIG);
        M.opSpecs.Vp       = op.Vp;
        M.MODEL.GRID.PARAM.SCR_grid = op.SCR;
        M.MODEL            = update_grid_impedances(M.MODEL);

        fprintf('\n  %s design: recomputing the operating point...\n', dName);
        M = LINEAR_ANALYSIS(M);

        cd ../BUS_DEFINITIONS
        BusDefinition(M.MODEL,   'MODEL_Bus');
        BusDefinition(M.CONTROL, 'CONTROL_Bus');
        cd ../CONFIGURATION
        assignin('base','CONTROL_INI',M.CONTROL);
        assignin('base','MODEL_INI',  M.MODEL);

        r = RUN_PERTURBATION_SIM(M, DISTURBANCE.type, DISTURBANCE.config);
        if ~r.success
            error('COMPARE_HYBRID_VS_LINEAR:simFailed', ...
                  '%s at operating point %d did not complete: %s', dName, o, r.error);
        end

        m = local_nonlinear_objectives(r, CH_GRID_FREQ, ...
                                       DISTURBANCE.config.breaker_time, ROCOF_WINDOW);
        fprintf('    IAE(df) = %.6f   peak RoCoF = %.6f pu/s   nadir(df) = %.6f\n', ...
                m.IAE_df, m.peak_RoCoF, m.nadir_df);
        res(o).(dName) = m;
    end
end

%% Comparison
fprintf('\n\n============================================================\n');
fprintf('  LINEAR SURROGATE vs HYBRID FITNESS\n');
fprintf('  Positive change means the hybrid design is WORSE.\n');
fprintf('============================================================\n');

objNames  = {'IAE_df','peak_RoCoF','nadir_df'};
objLabels = {'IAE of frequency deviation', ...
             'peak RoCoF over first 500 ms', ...
             'frequency nadir deviation'};

hybridWorseEverywhere = true;
for o = 1:nOP
    fprintf('\n--- %s ---\n', operatingPoints(o).label);
    fprintf('%-32s  %12s  %12s  %10s\n','Objective','LINEAR','HYBRID','Change');
    for k = 1:numel(objNames)
        vL = res(o).LINEAR.(objNames{k});
        vH = res(o).HYBRID.(objNames{k});
        ch = (vH - vL)/abs(vL)*100;
        if ch <= 0, hybridWorseEverywhere = false; end
        fprintf('%-32s  %12.6f  %12.6f  %+9.1f%%\n', objLabels{k}, vL, vH, ch);
    end
end

fprintf('\n------------------------------------------------------------\n');
if hybridWorseEverywhere
    fprintf('  The linear design is better on all three objectives at both\n');
    fprintf('  operating points. This is the ordering Section 4.1.3 reports.\n');
else
    fprintf('  The linear design is NOT better everywhere. This contradicts\n');
    fprintf('  Section 4.1.3 and must be resolved before the section stands.\n');
end
fprintf('  Percentages depend on the disturbance declared at the top of this\n');
fprintf('  file and are not the published values until that is confirmed.\n');
fprintf('------------------------------------------------------------\n');

%% Save
outDir = fullfile('..','RESULTS','SIMULATION','COMPARISON_HYBRID_VS_LINEAR');
if ~exist(outDir,'dir'), mkdir(outDir); end
timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
outFile   = fullfile(outDir, sprintf('hybrid_vs_linear_%s.mat', timestamp));
save(outFile, 'res', 'designs', 'operatingPoints', 'DISTURBANCE', 'ROCOF_WINDOW');
fprintf('\nSaved: %s\n', outFile);

%% Local functions
function m = local_nonlinear_objectives(results, ch, tEvent, rocofWindow)
%LOCAL_NONLINEAR_OBJECTIVES The three nonlinear objectives of Section 4.1.3.
v = results.SCOPE_SIM.signals(ch(1)).values;
if ndims(v) == 3
    f = squeeze(v(ch(2), 1, :));
else
    f = v(:, ch(2));
end
f = f(:);
t = results.t(:);

pre  = t < tEvent;
f0   = mean(f(pre));
post = t >= tEvent;
tp   = t(post);
df   = f(post) - f0;

m = struct();
m.IAE_df    = trapz(tp, abs(df));
m.nadir_df  = max(abs(df));

% RoCoF over the first rocofWindow seconds after the event.
w = tp <= tEvent + rocofWindow;
if nnz(w) > 2
    m.peak_RoCoF = max(abs(diff(df(w)) ./ diff(tp(w))));
else
    m.peak_RoCoF = NaN;
end
end
