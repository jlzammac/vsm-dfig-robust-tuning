function SETUP_PERTURBATION_BLOCKS(varargin)
%SETUP_PERTURBATION_BLOCKS  One-time Simulink model setup for full perturbation API
%
% DESCRIPTION:
%   Adds the following missing blocks to the PERTURBATION & MONITORING
%   subsystem of POWER_SYSTEM_FULL.slx:
%
%     A) inc_Qref  — Q_ref step (per-DFIG mask via Gain block)
%        Topology: inc_Qref (Step) → qref_mask_gain (Gain) → sum_qref (Sum)
%                  ← Const_Qref_ini (Constant) → DSWrite_Qref (DataStoreWrite)
%
%     B) inc_iL1_i — Reactive load step
%        Topology: inc_iL1_i (Step) → sum_iL1i (Sum)
%                  ← Const_iL1i_ini (Constant) → DSWrite_iL1i (DataStoreWrite)
%
%   Also updates the P_ref path to support per-DFIG mask:
%     C) pref_mask_gain inserted between inc_Pref and Mux
%
% USAGE:
%   Run ONCE from the SIMULATION directory (or anywhere on MATLAB path):
%     SETUP_PERTURBATION_BLOCKS()
%
%   Optionally specify model name:
%     SETUP_PERTURBATION_BLOCKS('POWER_SYSTEM_FULL')
%
% NOTE:
%   - Safe to re-run: skips blocks that already exist
%   - Saves and closes the model when done
%   - Must be run before using qref_step, load_step (reactive), or
%     per-DFIG pref_step in RUN_PERTURBATION_SIM
%
% SEE ALSO: RUN_PERTURBATION_SIM

%--------------------------------------------------------------------------
%% CONFIGURATION
%--------------------------------------------------------------------------
if nargin >= 1
    modelName = varargin{1};
else
    modelName = 'POWER_SYSTEM_FULL';
end
pertSubsys = [modelName '/PERTURBATION & MONITORING'];

%--------------------------------------------------------------------------
%% OPEN MODEL
%--------------------------------------------------------------------------
fprintf('=========================================================================\n')
fprintf('  SETUP_PERTURBATION_BLOCKS\n')
fprintf('=========================================================================\n')
fprintf('Model: %s\n', modelName)

% Navigate to SIMULINK directory
thisDir = fileparts(mfilename('fullpath'));  % .../SIMULATION/
simulinkDir = fullfile(thisDir, '..', 'SIMULINK');
startDir = pwd;
cd(simulinkDir);

