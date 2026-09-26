%% RUN_PAPER_V6_NL_VALIDATION.m
% Master script for Optimization Paper: NL Validation (Baseline vs GA-v6 BIOBJ)
%
% PURPOSE:
%   Automated pipeline to generate all nonlinear validation figures and
%   metrics for the paper "Robust Optimal Design of VSM-DFIG Controllers".
%   Uses the SAME perturbations as the submitted MPCE paper for cross-paper
%   consistency (MPCE-2025-0640.R2).
%
% PREREQUISITES:
%   1. CONFIG_POWER_SYSTEM.m: RUN_MODE = 0, CONTROL_TYPE = 2
%   2. Run CONFIG_POWER_SYSTEM first (initializes LIN_MODEL at OP_RATED)
%
% EXECUTION:
%   cd('CONFIGURATION')
%   CONFIG_POWER_SYSTEM       % ← run first if LIN_MODEL not in workspace
%   RUN_PAPER_V6_NL_VALIDATION   % ← this script
%
% WHAT IT DOES:
%   Phase 1: Setup Simulink perturbation blocks (inc_Qref, inc_iL1_i)
%   Phase 2: Run COMPARE_BASELINE_VS_V6 (2 perturbations, metrics, figures)
%
% OUTPUTS:
%   FIGURES/PAPER_V6/nl_pref_step.pdf   — Δω = ωr - ωt (P_ref step)
%   FIGURES/PAPER_V6/nl_voltage_dip.pdf — u_dc + i_GSCq (voltage dip)
%   FIGURES/PAPER_V6/*_overview.pdf     — Supplementary 4-panel figures
%   RESULTS/SIMULATION/COMPARISON_BASELINE_VS_V6/comparison_v6_*.mat
%
%   Console output includes LaTeX table rows for sec6_validation_results.tex
%
% ESTIMATED TIME: ~8-15 min (2 perturbations × 2 controllers × ~2 min each)

fprintf('\n================================================================\n');
fprintf('  RUN_PAPER_V6_NL_VALIDATION — Master Pipeline\n');
fprintf('  Paper: Robust Optimal Design of VSM-DFIG Controllers\n');
fprintf('  %s\n', datetime('now'));
fprintf('================================================================\n\n');

t_total = tic;

%% PHASE 1: Setup Simulink Perturbation Blocks
% Adds inc_Qref (Q_ref step) and inc_iL1_i (reactive load step) to
% PERTURBATION & MONITORING subsystem. Safe to re-run (skips if exist).
fprintf('=== PHASE 1: Setting up Simulink perturbation blocks ===\n');
addpath(fullfile(fileparts(pwd), 'SIMULATION'));
SETUP_PERTURBATION_BLOCKS('POWER_SYSTEM_FULL');

%% PHASE 2: Run Comparison (Baseline vs GA-v6 BIOBJ)
% 2 perturbations × 2 controllers: P_ref step + Voltage dip
% Generates metrics table + overlay figures → FIGURES/PAPER_V6/
fprintf('\n=== PHASE 2: Running NL comparison (2 MPCE perturbations) ===\n');
COMPARE_BASELINE_VS_V6

%% Summary
t_elapsed = toc(t_total);
fprintf('\n================================================================\n');
fprintf('  NL VALIDATION PIPELINE COMPLETE (%.1f min)\n', t_elapsed/60);
fprintf('  Paper figures: FIGURES/PAPER_V6/*.pdf\n');
fprintf('  Data:          RESULTS/SIMULATION/COMPARISON_BASELINE_VS_V6/\n');
fprintf('\n  NEXT STEPS:\n');
fprintf('  1. Check figures in FIGURES/PAPER_V6/\n');
fprintf('  2. Copy LaTeX table rows from console output to sec6_validation_results.tex\n');
fprintf('  3. Fill PENDING markers in sec6 with actual metric values\n');
fprintf('================================================================\n');
