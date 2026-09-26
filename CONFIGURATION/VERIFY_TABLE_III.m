%% VERIFY_TABLE_III — Extract and verify all values for Paper Table III
% Loads baseline and GA-optimized .mat files and prints all parameters
% for cross-checking against the LaTeX table.

clear; clc;
resultsCtrl = fullfile(fileparts(mfilename('fullpath')), '..', 'RESULTS', 'CONTROL');

% Load baseline
fprintf('=== LOADING BASELINE ===\n');
B = load(fullfile(resultsCtrl, 'LIN_MODEL_FRD_DESIGN.mat'));
fn = fieldnames(B); LM_B = B.(fn{1});

% Load GA-optimized (final phase: VI)
fprintf('=== LOADING GA-OPTIMIZED (VI BIOBJ) ===\n');
O = load(fullfile(resultsCtrl, 'LIN_MODEL_VI_OPT_BIOBJ.mat'));
fn = fieldnames(O); LM_O = O.(fn{1});

sel = 1; % selectedDFIG index

fprintf('\n============================================================\n');
fprintf('  TABLE III VERIFICATION: Baseline vs GA-Optimized\n');
fprintf('============================================================\n\n');

% --- VSM Outer Loops ---
fprintf('--- VSM Outer Loops ---\n');
fprintf('%-25s  %12s  %12s  %10s\n', 'Parameter', 'Baseline', 'GA-Opt', 'Delta(%)');

% VSMP Phase margin
b_val = LM_B.CONTROL_DESIGN.VSMP.frdSpecs.Fm;
o_val = LM_O.CONTROL_DESIGN.VSMP.frdSpecs.Fm;
fprintf('%-25s  %12.1f  %12.1f  %+10.1f\n', 'Fm_VSMP (deg)', b_val, o_val, (o_val-b_val)/b_val*100);

% VSMP crossover
b_val = LM_B.CONTROL_DESIGN.VSMP.frdSpecs.wo;
o_val = LM_O.CONTROL_DESIGN.VSMP.frdSpecs.wo;
fprintf('%-25s  %12.2f  %12.2f  %+10.1f\n', 'wo_VSMP (rad/s)', b_val, o_val, (o_val-b_val)/b_val*100);

% H (inertia)
b_val = LM_B.CONTROL.VSMP.PARAM.H(sel);
o_val = LM_O.CONTROL.VSMP.PARAM.H(sel);
fprintf('%-25s  %12.2f  %12.2f  %+10.1f\n', 'H (s)', b_val, o_val, (o_val-b_val)/b_val*100);

% Dd (transient damping)
b_val = LM_B.CONTROL.VSMP.PARAM.Dd(sel);
o_val = LM_O.CONTROL.VSMP.PARAM.Dd(sel);
fprintf('%-25s  %12.3f  %12.3f  %+10.1f\n', 'Dd', b_val, o_val, (o_val-b_val)/b_val*100);

% VSMQ crossover
b_val = LM_B.CONTROL_DESIGN.VSMQ.frdSpecs.wo;
o_val = LM_O.CONTROL_DESIGN.VSMQ.frdSpecs.wo;
fprintf('%-25s  %12.2f  %12.2f  %+10.1f\n', 'wo_VSMQ (rad/s)', b_val, o_val, (o_val-b_val)/b_val*100);

% --- Inner Loops d-axis ---
fprintf('\n--- Inner Loops (d-axis / reactive power path) ---\n');

