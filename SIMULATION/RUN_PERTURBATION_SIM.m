function results = RUN_PERTURBATION_SIM(LIN_MODEL, pertType, pertConfig, workerID)
% RUN_PERTURBATION_SIM - Run non-linear Simulink simulation with perturbation
%
% DESCRIPTION:
%   Configures perturbation workspace variables, enables the PERTURBATION &
%   MONITORING subsystem, runs time-domain simulation, and returns structured
%   results including frequency, voltage, and DFIG power time-series data.
%
%   The function assumes LIN_MODEL is fully initialized (from LINEAR_ANALYSIS)
%   with valid operating point, control parameters, and initial states.
%   Bus definitions must already exist in the base workspace.
%
% INPUTS:
%   LIN_MODEL   - Fully initialized model structure (from LINEAR_ANALYSIS)
%                  Required fields: .CONTROL, .MODEL, .initialMemoryState,
%                  .modelName
%   pertType    - Perturbation type:
%                  'generation_loss' : Breaker disconnection only
%                  'voltage_sag'     : Grid voltage sag only
%                  'both'            : Both gen_loss + voltage_sag
%                  'pref_step'       : Active power reference step
%                  'qref_step'       : Reactive power reference step
%                  'load_step'       : Load current step (real + imag)
%                  'wind_change'     : Wind speed change
%                  'custom'          : All perturbations from pertConfig
%   pertConfig  - Struct with perturbation parameters:
%     .breaker_mask     [1×nDFIG] binary (1=will disconnect, 0=stays)
%     .breaker_time     scalar [s] (time of disconnection)
%     .sag_depth        scalar [0-1] (voltage sag depth, 0.2 = 20%)
%     .sag_start_time   scalar [s] (start of sag)
%     .sag_duration     scalar [s] (duration of sag)
%     .pref_mask        [1×nDFIG] binary (1=apply step, 0=skip)
%     .pref_delta       scalar [pu] (P_ref step magnitude)
%     .pref_time        scalar [s] (P_ref step time)
%     .qref_mask        [1×nDFIG] binary (1=apply step, 0=skip)
%     .qref_delta       scalar [pu] (Q_ref step magnitude)
%     .qref_time        scalar [s] (Q_ref step time)
%     .load_delta_r     scalar [pu] (active load step)
%     .load_delta_i     scalar [pu] (reactive load step)
%     .load_time        scalar [s] (load step time)
%     .vw_mask          [1×nDFIG] binary (1=apply wind change, 0=skip)
%     .vw_delta_val     scalar [m/s] (wind speed change)
%     .vw_time          scalar [s] (wind change time)
%     .sim_duration     scalar [s] (total simulation time, default: 5)
%   workerID    - (Optional) Worker ID for parallel execution
%                  0 = sequential (default), >0 = parallel worker ID
%
% OUTPUTS:
%   results     - Struct with:
%     .t            time vector [N×1]
%     .f            grid frequency [N×1] (pu)
%     .Vpcc         PCC voltage [N×cols] (pu)
%     .P_dfig       DFIG active powers (pu) - from SCOPE_SIM signals(1)
%     .Q_dfig       DFIG reactive powers (pu) - from SCOPE_SIM signals(5)
%     .SCOPE_SIM    raw scope data (for additional analysis)
%     .success      boolean
%     .pertType     perturbation type used
%     .pertConfig   perturbation config used
%     .error        error message (only if success=false)
%
% SCOPE_SIM SIGNAL MAPPING (from PERTURBATION & MONITORING scope block):
%   signals(1)  : DFIG P [P_ref, P, P_mech] (pu)
%   signals(2)  : GRID P [P_ref, P, P_mech, Load] (pu/DFIG)
%   signals(5)  : DFIG Q [Q_ref, Q, Grid_Q, Load_Q] (pu)
%   signals(6)  : Voltages [Vs_ref, Vs, PCC_V, Grid_V] (pu)
%   signals(11) : Frequency [Grid_freq, VSMP_freq] (pu)
%
% USAGE:
%   % Example 1: Generation loss (disconnect DFIGs 1,3)
%   pertConfig.breaker_mask = [1 0 1 0];
%   pertConfig.breaker_time = 1.0;
%   pertConfig.sim_duration = 3.0;
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, 'generation_loss', pertConfig);
%
%   % Example 2: Voltage sag (20% for 150ms)
%   pertConfig.sag_depth = 0.2;
%   pertConfig.sag_start_time = 1.0;
%   pertConfig.sag_duration = 0.15;
%   pertConfig.sim_duration = 3.0;
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, 'voltage_sag', pertConfig);
%
%   % Example 3: Both perturbations simultaneously
%   pertConfig.breaker_mask = [1 0 1 0];
%   pertConfig.breaker_time = 1.0;
%   pertConfig.sag_depth = 0.2;
%   pertConfig.sag_start_time = 1.5;
%   pertConfig.sag_duration = 0.15;
%   pertConfig.sim_duration = 5.0;
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, 'both', pertConfig);
%
%   % Example 4: P_ref step (-0.1 pu on DFIGs 1,3)
%   pertConfig.pref_mask = [1 0 1 0];
%   pertConfig.pref_delta = -0.1;
%   pertConfig.pref_time = 1.0;
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, 'pref_step', pertConfig);
%
%   % Example 5: Wind speed change (-2 m/s on all DFIGs)
%   pertConfig.vw_mask = [1 1 1 1];
%   pertConfig.vw_delta_val = -2;
%   pertConfig.vw_time = 1.0;
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, 'wind_change', pertConfig);
%
%   % Example 6: Custom combined scenario
%   pertConfig.breaker_mask = [1 0 0 0];
%   pertConfig.breaker_time = 1.0;
%   pertConfig.vw_mask = [0 1 1 1];
%   pertConfig.vw_delta_val = -1;
%   pertConfig.vw_time = 2.0;
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, 'custom', pertConfig);
%
%   % Example 7: Parallel execution (from GA optimizer)
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, 'generation_loss', pertConfig, 3);
%
% SEE ALSO:
%   COMPUTE_PERTURBATION_METRICS, CONFIG_POWER_SYSTEM, LINEAR_ANALYSIS,
%   OPTIMIZER

