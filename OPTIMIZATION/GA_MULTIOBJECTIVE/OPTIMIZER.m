function [LIN_MODEL, varargout] = OPTIMIZER(LIN_MODEL,optType,newPopulation,useParallel,runTime,maxNumGen,numWorkers,PopulationSize,fitnessMode,refinementConfig)
% OPTIMIZER - Multi-objective genetic algorithm for DFIG wind farm control optimization
%
% DESCRIPTION:
%   Optimizes control parameters for DFIG-based wind farm using NSGA-II genetic
%   algorithm. Supports 4 fitness modes: 'linear' (4 obj, gamultiobj),
%   'hybrid' (5 obj, gamultiobj), 'linear_itae' (mono-objective, ga),
%   and 'linear_itae_biobj' (2 obj: J1=regulation, J2=tracking, gamultiobj).
%
% FUNDAMENTAL OPTIMIZATION PRINCIPLE (linear_itae mode):
%   Minimize ITAE without degrading eigenvalue damping in any frequency band.
%
%   8-channel step transient ITAE (v9): combines disturbance rejection
%   and reference tracking to find the natural H compromise.
%
%   Perturbation channels (4): il_r→Δf, il_r→ΔV, il_i→Δf, il_i→ΔV
%   Reference channels (4):    P_ref→Δf, P_ref→ΔV, Q_ref→Δf, Q_ref→ΔV
%
%   y_error(t) = y_step(t) - dcgain(sys) for all 8 channels.
%   J = mean of 4 grouped normalized ITAEs (baseline=1.0).
%
%   Perturbation rejection favors H↑ (inertia absorbs disturbances).
%   Reference tracking favors H↓ (fast response to setpoint changes).
%   The 8-channel formulation balances both → no artificial H bound needed.
%
%   Previous formulations and why they failed:
%     - v6 impulse: ΔΩ ∝ 1/H → any integral metric favors H→∞
%     - v7 pulse(1s): T_pulse << τ_system → behaves like impulse → H→∞
%     - v8 step-dcgain (perturbation only): still favors H↑ (no tracking)
%
%   Active load current (il_r) replaces P_ref because disturbance rejection
%   (external perturbation) is the primary VSM requirement, not reference
%   tracking (internal). Both perturbations enter through the PCC capacitor
%   equation, rotated by exp(j·θ_v1) at the operating point angle.
%
%   VSMQ bandwidth lower bound = 0.5 rad/s to prevent extreme slowness.
%   Eigenvalue constraints ensure that ITAE improvement is achieved solely
%   through controller tuning, NOT by trading off modal damping.
%   This is enforced via 3-band per-baseline monitoring:
%
%     LF band  (|Im| ≤ 100 rad/s):  grid/slow modes      — baseline ζ ~0.029
%     MF band  (100 < |Im| ≤ 500):  VSMP modes (~ω₀)     — baseline ζ ~0.096
%     HF band  (500 < |Im| ≤ 3000): current loop modes    — baseline ζ ~0.47
%     Spurious (|Im| > 3000):        PCC parasitic caps    — excluded
%
%   Each band has its own baseline calibrated at the start of each phase.
%   Candidates that degrade ANY band below its baseline are rejected (100%
%   tolerance — no degradation permitted). This prevents hidden instabilities
%   such as current-loop pole migration toward the imaginary axis, which a
%   single global damping threshold would miss.
%
%   Real pole constraint: min|Re(z)| must match or exceed baseline, preventing
%   slow integrator modes from approaching the origin.
%
%   Multi-endpoint robustness: constraints are verified at 2 operating points
%   (SCR=1, SCR=3) to ensure robust performance across grid strengths.
%
% INPUTS:
%   LIN_MODEL        - Linearized model structure with current control design
%   optType          - Optimization type (1-5):
%                      1: P-axis frequency-response design specifications (PDS)
%                      2: Q-axis frequency-response design specifications (QDS)
%                      3: P-axis control parameters (b-coefficients) (PCP)
%                      4: Q-axis control parameters (b-coefficients) (QCP)
%                      5: Virtual impedance (Lv_pu; Rv_pu fixed at 0) (VI)
%   newPopulation    - Boolean: true=random population, false=seed with current design
%                      (optional, default: false)
%   useParallel      - Boolean: true=use parallel pool, false=sequential execution
%                      (optional, default: true)
%   runTime          - Maximum optimization time in hours (optional, default: 5)
%   maxNumGen        - Maximum number of generations (optional, default: 25)
%   numWorkers       - Number of parallel workers (optional, default: 4)
%                      Only used if useParallel=true
%   PopulationSize   - Number of individuals per generation (optional, default: 80)
%   fitnessMode      - Fitness evaluation mode (optional, default: 'linear'):
%                      'linear' : 4 objectives from linearized model (original)
%                      'hybrid' : 5 objectives (2 linear stability + 3 non-linear sim)
%
% OUTPUTS:
%   LIN_MODEL - Updated LIN_MODEL structure with optimized control parameters
%
% OPTIMIZATION OBJECTIVES:
%   LINEAR mode (4 objectives):
%   [1] -minDamping(2): Maximize minimum damping ratio (enhance stability)
%   [2] maxRealEig: Minimize maximum real eigenvalue (ensure stability)
%   [3] ROCOF/ROCOV: Minimize rate of change of frequency/voltage
%   [4] nadir: Minimize maximum deviation from final value
%
%   HYBRID mode (5 objectives):
%   [1] -minDamping(2): From eigenvalue analysis (linear)
%   [2] maxRealEig: From eigenvalue analysis (linear)
%   [3] IAE/ITAE: Configurable cost metric from non-linear perturbation sim
%       (costMetric_P='ITAE' for P-axis, costMetric_Q='IAE' for Q-axis)
%   [4] ROCOF/ROCOV: Rate of change from non-linear perturbation sim
%   [5] nadir: Deviation from nominal (|1-nadir|) from non-linear sim
%
% ALGORITHM CONFIGURATION:
%   - Population size: 80 individuals
%   - Parallel workers: configurable via numWorkers parameter
%   - Integer parameters with predefined bounds
%   - Pareto front visualization enabled
%
% NOTES:
%   - Requires parallel computing toolbox for useParallel=true
%   - Creates temporary Simulink models for parallel evaluation
%   - Results saved by calling script (CONFIG_POWER_SYSTEM.m)
%   - For optType 1-2: Design specs are optimized, control params fixed at b=1
%   - For optType 3-5: Control params optimized, design specs inherit from input
%
% SEE ALSO:
%   CONFIG_POWER_SYSTEM, CONTROL_DESIGN_FR, LINEAR_ANALYSIS
%
%--------------------------------------------------------------------------
if nargin==2
    newPopulation = false;
    useParallel = true;
    runTime = 5;
    maxNumGen = 25;
    numWorkers = 4;
    PopulationSize = 80;
elseif nargin==3
    useParallel = true;
    runTime = 5;
    maxNumGen = 25;
    numWorkers = 4;
    PopulationSize = 80;
elseif nargin==4
    runTime = 5;
    maxNumGen = 25;
    numWorkers = 4;
    PopulationSize = 80;
elseif nargin==5
    maxNumGen = 25;
    numWorkers = 4;
    PopulationSize = 80;
elseif nargin==6
    numWorkers = 4;
    PopulationSize = 80;
elseif nargin==7
    PopulationSize = 80;
elseif nargin==8
    fitnessMode = 'linear';
elseif nargin>10 || nargin<2
    disp('Wrong number of function parameters')
    return
else
end
% Default fitnessMode for nargin < 9 (param 9 not provided)
if nargin < 9 && ~exist('fitnessMode', 'var')
    fitnessMode = 'linear';
end
% Default refinementConfig for nargin < 10 (micro-refinement disabled by default)
if nargin < 10 || isempty(refinementConfig)
    refinementConfig = struct('enabled', false, 'factor', 0.10);
end
% Validate fitnessMode
if ~ismember(fitnessMode, {'linear', 'hybrid', 'linear_itae', 'linear_itae_biobj'})
    error('OPTIMIZER:invalidMode', 'fitnessMode must be ''linear'', ''hybrid'', ''linear_itae'', or ''linear_itae_biobj''');
end
% Ensure load_node exists in MODEL.LINE.PARAM (v5 field, may be missing in old .mat files)
if ~isfield(LIN_MODEL.MODEL.LINE.PARAM, 'load_node')
    LIN_MODEL.MODEL.LINE.PARAM.load_node = 2;  % v5 default: grid bus injection
    fprintf('  [OPTIMIZER] Injected load_node=2 into LIN_MODEL (missing from .mat)\n');
end
% For linear_itae/biobj mode, force load_node=1 (PCC injection) — v6 methodology
% Load current perturbations must enter at PCC for proper capacitor coupling
if (strcmp(fitnessMode, 'linear_itae') || strcmp(fitnessMode, 'linear_itae_biobj')) && LIN_MODEL.MODEL.LINE.PARAM.load_node ~= 1
    LIN_MODEL.MODEL.LINE.PARAM.load_node = 1;
    fprintf('  [OPTIMIZER] Forced load_node=1 for linear_itae mode (PCC injection)\n');
end
% Number of objectives:
%   4 = linear (damping, maxRealEig, ROCOX, nadir) — gamultiobj
%   5 = hybrid (same 2 linear + ITAE/IAE + ROCOF/ROCOV + nadir from NL sim) — gamultiobj
%   1 = linear_itae (J = mean of 4 normalized ITAEs, mono-objective) — ga
%   2 = linear_itae_biobj (J1=regulation, J2=tracking, Vdc constraint) — gamultiobj
if strcmp(fitnessMode, 'hybrid')
    nObj = 5;
elseif strcmp(fitnessMode, 'linear_itae')
    nObj = 1;
elseif strcmp(fitnessMode, 'linear_itae_biobj')
    nObj = 2;
else
    nObj = 4;
end
format compact
format short g

%--------------------------------------------------------------------------
%% CURRENT FREQUENCY-RESPONSE SPECIFICATIONS
%--------------------------------------------------------------------------
cd('../../BUS_DEFINITIONS')
BusDefinition(LIN_MODEL.CONTROL,'CONTROL_Bus')
BusDefinition(LIN_MODEL.MODEL,'MODEL_Bus')
cd('../SIMULINK');
model.name = LIN_MODEL.modelName;
open_system(model.name,'loadonly')
model.workspace = get_param(model.name,'modelworkspace');
evalin(model.workspace,'clear')
assignin(model.workspace,'initialMemoryState',LIN_MODEL.initialMemoryState);
assignin(model.workspace,'MODEL_INI',LIN_MODEL.MODEL);
assignin(model.workspace,'CONTROL_INI',LIN_MODEL.CONTROL);
set_param([model.name '/PERTURBATION & MONITORING'],'Commented','on');
save_system(model.name,[],'OverwriteIfChangedOnDisk',true)
close_system(model.name)
cd('../OPTIMIZATION/GA_MULTIOBJECTIVE')
% fsolve options
opt_fsolve = optimoptions('fsolve');
opt_fsolve.MaxIterations = 5000;
opt_fsolve.Display = 'off';
% Selected DFIG
selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
% State-space model
ssModel = LIN_MODEL.ssModel;
% State space matrices
matA = ssModel.a;
matB = ssModel.b;
matC = ssModel.c;
matD = ssModel.d;
% Extract design specifications from CONTROL_DESIGN structure
% Use saved specs instead of recalculating from linearized model
% This ensures optimization starts from actual designed values
nCONTROL = 7;
Fm = NaN(1,nCONTROL); wo = NaN(1,nCONTROL);

if isfield(LIN_MODEL, 'CONTROL_DESIGN') && isfield(LIN_MODEL.CONTROL_DESIGN, 'VSMP')
    % Extract specs from CONTROL_DESIGN (preferred method)
    CD = LIN_MODEL.CONTROL_DESIGN;
    Fm(1) = CD.VSMP.frdSpecs.Fm;
    wo(1) = CD.VSMP.frdSpecs.wo;
    wo(2) = CD.VSMQ.frdSpecs.wo;
    Fm(3:4) = CD.RSC.frdSpecs.Fm;
    wo(3:4) = CD.RSC.frdSpecs.wo;
    Fm(5) = CD.VDC.frdSpecs.Fm;
    wo(5) = CD.VDC.frdSpecs.wo;
    Fm(6:7) = CD.GSC.frdSpecs.Fm;
    wo(6:7) = CD.GSC.frdSpecs.wo;
else
    % Fallback: Calculate from linearized model (legacy behavior)
    % This is only used if CONTROL_DESIGN structure is not available
    wo_ini = [10 2.5 350 350 100 500 500];
    nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
    for nn = 1:nCONTROL
        indT = nCONTROL*(selectedDFIG-1)+nn;
        indS = nCONTROL*nDFIG + nCONTROL*(selectedDFIG-1)+nn;
        Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
        Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));
        Gss = -Tss/Sss;
        wo(nn) = fsolve(@(w) abs(freqresp(Gss,w))-1,wo_ini(nn),opt_fsolve);
        Fm(nn) = 180 + 180/pi*angle(freqresp(Gss,wo(nn)));
    end
end

% 1. VSMP | 2. VSMQ | 3. RSCd | 4. RSCq | 5. VDC | 6. GSCd | 7. GSCq
% Scale vector
specsValue = [Fm(1) wo(1) wo(2) Fm(3) wo(3) Fm(4) wo(4) Fm(5) wo(5) Fm(6) wo(6) Fm(7) wo(7)];
specsScale  = [10 10 100 10 1 10 1 10 1 10 1 10 1];
specsParam  = round(specsValue.*specsScale);
% No clamping — bounds are enforced by lb/ub in GA, not here

%--------------------------------------------------------------------------
%% DESIGN SPECIFICATIONS - ACTIVE POWER CONTROLLERS
%--------------------------------------------------------------------------
% 1. VSMP Fm (deg)
% 2. VSMP wo (rad/s)
% 3. RSCq Fm (deg)
% 4. RSCq wo (rad/s)
% 5. VDC Fm  (deg)
% 6. VDC wo  (rad/s)
% 7. GSCq Fm (deg)
% 8. GSCq wo (rad/s)
% NOTE: Phase margin bounds set to 500-900 (50-90°) for all Fm parameters
%       Parameters 1,3,5,7 are phase margins (Fm) in 0.1° → valid range 500-900 (50-90°)
%       Parameters 2,4,6,8 are crossover freqs (wo) → extended upper bound to 1000 rad/s
lbDS_P = [500    50  500 500 500  50  500 500]; % Lower bound (Fm: 500 = 50°, wo: 500 for RSCq/GSCq)
ubDS_P = [900   250  900 2500 900 300  900 2500]; % Upper bound (Fm: 900 = 90°, wo: 2500 for RSCq/GSCq)
scDS_P = 1./specsScale([1 2 6 7 8 9 12 13]); % Scale
% Rated parameters
rpDS_P = specsParam([1 2 6 7 8 9 12 13]);

%--------------------------------------------------------------------------
%% DESIGN SPECIFICATIONS - REACTIVE POWER CONTROLLERS
%--------------------------------------------------------------------------
% 1. VSMQ wo (rad/s)
% 2. RSCd Fm (deg) - Phase margin bounds: 500-900 (50-90°)
% 3. RSCd wo -- 577.54 rad/s = 91.918 Hz
% 4. GSCd Fm (deg) - Phase margin bounds: 500-900 (50-90°)
% 5. GSCd wo -- 3969.2rad/s = 631.69 Hz
lbDS_Q = [  50  500 500 500 500]; % Lower bound (VSMQ_wo: 50=0.5 rad/s, Fm: 500=50°, wo: 500 for RSCd/GSCd)
ubDS_Q = [ 200  900 2500 900 2500]; % Upper bound (VSMQ_wo: 200=2.0 rad/s, Fm: 900=90°, wo: 2500 for RSCd/GSCd)
scDS_Q = 1./specsScale([3 4 5 10 11]); % Scale
% Rated parameters
rpDS_Q = specsParam([3 4 5 10 11]);

%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - ACTIVE POWER
%--------------------------------------------------------------------------
% 1. der3err  - VSMP / 0. Output / 1. Error
% 2. b_irq    - RSCq
% 3. b_vdc    - VDC
% 4. b_igq    - GSCq
lbCP_P = [0   50   50   50]; % Lower bound
ubCP_P = [1  150  150  150]; % Upper bound
scCP_P = [1 0.01 0.01 0.01]; % Scale
% Rated parameters
der2error = LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG);
b_irq = LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG);
b_vdc = LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG);
b_igq = LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG);
rpCP_P = round([der2error b_irq b_vdc b_igq]./scCP_P);

%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - REACTIVE POWER
%--------------------------------------------------------------------------
% 1. b_ird    - RSCd
% 2. b_igd    - GSCd
lbCP_Q = [  50   50]; % Lower bound
ubCP_Q = [ 150  150]; % Upper bound
scCP_Q = [0.01 0.01]; % Scale
% Rated parameters
b_ird = LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG);
b_igd = LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG);
rpCP_Q = round([b_ird b_igd]./scCP_Q);

%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - VIRTUAL IMPEDANCE
%--------------------------------------------------------------------------
% 1, Lv    - Virtual reactance
% 2. Rv    - Virtual resistance: FIXED AT 0, not a design variable. The model
%            does not read it (see ANALYSIS/RV_CONNECTIVITY_TEST.m); the slot
%            is kept only so the 21-slot parameter layout stays unchanged.
lbVI = [    0      0]; % Lower bound
ubVI = [  150      0]; % Upper bound (Rv pinned to 0)
scVI = [0.001 0.0001]; % Scale
% Rated parameters
Lv = LIN_MODEL.CONTROL.VIMP.PARAM.Lv_pu(selectedDFIG);
Rv = LIN_MODEL.CONTROL.VIMP.PARAM.Rv_pu(selectedDFIG);
rpVI = round([Lv Rv]./scVI);
 
%--------------------------------------------------------------------------
%% OPTIMIZER CONFIGURATION
%--------------------------------------------------------------------------
% Check control parameters for PDS/QDS optimization
% Only enforce b=1 requirement when starting from scratch (newPopulation=true)
% Allow re-optimization from any control design when newPopulation=false
if optType<3 && newPopulation && any([rpCP_P rpCP_Q].*[scCP_P scCP_Q]~=1)
    disp('All the control parameters should be equal to 1')
    disp('For PDS/QDS optimization with newPopulation=true, start from baseline control')
    disp('Alternatively, use newPopulation=false to re-optimize from current design')
    return
end

% When re-optimizing (newPopulation=false), use frdMargins instead of frdSpecs
% This ensures Individual 1 maintains the actual performance of VI_OPT
fprintf('\n===== DEBUG SPEC EXTRACTION =====\n');
fprintf('newPopulation = %d, optType = %d\n', newPopulation, optType);
fprintf('Condition (~newPopulation && optType == 1): %d\n', ~newPopulation && optType == 1);

