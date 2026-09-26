function LIN_MODEL = b7_build_operating_point(repoRoot, ~, SCR, P, Vpcc)
%B7_BUILD_OPERATING_POINT Assemble and solve the pre-fault operating point.
%
% DESCRIPTION:
%   Builds the four-machine benchmark at one point of the campaign matrix of
%   Section 6.3 and solves its operating point, ready for a nonlinear run.
%
%   The assembly order follows CONFIG_POWER_SYSTEM.m, which is the driver the
%   rest of the paper uses:
%       CONFIG_MODEL -> CONFIG_CONTROL -> bus objects -> STATE_NAMES
%       -> CONTROL_DESIGN_FR -> bus objects -> LINEAR_ANALYSIS
%   It is reproduced here rather than invoked because CONFIG_POWER_SYSTEM is a
%   script that begins with CLEAR and is configured by editing constants at its
%   head. A campaign has to set the operating point per run, so it needs the
%   same sequence available as a function.
%
% WHAT IS IMPOSED AND WHAT IS SOLVED
%   The PCC is a PV bus: the dispatched power and the PCC voltage magnitude are
%   imposed, the Thevenin source is the slack at 1 pu, and the transmission
%   angle and the reactive power are solved. The reactive dispatch of the farm
%   is therefore a dependent variable of this specification, not a free
%   parameter, and the reactive setpoint of the VSM Q-loop is recovered from
%   the solved equilibrium rather than imposed on it.
%
% INPUTS:
%   repoRoot  - Repository root directory.
%   workModel - Full path to the armed working copy from b7_arm_mechanisms.
%   SCR       - Short-circuit ratio at the PCC.
%   P         - Active power dispatched per DFIG [pu].
%   Vpcc      - Pre-fault PCC voltage magnitude [pu]. The campaign uses 0.975,
%               the optimisation operating point, NOT the 1.0 pu of Sections
%               6.1 and 6.2. The pre-fault angles of Table 10 cannot be
%               reproduced without this.
%
% OUTPUT:
%   LIN_MODEL - Solved and linearised model, ready for RUN_PERTURBATION_SIM.
%
% SEE ALSO: b7_point, b7_arm_mechanisms, LINEAR_ANALYSIS, CONFIG_POWER_SYSTEM

narginchk(5, 5);

oldDir  = pwd;
restore = onCleanup(@() cd(oldDir));

addpath(fullfile(repoRoot, 'ANALYSIS'));
addpath(fullfile(repoRoot, 'SIMULATION'));
addpath(fullfile(repoRoot, 'CONFIGURATION'));

LIN_MODEL = struct();
LIN_MODEL.modelName = 'POWER_SYSTEM_FULL';

%% Model and control parameters
cd(fullfile(repoRoot, 'MODEL'));
LIN_MODEL = CONFIG_MODEL(LIN_MODEL);

cd(fullfile(repoRoot, 'CONTROL'));
LIN_MODEL = CONFIG_CONTROL(LIN_MODEL);

nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;

%% Operating-point specification
% Held constant across the campaign.
LIN_MODEL.opSpecs.f       = 1;
LIN_MODEL.opSpecs.Vgrid   = 1;                      % slack, behind Z_grid
LIN_MODEL.opSpecs.Qg_ref  = zeros(1, nDFIG);        % GSC reactive references
LIN_MODEL.opSpecs.pitch   = ones(1, nDFIG);
LIN_MODEL.opSpecs.Vdc_ref = ones(1, nDFIG);
LIN_MODEL.opSpecs.il1     = 0;
LIN_MODEL.opSpecs.il2     = 0;

% Set per run.
LIN_MODEL.opSpecs.Vp      = Vpcc;
LIN_MODEL.opSpecs.P_ref   = P * ones(1, nDFIG);
LIN_MODEL.opSpecs.Vs_ref  = Vpcc * ones(1, nDFIG);
LIN_MODEL.MODEL.GRID.PARAM.SCR_grid = SCR;
LIN_MODEL.MODEL = update_grid_impedances(LIN_MODEL.MODEL);

