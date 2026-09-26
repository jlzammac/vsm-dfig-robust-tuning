%% GEN_PAPER_V6_FIGURES — Generate all paper figures and table data for v6 BIOBJ
%
% This script generates:
%   PART A: Phase-by-phase table data (J1, J2, per-band damping)
%   PART B: Step response comparison (VSMP, VDC, RSCd, GSCd) across OPs
%   PART C: Damping ratio vs operating point comparison (baseline vs optimized)
%
% Requires: LIN_MODEL_FRD_DESIGN.mat + all BIOBJ intermediate MATs
%           + LINEAR_ANALYSIS sweep data for both controllers
%
% Output:  Console table + PDF figures in PAPERS/.../figures/

%==========================================================================
%% SETUP
%==========================================================================
clear; clc; close all;
projRoot = fileparts(mfilename('fullpath'));  % CONFIGURATION/
resultsCtrl = fullfile(projRoot, '..', 'RESULTS', 'CONTROL');
resultsLA   = fullfile(projRoot, '..', 'RESULTS', 'LINEAR_ANALYSIS');
figDir      = fullfile(projRoot, '..', 'PAPERS', 'Paper_VSM_DFIG_Optimization_Robustness', 'figures');

% Add paths
addpath(fullfile(projRoot, '..', 'PLOT_FILES'));
addpath(fullfile(projRoot, '..', 'FIGURES', 'UTILS'));

%==========================================================================
%% PART A: PHASE-BY-PHASE TABLE DATA
%==========================================================================
fprintf('\n=========================================================================\n');
fprintf('  PART A: Phase-by-phase table data\n');
fprintf('=========================================================================\n');

% Load all intermediate LIN_MODEL MAT files
phaseFiles = {
    'LIN_MODEL_FRD_DESIGN.mat',    'Baseline (FRD)';
    'LIN_MODEL_PDS_OPT_BIOBJ.mat', 'Ph.1: P-Specs (PDS)';
    'LIN_MODEL_QDS_OPT_BIOBJ.mat', 'Ph.2: Q-Specs (QDS)';
    'LIN_MODEL_PCP_OPT_BIOBJ.mat', 'Ph.3: 2-DOF P (PCP)';
    'LIN_MODEL_QCP_OPT_BIOBJ.mat', 'Ph.4: 2-DOF Q (QCP)';
    'LIN_MODEL_VI_OPT_BIOBJ.mat',  'Ph.5: Virt. Imp. (VI)';
};
nPhases = size(phaseFiles, 1);

% Eigenvalue band thresholds (from OPTIMIZER.m)
mf_freq_thresh = 100;   % LF/MF boundary [rad/s]
hf_freq_thresh = 500;   % MF/HF boundary [rad/s]
spurious_freq  = 3000;  % HF/spurious boundary [rad/s]

% ITAE computation parameters
T_sim = 20;     % Simulation time for ITAE [s]
N_pts = 10000;  % Number of time points

% Preallocate results
results = struct('phase', {}, 'J1', {}, 'J2', {}, ...
    'zeta_LF', {}, 'zeta_MF', {}, 'zeta_HF', {}, 'zeta_global', {});

