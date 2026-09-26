function LIN_MODEL_PARETO = GEN_LIN_MODEL_PARETO(optType, numWorkers)
% GEN_LIN_MODEL_PARETO - Generate linearized models for all Pareto front solutions
%
% DESCRIPTION:
%   Processes all optimal solutions from genetic algorithm optimization,
%   applying each parameter set to generate complete linearized models.
%   Uses parallel computing to evaluate all Pareto front members efficiently.
%
% SYNTAX:
%   LIN_MODEL_PARETO = GEN_LIN_MODEL_PARETO(optType)
%   LIN_MODEL_PARETO = GEN_LIN_MODEL_PARETO(optType, numWorkers)
%
% INPUTS:
%   optType    - Optimization type (1-5):
%                1: PDS - P-axis droop slope frequency-response specs
%                2: QDS - Q-axis droop slope frequency-response specs
%                3: PCP - P-axis current PI controller parameters
%                4: QCP - Q-axis current PI controller parameters
%                5: VI  - Virtual impedance parameters
%   numWorkers - (Optional) Number of parallel workers (default: 4)
%
% OUTPUTS:
%   LIN_MODEL_PARETO - Array of linearized models (N×1) where N is Pareto size
%                      Each element contains complete system with optimized control
%
% FILE DEPENDENCIES:
%   INPUT:  RESULTS/GA_OPTIMIZATION/GAM_[PDS|QDS|PCP|QCP|VI].mat
%   CALLS:  CONTROL_DESIGN_FR.m (for optType 1-2)
%           LINEAR_ANALYSIS.m (for optType 3-5)
%           BusDefinition.m (for all types)
%
% OPERATING PRINCIPLE:
%   1. Load Pareto front from GAM file (param_opt, LIN_MODEL)
%   2. Scale parameters to engineering units
%   3. Create parallel pool with worker-specific Simulink models
%   4. For each Pareto member in parallel:
%      - Update control parameters based on optType
%      - Regenerate control (FRD) or relinearize (direct params)
%      - Compute eigenvalues and performance metrics
%   5. Return array of complete linearized models
%
% PARALLEL EXECUTION:
%   Uses MATLAB parpool with worker-specific Simulink model copies
%   to avoid file conflicts during parallel linearization.
%
% NOTES:
%   - Parameter scaling vector matches OPTIMIZER.m convention
%   - Paths navigate from OPTIMIZATION/GA_MULTIOBJECTIVE/ directory
%   - Temporary worker-specific Simulink models deleted after completion
%   - All workers must have access to shared CONTROL, CONFIGURATION directories
%
% EXAMPLE:
%   % Generate all Pareto solutions for PDS optimization
%   LIN_MODEL_PARETO = GEN_LIN_MODEL_PARETO(1);  % Uses 4 workers default
%
%   % Use 8 parallel workers
%   LIN_MODEL_PARETO = GEN_LIN_MODEL_PARETO(3, 8);
%
% See also: OPTIMIZER, LINEAR_ANALYSIS, CONTROL_DESIGN_FR
%
% Author: Power Systems Research Group
% Last modified: 2025-01-20

%--------------------------------------------------------------------------
% INPUT VALIDATION AND INITIALIZATION
%--------------------------------------------------------------------------
if nargin < 2
    numWorkers = 4;  % Default parallel workers
end

clc;
warning('off', 'all');

% Optimization type string mapping
optStr = {'PDS'; 'QDS'; 'PCP'; 'QCP'; 'VI'};

% Parameter scaling vector (must match OPTIMIZER.m convention)
% Indices 1-8: PDS specs, 9-13: QDS specs, 14-17: PCP params, 18-19: QCP params, 20-21: VI params
scale = [0.1 0.1 0.1 1 0.1 1 0.1 1 ...        % PDS (8)
         0.01 0.1 1 0.1 1 ...                  % QDS (5)
         1 0.01 0.01 0.01 0.01 ...             % PCP (4), QCP (2)
         0.001 0.0001];                        % VI (2)

%--------------------------------------------------------------------------
% LOAD OPTIMIZATION RESULTS
%--------------------------------------------------------------------------
gam_file = fullfile('../../RESULTS/GA_OPTIMIZATION', ['GAM_' optStr{optType} '.mat']);
if ~isfile(gam_file)
    error('GEN_LIN_MODEL_PARETO:FileNotFound', ...
          'GAM file not found: %s\nRun OPTIMIZER first with optType=%d', gam_file, optType);
end

load(gam_file, 'param_opt', 'LIN_MODEL');

% Pareto front size
N = size(param_opt, 1);
fprintf('\n=== PARETO FRONT GENERATION ===\n');
fprintf('Optimization type: %s\n', optStr{optType});
fprintf('Pareto members: %d\n', N);
fprintf('Parallel workers: %d\n\n', numWorkers);

% Scale parameters to engineering units
param_opt = param_opt .* repmat(scale, N, 1);

% Number of DFIGs in system
nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
%--------------------------------------------------------------------------
% PARALLEL POOL CONFIGURATION
%--------------------------------------------------------------------------
% Ensure clean parallel pool state
delete(gcp('nocreate'));

