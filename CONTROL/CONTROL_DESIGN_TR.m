function LIN_MODEL = CONTROL_DESIGN_TR(LIN_MODEL)
% CONTROL_DESIGN_TR - Time-Response Control Design for DFIG Wind Farm
%
% DESCRIPTION:
%   Designs controller parameters for all control loops (VSMP, VSMQ, RSC, VDC, GSC)
%   based on time-domain specifications (settling time ts2, damping ratio ζ).
%   Uses classical control theory to calculate PI/PD parameters that meet specified
%   transient response requirements.
%
% DESIGN METHODOLOGY:
%   1. Extract operating point parameters (voltage, power, impedances)
%   2. Calculate plant transfer functions for each control loop
%   3. Design controller parameters based on time-domain specifications:
%      - Natural frequency: ωn = 4/(ζ×ts2)
%      - PI gains: Kp, Ki calculated from desired closed-loop poles
%   4. Linearize closed-loop system for stability margin verification
%   5. Calculate gain and phase margins using numerical fsolve
%
% CONTROL HIERARCHY (from outer to inner loops):
%   - VSMP:  Virtual Synchronous Machine - Active Power (slow: ts2 ~ 1s)
%   - VSMQ:  Virtual Synchronous Machine - Reactive Power (slow: ts2 ~ 2s)
%   - VDC:   DC-bus Voltage Control (medium: ts2 ~ 80ms)
%   - RSC:   Rotor Side Converter Current Control (fast: ts2 ~ 4ms)
%   - GSC:   Grid Side Converter Current Control (fast: ts2 ~ 4ms)
%
% DESIGN SPECIFICATIONS:
%   All specifications are defined in CONFIG_POWER_SYSTEM.m:
%   - TRD_SPECS.*.ts2:  2% settling time [s]
%   - TRD_SPECS.*.seta: Damping ratio ζ [dimensionless]
%   - TRD_SPECS.VSMP.Dp: Steady-state damping coefficient (power-frequency droop)
%   - TRD_SPECS.VSMQ.DQ_absolute: Q-V droop coefficient [VAr/V]
%   - TRD_SPECS.STABILITY_MARGINS.w_ini_*: Initial guesses for margin calculation
%
% SYNTAX:
%   LIN_MODEL = CONTROL_DESIGN_TR(LIN_MODEL)
%
% INPUTS:
%   LIN_MODEL - Structure containing:
%               .MODEL: System model parameters (from CONFIG_MODEL.m)
%               .CONTROL: Control structure (from CONFIG_CONTROL.m)
%               .CONTROL_DESIGN: Design specifications (from CONFIG_POWER_SYSTEM.m)
%               .opSpecs: Operating point specifications
%
% OUTPUTS:
%   LIN_MODEL - Input structure with updated fields:
%               .CONTROL.*.PARAM: Designed controller parameters (Kp, Ki, H, Dp, Dd, etc.)
%               .CONTROL_DESIGN.*.trdParam: Design parameters used
%               .CONTROL_DESIGN.*.trdMargins: Calculated stability margins
%               .CONTROL_DESIGN.*.trdPss: Plant transfer functions
%               .CONTROL_DESIGN.*.trdGss: Open-loop transfer functions
%               .CONTROL_DESIGN.*.trdCss: Controller transfer functions
%
% EXECUTION TIME:
%   ~10-20 seconds (depends on linearization convergence and fsolve iterations)
%   Bottleneck: LINEAR_ANALYSIS call (~80-90% of total time)
%
% DESIGN EQUATIONS SUMMARY:
%   VSMP (PD controller):
%     C(s) = (1/Dp) × (1 + Dd×s) / (1 + Dp×s/(2×H))
%     H  = KTdelta/(2×Dp×ωn²×ω0)
%     Dd = (2×ζ×ωn×Jv - Dp)/(KTdelta×ω0)
%
%   VSMQ (Proportional controller):
%     C(s) = KQ
%     KQ = 1/(τ×(KQPsiv + DQ×KUPsiv)×ω0)
%     τ  = ts2/4
%
%   RSC/VDC/GSC (PI controllers):
%     C(s) = Kp + Ki/s
%     Ki = ωn² × L_eq / ω0
%     Kp = 2×ζ×ωn × L_eq / ω0 - R_eq
%
% MODIFICATION GUIDELINES:
%   ✅ SAFE: Modify specifications in CONFIG_POWER_SYSTEM.m
%   ⚠️ CAUTION: Modify design equations (requires control theory validation)
%   ❌ UNSAFE: Change structure field names (breaks compatibility)
%
% DEPENDENCIES:
%   - LINEAR_ANALYSIS.m: System linearization (called at line ~318)
%   - CONFIG_POWER_SYSTEM.m: Design specifications
%   - CONFIG_MODEL.m: System parameters
%   - fsolve: Numerical solver for stability margins
%
% SEE ALSO:
%   CONTROL_DESIGN_FR, CONFIG_CONTROL, LINEAR_ANALYSIS
%
% REFERENCES:
%   - CLAUDE.md: Project architecture and compatibility rules
%   - WORKFLOWS.md: Control design workflow documentation
%
% AUTHOR: DFIG-Based Wind Farm Research Project
% VERSION: 2.0 - Eliminated hardcoded values, enhanced documentation (2025-01-15)

