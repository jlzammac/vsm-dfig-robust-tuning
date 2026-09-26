function LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID)
% LINEAR_ANALYSIS Performs steady-state computation, operating point
% initialization, and linearization for N-DFIG wind farm power system
%
% SYNTAX:
%   LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL)
%   LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL, workerID)
%
% INPUTS:
%   LIN_MODEL - Structure containing:
%               .MODEL: System model parameters (from CONFIG_MODEL.m)
%               .CONTROL: Control parameters (from CONFIG_CONTROL.m)
%               .opSpecs: Operating point specifications
%               .modelName: Simulink model name ('POWER_SYSTEM_FULL' or 'POWER_SYSTEM_SIMP')
%   workerID  - (Optional) Worker ID for parallel execution (0 = sequential, >0 = parallel worker)
%               Default: 0
%
% OUTPUTS:
%   LIN_MODEL - Updated structure with additional fields:
%               .ssModel: State-space linear model
%               .eigenvalues: System eigenvalues
%               .participations: Participation factors
%               .stability: Boolean stability indicator
%               .minDamping: Minimum damping ratios
%               .maxRealEig: Maximum real part of eigenvalues
%               ... and other analysis results
%
% DESCRIPTION:
%   This function performs three main tasks:
%   1. Steady-state computation: Solves nonlinear equations (fsolve) for each DFIG
%      to find equilibrium operating point
%   2. Operating point initialization: Prepares Simulink model with computed states
%   3. Linearization: Extracts state-space model and performs eigenvalue analysis
%
% PERFORMANCE:
%   Typical execution time (N=4 DFIGs): ~0.1-0.2 seconds
%   - fsolve loop: ~100-170ms (sequential)
%   - Simulink linearization: ~2-3 seconds
%   - Eigenanalysis: ~400-800ms
%
% NOTES:
%   - Function is designed to work in parallel execution contexts (parfor)
%   - Uses workerID to assign different Simulink model copies to parallel workers
%   - Convergence tolerance: fsolve residual < 1e-6 (validates automatically)
%
% SEE ALSO:
%   CONFIG_POWER_SYSTEM, EIGEN_CALC, STATE_NAMES, LINEARIZE

if nargin == 1
    workerID = 0;
end

%--------------------------------------------------------------------------
%% COPY MODEL & CONTROL
%--------------------------------------------------------------------------
CONTROL = LIN_MODEL.CONTROL;
MODEL = LIN_MODEL.MODEL;
opSpecs = LIN_MODEL.opSpecs;

%--------------------------------------------------------------------------
%% OPERATING POINT DATA
%--------------------------------------------------------------------------
% Frequency [pu]
w = opSpecs.f;
% Grid voltage magnitude
Vgrid = opSpecs.Vgrid;
% PCC voltage magnitude
Vp = opSpecs.Vp;
% DFIG active power
P_ref = opSpecs.P_ref;
if isfield(opSpecs,'Q_ref')
    % DFIG reactive power
    Q_ref = opSpecs.Q_ref;
else
    % Stator voltage magnitude
    Vs_ref = opSpecs.Vs_ref;
end
% Reactive power reference from GSC into stator
Qg_ref = opSpecs.Qg_ref;
% Pitch angle [deg]
pitch = opSpecs.pitch;
% DC-Link voltage reference
Vdc_ref = opSpecs.Vdc_ref;
% Load current from node 1 of the grid line
il1 = opSpecs.il1;
% Load current from node 2 of the grid line
il2 = opSpecs.il2;
%--------------------------------------------------------------------------
%% PARAMETERS
%--------------------------------------------------------------------------
% Number of DFIGs
nDFIG = MODEL.DFIG.PARAM.nDFIG;
% Number of grids
nGRID = MODEL.GRID.PARAM.nGRID;
% Number of lines
nLINE = MODEL.LINE.PARAM.nLINE;
% Frequency [rad/s]
w0 = 2*pi*MODEL.BASE.f0;
%--------------------------------------------------------------------------
% Induction machine parameters
%--------------------------------------------------------------------------
% Magnetizing reactance
Lm_pu = MODEL.DFIG.PARAM.Lm_pu;
% Stator and rotor leakage reactances
ls_pu = MODEL.DFIG.PARAM.Lsig_s_pu;
lr_pu = MODEL.DFIG.PARAM.Lsig_r_pu;
% Rotor resistance
Rr_pu = MODEL.DFIG.PARAM.Rr_pu;
% Rotor resistance
Rs_pu = MODEL.DFIG.PARAM.Rs_pu;
% Auxiliar electric parameteRs_pu
Ls_pu = Lm_pu + ls_pu;
Lr_pu = Lm_pu + lr_pu;
sg = 1 - Lm_pu.^2./Ls_pu./Lr_pu;
%--------------------------------------------------------------------------
% GSC filter
%--------------------------------------------------------------------------
% GSC filter resistance
Rfg_pu = MODEL.DFIG.PARAM.Rfgsc_pu;
% GSC filter reactance
Lfg_pu = MODEL.DFIG.PARAM.Lfgsc_pu;
%--------------------------------------------------------------------------
% Transformer
%--------------------------------------------------------------------------
% Transformer resistance
Rt_pu = MODEL.DFIG.PARAM.Rt_pu;
% Transformer inductance
Lt_pu = MODEL.DFIG.PARAM.Lt_pu;
%--------------------------------------------------------------------------
% DC-bus capacitor bank [pu]
%--------------------------------------------------------------------------
Cdc_pu = MODEL.DFIG.PARAM.Cdc_pu; 
%--------------------------------------------------------------------------
% Turbine
%--------------------------------------------------------------------------
% Turbine data
turbineData = MODEL.DFIG.PARAM.turbineData;
%--------------------------------------------------------------------------
% Mechanical model: 2 masses (per unit)
%--------------------------------------------------------------------------
Ht_pu = MODEL.DFIG.PARAM.Ht_pu; 
Dt_pu = MODEL.DFIG.PARAM.Dt_pu; 
Hg_pu = MODEL.DFIG.PARAM.Hg_pu;
Dg_pu = MODEL.DFIG.PARAM.Dg_pu;
Dtg_pu = MODEL.DFIG.PARAM.Dtg_pu; 
Ktg_pu = MODEL.DFIG.PARAM.Ktg_pu; 
%--------------------------------------------------------------------------
% Grid
%--------------------------------------------------------------------------
% Grid resistance
Rg_pu = MODEL.GRID.PARAM.Rg_pu;
% Grid reactance
Lg_pu = MODEL.GRID.PARAM.Lg_pu;
% Node 1 capacitance
Cn1_pu = MODEL.LINE.PARAM.Cn1_pu;
% Node 1 resistance
Rn1_pu = MODEL.LINE.PARAM.Rn1_pu;
% Grid: damping (Deq_pu/2) and steady-state droop (2/Deq_pu)
Deq_pu = MODEL.GRID.PARAM.Deq_pu;
% Grid Inertia [s]
Hgrid = MODEL.GRID.PARAM.H;
% Time constant [s]
Tgov = MODEL.GRID.PARAM.Tgov;
% Turbine time constants [s]
% Second-order model: (Ttb1*Ttb2*s + 1)/(Ttb1*Ttb2*s + (Ttb1+Ttb2)*s + 1))
Ttb1 = MODEL.GRID.PARAM.Ttb1;
Ttb2 = MODEL.GRID.PARAM.Ttb2;
%--------------------------------------------------------------------------
% VSMP control parameters
%--------------------------------------------------------------------------
% Inertia [s]
H = CONTROL.VSMP.PARAM.H; 
% Steady-state damping
Dp = CONTROL.VSMP.PARAM.Dp; 
% Transient damping
Dd = CONTROL.VSMP.PARAM.Dd;
%--------------------------------------------------------------------------
% VSMQ control parameters
%--------------------------------------------------------------------------
% Voltage control
K_Fs_ref = CONTROL.VSMQ.PARAM.K_Fs_ref;
K_droopQV = CONTROL.VSMQ.PARAM.K_droopQV;
%--------------------------------------------------------------------------
% Virtual impedance
%--------------------------------------------------------------------------
Lv = CONTROL.VIMP.PARAM.Lv_pu;
% Rv = CONTROL.VIMP.PARAM.Rv_pu;
%--------------------------------------------------------------------------
% RSC current control (axid d) - Reactive power
%--------------------------------------------------------------------------
Kp_ird = CONTROL.RSCd.PARAM.Kp; 
Ki_ird = CONTROL.RSCd.PARAM.Ki; 
b_ird = CONTROL.RSCd.PARAM.b;  
%--------------------------------------------------------------------------
% RSC current control (axid q) - Active power
%--------------------------------------------------------------------------
Kp_irq = CONTROL.RSCq.PARAM.Kp; 
Ki_irq = CONTROL.RSCq.PARAM.Ki; 
b_irq = CONTROL.RSCq.PARAM.b;
%--------------------------------------------------------------------------
% DC-Link voltage control
%--------------------------------------------------------------------------
Kp_vdc = CONTROL.VDC.PARAM.Kp;
Ki_vdc = CONTROL.VDC.PARAM.Ki;
b_vdc = CONTROL.VDC.PARAM.b;
%--------------------------------------------------------------------------
% GSC current control (axid d) - Reactive power
%--------------------------------------------------------------------------
Kp_igd = CONTROL.GSCd.PARAM.Kp; 
Ki_igd = CONTROL.GSCd.PARAM.Ki; 
b_igd = CONTROL.GSCd.PARAM.b;  
%--------------------------------------------------------------------------
% GSC current control (axid q) - Active power
%--------------------------------------------------------------------------
Kp_igq = CONTROL.GSCq.PARAM.Kp; 
Ki_igq = CONTROL.GSCq.PARAM.Ki; 
b_igq = CONTROL.GSCq.PARAM.b;

