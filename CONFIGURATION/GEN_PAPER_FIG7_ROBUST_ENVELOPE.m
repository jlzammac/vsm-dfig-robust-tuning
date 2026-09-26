%% GEN_PAPER_FIG7_ROBUST_ENVELOPE — Per-band stability envelope (optimized)
%
% Generates Figure 7 of the paper: identical structure to Figure 5
% (baseline_perband_stability_envelope.pdf) but using the GA-optimized
% controller sweep data.
%
% Output: figures/robust_stability_envelope.pdf

clear; clc; close all;

%==========================================================================
%% SETUP
%==========================================================================
projRoot = fileparts(mfilename('fullpath'));  % CONFIGURATION/
resultsLA = fullfile(projRoot, '..', 'RESULTS', 'LINEAR_ANALYSIS');
figDir = fullfile(projRoot, '..', 'PAPERS', 'Paper_VSM_DFIG_Optimization_Robustness', 'figures');

% Add paths (for format_figure_for_publication if needed)
addpath(fullfile(projRoot, '..', 'PLOT_FILES'));
addpath(fullfile(projRoot, '..', 'FIGURES', 'UTILS'));

%==========================================================================
%% LOAD OPTIMIZED SWEEP DATA
%==========================================================================
% Find most recent VI_OPT_BIOBJ sweep
opt_sweeps = dir(fullfile(resultsLA, 'LINEAR_ANALYSIS_*_SWEEP_VI_OPT_BIOBJ_*.mat'));
if isempty(opt_sweeps)
    error('No optimized SWEEP data found. Run CONFIG_POWER_SYSTEM with RUN_MODE=2 for VI_OPT_BIOBJ first.');
end
[~, idx_opt] = max(arrayfun(@(f) f.datenum, opt_sweeps));
fprintf('Loading optimized sweep: %s\n', opt_sweeps(idx_opt).name);
data_opt = load(fullfile(resultsLA, opt_sweeps(idx_opt).name));
LIN_MODEL_ARRAY = data_opt.LIN_MODEL_ARRAY;
LIN_MODEL = LIN_MODEL_ARRAY.LIN_MODEL;
OPset = LIN_MODEL_ARRAY.OPset;

%==========================================================================
%% COMPUTE PER-BAND METRICS (identical logic to PLOT_LIN_MODEL_ARRAY Case 23)
%==========================================================================
% Band boundaries (rad/s) — consistent with OPTIMIZER.m eigenConfig
BND_LF_MF = 100;    % LF <= 100 rad/s
BND_MF_HF = 500;    % MF = (100, 500] rad/s
BND_SPUR  = 3000;   % Spurious > 3000 rad/s

% Target SCR values
target_scr = [1.0, 2.0, 3.0];

% Extract unique parameter values
vpcc_all  = table2array(OPset(:,1));
power_all = table2array(OPset(:,2));
scr_all   = table2array(OPset(:,3));

power_values = unique(power_all);
target_vpcc  = 0.975;  % stability-boundary voltage

% IEEE B&W style: 3 SCR curves with grayscale + markers
nSCR     = length(target_scr);
grays    = {[0 0 0], [0.4 0.4 0.4], [0.65 0.65 0.65]};
markers  = {'o', 's', 'd'};
lstyles  = {'-', '--', '-.'};
lineWidth = 1.2;
markerSz  = 4;

% Pre-allocate
nP = length(power_values);
zeta_LF  = NaN(nP, nSCR);
zeta_MF  = NaN(nP, nSCR);
zeta_HF  = NaN(nP, nSCR);
sigma_AP = NaN(nP, nSCR);

% Compute per-band metrics
for iSCR = 1:nSCR
    for pp = 1:nP
        idx = find(abs(vpcc_all - target_vpcc) < 0.001 & ...
                   abs(power_all - power_values(pp)) < 0.01 & ...
                   abs(scr_all - target_scr(iSCR)) < 0.01);
        if isempty(idx), continue; end
        idx = idx(1);

        if ~LIN_MODEL{idx}.stability
            continue;
        end

        z = LIN_MODEL{idx}.eigenvalues;
        omega_abs = abs(imag(z));
        zetaV = -real(z) ./ abs(z);

        % Aperiodic modes
        mask_real = omega_abs < 1e-6;
        if any(mask_real)
            sigma_AP(pp, iSCR) = max(real(z(mask_real)));
        end

        % LF band
        mask_lf = omega_abs > 1e-6 & omega_abs <= BND_LF_MF;
        if any(mask_lf)
            zeta_LF(pp, iSCR) = min(zetaV(mask_lf));
        end

        % MF band
        mask_mf = omega_abs > BND_LF_MF & omega_abs <= BND_MF_HF;
        if any(mask_mf)
            zeta_MF(pp, iSCR) = min(zetaV(mask_mf));
        end

        % HF band
        mask_hf = omega_abs > BND_MF_HF & omega_abs <= BND_SPUR;
        if any(mask_hf)
            zeta_HF(pp, iSCR) = min(zetaV(mask_hf));
        end
    end