%% Bus objects, state names, control design
cd(fullfile(repoRoot, 'BUS_DEFINITIONS'));
BusDefinition(LIN_MODEL.MODEL,   'MODEL_Bus');
BusDefinition(LIN_MODEL.CONTROL, 'CONTROL_Bus');

cd(fullfile(repoRoot, 'CONFIGURATION'));
LIN_MODEL = STATE_NAMES(LIN_MODEL);

%% Controller
% A saved design is loaded rather than redesigned here. That is how every other
% comparison script in this repository obtains a controller, and it keeps the
% campaign on exactly the gains the paper reports instead of on a fresh design
% that might differ in the last digits.
%
% WHICH DESIGN SECTION 6.3 USED IS NOT STATED IN THE PAPER. Section 6.3 studies
% one design across grid strengths; it is not a baseline-versus-optimised
% comparison, and the text never names the controller. The default below is the
% GA-optimised design of Table 5, because the campaign exists to characterise
% the design the paper proposes. If the published Table 10 is not reproduced
% with it, run the campaign against LIN_MODEL_FRD_DESIGN.mat instead: the two
% possibilities are distinguishable by their numbers, and whichever reproduces
% Table 10 is the one that was used.
designFile = fullfile(repoRoot, 'RESULTS', 'CONTROL', 'LIN_MODEL_VI_OPT_BIOBJ.mat');
if exist(designFile, 'file') ~= 2
    error('b7_build_operating_point:noDesign', 'Design file not found: %s', designFile);
end
loaded  = load(designFile);
fn      = fieldnames(loaded);
DESIGN  = loaded.(fn{1});

LIN_MODEL.CONTROL = DESIGN.CONTROL;
if isfield(DESIGN, 'CONTROL_DESIGN')
    LIN_MODEL.CONTROL_DESIGN = DESIGN.CONTROL_DESIGN;
end
if isfield(DESIGN, 'controlDesignMethod')
    LIN_MODEL.controlDesignMethod = DESIGN.controlDesignMethod;
end
[~, dName] = fileparts(designFile);
fprintf('  Controller: %s\n', dName);

cd(fullfile(repoRoot, 'BUS_DEFINITIONS'));
BusDefinition(LIN_MODEL.MODEL,   'MODEL_Bus');
BusDefinition(LIN_MODEL.CONTROL, 'CONTROL_Bus');

%% The model
% repoRoot is the armed MIRROR, so SIMULINK/POWER_SYSTEM_FULL.slx under it is
% already the armed model. LINEAR_ANALYSIS changes into ../SIMULINK and opens
% it by name from there, which is exactly why the whole repository is mirrored
% rather than just the .slx: a detached copy would not be the file simulated.
LIN_MODEL.modelName = 'POWER_SYSTEM_FULL';

%% Solve and linearise
cd(fullfile(repoRoot, 'ANALYSIS'));
LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL);

%% Report, and refuse to continue on a point that did not converge
if isfield(LIN_MODEL, 'maxErrFsolve') && LIN_MODEL.maxErrFsolve > 1e-6
    error('b7_build_operating_point:noConvergence', ...
          ['The operating-point solve did not converge at SCR = %g, P = %g pu, ' ...
           'V_pcc = %g pu (residual %.3e). Section 2.2 records that two of the ' ...
           '225 envelope points do not converge; such a point must be reported ' ...
           'as inadmissible, not simulated.'], SCR, P, Vpcc, LIN_MODEL.maxErrFsolve);
end

fprintf('  Operating point solved: SCR = %g, P = %g pu, V_pcc = %g pu\n', SCR, P, Vpcc);
if isfield(LIN_MODEL, 'lineAngle')
    fprintf('    transmission angle   : %.3f deg\n', LIN_MODEL.lineAngle);
end
if isfield(LIN_MODEL, 'dfigPower')
    fprintf('    realised power/DFIG  : %.4f pu (nominal %.4f)\n', ...
            mean(LIN_MODEL.dfigPower), P);
end
if isfield(LIN_MODEL, 'maxErrFsolve')
    fprintf('    solve residual       : %.3e\n', LIN_MODEL.maxErrFsolve);
end
if isfield(LIN_MODEL, 'stability')
    fprintf('    small-signal stable  : %d\n', LIN_MODEL.stability);
end

end