%--------------------------------------------------------------------------
%% OPTIONS FSOLVE
%--------------------------------------------------------------------------
opt_fsolve = optimoptions('fsolve');
% Algorithm: 'trust-region-dogleg'
% Display: 'final'
% FiniteDifferenceStepSize: 'sqrt(eps)'
% FiniteDifferenceType: 'forward'
% FunctionTolerance: 1e-06
% MaxFunctionEvaluations: '100*numberOfVariables'
% MaxIterations: 400
% OptimalityTolerance: 1e-06
% OutputFcn: []
% PlotFcn: []
% SpecifyObjectiveGradient: 0
% StepTolerance: 1e-06
% TypicalX: 'ones(numberOfVariables,1)'
% UseParallel: 0
opt_fsolve.MaxIterations = 5000;
opt_fsolve.Display = 'off';

%--------------------------------------------------------------------------
%% STEADY-STATE COMPUTATION
%--------------------------------------------------------------------------
% Grid line
%--------------------------------------------------------------------------
% Grid active and reactive power 
% Pline = Vp*Vgrid/Lg_pu*sin(delta)/sqrt(3)
% Qline = (Vp^2-Vp*Vgrid*cos_delta)/Lg_pu/sqrt(3);
Pline = sum(P_ref);
if Vp < sqrt(3)*Pline*Lg_pu/Vgrid
    % PCC voltage constraint: Vp must be greater than sqrt(3)*Pline*Lg_pu/Vgrid
    % Violation indicates insufficient PCC voltage for desired power transfer
end
GRID_delta = asin(Pline.*Lg_pu./Vp./Vgrid*sqrt(3));
% PCC and grid voltages
vgrid = Vgrid;
vp = Vp*(exp(1j*GRID_delta));
% Line current
iline = (vp - vgrid)/(Rg_pu + 1j*w*Lg_pu);
% Line active reactive power
Pline = real(vp*conj(iline))/sqrt(3);
Qline = imag(vp*conj(iline))/sqrt(3);
% Active power from grid
Pgrid = -real(vgrid*conj(iline))/sqrt(3);
Pgrid_ref = Pgrid;
% Active power from grid
Qgrid = -imag(vgrid*conj(iline))/sqrt(3);
%--------------------------------------------------------------------------
% Node current in PCC
%--------------------------------------------------------------------------
if strcmp(LIN_MODEL.modelName(end-3:end),'FULL')
    in1 = vp.*(1/Rn1_pu + 1j*w*Cn1_pu);
else
    in1 = 0;
