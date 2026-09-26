function LIN_MODEL = LINEARIZE(LIN_MODEL,workerID)
% LINEARIZE Re-linearizes Simulink model with updated operating point
%
% SYNTAX:
%   LIN_MODEL = LINEARIZE(LIN_MODEL)
%   LIN_MODEL = LINEARIZE(LIN_MODEL, workerID)
%
% INPUTS:
%   LIN_MODEL - Structure containing:
%               .MODEL: System model parameters
%               .CONTROL: Control parameters (updated controller gains)
%               .initialMemoryState: Initial conditions from LINEAR_ANALYSIS
%               .opModel: Operating point object from LINEAR_ANALYSIS
%               .modelName: Simulink model name ('POWER_SYSTEM_FULL' or 'POWER_SYSTEM_SIMP')
%   workerID  - (Optional) Worker ID for parallel execution (0 = sequential, >0 = parallel worker)
%               Default: 0
%
% OUTPUTS:
%   LIN_MODEL - Updated structure with:
%               .ssModel: Re-linearized state-space model reflecting new control parameters
%
% DESCRIPTION:
%   This function re-linearizes a Simulink model after control parameters
%   have been modified during iterative control design. It preserves the
%   operating point computed by LINEAR_ANALYSIS and only updates the
%   system state-space matrices to reflect new controller gains.
%
%   Typical usage pattern in CONTROL_DESIGN_FR:
%   1. Initial linearization with LINEAR_ANALYSIS (computes operating point)
%   2. Update controller parameters (Kp, Ki values)
%   3. Call LINEARIZE to get updated state-space model
%   4. Repeat steps 2-3 for each controller in design sequence
%
% PERFORMANCE:
%   Typical execution time: ~2.1-3.2 seconds per call
%   - Simulink model operations: ~50-100ms
%   - Linearization (numericalpert): ~2000-3000ms
%
%   Called 7 times during CONTROL_DESIGN_FR (one per controller):
%   Total linearization time: ~15-22 seconds
%
% NOTES:
%   - Uses 'numericalpert' linearization algorithm for numerical robustness
%   - Operating point is NOT recomputed (uses opModel from LINEAR_ANALYSIS)
%   - Safe for parallel execution via workerID parameter
%   - Model workspace variables are updated but model structure is unchanged
%
% SEE ALSO:
%   LINEAR_ANALYSIS, CONTROL_DESIGN_FR, linearize, operspec

if nargin == 1
    workerID = 0;
end

%--------------------------------------------------------------------------
%% COPY MODEL & CONTROL
%--------------------------------------------------------------------------
CONTROL = LIN_MODEL.CONTROL;
MODEL = LIN_MODEL.MODEL;
initialMemoryState = LIN_MODEL.initialMemoryState;
% Number of DFIGs
nDFIG = MODEL.DFIG.PARAM.nDFIG;
% Number of grids
nGRID = MODEL.GRID.PARAM.nGRID;
% Number of lines
nLINE = MODEL.LINE.PARAM.nLINE;

%--------------------------------------------------------------
%% MODEL DEFINITION
%--------------------------------------------------------------
cd('../SIMULINK');
model.name = LIN_MODEL.modelName;
if workerID
    model.name = [model.name '_' num2str(workerID)];
end
% Ensure base workspace has breaker_ts and Bus objects for model compilation
% (parallel workers start with empty base workspace)
if ~evalin('base', 'exist(''breaker_ts'',''var'')')
    bt.time = [0; 100];
    bt.signals.values = ones(1, nDFIG, 2);
    bt.signals.dimensions = [1, nDFIG];
    assignin('base', 'breaker_ts', bt);
end
if ~evalin('base', 'exist(''MODEL_Bus'',''var'')')
    cd('../BUS_DEFINITIONS');
    BusDefinition(MODEL, 'MODEL_Bus');
    BusDefinition(CONTROL, 'CONTROL_Bus');
    cd('../SIMULINK');
end
open_system(model.name,'loadonly')
model.workspace = get_param(model.name,'modelworkspace');
assignin(model.workspace,'initialMemoryState',initialMemoryState);
assignin(model.workspace,'MODEL_INI',MODEL);
assignin(model.workspace,'CONTROL_INI',CONTROL);   

%--------------------------------------------------------------
%% LINEARIZATION
%--------------------------------------------------------------
% State-space linear model
opModel = LIN_MODEL.opModel;
opModel.model = model.name;
linOptions = linearizeOptions;
linOptions.LinearizationAlgorithm = 'numericalpert';
% Options for LINEARIZE:
%     LinearizationAlgorithm         : blockbyblock
%     SampleTime (-1 Auto Detect)    : -1
%     UseFullBlockNameLabels (on/off): off
%     UseBusSignalLabels (on/off)    : off
%     StoreOffsets (true/false)      : false
%     StoreAdvisor (true/false)      : false
% 
% Options for 'blockbyblock' algorithm
%     BlockReduction (on/off)                   : on
%     IgnoreDiscreteStates (on/off)             : off
%     RateConversionMethod (zoh/tustin/prewarp/ : zoh
%                           upsampling_zoh/           
%                           upsampling_tustin/        
%                           upsampling_prewarp        
%     PreWarpFreq                               : 10
%     UseExactDelayModel (on/off)               : off
%     AreParamsTunable (true/false)             : true
% 
% Options for 'numericalpert' algorithm
%     NumericalPertRel : 1.000000e-05
%     NumericalXPert   : []
%     NumericalUPert   : []
opModel = update(opModel);
LIN_MODEL.ssModel = linearize(model.name,opModel,linOptions);

return
