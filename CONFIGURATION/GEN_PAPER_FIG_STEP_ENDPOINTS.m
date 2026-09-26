%% GEN_PAPER_FIG_STEP_ENDPOINTS — Step response comparison at endpoints
%
% Generates the step response comparison figure using only the two
% grid-strength endpoints (SCR=1 and SCR=3) instead of the full sweep.
%
% For each endpoint, all voltage and power combinations are shown as
% thin curves; the nominal OP is highlighted with a thick curve.
%
% Output: figures/step_response_comparison.pdf

clear; clc; close all;

%==========================================================================
%% SETUP
%==========================================================================
projRoot = fileparts(mfilename('fullpath'));  % CONFIGURATION/
resultsLA = fullfile(projRoot, '..', 'RESULTS', 'LINEAR_ANALYSIS');
figDir = fullfile(projRoot, '..', 'PAPERS', 'Paper_VSM_DFIG_Optimization_Robustness', 'figures');

addpath(fullfile(projRoot, '..', 'PLOT_FILES'));
addpath(fullfile(projRoot, '..', 'FIGURES', 'UTILS'));

%==========================================================================
%% LOAD SWEEP DATA
%==========================================================================
% Baseline sweep
bl_sweeps = dir(fullfile(resultsLA, 'LINEAR_ANALYSIS_*_SWEEP_FRD_*.mat'));
[~, idx_bl] = max(arrayfun(@(f) f.datenum, bl_sweeps));
fprintf('Baseline sweep: %s\n', bl_sweeps(idx_bl).name);
data_bl = load(fullfile(resultsLA, bl_sweeps(idx_bl).name));

% Optimized sweep
opt_sweeps = dir(fullfile(resultsLA, 'LINEAR_ANALYSIS_*_SWEEP_VI_OPT_BIOBJ_*.mat'));
[~, idx_opt] = max(arrayfun(@(f) f.datenum, opt_sweeps));
fprintf('Optimized sweep: %s\n', opt_sweeps(idx_opt).name);
data_opt = load(fullfile(resultsLA, opt_sweeps(idx_opt).name));

LIN_MODEL_ARRAY_BL  = data_bl.LIN_MODEL_ARRAY;
LIN_MODEL_ARRAY_OPT = data_opt.LIN_MODEL_ARRAY;

OPset = LIN_MODEL_ARRAY_BL.OPset;
numOP = size(OPset, 1);
LM_BL  = LIN_MODEL_ARRAY_BL.LIN_MODEL;
LM_OPT = LIN_MODEL_ARRAY_OPT.LIN_MODEL;

nDFIG    = LM_BL{1}.MODEL.DFIG.PARAM.nDFIG;
nCONTROL = 7;

%==========================================================================
%% SELECT ENDPOINT OPERATING POINTS
%==========================================================================
% Only use SCR=1 and SCR=3 (grid-strength endpoints)
scr_all = OPset.SCRgrid;
endpoint_scr = [1.0, 3.0];
endpoint_idx = [];
for kk = 1:length(endpoint_scr)
    idx_scr = find(abs(scr_all - endpoint_scr(kk)) < 0.01);
    endpoint_idx = [endpoint_idx; idx_scr]; %#ok<AGROW>
end
fprintf('Using %d endpoint operating points (SCR=1 and SCR=3) out of %d total.\n', ...
    length(endpoint_idx), numOP);

%==========================================================================
%% FIGURE
%==========================================================================
loopIdx    = [1, 5, 3, 6];          % VSMP, VDC, RSCd, GSCd
loopLabel  = {'VSMP', 'VDC', 'RSCd', 'GSCd'};
loopYlabel = {'Active power (pu)', 'DC-link voltage (pu)', ...
              '$d$-axis rotor current (pu)', '$d$-axis GSC current (pu)'};
tfin_loops = [1.5, 0.1, 0.02, 0.02];

hDFIG = [1 3];  % DFIG indices