end
%--------------------------------------------------------------------------
% Transformer line for each DFIG
%--------------------------------------------------------------------------
% it = iline.*(1./Lt_pu)/sum(1./Lt_pu);
it = (iline+in1+il1)/nDFIG*ones(1,nDFIG);
% Stator voltage
vs = vp + it.*(Rt_pu + 1j*w*Lt_pu);
% DFIG active and reactive power
Ptrafo = real(vp.*conj(it))/sqrt(3);
Qtrafo = imag(vp.*conj(it))/sqrt(3);
Pdfig = real(vs.*conj(it))/sqrt(3);
Qdfig = imag(vs.*conj(it))/sqrt(3);
%--------------------------------------------------------------------------
% DFIG
%--------------------------------------------------------------------------
cd ../SIMULINK
% Unknown variables: [vrr vri isr isi irr iri Fsr Fsi Frr Fri ...
%                     vgr vgi igr igi Pm windSpeed wr Fs_ref th_VSMP]
%--------------------------------------------------------------------------
% (1) 0 = -vr + Rr*ir + j*(w-wr)*Fr
% (2) vs = Rs*is + j*w*Fs
% (3) 0 = -Fr + Lm*is + Lr*ir
% (4) 0 = -Fs + Ls*is + Lm*ir
%--------------------------------------------------------------------------
% (5) it + is + ig = 0;
%--------------------------------------------------------------------------
% (6) vs = vg + (Rfg + j*w*Lfg)*ig
% (7) sqrt(3)*Qg_ref = -igd*Vs = -real(ig*exp(-j*th_VSMP))*Vs
%--------------------------------------------------------------------------
% PRSC = PGSC
% (8) vrr*irr + vri*iri = vgr*igr + vgi*igi
%--------------------------------------------------------------------------
% Mechanical power [pu]
% Tm = - Te + (Dt_pu + Dg_pu)*wr -> Pm = -Te*wr + (Dt_pu + Dg_pu)*wr^2
% sqrt(3)*Te./Lm_pu = imag(is*conj(ir)) = -isr*iri + isi*irr
% MPPT TURBINE CURVE
turbineMPPT = WIND_TURBINE_MPPT(1,turbineData);
% wrMPPT = interp1(turbineMPPT.turbinePower,turbineMPPT.turbineSpeed,Pm)
% (9)  Pm = Lm*(-isr*iri + isi*irr)*wr/sqrt(3) + (Dt_pu + Dg_pu)*wr^2
% (10) Pm = WIND_TURBINE_OP(pitch,windSpeed,wr,turbineData)
% (11) wr = (wrMPPT + 1.3)/2 -> wrMPPT = 2*wr - 1.3
%--------------------------------------------------------------------------
% Fs_ref - Lm*irdq - Lv*itdq - Ls*isdq = 0
% (13)  Fs_ref - Lm*real(ir*exp(-1j*th_VSMP)) - Lv*real(it*exp(-1j*th_VSMP)) - Ls*real(is*exp(-1j*th_VSMP)) = 0
% (14) -Lm*imag(ir*exp(-1j*th_VSMP)) - Lv*imag(it*exp(-1j*th_VSMP)) - Ls*imag(is*exp(-1j*th_VSMP)) = 0
%--------------------------------------------------------------------------
% x(1:10) = [vrr vri isr isi irr iri Fsr Fsi Frr Fri]'
% x(11:14) = [vgr vgi igr igi]
% x(15:17) = [Pm windSpeed wr]
% x(18:19) = [Fs_ref  th_VSMP]
%--------------------------------------------------------------------------
vr = NaN(1,nDFIG); is = NaN(1,nDFIG); ir = NaN(1,nDFIG); Fs = NaN(1,nDFIG); 
Fr = NaN(1,nDFIG); vg = NaN(1,nDFIG); ig = NaN(1,nDFIG); 
Pm = NaN(1,nDFIG); windSpeed = NaN(1,nDFIG); wr = NaN(1,nDFIG);
Fs_ref = NaN(1,nDFIG); th_VSMP = NaN(1,nDFIG);
fval = NaN(nDFIG,19);
R = eye(2); J = [0 -1; 1 0]; Z = zeros(2);
for nn = 1:nDFIG
    vsr = real(vs(nn)); vsi = imag(vs(nn)); 
    itr = real(it(nn)); iti = imag(it(nn)); 
    B = [0 ; 0 ; vsr ; vsi ; 0 ; 0 ; 0 ; 0];
    A1 = [-R     Z       Rr_pu(nn)*R     Z        w*J
           Z  Rs_pu(nn)*R     Z         w*J        Z
           Z  Lm_pu(nn)*R Lr_pu(nn)*R    Z        -R
           Z  Ls_pu(nn)*R Lm_pu(nn)*R   -R         Z  ];
    A2 = zeros(size(A1)); A2(1:2,9:10)= J;
    [x0,fval(nn,:)] = fsolve(@(x) [...
            -B + (A1-x(17)*A2)*x(1:10) ; ...
            itr + x(3) + x(13) ; ...
            iti + x(4) + x(14) ; ...
            -[vsr ; vsi] + [R Rfg_pu(nn)*R+w*Lfg_pu(nn)*J]*x(11:14) ; ...
            -sqrt(3)*Qg_ref(nn) - real((x(13)+1j*x(14))*exp(-1j*x(19)))*abs(vs(nn)) ;  ...
            -x(1)*x(5) - x(2)*x(6) + x(11)*x(13) + x(12)*x(14) ; ...
            x(15) +  Lm_pu(nn)*(x(4)*x(5) - x(3)*x(6))*x(17)/sqrt(3) - (Dt_pu(nn)+Dg_pu(nn))*x(17)^2;  ...
            x(15) - WIND_TURBINE_OP(pitch(nn),x(16),x(17),turbineData); ...
            2*x(17) - 1.3 - interp1(turbineMPPT.turbinePower,turbineMPPT.turbineSpeed,x(15)) ; ...
            x(18) - Lm_pu(nn)*real((x(5) + 1j*x(6))*exp(-1j*x(19))) - Lv(nn)*real(-(x(3)+x(13)+1j*x(4)+1j*x(14))*exp(-1j*x(19))) - Ls_pu(nn)*real((x(3)+1j*x(4))*exp(-1j*x(19))) ; ...
            -Lm_pu(nn)*imag((x(5) + 1j*x(6))*exp(-1j*x(19))) - Lv(nn)*imag(-(x(3)+x(13)+1j*x(4)+1j*x(14))*exp(-1j*x(19))) - Ls_pu(nn)*imag((x(3)+1j*x(4))*exp(-1j*x(19)))],...          
           [ 0.5*[1 ; 1 ; -1 ; -1 ; 1 ; -1 ; 1 ; -1 ; 1 ; -1 ; 1 ; 1 ; 1 ; 1 ] ; 0.5 ; 10 ; 1 ; 1 ; -pi/4],opt_fsolve);
    vr(nn) = x0(1) + 1j*x0(2);
    is(nn) = x0(3) + 1j*x0(4);
    ir(nn) = x0(5) + 1j*x0(6);
    Fs(nn) = x0(7) + 1j*x0(8);
    Fr(nn) = x0(9) + 1j*x0(10);
    vg(nn) = x0(11) + 1j*x0(12);
    ig(nn) = x0(13) + 1j*x0(14);
    Pm(nn) = x0(15);
    windSpeed(nn) = x0(16);
    wr(nn) = x0(17);
    wrMPPT(nn) = x0(17)/1.25;
    Fs_ref(nn) = x0(18);
    th_VSMP(nn) = x0(19);
