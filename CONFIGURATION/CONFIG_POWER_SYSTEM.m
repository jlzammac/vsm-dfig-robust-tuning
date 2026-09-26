clear
clc
format compact
format short g
warning ('off','all');
close('all')
bdclose('all')

% Create TEMP directory for logs if it doesn't exist
if ~exist('../TEMP', 'dir')
    mkdir('../TEMP');
end

% Generate timestamp for log file
log_timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
log_filename = sprintf('../TEMP/LOG_%s.txt', log_timestamp);
diary(log_filename)
ttime = tic;

% Add ANALYSIS directory to path for analysis functions
addpath(fullfile(fileparts(pwd), 'ANALYSIS'));

%==========================================================================
%% USER CONFIGURATION - ALL SETTINGS IN THIS SECTION
%==========================================================================

%--------------------------------------------------------------
% SIMULINK MODEL SELECTION
%--------------------------------------------------------------
modelName = 'POWER_SYSTEM_FULL';
% modelName = 'POWER_SYSTEM_SIMP';

%--------------------------------------------------------------
% RUN_MODE DEFINITION
% / 0. OPERATING POINT ONLY
% / 1. LINEAR ANALYSIS FOR OP ENDPOINTS
% / 2. LINEAR ANALYSIS FOR OP SPAN
% / 3. CONTROL OPTIMIZATION (GAM)
% / 4. NON-LINEAR SIMULATION
% / 5. OPTIMUM CONTROL DESIGN SEQUENCE
%--------------------------------------------------------------
%--------------------------------------------------------------
% OUTPUT DIRECTORIES
%--------------------------------------------------------------
% Created up front so that no later `cd` into an output folder can fail.
%
% Only RESULTS/CONTROL is versioned -- everything else under RESULTS/ and
% FIGURES/ is generated and is deliberately git-ignored. Three separate sites
% in this file used to `cd` into one of these and only then test
% `~exist('.','dir')`, which asks whether the CURRENT folder exists: always
% true once the cd has succeeded, and unreachable when it has not. On a fresh
% clone each of them threw MATLAB:cd:NonExistentFolder AFTER the work was
% done -- the 225-point sweep and a completed GA phase both ran to the end and
% then lost their output at the save step.
%
% Creating them here is cheaper than guarding every call site and cannot go
% stale when a new one is added.
for outdir_ = { fullfile('..','RESULTS'), ...
                fullfile('..','RESULTS','CONTROL'), ...
                fullfile('..','RESULTS','LINEAR_ANALYSIS'), ...
                fullfile('..','RESULTS','SIMULATION'), ...
                fullfile('..','RESULTS','GA_OPTIMIZATION'), ...
                fullfile('..','FIGURES') }
    if ~exist(outdir_{1}, 'dir'); mkdir(outdir_{1}); end
end
clear outdir_

RUN_MODE = 0;  % NOMINAL LINEARIZATION

%--------------------------------------------------------------
% CONTROL TYPE SELECTION
% / 1. TIME-RESPONSE CONTROL DESIGN
% / 2. FREQUENCY-RESPONSE CONTROL DESIGN
% / 3. FREQUENCY-RESPONSE OPTIMUM DESIGN SPECS FOR ACTIVE POWER (GAM)
% / 4. FREQUENCY-RESPONSE OPTIMUM DESIGN SPECS FOR REACTIVE POWER (GAM)
% / 5. CONTROL PARAMETER OPTIMUM FOR ACTIVE POWER (GAM)
% / 6. CONTROL-PARAMETER OPTIMUM FOR REACTIVE POWER (GAM)
% / 7. VIRTUAL IMPEDANCE OPTIMUM (GAM)
%--------------------------------------------------------------
CONTROL_TYPE = 2;  % FREQUENCY-RESPONSE CONTROL DESIGN

%--------------------------------------------------------------
% CONTROL REDESIGN FLAG (for CONTROL_TYPE 1-2)
% / true  : Force redesign of control (ignore saved designs)
% / false : Load saved design if compatible (checks: model, operating point,
%           specifications TRD/FRD, base values, SCR). Automatically redesigns
%           if any parameter mismatch is detected.
%--------------------------------------------------------------
CONTROL_REDESIGN = false;  % Load saved FRD design (fast init for comparison)

%--------------------------------------------------------------
% GENETIC ALGORITHM OPTIMIZATION CONFIGURATION (for RUN_MODE = 3)
%--------------------------------------------------------------
% OPTIMIZATION SEQUENCE: Select which phases to execute and in what order
% / 1. P controllers frequency-response specs (PDS)
% / 2. Q controllers frequency-response specs (QDS)
% / 3. P control parameters (PCP)
% / 4. Q control parameters (QCP)
% / 5. Virtual impedance (VI)
% Examples: [1 2 3 4 5] = all phases, [1 3 5] = only PDS→PCP→VI, [5] = only VI
% PHASE-BY-PHASE EXECUTION — set OPT_SEQUENCE to the phase(s) you want to run now
% Run one phase at a time and verify results before advancing to the next.
%
%   Phase 1 (PDS): OPT_SEQUENCE=[1], INIT_STEP=0   → uses FRD baseline
%   Phase 2 (QDS): OPT_SEQUENCE=[2], INIT_STEP=1   → uses PDS result
%   Phase 3 (PCP): OPT_SEQUENCE=[3], INIT_STEP=2   → uses QDS result
%   Phase 4 (QCP): OPT_SEQUENCE=[4], INIT_STEP=3   → uses PCP result
%   Phase 5 (VI):  OPT_SEQUENCE=[5], INIT_STEP=4   → uses QCP result
%   Refinement:    OPT_SEQUENCE=[1], INIT_STEP=5,  refinementConfig.enabled=true
%                  then OPT_SEQUENCE=[2], INIT_STEP=1 (after refining PDS)
%
% To run multiple phases in one session: OPT_SEQUENCE=[1 2 3 4 5]
%   WARNING: ~25h total. Recommended: one phase per session.
OPT_SEQUENCE = [3 4 5];  % ← v6 Phases 3-5 (PCP→QCP→VI): skip QDS, from PDS2

% INITIALIZATION STEP: Defines starting point for FIRST step in OPT_SEQUENCE
% / 0 = Start from FRD baseline design (creates/updates LIN_MODEL_FRD_OPT.mat)
% / 1 = Start from last PDS optimization (*_LITAE.mat or *_BIOBJ.mat)
% / 2 = Start from last QDS optimization
% / 3 = Start from last PCP optimization
% / 4 = Start from last QCP optimization
% / 5 = Start from last VI optimization
% NOTE: Subsequent steps in OPT_SEQUENCE ALWAYS inherit from previous step in sequence
INIT_STEP = 1;  % ← v6 Phase 3 from PDS2: Skip QDS (path-dependent CDR degradation)

%--------------------------------------------------------------
% OPTIMIZATION PHASE CONFIGURATION (Advanced - Modify only if needed)
% Defines control design order for each optimization phase
% Order: 1-VSMP | 2-VSMQ | 3-RSCd | 4-RSCq | 5-VDC | 6-GSCd | 7-GSCq
%--------------------------------------------------------------
OPT_PHASE_CONFIG = struct(...
    'PDS', struct('designOrder', [7 4 1 5], 'filename', 'LIN_MODEL_PDS_OPT'), ...
    'QDS', struct('designOrder', [3 6 2],   'filename', 'LIN_MODEL_QDS_OPT'), ...
    'PCP', struct('designOrder', [7 4 1 5], 'filename', 'LIN_MODEL_PCP_OPT'), ...
    'QCP', struct('designOrder', [3 6 2],   'filename', 'LIN_MODEL_QCP_OPT'), ...
    'VI',  struct('designOrder', [3 6 2],   'filename', 'LIN_MODEL_VI_OPT'));
% Phase names (do not modify)
OPT_PHASE_NAMES = {'PDS', 'QDS', 'PCP', 'QCP', 'VI'};

%--------------------------------------------------------------
% GENETIC ALGORITHM PARAMETERS (for RUN_MODE = 3)
%--------------------------------------------------------------
% Parallel workers configuration
% / 0  = Sequential execution (no parallel pool)
% / 4  = Use 4 workers (recommended for most systems)
% / 8  = Use 8 workers (for high-performance systems)
% / 10 = Use 10 workers (for maximum parallelization)
% NOTE: 4 workers optimal for PopulationSize 80, 2-3 for smaller populations
GA_OPTIMIZATION_numWorkers = 4;  % Parallel workers (4=recommended)

% Population size (number of individuals per generation)
% Larger populations explore more but take longer per generation
% Recommended: 50-100 for production, 20-40 for quick verification
GA_OPTIMIZATION_PopulationSize = 80;  % Quick test population