for kk = 1:nPhases
    matFile = fullfile(resultsCtrl, phaseFiles{kk, 1});
    fprintf('\nLoading: %s\n', phaseFiles{kk, 1});

    if ~isfile(matFile)
        fprintf('  WARNING: File not found — skipping.\n');
        continue;
    end

    data = load(matFile);
    fn = fieldnames(data);
    LM = data.(fn{1});

    results(kk).phase = phaseFiles{kk, 2};

    %--- Per-band damping at nominal OP ---
    z = LM.eigenvalues;
    [Wn, Zeta] = damp(ss(LM.ssModel.a, LM.ssModel.b(:,1), LM.ssModel.c(1,:), 0));

    % Alternative: use eigenvalues directly
    is_complex = abs(imag(z)) > 1e-6;
    z_cplx = z(is_complex);
    freq_cplx = abs(imag(z_cplx));
    damp_cplx = -real(z_cplx) ./ abs(z_cplx);

    % Filter spurious
    valid = freq_cplx < spurious_freq;
    freq_v = freq_cplx(valid);
    damp_v = damp_cplx(valid);

    % Per-band
    is_lf = freq_v <= mf_freq_thresh;
    is_mf = freq_v > mf_freq_thresh & freq_v <= hf_freq_thresh;
    is_hf = freq_v > hf_freq_thresh;

    if any(is_lf), results(kk).zeta_LF = min(damp_v(is_lf)); else, results(kk).zeta_LF = NaN; end
    if any(is_mf), results(kk).zeta_MF = min(damp_v(is_mf)); else, results(kk).zeta_MF = NaN; end
    if any(is_hf), results(kk).zeta_HF = min(damp_v(is_hf)); else, results(kk).zeta_HF = NaN; end
    results(kk).zeta_global = min(damp_v);

    fprintf('  Damping: LF=%.4f  MF=%.4f  HF=%.4f  Global=%.4f\n', ...
        results(kk).zeta_LF, results(kk).zeta_MF, results(kk).zeta_HF, results(kk).zeta_global);

    %--- ITAE computation (J1 regulation, J2 tracking) ---
    ssM = LM.ssModel;
    nDFIG = LM.MODEL.DFIG.PARAM.nDFIG;
    nCONTROL = 7;
    nLINE = LM.MODEL.LINE.PARAM.nLINE;
    selectedDFIG = LM.CONTROL_DESIGN.selectedDFIG;

    % SISO indices (same as in OPTIMIZER.m compute_fitness_itae_biobj)
    indI_Pl = nCONTROL*nDFIG + 2*nDFIG + nLINE;       % il_r (active load)
    indI_Ql = nCONTROL*nDFIG + 2*nDFIG + nLINE + 1;   % il_i (reactive load)
    indI_Pr = nCONTROL*nDFIG + selectedDFIG;             % P_ref
    indI_Qr = nCONTROL*nDFIG + nDFIG + selectedDFIG;    % Q_ref
    indO_f  = 2*nCONTROL*nDFIG + 1;                     % frequency output
    indO_v  = 2*nCONTROL*nDFIG + 2;                     % voltage output

    % Find P and Q output indices (same logic as OPTIMIZER)
    indO_P = nCONTROL*(selectedDFIG-1) + 1;  % VSMP output
    indO_Q = nCONTROL*(selectedDFIG-1) + 2;  % VSMQ output

    % Find wind input index
    % Wind input comes after il_r, il_i
    indI_vw = nCONTROL*nDFIG + 2*nDFIG + nLINE + 2;    % vw_delta

    matA = ssM.a; matB = ssM.b; matC = ssM.c; matD = ssM.d;
    t = linspace(0, T_sim, N_pts)';
    dt = t(2) - t(1);

    % Build SISO transfer functions
    % Regulation channels: il_r→Δf, il_i→Δf, il_r→ΔV, il_i→ΔV, vw→Δf, vw→ΔV
    reg_channels = {
        indI_Pl, indO_f, 'il_r→Δf';
        indI_Ql, indO_f, 'il_i→Δf';
        indI_Pl, indO_v, 'il_r→ΔV';
        indI_Ql, indO_v, 'il_i→ΔV';
    };

    % Tracking channels: P_ref→P, Q_ref→Q
    trk_channels = {
        indI_Pr, indO_P, 'P_ref→P';
        indI_Qr, indO_Q, 'Q_ref→Q';
    };

    % Compute regulation ITAE (J1)
    itae_reg = zeros(size(reg_channels, 1), 1);
    for ch = 1:size(reg_channels, 1)
        iI = reg_channels{ch, 1};
        iO = reg_channels{ch, 2};
        if iI > size(matB,2) || iO > size(matC,1)
            fprintf('    WARNING: index out of range for %s\n', reg_channels{ch,3});
            itae_reg(ch) = NaN;
            continue;
        end
        Fss = ss(matA, matB(:,iI), matC(iO,:), matD(iO,iI));
        y = step(Fss, t);
        e = y - y(end);  % transient error
        itae_reg(ch) = trapz(t, t .* abs(e));
    end

    % Compute tracking ITAE (J2)
    itae_trk = zeros(size(trk_channels, 1), 1);
    for ch = 1:size(trk_channels, 1)
        iI = trk_channels{ch, 1};
        iO = trk_channels{ch, 2};
        if iI > size(matB,2) || iO > size(matC,1)
            fprintf('    WARNING: index out of range for %s\n', trk_channels{ch,3});
            itae_trk(ch) = NaN;
            continue;
        end
        Fss = ss(matA, matB(:,iI), matC(iO,:), matD(iO,iI));
        y = step(Fss, t);
        e = y - y(end);  % transient error
        itae_trk(ch) = trapz(t, t .* abs(e));
    end

    results(kk).J1 = mean(itae_reg, 'omitnan');
    results(kk).J2 = mean(itae_trk, 'omitnan');

    fprintf('  J1 (reg) = %.6f  J2 (trk) = %.6f\n', results(kk).J1, results(kk).J2);