end
%--------------------------------------------------------------------------
% Validate fsolve convergence
%--------------------------------------------------------------------------
maxErrFsolve_loop = max(abs(fval(:)));
if maxErrFsolve_loop > 1e-6
    warning('LINEAR_ANALYSIS:FsolveConvergence', ...
            'fsolve did not fully converge. Max residual = %.2e (threshold: 1e-6)\nThis may indicate numerical issues or inappropriate operating point.', ...
            maxErrFsolve_loop);
end
cd ../CONFIGURATION
% Turbine speed [pu]
wt = wr;
% Electric torque [pu]
Te = Lm_pu.*imag(is.*conj(ir))/sqrt(3); 
% Shaft torque [pu]
Ttg = Dg_pu.*wr - Te;
% Mechanical torque [pu]
Tm = Ttg + Dt_pu.*wt;
%-------------------------------------------------------------------------
% Magnetic fluxes
%--------------------------------------------------------------------------
Fg = Lfg_pu.*ig;
Ft = Lt_pu.*it;
Fgt = Fg - Ft;
Fst = Fs - Ft;
%--------------------------------------------------------------------------
% DC-Link active power and current
%--------------------------------------------------------------------------
P_RSC = real(vr.*conj(ir))/sqrt(3);
P_GSC = real(vg.*conj(ig))/sqrt(3);
Pdc = P_GSC - P_RSC;
Vdc = Vdc_ref;
idc = Pdc./Vdc;
%--------------------------------------------------------------------------
% Grid load-frequency control
%--------------------------------------------------------------------------
% Grid active power
Pgrid = -real(vgrid.*conj(iline))/sqrt(3); % Flows from the grid
% Speed governor
Pm_grid_ref = Pgrid_ref*MODEL.BASE.Sb/MODEL.GRID.BASE.Sb;
xsg = Pm_grid_ref + 0.5*Deq_pu*(1-w);
xt2 = 0;
xt1 = -(Ttb1+Ttb2)*xt2 + xsg;
% Mechanical power
Pm_grid = Ttb1*Ttb2*xt2 + xt1;
%--------------------------------------------------------------------------
% DFIG CONTROL
%--------------------------------------------------------------------------
% VSMP
%--------------------------------------------------------------------------
% dx_VSMP = 1/(2*H)*(P_ref - P - Dp*(w_VSMP_pu - 1))
% w_VSMP_pu = x_VSMP + (Dd/2/H)*(P_ref - P)
P = real(vs.*conj(it))/sqrt(3);
P_ref = P;
w_VSMP_pu = 1 + (P_ref - P)./Dp;
x_VSMP = w_VSMP_pu - (Dd./2./H).*(P_ref - P);
%--------------------------------------------------------------------------
% VSMQ
%--------------------------------------------------------------------------
Q = imag(vs.*conj(it))/sqrt(3);
Vs = abs(vs);
if isfield(opSpecs,'Q_ref')
    Vs_ref = Vs - (Q_ref - Q)./K_droopQV;
else
    Q_ref = Q - K_droopQV.*(Vs_ref - Vs);
end
%--------------------------------------------------------------------------
% RSC
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
irdq = ir.*exp(-1j*th_VSMP);
iRSCd = real(irdq);
iRSCq = imag(irdq);
iRSCd_ref = iRSCd; 
iRSCq_ref = iRSCq;
vRSCdq = vr.*exp(-1j*th_VSMP);
vRSCd = real(vRSCdq); 
vRSCq = imag(vRSCdq);
I_ird = vRSCd + (w_VSMP_pu - wr).*sg.*Lr_pu.*iRSCq - Kp_ird.*(b_ird.*iRSCd_ref - iRSCd);
I_irq = vRSCq - (w_VSMP_pu - wr).*sg.*Lr_pu.*iRSCd - Kp_irq.*(b_irq.*iRSCq_ref - iRSCq);
%--------------------------------------------------------------------------
% GSC
%--------------------------------------------------------------------------
% vs - vg = Rfg*ig + Lfg/w0*dig/dt + j*w*Lfg*ig
% Rfg*ig + Lfg/w0*dig/dt = -mvdq = -vgdq + vsdq - j*w*Lfg*ig
% vgdq = -vgdq + vsdq - j*w*Lfg*ig
% vgd = -mvd + vsd + w*Lfg*igq
% vgq = -mvq + vsq - w*Lfg*igd
% mvd: manipulated variable in axis d 
% mvq: manipulated variable in axis q
%--------------------------------------------------------------------------
vsdq = vs.*exp(-1j*th_VSMP);
vsd = real(vsdq);
vsq = imag(vsdq);
iGSCdq = ig.*exp(-1j*th_VSMP);
iGSCd = real(iGSCdq);
iGSCq = imag(iGSCdq);
iGSCd_ref = sqrt(3)*Qg_ref./Vs;
iGSCq_ref = iGSCq;
Pg_ref = Vs.*iGSCq/sqrt(3);
vGSCdq = vg.*exp(-1j*th_VSMP);
vGSCd = real(vGSCdq);
vGSCq = imag(vGSCdq);
I_igd = -vGSCd + vsd + iGSCq.*1.*Lfg_pu - Kp_igd.*(b_igd.*iGSCd_ref - iGSCd);
I_igq = -vGSCq + vsq - iGSCd.*1.*Lfg_pu - Kp_igq.*(b_igq.*iGSCq_ref - iGSCq);
%--------------------------------------------------------------------------
% VDC
%--------------------------------------------------------------------------
Vdc2_ref = Vdc_ref.^2;
Vdc2 = Vdc2_ref;
Vdc = sqrt(Vdc2);
I_vdc = Pg_ref - Kp_vdc.*(b_vdc.*Vdc2_ref - Vdc2);
%--------------------------------------------------------------------------
%% CHECK NULL DERIVATIVES
%--------------------------------------------------------------------------
% DFIG
%--------------------------------------------------------------------------
% DFIG_state = [
%     real(Fst) ; imag(Fst) ; real(Fr) ; imag(Fr) ; ...
%     wr ; Vdc ; real(Fgt) ; imag(Fgt) ; wt ; Ttg];
Pdc = P_GSC - P_RSC;
dFst = w0*(vp - Rt_pu.*ig - (Rt_pu + Rs_pu).*is - 1j.*w.*Fst);
dFr = w0*(vr - Rr_pu.*ir - 1j.*(w - wr).*Fr);
dwr = (1/2)./Hg_pu.*(Ttg + Te - Dg_pu.*wr + Dtg_pu.*(wt-wr));
dVdc = w0*idc./Cdc_pu;
dFgt = w0*(vp - vg - Rt_pu.*is - (Rt_pu + Rfg_pu).*ig - 1j*w.*Fgt);
dwt = (1/2)./Ht_pu.*(Tm - Dt_pu.*wt - Ttg - Dtg_pu.*(wt-wr));
dTtg = w0*Ktg_pu.*(wt-wr);
dxDFIG = [dFst ; dFr ; dwr ; dVdc ; dFgt ; dTtg];
%--------------------------------------------------------------------------
% GRID
%--------------------------------------------------------------------------
% di = w0*(1/Lg_pu*(vp - vgrid - Rg_pu*iline) - 1j*w*iline);
% dvp = w0*(1/Cn1_pu*(sum(it) - vp/Rn1_pu -il1 - iline) - 1j*w*vp);
dxsg = 1/Tgov*(-xsg + Pm_grid_ref + 0.5*Deq_pu*(1-w));
dxt1 = xt2;
dxt2 = 1/Ttb1/Ttb2.*(-(Ttb1+Ttb2)*xt2 - xt1 + xsg);
dw = 1/2/Hgrid.*(Pm_grid - Pgrid*MODEL.BASE.Sb/MODEL.GRID.BASE.Sb + 0.5*Deq_pu*(1-w));
dxGRID = [dxsg ; dxt1 ; dxt2 ; dw];
%--------------------------------------------------------------------------
% LINE
%--------------------------------------------------------------------------
diline = w0.*(1./Lg_pu.*(vp - vgrid - Rg_pu.*iline) - 1j*w*iline);
dvp = w0.*(1./Cn1_pu.*(sum(it) - iline - il1 - vp./Rn1_pu) - 1j*w.*vp);
dxLINE = [real(diline) ; imag(diline) ; real(dvp) ; imag(dvp)];
%--------------------------------------------------------------------------
% CONTROL
%--------------------------------------------------------------------------
dx_VSMP = 1./(2*H).*(P_ref - P - Dp.*(w_VSMP_pu - 1));
dth_VSMP = w0*(w_VSMP_pu - w);
dFs_ref = w0*K_Fs_ref.*(K_droopQV.*(Vs_ref-Vs) + Q_ref - Q);
dI_ird = Ki_ird.*(iRSCd_ref - iRSCd);
dI_irq = Ki_irq.*(iRSCq_ref - iRSCq);
dI_vdc = Ki_vdc.*(Vdc2_ref - Vdc2);
dI_igd = Ki_igd.*(iGSCd_ref - iGSCd);
dI_igq = Ki_igq.*(iGSCq_ref - iGSCq);
dxCONTROL = [dx_VSMP ; dth_VSMP ; dFs_ref ; dI_ird ; dI_irq ; dI_vdc ; dI_igd ; dI_igq];
%--------------------------------------------------------------------------

