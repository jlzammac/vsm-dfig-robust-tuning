function TABLE11_SCR_SWEEP(design, outDir)
%TABLE11_SCR_SWEEP  Table 11 runs: generation loss and voltage sag at four SCRs.
%
%   TABLE11_SCR_SWEEP('BASE', outDir)   baseline, LIN_MODEL_FRD_DESIGN.mat
%   TABLE11_SCR_SWEEP('GA',   outDir)   optimised, LIN_MODEL_VI_OPT_BIOBJ.mat
%
%   Eight nonlinear runs per design: SCR in {1, 1.5, 2, 3} x {generation loss,
%   voltage sag}, at the configuration's operating point (P = 0.7 pu,
%   V_pcc = 1.0 pu). Only the SCR and the impedances derived from it move.
%   Both events at t = 0.5 s, 3.5 s horizon; generation loss trips DFIG 4, the
%   sag is 20 % of the grid source for 150 ms.
%
%   Each run is saved as <outDir>/<design>_<event>_SCR<x.x>.mat and skipped if
%   it already exists, so the sweep can be run in pieces. Running the model
%   rewrites POWER_SYSTEM_FULL.slx: use a clone of the repository per design
%   if the two are run in parallel. About 20 min per run.
%
%   Metrics: ANALYSIS/TABLE11_METRICS.m. See REPRODUCE/tab11_scr_sweep.md.

switch upper(design)
    case 'BASE', dfile = 'LIN_MODEL_FRD_DESIGN.mat';
    case 'GA',   dfile = 'LIN_MODEL_VI_OPT_BIOBJ.mat';
    otherwise,   error('TABLE11_SCR_SWEEP:design', 'design must be ''BASE'' or ''GA''');
end
R = fileparts(fileparts(mfilename('fullpath')));
if ~exist(outDir, 'dir'), mkdir(outDir); end

cd(fullfile(R, 'CONFIGURATION'));
evalin('base', 'CONFIG_POWER_SYSTEM');            % RUN_MODE = 0, the design configuration
LIN_MODEL = evalin('base', 'LIN_MODEL');
addpath(fullfile(R, 'SIMULATION'), fullfile(R, 'ANALYSIS'));
cd(fullfile(R, 'CONFIGURATION'));
evalin('base', 'SETUP_PERTURBATION_BLOCKS');
cd(fullfile(R, 'CONFIGURATION'));

base = LIN_MODEL;
d = load(fullfile(R, 'RESULTS', 'CONTROL', dfile)); f = fieldnames(d);
base.CONTROL = d.(f{1}).CONTROL;

cfgs.generation_loss = struct('breaker_mask', [0 0 0 1], 'breaker_time', 0.500, 'sim_duration', 3.5);
cfgs.voltage_sag     = struct('sag_depth', 0.20, 'sag_start_time', 0.500, 'sag_duration', 0.150, 'sim_duration', 3.5);
pert = {'generation_loss', 'voltage_sag'};

for scr = [1 1.5 2 3]
    for k = 1:2
        fn = fullfile(outDir, sprintf('%s_%s_SCR%.1f.mat', upper(design), pert{k}, scr));
        if exist(fn, 'file'), fprintf('  skip %s\n', fn); continue; end
        M = base;
        M.MODEL.GRID.PARAM.SCR_grid = scr;
        M.MODEL = update_grid_impedances(M.MODEL);
        t0 = tic; fprintf('\n--- %s  %s  SCR = %.1f ---\n', design, pert{k}, scr);
        M = LINEAR_ANALYSIS(M);
        cd(fullfile(R, 'BUS_DEFINITIONS'));
        BusDefinition(M.MODEL, 'MODEL_Bus'); BusDefinition(M.CONTROL, 'CONTROL_Bus');
        cd(fullfile(R, 'CONFIGURATION'));
        assignin('base', 'CONTROL_INI', M.CONTROL); assignin('base', 'MODEL_INI', M.MODEL);
        r = RUN_PERTURBATION_SIM(M, pert{k}, cfgs.(pert{k}));
        op = struct('SCR', scr, 'P', M.opSpecs.P_ref, 'Vp', M.opSpecs.Vp); %#ok<NASGU>
        fprintf('  success = %d, %.0f s\n', r.success, toc(t0));
        if r.success, save(fn, 'r', 'op', '-v7.3'); else, fprintf(2, '  FAIL: %s\n', r.error); end
    end
end
end