LIN_MODEL.controlDesignMethod = 'Time response';
%--------------------------------------------------------------------------
%% CONTROL SPECIFICATIONS
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% VSMP controller specifications
%--------------------------------------------------------------------------
% Setling time 2% [s]
VSMP_ts2 = LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.ts2;
% Damping 
VSMP_seta = LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.seta;
%--------------------------------------------------------------------------
% VSMQ controller specifications
%--------------------------------------------------------------------------
% Setling time 2% [s]
VSMQ_ts2 = LIN_MODEL.CONTROL_DESIGN.VSMQ.trdSpecs.ts2;
%--------------------------------------------------------------------------
% RSC current controller specifications
%--------------------------------------------------------------------------
% Setling time 2% [s]
RSC_ts2 = LIN_MODEL.CONTROL_DESIGN.RSC.trdSpecs.ts2;
% Damping 
RSC_seta = LIN_MODEL.CONTROL_DESIGN.RSC.trdSpecs.seta;
%--------------------------------------------------------------------------
% DC-bus voltage controller specifications
%--------------------------------------------------------------------------
% Setling time 2% [s]
VDC_ts2 = LIN_MODEL.CONTROL_DESIGN.VDC.trdSpecs.ts2;
% Damping 
VDC_seta = LIN_MODEL.CONTROL_DESIGN.VDC.trdSpecs.seta;
%--------------------------------------------------------------------------
% GSC current controller specifications
%--------------------------------------------------------------------------
% Setling time 2% [s]
GSC_ts2 = LIN_MODEL.CONTROL_DESIGN.GSC.trdSpecs.ts2;
% Damping 
GSC_seta = LIN_MODEL.CONTROL_DESIGN.GSC.trdSpecs.seta;