%--------------------------------------------------------------
%% OPERATING POINT INITIALZATION
%--------------------------------------------------------------
%--------------------------------------------------------------
% DFIG STATE
%--------------------------------------------------------------
% STATE = {
% 'STATOR-TRAFO FLUX REAL'
% 'STATOR-TRAFO FLUX IMAG'
% 'ROTOR FLUX REAL'
% 'ROTOR FLUX IMAG'
% 'ROTOR SPEED'
% 'DC VOLTAGE'
% 'GSC-TRAFO FLUX REAL'
% 'GSC-TRAFO FLUX IMAG'
% 'TURBINE SPEED'
% 'SHAFT TORQUE'}
MODEL.DFIG.STATE = [
    real(Fst) ; imag(Fst) ; real(Fr) ; imag(Fr) ; ...
    wr ; Vdc ; real(Fgt) ; imag(Fgt) ; wt ; Ttg];
%--------------------------------------------------------------
% LINE STATE
%--------------------------------------------------------------
% STATE = {
% 'LINE CURRENT REAL'
% 'LINE CURRENT IMAG'
% 'NODE 1 VOLTAGE REAL'
% 'NODE 1 VOLTAGE IMAG'
% 'NODE 2 VOLTAGE REAL'
% 'NODE 2 VOLTAGE IMAG'}
MODEL.LINE.STATE = [
    real(iline) ; imag(iline) ; real(vp) ; imag(vp) ; real(vgrid) ; imag(vgrid)];