if ~newPopulation && optType == 1  % FIX: Only for PDS re-optimization/refinement, NOT sequential QDS
    fprintf('\n>>> ENTERING frdMargins extraction block <<<\n');

    % Extract ACTUAL margins (not design specs) for re-optimization
    Fm_margins = NaN(1,nCONTROL); wo_margins = NaN(1,nCONTROL);
    Fm_margins(1) = LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.Fm;
    wo_margins(1) = LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.wo;
    wo_margins(2) = LIN_MODEL.CONTROL_DESIGN.VSMQ.frdMargins.wo;
    Fm_margins(3:4) = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm;
    wo_margins(3:4) = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.wo;
    Fm_margins(5) = LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.Fm;
    wo_margins(5) = LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.wo;
    Fm_margins(6:7) = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm;
    wo_margins(6:7) = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.wo;

    fprintf('Extracted frdMargins:\n');
    fprintf('  VSMP: Fm=%.1f°, wo=%.2f rad/s\n', Fm_margins(1), wo_margins(1));
    fprintf('  RSCq: Fm=%.1f°, wo=%.1f rad/s\n', Fm_margins(4), wo_margins(4));
    fprintf('  VDC:  Fm=%.1f°, wo=%.1f rad/s\n', Fm_margins(5), wo_margins(5));
    fprintf('  GSCq: Fm=%.1f°, wo=%.1f rad/s\n', Fm_margins(7), wo_margins(7));

    % Recalculate rpDS_P and rpDS_Q with margins
    specsValue_margins = [Fm_margins(1) wo_margins(1) wo_margins(2) Fm_margins(3) wo_margins(3) ...
                          Fm_margins(4) wo_margins(4) Fm_margins(5) wo_margins(5) ...
                          Fm_margins(6) wo_margins(6) Fm_margins(7) wo_margins(7)];
    specsParam_margins = round(specsValue_margins.*specsScale);
    % No clamping — bounds are enforced by lb/ub in GA, not here

    fprintf('specsValue_margins (all 13 values):\n');
    fprintf('  [%.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f]\n', specsValue_margins);
    fprintf('specsParam_margins (all 13 values):\n');
    fprintf('  [%d %d %d %d %d %d %d %d %d %d %d %d %d]\n', specsParam_margins);
    fprintf('Extracting rpDS_P from indices [1 2 6 7 8 9 12 13]:\n');
    fprintf('Original rpDS_P (before): [%d %d %d %d %d %d %d %d]\n', rpDS_P);
    rpDS_P = specsParam_margins([1 2 6 7 8 9 12 13]);
    rpDS_Q = specsParam_margins([3 4 5 10 11]);
    fprintf('Updated rpDS_P (after):   [%d %d %d %d %d %d %d %d]\n', rpDS_P);
    fprintf('  Meaning: [VSMP_Fm VSMP_wo RSCq_Fm RSCq_wo VDC_Fm VDC_wo GSCq_Fm GSCq_wo]\n');
else
    fprintf('>>> NOT entering frdMargins extraction (using frdSpecs) <<<\n');
end

fprintf('Final rpDS_P used: [%d %d %d %d %d %d %d %d]\n', rpDS_P);
fprintf('=================================\n\n');

% PopulationSize now comes from function parameter (configured in CONFIG_POWER_SYSTEM.m)
% Optimizer scale and parameter vectors
scale = [scDS_P scDS_Q scCP_P scCP_Q scVI];
param = [rpDS_P rpDS_Q rpCP_P rpCP_Q rpVI];

% Lower and upper bounds
switch(optType)
    case 1 % Design specs P
        lb    = [lbDS_P rpDS_Q rpCP_P rpCP_Q rpVI];
        ub    = [ubDS_P rpDS_Q rpCP_P rpCP_Q rpVI];
    case 2 % Design Specs Q
        lb    = [rpDS_P lbDS_Q rpCP_P rpCP_Q rpVI];
        ub    = [rpDS_P ubDS_Q rpCP_P rpCP_Q rpVI];
    case 3 % Control parameters P
        lb    = [rpDS_P rpDS_Q lbCP_P rpCP_Q rpVI];
        ub    = [rpDS_P rpDS_Q ubCP_P rpCP_Q rpVI];
    case 4 % Control parameters Q
        lb    = [rpDS_P rpDS_Q rpCP_P lbCP_Q rpVI];
        ub    = [rpDS_P rpDS_Q rpCP_P ubCP_Q rpVI];
    case 5 % Vitual impedance
        lb    = [rpDS_P rpDS_Q rpCP_P rpCP_Q lbVI];
        ub    = [rpDS_P rpDS_Q rpCP_P rpCP_Q ubVI];
    otherwise
end

% MICRO-REFINEMENT MODE: tighten bounds to ±factor of current design
% Used for final pass after full 5-phase optimization to fine-tune solution
if refinementConfig.enabled
    rf = refinementConfig.factor;
    switch optType
        case 1, refine_indices = 1:8;
        case 2, refine_indices = 9:13;
        case 3, refine_indices = 14:17;
        case 4, refine_indices = 18:19;
        case 5, refine_indices = 20:21;
        otherwise, refine_indices = [];
    end
    fprintf('\n--- REFINEMENT MODE: tightening bounds to ±%.0f%% of current design ---\n', rf*100);
    for idx = refine_indices
        center = param(idx);
        tight_lb = max(lb(idx), floor(center * (1 - rf)));
        tight_ub = min(ub(idx), ceil(center * (1 + rf)));
        if tight_ub <= tight_lb
            tight_ub = tight_lb + 1;  % guarantee lb < ub
        end
        lb(idx) = tight_lb;
        ub(idx) = tight_ub;
    end
end

% When re-optimizing (newPopulation=false), ensure bounds include current param values
% This is critical for Individual 1 to maintain frdMargins from VI_OPT
if ~newPopulation
    % Identify which parameters are being optimized
    switch optType
        case 1, optimize_indices = 1:8;   % PDS
        case 2, optimize_indices = 9:13;  % QDS
        case 3, optimize_indices = 14:17; % PCP
        case 4, optimize_indices = 18:19; % QCP
        case 5, optimize_indices = 20:21; % VI
    end

    % Expand bounds to include current param values (with 10% margin for exploration)
    for idx = optimize_indices
        if param(idx) < lb(idx)
            old_lb = lb(idx);
            lb(idx) = floor(param(idx) * 0.9);  % 10% below current value
            fprintf('Expanded lower bound for param %d: %d -> %d (current=%d)\n', idx, old_lb, lb(idx), param(idx));
        end
        if param(idx) > ub(idx)
            old_ub = ub(idx);
            ub(idx) = ceil(param(idx) * 1.1);   % 10% above current value
            fprintf('Expanded upper bound for param %d: %d -> %d (current=%d)\n', idx, old_ub, ub(idx), param(idx));
        end
    end
end
% Number of parameters to be optimized
numParam = length(param);
% All the parameters are defined as integer
intcon = 1:numParam;
% Seed for reproducibility
rng default % 
% Equalities and inequalities
% Aineq*x <= bineq
%   Aeq*x  = beq
Aineq = [];
bineq = [];
Aeq = [];
beq = [];

%--------------------------------------------------------------------------
%% INITIAL POPULATION FOR GAM
%--------------------------------------------------------------------------
% Find Pareto front of multiple fitness functions using genetic algorithm
% NOTE: Initial population generation simplified - inheritance is now handled
%       by CONFIG_POWER_SYSTEM.m through LIN_MODEL structure passed to OPTIMIZER
%       The LIN_MODEL already contains the appropriate starting control design
cd ../../OPTIMIZATION/GA_MULTIOBJECTIVE

if newPopulation
    % Generate completely random initial population
    InitialPopulationMatrix = NaN(PopulationSize,numParam);
    InitialPopulationMatrix(1,:) = param;
    for nn = 1:numParam
        InitialPopulationMatrix(2:end,nn) = lb(nn) + rand(PopulationSize-1,1)*(ub(nn)-lb(nn));
        if any((nn-intcon)==0)
            InitialPopulationMatrix(2:end,nn) = round(InitialPopulationMatrix(2:end,nn));
        end
    end
else
    % Use current design as first individual, randomize rest
    % The current LIN_MODEL already contains the correct starting point
    % (either from FRD_OPT or from previous optimization step)
    InitialPopulationMatrix = NaN(PopulationSize,numParam);

    % Initialize ALL individuals with current design parameters
    for nn = 1:PopulationSize
        InitialPopulationMatrix(nn,:) = param;
    end

    % Note: When newPopulation=false and optType=1 or 2, the param vector already
    % contains frdMargins (extracted in lines 251-274), so Individual 1 will
    % automatically use the actual margins as specs. No additional extraction needed here.

    % Determine which parameters to randomize based on optimization type
    % This allows the population to explore around the current design
    switch optType
        case 1 % Design specs P (optimize parameters 1-8)
            randomize_params = 1:8;
        case 2 % Design specs Q (optimize parameters 9-13)
            randomize_params = 9:13;
        case 3 % Control param P (optimize parameters 14-17)
            randomize_params = 14:17;
        case 4 % Control param Q (optimize parameters 18-19)
            randomize_params = 18:19;
        case 5 % Virtual impedance (parameter 20, L_v; slot 21, R_v, has lb = ub = 0)
            randomize_params = 20:21;
        otherwise
            randomize_params = [];
    end

    % Randomize ONLY the parameters being optimized (individuals 2 to end)
    % Individual 1 keeps the exact current design for reference
    for nn = randomize_params
        InitialPopulationMatrix(2:end,nn) = lb(nn) + rand(PopulationSize-1,1)*(ub(nn)-lb(nn));
        if any((nn-intcon)==0)
            InitialPopulationMatrix(2:end,nn) = round(InitialPopulationMatrix(2:end,nn));
        end
    end
end

%--------------------------------------------------------------------------
%% PARPOOL CONFIGURATION
%--------------------------------------------------------------------------
if useParallel
    % Ensure that no parallel pool is running
    delete(gcp('nocreate'))
    % Open a pool of a specific size with extended idle timeout
    % (default 30 min too short for dual-perturbation ITAE setup phase)
    pool = parpool(numWorkers);
    pool.IdleTimeout = 360;  % 6 hours — covers full optimization run
    fprintf('Parallel pool created with %d workers\n', numWorkers);
    % Get the current parallel pool
    % poolObj = gcp;
    % ProcessPool properties: 
    %         Connected: true
    %        NumWorkers: 4
    %              Busy: false
    %           Cluster: Processes (Local Cluster)
    %     AttachedFiles: {}
    % AutoAddClientPath: true
    %         FileStore: [1x1 parallel.FileStore]
    %        ValueStore: [1x1 parallel.ValueStore]
    %       IdleTimeout: 30 minutes (30 minutes remaining)
    %       SpmdEnabled: true     
    % addAttachedFiles(poolObj,["../../SIMULINK" ...
    %                           "../../CONFIGURATION/LINEAR_ANALYSIS.m" ...
    %                           "../../CONTROL/CONTROL_DESIGN_FR.m" ...
    %                           "../../BUS_DEFINITIONS/BusDefinition.m"]);
    cd('../../SIMULINK');
    for nn = 1:numWorkers
        model.name = LIN_MODEL.modelName;
        open_system(model.name,'loadonly')
        save_system(model.name,[model.name '_' num2str(nn)]);
        close_system([model.name '_' num2str(nn)])
    end
    close_system(model.name)
    cd('../OPTIMIZATION/GA_MULTIOBJECTIVE');
end

%--------------------------------------------------------------------------
%% ENSURE SIMULATION PATH (for hybrid fitness mode)
%--------------------------------------------------------------------------
simPath = fullfile(pwd, '../../SIMULATION');
if exist(simPath, 'dir')
    addpath(simPath);
end

%--------------------------------------------------------------------------
%% ALGORITHM PARAMETERS & CALL TO GAM FUNCTION
%--------------------------------------------------------------------------
%==========================================================================
% PERMANENT MONITORING SYSTEM - DO NOT REMOVE
%==========================================================================
% This section implements the permanent progress tracking system that shows
% real-time optimization progress during GA execution.
%
% Purpose: Display "VI | Gen X/Y | Ind Z/PopSize | WN | S=1 | fval=[...]"
%
% Components:
%   1. progressFile: Shared state managed by gaOutputFcn_local (OutputFcn)
%   2. gaOutputFcn_local: Updates generation counter (MATLAB-guaranteed execution)
%   3. fitnessFcn: Reads progress and displays individual evaluation results
%
% NOTE: This is PERMANENT monitoring for user visibility, NOT debug code.
%       If removing debug monitoring, preserve this section entirely.
%==========================================================================

% Create progress tracking file (managed by OutputFcn, read by fitnessFcn)
progressFile = fullfile(pwd, '.ga_progress.mat');
if exist(progressFile, 'file'), delete(progressFile); end
currentGen = 1;  % Start at generation 1 (updated by OutputFcn)
totalIndEvaluated = 0;  % Total individuals evaluated so far
save(progressFile, 'currentGen', 'totalIndEvaluated');

% Create detailed generation log file for post-hoc analysis
% Log file: TEMP/LOG_GA_{optLabel}_{fitnessMode}_{timestamp}.txt
optLabels = {'PDS','QDS','PCP','QCP','VI'};
gaLogDir = fullfile(pwd, '../../TEMP');
if ~exist(gaLogDir, 'dir'), mkdir(gaLogDir); end
gaLogFile = fullfile(gaLogDir, sprintf('LOG_GA_%s_%s_%s.txt', ...
    optLabels{optType}, fitnessMode, datestr(now, 'yyyymmdd_HHMMSS')));
gaLogFid = fopen(gaLogFile, 'w');
fprintf(gaLogFid, '=== GA OPTIMIZATION LOG ===\n');
fprintf(gaLogFid, 'Phase: %s | Mode: %s | Pop: %d | MaxGen: %d | MaxTime: %.1fh | Workers: %d\n', ...
    optLabels{optType}, fitnessMode, PopulationSize, maxNumGen, runTime, numWorkers);