% Maximum runtime (hours)
% Algorithm stops when time limit reached OR max generations reached
% Set to [] for no time limit (only generation limit applies)
GA_OPTIMIZATION_maxTime = 5;  % hours (5 hours max
% Maximum number of generations
% Algorithm stops when generation limit reached OR max time reached
% Recommended: 25-50 for production, 5-10 for quick verification
GA_OPTIMIZATION_maxGenerations = 25;  % Quick test generations

% Random population initialization
% / false = Seed first individual with current design (recommended)
% / true  = Completely random initial population
% NOTE: Seeding usually converges faster to good solutions
GA_OPTIMIZATION_newPopulation = false;

% Fitness evaluation mode
% 'linear'           : 4 objectives from linearized model (original mode, gamultiobj)
% 'hybrid'           : 5 objectives (2 linear stability + 3 NL simulation, gamultiobj) — legacy
% 'linear_itae'      : mono-objective ga() → J = mean of 4 normalized ITAEs
% 'linear_itae_biobj': bi-objective gamultiobj() → J1=regulation (6ch), J2=tracking (2ch)
%                       Vdc peak constraint (<10%), wind perturbation channels.
%                       ITAE_k = ∫t·|y(t)-y(T)|dt, normalized by baseline (J0=1.0).
GA_OPTIMIZATION_fitnessMode = 'linear_itae_biobj';  % v6: bi-objective Pareto (reg vs track)

% ITAE BASELINE: Always uses FRD original (LIN_MODEL_FRD_OPT.mat) for normalization.
% This ensures J values are comparable across all phases and refinement cycles.
% Hardcoded in OPTIMIZER.m — no configuration needed here.

%--------------------------------------------------------------
% MICRO-REFINEMENT CONFIGURATION (optional final pass)
% After completing all 5 phases, run PDS+QDS again with tight bounds
% to squeeze final performance. Set enabled=true + desired factor.
%--------------------------------------------------------------
% GA_OPTIMIZATION_refinementConfig = struct('enabled', true,  'factor', 0.10);
GA_OPTIMIZATION_refinementConfig  = struct('enabled', false, 'factor', 0.10);  % disabled by default

%--------------------------------------------------------------
% OPERATING POINT SPECIFICATIONS
% Note: Actual values used depend on RUN_MODE:
%   RUN_MODE 0,4,5: Uses OP_RATED
%   RUN_MODE 1,2:   Uses OP_RATED as base, then sweeps
%   RUN_MODE 3:     Uses OP_OPTIMIZATION
%--------------------------------------------------------------
% RATED OPERATING POINT (nominal conditions)
OP_RATED.Vp = 1.0;        % PCC voltage (pu)
OP_RATED.P_ref = 0.70;    % Active power reference per DFIG (pu)
OP_RATED.SCR_grid = [];   % Grid SCR: [] = use from MODEL/CONFIG_MODEL.m (default: 1.0)
                          %            or specify value to override (e.g., 2.5, 5.0)

% OPTIMIZATION OPERATING POINT (for genetic algorithm)
% Worst-case STABLE OP for robust hybrid optimization:
%   Stability boundary analysis (sweep Nov 2025): P>=0.90 unstable at SCR=1.0
%   Vp=0.975 → low voltage (0.95 limits P_ref to 0.70)
%   P_ref=0.80 → max stable power at SCR=1.0 for Vp<=0.975
%   SCR=1.0 → weakest grid, minimum support
OP_OPTIMIZATION.Vp = 0.975;      % PCC voltage (pu) — near stability boundary
OP_OPTIMIZATION.P_ref = 0.80;    % Active power reference per DFIG (pu) — max stable at SCR=1
OP_OPTIMIZATION.SCR_grid = 1.0;  % Grid short-circuit ratio — worst-case: minimum

%--------------------------------------------------------------
% NON-LINEAR SIMULATION CONFIGURATION (for RUN_MODE = 4)
% Set NL_SIM_PERT_TYPE and NL_SIM_CONFIG fields for the desired test.
% 'none'            : Baseline (no perturbation)
% 'generation_loss' : DFIG disconnection via breaker_mask
% 'voltage_sag'     : Grid voltage sag (sag_depth>0) or swell (sag_depth<0)
%                     sag_duration >> sim_duration → effective step (no recovery)
% 'pref_step'       : Active power reference step (per-DFIG mask)
% 'qref_step'       : Reactive power reference step (per-DFIG mask) [*]
% 'load_step'       : Load current step (real + reactive) [reactive*]
% 'wind_change'     : Wind speed change (per-DFIG mask)
% 'custom'          : Arbitrary combination of all perturbations
% [*] Requires SETUP_PERTURBATION_BLOCKS.m to have been run once
%--------------------------------------------------------------
NL_SIM_PERT_TYPE = 'none';   % Perturbation type
NL_SIM_DURATION  = 5;        % Simulation duration [s]

NL_SIM_CONFIG = struct();
NL_SIM_CONFIG.sim_duration     = NL_SIM_DURATION;
% Generation loss parameters
NL_SIM_CONFIG.breaker_mask     = [0 0 0 1];    % [1×nDFIG]: 1=disconnect (DFIG 4)
NL_SIM_CONFIG.breaker_time     = 0.500;        % [s] apply at t=500ms (settling first)
% Voltage sag/swell parameters
NL_SIM_CONFIG.sag_depth        = 0.20;         % [pu] >0=sag, <0=swell
NL_SIM_CONFIG.sag_start_time   = 0.500;        % [s] apply at t=500ms (settling first)
NL_SIM_CONFIG.sag_duration     = 0.150;        % [s] (set >>sim_duration for step)
% P_ref step parameters
NL_SIM_CONFIG.pref_mask        = [1 0 0 0];    % [1×nDFIG]: 1=apply step
NL_SIM_CONFIG.pref_delta       = +0.15;        % [pu]
NL_SIM_CONFIG.pref_time        = 0.005;        % [s] apply at t=5ms (start of sim)
% Q_ref step parameters [requires SETUP_PERTURBATION_BLOCKS]
NL_SIM_CONFIG.qref_mask        = [1 0 0 0];    % [1×nDFIG]: 1=apply step
NL_SIM_CONFIG.qref_delta       = -0.20;        % [pu]
NL_SIM_CONFIG.qref_time        = 0.005;        % [s] apply at t=5ms (start of sim)
% Load step parameters [reactive requires SETUP_PERTURBATION_BLOCKS]
NL_SIM_CONFIG.load_delta_r     = 0;            % [pu] active load step
NL_SIM_CONFIG.load_delta_i     = 0;            % [pu] reactive load step
NL_SIM_CONFIG.load_time        = 0.005;        % [s] apply at t=5ms (start of sim)
% Wind speed change parameters
NL_SIM_CONFIG.vw_mask          = [1 0 0 0];    % [1×nDFIG]: 1=apply change
NL_SIM_CONFIG.vw_delta_val     = -2.0;         % [m/s]
NL_SIM_CONFIG.vw_time          = 0.005;        % [s] apply at t=5ms (start of sim)
% SCR/H override for sim (leave empty to use OP_RATED SCR)
NL_SIM_CONFIG.override_SCR     = [];           % e.g. 3.0 for strong grid
NL_SIM_CONFIG.override_H_scale = [];           % e.g. 3.0 to triple inertia

%--------------------------------------------------------------
% VIRTUAL IMPEDANCE (for initial control design)
%--------------------------------------------------------------
VIMP_Lv_pu = 0.06507;  % Virtual inductance (pu)
VIMP_Rv_pu = 0.0;      % Virtual resistance (pu)

%--------------------------------------------------------------
% TIME-RESPONSE DESIGN SPECIFICATIONS
% Note: ts2 = 2% settling time criterion (ts2% = 4/(ζ*ωn))
%--------------------------------------------------------------
% VSMP - Virtual Synchronous Machine Active Power Control
TRD_SPECS.VSMP.ts2 = 1;            % 2% settling time (s)
TRD_SPECS.VSMP.seta = 1/sqrt(2);   % Damping ratio ζ (0.707 = critically damped)
TRD_SPECS.VSMP.Dp = 20;            % Steady-state damping coefficient [dimensionless]
                                   % Physical meaning: Power-frequency droop = 1/Dp
                                   % Value of 20 → 5% droop (1/20 = 0.05)
                                   % Typical range: 10-40 for VSM applications
                                   % Should match MODEL.GRID.PARAM.Deq_pu for grid consistency

% VSMQ - Virtual Synchronous Machine Reactive Power Control
TRD_SPECS.VSMQ.ts2 = 2;            % 2% settling time (s)
TRD_SPECS.VSMQ.DQ_absolute = 900;  % Q-V droop coefficient [VAr/V]
                                   % Physical meaning: Reactive power change per voltage change
                                   % For 690V base: 900 VAr/V ≈ 0.295 pu droop
                                   % IMPORTANT: Voltage-level dependent parameter
                                   %   - Valid for 690V LV systems
                                   %   - For MV/HV systems, recalculate based on new base voltage
                                   % ⚠️ DISCLAIMER: This value provides relatively weak Q-V droop
                                   %    (DQ_pu ≈ 0.3) compared to typical grid codes (2-5% voltage
                                   %    droop would require DQ_pu ≈ 6-15). Value empirically tuned
                                   %    for baseline system performance. For strict grid code
                                   %    compliance, consider increasing to 3000-4500 VAr/V.

% RSC - Rotor Side Converter Current Control
TRD_SPECS.RSC.ts2 = 4e-3;          % 2% settling time (s) - Fast inner loop
TRD_SPECS.RSC.seta = 1/sqrt(2);    % Damping ratio ζ (0.707 = critically damped)

% VDC - DC Bus Voltage Control
TRD_SPECS.VDC.ts2 = 80e-3;         % 2% settling time (s) - Medium-speed loop
TRD_SPECS.VDC.seta = 1/sqrt(2);    % Damping ratio ζ (0.707 = critically damped)

% GSC - Grid Side Converter Current Control
TRD_SPECS.GSC.ts2 = 4e-3;          % 2% settling time (s) - Fast inner loop
TRD_SPECS.GSC.seta = 1/sqrt(2);    % Damping ratio ζ (0.707 = critically damped)

%--------------------------------------------------------------
% STABILITY MARGIN CALCULATION SPECIFICATIONS
%--------------------------------------------------------------
% Initial crossover frequency guesses for fsolve convergence [rad/s]
% These values are used in CONTROL_DESIGN_TR.m for numerical calculation
% of gain and phase margins. Good initial guesses improve convergence
% speed and reliability.
%
% Values reflect typical control loop bandwidth hierarchy:
%   - Outer loops (power/voltage): slow dynamics (1-10 rad/s)
%   - Inner loops (current): fast dynamics (100-1000 rad/s)
%   - DC voltage: medium dynamics (50-150 rad/s)
%
% For adaptive calculation from time-domain specs, set individual values to []
TRD_SPECS.STABILITY_MARGINS.w_ini_VSMP = 10;    % Active power loop (~1.6 Hz)
TRD_SPECS.STABILITY_MARGINS.w_ini_VSMQ = 2.5;   % Reactive power/voltage loop (~0.4 Hz)
TRD_SPECS.STABILITY_MARGINS.w_ini_RSC  = 350;   % Rotor current loop (~55 Hz)
TRD_SPECS.STABILITY_MARGINS.w_ini_VDC  = 100;   % DC voltage loop (~16 Hz)
TRD_SPECS.STABILITY_MARGINS.w_ini_GSC  = 500;   % Grid current loop (~80 Hz)
% Note: For aggressive tuning (ts2 < 0.05s), increase guesses by 5-10×
%       For conservative tuning (ts2 > 2s), decrease guesses by 2-5×

%--------------------------------------------------------------
% FREQUENCY-RESPONSE DESIGN SPECIFICATIONS
%--------------------------------------------------------------
FRD_SPECS.VSMP.Fm = 67.2;          % Phase margin (deg)
FRD_SPECS.VSMP.wo = 8.07;          % Crossover frequency (rad/s)
FRD_SPECS.VSMQ.wo = 2.0;           % Crossover frequency (rad/s)
FRD_SPECS.RSC.Fm = [65.7 65.7];    % Phase margin [d-axis q-axis] (deg)
FRD_SPECS.RSC.wo = [2184 2184];    % Crossover frequency [d-axis q-axis] (rad/s)
FRD_SPECS.VDC.Fm = 65.5;           % Phase margin (deg)
FRD_SPECS.VDC.wo = 109.9;          % Crossover frequency (rad/s)
FRD_SPECS.GSC.Fm = [65.7 65.7];    % Phase margin [d-axis q-axis] (deg)
FRD_SPECS.GSC.wo = [2184 2184];    % Crossover frequency [d-axis q-axis] (rad/s)

%--------------------------------------------------------------
% CONTROL DESIGN SEQUENCE
% Order: 1-VSMP | 2-VSMQ | 3-RSCd | 4-RSCq | 5-VDC | 6-GSCd | 7-GSCq
%--------------------------------------------------------------
FRD_designOrder = [7 3 4 6 1 2 5];  % Design sequence for FRD
FRD_selectedDFIG = 1;                % Selected DFIG for design
FRD_N_iter = 3;                      % Number of iterations

%--------------------------------------------------------------
% CONTROL DESIGN SEQUENCE OPTIMIZATION (for RUN_MODE = 5)
% Tests different design orders to find optimal sequence
% WARNING: Testing all permutations (7! = 5040) takes several hours
%--------------------------------------------------------------
CD_SEQ_numWorkers = 10;              % Number of parallel workers
CD_SEQ_maxSequences = [];            % Max sequences to test: [] = all 5040
                                     % Set to smaller number for faster testing:
                                     %   100   = ~10 min test
                                     %   500   = ~1 hour test
                                     %   1000  = ~2 hour test
                                     %   []    = full search (many hours)

%--------------------------------------------------------------
% PARALLEL PROCESSING CONFIGURATION (for RUN_MODE = 1, 2)
% Enables parallel computation of multiple operating points
%
% PERFORMANCE BENCHMARKS (measured on 4-DFIG system):
%   RUN_MODE=1 (8 points):
%     - Sequential: 12s  |  Parallel (8 workers): 33s + 20s overhead = 53s
%     - Recommendation: SEQUENTIAL (2.8× faster)
%   RUN_MODE=2 (225 points):
%     - Sequential: ~5.5min  |  Parallel (8 workers): ~2.3min
%     - Recommendation: PARALLEL (2.4× faster)
%
% AUTOMATIC SELECTION:
%   -1 = Auto-detect based on RUN_MODE (0 for MODE 1, 8 for MODE 2)
%    0 = Sequential execution (best for small sweeps < 20 points)
%  8-10 = Parallel execution (best for large sweeps > 50 points)
%--------------------------------------------------------------
LINEAR_ANALYSIS_numWorkers = -1;    % -1 = Auto-detect (recommended)
                                     %  0 = Force sequential
                                     %  8 = Force parallel (8 workers)

%--------------------------------------------------------------
% OPERATING POINT SWEEP RANGES (for RUN_MODE = 1, 2)
% User-configurable ranges for parametric analysis
%--------------------------------------------------------------
% RUN_MODE = 1: ENDPOINT ANALYSIS (tests stability boundaries)
% Analyzes 2×2×2 = 8 operating points at extreme conditions
ENDPOINT_Vp_min = 0.95;              % Minimum PCC voltage [pu]
ENDPOINT_Vp_max = 1.05;              % Maximum PCC voltage [pu]
ENDPOINT_Pdfig_min = 0.5;            % Minimum DFIG power [pu]
ENDPOINT_Pdfig_max = 0.75;            % Maximum DFIG power [pu]
ENDPOINT_SCR_min = 1;                % Minimum grid SCR
ENDPOINT_SCR_max = 3;                % Maximum grid SCR

% RUN_MODE = 2: COMPREHENSIVE SWEEP (detailed operating envelope)
% Full analysis: 5×9×5 = 225 points (can be reduced for testing)
SWEEP_Vp_points = 5;                 % Number of voltage points (default: 5)
SWEEP_Vp_min = 0.95;                 % Minimum PCC voltage [pu]
SWEEP_Vp_max = 1.05;                 % Maximum PCC voltage [pu]

SWEEP_Pdfig_points = 9;              % Number of power points (default: 9)
SWEEP_Pdfig_min = 0.4;               % Minimum DFIG power [pu]
SWEEP_Pdfig_max = 1.2;               % Maximum DFIG power [pu]

SWEEP_SCR_points = 5;                % Number of SCR points (default: 5)
SWEEP_SCR_min = 1;                   % Minimum grid SCR
SWEEP_SCR_max = 3;                   % Maximum grid SCR

%==========================================================================
% END OF USER CONFIGURATION
%==========================================================================

%--------------------------------------------------------------
%% MODEL AND CONTROL INITIALIZATION
%--------------------------------------------------------------
% SIMULINK MODEL
LIN_MODEL.modelName = modelName;

% MODEL
cd ../MODEL
LIN_MODEL = CONFIG_MODEL(LIN_MODEL);

% CONTROL
cd ../CONTROL
LIN_MODEL = CONFIG_CONTROL(LIN_MODEL);

% BUS DEFINITIONS
cd ../BUS_DEFINITIONS
BusDefinition(LIN_MODEL.MODEL,'MODEL_Bus')
BusDefinition(LIN_MODEL.CONTROL,'CONTROL_Bus')
cd ../CONTROL

%--------------------------------------------------------------
%% OPERATING POINT DEFINITION
%--------------------------------------------------------------
nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;

% Common parameters for all operating points
LIN_MODEL.opSpecs.f = 1;
LIN_MODEL.opSpecs.Vgrid = 1;
LIN_MODEL.opSpecs.Qg_ref = 0*ones(1,nDFIG);
LIN_MODEL.opSpecs.pitch = 1*ones(1,nDFIG);
LIN_MODEL.opSpecs.Vdc_ref = 1*ones(1,nDFIG);
LIN_MODEL.opSpecs.il1 = 0;
LIN_MODEL.opSpecs.il2 = 0;

% Operating point defined by RUN_MODE
fprintf('=========================================================================\n')
fprintf('  OPERATING POINT CONFIGURATION\n')
fprintf('=========================================================================\n')

switch RUN_MODE
    case {0, 4, 5} % RATED: Operating point calculation, Simulation, Design sequence
        % RATED OPERATING POINT (nominal conditions)
        fprintf('RUN_MODE %d: RATED Operating Point\n', RUN_MODE)
        LIN_MODEL.opSpecs.Vp = OP_RATED.Vp;
        LIN_MODEL.opSpecs.P_ref = OP_RATED.P_ref*ones(1,nDFIG);

        % Handle SCR override
        if ~isempty(OP_RATED.SCR_grid)
            % User specified SCR - override CONFIG_MODEL value
            LIN_MODEL.MODEL.GRID.PARAM.SCR_grid = OP_RATED.SCR_grid;
            % Update all grid impedances using helper function
            LIN_MODEL.MODEL = update_grid_impedances(LIN_MODEL.MODEL);
            fprintf('  Vp = %.2f pu, P_ref = %.2f pu, SCR = %.2f (user specified)\n', ...
                OP_RATED.Vp, OP_RATED.P_ref, OP_RATED.SCR_grid)
        else
            % Use SCR from CONFIG_MODEL
            fprintf('  Vp = %.2f pu, P_ref = %.2f pu, SCR = %.2f (from CONFIG_MODEL)\n', ...
                OP_RATED.Vp, OP_RATED.P_ref, LIN_MODEL.MODEL.GRID.PARAM.SCR_grid)
        end

    case {1, 2} % LINEAR ANALYSIS: Parametric sweep
        % Multiple operating points will be defined in the loop below
        % Use RATED as base for control design
        fprintf('RUN_MODE %d: LINEAR ANALYSIS - Parametric Sweep\n', RUN_MODE)
        LIN_MODEL.opSpecs.Vp = OP_RATED.Vp;
        LIN_MODEL.opSpecs.P_ref = OP_RATED.P_ref*ones(1,nDFIG);

        % Handle SCR override for base operating point
        if ~isempty(OP_RATED.SCR_grid)
            LIN_MODEL.MODEL.GRID.PARAM.SCR_grid = OP_RATED.SCR_grid;
            LIN_MODEL.MODEL = update_grid_impedances(LIN_MODEL.MODEL);
            fprintf('  Base OP: Vp = %.2f pu, P_ref = %.2f pu, SCR = %.2f (user specified)\n', ...
                OP_RATED.Vp, OP_RATED.P_ref, OP_RATED.SCR_grid)
        else
            fprintf('  Base OP: Vp = %.2f pu, P_ref = %.2f pu, SCR = %.2f (from CONFIG_MODEL)\n', ...
                OP_RATED.Vp, OP_RATED.P_ref, LIN_MODEL.MODEL.GRID.PARAM.SCR_grid)
        end
        fprintf('  (Multiple operating points will be swept in the analysis loop)\n')

    case 3 % CONTROL OPTIMIZATION (GAM)
        % OPTIMIZATION OPERATING POINT (common for all GA phases)
        fprintf('RUN_MODE %d: OPTIMIZATION Operating Point\n', RUN_MODE)
        LIN_MODEL.opSpecs.Vp = OP_OPTIMIZATION.Vp;
        LIN_MODEL.opSpecs.P_ref = OP_OPTIMIZATION.P_ref*ones(1,nDFIG);
        % Grid SCR for optimization (always specified)
        LIN_MODEL.MODEL.GRID.PARAM.SCR_grid = OP_OPTIMIZATION.SCR_grid;
        % Update all grid impedances using helper function
        LIN_MODEL.MODEL = update_grid_impedances(LIN_MODEL.MODEL);
        fprintf('  Vp = %.2f pu, P_ref = %.2f pu, SCR = %.2f\n', ...
            OP_OPTIMIZATION.Vp, OP_OPTIMIZATION.P_ref, OP_OPTIMIZATION.SCR_grid)

    otherwise
        error('Invalid RUN_MODE = %d. Valid values: 0, 1, 2, 3, 4, 5', RUN_MODE)
end

fprintf('=========================================================================\n')

% Stator voltage reference
LIN_MODEL.opSpecs.Vs_ref = LIN_MODEL.opSpecs.Vp*ones(1,nDFIG);
% Alternative: DFIG reactive power (comment if Vs_ref is used)
% LIN_MODEL.opSpecs.Q_ref = 0*ones(1,nDFIG);

% State names and control design method
cd ../CONFIGURATION
LIN_MODEL = STATE_NAMES(LIN_MODEL);
LIN_MODEL.controlDesignMethod = '';

%--------------------------------------------------------------
%% CONTROL DESIGN (for CONTROL_TYPE 1-2)
%--------------------------------------------------------------
if CONTROL_TYPE <= 2
    cd ../CONFIGURATION

    % Define saved design filenames (in RESULTS/CONTROL/)
    if CONTROL_TYPE == 1
        saved_design_file = '../RESULTS/CONTROL/LIN_MODEL_TRD_DESIGN.mat';
        design_type_name = 'TIME-RESPONSE';
    else
        saved_design_file = '../RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat';
        design_type_name = 'FREQUENCY-RESPONSE';
    end

    % Check if saved design exists and CONTROL_REDESIGN is false
    if ~CONTROL_REDESIGN && exist(saved_design_file, 'file')
        fprintf('=========================================================================\n')
        fprintf('  Checking saved %s control design:\n', design_type_name)
        fprintf('  %s\n', saved_design_file)
        fprintf('=========================================================================\n')
        load(saved_design_file)

        % Load saved design
        if CONTROL_TYPE == 1
            LIN_MODEL_LOADED = LIN_MODEL_TRD_DESIGN;
        else
            LIN_MODEL_LOADED = LIN_MODEL_FRD_DESIGN;
        end

        % Verify compatibility (inline checks)
        is_compatible = true;
        reason = 'All parameters match';

        % Check number of DFIGs
        if LIN_MODEL_LOADED.MODEL.DFIG.PARAM.nDFIG ~= LIN_MODEL.MODEL.DFIG.PARAM.nDFIG
            is_compatible = false;
            reason = sprintf('Number of DFIGs mismatch: saved=%d, current=%d', ...
                LIN_MODEL_LOADED.MODEL.DFIG.PARAM.nDFIG, LIN_MODEL.MODEL.DFIG.PARAM.nDFIG);
        end

        % Check Grid SCR
        if is_compatible && abs(LIN_MODEL_LOADED.MODEL.GRID.PARAM.SCR_grid - LIN_MODEL.MODEL.GRID.PARAM.SCR_grid) > 1e-6
            is_compatible = false;
            reason = sprintf('Grid SCR mismatch: saved=%.3f, current=%.3f', ...
                LIN_MODEL_LOADED.MODEL.GRID.PARAM.SCR_grid, LIN_MODEL.MODEL.GRID.PARAM.SCR_grid);
        end

        % Check base voltage
        if is_compatible && abs(LIN_MODEL_LOADED.MODEL.BASE.Ub - LIN_MODEL.MODEL.BASE.Ub) > 1e-6
            is_compatible = false;
            reason = sprintf('Base voltage mismatch: saved=%.3f, current=%.3f', ...
                LIN_MODEL_LOADED.MODEL.BASE.Ub, LIN_MODEL.MODEL.BASE.Ub);
        end

        % Check base power
        if is_compatible && abs(LIN_MODEL_LOADED.MODEL.BASE.Sb - LIN_MODEL.MODEL.BASE.Sb) > 1e-6
            is_compatible = false;
            reason = sprintf('Base power mismatch: saved=%.3f, current=%.3f', ...
                LIN_MODEL_LOADED.MODEL.BASE.Sb, LIN_MODEL.MODEL.BASE.Sb);
        end

        % Check Simulink model name
        if is_compatible && ~strcmp(LIN_MODEL_LOADED.modelName, LIN_MODEL.modelName)
            is_compatible = false;
            reason = sprintf('Model name mismatch: saved=%s, current=%s', ...
                LIN_MODEL_LOADED.modelName, LIN_MODEL.modelName);
        end

        % Check operating point voltage
        if is_compatible && abs(LIN_MODEL_LOADED.opSpecs.Vp - LIN_MODEL.opSpecs.Vp) > 1e-6
            is_compatible = false;
            reason = sprintf('Operating point voltage mismatch: saved=%.3f, current=%.3f', ...
                LIN_MODEL_LOADED.opSpecs.Vp, LIN_MODEL.opSpecs.Vp);
        end

        % Check operating point power (first DFIG)
        if is_compatible && abs(LIN_MODEL_LOADED.opSpecs.P_ref(1) - LIN_MODEL.opSpecs.P_ref(1)) > 1e-6
            is_compatible = false;
            reason = sprintf('Operating point power mismatch: saved=%.3f, current=%.3f', ...
                LIN_MODEL_LOADED.opSpecs.P_ref(1), LIN_MODEL.opSpecs.P_ref(1));
        end

        % Check TRD specifications for CONTROL_TYPE=1
        if is_compatible && CONTROL_TYPE == 1
            if abs(LIN_MODEL_LOADED.CONTROL_DESIGN.VSMP.trdSpecs.ts2 - TRD_SPECS.VSMP.ts2) > 1e-6 || ...
               abs(LIN_MODEL_LOADED.CONTROL_DESIGN.VSMP.trdSpecs.Dp - TRD_SPECS.VSMP.Dp) > 1e-6 || ...
               abs(LIN_MODEL_LOADED.CONTROL_DESIGN.VSMQ.trdSpecs.DQ_absolute - TRD_SPECS.VSMQ.DQ_absolute) > 1e-6 || ...
               abs(LIN_MODEL_LOADED.CONTROL_DESIGN.RSC.trdSpecs.ts2 - TRD_SPECS.RSC.ts2) > 1e-6 || ...
               abs(LIN_MODEL_LOADED.CONTROL_DESIGN.VDC.trdSpecs.ts2 - TRD_SPECS.VDC.ts2) > 1e-6 || ...
               abs(LIN_MODEL_LOADED.CONTROL_DESIGN.GSC.trdSpecs.ts2 - TRD_SPECS.GSC.ts2) > 1e-6
                is_compatible = false;
                reason = 'TRD specifications mismatch (settling times, damping ratios, Dp, or DQ changed)';
            end
        end

        % Check FRD specifications for CONTROL_TYPE=2
        if is_compatible && CONTROL_TYPE == 2
            if abs(LIN_MODEL_LOADED.CONTROL_DESIGN.VSMP.frdSpecs.Fm - FRD_SPECS.VSMP.Fm) > 1e-6 || ...
               abs(LIN_MODEL_LOADED.CONTROL_DESIGN.VSMP.frdSpecs.wo - FRD_SPECS.VSMP.wo) > 1e-6 || ...
               abs(LIN_MODEL_LOADED.CONTROL_DESIGN.VDC.frdSpecs.Fm - FRD_SPECS.VDC.Fm) > 1e-6 || ...
               abs(LIN_MODEL_LOADED.CONTROL_DESIGN.VDC.frdSpecs.wo - FRD_SPECS.VDC.wo) > 1e-6
                is_compatible = false;
                reason = 'FRD specifications mismatch (phase margins or crossover frequencies changed)';
            end
        end

        if is_compatible
            % Perfect match - reuse saved design
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('  COMPATIBLE: %s\n', reason)
            fprintf('  Reusing saved design without relinearization\n')
            fprintf('=========================================================================\n')
            LIN_MODEL = LIN_MODEL_LOADED;
            disp(LIN_MODEL)
        else
            % Incompatible - must redesign
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('  INCOMPATIBLE: %s\n', reason)
            fprintf('  Redesigning and REPLACING saved design\n')
            fprintf('=========================================================================\n')
            CONTROL_REDESIGN = true;
        end
    end

    % Redesign control if needed
    if CONTROL_REDESIGN || ~exist(saved_design_file, 'file')
        if ~exist(saved_design_file, 'file')
            fprintf('=========================================================================\n')
            fprintf('  No saved design found. Designing %s control...\n', design_type_name)
            fprintf('=========================================================================\n')
        elseif CONTROL_REDESIGN && ~exist('is_compatible', 'var')
            fprintf('=========================================================================\n')
            fprintf('  CONTROL_REDESIGN = true: Forcing %s control redesign\n', design_type_name)
            fprintf('=========================================================================\n')
        end
        % Note: If is_compatible exists and is false, message was already printed above

        cd ../CONTROL

        %--------------------------------------------------------------------------
        % VIRTUAL IMPEDANCE
        %--------------------------------------------------------------------------
        LIN_MODEL.CONTROL.VIMP.PARAM.Lv_pu = VIMP_Lv_pu*ones(1,nDFIG);
        LIN_MODEL.CONTROL.VIMP.PARAM.Rv_pu = VIMP_Rv_pu*ones(1,nDFIG);

        %--------------------------------------------------------------------------
        % TIME-RESPONSE CONTROLLER DESIGN SPECIFICATIONS
        %--------------------------------------------------------------------------
        % Copy all TRD specifications to LIN_MODEL for control design algorithms
        LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.ts2 = TRD_SPECS.VSMP.ts2;
        LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.seta = TRD_SPECS.VSMP.seta;
        LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.Dp = TRD_SPECS.VSMP.Dp;

        LIN_MODEL.CONTROL_DESIGN.VSMQ.trdSpecs.ts2 = TRD_SPECS.VSMQ.ts2;
        LIN_MODEL.CONTROL_DESIGN.VSMQ.trdSpecs.DQ_absolute = TRD_SPECS.VSMQ.DQ_absolute;

        LIN_MODEL.CONTROL_DESIGN.RSC.trdSpecs.ts2 = TRD_SPECS.RSC.ts2;
        LIN_MODEL.CONTROL_DESIGN.RSC.trdSpecs.seta = TRD_SPECS.RSC.seta;

        LIN_MODEL.CONTROL_DESIGN.VDC.trdSpecs.ts2 = TRD_SPECS.VDC.ts2;
        LIN_MODEL.CONTROL_DESIGN.VDC.trdSpecs.seta = TRD_SPECS.VDC.seta;

        LIN_MODEL.CONTROL_DESIGN.GSC.trdSpecs.ts2 = TRD_SPECS.GSC.ts2;
        LIN_MODEL.CONTROL_DESIGN.GSC.trdSpecs.seta = TRD_SPECS.GSC.seta;

        % Stability margin calculation specifications
        LIN_MODEL.CONTROL_DESIGN.STABILITY_MARGINS = TRD_SPECS.STABILITY_MARGINS;

        LIN_MODEL.CONTROL_DESIGN.selectedDFIG = FRD_selectedDFIG;
        disp('TIME-RESPONSE CONTROL DESIGN')
        cd ../CONTROL
        LIN_MODEL = CONTROL_DESIGN_TR(LIN_MODEL);

        % Save TRD design (for both CONTROL_TYPE 1 and 2)
        cd ../RESULTS/CONTROL
        % Create directory if it doesn't exist
        if ~exist('.', 'dir')
            mkdir('.')
        end
        fprintf('-------------------------------------------------------------------------\n')
        fprintf('Saving TIME-RESPONSE control design to:\n')
        fprintf('RESULTS/CONTROL/LIN_MODEL_TRD_DESIGN.mat\n')
        fprintf('-------------------------------------------------------------------------\n')
        LIN_MODEL_TRD_DESIGN = LIN_MODEL;
        save('LIN_MODEL_TRD_DESIGN.mat', 'LIN_MODEL_TRD_DESIGN')

        %--------------------------------------------------------------------------
        % FREQUENCY-RESPONSE CONTROLLER DESIGN (only if CONTROL_TYPE = 2)
        %--------------------------------------------------------------------------
        if CONTROL_TYPE == 2
            cd ../../CONTROL

            LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.Fm = FRD_SPECS.VSMP.Fm;
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.wo = FRD_SPECS.VSMP.wo;
            LIN_MODEL.CONTROL_DESIGN.VSMQ.frdSpecs.wo = FRD_SPECS.VSMQ.wo;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.Fm = FRD_SPECS.RSC.Fm;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.wo = FRD_SPECS.RSC.wo;
            LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.Fm = FRD_SPECS.VDC.Fm;
            LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.wo = FRD_SPECS.VDC.wo;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.Fm = FRD_SPECS.GSC.Fm;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.wo = FRD_SPECS.GSC.wo;

            % Design sequence: 1-VSMP | 2-VSMQ | 3-RSCd | 4-RSCq | 5-VDC | 6-GSCd | 7-GSCq
            LIN_MODEL.CONTROL_DESIGN.designOrder = FRD_designOrder;
            LIN_MODEL.CONTROL_DESIGN.selectedDFIG = FRD_selectedDFIG;

            disp('FREQUENCY-RESPONSE CONTROL DESIGN:')
            % Initialize convergence tracking structure
            CONVERGENCE_DATA = struct();
            CONVERGENCE_DATA.N_iter = FRD_N_iter;
            CONVERGENCE_DATA.iterations = cell(1, FRD_N_iter);

            for ii = 1:FRD_N_iter
                fprintf('\n========== ITERATION %d/%d ==========\n', ii, FRD_N_iter);

                % Ensure we're in CONTROL directory before each iteration
                config_dir = pwd;
                if contains(config_dir, 'CONFIGURATION')
                    cd ../CONTROL
                elseif contains(config_dir, 'RESULTS')
                    cd ../../CONTROL
                end

                LIN_MODEL = CONTROL_DESIGN_FR(LIN_MODEL,true);

                % Save margins for this iteration
                CONVERGENCE_DATA.iterations{ii}.VSMP.Fm = LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.Fm;
                CONVERGENCE_DATA.iterations{ii}.VSMP.wo = LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.wo;
                CONVERGENCE_DATA.iterations{ii}.VSMQ.Fm = LIN_MODEL.CONTROL_DESIGN.VSMQ.frdMargins.Fm;
                CONVERGENCE_DATA.iterations{ii}.VSMQ.wo = LIN_MODEL.CONTROL_DESIGN.VSMQ.frdMargins.wo;
                CONVERGENCE_DATA.iterations{ii}.RSCd.Fm = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm(1);
                CONVERGENCE_DATA.iterations{ii}.RSCd.wo = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.wo(1);
                CONVERGENCE_DATA.iterations{ii}.RSCq.Fm = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm(2);
                CONVERGENCE_DATA.iterations{ii}.RSCq.wo = LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.wo(2);
                CONVERGENCE_DATA.iterations{ii}.VDC.Fm = LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.Fm;
                CONVERGENCE_DATA.iterations{ii}.VDC.wo = LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.wo;
                CONVERGENCE_DATA.iterations{ii}.GSCd.Fm = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm(1);
                CONVERGENCE_DATA.iterations{ii}.GSCd.wo = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.wo(1);
                CONVERGENCE_DATA.iterations{ii}.GSCq.Fm = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm(2);
                CONVERGENCE_DATA.iterations{ii}.GSCq.wo = LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.wo(2);
            end

            % Save target specifications for convergence analysis
            CONVERGENCE_DATA.targets.VSMP.Fm = FRD_SPECS.VSMP.Fm;
            CONVERGENCE_DATA.targets.VSMP.wo = FRD_SPECS.VSMP.wo;
            % VSMQ: Only wo target (proportional controller, no Fm target)
            CONVERGENCE_DATA.targets.VSMQ.wo = FRD_SPECS.VSMQ.wo;
            CONVERGENCE_DATA.targets.RSCd.Fm = FRD_SPECS.RSC.Fm(1);
            CONVERGENCE_DATA.targets.RSCd.wo = FRD_SPECS.RSC.wo(1);
            CONVERGENCE_DATA.targets.RSCq.Fm = FRD_SPECS.RSC.Fm(2);
            CONVERGENCE_DATA.targets.RSCq.wo = FRD_SPECS.RSC.wo(2);
            CONVERGENCE_DATA.targets.VDC.Fm = FRD_SPECS.VDC.Fm;
            CONVERGENCE_DATA.targets.VDC.wo = FRD_SPECS.VDC.wo;
            CONVERGENCE_DATA.targets.GSCd.Fm = FRD_SPECS.GSC.Fm(1);
            CONVERGENCE_DATA.targets.GSCd.wo = FRD_SPECS.GSC.wo(1);
            CONVERGENCE_DATA.targets.GSCq.Fm = FRD_SPECS.GSC.Fm(2);
            CONVERGENCE_DATA.targets.GSCq.wo = FRD_SPECS.GSC.wo(2);

            % Save FRD design
            cd ../RESULTS/CONTROL
            % Create directory if it doesn't exist
            if ~exist('.', 'dir')
                mkdir('.')
            end
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('Saving FREQUENCY-RESPONSE control design to:\n')
            fprintf('RESULTS/CONTROL/LIN_MODEL_FRD_DESIGN.mat\n')
            fprintf('RESULTS/CONTROL/CONVERGENCE_DATA.mat\n')
            fprintf('-------------------------------------------------------------------------\n')
            LIN_MODEL_FRD_DESIGN = LIN_MODEL;
            save('LIN_MODEL_FRD_DESIGN.mat', 'LIN_MODEL_FRD_DESIGN')
            save('CONVERGENCE_DATA.mat', 'CONVERGENCE_DATA')
        end
        % Return to CONFIGURATION directory
        cd ../../CONFIGURATION
    end
end

%--------------------------------------------------------------
%% CONTROL TYPE SELECTION
%--------------------------------------------------------------
clc

% Helper function for loading optimized models
load_optimized_model = @(filename) load_and_merge_model(filename, LIN_MODEL);

switch CONTROL_TYPE
    case 1 % TIME-RESPONSE CONTROL DESIGN
        cd ../CONTROL
        LIN_MODEL = CONTROL_DESIGN_TR(LIN_MODEL);
        disp('Initial operating point based for time-response control design')
        disp(LIN_MODEL)
        cd ../SIMULINK

    case 2 % FREQUENCY-RESPONSE CONTROL DESIGN
        disp('Initial operating point based on frequency-response control design')
        disp(LIN_MODEL)
        cd ../SIMULINK

    case 3 % FR OPTIMUM DESIGN SPECS FOR ACTIVE POWER
        disp('Initial operating point based on frequency-response control design for active power')
        LIN_MODEL = load_optimized_model('../RESULTS/CONTROL/LIN_MODEL_PDS_OPT.mat');
        cd ../SIMULINK

    case 4 % FR OPTIMUM DESIGN SPECS FOR REACTIVE POWER
        disp('Initial operating point based on optimum of frequency-response control design for active power')
        LIN_MODEL = load_optimized_model('../RESULTS/CONTROL/LIN_MODEL_QDS_OPT.mat');
        cd ../SIMULINK

    case 5 % CONTROL PARAMETER OPTIMUM FOR ACTIVE POWER
        disp('Initial operating point based on optimum of frequency-response control design for active power')
        LIN_MODEL = load_optimized_model('../RESULTS/CONTROL/LIN_MODEL_PCP_OPT.mat');
        cd ../SIMULINK

    case 6 % CONTROL PARAMETER OPTIMUM FOR REACTIVE POWER
        disp('Initial operating point based on optimum of frequency-response control design for active power')
        LIN_MODEL = load_optimized_model('../RESULTS/CONTROL/LIN_MODEL_QCP_OPT.mat');
        cd ../SIMULINK

    case 7 % VIRTUAL IMPEDANCE OPTIMUM
        disp('Initial operating point based on optimum of frequency-response control design for active power')
        LIN_MODEL = load_optimized_model('../RESULTS/CONTROL/LIN_MODEL_VI_OPT.mat');
        cd ../SIMULINK

    otherwise
        error('Invalid CONTROL_TYPE. Valid values: 1-7')
end

%--------------------------------------------------------------
%% BUS DEFINITIONS UPDATE & WORKSPACE INITIALIZATION
%--------------------------------------------------------------
cd ../BUS_DEFINITIONS
BusDefinition(LIN_MODEL.MODEL,'MODEL_Bus')
BusDefinition(LIN_MODEL.CONTROL,'CONTROL_Bus')

% Assign CONTROL and MODEL to base workspace for Simulink
assignin('base', 'CONTROL', LIN_MODEL.CONTROL);
assignin('base', 'MODEL', LIN_MODEL.MODEL);

cd ../CONTROL

%--------------------------------------------------------------
%% RUN_MODE EXECUTION
%--------------------------------------------------------------
clc
nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;

% Ensure breaker_ts exists in base workspace for Simulink model compilation
% (breaker_status_src From Workspace block requires this variable)
if ~evalin('base', 'exist(''breaker_ts'',''var'')')
    breaker_ts_tmp.time = [0; 100];
    breaker_ts_tmp.signals.values = ones(1, nDFIG, 2);
    breaker_ts_tmp.signals.dimensions = [1, nDFIG];
    assignin('base', 'breaker_ts', breaker_ts_tmp);
    clear breaker_ts_tmp
    fprintf('  [INFO] Created breaker_ts in base workspace (nDFIG=%d)\n', nDFIG)
end

switch RUN_MODE
    %-------------------------------------
    case 0 % OPERATING POINT ONLY
    %-------------------------------------
        disp('=========================================================================')
        disp('                    OPERATING POINT CONFIGURATION                        ')
        disp('=========================================================================')
        disp(LIN_MODEL)
        cd ../SIMULINK

    %-------------------------------------
    case {1,2} % LINEAR ANALYSIS - PARAMETRIC SWEEP
    %-------------------------------------
        % Performs linear analysis across multiple operating points to evaluate
        % system stability and performance over a range of conditions.
        %
        % RUN_MODE = 1: ENDPOINT ANALYSIS (2×2×2 = 8 operating points)
        %   - Quick stability boundary verification at extreme conditions
        %   - Vp: [0.95, 1.05] pu, Pdfig: [0.8, 1.0] pu, SCR: [1, 3]
        %   - Execution time: ~16 min sequential, ~2 min parallel (8 workers)
        %   - Includes automatic plotting (PLOT_LIN_MODEL_ARRAY)
        %
        % RUN_MODE = 2: COMPREHENSIVE SWEEP (5×9×5 = 225 operating points)
        %   - Detailed stability map generation for complete operating envelope
        %   - Vp: [0.95-1.05] pu (5 points), Pdfig: [0.4-1.2] pu (9 points), SCR: [1-3] (5 points)
        %   - Execution time: ~7.5 hours sequential, ~1 hour parallel (8 workers)
        %   - No automatic plotting (use PLOT_LIN_MODEL_ARRAY manually if needed)

        cd ../CONFIGURATION

        % Define operating point spans based on analysis mode
        if RUN_MODE == 1
            % ENDPOINT ANALYSIS: Test stability boundaries with user-defined ranges
            VpSpan = linspace(ENDPOINT_Vp_min, ENDPOINT_Vp_max, 2);
            PdfigSpan = linspace(ENDPOINT_Pdfig_min, ENDPOINT_Pdfig_max, 2);
            gridSCRSpan = linspace(ENDPOINT_SCR_min, ENDPOINT_SCR_max, 2);
            fprintf('=========================================================================\n')
            fprintf('  RUN_MODE 1: ENDPOINT ANALYSIS\n')
            fprintf('=========================================================================\n')
            fprintf('Testing %d operating points (2×2×2 combinations)\n', 2*2*2)
        else
            % COMPREHENSIVE SWEEP: Full operating envelope with user-defined ranges
            VpSpan = linspace(SWEEP_Vp_min, SWEEP_Vp_max, SWEEP_Vp_points);
            PdfigSpan = linspace(SWEEP_Pdfig_min, SWEEP_Pdfig_max, SWEEP_Pdfig_points);
            gridSCRSpan = linspace(SWEEP_SCR_min, SWEEP_SCR_max, SWEEP_SCR_points);
            fprintf('=========================================================================\n')
            fprintf('  RUN_MODE 2: COMPREHENSIVE SWEEP\n')
            fprintf('=========================================================================\n')
            fprintf('Testing %d operating points (%d×%d×%d combinations)\n', ...
                SWEEP_Vp_points*SWEEP_Pdfig_points*SWEEP_SCR_points, ...
                SWEEP_Vp_points, SWEEP_Pdfig_points, SWEEP_SCR_points)
        end
        fprintf('  Vp range: [%.2f, %.2f] pu (%d points)\n', min(VpSpan), max(VpSpan), length(VpSpan))
        fprintf('  Pdfig range: [%.2f, %.2f] pu (%d points)\n', min(PdfigSpan), max(PdfigSpan), length(PdfigSpan))
        fprintf('  SCR range: [%.0f, %.0f] (%d points)\n', min(gridSCRSpan), max(gridSCRSpan), length(gridSCRSpan))
        fprintf('=========================================================================\n')

        % Generate all operating point combinations
        OPset = combinations(VpSpan,PdfigSpan,gridSCRSpan);
        num_ops = size(OPset,1);

        % Create base model for iteration (single copy)
        LIN_MODEL_IN = LIN_MODEL;

        %----------------------------------------------------------------------
        % AUTO-DETECT OPTIMAL PARALLELIZATION STRATEGY
        %----------------------------------------------------------------------
        if LINEAR_ANALYSIS_numWorkers == -1
            % Automatic selection based on number of operating points
            % Threshold: ~20-25 points (parallelization overhead ~20s)
            if num_ops <= 20
                LINEAR_ANALYSIS_numWorkers = 0;  % Sequential for small sweeps
                fprintf('AUTO-DETECT: Using SEQUENTIAL mode (%d points, estimated ~%.1f sec)\n', ...
                    num_ops, num_ops*1.5)
            else
                LINEAR_ANALYSIS_numWorkers = 8;  % Parallel for large sweeps
                fprintf('AUTO-DETECT: Using PARALLEL mode with 8 workers (%d points, estimated ~%.1f sec)\n', ...
                    num_ops, num_ops*0.5 + 20)
            end
            fprintf('  To override: Set LINEAR_ANALYSIS_numWorkers = 0 (sequential) or 8 (parallel)\n')
            fprintf('-------------------------------------------------------------------------\n')
        end

        %----------------------------------------------------------------------
        % PERFORMANCE WARNING: Inefficient parallelization
        %----------------------------------------------------------------------
        if LINEAR_ANALYSIS_numWorkers > 0 && num_ops <= 20
            fprintf('=========================================================================\n')
            fprintf('⚠️  PERFORMANCE WARNING: Parallelization inefficient for %d points\n', num_ops)
            fprintf('=========================================================================\n')
            fprintf('Parallel overhead (~20s) exceeds benefit for small sweeps.\n')
            fprintf('MEASURED PERFORMANCE (RUN_MODE=1, 8 points):\n')
            fprintf('  Sequential: 12 seconds  |  Parallel: 53 seconds  (2.8× SLOWER)\n')
            fprintf('\n')
            fprintf('RECOMMENDATION: Set LINEAR_ANALYSIS_numWorkers = 0 for faster execution\n')
            fprintf('=========================================================================\n')
            fprintf('Continuing with PARALLEL mode (user override)...\n')
            fprintf('=========================================================================\n')
        end

        % Parallel processing setup
        if LINEAR_ANALYSIS_numWorkers > 0
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('PARALLEL MODE: Starting parallel pool with %d workers...\n', LINEAR_ANALYSIS_numWorkers)
            fprintf('-------------------------------------------------------------------------\n')

            % Create parallel pool if not already active
            poolobj = gcp('nocreate');
            if isempty(poolobj)
                parpool('local', LINEAR_ANALYSIS_numWorkers);
                poolobj = gcp('nocreate');
            elseif poolobj.NumWorkers ~= LINEAR_ANALYSIS_numWorkers
                delete(poolobj);
                parpool('local', LINEAR_ANALYSIS_numWorkers);
                poolobj = gcp('nocreate');
            end

            % Create Simulink model copies for each worker
            cd ../SIMULINK
            fprintf('Creating Simulink model copies for parallel workers...\n')
            for w = 1:LINEAR_ANALYSIS_numWorkers
                worker_model = [modelName '_' num2str(w)];
                if ~bdIsLoaded(worker_model)
                    if ~exist([worker_model '.slx'], 'file')
                        load_system(modelName);
                        save_system(modelName, worker_model);
                        close_system(modelName);
                        fprintf('  Created: %s.slx\n', worker_model)
                    end
                end
            end
            cd ../CONFIGURATION
            fprintf('Model copies ready for parallel processing\n')
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('Starting parallel linear analysis sweep...\n')
            fprintf('-------------------------------------------------------------------------\n')

            % Convert OPset table to array for parfor compatibility
            VpArray = OPset{:,'VpSpan'};
            PdfigArray = OPset{:,'PdfigSpan'};
            SCRArray = OPset{:,'gridSCRSpan'};

            % Pre-allocate results cell array for parfor
            LIN_MODEL_results = cell(num_ops,1);

            % Start timing
            analysis_start_time = tic;

            % Create progress monitoring queue for real-time updates
            progressQueue = parallel.pool.DataQueue;
            progress_data = struct('completed', 0, 'start_time', analysis_start_time, 'total', num_ops);

            % Setup callback for progress updates (executes each time a worker sends data)
            afterEach(progressQueue, @(data) fprintf('[Progress] %3d/%d (%5.1f%%) | Elapsed: %5.1fs | ETA: %5.1fs | Avg: %.2fs/OP\n', ...
                data.completed, data.total, data.percent, data.elapsed, data.remaining, data.avg_time));

            fprintf('Progress monitoring enabled (real-time updates from parallel workers)\n');
            fprintf('-------------------------------------------------------------------------\n');

            % Parallel computation loop
            parfor (nn = 1:num_ops, LINEAR_ANALYSIS_numWorkers)
                % CRITICAL: Generate bus definitions in worker's own workspace
                % Each parallel worker needs its own MODEL_Bus and CONTROL_Bus
                % This matches the pattern used in OPTIMIZER.m and GEN_LIN_MODEL_PARETO.m
                warning('off')
                cd '../BUS_DEFINITIONS'
                BusDefinition(LIN_MODEL_IN.CONTROL,'CONTROL_Bus')
                BusDefinition(LIN_MODEL_IN.MODEL,'MODEL_Bus')
                cd '../CONFIGURATION'

                % Create independent copy for this worker
                LIN_MODEL_TEMP = LIN_MODEL_IN;

                % Update operating point parameters using array indexing
                LIN_MODEL_TEMP.opSpecs.Vp = VpArray(nn);
                LIN_MODEL_TEMP.opSpecs.P_ref = PdfigArray(nn)*ones(1,nDFIG);

                % Update grid SCR and recalculate impedances
                LIN_MODEL_TEMP.MODEL.GRID.PARAM.SCR_grid = SCRArray(nn);
                LIN_MODEL_TEMP.MODEL = update_grid_impedances(LIN_MODEL_TEMP.MODEL);

                % Get ACTUAL worker ID (not iteration-based, but physical worker ID)
                % This is critical for parallel execution with Simulink models
                task = getCurrentTask();
                if ~isempty(task)
                    workerID = task.ID;  % Use actual worker thread ID (1-8)
                else
                    workerID = 1;  % Fallback for sequential execution
                end

                % Perform linear analysis with worker-specific model
                LIN_MODEL_results{nn} = LINEAR_ANALYSIS(LIN_MODEL_TEMP, workerID);

                % Send progress update to main process
                % Calculate progress metrics (note: nn is not sequential order in parallel)
                send(progressQueue, struct('completed', nn, 'total', num_ops, ...
                    'percent', 100*nn/num_ops, 'elapsed', toc(analysis_start_time), ...
                    'remaining', (num_ops-nn)*toc(analysis_start_time)/nn, ...
                    'avg_time', toc(analysis_start_time)/nn));
            end

            % End timing
            analysis_elapsed_time = toc(analysis_start_time);

            fprintf('-------------------------------------------------------------------------\n')
            fprintf('Parallel processing complete\n')
            fprintf('Elapsed time: %.2f seconds (%.2f minutes)\n', analysis_elapsed_time, analysis_elapsed_time/60)
            fprintf('Average time per OP: %.2f seconds\n', analysis_elapsed_time/num_ops)
            fprintf('-------------------------------------------------------------------------\n')

            % Build final results structure
            LIN_MODEL_ARRAY.OPset = OPset;
            LIN_MODEL_ARRAY.LIN_MODEL = LIN_MODEL_results;

            % Cleanup: Close and delete temporary Simulink model copies
            fprintf('Cleaning up temporary Simulink model copies...\n')
            cd ../SIMULINK
            bdclose('all');  % Close all Simulink models
            for w = 1:LINEAR_ANALYSIS_numWorkers
                worker_model = [modelName '_' num2str(w)];
                % Delete all worker-related files: .slx, .slxc, and backup files
                worker_files = dir([worker_model '.*']);
                for f = 1:length(worker_files)
                    delete(fullfile(worker_files(f).folder, worker_files(f).name));
                    fprintf('  Deleted: %s\n', worker_files(f).name)
                end
            end
            cd ../CONFIGURATION
            fprintf('Cleanup complete\n')
            fprintf('-------------------------------------------------------------------------\n')

        else
            % Sequential computation (original implementation)
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('SEQUENTIAL MODE: Starting linear analysis sweep...\n')
            fprintf('-------------------------------------------------------------------------\n')

            % Pre-allocate results structure
            LIN_MODEL_ARRAY.OPset = OPset;
            LIN_MODEL_ARRAY.LIN_MODEL = cell(num_ops,1);

            % Start timing
            analysis_start_time = tic;

            for nn = 1:num_ops
                fprintf('OP %d/%d: [Vpcc=%.3f, Pdfig=%.2f, SCR=%.1f]\n',...
                    nn, num_ops, OPset{nn,'VpSpan'}, OPset{nn,'PdfigSpan'}, OPset{nn,'gridSCRSpan'})

                % Update operating point parameters (no redundant copy)
                LIN_MODEL_IN.opSpecs.Vp = OPset{nn,'VpSpan'};
                LIN_MODEL_IN.opSpecs.P_ref = OPset{nn,'PdfigSpan'}*ones(1,nDFIG);

                % Update grid SCR and recalculate impedances
                LIN_MODEL_IN.MODEL.GRID.PARAM.SCR_grid = OPset{nn,'gridSCRSpan'};
                LIN_MODEL_IN.MODEL = update_grid_impedances(LIN_MODEL_IN.MODEL);

                % Perform linear analysis for this operating point
                LIN_MODEL_ARRAY.LIN_MODEL{nn} = LINEAR_ANALYSIS(LIN_MODEL_IN);

                % Display results summary
                display(LIN_MODEL_ARRAY.LIN_MODEL{nn})
                fprintf('-------------------------------------------------------------------------\n')
            end

            % End timing
            analysis_elapsed_time = toc(analysis_start_time);

            fprintf('=========================================================================\n')
            fprintf('Sequential processing complete\n')
            fprintf('Elapsed time: %.2f seconds (%.2f minutes)\n', analysis_elapsed_time, analysis_elapsed_time/60)
            fprintf('Average time per OP: %.2f seconds\n', analysis_elapsed_time/num_ops)
            fprintf('=========================================================================\n')
        end

        % Rename table variables for clarity in results
        LIN_MODEL_ARRAY.OPset = renamevars(LIN_MODEL_ARRAY.OPset,...
                                   ["VpSpan","PdfigSpan","gridSCRSpan"],...
                                   ["Vpcc","Pdfig","SCRgrid"]);

        % Close parallel pool if it was used
        if LINEAR_ANALYSIS_numWorkers > 0
            poolobj = gcp('nocreate');
            if ~isempty(poolobj)
                delete(poolobj);
                fprintf('Parallel pool closed\n')
            end
        end

        % Clean up temporary loop variables
        clear OPset VpSpan PdfigSpan gridSCRSpan MODEL CONTROL nn num_ops
        if LINEAR_ANALYSIS_numWorkers > 0
            clear VpArray PdfigArray SCRArray LIN_MODEL_results poolobj
        end

        % Save results with descriptive filename
        % NOTE: mkdir BEFORE cd. The previous form did `cd` first and then
        % tested `~exist('.','dir')`, which asks whether the CURRENT folder
        % exists -- always true once the cd has succeeded, and unreachable
        % when it has not. RESULTS/ subfolders other than CONTROL are output
        % and are not versioned, so on a fresh clone this threw
        % MATLAB:cd:NonExistentFolder AFTER the whole 225-point sweep had run,
        % discarding every result at the save step.
        outDir = fullfile('..', 'RESULTS', 'LINEAR_ANALYSIS');
        if ~exist(outDir, 'dir'); mkdir(outDir); end
        cd(outDir)

        % Generate descriptive filename with timestamp
        timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');

        % Determine control type name
        control_name = '';
        switch CONTROL_TYPE
            case 1, control_name = 'TRD';
            case 2, control_name = 'FRD';
            case 3, control_name = 'PDS_OPT';
            case 4, control_name = 'QDS_OPT';
            case 5, control_name = 'PCP_OPT';
            case 6, control_name = 'QCP_OPT';
            case 7, control_name = 'VI_OPT';
        end

        % Determine analysis type
        if RUN_MODE == 1
            analysis_type = 'ENDPOINTS';
        else
            analysis_type = 'SWEEP';
        end

        % Validate LIN_MODEL_ARRAY before saving
        if ~exist('LIN_MODEL_ARRAY', 'var') || ~isfield(LIN_MODEL_ARRAY, 'LIN_MODEL') || isempty(LIN_MODEL_ARRAY.LIN_MODEL)
            error('LINEAR_ANALYSIS failed: LIN_MODEL_ARRAY is empty or incomplete. No results to save.');
        end

        % Get actual number of points from results
        actual_num_points = length(LIN_MODEL_ARRAY.LIN_MODEL);

        nDFIG_str = sprintf('%dDFIG', nDFIG);
        results_filename = sprintf('LINEAR_ANALYSIS_%s_%s_%s_%s.mat', ...
            timestamp, analysis_type, control_name, nDFIG_str);

        fprintf('=========================================================================\n')
        fprintf('Saving linear analysis results (%d operating points)\n', actual_num_points)
        fprintf('  File: %s\n', results_filename)
        fprintf('  Location: RESULTS/LINEAR_ANALYSIS/\n')
        fprintf('=========================================================================\n')

        % Save complete analysis results (use -v7.3 for large datasets)
        save(results_filename, 'LIN_MODEL_ARRAY', 'RUN_MODE', 'CONTROL_TYPE', 'nDFIG', 'timestamp', '-v7.3')

        % Generate plots for RUN_MODE=1 (endpoint analysis only)
        if RUN_MODE == 1
            fprintf('Generating stability analysis plots...\n')
            fprintf('-------------------------------------------------------------------------\n')
            cd ../../PLOT_FILES
            % Construct slug from filename (remove 'LINEAR_ANALYSIS_' prefix and '.mat' suffix)
            slug = strrep(strrep(results_filename, 'LINEAR_ANALYSIS_', ''), '.mat', '');
            PLOT_LIN_MODEL_ARRAY(slug, 2)
            cd ../SIMULINK
        else
            fprintf('Sweep complete. Use PLOT_LIN_MODEL_ARRAY manually to visualize results.\n')
            fprintf('  Example: PLOT_LIN_MODEL_ARRAY(''%s'', 2)\n', ...
                strrep(strrep(results_filename, 'LINEAR_ANALYSIS_', ''), '.mat', ''))
            fprintf('=========================================================================\n')
            cd ../../SIMULINK
        end

    %-------------------------------------
    case 3 % CONTROL OPTIMIZATION (GAM)
    %-------------------------------------
        fprintf('=========================================================================\n')
        fprintf('  GENETIC ALGORITHM MULTI-OBJECTIVE OPTIMIZATION\n')
        fprintf('=========================================================================\n')
        fprintf('Optimization operating point: Vp=%.2f pu, P_ref=%.2f pu, SCR=%.1f\n', ...
            OP_OPTIMIZATION.Vp, OP_OPTIMIZATION.P_ref, OP_OPTIMIZATION.SCR_grid)
        fprintf('-------------------------------------------------------------------------\n')
        fprintf('Optimization sequence: %s\n', mat2str(OPT_SEQUENCE))
        fprintf('Initialization: INIT_STEP = %d\n', INIT_STEP)

        if INIT_STEP == 0
            fprintf('  First step (%s) will use FRD baseline (LIN_MODEL_FRD_OPT.mat)\n', OPT_PHASE_NAMES{OPT_SEQUENCE(1)})
        else
            fprintf('  First step (%s) will use %s.mat\n', ...
                OPT_PHASE_NAMES{OPT_SEQUENCE(1)}, OPT_PHASE_CONFIG.(OPT_PHASE_NAMES{INIT_STEP}).filename)
        end
        fprintf('  Subsequent steps inherit parameters from previous step in sequence\n')
        fprintf('=========================================================================\n')

        cd ../CONFIGURATION

        %----------------------------------------------------------------------
        % INITIALIZATION: Load or create initial control for first step
        %----------------------------------------------------------------------
        if INIT_STEP == 0
            % Create/update LIN_MODEL_FRD_OPT.mat with optimization operating point
            frd_opt_file = '../RESULTS/CONTROL/LIN_MODEL_FRD_OPT.mat';
            needs_update = true;

            if exist(frd_opt_file, 'file')
                fprintf('-------------------------------------------------------------------------\n')
                fprintf('Validating existing LIN_MODEL_FRD_OPT.mat\n')
                fprintf('-------------------------------------------------------------------------\n')
                load(frd_opt_file)

                % Check operating point and model compatibility
                [is_compatible, compatibility_msg] = check_optimization_compatibility(...
                    LIN_MODEL_FRD_OPT, LIN_MODEL, OP_OPTIMIZATION, true);

                if is_compatible
                    fprintf('  COMPATIBLE: Reusing existing LIN_MODEL_FRD_OPT.mat\n')
                    fprintf('  OP: Vp=%.2f, P_ref=%.2f, SCR=%.1f, nDFIG=%d\n', ...
                        LIN_MODEL_FRD_OPT.opSpecs.Vp, LIN_MODEL_FRD_OPT.opSpecs.P_ref(1), ...
                        LIN_MODEL_FRD_OPT.MODEL.GRID.PARAM.SCR_grid, LIN_MODEL_FRD_OPT.MODEL.DFIG.PARAM.nDFIG)
                    fprintf('-------------------------------------------------------------------------\n')
                    needs_update = false;
                    LIN_MODEL_INIT = LIN_MODEL_FRD_OPT;
                else
                    fprintf('  INCOMPATIBLE: %s\n', compatibility_msg)
                    fprintf('  Current OP: Vp=%.2f, P_ref=%.2f, SCR=%.1f, nDFIG=%d\n', ...
                        OP_OPTIMIZATION.Vp, OP_OPTIMIZATION.P_ref, OP_OPTIMIZATION.SCR_grid, nDFIG)
                    fprintf('  Saved OP:   Vp=%.2f, P_ref=%.2f, SCR=%.1f, nDFIG=%d\n', ...
                        LIN_MODEL_FRD_OPT.opSpecs.Vp, LIN_MODEL_FRD_OPT.opSpecs.P_ref(1), ...
                        LIN_MODEL_FRD_OPT.MODEL.GRID.PARAM.SCR_grid, LIN_MODEL_FRD_OPT.MODEL.DFIG.PARAM.nDFIG)
                    fprintf('-------------------------------------------------------------------------\n')
                end
            end

            if needs_update
                fprintf('-------------------------------------------------------------------------\n')
                fprintf('Creating LIN_MODEL_FRD_OPT.mat with optimization operating point\n')
                fprintf('-------------------------------------------------------------------------\n')

                % Start from current LIN_MODEL (already has optimization OP from lines 327-337)
                LIN_MODEL_INIT = LIN_MODEL;

                % Design FRD control with optimization operating point
                cd ../CONTROL
                LIN_MODEL_INIT = CONTROL_DESIGN_FR(LIN_MODEL_INIT, true);

                % Save to RESULTS/CONTROL
                cd ../RESULTS/CONTROL
                if ~exist('.', 'dir'), mkdir('.'); end

                LIN_MODEL_FRD_OPT = LIN_MODEL_INIT;
                save('LIN_MODEL_FRD_OPT.mat', 'LIN_MODEL_FRD_OPT')
                fprintf('  Saved: RESULTS/CONTROL/LIN_MODEL_FRD_OPT.mat\n')
                fprintf('  OP: Vp=%.2f, P_ref=%.2f, SCR=%.1f\n', ...
                    OP_OPTIMIZATION.Vp, OP_OPTIMIZATION.P_ref, OP_OPTIMIZATION.SCR_grid)
                fprintf('-------------------------------------------------------------------------\n')
                cd ../../CONFIGURATION
            end
        else
            % Load initial control from specified step (1-5)
            init_filename = OPT_PHASE_CONFIG.(OPT_PHASE_NAMES{INIT_STEP}).filename;
            % Prefer mode-specific file; fall back to linear baseline
            switch GA_OPTIMIZATION_fitnessMode
                case 'hybrid'
                    preferred_file = ['../RESULTS/CONTROL/' init_filename '_HYBRID.mat'];
                case 'linear_itae'
                    preferred_file = ['../RESULTS/CONTROL/' init_filename '_LITAE.mat'];
                case 'linear_itae_biobj'
                    preferred_file = ['../RESULTS/CONTROL/' init_filename '_BIOBJ.mat'];
                otherwise
                    preferred_file = ['../RESULTS/CONTROL/' init_filename '.mat'];
            end
            if exist(preferred_file, 'file')
                init_file = preferred_file;
            else
                init_file = ['../RESULTS/CONTROL/' init_filename '.mat'];
                fprintf('  NOTE: Mode-specific file not found, falling back to linear baseline\n')
            end

            fprintf('-------------------------------------------------------------------------\n')
            fprintf('Loading initial control from: %s\n', init_file)
            fprintf('-------------------------------------------------------------------------\n')

            if ~exist(init_file, 'file')
                error('Initial control file not found: %s\nRun optimization for step %d first, or use INIT_STEP=0', ...
                    init_file, INIT_STEP)
            end

            load(init_file)
            varname = whos('-file', init_file);
            LIN_MODEL_LOADED = eval(varname.name);

            % Validate and update operating point/model if needed
            fprintf('  Loaded OP: Vp=%.2f, P_ref=%.2f, SCR=%.1f\n', ...
                LIN_MODEL_LOADED.opSpecs.Vp, LIN_MODEL_LOADED.opSpecs.P_ref(1), ...
                LIN_MODEL_LOADED.MODEL.GRID.PARAM.SCR_grid)
            fprintf('  Current OP: Vp=%.2f, P_ref=%.2f, SCR=%.1f\n', ...
                OP_OPTIMIZATION.Vp, OP_OPTIMIZATION.P_ref, OP_OPTIMIZATION.SCR_grid)

            [is_compatible, compatibility_msg] = check_optimization_compatibility(...
                LIN_MODEL_LOADED, LIN_MODEL, OP_OPTIMIZATION, false);

            if is_compatible
                fprintf('  COMPATIBLE: Using loaded control without modifications\n')
                fprintf('-------------------------------------------------------------------------\n')
                LIN_MODEL_INIT = LIN_MODEL_LOADED;
            else
                fprintf('  INCOMPATIBLE: %s\n', compatibility_msg)
                fprintf('  Updating operating point and model...\n')

                % Update MODEL parameters from current configuration
                LIN_MODEL_LOADED.MODEL.BASE = LIN_MODEL.MODEL.BASE;
                LIN_MODEL_LOADED.MODEL.DFIG.BASE = LIN_MODEL.MODEL.DFIG.BASE;
                LIN_MODEL_LOADED.MODEL.DFIG.PARAM = LIN_MODEL.MODEL.DFIG.PARAM;
                LIN_MODEL_LOADED.MODEL.GRID.BASE = LIN_MODEL.MODEL.GRID.BASE;
                LIN_MODEL_LOADED.MODEL.GRID.PARAM = LIN_MODEL.MODEL.GRID.PARAM;
                LIN_MODEL_LOADED.MODEL.LINE.PARAM = LIN_MODEL.MODEL.LINE.PARAM;

                % Update operating point
                LIN_MODEL_LOADED.opSpecs = LIN_MODEL.opSpecs;

                % Relinearize
                fprintf('  Recomputing linearization...\n')
                LIN_MODEL_INIT = LINEAR_ANALYSIS(LIN_MODEL_LOADED);
                fprintf('  Updated OP: Vp=%.2f, P_ref=%.2f, SCR=%.1f\n', ...
                    LIN_MODEL_INIT.opSpecs.Vp, LIN_MODEL_INIT.opSpecs.P_ref(1), ...
                    LIN_MODEL_INIT.MODEL.GRID.PARAM.SCR_grid)
                fprintf('-------------------------------------------------------------------------\n')
            end
        end

        %----------------------------------------------------------------------
        % OPTIMIZATION LOOP: Execute each phase in sequence
        %----------------------------------------------------------------------
        LIN_MODEL_OPT = LIN_MODEL_INIT;

        for idx = 1:length(OPT_SEQUENCE)
            phase_number = OPT_SEQUENCE(idx);
            phase_name = OPT_PHASE_NAMES{phase_number};
            phase_config = OPT_PHASE_CONFIG.(phase_name);

            fprintf('=========================================================================\n')
            fprintf('Optimization Phase %d/%d: %s (Step %d)\n', idx, length(OPT_SEQUENCE), phase_name, phase_number)
            fprintf('=========================================================================\n')

            % Configure optimization
            LIN_MODEL_OPT.CONTROL_DESIGN.designOrder = phase_config.designOrder;
            LIN_MODEL_OPT.CONTROL_DESIGN.selectedDFIG = 3;

            % Verify operating point before optimization
            fprintf('Verifying operating point: Vp=%.2f, P_ref=%.2f, SCR=%.1f\n', ...
                LIN_MODEL_OPT.opSpecs.Vp, LIN_MODEL_OPT.opSpecs.P_ref(1), ...
                LIN_MODEL_OPT.MODEL.GRID.PARAM.SCR_grid)

            % Linear analysis
            LIN_MODEL_OPT = LINEAR_ANALYSIS(LIN_MODEL_OPT);

            % Run optimization
            cd ../OPTIMIZATION/GA_MULTIOBJECTIVE
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('OPTIMIZATION CONFIGURATION:\n')
            fprintf('  Workers: %d | Population: %d | Max Gen: %d | Max Time: %.1f hrs\n', ...
                GA_OPTIMIZATION_numWorkers, GA_OPTIMIZATION_PopulationSize, ...
                GA_OPTIMIZATION_maxGenerations, GA_OPTIMIZATION_maxTime)
            fprintf('  New Population: %s\n', mat2str(GA_OPTIMIZATION_newPopulation))
            fprintf('  Fitness Mode: %s\n', GA_OPTIMIZATION_fitnessMode)
            fprintf('-------------------------------------------------------------------------\n')
            tic
            [LIN_MODEL_OPT, GAM_RESULTS] = OPTIMIZER(LIN_MODEL_OPT, phase_number, ...
                                      GA_OPTIMIZATION_newPopulation, ...
                                      GA_OPTIMIZATION_numWorkers > 0, ...
                                      GA_OPTIMIZATION_maxTime, ...
                                      GA_OPTIMIZATION_maxGenerations, ...
                                      GA_OPTIMIZATION_numWorkers, ...
                                      GA_OPTIMIZATION_PopulationSize, ...
                                      GA_OPTIMIZATION_fitnessMode, ...
                                      GA_OPTIMIZATION_refinementConfig);
            elapsed = toc;
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('Optimization completed in %.1f minutes (%.2f hours)\n', elapsed/60, elapsed/3600)
            fprintf('-------------------------------------------------------------------------\n')

            % Save results to RESULTS/CONTROL
            cd ../../RESULTS/CONTROL
            if ~exist('.', 'dir'), mkdir('.'); end

            % File naming by fitness mode to preserve results across methodologies
            switch GA_OPTIMIZATION_fitnessMode
                case 'hybrid'
                    save_filename = sprintf('LIN_MODEL_%s_OPT_HYBRID.mat', phase_name);
                    varname_save  = sprintf('LIN_MODEL_%s_OPT_HYBRID', phase_name);
                case 'linear_itae'
                    save_filename = sprintf('LIN_MODEL_%s_OPT_LITAE.mat', phase_name);
                    varname_save  = sprintf('LIN_MODEL_%s_OPT_LITAE', phase_name);
                case 'linear_itae_biobj'
                    save_filename = sprintf('LIN_MODEL_%s_OPT_BIOBJ.mat', phase_name);
                    varname_save  = sprintf('LIN_MODEL_%s_OPT_BIOBJ', phase_name);
                otherwise  % 'linear'
                    save_filename = sprintf('LIN_MODEL_%s_OPT.mat', phase_name);
                    varname_save  = sprintf('LIN_MODEL_%s_OPT', phase_name);
            end
            fprintf('Saving optimized control: RESULTS/CONTROL/%s\n', save_filename)

            % Create variable with correct name and save
            eval(sprintf('%s = LIN_MODEL_OPT;', varname_save));
            save(save_filename, varname_save)

            % Export Pareto front figure to FIGURES/GA_MULTIOBJECTIVE/
            addpath('../../FIGURES/UTILS');  % Add export utilities to path

            fprintf('Exporting Pareto front figure to: FIGURES/GA_MULTIOBJECTIVE/%s/\n', phase_name)
            auto_export_figure(gcf, 'GA_MULTIOBJECTIVE', phase_name, sprintf('%s_Pareto', phase_name));

            % Also save to RESULTS/GA_OPTIMIZATION (legacy, for compatibility)
            % mkdir BEFORE cd -- see the OUTPUT DIRECTORIES block at the head
            % of this file. This is the site where a COMPLETED GA phase used to
            % throw away its figure.
            gaOutDir_ = fullfile('..', 'GA_OPTIMIZATION');
            if ~exist(gaOutDir_, 'dir'); mkdir(gaOutDir_); end
            cd(gaOutDir_)
            switch GA_OPTIMIZATION_fitnessMode
                case 'hybrid',            fig_filename = sprintf('FIG_GAM_%s_HYBRID.fig', phase_name);
                case 'linear_itae',       fig_filename = sprintf('FIG_GAM_%s_LITAE.fig',  phase_name);
                case 'linear_itae_biobj', fig_filename = sprintf('FIG_GAM_%s_BIOBJ.fig',  phase_name);
                otherwise,                fig_filename = sprintf('FIG_GAM_%s.fig',         phase_name);
            end
            saveas(gcf, fig_filename, 'fig')

            % Save Pareto front data (param_opt, fval_opt, etc.)
            switch GA_OPTIMIZATION_fitnessMode
                case 'hybrid',            gam_filename = sprintf('GAM_%s_HYBRID.mat', phase_name);
                case 'linear_itae',       gam_filename = sprintf('GAM_%s_LITAE.mat',  phase_name);
                case 'linear_itae_biobj', gam_filename = sprintf('GAM_%s_BIOBJ.mat',  phase_name);
                otherwise,                gam_filename = sprintf('GAM_%s.mat',         phase_name);
            end
            fprintf('Saving Pareto data: RESULTS/GA_OPTIMIZATION/%s\n', gam_filename)
            save(gam_filename, 'GAM_RESULTS')

            fprintf('=========================================================================\n')
            fprintf('Phase %d/%d (%s) completed successfully\n', idx, length(OPT_SEQUENCE), phase_name)
            fprintf('=========================================================================\n\n')

            cd ../../CONFIGURATION
        end

        fprintf('=========================================================================\n')
        fprintf('GENETIC ALGORITHM OPTIMIZATION COMPLETE\n')
        fprintf('=========================================================================\n')
        fprintf('Optimized %d phases: ', length(OPT_SEQUENCE))
        for idx = 1:length(OPT_SEQUENCE)
            fprintf('%s', OPT_PHASE_NAMES{OPT_SEQUENCE(idx)})
            if idx < length(OPT_SEQUENCE), fprintf(' → '); end
        end
        fprintf('\nResults saved to: RESULTS/CONTROL/LIN_MODEL_*_OPT.mat\n')
        fprintf('Figures exported to: FIGURES/GA_MULTIOBJECTIVE/{phase}/ (.fig, .eps, .pdf)\n')
        fprintf('Legacy figures: RESULTS/GA_OPTIMIZATION/FIG_GAM_*.fig\n')
        fprintf('=========================================================================\n')

        cd ../SIMULINK

    %-------------------------------------
    case 4 % NON-LINEAR SIMULATION
    %-------------------------------------
        fprintf('=========================================================================\n')
        fprintf('  NON-LINEAR SIMULATION CONFIGURATION\n')
        fprintf('=========================================================================\n')
        fprintf('SIMULATION OPERATING POINT: OP_RATED (defined in header)\n')
        fprintf('  Vp = %.2f pu, P_ref = %.2f pu, SCR = %.2f\n', ...
            LIN_MODEL.opSpecs.Vp, LIN_MODEL.opSpecs.P_ref(1), ...
            LIN_MODEL.MODEL.GRID.PARAM.SCR_grid)
        fprintf('-------------------------------------------------------------------------\n')
        fprintf('NOTE: Simulation ALWAYS uses OP_RATED regardless of CONTROL_TYPE.\n')
        fprintf('      CONTROL_TYPE 3-7 use optimized control parameters but simulate\n')
        fprintf('      at OP_RATED conditions (not OP_OPTIMIZATION conditions).\n')
        fprintf('=========================================================================\n')

        % CRITICAL: Clear cached linearization states and recompute
        % Ensures operating point is freshly computed with current parameters
        % This is essential for CONTROL_TYPE 3-7 where load_and_merge_model()
        % may have cached states from optimization operating point
        LIN_MODEL = rmfield(LIN_MODEL, intersect(fieldnames(LIN_MODEL), {'opModel', 'ssModel'}));

        cd ../CONFIGURATION
        LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL);

        fprintf('-------------------------------------------------------------------------\n')
        fprintf('OPERATING POINT VERIFICATION (Pre-Simulation)\n')
        fprintf('-------------------------------------------------------------------------\n')
        fprintf('Base values:\n')
        fprintf('  Ub = %.3f V, Sb = %.3f VA, Udc_base = %.3f V\n', ...
            LIN_MODEL.MODEL.BASE.Ub, LIN_MODEL.MODEL.BASE.Sb, LIN_MODEL.MODEL.DFIG.BASE.Udc_base(1))
        fprintf('Operating point:\n')
        fprintf('  Vp = %.3f pu, P_ref = %.3f pu, SCR = %.3f\n', ...
            LIN_MODEL.opSpecs.Vp, LIN_MODEL.opSpecs.P_ref(1), LIN_MODEL.MODEL.GRID.PARAM.SCR_grid)
        fprintf('Steady-state conditions:\n')
        fprintf('  vPCC_r = %.6f pu, wr = %.6f pu\n', ...
            LIN_MODEL.MODEL.DFIG.INPUT.vPCC_r(1), LIN_MODEL.MODEL.DFIG.OUTPUT.wr(1))
        fprintf('  Line currents: il = %s pu\n', mat2str(LIN_MODEL.MODEL.LINE.STATE', 6))
        fprintf('-------------------------------------------------------------------------\n')
        fprintf('POWER BALANCE VERIFICATION (Diagnostic Check)\n')
        fprintf('-------------------------------------------------------------------------\n')
        % Power balance diagnostic for each DFIG
        for i = 1:nDFIG
            % Extract DFIG outputs
            OUTPUT = LIN_MODEL.MODEL.DFIG.OUTPUT;
            PARAM = LIN_MODEL.MODEL.DFIG.PARAM;

            % Complex quantities
            vs = OUTPUT.vs_r(i) + 1j*OUTPUT.vs_i(i);
            is = OUTPUT.is_r(i) + 1j*OUTPUT.is_i(i);
            ir = OUTPUT.ir_r(i) + 1j*OUTPUT.ir_i(i);
            it = OUTPUT.it_r(i) + 1j*OUTPUT.it_i(i);

            % Power calculations
            P_trafo = real(vs * conj(it)) / sqrt(3);      % Transformer power
            Ps = real(vs * conj(is)) / sqrt(3);           % Stator power
            Te = PARAM.Lm_pu(i) * imag(is * conj(ir)) / sqrt(3);  % Electrical torque
            Ploss = (PARAM.Dt_pu(i) + PARAM.Dg_pu(i)) * OUTPUT.wr(i)^2;  % Mechanical losses

            % Power balance error: Pm + Te*wr - losses = 0
            error_pu = OUTPUT.Pm(i) + Te*OUTPUT.wr(i) - Ploss;

            fprintf('DFIG %d: Pm=%.4f, Ps=%.4f, P_trafo=%.4f, P_RSC=%.4f, P_GSC=%.4f pu\n', ...
                i, OUTPUT.Pm(i), Ps, P_trafo, OUTPUT.P_RSC(i), OUTPUT.P_GSC(i))
            fprintf('        Te=%.4f, Te*wr=%.4f, Losses=%.4f, Error=%.6f pu', ...
                Te, Te*OUTPUT.wr(i), Ploss, error_pu)
            if abs(error_pu) > 1e-3
                fprintf(' *** WARNING: Imbalance > 1e-3 pu! ***')
            end
            fprintf('\n')
        end
        fprintf('=========================================================================\n')

        % Apply SCR / H overrides from NL_SIM_CONFIG (if specified)
        LIN_MODEL_NL = LIN_MODEL;
        if ~isempty(NL_SIM_CONFIG.override_SCR)
            LIN_MODEL_NL.MODEL.GRID.PARAM.SCR_grid = NL_SIM_CONFIG.override_SCR;
            LIN_MODEL_NL.MODEL = update_grid_impedances(LIN_MODEL_NL.MODEL);
            fprintf('  SCR override: %.2f → recomputing grid impedances\n', NL_SIM_CONFIG.override_SCR)
            cd ../CONFIGURATION
            LIN_MODEL_NL = LINEAR_ANALYSIS(LIN_MODEL_NL);
        end
        if ~isempty(NL_SIM_CONFIG.override_H_scale)
            LIN_MODEL_NL.CONTROL.VSMP.PARAM.H = ...
                LIN_MODEL_NL.CONTROL.VSMP.PARAM.H * NL_SIM_CONFIG.override_H_scale;
            fprintf('  H override: ×%.2f → H = %.4f\n', NL_SIM_CONFIG.override_H_scale, ...
                LIN_MODEL_NL.CONTROL.VSMP.PARAM.H)
        end

        % Prepare workspace for Simulink simulation
        assignin('base', 'CONTROL_INI', LIN_MODEL_NL.CONTROL);
        assignin('base', 'MODEL_INI', LIN_MODEL_NL.MODEL);

        % Run BusDefinition (CRITICAL: must precede any sim() call)
        cd ../BUS_DEFINITIONS
        BusDefinition(LIN_MODEL_NL.MODEL, 'MODEL_Bus');
        BusDefinition(LIN_MODEL_NL.CONTROL, 'CONTROL_Bus');

        % Configure and run Simulink simulation via RUN_PERTURBATION_SIM
        fprintf('-------------------------------------------------------------------------\n')
        fprintf('SIMULINK SIMULATION (via RUN_PERTURBATION_SIM)\n')
        fprintf('-------------------------------------------------------------------------\n')
        fprintf('Model: %s\n', LIN_MODEL_NL.modelName)
        fprintf('Perturbation type: %s\n', NL_SIM_PERT_TYPE)
        fprintf('Duration: %.1f s\n', NL_SIM_CONFIG.sim_duration)
        fprintf('-------------------------------------------------------------------------\n')

        cd ../SIMULATION
        if strcmp(NL_SIM_PERT_TYPE, 'none')
            % Baseline: no perturbation (generation_loss with all-zero mask = no change)
            pertConfig_run = struct('sim_duration', NL_SIM_CONFIG.sim_duration);
            nl_results = RUN_PERTURBATION_SIM(LIN_MODEL_NL, 'generation_loss', pertConfig_run);
        else
            nl_results = RUN_PERTURBATION_SIM(LIN_MODEL_NL, NL_SIM_PERT_TYPE, NL_SIM_CONFIG);
        end

        if nl_results.success
            fprintf('Simulation SUCCESS. t_end = %.3f s\n', nl_results.t(end))
            fprintf('=========================================================================\n')

            % Save simulation results. mkdir BEFORE cd -- see the note at
            % the RESULTS/LINEAR_ANALYSIS site above for why the old form
            % could never create anything.
            outDir = fullfile('..', 'RESULTS', 'SIMULATION');
            if ~exist(outDir, 'dir'); mkdir(outDir); end
            cd(outDir)

            timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');
            control_name = '';
            switch CONTROL_TYPE
                case 1, control_name = 'TRD';
                case 2, control_name = 'FRD';
                case 3, control_name = 'PDS_OPT';
                case 4, control_name = 'QDS_OPT';
                case 5, control_name = 'PCP_OPT';
                case 6, control_name = 'QCP_OPT';
                case 7, control_name = 'VI_OPT';
            end
            nDFIG_str = sprintf('%dDFIG', nDFIG);
            pert_tag  = strrep(NL_SIM_PERT_TYPE, '_', '');  % e.g. 'qrefstep'
            sim_filename = sprintf('SIM_%s_%s_%s_%s.mat', timestamp, control_name, ...
                                   nDFIG_str, pert_tag);

            fprintf('-------------------------------------------------------------------------\n')
            fprintf('SAVING SIMULATION RESULTS\n')
            fprintf('-------------------------------------------------------------------------\n')
            fprintf('File: %s\n', sim_filename)
            fprintf('Control: %s | OP: RATED (Vp=%.2f, P=%.2f, SCR=%.1f) | Pert: %s\n', ...
                control_name, LIN_MODEL_NL.opSpecs.Vp, LIN_MODEL_NL.opSpecs.P_ref(1), ...
                LIN_MODEL_NL.MODEL.GRID.PARAM.SCR_grid, NL_SIM_PERT_TYPE)
            fprintf('-------------------------------------------------------------------------\n')

            SCOPE_SIM  = nl_results.SCOPE_SIM;
            CONTROL_INI = LIN_MODEL_NL.CONTROL;
            MODEL_INI   = LIN_MODEL_NL.MODEL;
            save(sim_filename, 'LIN_MODEL_NL', 'SCOPE_SIM', 'CONTROL_INI', 'MODEL_INI', ...
                 'nl_results', 'NL_SIM_PERT_TYPE', 'NL_SIM_CONFIG', ...
                 'RUN_MODE', 'CONTROL_TYPE', 'nDFIG', 'timestamp')
            fprintf('Simulation data saved.\n')
            fprintf('=========================================================================\n')

            % Generate visualization plots (all 15 signal groups)
            cd ../../PLOT_FILES
            PLOT_SCOPE_SIM(nl_results.SCOPE_SIM)
        else
            fprintf('Simulation FAILED: %s\n', nl_results.error)
            fprintf('=========================================================================\n')
        end

        % Return to CONFIGURATION directory for consistency
        cd ../CONFIGURATION

    %-------------------------------------
    case 5 % OPTIMUM CONTROL DESIGN SEQUENCE
    %-------------------------------------
        % CRITICAL: RUN_MODE=5 always uses FRD specifications, regardless of CONTROL_TYPE
        % Force CONTROL_TYPE=2 to avoid misleading filenames
        if CONTROL_TYPE ~= 2
            fprintf('=========================================================================\n')
            fprintf('  WARNING: RUN_MODE=5 requires CONTROL_TYPE=2 (FRD)\n')
            fprintf('=========================================================================\n')
            fprintf('Current CONTROL_TYPE=%d will be changed to CONTROL_TYPE=2\n', CONTROL_TYPE)
            fprintf('Reason: Control design sequence optimization ALWAYS uses FRD specs\n')
            fprintf('-------------------------------------------------------------------------\n')
            CONTROL_TYPE = 2;
        end

        fprintf('=========================================================================\n')
        fprintf('  CONTROL DESIGN SEQUENCE OPTIMIZATION\n')
        fprintf('=========================================================================\n')
        fprintf('Searching for optimal design sequence to minimize specification errors\n')

        % Calculate total permutations
        total_permutations = factorial(7);  % 7! = 5040
        if isempty(CD_SEQ_maxSequences)
            sequences_to_test = total_permutations;
            fprintf('Testing ALL permutations: %d sequences\n', sequences_to_test)
            fprintf('Estimated time: Several hours with %d parallel workers\n', CD_SEQ_numWorkers)
        else
            sequences_to_test = min(CD_SEQ_maxSequences, total_permutations);
            fprintf('Testing SUBSET: %d of %d total sequences (%.1f%%)\n', ...
                sequences_to_test, total_permutations, 100*sequences_to_test/total_permutations)
            fprintf('Estimated time: ~%.0f minutes with %d parallel workers\n', ...
                sequences_to_test/10, CD_SEQ_numWorkers)
        end
        fprintf('-------------------------------------------------------------------------\n')

        % Time-response design (base design)
        cd ../CONTROL
        LIN_MODEL = CONTROL_DESIGN_TR(LIN_MODEL);

        % Frequency-response specifications from header
        LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs = FRD_SPECS.VSMP;
        LIN_MODEL.CONTROL_DESIGN.VSMQ.frdSpecs = FRD_SPECS.VSMQ;
        LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs = FRD_SPECS.RSC;
        LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs = FRD_SPECS.VDC;
        LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs = FRD_SPECS.GSC;

        fprintf('Using frequency-response specifications from header:\n')
        fprintf('  VSMP: Fm=%.1f°, wo=%.2f rad/s\n', FRD_SPECS.VSMP.Fm, FRD_SPECS.VSMP.wo)
        fprintf('  VSMQ: wo=%.2f rad/s\n', FRD_SPECS.VSMQ.wo)
        fprintf('  RSC:  Fm=[%.1f %.1f]°, wo=[%.0f %.0f] rad/s\n', ...
            FRD_SPECS.RSC.Fm(1), FRD_SPECS.RSC.Fm(2), FRD_SPECS.RSC.wo(1), FRD_SPECS.RSC.wo(2))
        fprintf('  VDC:  Fm=%.1f°, wo=%.2f rad/s\n', FRD_SPECS.VDC.Fm, FRD_SPECS.VDC.wo)
        fprintf('  GSC:  Fm=[%.1f %.1f]°, wo=[%.0f %.0f] rad/s\n', ...
            FRD_SPECS.GSC.Fm(1), FRD_SPECS.GSC.Fm(2), FRD_SPECS.GSC.wo(1), FRD_SPECS.GSC.wo(2))
        fprintf('=========================================================================\n')

        % Run optimization
        cd ../OPTIMIZATION/SEQUENCE
        CD_SEQ_TABLE = OPT_CD_SEQ(LIN_MODEL, CD_SEQ_numWorkers, CD_SEQ_maxSequences);

        % Save results to dedicated directory
        cd ../../RESULTS
        if ~exist('SEQ_OPTIMIZATION', 'dir')
            mkdir('SEQ_OPTIMIZATION')
        end
        cd SEQ_OPTIMIZATION

        % Generate descriptive filename with timestamp
        timestamp = datetime('now', 'Format', 'yyyyMMdd_HHmmss');

        % Determine control type name
        control_name = '';
        switch CONTROL_TYPE
            case 1, control_name = 'TRD';
            case 2, control_name = 'FRD';
            case 3, control_name = 'PDS_OPT';
            case 4, control_name = 'QDS_OPT';
            case 5, control_name = 'PCP_OPT';
            case 6, control_name = 'QCP_OPT';
            case 7, control_name = 'VI_OPT';
        end

        nDFIG_str = sprintf('%dDFIG', nDFIG);

        % Determine scope description
        if isempty(CD_SEQ_maxSequences)
            scope_str = 'ALL';
            num_tested = 5040;
        else
            scope_str = sprintf('%dof5040', CD_SEQ_maxSequences);
            num_tested = CD_SEQ_maxSequences;
        end

        results_filename = sprintf('CD_SEQ_%s_%s_%s_%s.mat', ...
            timestamp, scope_str, control_name, nDFIG_str);

        fprintf('=========================================================================\n')
        fprintf('  SAVING CONTROL DESIGN SEQUENCE OPTIMIZATION RESULTS\n')
        fprintf('=========================================================================\n')
        fprintf('Sequences tested: %d\n', num_tested)
        fprintf('Best sequence: [%s]\n', num2str(CD_SEQ_TABLE{1,1:7}))
        fprintf('Mean absolute error: %.2f%%\n', CD_SEQ_TABLE.ERR_ABS_MEAN(1))
        fprintf('-------------------------------------------------------------------------\n')
        fprintf('File: %s\n', results_filename)
        fprintf('Location: RESULTS/SEQ_OPTIMIZATION/\n')
        fprintf('=========================================================================\n')

        % Save complete optimization results
        save(results_filename, 'CD_SEQ_TABLE', 'LIN_MODEL', 'FRD_SPECS', ...
             'CD_SEQ_numWorkers', 'CD_SEQ_maxSequences', 'timestamp', ...
             'RUN_MODE', 'CONTROL_TYPE', 'nDFIG')

        cd ../../SIMULINK

end

%--------------------------------------------------------------
%% FINALIZATION
%--------------------------------------------------------------
ttime_end = toc(ttime);
% Convert to hours, minutes, seconds
hours = floor(ttime_end / 3600);
minutes = floor(mod(ttime_end, 3600) / 60);
seconds = mod(ttime_end, 60);
fprintf('\n Total execution time: %02d:%02d:%06.3f (hh:mm:ss)\n', hours, minutes, seconds)
diary off

clear modelName modelType RUN_MODE CONTROL_TYPE CONTROL_REDESIGN OPT_SEQUENCE INIT_STEP OPT_PHASE_CONFIG OPT_PHASE_NAMES OP_RATED OP_OPTIMIZATION VIMP_Lv_pu VIMP_Rv_pu TRD_SPECS FRD_SPECS FRD_designOrder FRD_selectedDFIG FRD_N_iter nDFIG ii idx phase cfg hours minutes seconds saved_design_file design_type_name LIN_MODEL_LOADED is_compatible compatibility_msg timestamp control_name op_name nDFIG_str sim_filename CONTROL_INI MODEL_INI phase_number phase_name phase_config frd_opt_file needs_update init_file init_filename LIN_MODEL_INIT LIN_MODEL_FRD_OPT save_filename fig_filename elapsed varname LIN_MODEL_OPT msg

%--------------------------------------------------------------
%% HELPER FUNCTIONS
%--------------------------------------------------------------
function [is_compatible, msg] = check_optimization_compatibility(LIN_MODEL_LOADED, LIN_MODEL_CURRENT, OP_OPTIMIZATION, check_base_values)
% CHECK_OPTIMIZATION_COMPATIBILITY - Verify if loaded model is compatible with current optimization settings
%
% DESCRIPTION:
%   Checks if a previously saved optimization model is compatible with the current
%   system configuration and optimization operating point. Used to determine if
%   a saved optimization can be reused or needs to be updated.
%
% INPUTS:
%   LIN_MODEL_LOADED   - Previously saved LIN_MODEL structure
%   LIN_MODEL_CURRENT  - Current LIN_MODEL structure with active configuration
%   OP_OPTIMIZATION    - Target optimization operating point structure
%   check_base_values  - Boolean: if true, also checks base voltage/power values
%
% OUTPUTS:
%   is_compatible - Boolean: true if models are compatible, false otherwise
%   msg          - String: descriptive message explaining compatibility status
%
% COMPATIBILITY CRITERIA:
%   - Operating point voltage (Vp) must match within 1e-6 tolerance
%   - Operating point power (P_ref) must match within 1e-6 tolerance
%   - Grid SCR must match within 1e-6 tolerance
%   - Number of DFIGs must be identical
%   - If check_base_values=true: base voltage and power must match within 1e-6
%
% USAGE:
%   [is_compat, msg] = check_optimization_compatibility(saved_model, current_model, OP_OPT, true);

    % Check operating point compatibility
    if abs(LIN_MODEL_LOADED.opSpecs.Vp - OP_OPTIMIZATION.Vp) > 1e-6
        is_compatible = false;
        msg = sprintf('Operating point voltage mismatch (saved: %.3f, current: %.3f)', ...
            LIN_MODEL_LOADED.opSpecs.Vp, OP_OPTIMIZATION.Vp);
        return;
    end

    if abs(LIN_MODEL_LOADED.opSpecs.P_ref(1) - OP_OPTIMIZATION.P_ref) > 1e-6
        is_compatible = false;
        msg = sprintf('Operating point power mismatch (saved: %.3f, current: %.3f)', ...
            LIN_MODEL_LOADED.opSpecs.P_ref(1), OP_OPTIMIZATION.P_ref);
        return;
    end

    if abs(LIN_MODEL_LOADED.MODEL.GRID.PARAM.SCR_grid - OP_OPTIMIZATION.SCR_grid) > 1e-6
        is_compatible = false;
        msg = sprintf('Grid SCR mismatch (saved: %.3f, current: %.3f)', ...
            LIN_MODEL_LOADED.MODEL.GRID.PARAM.SCR_grid, OP_OPTIMIZATION.SCR_grid);
        return;
    end

    % Check model configuration compatibility
    if LIN_MODEL_LOADED.MODEL.DFIG.PARAM.nDFIG ~= LIN_MODEL_CURRENT.MODEL.DFIG.PARAM.nDFIG
        is_compatible = false;
        msg = sprintf('Number of DFIGs mismatch (saved: %d, current: %d)', ...
            LIN_MODEL_LOADED.MODEL.DFIG.PARAM.nDFIG, LIN_MODEL_CURRENT.MODEL.DFIG.PARAM.nDFIG);
        return;
    end

    % Check base values if requested (only for FRD_OPT validation)
    if check_base_values
        if abs(LIN_MODEL_LOADED.MODEL.BASE.Ub - LIN_MODEL_CURRENT.MODEL.BASE.Ub) > 1e-6
            is_compatible = false;
            msg = sprintf('Base voltage mismatch (saved: %.3f, current: %.3f)', ...
                LIN_MODEL_LOADED.MODEL.BASE.Ub, LIN_MODEL_CURRENT.MODEL.BASE.Ub);
            return;
        end

        if abs(LIN_MODEL_LOADED.MODEL.BASE.Sb - LIN_MODEL_CURRENT.MODEL.BASE.Sb) > 1e-6
            is_compatible = false;
            msg = sprintf('Base power mismatch (saved: %.3f, current: %.3f)', ...
                LIN_MODEL_LOADED.MODEL.BASE.Sb, LIN_MODEL_CURRENT.MODEL.BASE.Sb);
            return;
        end
    end

    % All checks passed
    is_compatible = true;
    msg = 'All parameters match';
end

%--------------------------------------------------------------------------
%% LOCAL FUNCTION: Load and merge model
%--------------------------------------------------------------------------
function LIN_MODEL_OUT = load_and_merge_model(filename, LIN_MODEL_BASE)
% LOAD_AND_MERGE_MODEL - Load optimized control and merge with current system configuration
%
% DESCRIPTION:
%   Loads a previously optimized control design from file and merges it with
%   the current system configuration. This function is critical for CONTROL_TYPE
%   3-7 (optimized designs) as it ensures the saved control parameters are
%   applied to the current operating point and model configuration.
%
%   The function performs a smart merge strategy:
%   - PRESERVES: Optimized CONTROL parameters from saved file
%   - UPDATES: MODEL parameters and operating point from current configuration
%   - RECOMPUTES: Linearization with merged configuration
%
% INPUTS:
%   filename        - Full path to saved .mat file containing optimized LIN_MODEL
%   LIN_MODEL_BASE  - Current LIN_MODEL structure with active system configuration
%
% OUTPUTS:
%   LIN_MODEL_OUT - Merged LIN_MODEL structure with:
%                   * Optimized CONTROL from file
%                   * Current MODEL parameters
%                   * Current operating point
%                   * Recomputed linearization
%
% WORKFLOW:
%   1. Load optimized model from file
%   2. Display operating point comparison (saved vs current)
%   3. Update BASE values (voltage, power, frequency)
%   4. Update MODEL parameters (DFIG, GRID, LINE) from current config
%   5. Update operating point specifications to current values
%   6. Recompute linearization with merged configuration
%   7. Verify and display final operating point
%
% CRITICAL NOTES:
%   - Optimized files may have obsolete MODEL parameters from when they were created
%   - Only CONTROL parameters should be preserved from the optimized file
%   - All MODEL parameters must come from current CONFIG_MODEL.m
%   - Linearization must be recomputed to reflect current operating point
%
% USAGE:
%   Used internally by CONFIG_POWER_SYSTEM.m for CONTROL_TYPE 3-7:
%   - Type 3: PDS_OPT (P-axis droop slope optimization)
%   - Type 4: QDS_OPT (Q-axis droop slope optimization)
%   - Type 5: PCP_OPT (P-axis current PI optimization)
%   - Type 6: QCP_OPT (Q-axis current PI optimization)
%   - Type 7: VI_OPT  (Virtual impedance optimization)
%
% SEE ALSO:
%   check_optimization_compatibility, update_grid_impedances

    % RESOLVE THE FITNESS-VARIANT SUFFIX BEFORE LOADING.
    %   The GA writes LIN_MODEL_<PHASE>_OPT_BIOBJ.mat, _HYBRID.mat or _LITAE.mat
    %   depending on the fitness variant, and only the plain _OPT.mat when the
    %   default variant is used (see the save_filename switch in the RUN_MODE 3
    %   block). CONTROL_TYPE 3-7 asked for the PLAIN name unconditionally.
    %
    %   Every design this paper reports is a BIOBJ design, so on a clean clone
    %   all five of those CONTROL_TYPE values failed with
    %   MATLAB:ErrorRecovery:ItemNoLongerOnPath -- the optimised design could
    %   not be selected at all. Resolve the variant instead of assuming it.
    if ~isfile(filename)
        [pdir, base, ext] = fileparts(filename);
        variants = {'_BIOBJ', '_HYBRID', '_LITAE'};
        found = '';
        for vv = 1:numel(variants)
            cand = fullfile(pdir, [base variants{vv} ext]);
            if isfile(cand); found = cand; break; end
        end
        if isempty(found)
            error('CONFIG_POWER_SYSTEM:noOptimisedDesign', ...
                  ['Optimised design not found: %s\n' ...
                   'Tried the plain name and the _BIOBJ, _HYBRID and _LITAE ' ...
                   'variants in %s.\nRESULTS/CONTROL ships the BIOBJ designs; ' ...
                   'if none is present the repository is incomplete.'], ...
                  filename, pdir);
        end
        fprintf('  (resolved variant: %s -> %s)\n', [base ext], [base variants{vv} ext]);
        filename = found;
    end

    fprintf('-------------------------------------------------------------------------\n')
    fprintf('Loading optimized control from: %s\n', filename)
    fprintf('-------------------------------------------------------------------------\n')

    load(filename)
    varname = whos('-file', filename);
    LIN_MODEL_LOADED = eval(varname.name);

    % Display loaded operating point
    fprintf('Loaded OP: Vp=%.3f, P_ref=%.2f, SCR=%.2f\n', ...
        LIN_MODEL_LOADED.opSpecs.Vp, LIN_MODEL_LOADED.opSpecs.P_ref(1), ...
        LIN_MODEL_LOADED.MODEL.GRID.PARAM.SCR_grid)

    % Display current operating point
    fprintf('Current OP: Vp=%.3f, P_ref=%.2f, SCR=%.2f\n', ...
        LIN_MODEL_BASE.opSpecs.Vp, LIN_MODEL_BASE.opSpecs.P_ref(1), ...
        LIN_MODEL_BASE.MODEL.GRID.PARAM.SCR_grid)

    % Always update BASE values (must match current system configuration)
    LIN_MODEL_LOADED.MODEL.BASE = LIN_MODEL_BASE.MODEL.BASE;
    LIN_MODEL_LOADED.MODEL.DFIG.BASE = LIN_MODEL_BASE.MODEL.DFIG.BASE;
    LIN_MODEL_LOADED.MODEL.GRID.BASE = LIN_MODEL_BASE.MODEL.GRID.BASE;

    % CRITICAL: Update ALL MODEL parameters from current CONFIG_MODEL
    % The optimized file may have obsolete parameters that cause wrong operating point
    % Only CONTROL parameters should be preserved from optimized file
    LIN_MODEL_LOADED.MODEL.DFIG.PARAM = LIN_MODEL_BASE.MODEL.DFIG.PARAM;
    LIN_MODEL_LOADED.MODEL.GRID.PARAM = LIN_MODEL_BASE.MODEL.GRID.PARAM;
    LIN_MODEL_LOADED.MODEL.LINE.PARAM = LIN_MODEL_BASE.MODEL.LINE.PARAM;

    % Update operating point specifications
    LIN_MODEL_LOADED.opSpecs = LIN_MODEL_BASE.opSpecs;

    % Recompute linearized model with current operating point
    fprintf('Recomputing linearization with current operating point...\n')
    cd ../CONFIGURATION
    LIN_MODEL_OUT = LINEAR_ANALYSIS(LIN_MODEL_LOADED);

    fprintf('Computed OP: Vp=%.3f, P_ref=%.2f, SCR=%.2f\n', ...
        LIN_MODEL_OUT.opSpecs.Vp, LIN_MODEL_OUT.opSpecs.P_ref(1), ...
        LIN_MODEL_OUT.MODEL.GRID.PARAM.SCR_grid)
    fprintf('-------------------------------------------------------------------------\n')
end

%--------------------------------------------------------------------------
%% LOCAL FUNCTION: Update Grid Impedances
%--------------------------------------------------------------------------
function MODEL = update_grid_impedances(MODEL)
% UPDATE_GRID_IMPEDANCES - Recalculate grid impedances based on SCR
%
% DESCRIPTION:
%   Updates grid inductance (Lg_H) and resistance (Rg_Ohm) parameters
%   based on the Short Circuit Ratio (SCR_grid) value.
%
%   Grid impedance calculation follows power system convention:
%     Lg_H = Ub^2 / (Sb * 2*pi*f0 * SCR)     [H]
%     Rg_Ohm = Lg_H * 2*pi*f0 / XR           [Ohm]
%
%   Where:
%     - Ub: Base voltage [V]
%     - Sb: Base apparent power [VA]
%     - f0: Base frequency [Hz]
%     - SCR: Short circuit ratio [pu]
%     - XR: X/R ratio (typically 10 for transmission systems)
%
% INPUTS:
%   MODEL - Model structure with GRID.PARAM.SCR_grid updated
%
% OUTPUTS:
%   MODEL - Model structure with recalculated Lg_H and Rg_Ohm
%
% USAGE:
%   Called during parametric sweeps when SCR varies across operating points

    % Extract base parameters
    Ub = MODEL.BASE.Ub;           % Base voltage [V]
    Sb = MODEL.GRID.BASE.Sb;      % Base apparent power [VA]
    f0 = MODEL.BASE.f0;           % Base frequency [Hz]
    SCR = MODEL.GRID.PARAM.SCR_grid;  % Short circuit ratio [pu]
    XR = MODEL.GRID.PARAM.XR_grid;    % X/R ratio

    % Recalculate grid inductance [H]
    MODEL.GRID.PARAM.Lg_H = Ub^2 / Sb / (2*pi*f0) / SCR;

    % Recalculate grid resistance [Ohm]
    MODEL.GRID.PARAM.Rg_Ohm = MODEL.GRID.PARAM.Lg_H * (2*pi*f0) / XR;

    % CRITICAL: Update per-unit values used by Simulink model
    % Without this, Simulink linearization uses stale per-unit impedances
    MODEL.GRID.PARAM.Lg_pu = MODEL.GRID.PARAM.Lg_H ./ MODEL.BASE.Lb;   % Grid inductance [pu]
    MODEL.GRID.PARAM.Rg_pu = MODEL.GRID.PARAM.Rg_Ohm ./ MODEL.BASE.Zb; % Grid resistance [pu]

end
