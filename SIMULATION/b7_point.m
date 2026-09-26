function summary = b7_point(tag, SCR, P, r_src, dur, Thor, outDir)
%B7_POINT Run one point of the symmetric-fault campaign of Section 6.3.
%
% DESCRIPTION:
%   Executes a single 150 ms symmetric fault on the four-machine benchmark and
%   writes BOTH the full state trajectories and the per-run summary metrics.
%
%   This harness reproduces Figure 14 and Table 10 of the paper. It replaces the
%   original campaign driver, which was run once per point in a disposable copy
%   of the repository and was not itself retained. The per-run summaries of that
%   campaign were retained and hold every quantity printed in Table 10; the state
%   trajectories behind Figure 14 were not. This function writes both, so the
%   omission cannot recur.
%
% THE VERIFICATION CONFIGURATION — WHY THIS FUNCTION PATCHES THE MODEL
%   Section 2.2 of the paper distinguishes a DESIGN configuration, carrying no
%   active limiting or protection, from a VERIFICATION configuration in which
%   three mechanisms are armed. The three master enables are literal constants
%   inside two Stateflow charts of POWER_SYSTEM_FULL.slx, not workspace
%   parameters:
%
%     LIM_EN     current-reference limiting, RSC and GSC   (chart "RSC/GSC")
%     RSCBLK_EN  RSC voltage derate                        (same chart)
%     CHOP_EN    DC-link chopper                           (chart "DC LINK")
%
%   All three are 0 in the model as distributed, which is the design
%   configuration and the one every small-signal result of the paper uses.
%   Arming them therefore requires editing the model. This function edits a
%   WORKING COPY and never the distributed file, so the design configuration
%   stays pristine and the two configurations cannot be silently conflated.
%
% INPUTS:
%   tag    - Run identifier, e.g. 'm_S1_P0.8_V90'. Names the output files.
%   SCR    - Short-circuit ratio at the PCC: 1, 1.5, 2 or 3.
%   P      - Active power dispatched per DFIG [pu], 0.4 or 0.8.
%   r_src  - Retained fraction of the Thevenin SOURCE voltage during the fault,
%            in [0,1]. NOT the retained PCC voltage. The fault is applied by
%            scaling the source behind Z_grid; the retained PCC voltage is a
%            RESULT and is reported in summary.PCC_ret. The two are not
%            proportional, and one source fraction leaves a different PCC
%            voltage at each SCR, which is why the campaign specifies r_src per
%            run. Values are tabulated in REPRODUCE/tab10_fault_phases.md.
%   dur    - Fault duration [s]. The campaign uses 0.15.
%   Thor   - Simulation horizon [s]. The campaign uses 3.0.
%   outDir - (optional) Destination directory. Default RESULTS/B7_CAMPAIGN/.
%
% OUTPUT:
%   summary - Struct of per-run metrics. Also written to <outDir>/b7_<tag>_summary.mat
%             together with <outDir>/b7_<tag>_traces.mat, which holds the full
%             time series.
%
% PRE-FAULT OPERATING POINT:
%   The campaign runs at the PCC voltage of the optimisation operating point,
%   V_pcc = 0.975 pu, and NOT at the 1.0 pu of Sections 6.1 and 6.2. The
%   pre-fault transmission angles of Table 10 cannot be reproduced without this.
%
% EXAMPLE — panel (a) of Figure 14:
%   summary = b7_point('m_S1_P0.8_V90', 1, 0.8, 0.73064, 0.15, 3.0);
%
% SEE ALSO: RUN_PERTURBATION_SIM, LINEAR_ANALYSIS, b7_campaign

%--------------------------------------------------------------------------
%% ARGUMENTS AND PATHS
%--------------------------------------------------------------------------
narginchk(6, 7);
validateattributes(SCR,   {'numeric'}, {'scalar','positive'},          mfilename, 'SCR');
validateattributes(P,     {'numeric'}, {'scalar','positive'},          mfilename, 'P');
validateattributes(r_src, {'numeric'}, {'scalar','>=',0,'<=',1},       mfilename, 'r_src');
validateattributes(dur,   {'numeric'}, {'scalar','positive'},          mfilename, 'dur');
validateattributes(Thor,  {'numeric'}, {'scalar','positive'},          mfilename, 'Thor');

% Repository root, resolved relative to this file. SIMULATION/ sits at the root.
repoRoot = fileparts(fileparts(mfilename('fullpath')));
if nargin < 7 || isempty(outDir)
    outDir = fullfile(repoRoot, 'RESULTS', 'B7_CAMPAIGN');
end
if ~exist(outDir, 'dir'), mkdir(outDir); end

VPCC_CAMPAIGN = 0.975;   % pre-fault PCC voltage, Section 4.1.1
T_FAULT       = 0.200;   % fault inception [s]; clearance at T_FAULT + dur

fprintf('=========================================================================\n');
fprintf('  B7 point %s : SCR = %g, P = %g pu, source retained = %.5f\n', tag, SCR, P, r_src);
fprintf('  Fault %.0f ms from t = %.3f s, horizon %.1f s, pre-fault V_pcc = %.3f pu\n', ...
        dur*1e3, T_FAULT, Thor, VPCC_CAMPAIGN);
fprintf('=========================================================================\n');

%--------------------------------------------------------------------------
%% WORKING COPY OF THE MODEL WITH THE THREE MECHANISMS ARMED
%--------------------------------------------------------------------------
mirrorRoot   = b7_arm_mechanisms(repoRoot, tag);
cleanupModel = onCleanup(@() b7_cleanup(mirrorRoot));