%--------------------------------------------------------------
%% INITIAL CONTROL DESIGN
%--------------------------------------------------------------
MODEL = LIN_MODEL.MODEL;
CONTROL = LIN_MODEL.CONTROL;
% Laplace variable
s = tf('s');
% Nominal frequency (Hz)
w0 = 2*pi*MODEL.BASE.f0; 
%--------------------------------------------------------------------------
% Induction machine parameters
%--------------------------------------------------------------------------
% Number of DFIGs
nDFIG = MODEL.DFIG.PARAM.nDFIG;
selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
% Magnetizing reactance
Lm_pu = MODEL.DFIG.PARAM.Lm_pu(selectedDFIG);
% Stator and rotor leakage reactances
ls_pu = MODEL.DFIG.PARAM.Lsig_s_pu(selectedDFIG);
lr_pu = MODEL.DFIG.PARAM.Lsig_r_pu(selectedDFIG);
% Rotor resistance
Rr_pu = MODEL.DFIG.PARAM.Rr_pu(selectedDFIG);
% Auxiliar electric parameters
Ls_pu = Lm_pu + ls_pu;
Lr_pu = Lm_pu + lr_pu;
sg = 1 - Lm_pu.^2./Ls_pu./Lr_pu;
%--------------------------------------------------------------------------
% Number of grids
% nGRID = MODEL.GRID.PARAM.nGRID;
% Number of lines
% nLINE = MODEL.LINE.PARAM.nLINE;
%--------------------------------------------------------------------------
% GSC filter
%--------------------------------------------------------------------------
% GSC filter resistance
Rfg_pu = MODEL.DFIG.PARAM.Rfgsc_pu(selectedDFIG);
% GSC filter reactance
Lfg_pu = MODEL.DFIG.PARAM.Lfgsc_pu(selectedDFIG);
%--------------------------------------------------------------------------
% Grid impedance
%--------------------------------------------------------------------------
% Grid resistance
Rg_pu = MODEL.GRID.PARAM.Rg_pu;
% Grid reactance
Lg_pu = MODEL.GRID.PARAM.Lg_pu;
%--------------------------------------------------------------------------
% Transformer
%--------------------------------------------------------------------------
% Transformer resistance
Rt_pu = MODEL.DFIG.PARAM.Rt_pu(selectedDFIG);
% Transformer inductance
Lt_pu = MODEL.DFIG.PARAM.Lt_pu(selectedDFIG);
%--------------------------------------------------------------------------
% DC-bus capacitor bank [pu]
%--------------------------------------------------------------------------
Cdc_pu = MODEL.DFIG.PARAM.Cdc_pu(selectedDFIG); 
%--------------------------------------------------------------------------
% Virtual impedance
%--------------------------------------------------------------------------
% Virtual reactance [pu]
Lv_pu = CONTROL.VIMP.PARAM.Lv_pu;
% Virtual resistance [pu]
Rv_pu = CONTROL.VIMP.PARAM.Rv_pu;
%--------------------------------------------------------------------------
% Total impedance
%--------------------------------------------------------------------------
L_pu = Lv_pu(selectedDFIG) + Lt_pu + Lg_pu;
R_pu = Rv_pu(selectedDFIG) + Rt_pu + Rg_pu;
CONTROL.VIMP.PARAM.Rv_pu = Rv_pu;
%--------------------------------------------------------------------------
% VSMP control design
%--------------------------------------------------------------------------
opSpecs = LIN_MODEL.opSpecs;
% Grid frequency [pu]
w_op = opSpecs.f; 
% Active power at PCC [pu]
Pdfig_op = mean(opSpecs.P_ref); 
% Reactive power al PCC [pu]
% % Qdfig_op = mean(opSpecs.Q_ref); 
Qdfig_op = 0;
% Apparent power at PCC [VA]
Sdfig_op = Pdfig_op + 1j*Qdfig_op; 
% Grid voltage magnitude: component only in imaginary axis (0 + 1j*Vg)
Vg_op = opSpecs.Vgrid; 
% Grid current magnitude
Ig_op = sqrt(3)*abs(Sdfig_op)/Vg_op;
% Power-factor angle
phi_op = acos(Pdfig_op/abs(Sdfig_op));
% Grid voltage angle deltas
tandSop_num = L_pu*w_op*Ig_op*cos(phi_op) - R_pu*Ig_op*sin(phi_op);
tandSop_den = Vg_op + R_pu*Ig_op*cos(phi_op) + L_pu*w_op*Ig_op*sin(phi_op);
deltaSop = atan(tandSop_num/tandSop_den);
Pvsm_op = Pdfig_op + Ig_op^2*R_pu/sqrt(3);
% Operating point for virtual flux
PSIV0 = sqrt(3)*Pvsm_op/(w_op*Ig_op*cos(deltaSop+phi_op));
% K operating points
KTdelta = Vg_op*PSIV0*(w_op*L_pu*cos(deltaSop) + R_pu*sin(deltaSop))/(R_pu^2 + w_op^2*L_pu^2)/sqrt(3);
% Control parameter design - VSMP
VSMP_wn = 4/(VSMP_seta*VSMP_ts2);
VSMP_Jv = KTdelta/VSMP_wn^2*w0;
VSMP_H = VSMP_Jv/2;
% Steady-state damping coefficient from design specifications
% Physical meaning: Power-frequency droop = 1/Dp (Dp=20 → 5% droop)
% Source: TRD_SPECS.VSMP.Dp defined in CONFIG_POWER_SYSTEM.m
VSMP_Dp = LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.Dp;
VSMP_Dd = (2*VSMP_seta*VSMP_wn*VSMP_Jv - VSMP_Dp)/KTdelta/w0;
% Inertia [s]
LIN_MODEL.CONTROL.VSMP.PARAM.H = VSMP_H*ones(1,nDFIG); 
% Steady-state damping
LIN_MODEL.CONTROL.VSMP.PARAM.Dp = VSMP_Dp*ones(1,nDFIG);
% Transient damping
LIN_MODEL.CONTROL.VSMP.PARAM.Dd = VSMP_Dd*ones(1,nDFIG);
% VSMP derivative to error
LIN_MODEL.CONTROL.VSMP.PARAM.der2error = ones(1,nDFIG);
% Control transfer function
tf_VSMP = (1+s*VSMP_Dd)/(1+s*2*VSMP_H/VSMP_Dp);
ss_VSMP = ss(tf_VSMP);
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.ts2 = VSMP_ts2;
LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.seta = VSMP_seta;
LIN_MODEL.CONTROL_DESIGN.VSMP.trdSpecs.wn = VSMP_wn;
LIN_MODEL.CONTROL_DESIGN.VSMP.trdParam.Dp = VSMP_Dp;
LIN_MODEL.CONTROL_DESIGN.VSMP.trdParam.Dd = VSMP_Dd;
LIN_MODEL.CONTROL_DESIGN.VSMP.trdParam.H = VSMP_H;
LIN_MODEL.CONTROL_DESIGN.VSMP.trdParam.der2error = CONTROL.VSMP.PARAM.der2error;
LIN_MODEL.CONTROL_DESIGN.VSMP.trdDesignFss2 = ss(tf([VSMP_Dd 1],[1/VSMP_wn^2 2*VSMP_seta/VSMP_wn 1]));
LIN_MODEL.CONTROL_DESIGN.VSMP.trdDesignPss = ss(tf(KTdelta*w0/VSMP_Dp,[1 0]));
LIN_MODEL.CONTROL_DESIGN.VSMP.trdCss = ss_VSMP;
%--------------------------------------------------------------------------
% VSMQ control design
%--------------------------------------------------------------------------
% K operating points
% Qvsm_op = Qdfig_op + Ig_op^2*w_op*L_pu/sqrt(3);
KQPsiv = (2*PSIV0*L_pu*w_op^3 - Vg_op*w_op*(w_op*L_pu*cos(deltaSop) + R_pu*sin(deltaSop)))/(R_pu^2 + w_op^2*L_pu^2)/sqrt(3);
KUPsiv = w_op*sqrt((Lg_pu^2*w_op^2 + Rg_pu^2)/(L_pu^2*w_op^2 + R_pu^2));
% Control parameter design - VSMQ
VSMQ_tau = VSMQ_ts2/4;
% Q-V droop coefficient calculation from design specifications
% DQ_absolute: Absolute droop in VAr/V (voltage-level dependent)
% Source: TRD_SPECS.VSMQ.DQ_absolute defined in CONFIG_POWER_SYSTEM.m
% For 690V base: 900 VAr/V ≈ 0.295 pu droop
DQ_absolute = LIN_MODEL.CONTROL_DESIGN.VSMQ.trdSpecs.DQ_absolute;  % [VAr/V]
DQ_b = MODEL.BASE.Sb/MODEL.BASE.Ub;  % Base droop coefficient [VAr/V]
DQ_pu = DQ_absolute/DQ_b;  % Per-unit droop coefficient
KQ_pu = 1/VSMQ_tau/(KQPsiv + DQ_pu*KUPsiv)/w0;
% Voltage control
LIN_MODEL.CONTROL.VSMQ.PARAM.K_Fs_ref = KQ_pu*ones(1,nDFIG);
LIN_MODEL.CONTROL.VSMQ.PARAM.K_droopQV = DQ_pu*ones(1,nDFIG);
% Control transfer function
tf_VSMQ = KQ_pu;
ss_VSMQ = ss(tf_VSMQ);
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdSpecs.ts2 = VSMQ_ts2;
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdSpecs.tau = VSMQ_tau;
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdParam.K_Fs_ref = KQ_pu;
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdParam.K_droopQV = DQ_pu;
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdDesignFss2 = ss(tf(1,[VSMQ_tau 1]));
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdDesignPss = ss(tf(w0*(KUPsiv*DQ_pu+KQPsiv),[1  0]));
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdCss = ss_VSMQ;
%--------------------------------------------------------------------------
% RSC current control design
%--------------------------------------------------------------------------
% vr = Rr*ir + 1/w0*dFr/dt  + j*(w-wr)*Fr
% Fs = Lm*ir + Ls*is -> is = (Fs - Lm*ir)/Ls
% Fr = Lr*ir + Lm*is -> Fr = Lr*ir + Lm*((Fs - Lm*ir)/Ls 
% Fr = Lr*(1-Lm^2/Ls/Lr)*ir + Lm/Ls*Fs = sg*Lr*ir + Lm/Ls*Fs
% vr = Rr*ir + sg*Lr/w0*dir/dt + j*(w-wr)*sg*Lr*ir + Lm/Ls/w0*dFs/dt + j*(w-wr)*Lm/Ls*Fs
% It is assumed that dFsdq/dt = 0
% j*(w-wr)*Lm/Ls*Fsdq = j*(w-wr)*Lm/Ls*Fsd = 0
% vrdq = Rr*irdq + sg*Lr/w0*dirdq/dt + j*(w-wr)*sg*Lr*irdq 
% Rr*irdq + sg*Lr/w0*dirdq/dt = mvrdq = vrdq - j*(w-wr)*sg*Lr*irdq 
% mvrdq = vrdq - j*(w-wr)*sg*Lr*irdq
% vrd = mvrd - (w-wr)*sg*Lr*irq
% vrq = mvrq + (w-wr)*sg*Lr*ird
% mvrd: manipulated variable in axis d 
% mvrq: manipulated variable in axis q
%--------------------------------------------------------------------------
% When working in pu, P(s) = 1/(s*sg*Lr_pu/w0 + Rr_pu)
RSC_wn = 4/RSC_seta/RSC_ts2;
RSC_Ki_pu = RSC_wn^2*sg*Lr_pu/w0;
RSC_Kp_pu = 2*RSC_seta*RSC_wn*sg*Lr_pu/w0 - Rr_pu;
RSC_b_pu = 1;
% RSC current control (axid d) - Reactive power
LIN_MODEL.CONTROL.RSCd.PARAM.Kp = RSC_Kp_pu*ones(1,nDFIG); 
LIN_MODEL.CONTROL.RSCd.PARAM.Ki = RSC_Ki_pu*ones(1,nDFIG); 
LIN_MODEL.CONTROL.RSCd.PARAM.b = RSC_b_pu*ones(1,nDFIG);  
% RSC current control (axid q) - Active power
LIN_MODEL.CONTROL.RSCq.PARAM.Kp = RSC_Kp_pu*ones(1,nDFIG); 
LIN_MODEL.CONTROL.RSCq.PARAM.Ki = RSC_Ki_pu*ones(1,nDFIG); 
LIN_MODEL.CONTROL.RSCq.PARAM.b = RSC_b_pu*ones(1,nDFIG);
% Control transfer function
P = 1/(s*sg*Lr_pu/w0 + Rr_pu);
tf_RSC = RSC_Kp_pu + RSC_Ki_pu/s;
ss_RSC = ss(tf_RSC);
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.RSC.trdSpecs.ts2 = RSC_ts2;
LIN_MODEL.CONTROL_DESIGN.RSC.trdSpecs.seta = RSC_seta;
LIN_MODEL.CONTROL_DESIGN.RSC.trdSpecs.wn = RSC_wn;
LIN_MODEL.CONTROL_DESIGN.RSC.trdParam.Kp = RSC_Kp_pu;
LIN_MODEL.CONTROL_DESIGN.RSC.trdParam.Ki = RSC_Ki_pu;
LIN_MODEL.CONTROL_DESIGN.RSC.trdParam.Ki = RSC_Ki_pu;
LIN_MODEL.CONTROL_DESIGN.RSC.trdParam.b = RSC_b_pu;
LIN_MODEL.CONTROL_DESIGN.RSC.trdDesignFss2 = ...
      ss(tf([RSC_Kp_pu/RSC_Ki_pu 1],[1/RSC_wn^2 2*RSC_seta/RSC_wn 1]));
LIN_MODEL.CONTROL_DESIGN.RSC.trdDesignPss = ...
      ss(tf(1,[sg*Lr_pu/w0  Rr_pu]));
LIN_MODEL.CONTROL_DESIGN.RSC.trdCss = ss_RSC;
%--------------------------------------------------------------------------
% DC-bus voltage control design
%--------------------------------------------------------------------------
% Pdc -> Vdc^2  :  P(s) = 2/(s*Cdc_pu/w0)
% Design in pu
VDC_wn = 4/VDC_seta/VDC_ts2;
VDC_Ki_pu = VDC_wn^2*Cdc_pu/2/MODEL.BASE.wbase;
VDC_Kp_pu = VDC_seta*VDC_wn*Cdc_pu/MODEL.BASE.wbase;
VDC_b_pu = 1;
% Control parameters
LIN_MODEL.CONTROL.VDC.PARAM.Kp = VDC_Kp_pu*ones(1,nDFIG);
LIN_MODEL.CONTROL.VDC.PARAM.Ki = VDC_Ki_pu*ones(1,nDFIG);
LIN_MODEL.CONTROL.VDC.PARAM.b = VDC_b_pu*ones(1,nDFIG);
% Control transfer function
P = 2/(s*Cdc_pu/w0);
tf_VDC = VDC_Kp_pu + VDC_Ki_pu/s;
ss_VDC = ss(tf_VDC);
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VDC.trdSpecs.ts2 = VDC_ts2;
LIN_MODEL.CONTROL_DESIGN.VDC.trdSpecs.seta = VDC_seta;
LIN_MODEL.CONTROL_DESIGN.VDC.trdSpecs.wn = VDC_wn;
LIN_MODEL.CONTROL_DESIGN.VDC.trdParam.Kp = VDC_Kp_pu;
LIN_MODEL.CONTROL_DESIGN.VDC.trdParam.Ki = VDC_Ki_pu;
LIN_MODEL.CONTROL_DESIGN.VDC.trdParam.Ki = VDC_Ki_pu;
LIN_MODEL.CONTROL_DESIGN.VDC.trdParam.b = VDC_b_pu;
LIN_MODEL.CONTROL_DESIGN.VDC.trdDesignFss2 = ...
      ss(tf([VDC_Kp_pu/VDC_Ki_pu 1],[1/VDC_wn^2 2*VDC_seta/VDC_wn 1]));
LIN_MODEL.CONTROL_DESIGN.VDC.trdDesignPss = ...
      ss(tf(2,[Cdc_pu/w0  0]));
LIN_MODEL.CONTROL_DESIGN.VDC.trdCss = ss_VDC;
%--------------------------------------------------------------------------
% GSC current control design
%--------------------------------------------------------------------------
% vs - vg = Rfg*ig + Lfg/w0*dig/dt + j*w*Lfg*ig
% Rfg*ig + Lfg/w0*dig/dt = -mvdq = -vgdq + vsdq - j*w*Lfg*ig
% vgdq = -vgdq + vsdq - j*w*Lfg*ig
% vgd = -mvd + vsd + w*Lfg*igq
% vgq = -mvq + vsq - w*Lfg*igd
% mvd: manipulated variable in axis d 
% mvq: manipulated variable in axis q
%--------------------------------------------------------------------------
% When working in pu, P(s) = 1/(s*Lfg_pu/w0 + Rfg_pu)
GSC_wn = 4/GSC_seta/GSC_ts2;
GSC_Ki_pu = GSC_wn^2*Lfg_pu/w0;
GSC_Kp_pu = 2*GSC_seta*GSC_wn*Lfg_pu/w0 - Rfg_pu;
GSC_b_pu = 1;
% GSC current control (axid d) - Reactive power
LIN_MODEL.CONTROL.GSCd.PARAM.Kp = GSC_Kp_pu*ones(1,nDFIG); 
LIN_MODEL.CONTROL.GSCd.PARAM.Ki = GSC_Ki_pu*ones(1,nDFIG); 
LIN_MODEL.CONTROL.GSCd.PARAM.b = GSC_b_pu*ones(1,nDFIG);  
% GSC current control (axid q) - Active power
LIN_MODEL.CONTROL.GSCq.PARAM.Kp = GSC_Kp_pu*ones(1,nDFIG); 
LIN_MODEL.CONTROL.GSCq.PARAM.Ki = GSC_Ki_pu*ones(1,nDFIG); 
LIN_MODEL.CONTROL.GSCq.PARAM.b = GSC_b_pu*ones(1,nDFIG);
% Control transfer function
tf_GSC = GSC_Kp_pu + GSC_Ki_pu/s;
ss_GSC = ss(tf_GSC);
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.GSC.trdSpecs.ts2 = GSC_ts2;
LIN_MODEL.CONTROL_DESIGN.GSC.trdSpecs.seta = GSC_seta;
LIN_MODEL.CONTROL_DESIGN.GSC.trdSpecs.wn = GSC_wn;
LIN_MODEL.CONTROL_DESIGN.GSC.trdParam.Kp = GSC_Kp_pu;
LIN_MODEL.CONTROL_DESIGN.GSC.trdParam.Ki = GSC_Ki_pu;
LIN_MODEL.CONTROL_DESIGN.GSC.trdParam.Ki = GSC_Ki_pu;
LIN_MODEL.CONTROL_DESIGN.GSC.trdParam.b = GSC_b_pu;
LIN_MODEL.CONTROL_DESIGN.GSC.trdDesignFss2 = ...
      ss(tf([GSC_Kp_pu/GSC_Ki_pu 1],[1/GSC_wn^2 2*GSC_seta/GSC_wn 1]));
LIN_MODEL.CONTROL_DESIGN.GSC.trdDesignPss = ...
      ss(tf(1,[Lfg_pu/w0  Rfg_pu]));
LIN_MODEL.CONTROL_DESIGN.GSC.trdCss = ss_GSC;

%--------------------------------------------------------------
%% TR DESIGN TRANSFER FUNCTIONS AND STABILITY MARGINS
%--------------------------------------------------------------
cd ../CONFIGURATION
% Number of controllers
nCONTROL = 7;
% Linear analysis
LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL);
% State space matrices
matA = LIN_MODEL.ssModel.a;
matB = LIN_MODEL.ssModel.b;
matC = LIN_MODEL.ssModel.c;
matD = LIN_MODEL.ssModel.d;
% fsolve options
opt_fsolve = optimoptions('fsolve');
opt_fsolve.MaxIterations = 5000;
opt_fsolve.Display = 'off';
% Controllers
Css = {
    LIN_MODEL.CONTROL_DESIGN.VSMP.trdCss
    LIN_MODEL.CONTROL_DESIGN.VSMQ.trdCss
    LIN_MODEL.CONTROL_DESIGN.RSC.trdCss
    LIN_MODEL.CONTROL_DESIGN.RSC.trdCss
    LIN_MODEL.CONTROL_DESIGN.VDC.trdCss
    LIN_MODEL.CONTROL_DESIGN.GSC.trdCss
    LIN_MODEL.CONTROL_DESIGN.GSC.trdCss
    };