try
    open_system(modelName, 'loadonly');
    fprintf('Model opened.\n')

    %----------------------------------------------------------------------
    %% STEP 0 — DISCOVER EXISTING TOPOLOGY
    %----------------------------------------------------------------------
    fprintf('\n--- Existing DataStoreWrite blocks in PERTURBATION & MONITORING ---\n')
    dsBlocks = find_system(pertSubsys, 'SearchDepth', 1, 'BlockType', 'DataStoreWrite');
    dsNames  = cell(size(dsBlocks));
    for i = 1:numel(dsBlocks)
        dsNames{i} = get_param(dsBlocks{i}, 'DataStoreName');
        fprintf('  [%d] %s  →  DataStore: %s\n', i, dsBlocks{i}, dsNames{i});
    end

    fprintf('\n--- Existing Step blocks ---\n')
    stepBlocks = find_system(pertSubsys, 'SearchDepth', 1, 'BlockType', 'Step');
    for i = 1:numel(stepBlocks)
        pos = get_param(stepBlocks{i}, 'Position');
        fprintf('  [%d] %s  Pos=%s\n', i, stepBlocks{i}, mat2str(pos));
    end

    %----------------------------------------------------------------------
    %% STEP A — Add inc_Qref path (Q_ref per-DFIG step)
    %----------------------------------------------------------------------
    fprintf('\n--- Step A: Adding inc_Qref path ---\n')
    qref_exists = ~isempty(find_system(pertSubsys, 'SearchDepth', 1, 'Name', 'inc_Qref'));
    if qref_exists
        fprintf('  inc_Qref already exists — skipping.\n')
    else
        % Position: place below the existing P_ref chain
        pref_pos = get_param([pertSubsys '/inc_Pref'], 'Position');
        base_x = pref_pos(1);
        base_y = pref_pos(4) + 80;

        % A1. Step block: inc_Qref
        add_block('simulink/Sources/Step', [pertSubsys '/inc_Qref'], ...
            'Position', [base_x, base_y, base_x+60, base_y+30], ...
            'Time', '999', 'Before', '0', 'After', '0', ...
            'SampleTime', '-1');
        fprintf('  Added: inc_Qref (Step)\n')

        % A2. Gain block: qref_mask_gain (reads qref_mask_vec from base workspace)
        gain_x = base_x + 100;
        add_block('simulink/Math Operations/Gain', [pertSubsys '/qref_mask_gain'], ...
            'Position', [gain_x, base_y, gain_x+60, base_y+30], ...
            'Gain', 'qref_mask_vec', ...
            'Multiplication', 'Element-wise(K.*u)', ...
            'SampleTime', '-1');
        fprintf('  Added: qref_mask_gain (Gain = qref_mask_vec)\n')

        % A3. Constant block: Q_ref initial value
        const_x = gain_x + 100;
        const_y_below = base_y + 50;
        add_block('simulink/Sources/Constant', [pertSubsys '/Const_Qref_ini'], ...
            'Position', [const_x, const_y_below, const_x+100, const_y_below+30], ...
            'Value', 'CONTROL_INI.VSMQ.TARGET.Q_ref', ...
            'SampleTime', '-1');
        fprintf('  Added: Const_Qref_ini (Constant)\n')

        % A4. Sum block: sum_qref
        sum_x = const_x + 120;
        add_block('simulink/Math Operations/Sum', [pertSubsys '/sum_qref'], ...
            'Position', [sum_x, base_y, sum_x+30, base_y+30], ...
            'Inputs', '++', ...
            'SampleTime', '-1');
        fprintf('  Added: sum_qref (Sum)\n')

        % A5. Find DataStore for Q_ref using keyword matching
        qref_ds_path = find_ds_by_keyword(dsBlocks, dsNames, 'Q_ref');
        if isempty(qref_ds_path)
            qref_ds_path = find_ds_by_keyword(dsBlocks, dsNames, 'VSMQ');
        end

        dsw_x = sum_x + 80;
        if ~isempty(qref_ds_path)
            qref_dsname = get_param(qref_ds_path, 'DataStoreName');
            fprintf('  Found existing Q_ref DataStore: %s\n', qref_dsname)
        else
            qref_dsname = 'CONTROL';
            fprintf('  WARNING: No Q_ref DataStore found. Using placeholder: CONTROL\n')
            fprintf('  ACTION REQUIRED: Manually verify DataStoreName in DSWrite_Qref\n')
        end
        add_block('simulink/Signal Routing/Data Store Write', [pertSubsys '/DSWrite_Qref'], ...
            'Position', [dsw_x, base_y, dsw_x+120, base_y+30], ...
            'DataStoreName', qref_dsname, ...
            'SampleTime', '-1');
        fprintf('  Added: DSWrite_Qref (DataStoreWrite = %s)\n', qref_dsname)

        % A6. Connect all blocks
        add_line(pertSubsys, 'inc_Qref/1', 'qref_mask_gain/1', 'autorouting', 'on');
        add_line(pertSubsys, 'qref_mask_gain/1', 'sum_qref/1', 'autorouting', 'on');
        add_line(pertSubsys, 'Const_Qref_ini/1', 'sum_qref/2', 'autorouting', 'on');
        add_line(pertSubsys, 'sum_qref/1', 'DSWrite_Qref/1', 'autorouting', 'on');
        fprintf('  Connected: inc_Qref → qref_mask_gain → sum_qref ← Const_Qref_ini → DSWrite_Qref\n')
    end

    %----------------------------------------------------------------------
    %% STEP B — Add inc_iL1_i path (reactive load step)
    %----------------------------------------------------------------------
    fprintf('\n--- Step B: Adding inc_iL1_i path ---\n')
    iL1i_exists = ~isempty(find_system(pertSubsys, 'SearchDepth', 1, 'Name', 'inc_iL1_i'));
    if iL1i_exists
        fprintf('  inc_iL1_i already exists — skipping.\n')
    else
        % Position below inc_iL1_r
        iL1r_pos = get_param([pertSubsys '/inc_iL1_r'], 'Position');
        base_x = iL1r_pos(1);
        base_y = iL1r_pos(4) + 80;

        % B1. Step block: inc_iL1_i
        add_block('simulink/Sources/Step', [pertSubsys '/inc_iL1_i'], ...
            'Position', [base_x, base_y, base_x+60, base_y+30], ...
            'Time', '999', 'Before', '0', 'After', '0', ...
            'SampleTime', '-1');
        fprintf('  Added: inc_iL1_i (Step)\n')

        % B2. Constant block: il1_i initial value
        const_x = base_x + 100;
        const_y_below = base_y + 50;
        add_block('simulink/Sources/Constant', [pertSubsys '/Const_iL1i_ini'], ...
            'Position', [const_x, const_y_below, const_x+100, const_y_below+30], ...
            'Value', 'MODEL_INI.LINE.INPUT.il1_i', ...
            'SampleTime', '-1');
        fprintf('  Added: Const_iL1i_ini (Constant = MODEL_INI.LINE.INPUT.il1_i)\n')

        % B3. Sum block: sum_iL1i
        sum_x = const_x + 120;
        add_block('simulink/Math Operations/Sum', [pertSubsys '/sum_iL1i'], ...
            'Position', [sum_x, base_y, sum_x+30, base_y+30], ...
            'Inputs', '++', ...
            'SampleTime', '-1');
        fprintf('  Added: sum_iL1i (Sum)\n')

        % B4. Find DataStore for il1_r to derive il1_i name
        iL1r_ds_path = find_ds_by_keyword(dsBlocks, dsNames, 'il1_r');
        if isempty(iL1r_ds_path)
            iL1r_ds_path = find_ds_by_keyword(dsBlocks, dsNames, 'LINE');
        end

        dsw_x = sum_x + 80;
        if ~isempty(iL1r_ds_path)
            il1r_dsname = get_param(iL1r_ds_path, 'DataStoreName');
            % Replace trailing 'r' with 'i' for the imaginary component
            il1i_dsname = regexprep(il1r_dsname, 'il1_r$', 'il1_i');
            if strcmp(il1i_dsname, il1r_dsname)
                il1i_dsname = [il1r_dsname(1:end-1) 'i'];  % replace last char
            end
            fprintf('  Derived il1_i DataStore name from il1_r: %s → %s\n', il1r_dsname, il1i_dsname)
        else
            il1i_dsname = 'MODEL';
            fprintf('  WARNING: il1_r DataStore not found. Using placeholder: MODEL\n')
            fprintf('  ACTION REQUIRED: Manually verify DataStoreName in DSWrite_iL1i\n')
        end
        add_block('simulink/Signal Routing/Data Store Write', [pertSubsys '/DSWrite_iL1i'], ...
            'Position', [dsw_x, base_y, dsw_x+120, base_y+30], ...
            'DataStoreName', il1i_dsname, ...
            'SampleTime', '-1');
        fprintf('  Added: DSWrite_iL1i (DataStoreWrite = %s)\n', il1i_dsname)

        % B5. Connect all blocks
        add_line(pertSubsys, 'inc_iL1_i/1', 'sum_iL1i/1', 'autorouting', 'on');
        add_line(pertSubsys, 'Const_iL1i_ini/1', 'sum_iL1i/2', 'autorouting', 'on');
        add_line(pertSubsys, 'sum_iL1i/1', 'DSWrite_iL1i/1', 'autorouting', 'on');
        fprintf('  Connected: inc_iL1_i → sum_iL1i ← Const_iL1i_ini → DSWrite_iL1i\n')
    end

    %----------------------------------------------------------------------
    %% STEP C — Fix per-DFIG P_ref mask (insert Gain block before Mux)
    %----------------------------------------------------------------------
    fprintf('\n--- Step C: Adding pref_mask_gain for per-DFIG P_ref ---\n')
    pref_gain_exists = ~isempty(find_system(pertSubsys, 'SearchDepth', 1, 'Name', 'pref_mask_gain'));
    if pref_gain_exists
        fprintf('  pref_mask_gain already exists — skipping.\n')
    else
        % Find Mux block(s) in subsystem
        mux_blocks = find_system(pertSubsys, 'SearchDepth', 1, 'BlockType', 'Mux');
        if isempty(mux_blocks)
            fprintf('  WARNING: No Mux block found. Skipping pref_mask_gain.\n')
            fprintf('  ACTION REQUIRED: Manually insert Gain block between inc_Pref and its Mux.\n')
        else
            pref_pos = get_param([pertSubsys '/inc_Pref'], 'Position');
            mux_pos  = get_param(mux_blocks{1}, 'Position');

            % Position Gain block midway between inc_Pref output and Mux input
            mid_x = round((pref_pos(3) + mux_pos(1)) / 2) - 30;
            mid_y = round((pref_pos(2) + pref_pos(4)) / 2) - 15;

            % Delete existing direct line from inc_Pref to Mux
            pref_line_handles = get_param([pertSubsys '/inc_Pref'], 'LineHandles');
            if ~isempty(pref_line_handles.Outport) && pref_line_handles.Outport(1) > 0
                delete_line(pref_line_handles.Outport(1));
                fprintf('  Deleted direct line: inc_Pref → Mux\n')
            end

            add_block('simulink/Math Operations/Gain', [pertSubsys '/pref_mask_gain'], ...
                'Position', [mid_x, mid_y, mid_x+60, mid_y+30], ...
                'Gain', 'pref_mask_vec', ...
                'Multiplication', 'Element-wise(K.*u)', ...
                'SampleTime', '-1');
            fprintf('  Added: pref_mask_gain (Gain = pref_mask_vec)\n')

            % Reconnect inc_Pref → pref_mask_gain → Mux port 1
            mux_name = get_param(mux_blocks{1}, 'Name');
            add_line(pertSubsys, 'inc_Pref/1', 'pref_mask_gain/1', 'autorouting', 'on');
            add_line(pertSubsys, 'pref_mask_gain/1', [mux_name '/1'], 'autorouting', 'on');
            fprintf('  Connected: inc_Pref → pref_mask_gain → %s/1\n', mux_name)
        end
    end

    %----------------------------------------------------------------------
    %% STEP D — Save and close model
    %----------------------------------------------------------------------
    fprintf('\n--- Saving model ---\n')
    save_system(modelName, [], 'OverwriteIfChangedOnDisk', true);
    close_system(modelName);
    fprintf('Model saved and closed.\n')

    fprintf('\n=========================================================================\n')
    fprintf('  SETUP COMPLETE\n')
    fprintf('=========================================================================\n')
    fprintf('Summary:\n')
    if ~qref_exists,      fprintf('  [A] inc_Qref path added (Q_ref per-DFIG step)\n'); end
    if ~iL1i_exists,      fprintf('  [B] inc_iL1_i path added (reactive load step)\n'); end
    if ~pref_gain_exists, fprintf('  [C] pref_mask_gain added (per-DFIG P_ref mask)\n'); end
    fprintf('\nIMPORTANT: Open POWER_SYSTEM_FULL.slx to verify DataStore names:\n')
    fprintf('  - DSWrite_Qref: should target Q_ref field in CONTROL bus\n')
    fprintf('  - DSWrite_iL1i: should target il1_i field in MODEL/LINE bus\n')
    fprintf('=========================================================================\n')

catch ME
    fprintf('\nERROR in SETUP_PERTURBATION_BLOCKS:\n  %s\n', ME.message)
    for k = 1:length(ME.stack)
        fprintf('  at %s (line %d)\n', ME.stack(k).name, ME.stack(k).line)
    end
    try
        close_system(modelName, 0);
    catch
    end
end

cd(startDir);
end

%--------------------------------------------------------------------------
%% LOCAL FUNCTION: find DataStoreWrite block by keyword in DataStoreName
%--------------------------------------------------------------------------
function dsPath = find_ds_by_keyword(dsBlocks, dsNames, keyword)
    dsPath = '';
    for ii = 1:numel(dsBlocks)
        if contains(dsNames{ii}, keyword, 'IgnoreCase', true)
            dsPath = dsBlocks{ii};
            return;
        end
    end
end