%--------------------------------------------------------------------------
%% DEFAULT ARGUMENTS
%--------------------------------------------------------------------------
if nargin < 4
    workerID = 0;
end

%--------------------------------------------------------------------------
%% INPUT VALIDATION
%--------------------------------------------------------------------------
nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;

% Validate pertType
validTypes = {'generation_loss', 'voltage_sag', 'both', ...
              'pref_step', 'qref_step', 'load_step', 'wind_change', 'custom'};
if ~ismember(pertType, validTypes)
    error('RUN_PERTURBATION_SIM:invalidType', ...
        'pertType must be one of: %s', strjoin(validTypes, ', '));
end

% Validate required LIN_MODEL fields
requiredFields = {'CONTROL', 'MODEL', 'initialMemoryState', 'modelName'};
for i = 1:length(requiredFields)
    if ~isfield(LIN_MODEL, requiredFields{i})
        error('RUN_PERTURBATION_SIM:missingField', ...
            'LIN_MODEL missing required field: %s', requiredFields{i});
    end
end

%--------------------------------------------------------------------------
%% DEFAULT PERTURBATION CONFIGURATION
%--------------------------------------------------------------------------
% Original perturbation defaults
if ~isfield(pertConfig, 'breaker_mask'),   pertConfig.breaker_mask = zeros(1,nDFIG); end
if ~isfield(pertConfig, 'breaker_time'),   pertConfig.breaker_time = 999; end
if ~isfield(pertConfig, 'sag_depth'),      pertConfig.sag_depth = 0; end
if ~isfield(pertConfig, 'sag_start_time'), pertConfig.sag_start_time = 999; end
if ~isfield(pertConfig, 'sag_duration'),   pertConfig.sag_duration = 0; end
% Phase 6: P_ref, Q_ref, Load step defaults
if ~isfield(pertConfig, 'pref_mask'),      pertConfig.pref_mask = zeros(1,nDFIG); end
if ~isfield(pertConfig, 'pref_delta'),     pertConfig.pref_delta = 0; end
if ~isfield(pertConfig, 'pref_time'),      pertConfig.pref_time = 999; end
if ~isfield(pertConfig, 'qref_mask'),      pertConfig.qref_mask = zeros(1,nDFIG); end
if ~isfield(pertConfig, 'qref_delta'),     pertConfig.qref_delta = 0; end
if ~isfield(pertConfig, 'qref_time'),      pertConfig.qref_time = 999; end
if ~isfield(pertConfig, 'load_delta_r'),   pertConfig.load_delta_r = 0; end
if ~isfield(pertConfig, 'load_delta_i'),   pertConfig.load_delta_i = 0; end
if ~isfield(pertConfig, 'load_time'),      pertConfig.load_time = 999; end
% Phase 7: Wind speed defaults
if ~isfield(pertConfig, 'vw_mask'),        pertConfig.vw_mask = zeros(1,nDFIG); end
if ~isfield(pertConfig, 'vw_delta_val'),   pertConfig.vw_delta_val = 0; end
if ~isfield(pertConfig, 'vw_time'),        pertConfig.vw_time = 999; end
% Simulation duration
if ~isfield(pertConfig, 'sim_duration'),   pertConfig.sim_duration = 5; end