% Transfer functions
Pss = cell(1,nCONTROL);
Gss = cell(1,nCONTROL);
Fss = cell(1,nCONTROL);
% Stability margins
Am = NaN(1,7); AmdB = NaN(1,7); Fm = NaN(1,7);
wu = NaN(1,7); wo = NaN(1,7);
% Initial crossover frequency guesses for fsolve convergence [rad/s]
% Source: TRD_SPECS.STABILITY_MARGINS defined in CONFIG_POWER_SYSTEM.m
% Values reflect control loop bandwidth hierarchy (outer loops slow, inner loops fast)
% Good initial guesses improve fsolve convergence speed and reliability
stability_specs = LIN_MODEL.CONTROL_DESIGN.STABILITY_MARGINS;
w_ini = [
    stability_specs.w_ini_VSMP   % VSMP: Active power loop
    stability_specs.w_ini_VSMQ   % VSMQ: Reactive power/voltage loop
    stability_specs.w_ini_RSC    % RSCd: Rotor d-axis current loop
    stability_specs.w_ini_RSC    % RSCq: Rotor q-axis current loop
    stability_specs.w_ini_VDC    % VDC: DC voltage loop
    stability_specs.w_ini_GSC    % GSCd: Grid d-axis current loop
    stability_specs.w_ini_GSC    % GSCq: Grid q-axis current loop
];
for ii = 1:nCONTROL
    indT = nCONTROL*(selectedDFIG-1)+ii;
    indS = nCONTROL*nDFIG + nCONTROL*(selectedDFIG-1)+ii;
    Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
    Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));
    Gss{ii} = -Tss/Sss;
    Fss{ii} = -Tss;
    Pss{ii} = Gss{ii}/Css{ii};
    [wo(ii),~,exitflag] = fsolve(@(w) abs(freqresp(Gss{ii},w))-1,w_ini(ii),opt_fsolve);
    if exitflag<1 || wo(ii)<0 
        wo(ii) = NaN;
        Fm(ii) = NaN;
    else
        Fm(ii) = 180 + 180/pi*angle(freqresp(Gss{ii},wo(ii)));
    end
    [wu(ii),~,exitflag] = fsolve(@(w) 180/pi*angle(freqresp(Gss{ii},w))+180,w_ini(ii),opt_fsolve);
    if exitflag<1 || wu(ii)<0
        wu(ii) = NaN;
        Am(ii) = NaN;
        AmdB(ii) = NaN;
    else
        Am(ii) = 1/abs(freqresp(Gss{ii},wu(ii)));
        AmdB(ii) = 20*log10(Am(ii));
    end