% Open parallel pool with specified workers
parpool(numWorkers);

%--------------------------------------------------------------------------
% PREPARE WORKER-SPECIFIC SIMULINK MODELS
%--------------------------------------------------------------------------
% Navigate to Simulink directory and close all models
cd('../../SIMULINK');
bdclose('all');

% Initialize Pareto array (pre-allocate for efficiency)
LIN_MODEL_PARETO = repmat(LIN_MODEL, N, 1);

% Create worker-specific model copies to avoid parallel conflicts
model_name = LIN_MODEL.modelName;
for nn = 1:numWorkers
    open_system(model_name, 'loadonly');
    save_system(model_name, [model_name '_' num2str(nn)]);
    close_system([model_name '_' num2str(nn)]);
end
close_system(model_name);
%--------------------------------------------------------------------------
% PARETO LOOP - PARALLEL EVALUATION
%--------------------------------------------------------------------------
parfor nn = 1:N
    warning('off', 'all');

    % Update bus definitions for current Pareto member
    cd('../../BUS_DEFINITIONS');
    BusDefinition(LIN_MODEL_PARETO(nn).CONTROL, 'CONTROL_Bus');
    BusDefinition(LIN_MODEL_PARETO(nn).MODEL, 'MODEL_Bus');

    % Get worker ID for progress tracking
    worker = getCurrentTask();
    if isempty(worker)
       workerID = 1;
    else
       workerID = worker.ID;
    end

    fprintf('Worker %d | Pareto member: %d / %d\n', workerID, nn, N);

    % Apply optimized parameters based on optimization type
    switch optType
        case 1  % PDS - P-axis Droop Slope Design Specs
            % Update frequency-response specifications for P-axis controllers
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.VSMP.frdSpecs.Fm      = param_opt(nn, 1);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.VSMP.frdSpecs.wo      = param_opt(nn, 2);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.RSC.frdSpecs.Fm(2)    = param_opt(nn, 3);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.RSC.frdSpecs.wo(2)    = param_opt(nn, 4);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.VDC.frdSpecs.Fm       = param_opt(nn, 5);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.VDC.frdSpecs.wo       = param_opt(nn, 6);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.GSC.frdSpecs.Fm(2)    = param_opt(nn, 7);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.GSC.frdSpecs.wo(2)    = param_opt(nn, 8);

            % Redesign P-axis controllers with new specs
            cd('../../CONTROL');
            LIN_MODEL_PARETO(nn) = CONTROL_DESIGN_FR(LIN_MODEL_PARETO(nn), false, workerID);

        case 2  % QDS - Q-axis Droop Slope Design Specs
            % Update frequency-response specifications for Q-axis controllers
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.VSMQ.frdSpecs.wo      = param_opt(nn, 9);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.RSC.frdSpecs.Fm(1)    = param_opt(nn, 10);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.RSC.frdSpecs.wo(1)    = param_opt(nn, 11);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.GSC.frdSpecs.Fm(1)    = param_opt(nn, 12);
            LIN_MODEL_PARETO(nn).CONTROL_DESIGN.GSC.frdSpecs.wo(1)    = param_opt(nn, 13);

            % Redesign Q-axis controllers with new specs
            cd('../../CONTROL');
            LIN_MODEL_PARETO(nn) = CONTROL_DESIGN_FR(LIN_MODEL_PARETO(nn), false, workerID);

        case 3  % PCP - P-axis Current PI Controller Parameters
            % Update P-axis PI controller b-coefficients (direct parameters)
            LIN_MODEL_PARETO(nn).CONTROL.VSMP.PARAM.der2error = param_opt(nn, 14) * ones(1, nDFIG);
            LIN_MODEL_PARETO(nn).CONTROL.RSCq.PARAM.b         = param_opt(nn, 15) * ones(1, nDFIG);
            LIN_MODEL_PARETO(nn).CONTROL.VDC.PARAM.b          = param_opt(nn, 16) * ones(1, nDFIG);
            LIN_MODEL_PARETO(nn).CONTROL.GSCq.PARAM.b         = param_opt(nn, 17) * ones(1, nDFIG);

            % Relinearize with updated control parameters
            cd('../../CONFIGURATION');
            LIN_MODEL_PARETO(nn) = LINEAR_ANALYSIS(LIN_MODEL_PARETO(nn), workerID);

        case 4  % QCP - Q-axis Current PI Controller Parameters
            % Update Q-axis PI controller b-coefficients (direct parameters)
            LIN_MODEL_PARETO(nn).CONTROL.RSCd.PARAM.b         = param_opt(nn, 18) * ones(1, nDFIG);
            LIN_MODEL_PARETO(nn).CONTROL.GSCd.PARAM.b         = param_opt(nn, 19) * ones(1, nDFIG);

            % Relinearize with updated control parameters
            cd('../../CONFIGURATION');
            LIN_MODEL_PARETO(nn) = LINEAR_ANALYSIS(LIN_MODEL_PARETO(nn), workerID);

        case 5  % VI - Virtual Impedance Parameters
            % Update virtual impedance parameters
            LIN_MODEL_PARETO(nn).CONTROL.VIMP.PARAM.Lv_pu     = param_opt(nn, 20) * ones(1, nDFIG);
            LIN_MODEL_PARETO(nn).CONTROL.VIMP.PARAM.Rv_pu     = zeros(1, nDFIG); % R_v fixed at 0

            % Relinearize with updated virtual impedance
            cd('../../CONFIGURATION');
            LIN_MODEL_PARETO(nn) = LINEAR_ANALYSIS(LIN_MODEL_PARETO(nn), workerID);
    end