end

%==========================================================================
%% FIGURE (identical layout to Figure 5)
%==========================================================================
fig = figure(1);
set(fig, 'Units', 'inches', 'Position', [1 1 7.16 4.5]);
set(fig, 'Color', 'white', 'InvertHardcopy', 'off');
set(fig, 'PaperPositionMode', 'auto', 'PaperUnits', 'inches', ...
    'PaperSize', [7.16 4.5]);

titles  = {'(a) Aperiodic modes', ...
           '(b) LF band ($|\omega| \leq 100$ rad/s)', ...
           '(c) MF band ($100 < |\omega| \leq 500$ rad/s)', ...
           '(d) HF band ($500 < |\omega| \leq 3000$ rad/s)'};
% Panel (a) reports the DISTANCE of the rightmost real eigenvalue from the
% imaginary axis, min|Re(lambda)| = |max Re(lambda)| for a stable system.
% That is what the manuscript caption of Fig. 7/9 states, so plot the
% positive quantity and reverse the axis (0 on top) — 2026-08-27.
ylabels = {'$\min|\mathrm{Re}(\lambda)|$', '$\zeta_{\min}$', ...
           '$\zeta_{\min}$', '$\zeta_{\min}$'};
datasets = {abs(sigma_AP), zeta_LF, zeta_MF, zeta_HF};

for sp = 1:4
    subplot(2, 2, sp);
    hold on; grid on; box on;

    data = datasets{sp};
    hPlots = gobjects(nSCR, 1);
    for iSCR = 1:nSCR
        valid = ~isnan(data(:, iSCR));
        if any(valid)
            hPlots(iSCR) = plot(power_values(valid), data(valid, iSCR), ...
                [lstyles{iSCR} markers{iSCR}], ...
                'LineWidth', lineWidth, ...
                'MarkerSize', markerSz, ...
                'MarkerFaceColor', grays{iSCR}, ...
                'Color', grays{iSCR});
        end
    end

    if sp == 1
        yline(0, 'r--', 'LineWidth', 0.8);
        set(gca, 'YDir', 'reverse');   % 0 on top; distance to the jw axis grows downwards
    end

    xlabel('$P$ (pu)', 'Interpreter', 'latex', 'FontSize', 8);
    ylabel(ylabels{sp}, 'Interpreter', 'latex', 'FontSize', 8);
    title(titles{sp}, 'Interpreter', 'latex', 'FontSize', 9);

    set(gca, 'FontSize', 7, 'TickLabelInterpreter', 'latex');
    xlim([min(power_values) max(power_values)]);

    if sp == 1
        leg_entries = cell(1, nSCR);
        for iSCR = 1:nSCR
            leg_entries{iSCR} = sprintf('SCR = %.0f', target_scr(iSCR));
        end
        lgd = legend(hPlots, leg_entries, 'Interpreter', 'latex', ...
              'FontSize', 6, 'Orientation', 'horizontal');
    end
end

% Position legend centered in the gap between subplot rows
drawnow;
ax_top = subplot(2,2,1);
ax_bot = subplot(2,2,3);
pos_top = get(ax_top, 'Position');
pos_bot = get(ax_bot, 'Position');
gap_bottom = pos_bot(2) + pos_bot(4);
gap_top = pos_top(2);
gap_center = (gap_bottom + gap_top) / 2;
lgd.Units = 'normalized';
lp = lgd.Position;
lp(1) = 0.5 - lp(3)/2 + 0.02;
lp(2) = gap_center - lp(4)/2;
lgd.Position = lp;

% Export
outFile = fullfile(figDir, 'robust_stability_envelope.pdf');
exportgraphics(fig, outFile, 'ContentType', 'vector', 'BackgroundColor', 'white');
fprintf('Exported: %s\n', outFile);

% Summary
fprintf('\n=== Per-Band Stability Envelope (GA-Optimized) ===\n');
fprintf('Voltage condition: Vpcc = %.3f pu\n', target_vpcc);
for iSCR = 1:nSCR
    fprintf('SCR=%.0f: zeta_LF_min=%.4f, zeta_MF_min=%.4f, zeta_HF_min=%.4f, sigma_AP_max=%.4f\n', ...
        target_scr(iSCR), min(zeta_LF(:,iSCR)), min(zeta_MF(:,iSCR)), ...
        min(zeta_HF(:,iSCR)), max(sigma_AP(:,iSCR)));
end