% Per-machine logging. SCOPE_SIM carries none: all fifteen of its signal groups
% have a unit dimension of 1. Figure 14 needs one trace per machine, so it is
% added here, in the mirror only.
b7_enable_per_machine_logging(mirrorRoot);
Simulink.sdi.clear;

%--------------------------------------------------------------------------
%% OPERATING POINT
%--------------------------------------------------------------------------
LIN_MODEL = b7_build_operating_point(mirrorRoot, [], SCR, P, VPCC_CAMPAIGN);

%--------------------------------------------------------------------------
%% FAULT
%--------------------------------------------------------------------------
pertConfig                 = struct();
pertConfig.sag_depth       = 1 - r_src;    % depth at the SOURCE, behind Z_grid
pertConfig.sag_start_time  = T_FAULT;
pertConfig.sag_duration    = dur;
pertConfig.sim_duration    = Thor;

oldDir = pwd; cd(fullfile(mirrorRoot, 'SIMULATION'));
restoreDir = onCleanup(@() cd(oldDir));
results = RUN_PERTURBATION_SIM(LIN_MODEL, 'voltage_sag', pertConfig);
clear restoreDir

if ~results.success
    error('b7_point:simFailed', 'Run %s did not complete: %s', tag, results.error);
end

%--------------------------------------------------------------------------
%% TRACES — WRITTEN FIRST, BEFORE ANY METRIC IS COMPUTED
%--------------------------------------------------------------------------
% Deliberate ordering. The campaign that produced the published Figure 14 kept
% the metrics and discarded the trajectories. Writing the trajectories first
% means an error in the metric code cannot cost the run.
traces           = struct();
traces.tag       = tag;
traces.t         = results.t;
traces.SCOPE_SIM = results.SCOPE_SIM;
traces.spec      = struct('SCR', SCR, 'P', P, 'r_src', r_src, 'dur', dur, ...
                          'Thor', Thor, 'Vpcc_prefault', VPCC_CAMPAIGN, ...
                          't_fault', T_FAULT);
% signals(6) = [Vs_ref, Vs, PCC_V, Grid_V]. Channel 2 is the machine terminal
% voltage |u_dqs| plotted in Figure 14, channel 3 the PCC voltage.
%
% Layout, per PLOT_SCOPE_SIM.m and the Section 6 figure scripts: when the log
% is three-dimensional it is [channel x unit x sample]. The unit dimension is
% the machine index where the quantity is per-machine and is a singleton where
% it is not, so it is read rather than assumed.
sig6 = results.SCOPE_SIM.signals(6).values;
traces.scope6_size = size(sig6);
fprintf('  signals(6) layout: [%s]\n', strjoin(string(size(sig6)), ' x '));

traces.V_pcc  = local_pick(sig6, 3);
traces.V_grid = local_pick(sig6, 4);

% Per-machine terminal voltage, the quantity Figure 14 plots. Falls back to the
% single-unit scope channel if the logging did not take, and says so, rather
% than silently plotting one machine four times.
PM = b7_fetch_per_machine(LIN_MODEL.MODEL.DFIG.PARAM.nDFIG);
if PM.found > 0
    traces.Vs_machines   = PM.Vs;
    traces.Vs_machines_t = PM.t;
    traces.per_machine   = true;
else
    warning('b7_point:noPerMachine', ...
            ['Per-machine traces unavailable; falling back to the single-unit ' ...
             'scope channel. Figure 14 cannot be drawn from this run.']);
    traces.Vs_machines = local_pick(sig6, 2);
    traces.per_machine = false;
end

tracesFile = fullfile(outDir, sprintf('b7_%s_traces.mat', tag));
save(tracesFile, '-struct', 'traces', '-v7.3');
fprintf('  Traces written : %s\n', tracesFile);

%--------------------------------------------------------------------------
%% SUMMARY METRICS
%--------------------------------------------------------------------------
summary = b7_metrics(results, traces, tag, SCR, P, r_src, dur, Thor, ...
                     VPCC_CAMPAIGN, T_FAULT);

summaryFile = fullfile(outDir, sprintf('b7_%s_summary.mat', tag));
save(summaryFile, '-struct', 'summary');
fprintf('  Summary written: %s\n', summaryFile);
fprintf('  Pre-fault PCC %.4f pu, retained PCC %.4f pu, delta_pre %.1f deg\n', ...
        summary.PCC_pre, summary.PCC_ret, summary.delta_pre);

end

%% ------------------------------------------------------------------------
function y = local_pick(v, ch)
%LOCAL_PICK One channel of a scope log, returned as [nSamples x nUnits].
%
% The log is [channel x unit x sample] when three-dimensional and
% [sample x channel] when it is not. The unit dimension carries the machine
% index for per-machine quantities and is a singleton otherwise; both are
% returned in the same orientation so callers do not have to branch.
if ndims(v) == 3
    if ch > size(v,1)
        error('b7_point:noSuchChannel', ...
              'Channel %d requested but the log has %d.', ch, size(v,1));
    end
    y = permute(v(ch, :, :), [3 2 1]);      % [sample x unit]
else
    if ch > size(v,2)
        error('b7_point:noSuchChannel', ...
              'Channel %d requested but the log has %d.', ch, size(v,2));
    end
    y = v(:, ch);
end
end