% IEEE B&W colors
clr_bl_thin  = [0.6 0.6 0.9];   % light blue
clr_opt_thin = [0.9 0.4 0.4];   % light red
clr_bl_thick = [0 0 0.7];       % dark blue
clr_opt_thick = [0.8 0 0];      % dark red

fig_step = figure('Name', 'Step Response Comparison (Endpoints)', ...
    'Units', 'inches', 'Position', [1 1 7.16 4.5], 'Color', 'white');
set(fig_step, 'InvertHardcopy', 'off', 'PaperPositionMode', 'auto', ...
    'PaperUnits', 'inches', 'PaperSize', [7.16 4.5]);

for pp = 1:4
    subplot(2, 2, pp)
    hold on
    nn = loopIdx(pp);

    for ii = 1:length(hDFIG)
        for jj_idx = 1:length(endpoint_idx)
            jj = endpoint_idx(jj_idx);

            % Skip unstable OPs
            if ~LM_BL{jj}.stability || ~LM_OPT{jj}.stability
                continue;
            end

            t = linspace(0, tfin_loops(pp), 3000);
            indT = nCONTROL*(hDFIG(ii)-1) + nn;

            % Baseline (blue, thin)
            ssM_bl = LM_BL{jj}.ssModel;
            Tss_bl = ss(ssM_bl.a, ssM_bl.b(:,indT), ssM_bl.c(indT,:), ssM_bl.d(indT,indT));
            y_bl = step(-Tss_bl, t);
            plot(t, y_bl, 'Color', clr_bl_thin, 'LineWidth', 0.5)

            % Optimized (red, thin)
            ssM_opt = LM_OPT{jj}.ssModel;
            Tss_opt = ss(ssM_opt.a, ssM_opt.b(:,indT), ssM_opt.c(indT,:), ssM_opt.d(indT,indT));
            y_opt = step(-Tss_opt, t);
            plot(t, y_opt, 'Color', clr_opt_thin, 'LineWidth', 0.5)
        end
    end

    % Thick representative curves (nominal OP = first stable endpoint)
    t = linspace(0, tfin_loops(pp), 3000);
    indT = nCONTROL*(hDFIG(1)-1) + nn;

    ssM_bl = LM_BL{1}.ssModel;
    Tss_bl = ss(ssM_bl.a, ssM_bl.b(:,indT), ssM_bl.c(indT,:), ssM_bl.d(indT,indT));
    y_bl = step(-Tss_bl, t);
    h1 = plot(t, y_bl, 'Color', clr_bl_thick, 'LineWidth', 2);

    ssM_opt = LM_OPT{1}.ssModel;
    Tss_opt = ss(ssM_opt.a, ssM_opt.b(:,indT), ssM_opt.c(indT,:), ssM_opt.d(indT,indT));
    y_opt = step(-Tss_opt, t);
    h2 = plot(t, y_opt, 'Color', clr_opt_thick, 'LineWidth', 2);

    xlim([0 tfin_loops(pp)]);
    xlabel('$t$ (s)', 'Interpreter', 'latex', 'FontSize', 8);
    ylabel(loopYlabel{pp}, 'Interpreter', 'latex', 'FontSize', 8);
    title(loopLabel{pp}, 'Interpreter', 'latex', 'FontSize', 9, 'FontWeight', 'bold');
    grid on
    set(gca, 'FontSize', 7, 'TickLabelInterpreter', 'latex', ...
        'GridLineStyle', ':', 'GridAlpha', 0.15);
    box on

    if pp == 1
        legend([h1 h2], {'Baseline', 'GA-Optimized'}, ...
            'Interpreter', 'latex', 'FontSize', 6, 'Location', 'best');
    end
    hold off
end

% Export
outFile = fullfile(figDir, 'step_response_comparison.pdf');
exportgraphics(fig_step, outFile, 'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('Exported: %s\n', outFile);
fprintf('Done. Used %d endpoint OPs instead of full %d-point sweep.\n', ...
    length(endpoint_idx), numOP);
