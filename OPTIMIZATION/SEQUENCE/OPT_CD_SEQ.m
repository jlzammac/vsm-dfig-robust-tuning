function CD_SEQ_TABLE = OPT_CD_SEQ(LIN_MODEL, numWorkers, maxSequences)
% OPT_CD_SEQ Optimize control design sequence to minimize specification errors
%
% This function tests different control design sequences to find the optimal order
% that minimizes deviation between specified and achieved frequency-response margins.
% The algorithm:
%   1. Generates permutations of 7 controllers (VSM P/Q, RSC d/q, VDC, GSC d/q)
%   2. Tests each sequence in parallel using frequency-response control design
%   3. Calculates percentage error between specifications and achieved margins
%   4. Ranks sequences by mean absolute error across all 13 specifications
%
% INPUTS:
%   LIN_MODEL     - Linear model structure with control design specifications
%                   Must contain frdSpecs for all controllers (VSMP, VSMQ, RSC, VDC, GSC)
%   numWorkers    - Number of parallel workers (default: 10)
%   maxSequences  - Maximum sequences to test ([] = all 5040 permutations, or specify subset)
%
% OUTPUT:
%   CD_SEQ_TABLE  - Table with tested sequences sorted by mean absolute error (best first)
%                   Columns 1-7:   Design sequence indices
%                   Columns 8-20:  Achieved frequency-response margins
%                   Column 21:     Stability flag (1 = stable, 0 = unstable)
%                   Columns 22-34: Percentage errors for each specification
%                   Column 35:     Mean absolute error (sorting criterion)

% Default parameters
if nargin < 2 || isempty(numWorkers)
    numWorkers = 10;
end
if nargin < 3
    maxSequences = [];
end

format compact
format short g

%--------------------------------------------------------------------------
%% CONTROL DESIGN SEQUENCE PERMUTATIONS
%--------------------------------------------------------------------------
% Generate all permutations (7! = 5040)
all_perms = perms(1:7);
N_total = size(all_perms, 1);

% Select subset if requested
if ~isempty(maxSequences) && maxSequences < N_total
    % Random sampling of sequences for faster testing
    fprintf('Selecting random subset of %d sequences from %d total\n', maxSequences, N_total)
    rng('default')  % For reproducibility
    idx = randperm(N_total, maxSequences);
    selected_perms = all_perms(idx, :);
    N = maxSequences;
else
    % Use all permutations
    selected_perms = all_perms;
    N = N_total;
end

% Create table
CD_SEQ_TABLE = array2table(selected_perms, ...
    'VariableNames', {'C1','C2','C3','C4','C5','C6','C7'});

fprintf('Testing %d design sequences with %d parallel workers\n', N, numWorkers)

%--------------------------------------------------------------------------
%% PARPOOL CONFIGURATION
%--------------------------------------------------------------------------
% Configure parallel computing pool for efficient sequence testing
poolObj = gcp('nocreate');
if isempty(poolObj)
    % No pool exists - create new one
    parpool(numWorkers);
elseif poolObj.NumWorkers ~= numWorkers
    % Existing pool has wrong size - recreate
    delete(poolObj);
    parpool(numWorkers);
else
    % Existing pool has correct size - reuse
    fprintf('Reusing existing parallel pool with %d workers\n', numWorkers)
end
%--------------------------------------------------------------------------
%% BUS DEFINITIONS AND MODEL PREPARATION
%--------------------------------------------------------------------------
% Generate bus definitions (persistent across parallel workers)
cd '../../BUS_DEFINITIONS'
BusDefinition(LIN_MODEL.CONTROL,'CONTROL_Bus')
BusDefinition(LIN_MODEL.MODEL,'MODEL_Bus')

% Create worker-specific Simulink model copies for parallel execution
% Pattern from OPTIMIZER.m lines 331-340
cd('../SIMULINK');
model.name = LIN_MODEL.modelName;