fprintf(gaLogFid, 'Start: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
try
    fprintf(gaLogFid, 'load_node: %d\n', LIN_MODEL.MODEL.LINE.PARAM.load_node);
catch
    fprintf(gaLogFid, 'load_node: 2 (from CONFIG_MODEL, not in LIN_MODEL)\n');
end
fprintf(gaLogFid, '=========================================================================\n');
if strcmp(fitnessMode, 'linear_itae')
    fprintf(gaLogFid, '%-6s | %-18s | %-18s | %-18s | %-10s | %s\n', ...
        'Gen', 'J_min', 'J_mean', 'J_best', 'Valid/Pop', 'Elapsed');
elseif strcmp(fitnessMode, 'linear_itae_biobj')
    fprintf(gaLogFid, '%-6s | %-14s | %-14s | %-14s | %-14s | %-8s | %-8s | %-8s | %s\n', ...
        'Gen', 'J1_reg_min', 'J1_reg_mean', 'J2_trk_min', 'J2_trk_mean', ...
        'Pareto', 'Valid', 'PopSize', 'Elapsed');
else
    fprintf(gaLogFid, '%-6s | %-12s | %-12s | %-12s | %-12s | %-12s | %-12s | %-8s | %-8s | %s\n', ...
        'Gen', 'Obj1_min', 'Obj1_mean', 'Obj2_min', 'Obj2_mean', 'Spread', 'AvgDist', ...
        'Pareto', 'PopSize', 'Elapsed');
end
fprintf(gaLogFid, '=========================================================================\n');
fclose(gaLogFid);
fprintf('GA log file: %s\n', gaLogFile);
gaStartTic = tic;

if strcmp(fitnessMode, 'linear_itae')
    % Mono-objective ga() for linear_itae mode
    options = optimoptions('ga',...
        'PlotFcn',{'gaplotbestf','gaplotbestindiv'},...
        'PopulationSize',PopulationSize,...
        'Display','iter',...
        'MaxGenerations',maxNumGen,...
        'InitialPopulationMatrix',InitialPopulationMatrix,...
        'MaxTime',3600*runTime,...
        'UseParallel',useParallel,...
        'UseVectorized',false,...
        'EliteCount', max(1, round(0.05*PopulationSize)),... % 5% elite preservation
        'OutputFcn',@(options,state,flag) gaOutputFcn_local(options,state,flag,progressFile,gaLogFile,gaStartTic,fitnessMode));
elseif strcmp(fitnessMode, 'linear_itae_biobj')
    % Bi-objective gamultiobj() for linear_itae_biobj mode (J1=regulation, J2=tracking)
    options = optimoptions('gamultiobj',...
        'PlotFcn',{'gaplotpareto','gaplotparetodistance','gaplotrankhist','gaplotspread'},...
        'PopulationSize',PopulationSize,...
        'Display','iter',...
        'MaxGenerations',maxNumGen,...
        'InitialPopulationMatrix',InitialPopulationMatrix,...
        'MaxTime',3600*runTime,...
        'UseParallel',useParallel,...
        'UseVectorized',false,...
        'ParetoFraction', 0.35,...
        'OutputFcn',@(options,state,flag) gaOutputFcn_local(options,state,flag,progressFile,gaLogFile,gaStartTic,fitnessMode));
else
    % Multi-objective gamultiobj() for linear and hybrid modes
    options = optimoptions('gamultiobj','PlotFcn',{'gaplotpareto',...
        'gaplotparetodistance','gaplotrankhist','gaplotspread'},...
        'PopulationSize',PopulationSize,...
        'Display','iter',...
        'MaxGenerations',maxNumGen,...
        'InitialPopulationMatrix',InitialPopulationMatrix,...
        'MaxTime',3600*runTime,...
        'UseParallel',useParallel,...
        'UseVectorized',false,...
        'OutputFcn',@(options,state,flag) gaOutputFcn_local(options,state,flag,progressFile,gaLogFile,gaStartTic,fitnessMode));
end
%    Default properties:
%         ConstraintTolerance: 0.001
%                 CreationFcn: []
%                CrossoverFcn: []
%           CrossoverFraction: 0.8
%                     Display: 'final'
%          DistanceMeasureFcn: {@distancecrowding  'phenotype'}
%           FunctionTolerance: 0.0001
%                   HybridFcn: []
%     InitialPopulationMatrix: []
%      InitialPopulationRange: [2×1 double]
%         InitialScoresMatrix: []
%              MaxGenerations: '200*numberOfVariables'
%         MaxStallGenerations: 100
%                     MaxTime: Inf
%                 MutationFcn: []
%                   OutputFcn: []
%              ParetoFraction: 0.35
%                     PlotFcn: []
%              PopulationSize: '50 when numberOfVariables <= 5, else 200'
%              PopulationType: 'doubleVector'
%                SelectionFcn: {@selectiontournament  [2]}
%                 UseParallel: 0
%               UseVectorized: 0
% Create metadata structure to pass to workers
gaMetadata.optType = optType;  % Optimization type (1=PDS, 2=QDS, 3=PCP, 4=QCP, 5=VI)
gaMetadata.PopulationSize = PopulationSize;  % Population size for counter management
gaMetadata.maxNumGen = maxNumGen;  % Maximum generations for display
gaMetadata.progressFile = progressFile;  % Progress file managed by OutputFcn
gaMetadata.numWorkers = numWorkers;  % Number of parallel workers
gaMetadata.fitnessMode = fitnessMode;  % 'linear' or 'hybrid'
gaMetadata.nObj = nObj;  % Number of objectives (4 linear, 5 hybrid, 1 linear_itae)

% ================================================================
% EIGENVALUE ROBUSTNESS CONFIG — shared by 'hybrid' and 'linear_itae'
% ================================================================
if strcmp(fitnessMode, 'hybrid') || strcmp(fitnessMode, 'linear_itae') || strcmp(fitnessMode, 'linear_itae_biobj')
    % Eigenvalue constraints (reject poorly-damped or slow-mode designs)
    eigenConfig = struct();
    eigenConfig.min_real_pole_mag    = 0.02;
    eigenConfig.min_damping          = 0.02;
    eigenConfig.spurious_freq_thresh = 3000;
    eigenConfig.mf_freq_thresh      = 100;    % LF ≤ 100 rad/s (grid/slow)
    eigenConfig.hf_freq_thresh      = 500;    % MF = (100, 500] rad/s (VSMP ~314), HF = (500, 3000] (current loops ~1400)
    eigenConfig.enabled              = true;
    gaMetadata.eigenConfig = eigenConfig;

    % Perturbation response constraints — nadir/ROCOF/ROCOV
    % Programmed but DISABLED for this optimization (activation: set .enabled = true)
    pertConstraints = struct();
    pertConstraints.max_ROCOF   = 1.0;
    pertConstraints.max_ROCOV   = 1.0;
    pertConstraints.min_nadir_f = 0.95;
    pertConstraints.min_nadir_V = 0.70;
    pertConstraints.enabled     = false;   % <-- disabled: use eigenvalue constraints only
    gaMetadata.pertConstraints = pertConstraints;

    % Multi-endpoint eigenvalue robustness (2 operating points)
    % SCR=1 (weak grid), SCR=3 (strong grid)
    % Threshold = max(baseline_at_OP, generic) — candidate CANNOT degrade baseline
    robustnessOPs = struct();
    robustnessOPs(1).SCR_grid = LIN_MODEL.MODEL.GRID.PARAM.SCR_grid;  % OP1: weak (opt OP)
    robustnessOPs(1).skip = false;
    robustnessOPs(2).SCR_grid = 3.0;   % OP2: strong grid extreme
    robustnessOPs(2).skip = false;

    % Calibrate baseline eigenvalue thresholds at each OP
    fprintf('\n--- Baseline Eigenvalue Calibration (2-OP Robustness: SCR=1/3) ---\n');
    [calOptimDir, ~, ~] = fileparts(mfilename('fullpath'));
    calStartDir = pwd;
    for k = 1:length(robustnessOPs)
        SCR_k = robustnessOPs(k).SCR_grid;
        if abs(SCR_k - LIN_MODEL.MODEL.GRID.PARAM.SCR_grid) < 1e-6
            z_cal = LIN_MODEL.eigenvalues;
        else
            LIN_CAL = LIN_MODEL;
            LIN_CAL.MODEL.GRID.PARAM.SCR_grid = SCR_k;
            Ub_cal  = LIN_CAL.MODEL.BASE.Ub;
            Sb_cal  = LIN_CAL.MODEL.GRID.BASE.Sb;
            f0_cal  = LIN_CAL.MODEL.BASE.f0;
            XR_cal  = LIN_CAL.MODEL.GRID.PARAM.XR_grid;
            LIN_CAL.MODEL.GRID.PARAM.Lg_H    = Ub_cal^2 / Sb_cal / (2*pi*f0_cal) / SCR_k;
            LIN_CAL.MODEL.GRID.PARAM.Rg_Ohm  = LIN_CAL.MODEL.GRID.PARAM.Lg_H * (2*pi*f0_cal) / XR_cal;
            LIN_CAL.MODEL.GRID.PARAM.Lg_pu   = LIN_CAL.MODEL.GRID.PARAM.Lg_H / LIN_CAL.MODEL.BASE.Lb;
            LIN_CAL.MODEL.GRID.PARAM.Rg_pu   = LIN_CAL.MODEL.GRID.PARAM.Rg_Ohm / LIN_CAL.MODEL.BASE.Zb;
            cd(fullfile(calOptimDir, '../../CONFIGURATION'));
            LIN_CAL = LINEAR_ANALYSIS(LIN_CAL, 0);
            if LIN_CAL.stability == 0
                fprintf('  WARNING: Baseline UNSTABLE at SCR=%.1f — skipping this OP\n', SCR_k);
                robustnessOPs(k).baseline_min_real_pole_mag = 0;
                robustnessOPs(k).baseline_min_damping_lf = 0;
                robustnessOPs(k).baseline_min_damping_mf = 0;
                robustnessOPs(k).baseline_min_damping_hf = 0;
                robustnessOPs(k).skip = true;
                continue;
            end
            z_cal = LIN_CAL.eigenvalues;
        end
        [~, Damping_cal] = damp(z_cal);
        is_real_cal = abs(Damping_cal) == 1;
        real_poles_cal = z_cal(is_real_cal);
        if ~isempty(real_poles_cal)
            robustnessOPs(k).baseline_min_real_pole_mag = min(abs(real(real_poles_cal)));
        else
            robustnessOPs(k).baseline_min_real_pole_mag = 0;
        end
        complex_poles_cal = z_cal(~is_real_cal);
        complex_damping_cal = Damping_cal(~is_real_cal);
        freq_cal = abs(imag(complex_poles_cal));
        is_spurious_cal = freq_cal > eigenConfig.spurious_freq_thresh;
        % Per-band calibration: 3 bands
        %   LF: |Im| ≤ mf_freq_thresh (grid/slow modes ~17 rad/s)
        %   MF: mf_freq_thresh < |Im| ≤ hf_freq_thresh (VSMP modes ~314 rad/s)
        %   HF: hf_freq_thresh < |Im| ≤ spurious_freq_thresh (current loops ~1400 rad/s)
        is_lf_cal = freq_cal <= eigenConfig.mf_freq_thresh & ~is_spurious_cal;
        is_mf_cal = freq_cal > eigenConfig.mf_freq_thresh & freq_cal <= eigenConfig.hf_freq_thresh & ~is_spurious_cal;
        is_hf_cal = freq_cal > eigenConfig.hf_freq_thresh & ~is_spurious_cal;
        lf_damping_cal = complex_damping_cal(is_lf_cal);
        mf_damping_cal = complex_damping_cal(is_mf_cal);
        hf_damping_cal = complex_damping_cal(is_hf_cal);
        if ~isempty(lf_damping_cal)
            robustnessOPs(k).baseline_min_damping_lf = min(lf_damping_cal);
        else
            robustnessOPs(k).baseline_min_damping_lf = 0;
        end
        if ~isempty(mf_damping_cal)
            robustnessOPs(k).baseline_min_damping_mf = min(mf_damping_cal);
        else
            robustnessOPs(k).baseline_min_damping_mf = 0;
        end
        if ~isempty(hf_damping_cal)
            robustnessOPs(k).baseline_min_damping_hf = min(hf_damping_cal);
        else
            robustnessOPs(k).baseline_min_damping_hf = 0;
        end
        fprintf('  OP%d (SCR=%.1f): min|Re(z)|=%.6f, damp_LF=%.6f, damp_MF=%.6f, damp_HF=%.6f\n', ...
            k, SCR_k, robustnessOPs(k).baseline_min_real_pole_mag, ...
            robustnessOPs(k).baseline_min_damping_lf, robustnessOPs(k).baseline_min_damping_mf, ...
            robustnessOPs(k).baseline_min_damping_hf);
    end
    cd(calStartDir);
    % 99.5% tolerance on ALL constraints to absorb GA integer quantization
    % noise. The GA encodes parameters as integers (quantized), then decodes
    % back — this lossy transformation introduces micro-perturbation (~0.1%)
    % in eigenvalues. Without tolerance, even the baseline design (seed)
    % fails its own constraints after encode→decode.
    %
    % 99.5% is sufficient to separate quantization noise (~0.1%) from real
    % physical degradation (12-30% in MF band when Lv/Rv changes).
    EIGEN_TOLERANCE = 0.99;
    for k = 1:length(robustnessOPs)
        robustnessOPs(k).baseline_min_real_pole_mag = robustnessOPs(k).baseline_min_real_pole_mag * EIGEN_TOLERANCE;
        robustnessOPs(k).baseline_min_damping_lf    = robustnessOPs(k).baseline_min_damping_lf * EIGEN_TOLERANCE;
        robustnessOPs(k).baseline_min_damping_mf    = robustnessOPs(k).baseline_min_damping_mf * EIGEN_TOLERANCE;
        robustnessOPs(k).baseline_min_damping_hf    = robustnessOPs(k).baseline_min_damping_hf * EIGEN_TOLERANCE;
    end
    gaMetadata.robustnessOPs = robustnessOPs;
    fprintf('--- Baseline thresholds calibrated (2 OPs, 3-band LF/MF/HF, %.1f%% tolerance for GA quantization). ---\n\n', EIGEN_TOLERANCE*100);

    if strcmp(fitnessMode, 'linear_itae') || strcmp(fitnessMode, 'linear_itae_biobj')
        % linear_itae v10/v6: step transient ITAE (step - y(T)), T_sim=80s
        %
        % Group 1 — Frequency regulation (H↑ → ITAE↓, good):
        %   il_r → Δf,  il_i → Δf
        % Group 2 — Voltage regulation (H↑ → ITAE↓, good):
        %   il_r → ΔV,  il_i → ΔV
        % Group 3 — Power tracking (H↑ → ITAE↑, bad — direct counterbalance):
        %   P_ref → P_actual,  Q_ref → Q_actual
        % Group 4 — DC bus stress (neutral wrt H — converter health):
        %   il_r → ΔVdc,  P_ref → ΔVdc
        %
        % J = (ITAE_f_pert/ITAE0_f_pert + ITAE_v_pert/ITAE0_v_pert
        %    + ITAE_track/ITAE0_track   + ITAE_vdc/ITAE0_vdc) / 4
        %
        % Key improvement over v9:
        %   - Group 3 measures P_actual and Q_actual DIRECTLY (not Δf/ΔV)
        %     → H↑ slows VSM inertial response → P_actual lags P_ref → ITAE↑
        %   - Group 4 captures converter health (V_dc oscillations)
        %     → penalizes designs that look good externally but stress the DC bus
        gaMetadata.itae_sim_duration = 80.0;
        gaMetadata.itae_npoints      = 5000;

        % Compute baseline ITAE for normalization (J_baseline = 1.0)
        % ALWAYS use FRD original design as baseline reference, regardless of
        % which phase we're optimizing. This ensures J values are comparable
        % across all phases and iterative refinement cycles (PDS→QDS→PDS...).
        frd_baseline_file = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'RESULTS', 'CONTROL', 'LIN_MODEL_FRD_OPT.mat');
        if exist(frd_baseline_file, 'file')
            frd_data = load(frd_baseline_file);
            frd_varname = fieldnames(frd_data);
            LIN_MODEL_BASELINE = frd_data.(frd_varname{1});
            % Ensure load_node=1 for baseline (PCC injection, same as GA)
            if ~isfield(LIN_MODEL_BASELINE.MODEL.LINE.PARAM, 'load_node') || LIN_MODEL_BASELINE.MODEL.LINE.PARAM.load_node ~= 1
                LIN_MODEL_BASELINE.MODEL.LINE.PARAM.load_node = 1;
            end
            % Verify baseline dimensions match expectations
            nOutputsBaseline = size(LIN_MODEL_BASELINE.ssModel.c, 1);
            fprintf('  Baseline ssModel: %d outputs\n', nOutputsBaseline);
            ssModel_baseline = LIN_MODEL_BASELINE.ssModel;
            fprintf('  ITAE baseline: FRD original (LIN_MODEL_FRD_OPT.mat)\n');
            fprintf('  Baseline H = %.2f s\n', LIN_MODEL_BASELINE.CONTROL.VSMP.PARAM.H(1));
        else
            % Fallback: use current model if FRD file not found
            ssModel_baseline = ssModel;
            fprintf('  WARNING: FRD baseline not found at %s\n', frd_baseline_file);
            fprintf('  Falling back to current model for baseline normalization\n');
        end

        % --- Indices for CURRENT model (used by GA fitness functions) ---
        nLINE_cur = LIN_MODEL.MODEL.LINE.PARAM.nLINE;
        nDFIG_cur = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
        selectedDFIG_cur = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;

        indO_aux_cur = 2*nCONTROL*nDFIG_cur + 2;
        gaMetadata.indO_P   = indO_aux_cur + nDFIG_cur + selectedDFIG_cur;
        gaMetadata.indO_Q   = indO_aux_cur + 2*nDFIG_cur + selectedDFIG_cur;
        gaMetadata.indO_Vdc = indO_aux_cur + 3*nDFIG_cur + selectedDFIG_cur;

        indI_vw_cur = nCONTROL*nDFIG_cur + 2*nDFIG_cur + 2*nLINE_cur + selectedDFIG_cur;
        gaMetadata.indI_vw = indI_vw_cur;
        nInputsActual = size(ssModel.b, 2);
        hasWindInput = (indI_vw_cur <= nInputsActual);
        gaMetadata.hasWindInput = hasWindInput;
        if strcmp(fitnessMode, 'linear_itae_biobj') && ~hasWindInput
            error('OPTIMIZER:noWindInput', 'linear_itae_biobj requires vw_delta input (Port 6). Model has %d inputs, need >= %d.', nInputsActual, indI_vw_cur);
        end

        % Verify current model output dimension
        nOutputsExpected = 2*nCONTROL*nDFIG_cur + 2 + 4*nDFIG_cur;
        nOutputsActual = size(ssModel.c, 1);
        if nOutputsActual ~= nOutputsExpected
            fprintf('  WARNING: ssModel has %d outputs, expected %d.\n', nOutputsActual, nOutputsExpected);
        end

        % --- Indices for BASELINE model (used for ITAE normalization only) ---
        % These may differ from current model if FRD was linearized with different load_node
        if exist('LIN_MODEL_BASELINE', 'var')
            nLINE_bl = LIN_MODEL_BASELINE.MODEL.LINE.PARAM.nLINE;
            nDFIG_bl = LIN_MODEL_BASELINE.MODEL.DFIG.PARAM.nDFIG;
            nCONTROL_bl = nCONTROL;  % same control structure
            selectedDFIG_bl = LIN_MODEL_BASELINE.CONTROL_DESIGN.selectedDFIG;
        else
            nLINE_bl = nLINE_cur; nDFIG_bl = nDFIG_cur;
            nCONTROL_bl = nCONTROL; selectedDFIG_bl = selectedDFIG_cur;
        end

        % Baseline input indices
        indI_Pl_bl = nCONTROL_bl*nDFIG_bl + 2*nDFIG_bl + nLINE_bl;       % il_r
        indI_Ql_bl = nCONTROL_bl*nDFIG_bl + 2*nDFIG_bl + nLINE_bl + 1;   % il_i
        indI_Pr_bl = nCONTROL_bl*nDFIG_bl + selectedDFIG_bl;              % P_ref
        indI_Qr_bl = nCONTROL_bl*nDFIG_bl + nDFIG_bl + selectedDFIG_bl;  % Q_ref
        % Baseline output indices
        indO_f_bl  = 2*nCONTROL_bl*nDFIG_bl + 1;   % frequency
        indO_v_bl  = 2*nCONTROL_bl*nDFIG_bl + 2;   % PCC voltage
        indO_aux_bl = 2*nCONTROL_bl*nDFIG_bl + 2;
        indO_P_bl   = indO_aux_bl + nDFIG_bl + selectedDFIG_bl;
        indO_Q_bl   = indO_aux_bl + 2*nDFIG_bl + selectedDFIG_bl;
        indO_Vdc_bl = indO_aux_bl + 3*nDFIG_bl + selectedDFIG_bl;
        % Baseline wind input
        indI_vw_bl = nCONTROL_bl*nDFIG_bl + 2*nDFIG_bl + 2*nLINE_bl + selectedDFIG_bl;

        t_b  = linspace(0, gaMetadata.itae_sim_duration, gaMetadata.itae_npoints)';
        dt_b = t_b(2) - t_b(1);
        % Use BASELINE ssModel for ITAE normalization (FRD original)
        Ab = ssModel_baseline.a; Bb = ssModel_baseline.b; Cb = ssModel_baseline.c; Db = ssModel_baseline.d;
        nOutputs_bl = size(Cb, 1);
        nInputs_bl  = size(Bb, 2);
        fprintf('  Baseline ssModel: %d states, %d inputs, %d outputs\n', size(Ab,1), nInputs_bl, nOutputs_bl);
        fprintf('  Current  ssModel: %d states, %d inputs, %d outputs\n', size(ssModel.a,1), nInputsActual, nOutputsActual);

        % Build 8 SISO systems from BASELINE — for ITAE normalization
        % Group 1: load perturbation → frequency
        sys_f_Pl_b = ss(Ab, Bb(:,indI_Pl_bl), Cb(indO_f_bl,:), Db(indO_f_bl,indI_Pl_bl));
        sys_f_Ql_b = ss(Ab, Bb(:,indI_Ql_bl), Cb(indO_f_bl,:), Db(indO_f_bl,indI_Ql_bl));
        % Group 2: load perturbation → voltage
        sys_v_Pl_b = ss(Ab, Bb(:,indI_Pl_bl), Cb(indO_v_bl,:), Db(indO_v_bl,indI_Pl_bl));
        sys_v_Ql_b = ss(Ab, Bb(:,indI_Ql_bl), Cb(indO_v_bl,:), Db(indO_v_bl,indI_Ql_bl));
        % Group 3: reference → actual power (DIRECT tracking)
        sys_P_Pr_b = ss(Ab, Bb(:,indI_Pr_bl), Cb(indO_P_bl,:), Db(indO_P_bl,indI_Pr_bl));
        sys_Q_Qr_b = ss(Ab, Bb(:,indI_Qr_bl), Cb(indO_Q_bl,:), Db(indO_Q_bl,indI_Qr_bl));
        % Group 4: perturbation/reference → Vdc (converter stress)
        sys_Vdc_Pl_b = ss(Ab, Bb(:,indI_Pl_bl), Cb(indO_Vdc_bl,:), Db(indO_Vdc_bl,indI_Pl_bl));
        sys_Vdc_Pr_b = ss(Ab, Bb(:,indI_Pr_bl), Cb(indO_Vdc_bl,:), Db(indO_Vdc_bl,indI_Pr_bl));

        % Step responses (8 channels)
        ys_f_Pl = step(sys_f_Pl_b, t_b);  ys_f_Ql = step(sys_f_Ql_b, t_b);
        ys_v_Pl = step(sys_v_Pl_b, t_b);  ys_v_Ql = step(sys_v_Ql_b, t_b);
        ys_P_Pr = step(sys_P_Pr_b, t_b);  ys_Q_Qr = step(sys_Q_Qr_b, t_b);
        ys_Vdc_Pl = step(sys_Vdc_Pl_b, t_b);  ys_Vdc_Pr = step(sys_Vdc_Pr_b, t_b);

        % Transient errors: y(t) - y(T) — pure transient, no steady-state contamination
        ye_f_Pl = ys_f_Pl - ys_f_Pl(end);  ye_f_Ql = ys_f_Ql - ys_f_Ql(end);
        ye_v_Pl = ys_v_Pl - ys_v_Pl(end);  ye_v_Ql = ys_v_Ql - ys_v_Ql(end);
        ye_P_Pr = ys_P_Pr - ys_P_Pr(end);  ye_Q_Qr = ys_Q_Qr - ys_Q_Qr(end);
        ye_Vdc_Pl = ys_Vdc_Pl - ys_Vdc_Pl(end);  ye_Vdc_Pr = ys_Vdc_Pr - ys_Vdc_Pr(end);

        if strcmp(fitnessMode, 'linear_itae')
            % v10 mono-objective: 4 grouped baseline ITAEs
            gaMetadata.itae0_f_pert = sum(t_b .* abs(ye_f_Pl)) * dt_b + sum(t_b .* abs(ye_f_Ql)) * dt_b;
            gaMetadata.itae0_v_pert = sum(t_b .* abs(ye_v_Pl)) * dt_b + sum(t_b .* abs(ye_v_Ql)) * dt_b;
            gaMetadata.itae0_track  = sum(t_b .* abs(ye_P_Pr)) * dt_b + sum(t_b .* abs(ye_Q_Qr)) * dt_b;
            gaMetadata.itae0_vdc    = sum(t_b .* abs(ye_Vdc_Pl)) * dt_b + sum(t_b .* abs(ye_Vdc_Pr)) * dt_b;

            fprintf('linear_itae v10: 8-channel step transient ITAE (step - y(T)), T_sim=%.0fs, %d points\n', ...
                gaMetadata.itae_sim_duration, gaMetadata.itae_npoints);
            fprintf('  Baseline output indices: f=%d, V=%d, P=%d, Q=%d, Vdc=%d (nOut=%d)\n', ...
                indO_f_bl, indO_v_bl, indO_P_bl, indO_Q_bl, indO_Vdc_bl, nOutputs_bl);
            fprintf('  Final values (y(T)): f_Pl=%.4e, f_Ql=%.4e, v_Pl=%.4e, v_Ql=%.4e\n', ...
                ys_f_Pl(end), ys_f_Ql(end), ys_v_Pl(end), ys_v_Ql(end));
            fprintf('  Tracking y(T):       P_Pr=%.4e, Q_Qr=%.4e (expect ~1.0)\n', ys_P_Pr(end), ys_Q_Qr(end));
            fprintf('  Vdc y(T):            Vdc_Pl=%.4e, Vdc_Pr=%.4e (expect ~0)\n', ys_Vdc_Pl(end), ys_Vdc_Pr(end));
            fprintf('  Baseline ITAE (4 groups): f_pert=%.4e, v_pert=%.4e, track=%.4e, vdc=%.4e\n', ...
                gaMetadata.itae0_f_pert, gaMetadata.itae0_v_pert, gaMetadata.itae0_track, gaMetadata.itae0_vdc);
            if exist('LIN_MODEL_BASELINE', 'var')
                fprintf('  Baseline H = %.2f s (FRD original)\n', LIN_MODEL_BASELINE.CONTROL.VSMP.PARAM.H(1));
            else
                fprintf('  Baseline H = %.2f s (current model)\n', LIN_MODEL.CONTROL.VSMP.PARAM.H(1));
            end
            fprintf('  Objective: J = mean of 4 normalized ITAEs (baseline=1.0)\n');

        else  % linear_itae_biobj
            % v6 bi-objective: 10 per-channel baseline ITAEs
            % Wind channels (2 additional SISO systems) — from baseline
            sys_f_vw_b = ss(Ab, Bb(:,indI_vw_bl), Cb(indO_f_bl,:), Db(indO_f_bl,indI_vw_bl));
            sys_v_vw_b = ss(Ab, Bb(:,indI_vw_bl), Cb(indO_v_bl,:), Db(indO_v_bl,indI_vw_bl));
            ys_f_vw = step(sys_f_vw_b, t_b);  ys_v_vw = step(sys_v_vw_b, t_b);
            ye_f_vw = ys_f_vw - ys_f_vw(end);  ye_v_vw = ys_v_vw - ys_v_vw(end);

            % Per-channel baseline ITAEs (10 channels)
            % J1 — Regulation (6 channels): load + wind → Δf, ΔV
            gaMetadata.itae0_f_Pl = sum(t_b .* abs(ye_f_Pl)) * dt_b;
            gaMetadata.itae0_f_Ql = sum(t_b .* abs(ye_f_Ql)) * dt_b;
            gaMetadata.itae0_v_Pl = sum(t_b .* abs(ye_v_Pl)) * dt_b;
            gaMetadata.itae0_v_Ql = sum(t_b .* abs(ye_v_Ql)) * dt_b;
            gaMetadata.itae0_f_vw = sum(t_b .* abs(ye_f_vw)) * dt_b;
            gaMetadata.itae0_v_vw = sum(t_b .* abs(ye_v_vw)) * dt_b;
            % J2 — Tracking (2 channels): P_ref → P, Q_ref → Q
            gaMetadata.itae0_P_Pr = sum(t_b .* abs(ye_P_Pr)) * dt_b;
            gaMetadata.itae0_Q_Qr = sum(t_b .* abs(ye_Q_Qr)) * dt_b;
            % Vdc constraint (2 channels): peak excursion
            gaMetadata.itae0_Vdc_Pl = sum(t_b .* abs(ye_Vdc_Pl)) * dt_b;
            gaMetadata.itae0_Vdc_Pr = sum(t_b .* abs(ye_Vdc_Pr)) * dt_b;
            % Vdc peak baseline (for constraint threshold calibration)
            gaMetadata.vdc_peak_Pl_baseline = max(abs(ys_Vdc_Pl));
            gaMetadata.vdc_peak_Pr_baseline = max(abs(ys_Vdc_Pr));

            % Verify J1_baseline = J2_baseline = 1.0
            J1_check = mean([1 1 1 1 1 1]);  % each itae0/itae0 = 1
            J2_check = mean([1 1]);
            fprintf('linear_itae_biobj v6: 10-channel step transient ITAE (step - y(T)), T_sim=%.0fs, %d points\n', ...
                gaMetadata.itae_sim_duration, gaMetadata.itae_npoints);
            fprintf('  Baseline indices: il_r=%d, il_i=%d, P_ref=%d, Q_ref=%d, vw=%d\n', ...
                indI_Pl_bl, indI_Ql_bl, indI_Pr_bl, indI_Qr_bl, indI_vw_bl);
            fprintf('  Baseline outputs: f=%d, V=%d, P=%d, Q=%d, Vdc=%d (nIn=%d, nOut=%d)\n', ...
                indO_f_bl, indO_v_bl, indO_P_bl, indO_Q_bl, indO_Vdc_bl, nInputs_bl, nOutputs_bl);
            fprintf('  J1 baseline ITAEs (regulation, 6 ch):\n');
            fprintf('    f_Pl=%.4e  f_Ql=%.4e  v_Pl=%.4e  v_Ql=%.4e  f_vw=%.4e  v_vw=%.4e\n', ...
                gaMetadata.itae0_f_Pl, gaMetadata.itae0_f_Ql, gaMetadata.itae0_v_Pl, ...
                gaMetadata.itae0_v_Ql, gaMetadata.itae0_f_vw, gaMetadata.itae0_v_vw);
            fprintf('  J2 baseline ITAEs (tracking, 2 ch):\n');
            fprintf('    P_Pr=%.4e  Q_Qr=%.4e\n', gaMetadata.itae0_P_Pr, gaMetadata.itae0_Q_Qr);
            fprintf('  Vdc baseline peaks: Pl=%.4e  Pr=%.4e\n', ...
                gaMetadata.vdc_peak_Pl_baseline, gaMetadata.vdc_peak_Pr_baseline);
            fprintf('  Final values (y(T)): P_Pr=%.4e (expect ~1.0), Q_Qr=%.4e, Vdc_Pl=%.4e, Vdc_Pr=%.4e\n', ...
                ys_P_Pr(end), ys_Q_Qr(end), ys_Vdc_Pl(end), ys_Vdc_Pr(end));
            if exist('LIN_MODEL_BASELINE', 'var')
                fprintf('  Baseline H = %.2f s (FRD original)\n', LIN_MODEL_BASELINE.CONTROL.VSMP.PARAM.H(1));
                fprintf('  Current  H = %.2f s\n', LIN_MODEL.CONTROL.VSMP.PARAM.H(1));
            else
                fprintf('  Baseline H = %.2f s (current model)\n', LIN_MODEL.CONTROL.VSMP.PARAM.H(1));
            end
            fprintf('  Objectives: J1=mean(6 reg ITAEs), J2=mean(2 track ITAEs), baseline=[1.0, 1.0]\n');
            fprintf('  Constraint: peak|ΔVdc| < 10%% Vdc_nom\n');
        end
    end