end

% Normalize by baseline
J1_base = results(1).J1;
J2_base = results(1).J2;

fprintf('\n=========================================================================\n');
fprintf('  PHASE-BY-PHASE TABLE (normalized by baseline)\n');
fprintf('=========================================================================\n');
fprintf('%-25s | %8s | %8s | %8s | %8s | %8s | %8s | %8s | %8s\n', ...
    'Phase', 'J1', 'J2', 'ΔJ1(%)', 'ΔJ2(%)', 'ζ_LF', 'ζ_MF', 'ζ_HF', 'ζ_glob');
fprintf('%s\n', repmat('-', 1, 120));
for kk = 1:nPhases
    if isempty(results(kk).phase), continue; end
    J1n = results(kk).J1 / J1_base;
    J2n = results(kk).J2 / J2_base;
    dJ1 = (J1n - 1) * 100;
    dJ2 = (J2n - 1) * 100;
    fprintf('%-25s | %8.3f | %8.3f | %+7.1f  | %+7.1f  | %8.4f | %8.4f | %8.4f | %8.4f\n', ...
        results(kk).phase, J1n, J2n, dJ1, dJ2, ...
        results(kk).zeta_LF, results(kk).zeta_MF, results(kk).zeta_HF, results(kk).zeta_global);
end

%==========================================================================
%% PART B: STEP RESPONSE COMPARISON (4 key loops)
%==========================================================================
fprintf('\n=========================================================================\n');
fprintf('  PART B: Step response comparison figure\n');
fprintf('=========================================================================\n');

% Check if we have SWEEP data for both controllers
% Baseline sweep
baseline_sweeps = dir(fullfile(resultsLA, 'LINEAR_ANALYSIS_*_SWEEP_FRD_*.mat'));
if isempty(baseline_sweeps)
    fprintf('ERROR: No baseline SWEEP data found.\n');
    fprintf('Run CONFIG_POWER_SYSTEM with RUN_MODE=2 for FRD design first.\n');
else
    % Use most recent baseline sweep
    [~, idx_bl] = max(arrayfun(@(f) f.datenum, baseline_sweeps));
    slug_baseline = strrep(baseline_sweeps(idx_bl).name, 'LINEAR_ANALYSIS_', '');
    slug_baseline = strrep(slug_baseline, '.mat', '');
    fprintf('Baseline sweep: %s\n', slug_baseline);
end

% Optimized sweep — prefer BIOBJ, fallback to any VI_OPT
opt_sweeps = dir(fullfile(resultsLA, 'LINEAR_ANALYSIS_*_SWEEP_VI_OPT_BIOBJ_*.mat'));
if isempty(opt_sweeps)
    opt_sweeps = dir(fullfile(resultsLA, 'LINEAR_ANALYSIS_*_SWEEP_VI_OPT_*.mat'));
end
if isempty(opt_sweeps)
    fprintf('WARNING: No optimized SWEEP data found.\n');
    fprintf('Need to generate via CONFIG_POWER_SYSTEM with RUN_MODE=2 for VI_OPT_BIOBJ.\n');
    fprintf('SKIPPING Part B — generate sweep first.\n');
    slug_optimized = '';
else
    % Use most recent optimized sweep
    [~, idx_opt] = max(arrayfun(@(f) f.datenum, opt_sweeps));
    slug_optimized = strrep(opt_sweeps(idx_opt).name, 'LINEAR_ANALYSIS_', '');
    slug_optimized = strrep(slug_optimized, '.mat', '');
    fprintf('Optimized sweep: %s\n', slug_optimized);