% Clean up any existing worker models first
bdclose('all')
delete([model.name '_*.slx'])

% Create fresh worker model copies
for nn = 1:numWorkers
    open_system(model.name,'loadonly')
    save_system(model.name,[model.name '_' num2str(nn)]);
    close_system([model.name '_' num2str(nn)])
    fprintf('  Created: %s.slx\n', [model.name '_' num2str(nn)])
end
close_system(model.name)
cd('../OPTIMIZATION/SEQUENCE');

% Replicate LIN_MODEL for parallel processing
LIN_MODEL_ARRAY = repmat(LIN_MODEL,N,1);
VSMP_Fm = NaN(N,1);
VSMP_wo = NaN(N,1);
VSMQ_wo = NaN(N,1);
RSCd_Fm = NaN(N,1);
RSCd_wo = NaN(N,1);
RSCq_Fm = NaN(N,1);
RSCq_wo = NaN(N,1);
VDC_Fm = NaN(N,1);
VDC_wo = NaN(N,1);
GSCd_Fm = NaN(N,1);
GSCd_wo = NaN(N,1);
GSCq_Fm = NaN(N,1);
GSCq_wo = NaN(N,1);
stability = NaN(N,1);

%--------------------------------------------------------------------------
%% PARALLEL CONTROL DESIGN LOOP
%--------------------------------------------------------------------------
% Extract sequences as array to avoid broadcast variable in parfor
sequences_array = table2array(CD_SEQ_TABLE);

fprintf('Starting parallel control design sequence optimization...\n')
tic
parfor nn = 1:N
    warning('off')

    % CRITICAL: Generate bus definitions in each worker's workspace
    % Pattern from OPTIMIZER.m lines 443-445
    % Starting from OPTIMIZATION/SEQUENCE, navigate to BUS_DEFINITIONS
    cd('../../BUS_DEFINITIONS')
    BusDefinition(LIN_MODEL_ARRAY(nn).CONTROL,'CONTROL_Bus')
    BusDefinition(LIN_MODEL_ARRAY(nn).MODEL,'MODEL_Bus')

    % Get worker ID for model selection
    worker = getCurrentTask();
    if isempty(worker)
       workerID = 1;
    else
       workerID = worker.ID;
    end

    % Create local copy and assign control design sequence
    LIN_MODEL_local = LIN_MODEL_ARRAY(nn);
    LIN_MODEL_local.CONTROL_DESIGN.designOrder = sequences_array(nn,:);

    % Execute frequency-response control design
    % From BUS_DEFINITIONS, navigate to CONTROL
    cd('../CONTROL')
    LIN_MODEL_local = CONTROL_DESIGN_FR(LIN_MODEL_local,false,workerID);

    % Extract achieved frequency-response margins
    VSMP_Fm(nn) = LIN_MODEL_local.CONTROL_DESIGN.VSMP.frdMargins.Fm;
    VSMP_wo(nn) = LIN_MODEL_local.CONTROL_DESIGN.VSMP.frdMargins.wo;
    VSMQ_wo(nn) = LIN_MODEL_local.CONTROL_DESIGN.VSMQ.frdMargins.wo;
    RSCd_Fm(nn) = LIN_MODEL_local.CONTROL_DESIGN.RSC.frdMargins.Fm(1);
    RSCd_wo(nn) = LIN_MODEL_local.CONTROL_DESIGN.RSC.frdMargins.wo(1);
    RSCq_Fm(nn) = LIN_MODEL_local.CONTROL_DESIGN.RSC.frdMargins.Fm(2);
    RSCq_wo(nn) = LIN_MODEL_local.CONTROL_DESIGN.RSC.frdMargins.wo(2);
    VDC_Fm(nn) = LIN_MODEL_local.CONTROL_DESIGN.VDC.frdMargins.Fm;
    VDC_wo(nn) = LIN_MODEL_local.CONTROL_DESIGN.VDC.frdMargins.wo;
    GSCd_Fm(nn) = LIN_MODEL_local.CONTROL_DESIGN.GSC.frdMargins.Fm(1);
    GSCd_wo(nn) = LIN_MODEL_local.CONTROL_DESIGN.GSC.frdMargins.wo(1);
    GSCq_Fm(nn) = LIN_MODEL_local.CONTROL_DESIGN.GSC.frdMargins.Fm(2);
    GSCq_wo(nn) = LIN_MODEL_local.CONTROL_DESIGN.GSC.frdMargins.wo(2);
    stability(nn) = LIN_MODEL_local.stability;

    % Display progress (non-blocking in parfor)
    fprintf('Worker %d: Sequence %d/%d: [%s] - Stability: %d\n', ...
        workerID, nn, N, num2str(sequences_array(nn,:)), stability(nn));