end
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMP.trdPss = Pss{1};
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdPss = Pss{2};
LIN_MODEL.CONTROL_DESIGN.RSC.trdPss = [Pss{3} Pss{4}];
LIN_MODEL.CONTROL_DESIGN.VDC.trdPss = Pss{5};
LIN_MODEL.CONTROL_DESIGN.GSC.trdPss = [Pss{6} Pss{7}];
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMP.trdGss = Gss{1};
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdGss = Gss{2};
LIN_MODEL.CONTROL_DESIGN.RSC.trdGss = [Gss{3} Gss{4}];
LIN_MODEL.CONTROL_DESIGN.VDC.trdGss = Gss{5};
LIN_MODEL.CONTROL_DESIGN.GSC.trdGss = [Gss{6} Gss{7}];
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMP.trdFss = Fss{1};
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdFss = Fss{2};
LIN_MODEL.CONTROL_DESIGN.RSC.trdFss = [Fss{3} Fss{4}];
LIN_MODEL.CONTROL_DESIGN.VDC.trdFss = Fss{5};
LIN_MODEL.CONTROL_DESIGN.GSC.trdFss = [Fss{6} Fss{7}];
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMP.trdMargins.Fm = Fm(1);
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdMargins.Fm = Fm(2);
LIN_MODEL.CONTROL_DESIGN.RSC.trdMargins.Fm = Fm(3:4);
LIN_MODEL.CONTROL_DESIGN.VDC.trdMargins.Fm = Fm(5);
LIN_MODEL.CONTROL_DESIGN.GSC.trdMargins.Fm = Fm(6:7);
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMP.trdMargins.wo = wo(1);
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdMargins.wo = wo(2);
LIN_MODEL.CONTROL_DESIGN.RSC.trdMargins.wo = wo(3:4);
LIN_MODEL.CONTROL_DESIGN.VDC.trdMargins.wo = wo(5);
LIN_MODEL.CONTROL_DESIGN.GSC.trdMargins.wo = wo(6:7);
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMP.trdMargins.AmdB = AmdB(1);
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdMargins.AmdB = AmdB(2);
LIN_MODEL.CONTROL_DESIGN.RSC.trdMargins.AmdB = AmdB(3:4);
LIN_MODEL.CONTROL_DESIGN.VDC.trdMargins.AmdB = AmdB(5);
LIN_MODEL.CONTROL_DESIGN.GSC.trdMargins.AmdB = AmdB(6:7);
%--------------------------------------------------------------------------
LIN_MODEL.CONTROL_DESIGN.VSMP.trdMargins.wu = wu(1);
LIN_MODEL.CONTROL_DESIGN.VSMQ.trdMargins.wu = wu(2);
LIN_MODEL.CONTROL_DESIGN.RSC.trdMargins.wu = wu(3:4);
LIN_MODEL.CONTROL_DESIGN.VDC.trdMargins.wu = wu(5);
LIN_MODEL.CONTROL_DESIGN.GSC.trdMargins.wu = wu(6:7);