end

% Default perturbation configurations for hybrid fitness mode
if strcmp(fitnessMode, 'hybrid')
    % P-axis scenarios: evaluated when input_type='P' (optType 1,3,5)
    % Each scenario: struct with .pertType and .pertConfig
    % Perturbation at t=0: trust analytical OP (improved by findop refinement)
    pc_P = struct();
    pc_P.breaker_mask = [1 0 1 0];   % Disconnect DFIGs 1 & 3 (50% generation)
    pc_P.breaker_time = 5e-3;          % [s] perturbation at t=5ms (avoids t=0 stiffness + spike)
    pc_P.settling_time = 0;           % [s] no settling phase
    pc_P.sim_duration = 5.0 + 5e-3;   % [s] 5s post-perturbation + 5ms pre-pert
    pc_P.eval_window_f = [7e-3, 5.0 + 5e-3]; % [s] skip 2ms spike, evaluate 5s from perturbation
    pc_P.f_ref = 1.0;                % [pu] nominal frequency (analytical OP)
    pc_P.V_ref = LIN_MODEL.opSpecs.Vp; % [pu] nominal PCC voltage (analytical OP)
    gaMetadata.pertScenarios_P = { struct('pertType','generation_loss', 'pertConfig',pc_P) };

    % Q-axis scenarios: evaluated when input_type='Q' (optType 2,4,5)
    pc_Q = struct();
    pc_Q.sag_depth = 0.2;             % 20% voltage sag
    pc_Q.sag_start_time = 5e-3;        % [s] sag at t=5ms (avoids t=0 stiffness + spike)
    pc_Q.sag_duration = 0.15;         % [s] 150ms sag
    pc_Q.settling_time = 0;           % [s] no settling phase
    pc_Q.sim_duration = 5.0 + 5e-3;   % [s] 5s post-perturbation + 5ms pre-pert
    pc_Q.eval_window_v = [5e-3, 5.0 + 5e-3]; % [s] evaluate 5s from perturbation (no T_SKIP for sag)
    pc_Q.f_ref = 1.0;                % [pu] nominal frequency (analytical OP)
    pc_Q.V_ref = LIN_MODEL.opSpecs.Vp; % [pu] nominal PCC voltage (analytical OP)
    gaMetadata.pertScenarios_Q = { struct('pertType','voltage_sag', 'pertConfig',pc_Q) };

    % Aggregation method for multi-scenario evaluation
    % 'worst_case': max across scenarios (conservative, default)
    % 'mean': average across scenarios (balanced)
    gaMetadata.scenarioAggregation = 'worst_case';

    % Cost metric selection: 'IAE' or 'ITAE' per axis
    % ITAE penalizes persistent/late errors → better for slow-settling responses
    % IAE treats all errors equally → better for fast transient responses
    gaMetadata.costMetric_P = 'ITAE';  % P-axis: ITAE for frequency recovery after gen loss
    gaMetadata.costMetric_Q = 'IAE';   % Q-axis: IAE for voltage recovery after sag

    % hybrid mode: re-enable perturbation constraints (disabled by default in shared block)
    gaMetadata.pertConstraints.enabled = true;

    fprintf('Hybrid fitness mode: %d P-scenario(s), %d Q-scenario(s), aggregation=%s (nObj=%d)\n', ...
        length(gaMetadata.pertScenarios_P), length(gaMetadata.pertScenarios_Q), ...
        gaMetadata.scenarioAggregation, nObj);
    fprintf('Cost metrics: P-axis=%s, Q-axis=%s\n', gaMetadata.costMetric_P, gaMetadata.costMetric_Q);
    fprintf('Eigenvalue constraints: min_real=%.2f, min_damp=%.3f, spurious_thresh=%d rad/s\n', ...
        gaMetadata.eigenConfig.min_real_pole_mag, gaMetadata.eigenConfig.min_damping, gaMetadata.eigenConfig.spurious_freq_thresh);
    fprintf('Perturbation constraints: max_ROCOF=%.2f, max_ROCOV=%.2f, min_nadir_f=%.2f, min_nadir_V=%.2f\n', ...
        gaMetadata.pertConstraints.max_ROCOF, gaMetadata.pertConstraints.max_ROCOV, ...
        gaMetadata.pertConstraints.min_nadir_f, gaMetadata.pertConstraints.min_nadir_V);
end

% Wrap fitness function to include metadata
FitnessFunction = @(param) fitnessFcn(LIN_MODEL,param,scale,optType,gaMetadata);

if strcmp(fitnessMode, 'linear_itae')
    %----------------------------------------------------------------------
    %% MONO-OBJECTIVE GA (linear_itae mode)
    %----------------------------------------------------------------------
    [param_opt_best, fval_opt_best, ~, output_ga] = ga(FitnessFunction,numParam,Aineq,bineq,Aeq,beq,lb,ub,[],intcon,options);
    % ga() returns a single best individual
    param_opt = param_opt_best;
    fval_opt  = fval_opt_best;
    N = 1;  % Single solution (no Pareto front)
    fprintf('\nga() completed: %d generations, J_best = %.6f\n', output_ga.generations, fval_opt_best);
elseif strcmp(fitnessMode, 'linear_itae_biobj')
    %----------------------------------------------------------------------
    %% BI-OBJECTIVE GAMULTIOBJ (linear_itae_biobj mode: J1=reg, J2=track)
    %----------------------------------------------------------------------
    [param_opt,fval_opt,~,~,~,~] = gamultiobj(FitnessFunction,numParam,Aineq,bineq,Aeq,beq,lb,ub,[],intcon,options);

    % BEST CASE SELECTION — Normalized Compromise (L1 distance to utopian point)
    N = size(fval_opt,1);
    fval_max = max(fval_opt);
    fval_min = min(fval_opt);
    fval_range = fval_min - fval_max;
    safe_range = fval_range;
    safe_range(abs(safe_range) < 1e-12) = 1;
    fval_pu = (fval_opt - repmat(fval_max,N,1)) ./ repmat(safe_range,N,1);
    mean_pu = mean(fval_pu, 2);
    [~,ind] = sort(mean_pu, 'descend');
    fval_opt = fval_opt(ind,:);
    param_opt = param_opt(ind,:);
    fprintf('\ngamultiobj() completed: Pareto front = %d solutions, J1_best=%.4f, J2_best=%.4f\n', ...
        N, min(fval_opt(:,1)), min(fval_opt(:,2)));
else
    %----------------------------------------------------------------------
    %% MULTI-OBJECTIVE GAMULTIOBJ (linear and hybrid modes)
    %----------------------------------------------------------------------
    [param_opt,fval_opt,~,~,~,~] = gamultiobj(FitnessFunction,numParam,Aineq,bineq,Aeq,beq,lb,ub,[],intcon,options);

    % BEST CASE SELECTION — Normalized Compromise (L1 distance to utopian point)
    % Method: normalize each objective to [0,1] over the Pareto front range
    %   0 = worst value on front, 1 = best value on front
    % Then select the individual with the maximum MEAN of normalized objectives.
    % Reference: "Normalized compromise programming" (Zeleny 1973)
    N = size(fval_opt,1);
    fval_max = max(fval_opt);
    fval_min = min(fval_opt);
    fval_range = fval_min - fval_max;
    safe_range = fval_range;
    safe_range(abs(safe_range) < 1e-12) = 1;
    fval_pu = (fval_opt - repmat(fval_max,N,1)) ./ repmat(safe_range,N,1);
    mean_pu = mean(fval_pu, 2);
    [~,ind] = sort(mean_pu, 'descend');
    fval_opt = fval_opt(ind,:);
    param_opt = param_opt(ind,:);
end

% Compute final LIN_MODEL with best parameters
[~,LIN_MODEL] = fitnessFcn(LIN_MODEL,param_opt(1,:),scale,optType,gaMetadata);

% Display detailed optimization summary
display_optimization_summary(optType, param_opt, fval_opt, scale, LIN_MODEL, N, fitnessMode);

% Return Pareto front data if requested (for GAM_*.mat save by caller)
if nargout > 1
    GAM_RESULTS.param_opt = param_opt;
    GAM_RESULTS.fval_opt = fval_opt;
    GAM_RESULTS.N = N;
    GAM_RESULTS.scale = scale;
    GAM_RESULTS.optType = optType;
    GAM_RESULTS.fitnessMode = fitnessMode;
    varargout{1} = GAM_RESULTS;
end

% NOTE: Saving is now handled by CONFIG_POWER_SYSTEM.m after this function returns
%       No hardcoded file paths in OPTIMIZER.m - all path management in main script

% Cleanup progress file
if exist(progressFile, 'file')
    delete(progressFile);
end

% Cleanup Simulink worker models
if useParallel
    currentDir = pwd;  % Save current directory
    try
        % Navigate to SIMULINK from GA_MULTIOBJECTIVE (where gamultiobj returns)
        cd('../../SIMULINK');
        bdclose('all');
        delete([LIN_MODEL.modelName '_*']);
    catch cleanup_error
        % If navigation or deletion fails
        warning('OPTIMIZER:CleanupError', '%s', cleanup_error.message);
        bdclose('all');
    end
    % ALWAYS return to where we started
    cd(currentDir);
end


end