%--------------------------------------------------------------
% GRID STATE
%--------------------------------------------------------------
% STATE = {
% 'SPEED GOVERNOR STATE'
% 'TURBINE STATE 1'
% 'TURBINE STATE 2'
% 'GRID FREQUENCY'}
MODEL.GRID.STATE = [xsg ; xt1 ; xt2 ; w];
%--------------------------------------------------------------
% CONTROL STATE
%--------------------------------------------------------------
CONTROL.VSMP.STATE = [x_VSMP ; th_VSMP];
CONTROL.VSMQ.STATE = Fs_ref;
CONTROL.RSCd.STATE = I_ird;
CONTROL.RSCq.STATE = I_irq;
CONTROL.VDC.STATE = I_vdc;
CONTROL.GSCd.STATE = I_igd;
CONTROL.GSCq.STATE = I_igq;
%--------------------------------------------------------------
% CONTROL BUS
%--------------------------------------------------------------
CONTROL.VSMP.TARGET.P_ref = P_ref;
CONTROL.VSMQ.TARGET.Vs_ref = Vs_ref;
CONTROL.VSMQ.TARGET.Q_ref = Q_ref;
CONTROL.VDC.TARGET.Vdc2_ref = Vdc2_ref;
CONTROL.GSCd.TARGET.Qg_ref = Qg_ref;
CONTROL.VSMP.INPUT.P = P;
CONTROL.VSMQ.INPUT.Q = Q;
CONTROL.VSMQ.INPUT.Vs = Vs;
CONTROL.VDC.INPUT.Vdc2 = Vdc2;
CONTROL.RSCd.TARGET.iRSCd_ref = iRSCd_ref;
CONTROL.RSCq.TARGET.iRSCq_ref = iRSCq_ref;
CONTROL.RSCd.INPUT.iRSCd = iRSCd;
CONTROL.RSCq.INPUT.iRSCq = iRSCq;
CONTROL.GSCd.TARGET.iGSCd_ref = iGSCd_ref;
CONTROL.GSCq.TARGET.iGSCq_ref = iGSCq_ref;
CONTROL.GSCd.INPUT.iGSCd = iGSCd;
CONTROL.GSCq.INPUT.iGSCq = iGSCq;
CONTROL.VSMP.OUTPUT.w_pu = w_VSMP_pu;
CONTROL.VSMP.OUTPUT.th = th_VSMP;
CONTROL.VSMP.OUTPUT.MV = Dp.*w_VSMP_pu;
CONTROL.VSMQ.OUTPUT.Fs_ref = Fs_ref;
CONTROL.VSMQ.OUTPUT.MV = zeros(1,nDFIG);
CONTROL.RSCd.OUTPUT.vRSCd = real(vRSCdq);
CONTROL.RSCq.OUTPUT.vRSCq = imag(vRSCdq);
CONTROL.RSCd.OUTPUT.MV = I_ird;
CONTROL.RSCq.OUTPUT.MV = I_irq;
CONTROL.VDC.OUTPUT.Pg_ref = Pg_ref;
CONTROL.VDC.OUTPUT.MV = Pg_ref;
CONTROL.GSCd.OUTPUT.vGSCd = vGSCd;
CONTROL.GSCq.OUTPUT.vGSCq = vGSCq;
CONTROL.GSCd.OUTPUT.MV = I_igd;
CONTROL.GSCq.OUTPUT.MV = I_igq;
%--------------------------------------------------------------
% DFIG BUS
%--------------------------------------------------------------
MODEL.DFIG.INPUT.windSpeed = windSpeed;
MODEL.DFIG.INPUT.turbinePitch = pitch;
MODEL.DFIG.INPUT.vPCC_r = real(vp)*ones(1,nDFIG);
MODEL.DFIG.INPUT.vPCC_i = imag(vp)*ones(1,nDFIG);
MODEL.DFIG.INPUT.vRSC_r = real(vr);
MODEL.DFIG.INPUT.vRSC_i = imag(vr);
MODEL.DFIG.INPUT.vGSC_r = real(vg);
MODEL.DFIG.INPUT.vGSC_i = imag(vg);
MODEL.DFIG.OUTPUT.vs_r = real(vs);
MODEL.DFIG.OUTPUT.vs_i = imag(vs);
MODEL.DFIG.OUTPUT.is_r = real(is);
MODEL.DFIG.OUTPUT.is_i = imag(is);
MODEL.DFIG.OUTPUT.ir_r = real(ir);
MODEL.DFIG.OUTPUT.ir_i = imag(ir);
MODEL.DFIG.OUTPUT.ig_r =  real(ig);
MODEL.DFIG.OUTPUT.ig_i =  imag(ig);
MODEL.DFIG.OUTPUT.it_r = real(it);
MODEL.DFIG.OUTPUT.it_i = imag(it);
MODEL.DFIG.OUTPUT.Vdc = Vdc;
MODEL.DFIG.OUTPUT.P_GSC = P_GSC;
MODEL.DFIG.OUTPUT.P_RSC = P_RSC;
MODEL.DFIG.OUTPUT.Pdc = Pdc;
MODEL.DFIG.OUTPUT.wr = wr;
MODEL.DFIG.OUTPUT.Pm = Pm;
%--------------------------------------------------------------
% LINE BUS
%--------------------------------------------------------------
MODEL.LINE.INPUT.il1_r = real(il1);
MODEL.LINE.INPUT.il1_i = imag(il1);
MODEL.LINE.INPUT.il2_r = real(il2);
MODEL.LINE.INPUT.il2_i = imag(il2);
MODEL.LINE.INPUT.in1_r = real(sum(it));
MODEL.LINE.INPUT.in1_i = imag(sum(it));
MODEL.LINE.INPUT.in2_r = real(iline);
MODEL.LINE.INPUT.in2_i = imag(iline);
MODEL.LINE.OUTPUT.vn1_r = real(vp);
MODEL.LINE.OUTPUT.vn1_i = imag(vp);
MODEL.LINE.OUTPUT.Vpcc = abs(vp);
MODEL.LINE.OUTPUT.vn2_r = real(vgrid);
MODEL.LINE.OUTPUT.vn2_i = imag(vgrid);
MODEL.LINE.OUTPUT.i_r = real(iline);
MODEL.LINE.OUTPUT.i_i = imag(iline);
%--------------------------------------------------------------
% GRID BUS
%--------------------------------------------------------------
MODEL.GRID.INPUT.v_grid_r = real(vgrid);
MODEL.GRID.INPUT.v_grid_i = imag(vgrid);
MODEL.GRID.INPUT.Pg_ref = Pm_grid_ref;
MODEL.GRID.OUTPUT.f_pu = w;
MODEL.GRID.OUTPUT.Pmech = Pm_grid;
MODEL.GRID.OUTPUT.Pgrid = Pgrid*MODEL.BASE.Sb/MODEL.GRID.BASE.Sb;
MODEL.GRID.OUTPUT.Qgrid = Qgrid*MODEL.BASE.Sb/MODEL.GRID.BASE.Sb;

%--------------------------------------------------------------
%% OPERATING POINT COMPUTATION
%--------------------------------------------------------------
% Model definition
%--------------------------------------------------------------
LIN_MODEL.MODEL = MODEL;
LIN_MODEL.CONTROL = CONTROL;
cd('../SIMULINK');
model.name = LIN_MODEL.modelName;
if workerID
    model.name = [model.name '_' num2str(workerID)];
end
open_system(model.name,'loadonly')
model.workspace = get_param(model.name,'modelworkspace');
initialMemoryState = [real(it(:)) ; imag(it(:)) ; real(is(:)) ; imag(is(:)) ; ...
                      real(ir(:)) ; imag(ir(:)) ; real(vs(:)) ; imag(vs(:)) ; ...
                      Vdc(:) ; wr(:)];
assignin(model.workspace,'initialMemoryState',initialMemoryState);
assignin(model.workspace,'MODEL_INI',MODEL);
assignin(model.workspace,'CONTROL_INI',CONTROL);
%--------------------------------------------------------------
% Create or reuse operating point specification
%--------------------------------------------------------------
% Ensure base workspace has all variables needed by Simulink model compilation
% (parallel workers start with empty base workspace)
if ~evalin('base', 'exist(''breaker_ts'',''var'')')
    bt.time = [0; 100];
    bt.signals.values = ones(1, nDFIG, 2);
    bt.signals.dimensions = [1, nDFIG];
    assignin('base', 'breaker_ts', bt);
end
if ~evalin('base', 'exist(''MODEL_Bus'',''var'')')
    BusDefinition(MODEL, 'MODEL_Bus');
    BusDefinition(CONTROL, 'CONTROL_Bus');