b_val = LM_B.CONTROL_DESIGN.RSC.frdSpecs.Fm(1);
o_val = LM_O.CONTROL_DESIGN.RSC.frdSpecs.Fm(1);
fprintf('%-25s  %12.1f  %12.1f  %+10.1f\n', 'Fm_RSCd (deg)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL_DESIGN.RSC.frdSpecs.wo(1);
o_val = LM_O.CONTROL_DESIGN.RSC.frdSpecs.wo(1);
fprintf('%-25s  %12.0f  %12.0f  %+10.1f\n', 'wo_RSCd (rad/s)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL.RSCd.PARAM.b(sel);
o_val = LM_O.CONTROL.RSCd.PARAM.b(sel);
fprintf('%-25s  %12.2f  %12.2f  %+10.1f\n', 'b_RSCd', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL_DESIGN.GSC.frdSpecs.Fm(1);
o_val = LM_O.CONTROL_DESIGN.GSC.frdSpecs.Fm(1);
fprintf('%-25s  %12.1f  %12.1f  %+10.1f\n', 'Fm_GSCd (deg)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL_DESIGN.GSC.frdSpecs.wo(1);
o_val = LM_O.CONTROL_DESIGN.GSC.frdSpecs.wo(1);
fprintf('%-25s  %12.0f  %12.0f  %+10.1f\n', 'wo_GSCd (rad/s)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL.GSCd.PARAM.b(sel);
o_val = LM_O.CONTROL.GSCd.PARAM.b(sel);
fprintf('%-25s  %12.2f  %12.2f  %+10.1f\n', 'b_GSCd', b_val, o_val, (o_val-b_val)/b_val*100);

% --- Inner Loops q-axis ---
fprintf('\n--- Inner Loops (q-axis / active power path) ---\n');

b_val = LM_B.CONTROL_DESIGN.RSC.frdSpecs.Fm(2);
o_val = LM_O.CONTROL_DESIGN.RSC.frdSpecs.Fm(2);
fprintf('%-25s  %12.1f  %12.1f  %+10.1f\n', 'Fm_RSCq (deg)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL_DESIGN.RSC.frdSpecs.wo(2);
o_val = LM_O.CONTROL_DESIGN.RSC.frdSpecs.wo(2);
fprintf('%-25s  %12.0f  %12.0f  %+10.1f\n', 'wo_RSCq (rad/s)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL.RSCq.PARAM.b(sel);
o_val = LM_O.CONTROL.RSCq.PARAM.b(sel);
fprintf('%-25s  %12.2f  %12.2f  %+10.1f\n', 'b_RSCq', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL_DESIGN.GSC.frdSpecs.Fm(2);
o_val = LM_O.CONTROL_DESIGN.GSC.frdSpecs.Fm(2);
fprintf('%-25s  %12.1f  %12.1f  %+10.1f\n', 'Fm_GSCq (deg)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL_DESIGN.GSC.frdSpecs.wo(2);
o_val = LM_O.CONTROL_DESIGN.GSC.frdSpecs.wo(2);
fprintf('%-25s  %12.0f  %12.0f  %+10.1f\n', 'wo_GSCq (rad/s)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL.GSCq.PARAM.b(sel);
o_val = LM_O.CONTROL.GSCq.PARAM.b(sel);
fprintf('%-25s  %12.2f  %12.2f  %+10.1f\n', 'b_GSCq', b_val, o_val, (o_val-b_val)/b_val*100);

% --- DC-Link Voltage Controller ---
fprintf('\n--- DC-Link Voltage Controller ---\n');

b_val = LM_B.CONTROL_DESIGN.VDC.frdSpecs.Fm;
o_val = LM_O.CONTROL_DESIGN.VDC.frdSpecs.Fm;
fprintf('%-25s  %12.1f  %12.1f  %+10.1f\n', 'Fm_VDC (deg)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL_DESIGN.VDC.frdSpecs.wo;
o_val = LM_O.CONTROL_DESIGN.VDC.frdSpecs.wo;
fprintf('%-25s  %12.1f  %12.1f  %+10.1f\n', 'wo_VDC (rad/s)', b_val, o_val, (o_val-b_val)/b_val*100);

b_val = LM_B.CONTROL.VDC.PARAM.b(sel);
o_val = LM_O.CONTROL.VDC.PARAM.b(sel);
fprintf('%-25s  %12.2f  %12.2f  %+10.1f\n', 'b_VDC', b_val, o_val, (o_val-b_val)/b_val*100);

% --- Virtual Impedance ---
fprintf('\n--- Virtual Impedance ---\n');

b_val = LM_B.CONTROL.VIMP.PARAM.Lv_pu(sel);
o_val = LM_O.CONTROL.VIMP.PARAM.Lv_pu(sel);
if abs(b_val) > 1e-12
    fprintf('%-25s  %12.4f  %12.4f  %+10.1f\n', 'Lv (pu)', b_val, o_val, (o_val-b_val)/b_val*100);
else
    fprintf('%-25s  %12.4f  %12.4f  new\n', 'Lv (pu)', b_val, o_val);
end

% R_v is fixed at 0 and is not a design variable, so it has no row.

% --- VSM Damping flag ---
fprintf('\n--- VSM Damping ---\n');

b_val = LM_B.CONTROL.VSMP.PARAM.der2error(sel);
o_val = LM_O.CONTROL.VSMP.PARAM.der2error(sel);
fprintf('%-25s  %12d  %12d  %+10.1f\n', 'Dd-on-error flag', b_val, o_val, 0);

fprintf('\n============================================================\n');
fprintf('  VERIFICATION COMPLETE\n');
fprintf('============================================================\n');