%--------------------------------------------------------------
%% FITNESS FUNCTION
%--------------------------------------------------------------
function [fval,LIN_MODEL] = fitnessFcn(LIN_MODEL,param,scale,optType,gaMetadata)
    % Persistent counter for THIS worker only (guaranteed to work)
    persistent workerIndCounter

    % Get worker ID for parallel execution
    worker = getCurrentTask();
    if isempty(worker)
        workerID = 0;  % Sequential mode
    else
        workerID = worker.ID;  % Parallel mode
    end

    % Initialize worker-local counter
    if isempty(workerIndCounter)
        workerIndCounter = 0;
    end
    workerIndCounter = workerIndCounter + 1;

    % Read current generation from progress file
    try
        data = load(gaMetadata.progressFile);
        currentGen = data.currentGen;
    catch
        % File doesn't exist yet or is being written - use defaults
        currentGen = 1;
    end

    % Calculate individual number within current generation
    % Formula: (workerIteration - 1) * numWorkers + workerID
    % Sequential mode (workerID=0): just use workerIndCounter
    if workerID == 0
        indInGen = workerIndCounter;
    else
        indInGen = (workerIndCounter - 1) * gaMetadata.numWorkers + workerID;
    end

    try
        warning('off')
        nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
        nCONTROL = 7;
        nObj = gaMetadata.nObj;
        penaltyFval = 1e6 * ones(nObj, 1);

        % Optimization type labels for display
        optLabels = {'PDS', 'QDS', 'PCP', 'QCP', 'VI'};
        optLabel = optLabels{optType};

        % Phase margin validation limits (read from bounds - scaled values)
        % lbDS_P/ubDS_P: positions [1,3,5,7] correspond to Fm for [VSMP, RSCq, VDC, GSCq]
        % Scaled by 10, so 500 → 50.0°, 900 → 90.0°
        Fm_min_scaled = 500;  % Minimum acceptable Fm (scaled) = 50.0°
        Fm_max_scaled = 900;  % Maximum acceptable Fm (scaled) = 90.0°
        Fm_min = Fm_min_scaled / 10.0;  % Convert to degrees
        Fm_max = Fm_max_scaled / 10.0;  % Convert to degrees

        % Save starting directory for consistent navigation
        startDir = pwd;

        %----------------------------------------------------------------------
        cd(fullfile(startDir, '../../BUS_DEFINITIONS'))
        BusDefinition(LIN_MODEL.CONTROL,'CONTROL_Bus')
        BusDefinition(LIN_MODEL.MODEL,'MODEL_Bus')
        %----------------------------------------------------------------------
        switch(optType)
            %--------------------------------------------------------------
            case 1 % Design specs P
                %--------------------------------------------------------------
                % Selected DFIG
                selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;

                % Specs
                LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.Fm = param(1)*scale(1);
                LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.wo = param(2)*scale(2);
                LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.Fm(2) = param(3)*scale(3);
                LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.wo(2) = param(4)*scale(4);
                LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.Fm = param(5)*scale(5);
                LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.wo = param(6)*scale(6);
                LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.Fm(2) = param(7)*scale(7);
                LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.wo(2) = param(8)*scale(8);
                % Design P controllers
                cd(fullfile(startDir, '../../CONTROL'))
                LIN_MODEL = CONTROL_DESIGN_FR(LIN_MODEL,false,workerID);

                % VALIDATE PHASE MARGINS - Control by control validation
                % CRITICAL: Must force 1-DOF for EACH control individually
                % Fm_min and Fm_max defined at start of fitnessFcn

                % Validate VSMP
                der2error_backup = LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG);
                LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG) = 1;
                cd(fullfile(startDir, '../../CONFIGURATION'))
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_VSMP = LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.Fm;
                LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG) = der2error_backup;

                % Validate RSCq
                b_RSCq_backup = LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_RSCq = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm(2);
                LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG) = b_RSCq_backup;

                % Validate VDC
                b_VDC_backup = LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_VDC = LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.Fm;
                LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG) = b_VDC_backup;

                % Validate GSCq
                b_GSCq_backup = LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_GSCq = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm(2);
                LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG) = b_GSCq_backup;

                % Check if any margin is outside acceptable range
                if Fm_VSMP < Fm_min || Fm_VSMP > Fm_max || ...
                   Fm_RSCq < Fm_min || Fm_RSCq > Fm_max || ...
                   Fm_VDC < Fm_min  || Fm_VDC > Fm_max  || ...
                   Fm_GSCq < Fm_min || Fm_GSCq > Fm_max
                    % Reject individual - phase margins out of range
                    fval = penaltyFval;
                else
                    % Re-linearize with ALL b/der2error restored to get
                    % correct ssModel for ITAE evaluation (full 2-DOF)
                    % Without this, ssModel retains last Fm validation
                    % (GSCq with b=1) → identical ITAE for all individuals
                    cd(fullfile(startDir, '../../CONFIGURATION'))
                    LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL, workerID);
                    % All margins acceptable - compute fitness metrics
                    fval = compute_fitness_metrics(LIN_MODEL, LIN_MODEL.ssModel, selectedDFIG, nDFIG, nCONTROL, 'P', gaMetadata, workerID);
                end
                %--------------------------------------------------------------
            case 2 % Design specs Q
                %--------------------------------------------------------------
                % Selected DFIG
                selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
                % Specs
                LIN_MODEL.CONTROL_DESIGN.VSMQ.frdSpecs.wo = param(9)*scale(9);
                LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.Fm(1) = param(10)*scale(10);
                LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.wo(1) = param(11)*scale(11);
                LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.Fm(1) = param(12)*scale(12);
                LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.wo(1) = param(13)*scale(13);
                % Design Q controllers
                cd(fullfile(startDir, '../../CONTROL'))
                LIN_MODEL = CONTROL_DESIGN_FR(LIN_MODEL,false,workerID);

                % VALIDATE PHASE MARGINS - Control by control validation
                % CRITICAL: Must force 1-DOF for EACH control individually

                % Validate RSCd
                b_RSCd_backup = LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG) = 1;
                cd(fullfile(startDir, '../../CONFIGURATION'))
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_RSCd = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm(1);
                LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG) = b_RSCd_backup;

                % Validate GSCd
                b_GSCd_backup = LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_GSCd = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm(1);
                LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG) = b_GSCd_backup;

                % Check if any margin is outside acceptable range
                if Fm_RSCd < Fm_min || Fm_RSCd > Fm_max || Fm_GSCd < Fm_min || Fm_GSCd > Fm_max
                    % Reject individual - phase margins out of range
                    fval = penaltyFval;
                else
                    % Re-linearize with ALL b restored to get correct
                    % ssModel for ITAE evaluation (full 2-DOF)
                    cd(fullfile(startDir, '../../CONFIGURATION'))
                    LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL, workerID);
                    % All margins acceptable - compute fitness metrics
                    fval = compute_fitness_metrics(LIN_MODEL, LIN_MODEL.ssModel, selectedDFIG, nDFIG, nCONTROL, 'Q', gaMetadata, workerID);
                end
                %--------------------------------------------------------------
            case 3 % Control Param P
                %--------------------------------------------------------------
                % Selected DFIG
                selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
                % Control parameters
                LIN_MODEL.CONTROL.VSMP.PARAM.der2error = param(14)*scale(14)*ones(1,nDFIG);
                LIN_MODEL.CONTROL.RSCq.PARAM.b = param(15)*scale(15)*ones(1,nDFIG);
                LIN_MODEL.CONTROL.VDC.PARAM.b = param(16)*scale(16)*ones(1,nDFIG);
                LIN_MODEL.CONTROL.GSCq.PARAM.b = param(17)*scale(17)*ones(1,nDFIG);
                % New operating point and linearization (with 2-DOF params)
                cd(fullfile(startDir, '../../CONFIGURATION'))
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);

                % VALIDATE PHASE MARGINS - Control by control validation
                % CRITICAL: Must force 1-DOF for EACH control individually

                % Validate VSMP
                der2error_backup = LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG);
                LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_VSMP = LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.Fm;
                LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG) = der2error_backup;

                % Validate RSCq
                b_RSCq_backup = LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_RSCq = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm(2);
                LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG) = b_RSCq_backup;

                % Validate VDC
                b_VDC_backup = LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_VDC = LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.Fm;
                LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG) = b_VDC_backup;

                % Validate GSCq
                b_GSCq_backup = LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_GSCq = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm(2);
                LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG) = b_GSCq_backup;

                % Check if any margin is outside acceptable range
                if Fm_VSMP < Fm_min || Fm_VSMP > Fm_max || ...
                   Fm_RSCq < Fm_min || Fm_RSCq > Fm_max || ...
                   Fm_VDC < Fm_min  || Fm_VDC > Fm_max  || ...
                   Fm_GSCq < Fm_min || Fm_GSCq > Fm_max
                    % Reject individual - phase margins out of range
                    fval = penaltyFval;
                else
                    % Re-linearize with ALL b/der2error restored (full 2-DOF)
                    cd(fullfile(startDir, '../../CONFIGURATION'))
                    LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL, workerID);
                    % All margins acceptable - compute fitness metrics
                    fval = compute_fitness_metrics(LIN_MODEL, LIN_MODEL.ssModel, selectedDFIG, nDFIG, nCONTROL, 'P', gaMetadata, workerID);
                end
                %--------------------------------------------------------------
            case 4 % Control Param Q
                %--------------------------------------------------------------
                % Selected DFIG
                selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
                % Control parameters
                LIN_MODEL.CONTROL.RSCd.PARAM.b = param(18)*scale(18)*ones(1,nDFIG);
                LIN_MODEL.CONTROL.GSCd.PARAM.b = param(19)*scale(19)*ones(1,nDFIG);
                % New operating point and linearization (with 2-DOF params)
                cd(fullfile(startDir, '../../CONFIGURATION'))
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);

                % VALIDATE PHASE MARGINS - Control by control validation
                % CRITICAL: Must force 1-DOF for EACH control individually

                % Validate RSCd
                b_RSCd_backup = LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_RSCd = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm(1);
                LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG) = b_RSCd_backup;

                % Validate GSCd
                b_GSCd_backup = LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_GSCd = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm(1);
                LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG) = b_GSCd_backup;

                % Check if any margin is outside acceptable range
                if Fm_RSCd < Fm_min || Fm_RSCd > Fm_max || Fm_GSCd < Fm_min || Fm_GSCd > Fm_max
                    fval = penaltyFval;
                else
                    % Re-linearize with ALL b restored (full 2-DOF)
                    cd(fullfile(startDir, '../../CONFIGURATION'))
                    LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL, workerID);
                    fval = compute_fitness_metrics(LIN_MODEL, LIN_MODEL.ssModel, selectedDFIG, nDFIG, nCONTROL, 'Q', gaMetadata, workerID);
                end
                %--------------------------------------------------------------
            case 5 % Virtual impedance
                %--------------------------------------------------------------
                % Selected DFIG
                selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
                % Control parameters
                LIN_MODEL.CONTROL.VIMP.PARAM.Lv_pu = param(20)*scale(20)*ones(1,nDFIG);
                LIN_MODEL.CONTROL.VIMP.PARAM.Rv_pu = zeros(1,nDFIG); % R_v fixed at 0
                % New operating point and linearization (with VI params)
                cd(fullfile(startDir, '../../CONFIGURATION'))
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);

                % VALIDATE PHASE MARGINS - Control by control validation (6 controllers)
                % CRITICAL: Must force 1-DOF for EACH control individually
                % NOTE: VSMQ is not validated to avoid potential undefined Fm issues

                % Validate VSMP
                der2error_backup = LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG);
                LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_VSMP = LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.Fm;
                LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG) = der2error_backup;

                % Validate RSCd
                b_RSCd_backup = LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_RSCd = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm(1);
                LIN_MODEL.CONTROL.RSCd.PARAM.b(selectedDFIG) = b_RSCd_backup;

                % Validate RSCq
                b_RSCq_backup = LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_RSCq = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm(2);
                LIN_MODEL.CONTROL.RSCq.PARAM.b(selectedDFIG) = b_RSCq_backup;

                % Validate VDC
                b_VDC_backup = LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_VDC = LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.Fm;
                LIN_MODEL.CONTROL.VDC.PARAM.b(selectedDFIG) = b_VDC_backup;

                % Validate GSCd
                b_GSCd_backup = LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_GSCd = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm(1);
                LIN_MODEL.CONTROL.GSCd.PARAM.b(selectedDFIG) = b_GSCd_backup;

                % Validate GSCq
                b_GSCq_backup = LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG);
                LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG) = 1;
                LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);
                Fm_GSCq = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm(2);
                LIN_MODEL.CONTROL.GSCq.PARAM.b(selectedDFIG) = b_GSCq_backup;

                % Check if any margin is outside acceptable range (6 controllers, VSMQ excluded)
                if Fm_VSMP < Fm_min || Fm_VSMP > Fm_max || ...
                   Fm_RSCd < Fm_min || Fm_RSCd > Fm_max || ...
                   Fm_RSCq < Fm_min || Fm_RSCq > Fm_max || ...
                   Fm_VDC < Fm_min  || Fm_VDC > Fm_max  || ...
                   Fm_GSCd < Fm_min || Fm_GSCd > Fm_max || ...
                   Fm_GSCq < Fm_min || Fm_GSCq > Fm_max
                    fval = penaltyFval;
                else
                    % Re-linearize with ALL b/der2error restored (full 2-DOF)
                    cd(fullfile(startDir, '../../CONFIGURATION'))
                    LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL, workerID);
                    fval = compute_fitness_metrics(LIN_MODEL, LIN_MODEL.ssModel, selectedDFIG, nDFIG, nCONTROL, 'Q', gaMetadata, workerID);
                end
                %--------------------------------------------------------------
            otherwise
                %--------------------------------------------------------------
                fval = penaltyFval;
        end
        if LIN_MODEL.stability==0 % || (max(abs(y))-abs(y(end)))>0
            fval = penaltyFval;
        end
        if any(isnan(fval)) || any(isinf(fval))
            fval = penaltyFval;
        end

    catch fitErr
        % Error - assign penalty (penaltyFval may not exist if error was early)
        fval = 1e6 * ones(gaMetadata.nObj, 1);
        % DEBUG: Log error to file (fprintf doesn't work in parfor workers)
        try
            fid = fopen('/tmp/ga_worker_errors.log', 'a');
            if fid > 0
                fprintf(fid, '[W%d] %s | %s\n', workerID, fitErr.message, fitErr.stack(1).name);
                fclose(fid);
            end
        catch
        end
    end

    %======================================================================
    % PERMANENT MONITORING - Real-time progress display (DO NOT REMOVE)
    %======================================================================
    % This fprintf provides user visibility into optimization progress.
    % Format: "VI | Gen X/Y | Ind Z/PopSize | WN | S=1 | fval=[...]"
    %
    % This is PERMANENT monitoring for production use, NOT debug code.
    %======================================================================
    stabStatus = (fval(1) < 1e5);  % S=1 means stable, S=0 means rejected
    fvalStr = sprintf('%.2e ', fval);
    modeTag = '';
    if strcmp(gaMetadata.fitnessMode, 'hybrid'),            modeTag = 'H|';  end
    if strcmp(gaMetadata.fitnessMode, 'linear_itae'),       modeTag = 'LI|'; end
    if strcmp(gaMetadata.fitnessMode, 'linear_itae_biobj'), modeTag = 'LB|'; end
    if workerID == 0
        % Sequential mode
        fprintf('%s | %sGen %d/%d | Ind %d/%d | SEQ | S=%d | fval=[%s]\n', ...
            optLabel, modeTag, currentGen, gaMetadata.maxNumGen, indInGen, gaMetadata.PopulationSize, ...
            stabStatus, strtrim(fvalStr));
    else
        % Parallel mode: workerID is already 1-based (1,2,3,4,...)
        fprintf('%s | %sGen %d/%d | Ind %d/%d | W%d | S=%d | fval=[%s]\n', ...
            optLabel, modeTag, currentGen, gaMetadata.maxNumGen, indInGen, gaMetadata.PopulationSize, ...
            workerID, stabStatus, strtrim(fvalStr));
    end

    % CRITICAL: Return to starting directory
    cd(startDir);
end

%--------------------------------------------------------------
%% HELPER FUNCTION: Compute Fitness Metrics
%--------------------------------------------------------------
function fval = compute_fitness_metrics(LIN_MODEL, ssModel, selectedDFIG, nDFIG, nCONTROL, input_type, gaMetadata, workerID)
% COMPUTE_FITNESS_METRICS - Calculate optimization objective function values
%
% INPUTS:
%   LIN_MODEL    - Linearized model structure with stability metrics
%   ssModel      - State-space model structure
%   selectedDFIG - Index of DFIG being optimized
%   nDFIG        - Total number of DFIGs in system
%   nCONTROL     - Number of control loops (7)
%   input_type   - Type of input: 'P' (active power) or 'Q' (reactive power)
%                  NOTE: In 'linear_itae' mode, BOTH perturbations are always
%                  evaluated (il_r + il_i steps) regardless of input_type.
%                  The parameter is only used by 'linear' and NL sim modes.
%   gaMetadata   - GA metadata with fitnessMode, nObj, pertScenarios_P/Q,
%                  scenarioAggregation ('worst_case'|'mean')
%   workerID     - Worker ID for parallel execution (0=sequential)
%
% OUTPUTS:
%   fval - nObj×1 vector of fitness values:
%     LINEAR mode (nObj=4):
%       [1] -minDamping(2): Negative of minimum damping ratio
%       [2] maxRealEig: Maximum real part of eigenvalues
%       [3] ROCOX: Rate of change (ROCOF for P, ROCOV for Q) from linear step
%       [4] nadir: Maximum deviation from final value (linear step)
%     HYBRID mode (nObj=5):
%       [1] -minDamping(2): From eigenvalue analysis (linear)
%       [2] maxRealEig: From eigenvalue analysis (linear)
%       [3] IAE/ITAE: Configurable cost metric (non-linear simulation)
%           P-axis uses costMetric_P, Q-axis uses costMetric_Q
%       [4] ROCOF/ROCOV: Rate of change (non-linear simulation)
%       [5] nadir deviation: |1 - nadir| (non-linear simulation)

    fitnessMode = gaMetadata.fitnessMode;
    nObj = gaMetadata.nObj;
    penaltyFval = 1e6 * ones(nObj, 1);

    % Check stability FIRST - skip everything if unstable
    if LIN_MODEL.stability == 0
        fval = penaltyFval;
        return;
    end

    % LINEAR STABILITY METRICS (common to both modes)
    % Use GLOBAL minimum damping (both fast and slow modes)
    % minDamping(1) = fast modes (converter), minDamping(2) = slow modes (VSM/grid)
    % BOTH must be monitored to prevent hidden instabilities (e.g., b > 1.02)
    obj_damping = -min(LIN_MODEL.minDamping);
    obj_maxRealEig = LIN_MODEL.maxRealEig;

    % === DISPATCH: ITAE modes use dedicated fitness functions ===
    if strcmp(fitnessMode, 'linear_itae')
        fval = compute_fitness_itae_mono(LIN_MODEL, ssModel, nDFIG, nCONTROL, gaMetadata, workerID);
        return;
    elseif strcmp(fitnessMode, 'linear_itae_biobj')
        fval = compute_fitness_itae_biobj(LIN_MODEL, ssModel, nDFIG, nCONTROL, gaMetadata, workerID);
        return;
    end

    % === Legacy ITAE code below (unreachable — kept as reference) ===
    if strcmp(fitnessMode, 'linear_itae') || strcmp(fitnessMode, 'linear_itae_biobj')
        %==================================================================
        % LINEAR ITAE / BIOBJ MODE
        %==================================================================
        % linear_itae: 8-channel mono-objective (J = mean of 4 grouped ITAEs)
        % linear_itae_biobj: 10-channel bi-objective (J1=regulation, J2=tracking)
        %
        % y_error(t) = y_step(t) - y_step(T) for all channels.
        % Eigenvalue constraints (SCR=1/2/3) as hard feasibility gates.
        %==================================================================

        % Pre-filter: reject unstable or poorly-damped designs
        if obj_damping > -0.01 || obj_maxRealEig > 0
            fprintf('  [DEBUG W%d] Pre-filter REJECT: damping=%.6f maxRealEig=%.6f\n', workerID, obj_damping, obj_maxRealEig);
            fval = penaltyFval;
            return;
        end

        % Multi-endpoint eigenvalue robustness check (SCR=1, SCR=3)
        if isfield(gaMetadata, 'robustnessOPs') && ~isempty(gaMetadata.robustnessOPs)
            for k_op = 1:length(gaMetadata.robustnessOPs)
                ropk = gaMetadata.robustnessOPs(k_op);
                if ropk.skip, continue; end
                if abs(ropk.SCR_grid - LIN_MODEL.MODEL.GRID.PARAM.SCR_grid) < 1e-6
                    LIN_CHECK = LIN_MODEL;
                else
                    LIN_CHECK = LIN_MODEL;
                    LIN_CHECK.MODEL.GRID.PARAM.SCR_grid = ropk.SCR_grid;
                    Ub_r  = LIN_CHECK.MODEL.BASE.Ub;
                    Sb_r  = LIN_CHECK.MODEL.GRID.BASE.Sb;
                    f0_r  = LIN_CHECK.MODEL.BASE.f0;
                    XR_r  = LIN_CHECK.MODEL.GRID.PARAM.XR_grid;
                    LIN_CHECK.MODEL.GRID.PARAM.Lg_H    = Ub_r^2 / Sb_r / (2*pi*f0_r) / ropk.SCR_grid;
                    LIN_CHECK.MODEL.GRID.PARAM.Rg_Ohm  = LIN_CHECK.MODEL.GRID.PARAM.Lg_H * (2*pi*f0_r) / XR_r;
                    LIN_CHECK.MODEL.GRID.PARAM.Lg_pu   = LIN_CHECK.MODEL.GRID.PARAM.Lg_H / LIN_CHECK.MODEL.BASE.Lb;
                    LIN_CHECK.MODEL.GRID.PARAM.Rg_pu   = LIN_CHECK.MODEL.GRID.PARAM.Rg_Ohm / LIN_CHECK.MODEL.BASE.Zb;
                    try
                        LIN_CHECK = LINEAR_ANALYSIS(LIN_CHECK, workerID);
                    catch ME_rob
                        fprintf('  [DEBUG W%d] SCR=%.1f LINEAR_ANALYSIS error: %s\n', workerID, ropk.SCR_grid, ME_rob.message);
                        fval = penaltyFval;
                        return;
                    end
                    if LIN_CHECK.stability == 0
                        fprintf('  [DEBUG W%d] SCR=%.1f UNSTABLE\n', workerID, ropk.SCR_grid);
                        fval = penaltyFval;
                        return;
                    end
                end
                eigenConfig_k = gaMetadata.eigenConfig;
                eigenConfig_k.min_real_pole_mag = max(ropk.baseline_min_real_pole_mag, ...
                                                      gaMetadata.eigenConfig.min_real_pole_mag);
                eigenConfig_k.min_damping_lf    = max(ropk.baseline_min_damping_lf, ...
                                                      gaMetadata.eigenConfig.min_damping);
                eigenConfig_k.min_damping_mf    = max(ropk.baseline_min_damping_mf, ...
                                                      gaMetadata.eigenConfig.min_damping);
                eigenConfig_k.min_damping_hf    = max(ropk.baseline_min_damping_hf, ...
                                                      gaMetadata.eigenConfig.min_damping);
                [eig_valid_k, cinfo_k] = check_eigenvalue_constraints(LIN_CHECK, eigenConfig_k);
                if ~eig_valid_k
                    fprintf('  [DEBUG W%d] SCR=%.1f eig FAIL: %s (thresh: re=%.6f dLF=%.6f dMF=%.6f dHF=%.6f)\n', ...
                        workerID, ropk.SCR_grid, cinfo_k.violation_reason, ...
                        eigenConfig_k.min_real_pole_mag, eigenConfig_k.min_damping_lf, ...
                        eigenConfig_k.min_damping_mf, eigenConfig_k.min_damping_hf);
                    fval = penaltyFval;
                    return;
                end
            end
        end

        % STEP TRANSIENT ITAE — shared index computation
        nLINE = LIN_MODEL.MODEL.LINE.PARAM.nLINE;
        selectedDFIG_k = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;

        % Input indices — perturbation (load current at PCC)
        indI_Pl = nCONTROL*nDFIG + 2*nDFIG + nLINE;       % il_r
        indI_Ql = nCONTROL*nDFIG + 2*nDFIG + nLINE + 1;   % il_i
        % Input indices — reference (P_ref, Q_ref of selected DFIG)
        indI_Pr = nCONTROL*nDFIG + selectedDFIG_k;          % P_ref
        indI_Qr = nCONTROL*nDFIG + nDFIG + selectedDFIG_k;  % Q_ref
        % Output indices — grid signals
        indO_f  = 2*nCONTROL*nDFIG + 1;  % Frequency
        indO_v  = 2*nCONTROL*nDFIG + 2;  % Voltage
        % Output indices — dfigAuxSignals (from gaMetadata, computed at baseline)
        indO_P   = gaMetadata.indO_P;     % P_actual(selected)
        indO_Q   = gaMetadata.indO_Q;     % Q_actual(selected)
        indO_Vdc = gaMetadata.indO_Vdc;   % Vdc(selected)

        % Build SISO transfer functions
        matA = ssModel.a;
        matB = ssModel.b;
        matC = ssModel.c;
        matD = ssModel.d;

        % 8 shared SISO systems (load perturbation + tracking + Vdc)
        Fss_f_Pl = ss(matA, matB(:,indI_Pl), matC(indO_f,:), matD(indO_f,indI_Pl));
        Fss_f_Ql = ss(matA, matB(:,indI_Ql), matC(indO_f,:), matD(indO_f,indI_Ql));
        Fss_v_Pl = ss(matA, matB(:,indI_Pl), matC(indO_v,:), matD(indO_v,indI_Pl));
        Fss_v_Ql = ss(matA, matB(:,indI_Ql), matC(indO_v,:), matD(indO_v,indI_Ql));
        Fss_P_Pr = ss(matA, matB(:,indI_Pr), matC(indO_P,:), matD(indO_P,indI_Pr));
        Fss_Q_Qr = ss(matA, matB(:,indI_Qr), matC(indO_Q,:), matD(indO_Q,indI_Qr));
        Fss_Vdc_Pl = ss(matA, matB(:,indI_Pl), matC(indO_Vdc,:), matD(indO_Vdc,indI_Pl));
        Fss_Vdc_Pr = ss(matA, matB(:,indI_Pr), matC(indO_Vdc,:), matD(indO_Vdc,indI_Pr));

        % Simulation parameters
        T_sim = gaMetadata.itae_sim_duration;
        N_pts = gaMetadata.itae_npoints;
        t   = linspace(0, T_sim, N_pts)';
        dt  = t(2) - t(1);

        % Step responses (8 channels)
        ys_f_Pl = step(Fss_f_Pl, t);  ys_f_Ql = step(Fss_f_Ql, t);
        ys_v_Pl = step(Fss_v_Pl, t);  ys_v_Ql = step(Fss_v_Ql, t);
        ys_P_Pr = step(Fss_P_Pr, t);  ys_Q_Qr = step(Fss_Q_Qr, t);
        ys_Vdc_Pl = step(Fss_Vdc_Pl, t);  ys_Vdc_Pr = step(Fss_Vdc_Pr, t);

        % Transient errors: y(t) - y(T) — pure transient metric
        ye_f_Pl = ys_f_Pl - ys_f_Pl(end);  ye_f_Ql = ys_f_Ql - ys_f_Ql(end);
        ye_v_Pl = ys_v_Pl - ys_v_Pl(end);  ye_v_Ql = ys_v_Ql - ys_v_Ql(end);
        ye_P_Pr = ys_P_Pr - ys_P_Pr(end);  ye_Q_Qr = ys_Q_Qr - ys_Q_Qr(end);
        ye_Vdc_Pl = ys_Vdc_Pl - ys_Vdc_Pl(end);  ye_Vdc_Pr = ys_Vdc_Pr - ys_Vdc_Pr(end);

        if strcmp(fitnessMode, 'linear_itae')
            % v10 MONO-OBJECTIVE: 4 grouped ITAEs
            ITAE_f_pert = sum(t .* abs(ye_f_Pl)) * dt + sum(t .* abs(ye_f_Ql)) * dt;
            ITAE_v_pert = sum(t .* abs(ye_v_Pl)) * dt + sum(t .* abs(ye_v_Ql)) * dt;
            ITAE_track  = sum(t .* abs(ye_P_Pr)) * dt + sum(t .* abs(ye_Q_Qr)) * dt;
            ITAE_vdc    = sum(t .* abs(ye_Vdc_Pl)) * dt + sum(t .* abs(ye_Vdc_Pr)) * dt;

            J = (ITAE_f_pert / gaMetadata.itae0_f_pert + ITAE_v_pert / gaMetadata.itae0_v_pert ...
               + ITAE_track  / gaMetadata.itae0_track  + ITAE_vdc    / gaMetadata.itae0_vdc) / 4;
            fval = J;
            if fval > 1e4 || isnan(fval) || isinf(fval)
                fval = penaltyFval;
            end

        else  % linear_itae_biobj
            % v6 BI-OBJECTIVE: J1=regulation (6 ch), J2=tracking (2 ch), Vdc constraint
            % Wind channels (2 additional SISO systems)
            indI_vw = gaMetadata.indI_vw;
            Fss_f_vw = ss(matA, matB(:,indI_vw), matC(indO_f,:), matD(indO_f,indI_vw));
            Fss_v_vw = ss(matA, matB(:,indI_vw), matC(indO_v,:), matD(indO_v,indI_vw));
            ys_f_vw = step(Fss_f_vw, t);  ys_v_vw = step(Fss_v_vw, t);
            ye_f_vw = ys_f_vw - ys_f_vw(end);  ye_v_vw = ys_v_vw - ys_v_vw(end);

            % Per-channel ITAEs (10 channels)
            itae_f_Pl = sum(t .* abs(ye_f_Pl)) * dt;
            itae_f_Ql = sum(t .* abs(ye_f_Ql)) * dt;
            itae_v_Pl = sum(t .* abs(ye_v_Pl)) * dt;
            itae_v_Ql = sum(t .* abs(ye_v_Ql)) * dt;
            itae_f_vw = sum(t .* abs(ye_f_vw)) * dt;
            itae_v_vw = sum(t .* abs(ye_v_vw)) * dt;
            itae_P_Pr = sum(t .* abs(ye_P_Pr)) * dt;
            itae_Q_Qr = sum(t .* abs(ye_Q_Qr)) * dt;

            % J1 = mean of 6 normalized regulation ITAEs
            J1 = ( itae_f_Pl / gaMetadata.itae0_f_Pl ...
                 + itae_f_Ql / gaMetadata.itae0_f_Ql ...
                 + itae_v_Pl / gaMetadata.itae0_v_Pl ...
                 + itae_v_Ql / gaMetadata.itae0_v_Ql ...
                 + itae_f_vw / gaMetadata.itae0_f_vw ...
                 + itae_v_vw / gaMetadata.itae0_v_vw ) / 6;

            % J2 = mean of 2 normalized tracking ITAEs
            J2 = ( itae_P_Pr / gaMetadata.itae0_P_Pr ...
                 + itae_Q_Qr / gaMetadata.itae0_Q_Qr ) / 2;

            % Vdc peak constraint: penalize if WORSE than baseline
            vdc_peak_Pl = max(abs(ys_Vdc_Pl));
            vdc_peak_Pr = max(abs(ys_Vdc_Pr));
            vdc_excess = max(vdc_peak_Pl / gaMetadata.vdc_peak_Pl_baseline, ...
                             vdc_peak_Pr / gaMetadata.vdc_peak_Pr_baseline);
            if vdc_excess > 1.0
                vdc_penalty = 1 + 100 * (vdc_excess - 1.0);
                J1 = J1 * vdc_penalty;
                J2 = J2 * vdc_penalty;
            end

            fval = [J1, J2];
            if any(fval > 1e4) || any(isnan(fval)) || any(isinf(fval))
                fval = penaltyFval';
            end
        end

    elseif strcmp(fitnessMode, 'linear')
        %==================================================================
        % LINEAR MODE (original behavior, 4 objectives)
        %==================================================================
        matA = ssModel.a;
        matB = ssModel.b;
        matC = ssModel.c;
        matD = ssModel.d;

        t = linspace(0,5,500);

        if strcmp(input_type, 'P')
            indI = nCONTROL*nDFIG + selectedDFIG;
            indO = 2*nCONTROL*nDFIG + 1;
        else % 'Q'
            indI = nCONTROL*nDFIG + nDFIG + selectedDFIG;
            indO = 2*nCONTROL*nDFIG + 2;
        end

        Fss = ss(matA, matB(:,indI), matC(indO,:), matD(indO,indI));
        y = step(Fss, t);

        [~,ind] = min(abs(y - y(end)/2));
        ROCOX = y(ind) / t(ind);
        nadir = max(abs(y));

        fval = [obj_damping; obj_maxRealEig; abs(ROCOX); abs(nadir)];

        if any(fval > 10)
            fval = penaltyFval;
        end

    else
        %==================================================================
        % HYBRID MODE (linear stability + non-linear dynamics, 5 objectives)
        %==================================================================
        % Pre-filter: reject clearly marginal designs without expensive sim
        if obj_damping > -0.01 || obj_maxRealEig > 0
            fval = penaltyFval;
            return;
        end

        % Multi-endpoint eigenvalue robustness check
        % Evaluates at all robustness OPs (weak + strong grid).
        % Thresholds = max(baseline, generic) → candidate CANNOT degrade baseline.
        if isfield(gaMetadata, 'robustnessOPs') && ~isempty(gaMetadata.robustnessOPs)
            for k_op = 1:length(gaMetadata.robustnessOPs)
                ropk = gaMetadata.robustnessOPs(k_op);

                % Skip OPs marked as invalid (e.g., baseline unstable)
                if ropk.skip, continue; end

                if abs(ropk.SCR_grid - LIN_MODEL.MODEL.GRID.PARAM.SCR_grid) < 1e-6
                    % Current OP — use existing LIN_MODEL eigenvalues
                    LIN_CHECK = LIN_MODEL;
                else
                    % Different SCR — temporary re-linearization
                    LIN_CHECK = LIN_MODEL;
                    LIN_CHECK.MODEL.GRID.PARAM.SCR_grid = ropk.SCR_grid;
                    % Inline grid impedance update
                    Ub_r  = LIN_CHECK.MODEL.BASE.Ub;
                    Sb_r  = LIN_CHECK.MODEL.GRID.BASE.Sb;
                    f0_r  = LIN_CHECK.MODEL.BASE.f0;
                    XR_r  = LIN_CHECK.MODEL.GRID.PARAM.XR_grid;
                    LIN_CHECK.MODEL.GRID.PARAM.Lg_H    = Ub_r^2 / Sb_r / (2*pi*f0_r) / ropk.SCR_grid;
                    LIN_CHECK.MODEL.GRID.PARAM.Rg_Ohm  = LIN_CHECK.MODEL.GRID.PARAM.Lg_H * (2*pi*f0_r) / XR_r;
                    LIN_CHECK.MODEL.GRID.PARAM.Lg_pu   = LIN_CHECK.MODEL.GRID.PARAM.Lg_H / LIN_CHECK.MODEL.BASE.Lb;
                    LIN_CHECK.MODEL.GRID.PARAM.Rg_pu   = LIN_CHECK.MODEL.GRID.PARAM.Rg_Ohm / LIN_CHECK.MODEL.BASE.Zb;
                    % Re-linearize (pwd should be CONFIGURATION from fitnessFcn)
                    try
                        LIN_CHECK = LINEAR_ANALYSIS(LIN_CHECK, workerID);
                    catch
                        fval = penaltyFval;
                        return;
                    end
                    if LIN_CHECK.stability == 0
                        fval = penaltyFval;
                        return;
                    end
                end

                % Check eigenvalues against max(baseline, generic) thresholds
                eigenConfig_k = gaMetadata.eigenConfig;
                eigenConfig_k.min_real_pole_mag = max(ropk.baseline_min_real_pole_mag, ...
                                                      gaMetadata.eigenConfig.min_real_pole_mag);
                eigenConfig_k.min_damping       = max(ropk.baseline_min_damping, ...
                                                      gaMetadata.eigenConfig.min_damping);

                [eig_valid_k, ~] = check_eigenvalue_constraints(LIN_CHECK, eigenConfig_k);
                if ~eig_valid_k
                    fval = penaltyFval;
                    return;
                end
            end
        end

        % Select perturbation scenarios and cost metric based on input_type
        if strcmp(input_type, 'P')
            scenarios = gaMetadata.pertScenarios_P;
            costMetric = gaMetadata.costMetric_P;  % 'IAE' or 'ITAE'
        else % 'Q'
            scenarios = gaMetadata.pertScenarios_Q;
            costMetric = gaMetadata.costMetric_Q;  % 'IAE' or 'ITAE'
        end

        % Evaluate all scenarios and collect metrics
        nScen = length(scenarios);
        all_cost  = zeros(nScen, 1);
        all_ROC   = zeros(nScen, 1);
        all_nadir = zeros(nScen, 1);
        all_ok    = true;

        for sc = 1:nScen
            pertType   = scenarios{sc}.pertType;
            pertConfig = scenarios{sc}.pertConfig;

            try
                results = RUN_PERTURBATION_SIM(LIN_MODEL, pertType, pertConfig, workerID);
                metrics = COMPUTE_PERTURBATION_METRICS(results, pertType, pertConfig);
            catch
                all_ok = false;
                break;
            end

            if ~metrics.success
                all_ok = false;
                break;
            end

            % Extract relevant metrics based on input type and cost metric
            if strcmp(input_type, 'P')
                if strcmp(costMetric, 'ITAE')
                    all_cost(sc) = metrics.ITAE_f;
                else
                    all_cost(sc) = metrics.IAE_f;
                end
                all_ROC(sc)   = metrics.ROCOF;
                all_nadir(sc) = abs(1 - metrics.nadir_f);

                % Hard constraints on ROCOF and nadir_f
                if isfield(gaMetadata, 'pertConstraints') && gaMetadata.pertConstraints.enabled
                    pc = gaMetadata.pertConstraints;
                    if metrics.ROCOF > pc.max_ROCOF || metrics.nadir_f < pc.min_nadir_f
                        all_ok = false;
                        break;
                    end
                end
            else % 'Q'
                if strcmp(costMetric, 'ITAE')
                    all_cost(sc) = metrics.ITAE_V;
                else
                    all_cost(sc) = metrics.IAE_V;
                end
                all_ROC(sc)   = metrics.ROCOV;
                all_nadir(sc) = abs(1 - metrics.nadir_V);

                % Hard constraints on ROCOV and nadir_V
                if isfield(gaMetadata, 'pertConstraints') && gaMetadata.pertConstraints.enabled
                    pc = gaMetadata.pertConstraints;
                    if metrics.ROCOV > pc.max_ROCOV || metrics.nadir_V < pc.min_nadir_V
                        all_ok = false;
                        break;
                    end
                end
            end
        end

        if ~all_ok
            fval = penaltyFval;
            return;
        end

        % Aggregate metrics across scenarios
        if strcmp(gaMetadata.scenarioAggregation, 'worst_case')
            obj_cost  = max(all_cost);
            obj_ROC   = max(all_ROC);
            obj_nadir = max(all_nadir);
        else % 'mean'
            obj_cost  = mean(all_cost);
            obj_ROC   = mean(all_ROC);
            obj_nadir = mean(all_nadir);
        end

        fval = [obj_damping; obj_maxRealEig; obj_cost; abs(obj_ROC); obj_nadir];

        if any(fval > 10)
            fval = penaltyFval;
        end
    end
end

%--------------------------------------------------------------
%% LOCAL OUTPUT FUNCTION - GUARANTEED EXECUTION ONCE PER GENERATION
%--------------------------------------------------------------
% *** PERMANENT MONITORING COMPONENT - DO NOT REMOVE ***
% This function is part of the permanent progress tracking system.
%--------------------------------------------------------------
function [state, options, optchanged] = gaOutputFcn_local(options, state, flag, progressFile, gaLogFile, gaStartTic, fitnessMode)
% GAOUTPUTFCN_LOCAL - Output function called by gamultiobj after each generation
%
% PERMANENT MONITORING COMPONENT (DO NOT REMOVE)
%
% This function is GUARANTEED by MATLAB to execute exactly once per generation
% in the main thread (not in parallel workers). It updates the progress file
% that fitnessFcn reads to display correct generation numbers, AND writes
% detailed per-generation statistics to the GA log file.
%
% INPUTS:
%   options      - GA options structure
%   state        - Current GA state (contains Generation, Score, Rank, etc.)
%   flag         - Execution flag: 'init', 'iter', 'interrupt', 'done'
%   progressFile - Path to progress file (written here, read by fitnessFcn)
%   gaLogFile    - Path to detailed GA log file (TXT)
%   gaStartTic   - tic value from optimization start (for elapsed time)
%   fitnessMode  - 'linear_itae' | 'linear' | 'hybrid'
%
% OUTPUTS:
%   state        - Possibly modified state (not modified here)
%   options      - Possibly modified options (not modified here)
%   optchanged   - Always false (no option changes)

    optchanged = false;

    switch flag
        case 'init'
            % Initialization - reset counters
            currentGen = 1;  % Start at generation 1
            totalIndEvaluated = 0;
            save(progressFile, 'currentGen', 'totalIndEvaluated');

        case 'iter'
            % After each generation completes
            currentGen = state.Generation;

            % Count how many individuals were evaluated this generation
            if isfield(state, 'Score') && ~isempty(state.Score)
                nEvaluated = size(state.Score, 1);
            else
                nEvaluated = options.PopulationSize;
            end

            % Update total count
            try
                data = load(progressFile);
                totalIndEvaluated = data.totalIndEvaluated + nEvaluated;
            catch
                % First iteration or file error
                totalIndEvaluated = nEvaluated;
            end

            % Write updated values ATOMICALLY
            save(progressFile, 'currentGen', 'totalIndEvaluated');

            % ============================================================
            % DETAILED GENERATION LOG (written to gaLogFile)
            % ============================================================
            try
                elapsed = toc(gaStartTic);
                elapsed_str = sprintf('%02d:%02d:%02d', ...
                    floor(elapsed/3600), floor(mod(elapsed,3600)/60), floor(mod(elapsed,60)));

                % Extract scores
                scores = state.Score;  % (PopSize × nObj)
                popSize = size(scores, 1);

                if ~strcmp(fitnessMode, 'linear_itae')
                    % Multi-objective: extract Pareto front (Rank 1 individuals)
                    if isfield(state, 'Rank')
                        paretoMask = (state.Rank == 1);
                    else
                        paretoMask = true(popSize, 1);
                    end
                    nPareto = sum(paretoMask);
                    paretoScores = scores(paretoMask, :);

                    if nPareto > 1
                        spreads = max(paretoScores) - min(paretoScores);
                        spreadVal = norm(spreads);
                        if isfield(state, 'Distance')
                            avgDist = mean(state.Distance(paretoMask));
                        else
                            avgDist = NaN;
                        end
                    else
                        spreadVal = 0;
                        avgDist = 0;
                    end
                end

                % Build log line based on fitness mode
                fid = fopen(gaLogFile, 'a');
                if fid > 0
                    if strcmp(fitnessMode, 'linear_itae')
                        % Mono-objective mode: J = (ITAE_f/ITAE_f0 + ITAE_v/ITAE_v0)/2
                        valid = scores(:,1) < 1e5;
                        nValid = sum(valid);
                        if nValid > 0
                            validScores = scores(valid,1);
                            fprintf(fid, '%-6d | J_min=%-12.6f | J_mean=%-12.6f | J_best=%-12.6f | Valid: %-3d/%-4d | %s\n', ...
                                currentGen, min(validScores), mean(validScores), ...
                                min(validScores), nValid, popSize, elapsed_str);
                        else
                            fprintf(fid, '%-6d | ALL PENALIZED | Valid: 0/%-4d | %s\n', ...
                                currentGen, popSize, elapsed_str);
                        end
                    else
                        % Generic mode: log all objectives min/mean
                        nObj = size(scores, 2);
                        objStr = '';
                        for oi = 1:nObj
                            objStr = [objStr, sprintf('O%d:[%.3e/%.3e] ', oi, min(scores(:,oi)), mean(scores(:,oi)))];
                        end
                        fprintf(fid, 'Gen %-4d | %s | Pareto: %d/%d | Valid: %d/%d | %s\n', ...
                            currentGen, objStr, nPareto, popSize, sum(scores(:,1)<1e5), popSize, elapsed_str);
                    end
                    fclose(fid);
                end

                % Also print summary to console (captured by diary)
                if strcmp(fitnessMode, 'linear_itae') && exist('validScores', 'var') && ~isempty(validScores)
                    fprintf('\n>>> Gen %d/%d | J_best=%.6f | J_mean=%.6f | Valid: %d/%d | %s\n', ...
                        currentGen, options.MaxGenerations, min(validScores), mean(validScores), ...
                        nValid, popSize, elapsed_str);
                else
                    fprintf('\n>>> Gen %d/%d | Pareto: %d | %s\n', ...
                        currentGen, options.MaxGenerations, nPareto, elapsed_str);
                end
            catch logErr
                % Logging failure should NEVER stop optimization
                try
                    fid = fopen(gaLogFile, 'a');
                    if fid > 0
                        fprintf(fid, 'Gen %-4d | LOG ERROR: %s\n', currentGen, logErr.message);
                        fclose(fid);
                    end
                catch
                end
            end

        case {'interrupt', 'done'}
            % Write final summary to log
            try
                elapsed = toc(gaStartTic);
                elapsed_str = sprintf('%02d:%02d:%02d', ...
                    floor(elapsed/3600), floor(mod(elapsed,3600)/60), floor(mod(elapsed,60)));
                fid = fopen(gaLogFile, 'a');
                if fid > 0
                    fprintf(fid, '=========================================================================\n');
                    fprintf(fid, 'Optimization %s at %s | Total elapsed: %s\n', ...
                        flag, datestr(now, 'yyyy-mm-dd HH:MM:SS'), elapsed_str);

                    if isfield(state, 'Score')
                        scores = state.Score;
                        if strcmp(fitnessMode, 'linear_itae')
                            % Mono-objective: report best J
                            validJ = scores(scores(:,1) < 1e5, 1);
                            if ~isempty(validJ)
                                fprintf(fid, 'Final J_best=%.6f  J_mean=%.6f  Valid: %d/%d\n', ...
                                    min(validJ), mean(validJ), length(validJ), size(scores,1));
                            end
                        elseif isfield(state, 'Rank')
                            paretoMask = (state.Rank == 1);
                            paretoScores = scores(paretoMask, :);
                            validPareto = paretoScores(paretoScores(:,1) < 1e5, :);
                            fprintf(fid, 'Final Pareto size: %d (valid: %d)\n', sum(paretoMask), size(validPareto,1));
                            if ~isempty(validPareto)
                                for oi = 1:size(validPareto, 2)
                                    fprintf(fid, '  Obj %d: min=%.6e  max=%.6e  mean=%.6e\n', ...
                                        oi, min(validPareto(:,oi)), max(validPareto(:,oi)), mean(validPareto(:,oi)));
                                end
                            end
                        end
                    end
                    fprintf(fid, '=========================================================================\n');
                    fclose(fid);
                end
            catch
            end
    end
end

%--------------------------------------------------------------
%% LOCAL FUNCTION - CHECK EIGENVALUE CONSTRAINTS
%--------------------------------------------------------------
function [is_valid, constraint_info] = check_eigenvalue_constraints(LIN_MODEL, eigenConfig)
% CHECK_EIGENVALUE_CONSTRAINTS - Validate eigenvalue-based design constraints
%
% 3-band damping check:
%   LF (|Im| ≤ mf_freq_thresh): grid/slow modes (~17 rad/s) — baseline ~0.029
%   MF (mf_freq_thresh < |Im| ≤ hf_freq_thresh): VSMP modes (~314 rad/s) — baseline ~0.096
%   HF (hf_freq_thresh < |Im| ≤ spurious_freq_thresh): current loops (~1400 rad/s) — baseline ~0.47
%   Spurious (|Im| > spurious_freq_thresh): PCC parasitic (~40000 rad/s) — excluded
%
% INPUTS:
%   LIN_MODEL   - Linearized model with .eigenvalues field
%   eigenConfig - Struct with constraint thresholds:
%     .min_real_pole_mag      min |Re(z)| for real poles (reject slow modes)
%     .min_damping_lf         min damping for LF complex poles (|Im| ≤ mf_freq_thresh)
%     .min_damping_mf         min damping for MF complex poles (mf < |Im| ≤ hf)
%     .min_damping_hf         min damping for HF complex poles (hf < |Im| ≤ spurious)
%     .mf_freq_thresh         [rad/s] boundary between LF and MF bands
%     .hf_freq_thresh         [rad/s] boundary between MF and HF bands
%     .spurious_freq_thresh   [rad/s] complex poles above this are parasitic
%     .enabled                boolean, if false always returns valid
%
% OUTPUTS:
%   is_valid        - true if all constraints satisfied
%   constraint_info - Struct with:
%     .min_real_pole_found    actual min |Re(z)| of real poles
%     .min_damping_found      actual min damping of all non-spurious complex poles
%     .min_damping_lf_found   actual min damping in LF band
%     .min_damping_mf_found   actual min damping in MF band
%     .min_damping_hf_found   actual min damping in HF band
%     .n_spurious_excluded    number of spurious poles excluded
%     .violation_reason       string describing why constraint failed ('' if ok)

    constraint_info = struct();
    constraint_info.min_real_pole_found = Inf;
    constraint_info.min_damping_found = Inf;
    constraint_info.n_spurious_excluded = 0;
    constraint_info.violation_reason = '';

    % Skip if disabled
    if ~eigenConfig.enabled
        is_valid = true;
        return;
    end

    z = LIN_MODEL.eigenvalues;
    [~, Damping] = damp(z);

    % Separate real poles (|Damping| == 1) and complex poles (|Damping| < 1)
    is_real = abs(Damping) == 1;
    is_complex = ~is_real;

    % --- Real pole constraint: min |Re(z)| >= min_real_pole_mag ---
    real_poles = z(is_real);
    if ~isempty(real_poles)
        min_re = min(abs(real(real_poles)));
        constraint_info.min_real_pole_found = min_re;
        if min_re < eigenConfig.min_real_pole_mag
            is_valid = false;
            constraint_info.violation_reason = sprintf( ...
                'Real pole too slow: |Re(z)|=%.4f < threshold %.4f', ...
                min_re, eigenConfig.min_real_pole_mag);
            return;
        end
    end

    % --- Complex pole constraint: 3-band damping check ---
    % LF band (|Im| ≤ mf_freq_thresh): slow grid modes (~17 rad/s, ζ~0.029)
    % MF band (mf < |Im| ≤ hf_freq_thresh): VSMP modes (~314 rad/s, ζ~0.096)
    % HF band (hf < |Im| ≤ spurious_freq_thresh): current loops (~1400 rad/s, ζ~0.47)
    % Spurious (|Im| > spurious_freq_thresh): PCC parasitic (~40000 rad/s) — excluded
    complex_poles = z(is_complex);
    complex_damping = Damping(is_complex);

    if ~isempty(complex_poles)
        freq = abs(imag(complex_poles));
        is_spurious = freq > eigenConfig.spurious_freq_thresh;
        constraint_info.n_spurious_excluded = sum(is_spurious);

        mf_thresh = eigenConfig.mf_freq_thresh;
        hf_thresh = eigenConfig.hf_freq_thresh;

        % LF band check (|Im| ≤ mf_freq_thresh)
        is_lf = freq <= mf_thresh & ~is_spurious;
        lf_damping = complex_damping(is_lf);
        if ~isempty(lf_damping)
            min_d_lf = min(lf_damping);
            constraint_info.min_damping_lf_found = min_d_lf;
            thresh_lf = eigenConfig.min_damping_lf;
            if min_d_lf < thresh_lf
                is_valid = false;
                constraint_info.violation_reason = sprintf( ...
                    'LF pole poorly damped: damping=%.4f < threshold %.4f (|Im|<=%.0f)', ...
                    min_d_lf, thresh_lf, mf_thresh);
                return;
            end
        end

        % MF band check (mf_freq_thresh < |Im| ≤ hf_freq_thresh)
        is_mf = freq > mf_thresh & freq <= hf_thresh & ~is_spurious;
        mf_damping = complex_damping(is_mf);
        if ~isempty(mf_damping)
            min_d_mf = min(mf_damping);
            constraint_info.min_damping_mf_found = min_d_mf;
            thresh_mf = eigenConfig.min_damping_mf;
            if min_d_mf < thresh_mf
                is_valid = false;
                constraint_info.violation_reason = sprintf( ...
                    'MF pole poorly damped: damping=%.4f < threshold %.4f (%.0f<|Im|<=%.0f)', ...
                    min_d_mf, thresh_mf, mf_thresh, hf_thresh);
                return;
            end
        end

        % HF band check (hf_freq_thresh < |Im| ≤ spurious_freq_thresh)
        is_hf = freq > hf_thresh & ~is_spurious;
        hf_damping = complex_damping(is_hf);
        if ~isempty(hf_damping)
            min_d_hf = min(hf_damping);
            constraint_info.min_damping_hf_found = min_d_hf;
            thresh_hf = eigenConfig.min_damping_hf;
            if min_d_hf < thresh_hf
                is_valid = false;
                constraint_info.violation_reason = sprintf( ...
                    'HF pole poorly damped: damping=%.4f < threshold %.4f (|Im|>%.0f)', ...
                    min_d_hf, thresh_hf, hf_thresh);
                return;
            end
        end

        % Global min for info
        all_filtered = complex_damping(~is_spurious);
        if ~isempty(all_filtered)
            constraint_info.min_damping_found = min(all_filtered);
        end
    end

    is_valid = true;
end

%--------------------------------------------------------------
%% LOCAL FUNCTION - DISPLAY OPTIMIZATION SUMMARY
%--------------------------------------------------------------
% *** PERMANENT MONITORING COMPONENT - DO NOT REMOVE ***
% This function provides detailed summary after optimization completes.
%--------------------------------------------------------------
function display_optimization_summary(optType, param_opt, fval_opt, scale, LIN_MODEL, N, fitnessMode)
% DISPLAY_OPTIMIZATION_SUMMARY - Print detailed optimization results
%
% PERMANENT MONITORING COMPONENT (DO NOT REMOVE)
%
% Displays a comprehensive summary of the optimization results including:
% - Optimization phase identification
% - Best individual parameters (in physical units)
% - Performance metrics (objectives)
% - System stability information
% - Pareto front size

    optLabels = {'PDS (P-axis Design Specs)', 'QDS (Q-axis Design Specs)', ...
                 'PCP (P-axis Control Params)', 'QCP (Q-axis Control Params)', ...
                 'VI (Virtual Impedance)'};

    fprintf('\n');
    fprintf('════════════════════════════════════════════════════════════════════════════\n');
    fprintf('  OPTIMIZATION COMPLETE: %s\n', optLabels{optType});
    fprintf('════════════════════════════════════════════════════════════════════════════\n\n');

    % Best individual (first in sorted list)
    best_param_scaled = param_opt(1,:) .* scale;
    best_fval = fval_opt(1,:);

    fprintf('BEST SOLUTION (Ranked by maximum damping ratio):\n');
    fprintf('────────────────────────────────────────────────────────────────────────────\n\n');

    % Display parameters based on optimization type
    switch optType
        case 1  % PDS - P-axis Design Specs
            fprintf('  FREQUENCY-RESPONSE DESIGN SPECIFICATIONS (P-axis):\n\n');
            fprintf('    VSMP (Virtual Synchronous Machine - Active Power):\n');
            fprintf('      Phase Margin (Fm):       %6.2f°\n', best_param_scaled(1));
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(2));

            fprintf('    RSCq (Rotor Side Converter - q-axis):\n');
            fprintf('      Phase Margin (Fm):       %6.2f°\n', best_param_scaled(3));
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(4));

            fprintf('    VDC (DC-Link Voltage Control):\n');
            fprintf('      Phase Margin (Fm):       %6.2f°\n', best_param_scaled(5));
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(6));

            fprintf('    GSCq (Grid Side Converter - q-axis):\n');
            fprintf('      Phase Margin (Fm):       %6.2f°\n', best_param_scaled(7));
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(8));

        case 2  % QDS - Q-axis Design Specs (params 9-13)
            fprintf('  FREQUENCY-RESPONSE DESIGN SPECIFICATIONS (Q-axis):\n\n');
            fprintf('    VSMQ (Virtual Synchronous Machine - Reactive Power):\n');
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(9));

            fprintf('    RSCd (Rotor Side Converter - d-axis):\n');
            fprintf('      Phase Margin (Fm):       %6.2f°\n', best_param_scaled(10));
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(11));

            fprintf('    GSCd (Grid Side Converter - d-axis):\n');
            fprintf('      Phase Margin (Fm):       %6.2f°\n', best_param_scaled(12));
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(13));

        case 3  % PCP - P-axis Control Params (params 14-17)
            fprintf('  CONTROL PARAMETERS (P-axis):\n\n');
            fprintf('    VSMP:\n');
            fprintf('      der2error (2-DOF):       %6.3f\n\n', best_param_scaled(14));

            fprintf('    RSCq:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(15));

            fprintf('    VDC:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(16));

            fprintf('    GSCq:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(17));

        case 4  % QCP - Q-axis Control Params (params 18-19)
            fprintf('  CONTROL PARAMETERS (Q-axis):\n\n');
            fprintf('    RSCd:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(18));

            fprintf('    GSCd:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(19));

        case 5  % VI - Virtual Impedance (param 20; R_v fixed at 0)
            fprintf('  VIRTUAL IMPEDANCE PARAMETERS:\n\n');
            fprintf('    Lv (Virtual Inductance):   %6.4f pu\n\n', best_param_scaled(20));
    end

    % Performance metrics (objectives)
    fprintf('  PERFORMANCE METRICS [%s mode]:\n\n', fitnessMode);
    if strcmp(fitnessMode, 'linear_itae')
        fprintf('    J = mean(4 normalized ITAEs) = %.6f\n', best_fval(1));
        fprintf('    (Baseline J = 1.0 by construction)\n\n');
    elseif strcmp(fitnessMode, 'linear_itae_biobj')
        fprintf('    J1 (Regulation) = %.6f  (mean of 6 normalized ITAEs: 4 load + 2 wind)\n', best_fval(1));
        fprintf('    J2 (Tracking)   = %.6f  (mean of 2 normalized ITAEs: P_ref→P, Q_ref→Q)\n', best_fval(2));
        fprintf('    (Baseline J1=J2=1.0 by construction)\n\n');
    elseif strcmp(fitnessMode, 'hybrid')
        fprintf('    Objective 1 (-minDamping):   %.4e  →  minDamping = %.4f\n', best_fval(1), -best_fval(1));
        fprintf('    Objective 2 (maxRealEig):    %.4e\n', best_fval(2));
        fprintf('    Objective 3 (IAE/ITAE):      %.4e  [non-linear]\n', best_fval(3));
        fprintf('    Objective 4 (ROCOF/ROCOV):   %.4e  [non-linear]\n', best_fval(4));
        fprintf('    Objective 5 (Nadir dev):     %.4e  [non-linear]\n\n', best_fval(5));
    else
        fprintf('    Objective 1 (-minDamping):   %.4e  →  minDamping = %.4f\n', best_fval(1), -best_fval(1));
        fprintf('    Objective 2 (maxRealEig):    %.4e\n', best_fval(2));
        fprintf('    Objective 3 (ROCOF/ROCOV):   %.4e\n', best_fval(3));
        fprintf('    Objective 4 (Nadir):         %.4e\n\n', best_fval(4));
    end

    % System stability
    fprintf('  SYSTEM STABILITY:\n\n');
    if LIN_MODEL.stability == 1
        fprintf('    Status:                      ✓ STABLE\n');
        fprintf('    Minimum Damping Ratio:       %.4f (fast: %.4f, slow: %.4f)\n', ...
            min(LIN_MODEL.minDamping), LIN_MODEL.minDamping(1), LIN_MODEL.minDamping(2));
        fprintf('    Maximum Real Eigenvalue:     %.4e\n', LIN_MODEL.maxRealEig);
    else
        fprintf('    Status:                      ✗ UNSTABLE\n');
    end
    fprintf('\n');

    % Solution set information
    if strcmp(fitnessMode, 'linear_itae')
        fprintf('  SOLUTION: Single best individual (mono-objective ga)\n');
    elseif strcmp(fitnessMode, 'linear_itae_biobj')
        fprintf('  PARETO FRONT (Regulation vs Tracking):\n\n');
        fprintf('    Solutions in Pareto set:     %d\n', N);
        fprintf('    J1_min=%.4f  J1_max=%.4f  (Regulation)\n', min(fval_opt(:,1)), max(fval_opt(:,1)));
        fprintf('    J2_min=%.4f  J2_max=%.4f  (Tracking)\n', min(fval_opt(:,2)), max(fval_opt(:,2)));
    else
        fprintf('  PARETO FRONT:\n\n');
        fprintf('    Solutions in Pareto set:     %d\n', N);
        if N > 1
            fprintf('    (All %d non-dominated solutions available in param_opt/fval_opt)\n', N);
        end
    end
    fprintf('\n');

    fprintf('════════════════════════════════════════════════════════════════════════════\n\n');
end

%--------------------------------------------------------------
%% DEDICATED FITNESS FUNCTION: Mono-objective ITAE (linear_itae)
%--------------------------------------------------------------
function fval = compute_fitness_itae_mono(LIN_MODEL, ssModel, nDFIG, nCONTROL, gaMetadata, workerID)
% COMPUTE_FITNESS_ITAE_MONO - Single-objective fitness: J = mean(4 normalized ITAEs)
%
%   8-channel step transient ITAE (pure transient: y(t) - y(T)):
%     Group 1 (f_pert): il_r→Δf + il_i→Δf    (frequency regulation)
%     Group 2 (v_pert): il_r→ΔV + il_i→ΔV    (voltage regulation)
%     Group 3 (track):  P_ref→P + Q_ref→Q      (power tracking)
%     Group 4 (vdc):    il_r→Vdc + P_ref→Vdc   (DC bus stress)
%
%   J = (ITAE_f/ITAE0_f + ITAE_v/ITAE0_v + ITAE_track/ITAE0_track + ITAE_vdc/ITAE0_vdc) / 4
%
%   Constraints: eigenvalue robustness at SCR=1/2/3 (3-band LF/MF/HF)
%
% INPUTS:
%   LIN_MODEL  - Linearized model (must be stable)
%   ssModel    - State-space model (LIN_MODEL.ssModel)
%   nDFIG      - Number of DFIGs
%   nCONTROL   - Number of control loops (7)
%   gaMetadata - GA metadata with baseline ITAEs, indices, eigenConfig
%   workerID   - Parallel worker ID (0=sequential)
%
% OUTPUT:
%   fval - Scalar fitness value (J or 1e6 penalty)

    penaltyFval = 1e6;

    % --- Pre-filter: reject unstable or poorly-damped ---
    if LIN_MODEL.stability == 0
        fval = penaltyFval;
        return;
    end
    obj_damping = -min(LIN_MODEL.minDamping);
    obj_maxRealEig = LIN_MODEL.maxRealEig;
    if obj_damping > -0.01 || obj_maxRealEig > 0
        fprintf('  [MONO W%d] Pre-filter REJECT: damping=%.6f maxRealEig=%.6f\n', workerID, obj_damping, obj_maxRealEig);
        fval = penaltyFval;
        return;
    end

    % --- Multi-endpoint eigenvalue robustness (SCR=1/2/3) ---
    if isfield(gaMetadata, 'robustnessOPs') && ~isempty(gaMetadata.robustnessOPs)
        for k_op = 1:length(gaMetadata.robustnessOPs)
            ropk = gaMetadata.robustnessOPs(k_op);
            if ropk.skip, continue; end
            if abs(ropk.SCR_grid - LIN_MODEL.MODEL.GRID.PARAM.SCR_grid) < 1e-6
                LIN_CHECK = LIN_MODEL;
            else
                LIN_CHECK = LIN_MODEL;
                LIN_CHECK.MODEL.GRID.PARAM.SCR_grid = ropk.SCR_grid;
                Ub_r  = LIN_CHECK.MODEL.BASE.Ub;
                Sb_r  = LIN_CHECK.MODEL.GRID.BASE.Sb;
                f0_r  = LIN_CHECK.MODEL.BASE.f0;
                XR_r  = LIN_CHECK.MODEL.GRID.PARAM.XR_grid;
                LIN_CHECK.MODEL.GRID.PARAM.Lg_H    = Ub_r^2 / Sb_r / (2*pi*f0_r) / ropk.SCR_grid;
                LIN_CHECK.MODEL.GRID.PARAM.Rg_Ohm  = LIN_CHECK.MODEL.GRID.PARAM.Lg_H * (2*pi*f0_r) / XR_r;
                LIN_CHECK.MODEL.GRID.PARAM.Lg_pu   = LIN_CHECK.MODEL.GRID.PARAM.Lg_H / LIN_CHECK.MODEL.BASE.Lb;
                LIN_CHECK.MODEL.GRID.PARAM.Rg_pu   = LIN_CHECK.MODEL.GRID.PARAM.Rg_Ohm / LIN_CHECK.MODEL.BASE.Zb;
                try
                    LIN_CHECK = LINEAR_ANALYSIS(LIN_CHECK, workerID);
                catch ME_rob
                    fprintf('  [MONO W%d] SCR=%.1f LINEAR_ANALYSIS error: %s\n', workerID, ropk.SCR_grid, ME_rob.message);
                    fval = penaltyFval;
                    return;
                end
                if LIN_CHECK.stability == 0
                    fprintf('  [MONO W%d] SCR=%.1f UNSTABLE\n', workerID, ropk.SCR_grid);
                    fval = penaltyFval;
                    return;
                end
            end
            eigenConfig_k = gaMetadata.eigenConfig;
            eigenConfig_k.min_real_pole_mag = max(ropk.baseline_min_real_pole_mag, gaMetadata.eigenConfig.min_real_pole_mag);
            eigenConfig_k.min_damping_lf    = max(ropk.baseline_min_damping_lf, gaMetadata.eigenConfig.min_damping);
            eigenConfig_k.min_damping_mf    = max(ropk.baseline_min_damping_mf, gaMetadata.eigenConfig.min_damping);
            eigenConfig_k.min_damping_hf    = max(ropk.baseline_min_damping_hf, gaMetadata.eigenConfig.min_damping);
            [eig_valid_k, cinfo_k] = check_eigenvalue_constraints(LIN_CHECK, eigenConfig_k);
            if ~eig_valid_k
                fprintf('  [MONO W%d] SCR=%.1f eig FAIL: %s\n', workerID, ropk.SCR_grid, cinfo_k.violation_reason);
                fval = penaltyFval;
                return;
            end
        end
    end

    % --- SISO index computation ---
    nLINE = LIN_MODEL.MODEL.LINE.PARAM.nLINE;
    selectedDFIG_k = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
    indI_Pl = nCONTROL*nDFIG + 2*nDFIG + nLINE;       % il_r
    indI_Ql = nCONTROL*nDFIG + 2*nDFIG + nLINE + 1;   % il_i
    indI_Pr = nCONTROL*nDFIG + selectedDFIG_k;          % P_ref
    indI_Qr = nCONTROL*nDFIG + nDFIG + selectedDFIG_k;  % Q_ref
    indO_f  = 2*nCONTROL*nDFIG + 1;
    indO_v  = 2*nCONTROL*nDFIG + 2;
    indO_P   = gaMetadata.indO_P;
    indO_Q   = gaMetadata.indO_Q;
    indO_Vdc = gaMetadata.indO_Vdc;

    % --- Build 8 SISO transfer functions ---
    matA = ssModel.a; matB = ssModel.b; matC = ssModel.c; matD = ssModel.d;
    Fss_f_Pl   = ss(matA, matB(:,indI_Pl), matC(indO_f,:),   matD(indO_f,indI_Pl));
    Fss_f_Ql   = ss(matA, matB(:,indI_Ql), matC(indO_f,:),   matD(indO_f,indI_Ql));
    Fss_v_Pl   = ss(matA, matB(:,indI_Pl), matC(indO_v,:),   matD(indO_v,indI_Pl));
    Fss_v_Ql   = ss(matA, matB(:,indI_Ql), matC(indO_v,:),   matD(indO_v,indI_Ql));
    Fss_P_Pr   = ss(matA, matB(:,indI_Pr), matC(indO_P,:),   matD(indO_P,indI_Pr));
    Fss_Q_Qr   = ss(matA, matB(:,indI_Qr), matC(indO_Q,:),   matD(indO_Q,indI_Qr));
    Fss_Vdc_Pl = ss(matA, matB(:,indI_Pl), matC(indO_Vdc,:), matD(indO_Vdc,indI_Pl));
    Fss_Vdc_Pr = ss(matA, matB(:,indI_Pr), matC(indO_Vdc,:), matD(indO_Vdc,indI_Pr));

    % --- Step responses + transient errors ---
    T_sim = gaMetadata.itae_sim_duration;
    N_pts = gaMetadata.itae_npoints;
    t  = linspace(0, T_sim, N_pts)';
    dt = t(2) - t(1);

    ys_f_Pl = step(Fss_f_Pl, t);    ys_f_Ql = step(Fss_f_Ql, t);
    ys_v_Pl = step(Fss_v_Pl, t);    ys_v_Ql = step(Fss_v_Ql, t);
    ys_P_Pr = step(Fss_P_Pr, t);    ys_Q_Qr = step(Fss_Q_Qr, t);
    ys_Vdc_Pl = step(Fss_Vdc_Pl, t);  ys_Vdc_Pr = step(Fss_Vdc_Pr, t);

    % y(t) - y(T): pure transient, no steady-state contamination
    ye_f_Pl = ys_f_Pl - ys_f_Pl(end);    ye_f_Ql = ys_f_Ql - ys_f_Ql(end);
    ye_v_Pl = ys_v_Pl - ys_v_Pl(end);    ye_v_Ql = ys_v_Ql - ys_v_Ql(end);
    ye_P_Pr = ys_P_Pr - ys_P_Pr(end);    ye_Q_Qr = ys_Q_Qr - ys_Q_Qr(end);
    ye_Vdc_Pl = ys_Vdc_Pl - ys_Vdc_Pl(end);  ye_Vdc_Pr = ys_Vdc_Pr - ys_Vdc_Pr(end);

    % --- 4 grouped ITAEs ---
    ITAE_f_pert = sum(t .* abs(ye_f_Pl)) * dt + sum(t .* abs(ye_f_Ql)) * dt;
    ITAE_v_pert = sum(t .* abs(ye_v_Pl)) * dt + sum(t .* abs(ye_v_Ql)) * dt;
    ITAE_track  = sum(t .* abs(ye_P_Pr)) * dt + sum(t .* abs(ye_Q_Qr)) * dt;
    ITAE_vdc    = sum(t .* abs(ye_Vdc_Pl)) * dt + sum(t .* abs(ye_Vdc_Pr)) * dt;

    J = (ITAE_f_pert / gaMetadata.itae0_f_pert + ITAE_v_pert / gaMetadata.itae0_v_pert ...
       + ITAE_track  / gaMetadata.itae0_track  + ITAE_vdc    / gaMetadata.itae0_vdc) / 4;

    fval = J;
    if fval > 1e4 || isnan(fval) || isinf(fval)
        fval = penaltyFval;
    end
end

%--------------------------------------------------------------
%% DEDICATED FITNESS FUNCTION: Bi-objective ITAE (linear_itae_biobj)
%--------------------------------------------------------------
function fval = compute_fitness_itae_biobj(LIN_MODEL, ssModel, nDFIG, nCONTROL, gaMetadata, workerID)
% COMPUTE_FITNESS_ITAE_BIOBJ - Bi-objective fitness: J1=regulation, J2=tracking
%
%   J1 = mean of 6 normalized regulation ITAEs (4 load + 2 wind → Δf, ΔV)
%   J2 = mean of 2 normalized tracking ITAEs (P_ref→P, Q_ref→Q)
%   Constraint: peak|ΔVdc| < 10% Vdc_nom → soft penalty on J1, J2
%
%   10-channel step transient ITAE (pure transient: y(t) - y(T)):
%     Regulation (J1): il_r→Δf, il_i→Δf, il_r→ΔV, il_i→ΔV, vw→Δf, vw→ΔV
%     Tracking   (J2): P_ref→P, Q_ref→Q
%     Constraint:      il_r→Vdc, P_ref→Vdc (peak excursion)
%
%   Constraints: eigenvalue robustness at SCR=1/2/3 (3-band LF/MF/HF)
%
% INPUTS:
%   LIN_MODEL  - Linearized model (must be stable)
%   ssModel    - State-space model (LIN_MODEL.ssModel)
%   nDFIG      - Number of DFIGs
%   nCONTROL   - Number of control loops (7)
%   gaMetadata - GA metadata with per-channel baseline ITAEs, wind index, eigenConfig
%   workerID   - Parallel worker ID (0=sequential)
%
% OUTPUT:
%   fval - [J1, J2] row vector (or 1×2 penalty)

    nObj = 2;
    penaltyFval = 1e6 * ones(1, nObj);

    % --- Pre-filter: reject unstable or poorly-damped ---
    if LIN_MODEL.stability == 0
        fval = penaltyFval;
        return;
    end
    obj_damping = -min(LIN_MODEL.minDamping);
    obj_maxRealEig = LIN_MODEL.maxRealEig;
    if obj_damping > -0.01 || obj_maxRealEig > 0
        fprintf('  [BIOBJ W%d] Pre-filter REJECT: damping=%.6f maxRealEig=%.6f\n', workerID, obj_damping, obj_maxRealEig);
        fval = penaltyFval;
        return;
    end

    % --- Multi-endpoint eigenvalue robustness (SCR=1/2/3) ---
    if isfield(gaMetadata, 'robustnessOPs') && ~isempty(gaMetadata.robustnessOPs)
        for k_op = 1:length(gaMetadata.robustnessOPs)
            ropk = gaMetadata.robustnessOPs(k_op);
            if ropk.skip, continue; end
            if abs(ropk.SCR_grid - LIN_MODEL.MODEL.GRID.PARAM.SCR_grid) < 1e-6
                LIN_CHECK = LIN_MODEL;
            else
                LIN_CHECK = LIN_MODEL;
                LIN_CHECK.MODEL.GRID.PARAM.SCR_grid = ropk.SCR_grid;
                Ub_r  = LIN_CHECK.MODEL.BASE.Ub;
                Sb_r  = LIN_CHECK.MODEL.GRID.BASE.Sb;
                f0_r  = LIN_CHECK.MODEL.BASE.f0;
                XR_r  = LIN_CHECK.MODEL.GRID.PARAM.XR_grid;
                LIN_CHECK.MODEL.GRID.PARAM.Lg_H    = Ub_r^2 / Sb_r / (2*pi*f0_r) / ropk.SCR_grid;
                LIN_CHECK.MODEL.GRID.PARAM.Rg_Ohm  = LIN_CHECK.MODEL.GRID.PARAM.Lg_H * (2*pi*f0_r) / XR_r;
                LIN_CHECK.MODEL.GRID.PARAM.Lg_pu   = LIN_CHECK.MODEL.GRID.PARAM.Lg_H / LIN_CHECK.MODEL.BASE.Lb;
                LIN_CHECK.MODEL.GRID.PARAM.Rg_pu   = LIN_CHECK.MODEL.GRID.PARAM.Rg_Ohm / LIN_CHECK.MODEL.BASE.Zb;
                try
                    LIN_CHECK = LINEAR_ANALYSIS(LIN_CHECK, workerID);
                catch ME_rob
                    fprintf('  [BIOBJ W%d] SCR=%.1f LINEAR_ANALYSIS error: %s\n', workerID, ropk.SCR_grid, ME_rob.message);
                    fval = penaltyFval;
                    return;
                end
                if LIN_CHECK.stability == 0
                    fprintf('  [BIOBJ W%d] SCR=%.1f UNSTABLE\n', workerID, ropk.SCR_grid);
                    fval = penaltyFval;
                    return;
                end
            end
            eigenConfig_k = gaMetadata.eigenConfig;
            eigenConfig_k.min_real_pole_mag = max(ropk.baseline_min_real_pole_mag, gaMetadata.eigenConfig.min_real_pole_mag);
            eigenConfig_k.min_damping_lf    = max(ropk.baseline_min_damping_lf, gaMetadata.eigenConfig.min_damping);
            eigenConfig_k.min_damping_mf    = max(ropk.baseline_min_damping_mf, gaMetadata.eigenConfig.min_damping);
            eigenConfig_k.min_damping_hf    = max(ropk.baseline_min_damping_hf, gaMetadata.eigenConfig.min_damping);
            [eig_valid_k, cinfo_k] = check_eigenvalue_constraints(LIN_CHECK, eigenConfig_k);
            if ~eig_valid_k
                fprintf('  [BIOBJ W%d] SCR=%.1f eig FAIL: %s\n', workerID, ropk.SCR_grid, cinfo_k.violation_reason);
                fval = penaltyFval;
                return;
            end
        end
    end

    % --- SISO index computation ---
    nLINE = LIN_MODEL.MODEL.LINE.PARAM.nLINE;
    selectedDFIG_k = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
    indI_Pl = nCONTROL*nDFIG + 2*nDFIG + nLINE;       % il_r (active load)
    indI_Ql = nCONTROL*nDFIG + 2*nDFIG + nLINE + 1;   % il_i (reactive load)
    indI_Pr = nCONTROL*nDFIG + selectedDFIG_k;          % P_ref
    indI_Qr = nCONTROL*nDFIG + nDFIG + selectedDFIG_k;  % Q_ref
    indI_vw = gaMetadata.indI_vw;                        % vw_delta (wind)
    indO_f  = 2*nCONTROL*nDFIG + 1;
    indO_v  = 2*nCONTROL*nDFIG + 2;
    indO_P   = gaMetadata.indO_P;
    indO_Q   = gaMetadata.indO_Q;
    indO_Vdc = gaMetadata.indO_Vdc;

    % --- Build 10 SISO transfer functions (8 shared + 2 wind) ---
    matA = ssModel.a; matB = ssModel.b; matC = ssModel.c; matD = ssModel.d;
    % Load perturbation → Δf, ΔV
    Fss_f_Pl   = ss(matA, matB(:,indI_Pl), matC(indO_f,:),   matD(indO_f,indI_Pl));
    Fss_f_Ql   = ss(matA, matB(:,indI_Ql), matC(indO_f,:),   matD(indO_f,indI_Ql));
    Fss_v_Pl   = ss(matA, matB(:,indI_Pl), matC(indO_v,:),   matD(indO_v,indI_Pl));
    Fss_v_Ql   = ss(matA, matB(:,indI_Ql), matC(indO_v,:),   matD(indO_v,indI_Ql));
    % Reference → P, Q (tracking)
    Fss_P_Pr   = ss(matA, matB(:,indI_Pr), matC(indO_P,:),   matD(indO_P,indI_Pr));
    Fss_Q_Qr   = ss(matA, matB(:,indI_Qr), matC(indO_Q,:),   matD(indO_Q,indI_Qr));
    % Vdc channels (constraint)
    Fss_Vdc_Pl = ss(matA, matB(:,indI_Pl), matC(indO_Vdc,:), matD(indO_Vdc,indI_Pl));
    Fss_Vdc_Pr = ss(matA, matB(:,indI_Pr), matC(indO_Vdc,:), matD(indO_Vdc,indI_Pr));
    % Wind channels (regulation)
    Fss_f_vw   = ss(matA, matB(:,indI_vw), matC(indO_f,:),   matD(indO_f,indI_vw));
    Fss_v_vw   = ss(matA, matB(:,indI_vw), matC(indO_v,:),   matD(indO_v,indI_vw));

    % --- Step responses + transient errors ---
    T_sim = gaMetadata.itae_sim_duration;
    N_pts = gaMetadata.itae_npoints;
    t  = linspace(0, T_sim, N_pts)';
    dt = t(2) - t(1);

    % 10 step responses
    ys_f_Pl = step(Fss_f_Pl, t);    ys_f_Ql = step(Fss_f_Ql, t);
    ys_v_Pl = step(Fss_v_Pl, t);    ys_v_Ql = step(Fss_v_Ql, t);
    ys_P_Pr = step(Fss_P_Pr, t);    ys_Q_Qr = step(Fss_Q_Qr, t);
    ys_Vdc_Pl = step(Fss_Vdc_Pl, t);  ys_Vdc_Pr = step(Fss_Vdc_Pr, t);
    ys_f_vw = step(Fss_f_vw, t);    ys_v_vw = step(Fss_v_vw, t);

    % y(t) - y(T): pure transient, no steady-state contamination
    ye_f_Pl = ys_f_Pl - ys_f_Pl(end);    ye_f_Ql = ys_f_Ql - ys_f_Ql(end);
    ye_v_Pl = ys_v_Pl - ys_v_Pl(end);    ye_v_Ql = ys_v_Ql - ys_v_Ql(end);
    ye_P_Pr = ys_P_Pr - ys_P_Pr(end);    ye_Q_Qr = ys_Q_Qr - ys_Q_Qr(end);
    ye_Vdc_Pl = ys_Vdc_Pl - ys_Vdc_Pl(end);  ye_Vdc_Pr = ys_Vdc_Pr - ys_Vdc_Pr(end);
    ye_f_vw = ys_f_vw - ys_f_vw(end);    ye_v_vw = ys_v_vw - ys_v_vw(end);

    % --- Per-channel ITAEs (10 channels) ---
    itae_f_Pl = sum(t .* abs(ye_f_Pl)) * dt;
    itae_f_Ql = sum(t .* abs(ye_f_Ql)) * dt;
    itae_v_Pl = sum(t .* abs(ye_v_Pl)) * dt;
    itae_v_Ql = sum(t .* abs(ye_v_Ql)) * dt;
    itae_f_vw = sum(t .* abs(ye_f_vw)) * dt;
    itae_v_vw = sum(t .* abs(ye_v_vw)) * dt;
    itae_P_Pr = sum(t .* abs(ye_P_Pr)) * dt;
    itae_Q_Qr = sum(t .* abs(ye_Q_Qr)) * dt;

    % --- J1 = mean of 6 normalized regulation ITAEs ---
    J1 = ( itae_f_Pl / gaMetadata.itae0_f_Pl ...
         + itae_f_Ql / gaMetadata.itae0_f_Ql ...
         + itae_v_Pl / gaMetadata.itae0_v_Pl ...
         + itae_v_Ql / gaMetadata.itae0_v_Ql ...
         + itae_f_vw / gaMetadata.itae0_f_vw ...
         + itae_v_vw / gaMetadata.itae0_v_vw ) / 6;

    % --- J2 = mean of 2 normalized tracking ITAEs ---
    J2 = ( itae_P_Pr / gaMetadata.itae0_P_Pr ...
         + itae_Q_Qr / gaMetadata.itae0_Q_Qr ) / 2;

    % --- Vdc peak constraint: soft penalty if WORSE than baseline ---
    vdc_peak_Pl = max(abs(ys_Vdc_Pl));
    vdc_peak_Pr = max(abs(ys_Vdc_Pr));
    vdc_excess = max(vdc_peak_Pl / gaMetadata.vdc_peak_Pl_baseline, ...
                     vdc_peak_Pr / gaMetadata.vdc_peak_Pr_baseline);
    if vdc_excess > 1.0
        vdc_penalty = 1 + 100 * (vdc_excess - 1.0);
        J1 = J1 * vdc_penalty;
        J2 = J2 * vdc_penalty;
    end

    fval = [J1, J2];
    if any(fval > 1e4) || any(isnan(fval)) || any(isinf(fval))
        fval = penaltyFval;
    end
end