% Enforce pertType constraints (enable only the requested perturbation)
switch pertType
    case 'generation_loss'
        pertConfig.sag_depth = 0;      pertConfig.sag_start_time = 999;
        pertConfig.sag_duration = 0;
        pertConfig.pref_mask = zeros(1,nDFIG); pertConfig.pref_time = 999;
        pertConfig.qref_mask = zeros(1,nDFIG); pertConfig.qref_time = 999;
        pertConfig.load_delta_r = 0;   pertConfig.load_delta_i = 0;
        pertConfig.load_time = 999;
        pertConfig.vw_mask = zeros(1,nDFIG); pertConfig.vw_time = 999;
    case 'voltage_sag'
        pertConfig.breaker_mask = zeros(1,nDFIG); pertConfig.breaker_time = 999;
        pertConfig.pref_mask = zeros(1,nDFIG); pertConfig.pref_time = 999;
        pertConfig.qref_mask = zeros(1,nDFIG); pertConfig.qref_time = 999;
        pertConfig.load_delta_r = 0;   pertConfig.load_delta_i = 0;
        pertConfig.load_time = 999;
        pertConfig.vw_mask = zeros(1,nDFIG); pertConfig.vw_time = 999;
    case 'both'
        pertConfig.pref_mask = zeros(1,nDFIG); pertConfig.pref_time = 999;
        pertConfig.qref_mask = zeros(1,nDFIG); pertConfig.qref_time = 999;
        pertConfig.load_delta_r = 0;   pertConfig.load_delta_i = 0;
        pertConfig.load_time = 999;
        pertConfig.vw_mask = zeros(1,nDFIG); pertConfig.vw_time = 999;
    case 'pref_step'
        pertConfig.breaker_mask = zeros(1,nDFIG); pertConfig.breaker_time = 999;
        pertConfig.sag_depth = 0;      pertConfig.sag_start_time = 999;
        pertConfig.qref_mask = zeros(1,nDFIG); pertConfig.qref_time = 999;
        pertConfig.load_delta_r = 0;   pertConfig.load_delta_i = 0;
        pertConfig.load_time = 999;
        pertConfig.vw_mask = zeros(1,nDFIG); pertConfig.vw_time = 999;
    case 'qref_step'
        pertConfig.breaker_mask = zeros(1,nDFIG); pertConfig.breaker_time = 999;
        pertConfig.sag_depth = 0;      pertConfig.sag_start_time = 999;
        pertConfig.pref_mask = zeros(1,nDFIG); pertConfig.pref_time = 999;
        pertConfig.load_delta_r = 0;   pertConfig.load_delta_i = 0;
        pertConfig.load_time = 999;
        pertConfig.vw_mask = zeros(1,nDFIG); pertConfig.vw_time = 999;
    case 'load_step'
        pertConfig.breaker_mask = zeros(1,nDFIG); pertConfig.breaker_time = 999;
        pertConfig.sag_depth = 0;      pertConfig.sag_start_time = 999;
        pertConfig.pref_mask = zeros(1,nDFIG); pertConfig.pref_time = 999;
        pertConfig.qref_mask = zeros(1,nDFIG); pertConfig.qref_time = 999;
        pertConfig.vw_mask = zeros(1,nDFIG); pertConfig.vw_time = 999;
    case 'wind_change'
        pertConfig.breaker_mask = zeros(1,nDFIG); pertConfig.breaker_time = 999;
        pertConfig.sag_depth = 0;      pertConfig.sag_start_time = 999;
        pertConfig.pref_mask = zeros(1,nDFIG); pertConfig.pref_time = 999;
        pertConfig.qref_mask = zeros(1,nDFIG); pertConfig.qref_time = 999;
        pertConfig.load_delta_r = 0;   pertConfig.load_delta_i = 0;
        pertConfig.load_time = 999;
    case 'custom'
        % Use all provided values — no constraints enforced