end

if ~isempty(slug_baseline) && ~isempty(slug_optimized)
    % Load both sweep datasets
    data_bl = load(fullfile(resultsLA, baseline_sweeps(idx_bl).name));
    data_opt = load(fullfile(resultsLA, opt_sweeps(idx_opt).name));

    LIN_MODEL_ARRAY_BL  = data_bl.LIN_MODEL_ARRAY;
    LIN_MODEL_ARRAY_OPT = data_opt.LIN_MODEL_ARRAY;

    OPset = LIN_MODEL_ARRAY_BL.OPset;
    numOP = size(OPset, 1);
    LM_BL  = LIN_MODEL_ARRAY_BL.LIN_MODEL;
    LM_OPT = LIN_MODEL_ARRAY_OPT.LIN_MODEL;

    nDFIG_s = LM_BL{1}.MODEL.DFIG.PARAM.nDFIG;
    nCONTROL_s = 7;

    % Key loops to plot (indices within the 7 controllers)
    loopIdx   = [1, 5, 3, 6];          % VSMP, VDC, RSCd, GSCd
    loopLabel = {'VSMP', 'VDC', 'RSCd', 'GSCd'};
    loopYlabel = {'Active power (pu)', 'DC-link voltage (pu)', ...
                  '$d$-axis rotor current (pu)', '$d$-axis GSC current (pu)'};
    tfin_loops = [1.5, 0.1, 0.02, 0.02];   % Time horizon per loop

    hDFIG = [1 3];  % DFIG 1 (SCR=10) and DFIG 3 (SCR=5)

    % --- Create publication figure ---
    fig_step = figure('Name', 'Step Response Comparison', ...
        'Position', [50, 50, 900, 700], 'Color', 'white');

    for pp = 1:4
        subplot(2, 2, pp)
        hold on
        nn = loopIdx(pp);

        for ii = 1:length(hDFIG)
            for jj = 1:numOP
                % Skip unstable OPs
                if ~LM_BL{jj}.stability || ~LM_OPT{jj}.stability
                    continue;
                end

                t = linspace(0, tfin_loops(pp), 3000);

                % --- Baseline (blue, thin) ---
                ssM_bl = LM_BL{jj}.ssModel;
                indT = nCONTROL_s*(hDFIG(ii)-1) + nn;
                Tss_bl = ss(ssM_bl.a, ssM_bl.b(:,indT), ssM_bl.c(indT,:), ssM_bl.d(indT,indT));
                y_bl = step(-Tss_bl, t);
                plot(t, y_bl, 'Color', [0.6 0.6 0.9], 'LineWidth', 0.5)

                % --- Optimized (red, thin) ---
                ssM_opt = LM_OPT{jj}.ssModel;
                Tss_opt = ss(ssM_opt.a, ssM_opt.b(:,indT), ssM_opt.c(indT,:), ssM_opt.d(indT,indT));
                y_opt = step(-Tss_opt, t);
                plot(t, y_opt, 'Color', [0.9 0.4 0.4], 'LineWidth', 0.5)
            end
        end

        % Add thick representative curves (nominal OP = first)
        t = linspace(0, tfin_loops(pp), 3000);
        indT = nCONTROL_s*(hDFIG(1)-1) + nn;

        ssM_bl = LM_BL{1}.ssModel;
        Tss_bl = ss(ssM_bl.a, ssM_bl.b(:,indT), ssM_bl.c(indT,:), ssM_bl.d(indT,indT));
        y_bl = step(-Tss_bl, t);
        h1 = plot(t, y_bl, 'b', 'LineWidth', 2);

        ssM_opt = LM_OPT{1}.ssModel;
        Tss_opt = ss(ssM_opt.a, ssM_opt.b(:,indT), ssM_opt.c(indT,:), ssM_opt.d(indT,indT));
        y_opt = step(-Tss_opt, t);
        h2 = plot(t, y_opt, 'r', 'LineWidth', 2);

        xlim([0 tfin_loops(pp)]);
        xlabel('$t$ (s)', 'Interpreter', 'latex', 'FontSize', 11);
        ylabel(loopYlabel{pp}, 'Interpreter', 'latex', 'FontSize', 11);
        title(loopLabel{pp}, 'Interpreter', 'latex', 'FontSize', 13, 'FontWeight', 'bold');
        grid on
        set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
            'GridLineStyle', ':', 'GridAlpha', 0.15);
        box on

        if pp == 1
            legend([h1 h2], {'Baseline (FRD)', 'GA-Optimized'}, ...
                'Interpreter', 'latex', 'FontSize', 9, 'Location', 'best');
        end
        hold off
    end

    % Export
    stepFigPath = fullfile(figDir, 'step_response_comparison.pdf');
    exportgraphics(fig_step, stepFigPath, 'ContentType', 'vector');
    fprintf('Saved: %s\n', stepFigPath);

    %======================================================================
    %% PART C: DAMPING RATIO VS OPERATING POINT
    %======================================================================
    fprintf('\n=========================================================================\n');
    fprintf('  PART C: Damping ratio vs operating point\n');
    fprintf('=========================================================================\n');

    % Extract per-band damping for each OP and both controllers
    zeta_bl = struct('LF', nan(numOP,1), 'MF', nan(numOP,1), 'HF', nan(numOP,1), ...
                     'maxRealEig', nan(numOP,1));
    zeta_opt = struct('LF', nan(numOP,1), 'MF', nan(numOP,1), 'HF', nan(numOP,1), ...
                      'maxRealEig', nan(numOP,1));

    for jj = 1:numOP
        % Baseline
        if LM_BL{jj}.stability
            if isfield(LM_BL{jj}, 'eigenvalues')
                z_bl = LM_BL{jj}.eigenvalues;
            else
                z_bl = eig(LM_BL{jj}.ssModel.A);
            end
            [zLF, zMF, zHF] = compute_band_damping(z_bl, mf_freq_thresh, hf_freq_thresh, spurious_freq);
            zeta_bl.LF(jj) = zLF;
            zeta_bl.MF(jj) = zMF;
            zeta_bl.HF(jj) = zHF;
            if isfield(LM_BL{jj}, 'maxRealEig')
                zeta_bl.maxRealEig(jj) = LM_BL{jj}.maxRealEig;
            else
                zeta_bl.maxRealEig(jj) = max(real(z_bl));
            end
        end

        % Optimized
        if LM_OPT{jj}.stability
            if isfield(LM_OPT{jj}, 'eigenvalues')
                z_opt = LM_OPT{jj}.eigenvalues;
            else
                z_opt = eig(LM_OPT{jj}.ssModel.A);
            end
            [zLF, zMF, zHF] = compute_band_damping(z_opt, mf_freq_thresh, hf_freq_thresh, spurious_freq);
            zeta_opt.LF(jj) = zLF;
            zeta_opt.MF(jj) = zMF;
            zeta_opt.HF(jj) = zHF;
            if isfield(LM_OPT{jj}, 'maxRealEig')
                zeta_opt.maxRealEig(jj) = LM_OPT{jj}.maxRealEig;
            else
                zeta_opt.maxRealEig(jj) = max(real(z_opt));
            end
        end
    end

    % Extract OP grid parameters
    Vpcc  = OPset.Vpcc;
    Pdfig = OPset.Pdfig;
    SCR   = OPset.SCRgrid;

    % Unique values
    Vpcc_u  = unique(Vpcc);
    Pdfig_u = unique(Pdfig);
    SCR_u   = unique(SCR);

    % --- Figure: 3-band damping comparison ---
    bands = {'LF', 'MF', 'HF'};
    bandLabels = {'LF band ($|\omega| \leq 100$ rad/s)', ...
                  'MF band ($100 < |\omega| \leq 500$ rad/s)', ...
                  'HF band ($|\omega| > 500$ rad/s)'};

    fig_damp = figure('Name', 'Per-Band Damping Comparison', ...
        'Position', [50, 50, 1200, 500], 'Color', 'white');

    for bb = 1:3
        subplot(1, 3, bb)
        hold on

        z_bl_band = zeta_bl.(bands{bb});
        z_opt_band = zeta_opt.(bands{bb});

        % Plot all OPs sorted by damping value
        valid_bl  = find(~isnan(z_bl_band) & z_bl_band > 0);
        valid_opt = find(~isnan(z_opt_band) & z_opt_band > 0);

        [sorted_bl, idx_bl]   = sort(z_bl_band(valid_bl));
        [sorted_opt, idx_opt] = sort(z_opt_band(valid_opt));

        plot(1:length(sorted_bl), sorted_bl, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 3);
        plot(1:length(sorted_opt), sorted_opt, 'r-s', 'LineWidth', 1.5, 'MarkerSize', 3);

        xlabel('Operating point (sorted)', 'Interpreter', 'latex', 'FontSize', 11);
        ylabel('$\zeta_{\min}$', 'Interpreter', 'latex', 'FontSize', 12);
        title(bandLabels{bb}, 'Interpreter', 'latex', 'FontSize', 12);

        if bb == 1
            legend({'Baseline', 'GA-Optimized'}, 'Interpreter', 'latex', ...
                'FontSize', 9, 'Location', 'northwest');
        end

        grid on
        set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
            'GridLineStyle', ':', 'GridAlpha', 0.15);
        box on
        hold off
    end

    dampFigPath = fullfile(figDir, 'damping_comparison_perband.pdf');
    exportgraphics(fig_damp, dampFigPath, 'ContentType', 'vector');
    fprintf('Saved: %s\n', dampFigPath);

    % --- Figure: Max real eigenvalue comparison ---
    fig_reig = figure('Name', 'Max Real Eigenvalue Comparison', ...
        'Position', [50, 50, 700, 400], 'Color', 'white');
    hold on

    valid_bl  = find(~isnan(zeta_bl.maxRealEig));
    valid_opt = find(~isnan(zeta_opt.maxRealEig));

    [sorted_bl, ~]  = sort(zeta_bl.maxRealEig(valid_bl), 'descend');
    [sorted_opt, ~] = sort(zeta_opt.maxRealEig(valid_opt), 'descend');

    plot(1:length(sorted_bl), sorted_bl, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 3);
    plot(1:length(sorted_opt), sorted_opt, 'r-s', 'LineWidth', 1.5, 'MarkerSize', 3);
    yline(0, 'k--', 'LineWidth', 1);

    xlabel('Operating point (sorted by $\max \Re(\lambda)$)', 'Interpreter', 'latex', 'FontSize', 11);
    ylabel('$\max \Re(\lambda)$', 'Interpreter', 'latex', 'FontSize', 12);
    title('Maximum Real Eigenvalue Across Operating Envelope', 'Interpreter', 'latex', 'FontSize', 13);
    legend({'Baseline', 'GA-Optimized', 'Stability boundary'}, 'Interpreter', 'latex', ...
        'FontSize', 9, 'Location', 'best');
    grid on
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
        'GridLineStyle', ':', 'GridAlpha', 0.15);
    box on
    hold off

    reigFigPath = fullfile(figDir, 'max_real_eigenvalue_comparison.pdf');
    exportgraphics(fig_reig, reigFigPath, 'ContentType', 'vector');
    fprintf('Saved: %s\n', reigFigPath);
end

fprintf('\n=========================================================================\n');
fprintf('  ALL DONE\n');
fprintf('=========================================================================\n');

%==========================================================================
%% LOCAL FUNCTION: compute per-band damping from eigenvalues
%==========================================================================
function [zeta_LF, zeta_MF, zeta_HF] = compute_band_damping(z, mf_thresh, hf_thresh, spur_thresh)
    is_complex = abs(imag(z)) > 1e-6;
    z_cplx = z(is_complex);
    freq = abs(imag(z_cplx));
    damp_ratio = -real(z_cplx) ./ abs(z_cplx);

    valid = freq < spur_thresh;
    freq_v = freq(valid);
    damp_v = damp_ratio(valid);

    lf_mask = freq_v <= mf_thresh;
    mf_mask = freq_v > mf_thresh & freq_v <= hf_thresh;
    hf_mask = freq_v > hf_thresh;

    if any(lf_mask), zeta_LF = min(damp_v(lf_mask)); else, zeta_LF = NaN; end
    if any(mf_mask), zeta_MF = min(damp_v(mf_mask)); else, zeta_MF = NaN; end
    if any(hf_mask), zeta_HF = min(damp_v(hf_mask)); else, zeta_HF = NaN; end
end