end
elapsed_time = toc;
fprintf('Parallel optimization completed in %.2f seconds\n', elapsed_time)

%--------------------------------------------------------------------------
%% RESULTS COMPILATION AND ERROR ANALYSIS
%--------------------------------------------------------------------------
% Extract target specifications from original LIN_MODEL
SPEC_VSMP_Fm = LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.Fm;
SPEC_VSMP_wo = LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.wo;
SPEC_VSMQ_wo = LIN_MODEL.CONTROL_DESIGN.VSMQ.frdSpecs.wo;
SPEC_RSCd_Fm = LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.Fm(1);
SPEC_RSCd_wo = LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.wo(1);
SPEC_RSCq_Fm = LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.Fm(2);
SPEC_RSCq_wo = LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.wo(2);
SPEC_VDC_Fm = LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.Fm;
SPEC_VDC_wo = LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.wo;
SPEC_GSCd_Fm = LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.Fm(1);
SPEC_GSCd_wo = LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.wo(1);
SPEC_GSCq_Fm = LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.Fm(2);
SPEC_GSCq_wo = LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.wo(2);

% Add achieved frequency-response margins to table (columns 8-20)
CD_SEQ_TABLE.VSMP_Fm = VSMP_Fm;
CD_SEQ_TABLE.VSMP_wo = VSMP_wo;
CD_SEQ_TABLE.VSMQ_wo = VSMQ_wo;
CD_SEQ_TABLE.RSCd_Fm = RSCd_Fm;
CD_SEQ_TABLE.RSCd_wo = RSCd_wo;
CD_SEQ_TABLE.RSCq_Fm = RSCq_Fm;
CD_SEQ_TABLE.RSCq_wo = RSCq_wo;
CD_SEQ_TABLE.VDC_Fm = VDC_Fm;
CD_SEQ_TABLE.VDC_wo = VDC_wo;
CD_SEQ_TABLE.GSCd_Fm = GSCd_Fm;
CD_SEQ_TABLE.GSCd_wo = GSCd_wo;
CD_SEQ_TABLE.GSCq_Fm = GSCq_Fm;
CD_SEQ_TABLE.GSCq_wo = GSCq_wo;

% Add stability flag (column 21)
CD_SEQ_TABLE.stability = stability;