end
% Use persistent variable to cache opspecModel across function calls
% Only recreate if model name or number of DFIGs changes
persistent opspecModel_cached modelName_cached nDFIG_cached
if isempty(opspecModel_cached) || ...
   ~strcmp(modelName_cached, LIN_MODEL.modelName) || ...
   nDFIG_cached ~= nDFIG
    opspecModel_cached = operspec(model.name);
    modelName_cached = LIN_MODEL.modelName;
    nDFIG_cached = nDFIG;
end
opspecModel = opspecModel_cached;
%--------------------------------------------------------------
% Specifications
%--------------------------------------------------------------
% Matrices sorted by columns
% Perturbation for control analysis
opspecModel.Inputs(1).u = zeros(7*nDFIG,1); 
opspecModel.Inputs(1).Known = ones(7*nDFIG,1); 
opspecModel.Inputs(1).Min = -inf*ones(7*nDFIG,1); 
opspecModel.Inputs(1).Max = inf*ones(7*nDFIG,1); 
% VSMP P_ref
opspecModel.Inputs(2).u = zeros(nDFIG,1); 
opspecModel.Inputs(2).Known = ones(nDFIG,1); 
opspecModel.Inputs(2).Min = -inf*ones(nDFIG,1); 
opspecModel.Inputs(2).Max =  inf*ones(nDFIG,1); 
% VSMQ Q_ref
opspecModel.Inputs(3).u = zeros(nDFIG,1); 
opspecModel.Inputs(3).Known = ones(nDFIG,1); 
opspecModel.Inputs(3).Min = -inf*ones(nDFIG,1); 
opspecModel.Inputs(3).Max =  inf*ones(nDFIG,1); 
% Active load
opspecModel.Inputs(4).u = zeros(nLINE,1); 
opspecModel.Inputs(4).Known = ones(nLINE,1); 
opspecModel.Inputs(4).Min = -inf*ones(nLINE,1); 
opspecModel.Inputs(4).Max =  inf*ones(nLINE,1); 
% Reactive load
opspecModel.Inputs(5).u = zeros(nLINE,1);
opspecModel.Inputs(5).Known = ones(nLINE,1);
opspecModel.Inputs(5).Min = -inf*ones(nLINE,1);
opspecModel.Inputs(5).Max =  inf*ones(nLINE,1);
% Wind speed perturbation (vw_delta) — one per DFIG [m/s]
% Only configure if the Simulink model has a 6th Inport. The shipped
% POWER_SYSTEM_FULL.slx already has it (vw_delta); the one-time script that
% added it is not included, since re-running it would duplicate the port.
if numel(opspecModel.Inputs) >= 6
    opspecModel.Inputs(6).u = zeros(nDFIG,1);
    opspecModel.Inputs(6).Known = ones(nDFIG,1);
    opspecModel.Inputs(6).Min = -inf*ones(nDFIG,1);
    opspecModel.Inputs(6).Max =  inf*ones(nDFIG,1);
end
% DFIG control state
controlStateMatrix = [
    CONTROL.VSMP.STATE 
    CONTROL.VSMQ.STATE
    CONTROL.RSCd.STATE
    CONTROL.RSCq.STATE
    CONTROL.VDC.STATE
    CONTROL.GSCd.STATE
    CONTROL.GSCq.STATE];
opspecModel.States(1).x = controlStateMatrix(:); 
opspecModel.States(1).Known = ones(8*nDFIG,1); 
opspecModel.States(1).Min = -inf*ones(8*nDFIG,1); 
opspecModel.States(1).Max =  inf*ones(8*nDFIG,1); 
% DFIG state
opspecModel.States(2).x = MODEL.DFIG.STATE(:); 
opspecModel.States(2).Known = ones(10*nDFIG,1); 
opspecModel.States(2).Min = -inf*ones(10*nDFIG,1); 
opspecModel.States(2).Max =  inf*ones(10*nDFIG,1); 
% GRID state
if strcmp(LIN_MODEL.modelName(end-3:end),'FULL')
    gridStateMatrix = [   
        MODEL.GRID.STATE
        MODEL.LINE.STATE(1:4,:)];
else
    gridStateMatrix = MODEL.GRID.STATE;
end
opspecModel.States(3).x = gridStateMatrix(:); 
opspecModel.States(3).Known = 0*ones(size(gridStateMatrix,1),1); 
opspecModel.States(3).Min = -inf*ones(size(gridStateMatrix,1),1); 
opspecModel.States(3).Max = inf*ones(size(gridStateMatrix,1),1); 
%--------------------------------------------------------------
% Options
%--------------------------------------------------------------
opts = findopOptions;
% Algorithm: 'active-set'
% AlwaysHonorConstraints: 'bounds'
% BarrierParamUpdate: 'monotone'
% DerivativeCheck: 'off'
% Diagnostics: 'off'
% DiffMaxChange: Inf
% DiffMinChange: 0
% Display: 'off'
% EnableFeasibilityMode: 0
% FinDiffRelStep: []
% FinDiffType: 'forward'
% FunValCheck: 'off'
% FunctionEvaluationCounter: []
% GradConstr: 'off'
% GradObj: 'off'
% HessFcn: []
% Hessian: []
% HessMult: []
% HessPattern: 'sparse(ones(numberOfVariables))'
% InitBarrierParam: 0.1
% InitTrustRegionRadius: 'sqrt(numberOfVariables)'
% MaxFunEvals: 10000
% MaxIter: 2000
% MaxPCGIter: []
% MaxProjCGIter: '2*(numberOfVariables-numberOfEqualities)'
% MaxSQPIter: '10*max(numberOfVariables,numberOfInequalities+numberOfBounds)'
% ObjectiveLimit: -1e+20
% OutputFcn: []
% PlotFcns: []
% PrecondBandWidth: 0
% RelLineSrchBnd: []
% RelLineSrchBndDuration: 1
% ScaleProblem: 'none'
% SubproblemAlgorithm: 'ldl-factorization'
% TolCon: 1e-06
% TolConSQP: 1e-06
% TolFun: 1e-06
% TolFunValue: 1e-06
% TolPCG: 0.1
% TolProjCG: 0.01
% TolProjCGAbs: 1e-10
% TolX: 1e-06
% TypicalX: 'ones(numberOfVariables,1)'
% UseParallel: 0
% Jacobian: 'off'
% LargeScale: 'off'
opts.DisplayReport = 'off';
opts.OptimizationOptions.MaxIter = 0;
opts.OptimizationOptions.MaxFunEvals = 0;
%--------------------------------------------------------------
% Operating point
%--------------------------------------------------------------
[opModel,opReportModel] = findop(model.name,opspecModel,opts);
%--------------------------------------------------------------
% OP QUALITY CHECK AND REFINEMENT
%--------------------------------------------------------------
% Evaluate state derivatives at the found operating point.
% If the analytical OP (from fsolve) is insufficiently precise for the
% Simulink model (e.g., due to large parameter changes like 3x inertia),
% re-run findop with numerical optimization to refine.
maxDxFindop = 0;
for iState = 1:numel(opReportModel.States)
    maxDxFindop = max(maxDxFindop, max(abs(opReportModel.States(iState).dx)));