end

%--------------------------------------------------------------------------
%% MODEL NAMING (parallel worker support)
%--------------------------------------------------------------------------
modelName = LIN_MODEL.modelName;
if workerID > 0
    modelName = [modelName '_' num2str(workerID)];
end

%--------------------------------------------------------------------------
%% DIRECTORY NAVIGATION
%--------------------------------------------------------------------------
startDir = pwd;
thisDir = fileparts(mfilename('fullpath'));  % .../SIMULATION/
simulinkDir = fullfile(thisDir, '..', 'SIMULINK');

try
    cd(simulinkDir);

    %----------------------------------------------------------------------
    %% OPEN MODEL AND CONFIGURE WORKSPACE
    %----------------------------------------------------------------------
    % open_system with 'loadonly' is safe if model is already open (no-op)
    open_system(modelName, 'loadonly');
    mdlWks = get_param(modelName, 'modelworkspace');

    % Assign model initialization variables to model workspace
    % (these may already be set by LINEAR_ANALYSIS, but reassign for safety)
    assignin(mdlWks, 'CONTROL_INI', LIN_MODEL.CONTROL);
    assignin(mdlWks, 'MODEL_INI', LIN_MODEL.MODEL);
    assignin(mdlWks, 'initialMemoryState', LIN_MODEL.initialMemoryState);

    %----------------------------------------------------------------------
    %% SETTLING PHASE CONFIGURATION
    %----------------------------------------------------------------------
    % Add pre-perturbation settling time for the model to reach true
    % Simulink equilibrium from analytical initial conditions.
    % All perturbation times are shifted forward; results are trimmed after.
    if isfield(pertConfig, 'settling_time')
        SETTLING_TIME = pertConfig.settling_time;
    else
        SETTLING_TIME = 0;  % No settling — trust analytical OP (findop refinement)
    end

    %----------------------------------------------------------------------
    %% CONFIGURE PERTURBATION VARIABLES (legacy assignin — kept for logging)
    %----------------------------------------------------------------------
    % NOTE: These assignin calls write to base workspace, but the Simulink
    % model does NOT read them. The actual perturbation mechanism uses
    % hardcoded Step blocks inside PERTURBATION & MONITORING. The real
    % configuration is done below via set_param on the Step blocks.
    assignin('base', 'breaker_mask', pertConfig.breaker_mask);
    assignin('base', 'breaker_time', pertConfig.breaker_time + SETTLING_TIME);
    assignin('base', 'sag_depth', pertConfig.sag_depth);
    assignin('base', 'sag_start_time', pertConfig.sag_start_time + SETTLING_TIME);
    assignin('base', 'sag_duration', pertConfig.sag_duration);
    assignin('base', 'pref_mask', pertConfig.pref_mask);
    assignin('base', 'pref_mask_vec', pertConfig.pref_mask);
    assignin('base', 'pref_delta', pertConfig.pref_delta);
    assignin('base', 'pref_time', pertConfig.pref_time + SETTLING_TIME);
    assignin('base', 'qref_mask', pertConfig.qref_mask);
    assignin('base', 'qref_mask_vec', pertConfig.qref_mask);
    assignin('base', 'qref_delta', pertConfig.qref_delta);
    assignin('base', 'qref_time', pertConfig.qref_time + SETTLING_TIME);
    assignin('base', 'load_delta_r', pertConfig.load_delta_r);
    assignin('base', 'load_delta_i', pertConfig.load_delta_i);
    assignin('base', 'load_time', pertConfig.load_time + SETTLING_TIME);
    assignin('base', 'vw_mask', pertConfig.vw_mask);
    assignin('base', 'vw_delta_val', pertConfig.vw_delta_val);
    assignin('base', 'vw_time', pertConfig.vw_time + SETTLING_TIME);

    %----------------------------------------------------------------------
    %% ENABLE PERTURBATION SUBSYSTEM
    %----------------------------------------------------------------------
    set_param([modelName '/PERTURBATION & MONITORING'], 'Commented', 'off');

    %----------------------------------------------------------------------
    %% CONFIGURE STEP BLOCKS VIA set_param (THE REAL MECHANISM)
    %----------------------------------------------------------------------
    % CRITICAL FIX (2026-03-02): The Simulink Step blocks inside
    % PERTURBATION & MONITORING have hardcoded Time/After values that were
    % never updated by RUN_PERTURBATION_SIM. This caused ALL simulations
    % to apply the same hardcoded inc_Pref=+0.2 regardless of pertConfig.
    %
    % Topology (from model exploration):
    %   inc_Pref      → Mux[4]([delta,0,0,0]) → Reshape → Sum(+Const2) → DSWrite2(CONTROL.VSMP.TARGET.P_ref)
    %   inc_vdroop_1  → Sum3(+vdroop_2) → Sum2(+Const4) → DSWrite3(MODEL.GRID.INPUT.v_grid_r)
    %   inc_vdroop_2  → Sum3 (see above, used for sag recovery)
    %   inc_iL1_r     → Sum4(+Const5) → DSWrite4(MODEL.LINE.INPUT.il1_r)
    %   inc_windspeed → Sum1(+Const3) → DSWrite1(MODEL.DFIG.INPUT.windSpeed)
    %
    % Pattern: DataStoreWrite = Constant_INI + Step_increment
    % Step output: 0 for t<Time, After for t>=Time  (Before is always 0)

    pertSubsys = [modelName '/PERTURBATION & MONITORING'];

    % 1. RESET all Step blocks to neutral (no perturbation)
    % Core blocks (always present); extended blocks added by SETUP_PERTURBATION_BLOCKS.m
    coreStepBlocks     = {'inc_Pref', 'inc_iL1_r', 'inc_vdroop_1', 'inc_vdroop_2', 'inc_windspeed'};
    extendedStepBlocks = {'inc_Qref', 'inc_iL1_i'};
    stepBlockNames = coreStepBlocks;
    for k = 1:length(extendedStepBlocks)
        blkPath = [pertSubsys '/' extendedStepBlocks{k}];
        if ~isempty(find_system(pertSubsys, 'SearchDepth', 1, 'Name', extendedStepBlocks{k}))
            stepBlockNames{end+1} = extendedStepBlocks{k}; %#ok<AGROW>
        end
    end
    for k = 1:length(stepBlockNames)
        set_param([pertSubsys '/' stepBlockNames{k}], ...
            'Time', '999', 'Before', '0', 'After', '0');
    end

    % 2a. Create DEFAULT breaker_ts (all DFIGs connected for full sim)
    %     The breaker_status_src (From Workspace) block reads this timeseries.
    %     breaker_status: 1=connected, 0=disconnected
    %     (multiplies STATE_DERIVATIVE + currents in DFIG and CONTROL blocks)
    sim_end_ts = pertConfig.sim_duration + SETTLING_TIME + 1;
    breaker_ts.time = [0; sim_end_ts];
    bk_vals = ones(1, nDFIG, 2);           % [rows x cols x T] = [1 x nDFIG x 2]
    breaker_ts.signals.values = bk_vals;   % all DFIGs connected at both time points
    breaker_ts.signals.dimensions = [1, nDFIG];

    % 2b. Configure Step blocks and breaker_ts based on pertType
    switch pertType
        case 'generation_loss'
            % REAL BREAKER DISCONNECTION via breaker_status_src (From Workspace).
            % breaker_status [1xnDFIG]: 1=connected, 0=disconnected.
            % Disconnected DFIGs: STATE_DERIVATIVE zeroed (dynamics frozen),
            % all currents zeroed (no electrical output to grid).
            if any(pertConfig.breaker_mask)
                t_break = pertConfig.breaker_time + SETTLING_TIME;
                status_after = ones(1, nDFIG) - pertConfig.breaker_mask;
                bk_vals = ones(1, nDFIG, 2);       % [1 x nDFIG x T]
                bk_vals(1, :, 2) = status_after;    % t=t_break: disconnect
                breaker_ts.time = [0; t_break];
                breaker_ts.signals.values = bk_vals;
                breaker_ts.signals.dimensions = [1, nDFIG];
            end

        case 'voltage_sag'
            % Voltage sag/swell on v_grid_r (real part of grid voltage).
            % inc_vdroop_1: applies voltage change at sag_start_time
            % inc_vdroop_2: recovers voltage at sag_start_time + sag_duration
            % Net effect on v_grid_r:
            %   t < t_start:          0 (no change)
            %   t_start <= t < t_end: delta_v (negative=drop/sag, positive=swell)
            %   t >= t_end:           delta_v + (-delta_v) = 0 (recovered)
            % sag_depth > 0: voltage sag (drop), sag_depth < 0: voltage swell (rise)
            % sag_duration >> sim_duration: effectively a step (no recovery during sim)
            if pertConfig.sag_depth ~= 0
                MODEL_INI = mdlWks.getVariable('MODEL_INI');
                v_grid_r_ini = MODEL_INI.GRID.INPUT.v_grid_r;
                delta_v = -pertConfig.sag_depth * v_grid_r_ini;

                t_start = pertConfig.sag_start_time + SETTLING_TIME;
                t_end = t_start + pertConfig.sag_duration;

                set_param([pertSubsys '/inc_vdroop_1'], ...
                    'Time', num2str(t_start), 'After', num2str(delta_v));
                set_param([pertSubsys '/inc_vdroop_2'], ...
                    'Time', num2str(t_end), 'After', num2str(-delta_v));
            end

        case 'both'
            % Combined: real breaker disconnection + voltage sag/swell
            if any(pertConfig.breaker_mask)
                t_break = pertConfig.breaker_time + SETTLING_TIME;
                status_after = ones(1, nDFIG) - pertConfig.breaker_mask;
                bk_vals = ones(1, nDFIG, 2);       % [1 x nDFIG x T]
                bk_vals(1, :, 2) = status_after;    % t=t_break: disconnect
                breaker_ts.time = [0; t_break];
                breaker_ts.signals.values = bk_vals;
                breaker_ts.signals.dimensions = [1, nDFIG];
            end
            if pertConfig.sag_depth ~= 0
                MODEL_INI = mdlWks.getVariable('MODEL_INI');
                v_grid_r_ini = MODEL_INI.GRID.INPUT.v_grid_r;
                delta_v = -pertConfig.sag_depth * v_grid_r_ini;
                t_start = pertConfig.sag_start_time + SETTLING_TIME;
                t_end = t_start + pertConfig.sag_duration;
                set_param([pertSubsys '/inc_vdroop_1'], ...
                    'Time', num2str(t_start), 'After', num2str(delta_v));
                set_param([pertSubsys '/inc_vdroop_2'], ...
                    'Time', num2str(t_end), 'After', num2str(-delta_v));
            end

        case 'pref_step'
            % Direct P_ref step with per-DFIG mask support.
            % pref_mask_vec is read by the Gain block in PERTURBATION & MONITORING
            % (added by SETUP_PERTURBATION_BLOCKS.m). Without setup, only DFIG1 is affected.
            if pertConfig.pref_delta ~= 0
                assignin('base', 'pref_mask_vec', pertConfig.pref_mask);
                set_param([pertSubsys '/inc_Pref'], ...
                    'Time', num2str(pertConfig.pref_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.pref_delta));
            end

        case 'qref_step'
            % Q_ref step via inc_Qref (added by SETUP_PERTURBATION_BLOCKS.m).
            % qref_mask_vec read by Gain block to route step to selected DFIGs.
            if pertConfig.qref_delta ~= 0 && any(pertConfig.qref_mask)
                assignin('base', 'qref_mask_vec', pertConfig.qref_mask);
                set_param([pertSubsys '/inc_Qref'], ...
                    'Time', num2str(pertConfig.qref_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.qref_delta));
            end

        case 'load_step'
            % Load current step: real (inc_iL1_r) + reactive (inc_iL1_i).
            % inc_iL1_i requires SETUP_PERTURBATION_BLOCKS.m to have been run.
            if pertConfig.load_delta_r ~= 0
                set_param([pertSubsys '/inc_iL1_r'], ...
                    'Time', num2str(pertConfig.load_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.load_delta_r));
            end
            if pertConfig.load_delta_i ~= 0
                set_param([pertSubsys '/inc_iL1_i'], ...
                    'Time', num2str(pertConfig.load_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.load_delta_i));
            end

        case 'wind_change'
            % Wind speed step via inc_windspeed
            if pertConfig.vw_delta_val ~= 0
                set_param([pertSubsys '/inc_windspeed'], ...
                    'Time', num2str(pertConfig.vw_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.vw_delta_val));
            end

        case 'custom'
            % Apply all configured perturbations
            if any(pertConfig.breaker_mask)
                % Real breaker disconnection
                t_break = pertConfig.breaker_time + SETTLING_TIME;
                status_after = ones(1, nDFIG) - pertConfig.breaker_mask;
                bk_vals = ones(1, nDFIG, 2);       % [1 x nDFIG x T]
                bk_vals(1, :, 2) = status_after;    % t=t_break: disconnect
                breaker_ts.time = [0; t_break];
                breaker_ts.signals.values = bk_vals;
                breaker_ts.signals.dimensions = [1, nDFIG];
            end
            if pertConfig.pref_delta ~= 0
                assignin('base', 'pref_mask_vec', pertConfig.pref_mask);
                set_param([pertSubsys '/inc_Pref'], ...
                    'Time', num2str(pertConfig.pref_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.pref_delta));
            end
            if pertConfig.qref_delta ~= 0 && any(pertConfig.qref_mask)
                assignin('base', 'qref_mask_vec', pertConfig.qref_mask);
                set_param([pertSubsys '/inc_Qref'], ...
                    'Time', num2str(pertConfig.qref_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.qref_delta));
            end
            if pertConfig.sag_depth ~= 0
                MODEL_INI = mdlWks.getVariable('MODEL_INI');
                v_grid_r_ini = MODEL_INI.GRID.INPUT.v_grid_r;
                delta_v = -pertConfig.sag_depth * v_grid_r_ini;
                t_start = pertConfig.sag_start_time + SETTLING_TIME;
                t_end = t_start + pertConfig.sag_duration;
                set_param([pertSubsys '/inc_vdroop_1'], ...
                    'Time', num2str(t_start), 'After', num2str(delta_v));
                set_param([pertSubsys '/inc_vdroop_2'], ...
                    'Time', num2str(t_end), 'After', num2str(-delta_v));
            end
            if pertConfig.load_delta_r ~= 0
                set_param([pertSubsys '/inc_iL1_r'], ...
                    'Time', num2str(pertConfig.load_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.load_delta_r));
            end
            if pertConfig.load_delta_i ~= 0
                set_param([pertSubsys '/inc_iL1_i'], ...
                    'Time', num2str(pertConfig.load_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.load_delta_i));
            end
            if pertConfig.vw_delta_val ~= 0
                set_param([pertSubsys '/inc_windspeed'], ...
                    'Time', num2str(pertConfig.vw_time + SETTLING_TIME), ...
                    'After', num2str(pertConfig.vw_delta_val));
            end
    end

    % 3. Assign breaker_ts to base workspace for breaker_status_src (From Workspace)
    assignin('base', 'breaker_ts', breaker_ts);

    % Simulation timing
    set_param(modelName, 'StopTime', num2str(pertConfig.sim_duration + SETTLING_TIME));

    % Solver configuration for ode23t (variable-step, stiff/DAE)
    % MinStep: SIM_SAMPLING_TIME (~1e-6) for fast transient capture
    % MaxStep: 1e-3 (1ms) — phenomena of interest are 0.1-100 Hz,
    %   Nyquist at 1 kHz is more than sufficient. The solver uses small
    %   steps during transients and large steps in quasi-steady-state.
    %   Default 'auto' is overly conservative (~10us avg), wasting compute.
    set_param(modelName, 'MinStep', num2str(LIN_MODEL.MODEL.PARAM.SIM_SAMPLING_TIME));
    if isfield(pertConfig, 'solver_MaxStep')
        set_param(modelName, 'MaxStep', num2str(pertConfig.solver_MaxStep));
    else
        set_param(modelName, 'MaxStep', '1e-3');
    end
    if isfield(pertConfig, 'solver_RelTol')
        set_param(modelName, 'RelTol', num2str(pertConfig.solver_RelTol));
    end
    if isfield(pertConfig, 'sim_mode')
        set_param(modelName, 'SimulationMode', pertConfig.sim_mode);
    end

    %----------------------------------------------------------------------
    %% RUN SIMULATION
    %----------------------------------------------------------------------
    set_param(modelName, 'ReturnWorkspaceOutputs', 'on');
    simOut = sim(modelName);

    % Retrieve SCOPE_SIM: prefer SimulationOutput, fallback to workspace
    if ~isempty(simOut.who) && any(strcmp(simOut.who, 'SCOPE_SIM'))
        SCOPE_SIM = simOut.get('SCOPE_SIM');
    elseif evalin('base', 'exist(''SCOPE_SIM'',''var'')')
        SCOPE_SIM = evalin('base', 'SCOPE_SIM');
    else
        error('RUN_PERTURBATION_SIM:noScope', 'SCOPE_SIM not found');
    end

    %----------------------------------------------------------------------
    %% EXTRACT RESULTS
    %----------------------------------------------------------------------
    % R2025a stores Scope data as 3D arrays [channels x 1 x timeSteps]
    % Convert to 2D [timeSteps x channels] for backward compatibility
    results.t         = SCOPE_SIM.time;
    sig11 = SCOPE_SIM.signals(11).values;
    sig6  = SCOPE_SIM.signals(6).values;
    sig1  = SCOPE_SIM.signals(1).values;
    sig5  = SCOPE_SIM.signals(5).values;
    if ndims(sig11) == 3
        results.f      = squeeze(sig11(1,1,:));           % Grid frequency (pu)
        results.Vpcc   = squeeze(sig6(3,1,:));            % PCC voltage (pu)
        results.P_dfig = squeeze(permute(sig1,[3 1 2]));  % [T x channels]
        results.Q_dfig = squeeze(permute(sig5,[3 1 2]));  % [T x channels]
    else
        results.f      = sig11(:,1);
        results.Vpcc   = sig6(:,3);
        results.P_dfig = sig1;
        results.Q_dfig = sig5;
    end
    results.SCOPE_SIM = SCOPE_SIM;
    results.success   = true;
    results.pertType  = pertType;
    results.pertConfig = pertConfig;

    %----------------------------------------------------------------------
    %% SETTLING PHASE: QUALITY CHECK AND TRIMMING
    %----------------------------------------------------------------------
    results.settling.SETTLING_TIME = SETTLING_TIME;

    if SETTLING_TIME > 0
        % Evaluate signal flatness at the end of the settling window
        idx_start = find(results.t >= SETTLING_TIME, 1);
        if isempty(idx_start)
            error('RUN_PERTURBATION_SIM:settlingError', ...
                  'Simulation too short for %.1f s settling phase', SETTLING_TIME);
        end
        nCheck = min(200, round(idx_start/2));
        settle_check = max(1, idx_start - nCheck):(idx_start - 1);

        results.settling.f_mean = mean(results.f(settle_check));
        results.settling.f_std  = std(results.f(settle_check));
        results.settling.V_mean = mean(results.Vpcc(settle_check));
        results.settling.V_std  = std(results.Vpcc(settle_check));

        % Trim settling phase from results
        results.t      = results.t(idx_start:end) - SETTLING_TIME;
        results.f      = results.f(idx_start:end);
        results.Vpcc   = results.Vpcc(idx_start:end);
        results.P_dfig = results.P_dfig(idx_start:end,:);
        results.Q_dfig = results.Q_dfig(idx_start:end,:);
    else
        % No settling phase — perturbation applied directly
        results.settling.f_mean = results.f(1);
        results.settling.f_std  = 0;
        results.settling.V_mean = results.Vpcc(1);
        results.settling.V_std  = 0;
    end

    %----------------------------------------------------------------------
    %% CLEANUP: Re-disable PERTURBATION & MONITORING
    %----------------------------------------------------------------------
    % CRITICAL: Must recomment to ensure next linearize() call produces
    % correct state-space dimensions (without perturbation inputs)
    set_param([modelName '/PERTURBATION & MONITORING'], 'Commented', 'on');

catch ME
    %----------------------------------------------------------------------
    %% ERROR HANDLING
    %----------------------------------------------------------------------
    results.t          = [];
    results.f          = [];
    results.Vpcc       = [];
    results.P_dfig     = [];
    results.Q_dfig     = [];
    results.SCOPE_SIM  = [];
    results.success    = false;
    results.pertType   = pertType;
    results.pertConfig = pertConfig;
    results.error      = ME.message;

    % CRITICAL: Attempt to re-comment PERTURBATION & MONITORING even on error
    % to prevent corrupting next linearization call
    try
        set_param([modelName '/PERTURBATION & MONITORING'], 'Commented', 'on');
    catch
        % Model may not be open; ignore cleanup error
    end

    warning('RUN_PERTURBATION_SIM:simFailed', ...
        'Simulation failed: %s', ME.message);
end

%--------------------------------------------------------------------------
%% RETURN TO STARTING DIRECTORY
%--------------------------------------------------------------------------
cd(startDir);

end