% Calculate percentage errors between specifications and achieved margins (columns 22-34)
CD_SEQ_TABLE.ERR_VSMP_Fm = 100*(VSMP_Fm - SPEC_VSMP_Fm)/SPEC_VSMP_Fm;
CD_SEQ_TABLE.ERR_VSMP_wo = 100*(VSMP_wo - SPEC_VSMP_wo)/SPEC_VSMP_wo;
CD_SEQ_TABLE.ERR_VSMQ_wo = 100*(VSMQ_wo - SPEC_VSMQ_wo)/SPEC_VSMQ_wo;
CD_SEQ_TABLE.ERR_RSCd_Fm = 100*(RSCd_Fm - SPEC_RSCd_Fm)/SPEC_RSCd_Fm;
CD_SEQ_TABLE.ERR_RSCd_wo = 100*(RSCd_wo - SPEC_RSCd_wo)/SPEC_RSCd_wo;
CD_SEQ_TABLE.ERR_RSCq_Fm = 100*(RSCq_Fm - SPEC_RSCq_Fm)/SPEC_RSCq_Fm;
CD_SEQ_TABLE.ERR_RSCq_wo = 100*(RSCq_wo - SPEC_RSCq_wo)/SPEC_RSCq_wo;
CD_SEQ_TABLE.ERR_VDC_Fm = 100*(VDC_Fm - SPEC_VDC_Fm)/SPEC_VDC_Fm;
CD_SEQ_TABLE.ERR_VDC_wo = 100*(VDC_wo - SPEC_VDC_wo)/SPEC_VDC_wo;
CD_SEQ_TABLE.ERR_GSCd_Fm = 100*(GSCd_Fm - SPEC_GSCd_Fm)/SPEC_GSCd_Fm;
CD_SEQ_TABLE.ERR_GSCd_wo = 100*(GSCd_wo - SPEC_GSCd_wo)/SPEC_GSCd_wo;
CD_SEQ_TABLE.ERR_GSCq_Fm = 100*(GSCq_Fm - SPEC_GSCq_Fm)/SPEC_GSCq_Fm;
CD_SEQ_TABLE.ERR_GSCq_wo = 100*(GSCq_wo - SPEC_GSCq_wo)/SPEC_GSCq_wo;

% Calculate mean absolute error across all specifications (column 35)
% This is the primary ranking criterion for sequence quality
CD_SEQ_TABLE.ERR_ABS_MEAN = mean(abs(CD_SEQ_TABLE{:,22:34}), 2);

% Sort table by mean absolute error (best sequences first)
CD_SEQ_TABLE = sortrows(CD_SEQ_TABLE, 'ERR_ABS_MEAN', 'ascend');

fprintf('-------------------------------------------------------------------------\n')
fprintf('Optimization Results Summary:\n')
fprintf('  Best sequence: [%s]\n', num2str(CD_SEQ_TABLE{1,1:7}))
fprintf('  Mean absolute error: %.2f%%\n', CD_SEQ_TABLE.ERR_ABS_MEAN(1))
fprintf('  Stability: %d\n', CD_SEQ_TABLE.stability(1))
fprintf('-------------------------------------------------------------------------\n')

%--------------------------------------------------------------------------
%% CLEANUP - DELETE AUXILIARY SIMULINK MODELS
%--------------------------------------------------------------------------
% Remove worker-specific Simulink model copies created for parallel execution
fprintf('Cleaning up temporary Simulink model copies...\n')
cd('../../SIMULINK');
bdclose('all')  % Close all open Simulink models

% Delete ALL worker-related files using wildcard pattern
% This includes: .slx (source), .slxc (compiled cache), .r2024a (backups), etc.
% Pattern: POWER_SYSTEM_FULL_*.* captures all extensions
allModelFiles = dir([LIN_MODEL.modelName '_*.*']);

% Filter out the main model file (keep only worker files with _N pattern)
workerPattern = [LIN_MODEL.modelName '_\d+\.'];  % Regex: POWER_SYSTEM_FULL_<number>.
workerFiles = {};
for i = 1:length(allModelFiles)
    if ~isempty(regexp(allModelFiles(i).name, workerPattern, 'once'))
        workerFiles{end+1} = allModelFiles(i).name;
    end
end

if ~isempty(workerFiles)
    for i = 1:length(workerFiles)
        delete(fullfile(allModelFiles(1).folder, workerFiles{i}));
        fprintf('  Deleted: %s\n', workerFiles{i})
    end
    fprintf('Deleted %d worker files\n', length(workerFiles))
else
    fprintf('  No temporary worker files found to delete\n')
end

cd('../OPTIMIZATION/SEQUENCE')
fprintf('Cleanup complete. Optimization finished.\n')

end