end
LIN_MODEL.maxDxFindop = maxDxFindop;
LIN_MODEL.opRefined = false;

OP_DX_THRESHOLD = 10;  % Diagnostic only — settling phase handles NL initialization
if maxDxFindop > OP_DX_THRESHOLD
    % TARGETED refinement: free ONLY control states (integrators/theta).
    % Keep DFIG states fixed (preserve electrical equilibrium from fsolve)
    % and grid/line states fixed (preserve operating point V, f, P).
    % This adjusts control integrators to be consistent with Simulink
    % without shifting the intended operating point.
    opspecModel.States(1).Known = zeros(8*nDFIG,1);   % Control: FREE
    % States(2) DFIG: stays Known=1 (preserve electrical equilibrium)
    % Fix grid states too (override original Known=0)
    savedKnown3 = opspecModel.States(3).Known;
    opspecModel.States(3).Known = ones(size(savedKnown3));  % Grid: FIXED

    % Configure numerical refinement
    optsRefine = findopOptions;
    optsRefine.DisplayReport = 'off';
    optsRefine.OptimizationOptions.MaxIter = 400;
    optsRefine.OptimizationOptions.MaxFunEvals = 4000;

    % Re-run findop with control-only refinement
    [opModel,opReportModel] = findop(model.name,opspecModel,optsRefine);

    % Restore Known flags for grid states
    opspecModel.States(3).Known = savedKnown3;

    % Evaluate refined quality
    maxDxRefined = 0;
    for iState = 1:numel(opReportModel.States)
        maxDxRefined = max(maxDxRefined, max(abs(opReportModel.States(iState).dx)));
    end
    LIN_MODEL.maxDxFindopRefined = maxDxRefined;
    LIN_MODEL.opRefined = true;

    % Update CONTROL states from refined operating point
    refinedCtrl = reshape(opModel.States(1).x, 8, nDFIG);
    CONTROL.VSMP.STATE = refinedCtrl(1:2,:);
    CONTROL.VSMQ.STATE = refinedCtrl(3,:);
    CONTROL.RSCd.STATE = refinedCtrl(4,:);
    CONTROL.RSCq.STATE = refinedCtrl(5,:);
    CONTROL.VDC.STATE  = refinedCtrl(6,:);
    CONTROL.GSCd.STATE = refinedCtrl(7,:);
    CONTROL.GSCq.STATE = refinedCtrl(8,:);

    % Update LIN_MODEL buses and model workspace
    % (DFIG states unchanged — electrical equilibrium preserved)
    LIN_MODEL.CONTROL = CONTROL;
    assignin(model.workspace, 'CONTROL_INI', CONTROL);
end
%--------------------------------------------------------------
%% LINEARIZATION
%--------------------------------------------------------------
% Maximum error in fsolve (DFIG equation system)
LIN_MODEL.maxErrFsolve = max(abs(fval(:)));
% Maximum state derivative
if strcmp(LIN_MODEL.modelName(end-3:end),'FULL')
    aux = [dxCONTROL(:) ; real(dxDFIG(:)) ; imag(dxDFIG(:)) ; dxGRID(:) ; dxLINE(:)];
else
    aux = [dxCONTROL(:) ; real(dxDFIG(:)) ; imag(dxDFIG(:)) ; dxGRID(:)];
end
LIN_MODEL.maxDSTATE = max(abs(aux));
% State-space linear model
LIN_MODEL.opModel = opModel;
LIN_MODEL.oprModel = opReportModel;
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
LIN_MODEL.ssModel = linearize(model.name,opModel,linOptions);
% clear(model.workspace)
% Angle between node voltages in grid line [deg]
LIN_MODEL.lineAngle = angle(vp./vgrid)*180/pi;
% Angle between node voltages in DFIG trafos [deg]
LIN_MODEL.dfigAngles = angle(vs./vp)*180/pi;
% Wind speed
LIN_MODEL.windSpeed = windSpeed;
% DFIG rotor speed
LIN_MODEL.rotorSpeed = wr;
% Mechanical power
LIN_MODEL.turbinePower = Tm.*wt;
% DFIG power
LIN_MODEL.dfigPower = Pdfig;
% Final MODEL and CONTROL buses
LIN_MODEL.initialMemoryState = initialMemoryState;
% Eigenvalues and participations
cd('../CONFIGURATION');
[z,~,~,p] = EIGEN_CALC(LIN_MODEL.ssModel.a);
LIN_MODEL.eigenvalues = z;
LIN_MODEL.participations = p;
% Participations = [States Eigenvalues]
% Sorting states for each eigenvalue based on participations
[~,indp] = sort(abs(p),'descend');
sortedStateNames = cell(size(p));
sortedParticipations = NaN(size(p));
for nn=1:size(p,1)
    sortedStateNames(:,nn) = LIN_MODEL.stateNames(indp(:,nn));
    sortedParticipations(:,nn) = p(indp(:,nn),nn); 
end
LIN_MODEL.sortedParticipations = sortedParticipations;
LIN_MODEL.sortedStateNames = sortedStateNames;
% Stability
LIN_MODEL.stability = all(real(z)<0);
% Minimum time constant
LIN_MODEL.minTimeConstant = -1/real(z(1));
% Minimum damping
[naturalFreq,Damping] = damp(z);
[minDamping1,ind1] = min(Damping(1:4) + 1e6*(abs(Damping(1:4))==1));
[minDamping2,ind2] = min(Damping(5:end) + 1e6*(abs(Damping(5:end))==1));
LIN_MODEL.minDamping = [minDamping1 minDamping2];
LIN_MODEL.naturalFreq = [naturalFreq(ind1) naturalFreq(4+ind2)];
LIN_MODEL.stateMinDamping = [sortedStateNames(1,ind1) sortedStateNames(1,4+ind2)];
% Maximum real eigenvalue
[maxRealEig,ind3] = max(real(z) - 1e6*(abs(Damping)<1));
LIN_MODEL.maxRealEig = maxRealEig;
LIN_MODEL.stateMaxRealEig = sortedStateNames(1,ind3);

return