end

%--------------------------------------------------------------------------
% CLEANUP - Remove temporary worker-specific models
%--------------------------------------------------------------------------
cd('../../SIMULINK');
bdclose('all');
delete([LIN_MODEL.modelName '_*']);

%--------------------------------------------------------------------------
% DISPLAY DETAILED OPTIMIZATION SUMMARY
%--------------------------------------------------------------------------
% *** PERMANENT MONITORING - DO NOT REMOVE ***
% This section provides detailed results summary after Pareto generation.
%--------------------------------------------------------------------------
cd('../OPTIMIZATION/GA_MULTIOBJECTIVE');
load(gam_file, 'param_opt', 'fval_opt');

% Display detailed summary using best individual (first in Pareto)
display_optimization_summary(optType, param_opt, fval_opt, scale, LIN_MODEL_PARETO(1), N);

fprintf('\n=== PARETO FRONT GENERATION COMPLETE ===\n');
fprintf('Generated %d linearized models\n', N);
fprintf('All temporary files cleaned\n\n');

end

%--------------------------------------------------------------
%% LOCAL FUNCTION - DISPLAY OPTIMIZATION SUMMARY
%--------------------------------------------------------------
% *** PERMANENT MONITORING COMPONENT - DO NOT REMOVE ***
% This function provides detailed summary after Pareto generation completes.
%--------------------------------------------------------------
function display_optimization_summary(optType, param_opt, fval_opt, scale, LIN_MODEL, N)
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

        case 2  % QDS - Q-axis Design Specs
            fprintf('  FREQUENCY-RESPONSE DESIGN SPECIFICATIONS (Q-axis):\n\n');
            fprintf('    VSMQ (Virtual Synchronous Machine - Reactive Power):\n');
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(1));

            fprintf('    RSCd (Rotor Side Converter - d-axis):\n');
            fprintf('      Phase Margin (Fm):       %6.2f°\n', best_param_scaled(2));
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(3));

            fprintf('    GSCd (Grid Side Converter - d-axis):\n');
            fprintf('      Phase Margin (Fm):       %6.2f°\n', best_param_scaled(4));
            fprintf('      Crossover Freq (ωc):     %6.2f rad/s\n\n', best_param_scaled(5));

        case 3  % PCP - P-axis Control Params
            fprintf('  CONTROL PARAMETERS (P-axis):\n\n');
            fprintf('    VSMP:\n');
            fprintf('      der2error (2-DOF):       %6.3f\n\n', best_param_scaled(1));

            fprintf('    RSCq:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(2));

            fprintf('    VDC:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(3));

            fprintf('    GSCq:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(4));

        case 4  % QCP - Q-axis Control Params
            fprintf('  CONTROL PARAMETERS (Q-axis):\n\n');
            fprintf('    RSCd:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(1));

            fprintf('    GSCd:\n');
            fprintf('      b (setpoint weight):     %6.3f\n\n', best_param_scaled(2));

        case 5  % VI - Virtual Impedance
            fprintf('  VIRTUAL IMPEDANCE PARAMETERS:\n\n');
            fprintf('    Lv (Virtual Inductance):   %6.4f pu\n\n', best_param_scaled(1));
    end

    % Performance metrics (objectives)
    fprintf('  PERFORMANCE METRICS:\n\n');
    fprintf('    Objective 1 (-minDamping):   %.4e  →  minDamping = %.4f\n', best_fval(1), -best_fval(1));
    fprintf('    Objective 2 (maxRealEig):    %.4e\n', best_fval(2));
    fprintf('    Objective 3 (ROCOF/ROCOV):   %.4e\n', best_fval(3));
    fprintf('    Objective 4 (Nadir):         %.4e\n\n', best_fval(4));

    % System stability
    fprintf('  SYSTEM STABILITY:\n\n');
    if LIN_MODEL.stability == 1
        fprintf('    Status:                      ✓ STABLE\n');
        fprintf('    Minimum Damping Ratio:       %.4f\n', LIN_MODEL.minDamping(2));
        fprintf('    Maximum Real Eigenvalue:     %.4e\n', LIN_MODEL.maxRealEig);
    else
        fprintf('    Status:                      ✗ UNSTABLE\n');
    end
    fprintf('\n');

    % Pareto front information
    fprintf('  PARETO FRONT:\n\n');
    fprintf('    Solutions in Pareto set:     %d\n', N);
    if N > 1
        fprintf('    (All %d non-dominated solutions available in param_opt/fval_opt)\n', N);
    end
    fprintf('\n');

    fprintf('════════════════════════════════════════════════════════════════════════════\n\n');
end
