%% TABLE6_ENDPOINT_MARGINS  Table 6: realised loop margins at SCR = 1 and SCR = 3.
%
%   Run from the repository root or from ANALYSIS:
%       run ANALYSIS/TABLE6_ENDPOINT_MARGINS.m
%
%   For each design (baseline CFRD, LIN_MODEL_FRD_OPT; GA-optimised,
%   LIN_MODEL_VI_OPT_BIOBJ) and each grid-strength endpoint, the design is held
%   FIXED, the plant is re-linearised at the endpoint, and every loop's phase
%   margin and crossover are measured with LOOP_MARGINS. Only the SCR moves:
%   P = 0.8 pu and V_pcc = 0.975 pu stay at the optimisation point.
%
%   Each loop is measured with its own set-point weight forced to 1 (one
%   degree of freedom) and the plant re-linearised, one loop at a time. That is
%   the quantity the Table 6 caption describes. VSMQ has no weight to force.
%
%   The SCR = 1 GA column is compared against the published values as a
%   control; if it does not match, the SCR = 3 numbers are not comparable.
%
%   Output: RESULTS/CONTROL/TABLE6_ENDPOINT_MARGINS.txt and .mat
%   Runtime: a few minutes (28 linearisations).

W = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(W,'ANALYSIS'), fullfile(W,'CONTROL'), fullfile(W,'CONFIGURATION'), ...
        fullfile(W,'SIMULATION'), fullfile(W,'BUS_DEFINITIONS'), fullfile(W,'SIMULINK'));
modelName = 'POWER_SYSTEM_FULL';

names   = {'VSMP','VSMQ','RSCd','RSCq','VDC','GSCd','GSCq'};
designs = {'LIN_MODEL_FRD_OPT','LIN_MODEL_VI_OPT_BIOBJ'};
labels  = {'baseline','GA'};
SCRs    = [1.0 3.0];

% Published Table 6, GA column, derivation B, for the SCR = 1 control check.
PUB_GA_Fm = [83.52 107.68 55.69 65.22 57.24 60.14 58.61];
PUB_GA_wo = [5.845 2.016  1835  2304  180.8 2064.5 2358 ];

R = struct();

for di = 1:numel(designs)
  f = fullfile(W,'RESULTS','CONTROL',[designs{di} '.mat']);
  S = load(f); fn = fieldnames(S); M0raw = S.(fn{1});
  sd = M0raw.CONTROL_DESIGN.selectedDFIG;
  fprintf('\n############ %s  (%s), selectedDFIG=%d ############\n', ...
          designs{di}, labels{di}, sd);

  % Simulink preamble, identical to b10_chain_and_table6.m
  cd(fullfile(W,'BUS_DEFINITIONS'));
  BusDefinition(M0raw.CONTROL,'CONTROL_Bus'); BusDefinition(M0raw.MODEL,'MODEL_Bus');
  cd(fullfile(W,'SIMULINK'));
  open_system(modelName,'loadonly');
  mws = get_param(modelName,'modelworkspace'); evalin(mws,'clear');
  assignin(mws,'initialMemoryState',M0raw.initialMemoryState);
  assignin(mws,'MODEL_INI',M0raw.MODEL); assignin(mws,'CONTROL_INI',M0raw.CONTROL);
  set_param([modelName '/PERTURBATION & MONITORING'],'Commented','on');
  save_system(modelName,[],'OverwriteIfChangedOnDisk',true);
  assignin('base','CONTROL',M0raw.CONTROL); assignin('base','MODEL',M0raw.MODEL);
  cd(fullfile(W,'CONFIGURATION'));

  for si = 1:numel(SCRs)
    scr = SCRs(si);
    M0 = M0raw;

    % ---- move the grid-strength endpoint, and nothing else -----------------
    % Same substitution OPTIMIZER.m makes for its SCR = 3 robustness point.
    M0.MODEL.GRID.PARAM.SCR_grid = scr;
    Ub_r = M0.MODEL.BASE.Ub;  Sb_r = M0.MODEL.GRID.BASE.Sb;
    f0_r = M0.MODEL.BASE.f0;  XR_r = M0.MODEL.GRID.PARAM.XR_grid;
    M0.MODEL.GRID.PARAM.Lg_H   = Ub_r^2 / Sb_r / (2*pi*f0_r) / scr;
    M0.MODEL.GRID.PARAM.Rg_Ohm = M0.MODEL.GRID.PARAM.Lg_H * (2*pi*f0_r) / XR_r;
    M0.MODEL.GRID.PARAM.Lg_pu  = M0.MODEL.GRID.PARAM.Lg_H   / M0.MODEL.BASE.Lb;
    M0.MODEL.GRID.PARAM.Rg_pu  = M0.MODEL.GRID.PARAM.Rg_Ohm / M0.MODEL.BASE.Zb;

    M0 = LINEAR_ANALYSIS(M0, 0);
    fprintf('\n--- %s at SCR = %.1f : stability=%d maxErrFsolve=%.3e  Xg_pu=%.5f\n', ...
            labels{di}, scr, M0.stability, M0.maxErrFsolve, M0.MODEL.GRID.PARAM.Lg_pu);

    % ---- derivation B: each loop forced to 1-DOF in turn, re-linearised ----
    [Fm_A, wo_A] = LOOP_MARGINS(M0);
    Fm_B = nan(1,7); wo_B = nan(1,7);
    gate = {1,'VSMP','der2error'; 2,'',''; 3,'RSCd','b'; 4,'RSCq','b'; ...
            5,'VDC','b'; 6,'GSCd','b'; 7,'GSCq','b'};
    here = pwd;
    for k = 1:size(gate,1)
        if isempty(gate{k,2}), continue; end     % VSMQ has no 2-DOF weight
        M = M0; ctrl = gate{k,2}; fld = gate{k,3};
        M.CONTROL.(ctrl).PARAM.(fld)(sd) = 1;
        M = LINEARIZE(M, 0); cd(here);
        [Fk, wk] = LOOP_MARGINS(M, gate{k,1});
        Fm_B(gate{k,1}) = Fk(gate{k,1});  wo_B(gate{k,1}) = wk(gate{k,1});
    end
    Fm_B(2) = Fm_A(2); wo_B(2) = wo_A(2);        % VSMQ identical in both

    tag = sprintf('%s_SCR%d', labels{di}, round(scr*10));
    R.(tag) = struct('Fm',Fm_B,'wo',wo_B,'Fm_A',Fm_A,'wo_A',wo_A, ...
                     'stability',M0.stability,'scr',scr,'design',designs{di});

    fprintf('%-6s %12s %12s\n','loop','Fm_B (deg)','wo_B (rad/s)');
    for i = 1:7
        fprintf('%-6s %12.2f %12.4g\n', names{i}, Fm_B(i), wo_B(i));
    end
  end
end

% Leave the model as it was found.
set_param([modelName '/PERTURBATION & MONITORING'],'Commented','off');
save_system(modelName,[],'OverwriteIfChangedOnDisk',true);
cd(W);

%% ---- control: does SCR = 1 reproduce the published GA column? ------------
PUB_GA_Fm = [83.52 107.68 55.69 65.22 57.24 60.14 58.61];
d1 = abs(R.GA_SCR10.Fm - PUB_GA_Fm);
fprintf('\ncontrol: GA at SCR = 1 vs published, max |dFm| = %.4f deg\n', max(d1));
if max(d1) > 0.05
    fprintf(2,'*** SCR = 1 does not reproduce the published column.\n');
end

%% ---- the table ------------------------------------------------------------
out = fullfile(W,'RESULTS','CONTROL','TABLE6_ENDPOINT_MARGINS');
save([out '.mat'],'R','-v7');
fid = fopen([out '.txt'],'w');
for f = [1 fid]
    fprintf(f,'\nTable 6. Phase margin (deg), each loop 1-DOF; P = 0.8 pu, V_pcc = 0.975 pu.\n');
    fprintf(f,'%-6s %10s %10s %10s %10s\n','loop','base SCR1','base SCR3','GA SCR1','GA SCR3');
    for i = 1:7
        fprintf(f,'%-6s %10.2f %10.2f %10.2f %10.2f\n', names{i}, R.baseline_SCR10.Fm(i), ...
            R.baseline_SCR30.Fm(i), R.GA_SCR10.Fm(i), R.GA_SCR30.Fm(i));
    end
    fprintf(f,'control vs published GA SCR1: max |dFm| = %.4f deg\n', max(d1));
end
fclose(fid);
