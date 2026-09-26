function LIN_MODEL = CONTROL_DESIGN_FR(LIN_MODEL,flagScreenOutput,workerID)
% CONTROL_DESIGN_FR - Frequency-Response Control Design for N-DFIG Wind Farm
%
% DESCRIPTION:
%   Designs all controllers in the hierarchical control system using
%   frequency-response methodology. Calculates controller parameters (Kp, Ki,
%   Tc, Tp, H, Dd) to achieve specified phase margins (Fm) and crossover
%   frequencies (wo) for each control loop.
%
% SYNTAX:
%   LIN_MODEL = CONTROL_DESIGN_FR(LIN_MODEL)
%   LIN_MODEL = CONTROL_DESIGN_FR(LIN_MODEL, flagScreenOutput)
%   LIN_MODEL = CONTROL_DESIGN_FR(LIN_MODEL, flagScreenOutput, workerID)
%
% INPUTS:
%   LIN_MODEL         - Structure containing system model and control design data
%   flagScreenOutput  - [Optional] Display progress messages (default: true)
%   workerID          - [Optional] Worker ID for parallel computing (default: 0)
%
% OUTPUTS:
%   LIN_MODEL - Updated structure with designed controller parameters in:
%               LIN_MODEL.CONTROL.VSMP.PARAM (H, Dd, Dp)
%               LIN_MODEL.CONTROL.VSMQ.PARAM (K_Fs_ref)
%               LIN_MODEL.CONTROL.RSCd/RSCq.PARAM (Kp, Ki)
%               LIN_MODEL.CONTROL.VDC.PARAM (Kp, Ki)
%               LIN_MODEL.CONTROL.GSCd/GSCq.PARAM (Kp, Ki)
%
% DESIGN SPECIFICATIONS:
%   All design specifications are defined in CONFIG_POWER_SYSTEM.m as FRD_SPECS
%   and copied to LIN_MODEL.CONTROL_DESIGN.*.frdSpecs:
%
%   - VSMP: Fm (phase margin), wo (crossover frequency) [deg, rad/s]
%   - VSMQ: wo (crossover frequency) [rad/s]
%   - RSC:  Fm, wo for d-axis and q-axis independently [deg, rad/s]
%   - VDC:  Fm, wo [deg, rad/s]
%   - GSC:  Fm, wo for d-axis and q-axis independently [deg, rad/s]
%
% FREQUENCY-RESPONSE DESIGN METHODOLOGY:
%   The frequency-response design method shapes the open-loop frequency
%   response to achieve desired stability margins. For each control loop:
%
%   1. Linearize the system around the operating point
%   2. Extract plant transfer function Pss from linearization
%   3. Design controller Css to meet Fm and wo specifications:
%      - Phase margin (Fm): Safety margin before instability [deg]
%      - Crossover frequency (wo): Speed of response [rad/s]
%   4. Verify closed-loop stability and performance
%
% CONTROLLER TYPES:
%   - PI Controller:  C(s) = Kp + Ki/s
%                     Used for: RSC, VDC, GSC (fast current/voltage loops)
%   - RF Controller:  C(s) = (1 + Tc*s)/(1 + Tp*s)
%                     Used for: VSMP (power-frequency droop with dynamics)
%   - P Controller:   C(s) = Kp
%                     Used for: VSMQ (reactive power-voltage droop)
%
% DESIGN ALGORITHM:
%   For each controller in designOrder sequence:
%     1. Read specifications (Fm, wo) from LIN_MODEL.CONTROL_DESIGN
%     2. Extract plant model Pss from linearization
%     3. Call appropriate design function (designPI, designRF, designP)
%     4. Calculate controller parameters to meet specifications
%     5. Update LIN_MODEL.CONTROL structure with new parameters
%     6. Relinearize system with updated controller
%     7. Calculate and verify stability margins
%
% HELPER FUNCTIONS:
%   designPI(Pss, Fm, wo)     - PI controller design for current/voltage loops
%   designRF(Pss, Fm, wo)     - Real-pole/zero controller for VSMP dynamics
%   designP(Pss, wo)          - Proportional controller for VSMQ droop
%   update_structs(LIN_MODEL) - Relinearization and stability margin calculation
%
% DESIGN ORDER:
%   The design sequence is specified in LIN_MODEL.CONTROL_DESIGN.designOrder
%   Typical sequence: [1 2 3 4 5 6 7] corresponding to:
%     1-VSMP, 2-VSMQ, 3-RSCd, 4-RSCq, 5-VDC, 6-GSCd, 7-GSCq
%
% STABILITY MARGINS:
%   After each design iteration, the function calculates:
%   - Phase margin (Fm): Phase at crossover frequency wo [deg]
%   - Gain margin (AmdB): Gain at phase crossover frequency wu [dB]
%   - Crossover frequency (wo): |G(jwo)| = 1 [rad/s]
%   - Phase crossover (wu): angle(G(jwu)) = -180° [rad/s]
%
% VECTORIAL PARAMETRIZATION (N-DFIG SCALABILITY):
%   Controller parameters are broadcast to all DFIGs using ones(1,nDFIG):
%   - Design is performed for selectedDFIG (typically DFIG #1)
%   - Parameters are replicated to all nDFIG units
%   - Enables N-DFIG scalability without code modifications
%
% ARCHITECTURE INTEGRATION:
%   CONFIG_POWER_SYSTEM.m → FRD_SPECS → LIN_MODEL.CONTROL_DESIGN.*.frdSpecs
%                                     ↓
%                           CONTROL_DESIGN_FR.m (this file)
%                                     ↓
%                           LIN_MODEL.CONTROL.*.PARAM → Simulink model
%
% CRITICAL COMPATIBILITY WARNING:
%   DO NOT modify controller parameter assignments or design algorithms.
%   Changes affect published papers and Simulink model compatibility.
%   The MATLAB data structure ↔ Simulink bus structure must remain aligned.
%
% EXECUTION TIME:
%   Typical execution: ~3-5 seconds per design iteration
%   Bottleneck: LINEAR_ANALYSIS (~80-90% of time) - necessary for stability
%
% RELATED FILES:
%   - CONFIG_POWER_SYSTEM.m: Defines FRD_SPECS (phase margins, crossovers)
%   - CONFIG_CONTROL.m: Initializes CONTROL structure with default values
%   - CONTROL_DESIGN_TR.m: Alternative time-response design methodology
%   - LINEAR_ANALYSIS.m: System linearization and eigenvalue analysis
%   - LINEARIZE.m: Operating point linearization
%
% SEE ALSO:
%   CONTROL_DESIGN_TR, CONFIG_CONTROL, LINEAR_ANALYSIS, LINEARIZE
%
% DATE: 2025-01-15 (Documentation enhanced)
% PROJECT: DFIG-Based Wind Farm Power System Analysis

if nargin==1
    flagScreenOutput = true;
    workerID = 0;
elseif nargin==2
    workerID = 0;
else
end
format compact
LIN_MODEL.controlDesignMethod = 'Frequency response';

%--------------------------------------------------------------------------
%% INITIALIZATION
%--------------------------------------------------------------------------
% Extract number of DFIGs from system model
nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;

% Define Laplace variable for transfer function calculations
s = tf('s');

% Initial linearization and stability margin calculation
if flagScreenOutput
    disp('Initializing ...')
end
LIN_MODEL = update_structs(LIN_MODEL,workerID);

%--------------------------------------------------------------------------
%% SEQUENTIAL CONTROL DESIGN LOOP
%--------------------------------------------------------------------------
% Design controllers in specified order (typically: VSMP, VSMQ, RSC, VDC, GSC)
% Each iteration: backup 2-DOF → force 1-DOF → linearize → extract plant →
%                 design controller → restore 2-DOF → update parameters
for controlID = LIN_MODEL.CONTROL_DESIGN.designOrder

    %----------------------------------------------------------------------
    % STEP 1: BACKUP 2-DOF parameters for controller being designed
    %----------------------------------------------------------------------
    % Initialize backup variables (case 2 VSMQ doesn't need backup)
    der2error_saved = 1;
    b_saved = 1;

    selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
    switch controlID
        case 1  % VSMP - backup der2error parameter
            if isfield(LIN_MODEL.CONTROL.VSMP.PARAM, 'der2error') && ...
               ~isempty(LIN_MODEL.CONTROL.VSMP.PARAM.der2error)
                der2error_saved = LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG);
            end
        case {3, 4, 5, 6, 7}  % Controllers with b parameter
            ctrl_names = {'', '', 'RSCd', 'RSCq', 'VDC', 'GSCd', 'GSCq'};
            ctrl_name = ctrl_names{controlID};
            if isfield(LIN_MODEL.CONTROL.(ctrl_name).PARAM, 'b') && ...
               ~isempty(LIN_MODEL.CONTROL.(ctrl_name).PARAM.b)
                b_saved = LIN_MODEL.CONTROL.(ctrl_name).PARAM.b(selectedDFIG);
            end
    end

    %----------------------------------------------------------------------
    % STEP 2: FORCE 1-DOF for selectedDFIG only (preserve other DFIGs)
    %----------------------------------------------------------------------
    % During design, only the DFIG being designed needs 1-DOF control for
    % correct plant extraction. Other DFIGs preserve their 2-DOF parameters.
    % After design, STEP 5 broadcasts the final parameters to all DFIGs.
    switch controlID
        case 1  % VSMP
            LIN_MODEL.CONTROL.VSMP.PARAM.der2error(selectedDFIG) = 1;
        case {3, 4, 5, 6, 7}  % Controllers with b parameter
            LIN_MODEL.CONTROL.(ctrl_name).PARAM.b(selectedDFIG) = 1;
    end

    %----------------------------------------------------------------------
    % STEP 3: RE-LINEARIZE with this controller in 1-DOF
    %----------------------------------------------------------------------
    LIN_MODEL = update_structs(LIN_MODEL,workerID);

    %----------------------------------------------------------------------
    % STEP 4: DESIGN controller using frequency-response method
    %----------------------------------------------------------------------
    switch controlID
        %--------------------------------------------------------------------------
        case 1 % VSMP - Virtual Synchronous Machine (Active Power Control)
        %--------------------------------------------------------------------------
            if flagScreenOutput
                disp('Designing VSMP ...')
            end
            % Read frequency-response specifications from CONFIG_POWER_SYSTEM.m
            Fm = LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.Fm;  % Phase margin [deg]
            wo = LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.wo;  % Crossover frequency [rad/s]

            % Extract plant transfer function from linearization
            Pss = LIN_MODEL.CONTROL_DESIGN.VSMP.frdDesignPss;

            % Design RF controller: C(s) = (1+Tc*s)/(1+Tp*s)
            [Tc,Tp,Css,Gss,Fss] = designRF(Pss,Fm,wo);

            % Retrieve steady-state damping coefficient (power-frequency droop)
            Dp = LIN_MODEL.CONTROL.VSMP.PARAM.Dp(LIN_MODEL.CONTROL_DESIGN.selectedDFIG);

            % Store design parameters
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdParam.Dp = Dp;
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdParam.Dd = Tc;  % Transient damping [s]
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdParam.H = Dp*Tp/2;  % Inertia constant [s]
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdParam.der2error = 1;
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdCss = Css;
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdDesignGss = Gss;
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdDesignFss = Fss;

            % Update control parameters (broadcast to all DFIGs - all DFIGs are identical)
            LIN_MODEL.CONTROL.VSMP.PARAM.H = Dp*Tp/2*ones(1,nDFIG);
            LIN_MODEL.CONTROL.VSMP.PARAM.Dd = Tc*ones(1,nDFIG);
        %--------------------------------------------------------------------------
        case 2 % VSMQ - Virtual Synchronous Machine (Reactive Power/Voltage Control)
        %--------------------------------------------------------------------------
            if flagScreenOutput
                disp('Designing VSMQ ...')
            end
            % Read frequency-response specifications from CONFIG_POWER_SYSTEM.m
            wo = LIN_MODEL.CONTROL_DESIGN.VSMQ.frdSpecs.wo;  % Crossover frequency [rad/s]

            % Extract plant transfer function from linearization
            Pss = LIN_MODEL.CONTROL_DESIGN.VSMQ.frdDesignPss;

            % Design proportional controller: C(s) = Kp (Q-V droop gain)
            [Kp,Css,Gss,Fss] = designP(Pss,wo);

            % Store design parameters
            LIN_MODEL.CONTROL_DESIGN.VSMQ.frdParam.Kp = Kp;
            LIN_MODEL.CONTROL_DESIGN.VSMQ.frdCss = Css;
            LIN_MODEL.CONTROL_DESIGN.VSMQ.frdDesignGss = Gss;
            LIN_MODEL.CONTROL_DESIGN.VSMQ.frdDesignFss = Fss;

            % Update control parameters (broadcast to all DFIGs - all DFIGs are identical)
            LIN_MODEL.CONTROL.VSMQ.PARAM.K_Fs_ref = Kp*ones(1,nDFIG);
        %--------------------------------------------------------------------------
        case 3 % RSCd - Rotor Side Converter (d-axis Current Control)
        %--------------------------------------------------------------------------
            if flagScreenOutput
                disp('Designing RSCd ...')
            end
            % Read frequency-response specifications from CONFIG_POWER_SYSTEM.m
            Fm = LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.Fm(1);  % Phase margin [deg]
            wo = LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.wo(1);  % Crossover frequency [rad/s]

            % Extract plant transfer function from linearization
            Pss = LIN_MODEL.CONTROL_DESIGN.RSC.frdDesignPss(1);

            % Design PI controller: C(s) = Kp + Ki/s
            [Kp,Ki,Css,Gss,Fss] = designPI(Pss,Fm,wo);

            % Store design parameters
            LIN_MODEL.CONTROL_DESIGN.RSC.frdParam.Kp(1) = Kp;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdParam.Ki(1) = Ki;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdParam.b(1) = 1;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdCss{1} = Css;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdDesignGss{1} = Gss;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdDesignFss{1} = Fss;

            % Update control parameters (broadcast to all DFIGs - all DFIGs are identical)
            LIN_MODEL.CONTROL.RSCd.PARAM.Kp = Kp*ones(1,nDFIG);
            LIN_MODEL.CONTROL.RSCd.PARAM.Ki = Ki*ones(1,nDFIG);
        %--------------------------------------------------------------------------
        case 4 % RSCq - Rotor Side Converter (q-axis Current Control)
        %--------------------------------------------------------------------------
            if flagScreenOutput
                disp('Designing RSCq ...')
            end
            % Read frequency-response specifications from CONFIG_POWER_SYSTEM.m
            Fm = LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.Fm(2);  % Phase margin [deg]
            wo = LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.wo(2);  % Crossover frequency [rad/s]

            % Extract plant transfer function from linearization
            Pss = LIN_MODEL.CONTROL_DESIGN.RSC.frdDesignPss(2);

            % Design PI controller: C(s) = Kp + Ki/s
            [Kp,Ki,Css,Gss,Fss] = designPI(Pss,Fm,wo);

            % Store design parameters
            LIN_MODEL.CONTROL_DESIGN.RSC.frdParam.Kp(2) = Kp;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdParam.Ki(2) = Ki;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdParam.b(2) = 1;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdCss{2} = Css;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdDesignGss{2} = Gss;
            LIN_MODEL.CONTROL_DESIGN.RSC.frdDesignFss{2} = Fss;

            % Update control parameters (broadcast to all DFIGs - all DFIGs are identical)
            LIN_MODEL.CONTROL.RSCq.PARAM.Kp = Kp*ones(1,nDFIG);
            LIN_MODEL.CONTROL.RSCq.PARAM.Ki = Ki*ones(1,nDFIG);
        %--------------------------------------------------------------------------
        case 5 % VDC - DC-Bus Voltage Control
        %--------------------------------------------------------------------------
            if flagScreenOutput
                disp('Designing VDC ...')
            end
            % Read frequency-response specifications from CONFIG_POWER_SYSTEM.m
            Fm = LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.Fm;  % Phase margin [deg]
            wo = LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.wo;  % Crossover frequency [rad/s]

            % Extract plant transfer function from linearization
            Pss = LIN_MODEL.CONTROL_DESIGN.VDC.frdDesignPss;

            % Design PI controller: C(s) = Kp + Ki/s
            [Kp,Ki,Css,Gss,Fss] = designPI(Pss,Fm,wo);

            % Store design parameters
            LIN_MODEL.CONTROL_DESIGN.VDC.frdParam.Kp = Kp;
            LIN_MODEL.CONTROL_DESIGN.VDC.frdParam.Ki = Ki;
            LIN_MODEL.CONTROL_DESIGN.VDC.frdParam.b = 1;
            LIN_MODEL.CONTROL_DESIGN.VDC.frdCss = Css;
            LIN_MODEL.CONTROL_DESIGN.VDC.frdDesignGss = Gss;
            LIN_MODEL.CONTROL_DESIGN.VDC.frdDesignFss = Fss;

            % Update control parameters (broadcast to all DFIGs - all DFIGs are identical)
            LIN_MODEL.CONTROL.VDC.PARAM.Kp = Kp*ones(1,nDFIG);
            LIN_MODEL.CONTROL.VDC.PARAM.Ki = Ki*ones(1,nDFIG);
        %--------------------------------------------------------------------------
        case 6 % GSCd - Grid Side Converter (d-axis Current Control)
        %--------------------------------------------------------------------------
            if flagScreenOutput
                disp('Designing GSCd ...')
            end
            % Read frequency-response specifications from CONFIG_POWER_SYSTEM.m
            Fm = LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.Fm(1);  % Phase margin [deg]
            wo = LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.wo(1);  % Crossover frequency [rad/s]

            % Extract plant transfer function from linearization
            Pss = LIN_MODEL.CONTROL_DESIGN.GSC.frdDesignPss(1);

            % Design PI controller: C(s) = Kp + Ki/s
            [Kp,Ki,Css,Gss,Fss] = designPI(Pss,Fm,wo);

            % Store design parameters
            LIN_MODEL.CONTROL_DESIGN.GSC.frdParam.Kp(1) = Kp;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdParam.Ki(1) = Ki;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdParam.b(1) = 1;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdCss{1} = Css;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdDesignGss{1} = Gss;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdDesignFss{1} = Fss;

            % Update control parameters (broadcast to all DFIGs - all DFIGs are identical)
            LIN_MODEL.CONTROL.GSCd.PARAM.Kp = Kp*ones(1,nDFIG);
            LIN_MODEL.CONTROL.GSCd.PARAM.Ki = Ki*ones(1,nDFIG);
        %--------------------------------------------------------------------------
        case 7 % GSCq - Grid Side Converter (q-axis Current Control)
        %--------------------------------------------------------------------------
            if flagScreenOutput
                disp('Designing GSCq ...')
            end
            % Read frequency-response specifications from CONFIG_POWER_SYSTEM.m
            Fm = LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.Fm(2);  % Phase margin [deg]
            wo = LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.wo(2);  % Crossover frequency [rad/s]

            % Extract plant transfer function from linearization
            Pss = LIN_MODEL.CONTROL_DESIGN.GSC.frdDesignPss(2);

            % Design PI controller: C(s) = Kp + Ki/s
            [Kp,Ki,Css,Gss,Fss] = designPI(Pss,Fm,wo);

            % Store design parameters
            LIN_MODEL.CONTROL_DESIGN.GSC.frdParam.Kp(2) = Kp;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdParam.Ki(2) = Ki;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdParam.b(2) = 1;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdCss{2} = Css;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdDesignGss{2} = Gss;
            LIN_MODEL.CONTROL_DESIGN.GSC.frdDesignFss{2} = Fss;

            % Update control parameters (broadcast to all DFIGs - all DFIGs are identical)
            LIN_MODEL.CONTROL.GSCq.PARAM.Kp = Kp*ones(1,nDFIG);
            LIN_MODEL.CONTROL.GSCq.PARAM.Ki = Ki*ones(1,nDFIG);
        %--------------------------------------------------------------------------
        otherwise
        %--------------------------------------------------------------------------
    end

    % STEP 5: RESTORE 2-DOF parameters after design (broadcast to all DFIGs)
    % The frequency-response design method requires 1-DOF control (b=1, der2error=1)
    % to correctly extract the plant transfer function. After design, we restore
    % the optimized 2-DOF parameters and broadcast to all DFIGs (all DFIGs identical).
    switch controlID
        case 1  % VSMP - restore der2error
            LIN_MODEL.CONTROL_DESIGN.VSMP.frdParam.der2error = der2error_saved;
            % Propagate to CONTROL.VSMP.PARAM (broadcast to all DFIGs)
            LIN_MODEL.CONTROL.VSMP.PARAM.der2error = der2error_saved*ones(1,nDFIG);
        case 3  % RSCd - restore b parameter
            LIN_MODEL.CONTROL_DESIGN.RSC.frdParam.b(1) = b_saved;
            % Propagate to CONTROL.RSCd.PARAM (broadcast to all DFIGs)
            LIN_MODEL.CONTROL.RSCd.PARAM.b = b_saved*ones(1,nDFIG);
        case 4  % RSCq - restore b parameter
            LIN_MODEL.CONTROL_DESIGN.RSC.frdParam.b(2) = b_saved;
            % Propagate to CONTROL.RSCq.PARAM (broadcast to all DFIGs)
            LIN_MODEL.CONTROL.RSCq.PARAM.b = b_saved*ones(1,nDFIG);
        case 5  % VDC - restore b parameter
            LIN_MODEL.CONTROL_DESIGN.VDC.frdParam.b = b_saved;
            % Propagate to CONTROL.VDC.PARAM (broadcast to all DFIGs)
            LIN_MODEL.CONTROL.VDC.PARAM.b = b_saved*ones(1,nDFIG);
        case 6  % GSCd - restore b parameter
            LIN_MODEL.CONTROL_DESIGN.GSC.frdParam.b(1) = b_saved;
            % Propagate to CONTROL.GSCd.PARAM (broadcast to all DFIGs)
            LIN_MODEL.CONTROL.GSCd.PARAM.b = b_saved*ones(1,nDFIG);
        case 7  % GSCq - restore b parameter
            LIN_MODEL.CONTROL_DESIGN.GSC.frdParam.b(2) = b_saved;
            % Propagate to CONTROL.GSCq.PARAM (broadcast to all DFIGs)
            LIN_MODEL.CONTROL.GSCq.PARAM.b = b_saved*ones(1,nDFIG);
    end

    % Relinearize system with updated controller and calculate stability margins
    LIN_MODEL = update_structs(LIN_MODEL,workerID);
end

%--------------------------------------------------------------------------
%% FINAL STABILITY ANALYSIS
%--------------------------------------------------------------------------
% Perform comprehensive linear analysis with all controllers designed
cd ../CONFIGURATION
LIN_MODEL = LINEAR_ANALYSIS(LIN_MODEL,workerID);

end

%==========================================================================
% HELPER FUNCTIONS - FREQUENCY-RESPONSE CONTROLLER DESIGN
%==========================================================================

%--------------------------------------------------------------------------
function [Kp,Ki,Css,Gss,Fss] = designPI(Pss,Fm,wo)
% designPI - PI Controller Design to Meet Phase Margin and Crossover Frequency
%
% DESCRIPTION:
%   Designs a PI controller C(s) = Kp + Ki/s to achieve specified phase margin
%   at specified crossover frequency for fast inner current/voltage loops.
%
% INPUTS:
%   Pss - Plant transfer function (state-space)
%   Fm  - Desired phase margin [deg]
%   wo  - Desired crossover frequency [rad/s]
%
% OUTPUTS:
%   Kp  - Proportional gain
%   Ki  - Integral gain
%   Css - Controller transfer function (state-space)
%   Gss - Open-loop transfer function G(s) = C(s)*P(s)
%   Fss - Closed-loop transfer function F(s) = G(s)/(1+G(s))
%
% ALGORITHM:
%   1. Calculate required controller angle to achieve Fm at wo
%   2. Determine controller gain to achieve |G(jwo)| = 1
%   3. Extract Kp and Ki from controller specifications
%--------------------------------------------------------------------------
    % Required controller angle to achieve phase margin [deg]
    Fic = -180 + Fm - 180/pi*angle(freqresp(Pss,wo));

    % Plant gain at crossover frequency
    Ap = abs(freqresp(Pss,wo));

    % Required controller gain for unity gain crossover: |C(jwo)*P(jwo)| = 1
    Ac = 1/Ap;

    % Calculate integral time constant from phase requirement
    I = tand(90 + Fic)/wo;

    % Calculate proportional and integral gains
    Kp = Ac*I*wo/sqrt(1 + (I*wo)^2);
    Ki = Kp/I;

    % Construct controller transfer function C(s) = Kp + Ki/s
    s = tf('s');
    Css = ss(Kp + Ki/s);

    % Calculate open-loop transfer function G(s) = C(s)*P(s)
    Gss = Css*Pss;

    % Calculate closed-loop transfer function F(s) = G(s)/(1+G(s))
    Fss = Css*Pss/(1+Gss);
end

%--------------------------------------------------------------------------
function [Tc,Tp,Css,Gss,Fss] = designRF(Pss,Fm,wo)
% designRF - Real Pole-Zero (RF) Controller Design for VSMP
%
% DESCRIPTION:
%   Designs an RF controller C(s) = (1+Tc*s)/(1+Tp*s) with real pole and zero
%   to achieve specified phase margin at specified crossover frequency.
%   Used for VSMP to provide transient damping while maintaining inertia.
%
% INPUTS:
%   Pss - Plant transfer function (state-space)
%   Fm  - Desired phase margin [deg]
%   wo  - Desired crossover frequency [rad/s]
%
% OUTPUTS:
%   Tc  - Zero time constant [s] (numerator: transient damping)
%   Tp  - Pole time constant [s] (denominator: relates to inertia H=Dp*Tp/2)
%   Css - Controller transfer function (state-space)
%   Gss - Open-loop transfer function G(s) = C(s)*P(s)
%   Fss - Closed-loop transfer function F(s) = G(s)/(1+G(s))
%
% ALGORITHM:
%   Uses fsolve to find Tc and Tp that simultaneously satisfy:
%   1. Phase condition: angle(C(jwo)) achieves desired Fm
%   2. Gain condition: |C(jwo)*P(jwo)| = 1 for crossover at wo
%--------------------------------------------------------------------------
    % Required controller angle to achieve phase margin [deg]
    Fic = -180 + Fm -180/pi*angle(freqresp(Pss,wo));

    % Plant gain at crossover frequency
    Ap = abs(freqresp(Pss,wo));

    % Required controller gain for unity gain crossover: |C(jwo)*P(jwo)| = 1
    Ac = 1/Ap;

    % Define Laplace variable for transfer function
    s = tf('s');

    % Configure fsolve nonlinear solver options
    opt_fsolve = optimoptions('fsolve');
    opt_fsolve.MaxIterations = 5000;  % Increase for RF controller convergence
    opt_fsolve.Display = 'off';       % Suppress solver output

    % Solve for Tc and Tp using nonlinear equation solver
    % Initial guess: Tc=0.002 (fast zero), Tp=0.6 (slow pole for inertia)
    % Equations: [angle(C(jwo)) = Fic; |C(jwo)| = Ac]
    xo = fsolve(@(x) [180/pi*angle(freqresp((1 + x(1)*s)/(1 + s*x(2)),wo))-Fic; ...
        abs(freqresp((1 + x(1)*s)/(1 + s*x(2)),wo))-Ac],[0.002;0.002*300],opt_fsolve);

    % Extract time constants from solution
    Tc = xo(1);  % Zero time constant (transient damping Dd = Tc)
    Tp = xo(2);  % Pole time constant (inertia H = Dp*Tp/2)

    % Construct controller transfer function C(s) = (1+Tc*s)/(1+Tp*s)
    Css = ss((1+Tc*s)/(1+Tp*s));

    % Calculate open-loop transfer function G(s) = C(s)*P(s)
    Gss = Css*Pss;

    % Calculate closed-loop transfer function F(s) = G(s)/(1+G(s))
    Fss = Css*Pss/(1+Gss);
end

%--------------------------------------------------------------------------
function [Kp,Css,Gss,Fss] = designP(Pss,wo)
% designP - Proportional Controller Design for VSMQ (Q-V Droop)
%
% DESCRIPTION:
%   Designs a proportional controller C(s) = Kp to achieve unity gain crossover
%   at specified frequency. Used for VSMQ reactive power/voltage droop control.
%
% INPUTS:
%   Pss - Plant transfer function (state-space)
%   wo  - Desired crossover frequency [rad/s]
%
% OUTPUTS:
%   Kp  - Proportional gain (Q-V droop gain)
%   Css - Controller transfer function (constant gain)
%   Gss - Open-loop transfer function G(s) = C(s)*P(s)
%   Fss - Closed-loop transfer function F(s) = G(s)/(1+G(s))
%
% ALGORITHM:
%   Simple gain calculation: Kp = 1/|P(jwo)| for |G(jwo)| = 1
%--------------------------------------------------------------------------
    % Plant gain at crossover frequency
    Ap = abs(freqresp(Pss,wo));

    % Proportional gain for unity gain crossover: |Kp*P(jwo)| = 1
    Kp = 1/Ap;

    % Controller is a constant gain (no dynamics)
    Css = Kp;

    % Calculate open-loop transfer function G(s) = Kp*P(s)
    Gss = Css*Pss;

    % Calculate closed-loop transfer function F(s) = G(s)/(1+G(s))
    Fss = Css*Pss/(1+Gss);
end

%--------------------------------------------------------------------------
function LIN_MODEL = update_structs(LIN_MODEL,workerID)
% update_structs - Relinearize System and Calculate Stability Margins
%
% DESCRIPTION:
%   Updates controller transfer functions, relinearizes the system with
%   current controller parameters, and calculates stability margins for
%   all control loops. Called after each controller design iteration.
%
% INPUTS:
%   LIN_MODEL - Structure with updated controller parameters
%   workerID  - [Optional] Worker ID for parallel computing (default: 0)
%
% OUTPUTS:
%   LIN_MODEL - Updated structure with:
%               - Controller transfer functions (frdCss)
%               - Plant transfer functions (frdDesignPss)
%               - Open-loop transfer functions (frdGss)
%               - Closed-loop transfer functions (frdFss)
%               - Stability margins (frdMargins: Fm, AmdB, wo, wu)
%
% PROCESS:
%   1. Construct controller transfer functions from parameters
%   2. Linearize system around operating point (calls LINEARIZE)
%   3. Extract plant models for each control loop
%   4. Calculate stability margins using fsolve
%--------------------------------------------------------------------------
    if nargin==1
        workerID = 0;
    end

    % Extract system parameters
    nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
    selectedDFIG = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;

    % Define Laplace variable for transfer functions
    s = tf('s');
    %--------------------------------------------------------------------------
    % CONSTRUCT CONTROLLER TRANSFER FUNCTIONS FROM PARAMETERS
    %--------------------------------------------------------------------------

    % VSMP: C(s) = (1 + Dd*s)/(1 + 2*H/Dp*s)
    H = LIN_MODEL.CONTROL.VSMP.PARAM.H(selectedDFIG);   % Inertia [s]
    Dp = LIN_MODEL.CONTROL.VSMP.PARAM.Dp(selectedDFIG); % Steady-state damping
    Dd = LIN_MODEL.CONTROL.VSMP.PARAM.Dd(selectedDFIG); % Transient damping [s]
    LIN_MODEL.CONTROL_DESIGN.VSMP.frdCss = ss((1 + Dd*s)/(1 + 2*H/Dp*s));

    % VSMQ: C(s) = Kp (proportional droop gain)
    K_Fs_ref = LIN_MODEL.CONTROL.VSMQ.PARAM.K_Fs_ref(selectedDFIG);
    LIN_MODEL.CONTROL_DESIGN.VSMQ.frdCss = K_Fs_ref;

    % RSCd: C(s) = Kp + Ki/s (d-axis current control)
    Kp_ird = LIN_MODEL.CONTROL.RSCd.PARAM.Kp(selectedDFIG);
    Ki_ird = LIN_MODEL.CONTROL.RSCd.PARAM.Ki(selectedDFIG);
    LIN_MODEL.CONTROL_DESIGN.RSC.frdCss{1} = ss(Kp_ird + Ki_ird/s);

    % RSCq: C(s) = Kp + Ki/s (q-axis current control)
    Kp_irq = LIN_MODEL.CONTROL.RSCq.PARAM.Kp(selectedDFIG);
    Ki_irq = LIN_MODEL.CONTROL.RSCq.PARAM.Ki(selectedDFIG);
    LIN_MODEL.CONTROL_DESIGN.RSC.frdCss{2} = ss(Kp_irq + Ki_irq/s);

    % VDC: C(s) = Kp + Ki/s (DC voltage control)
    Kp_vdc = LIN_MODEL.CONTROL.VDC.PARAM.Kp(selectedDFIG);
    Ki_vdc = LIN_MODEL.CONTROL.VDC.PARAM.Ki(selectedDFIG);
    LIN_MODEL.CONTROL_DESIGN.VDC.frdCss = ss(Kp_vdc + Ki_vdc/s);

    % GSCd: C(s) = Kp + Ki/s (d-axis current control)
    Kp_igd = LIN_MODEL.CONTROL.GSCd.PARAM.Kp(selectedDFIG);
    Ki_igd = LIN_MODEL.CONTROL.GSCd.PARAM.Ki(selectedDFIG);
    LIN_MODEL.CONTROL_DESIGN.GSC.frdCss{1} = ss(Kp_igd + Ki_igd/s);

    % GSCq: C(s) = Kp + Ki/s (q-axis current control)
    Kp_igq = LIN_MODEL.CONTROL.GSCq.PARAM.Kp(selectedDFIG);
    Ki_igq = LIN_MODEL.CONTROL.GSCq.PARAM.Ki(selectedDFIG);
    LIN_MODEL.CONTROL_DESIGN.GSC.frdCss{2} = ss(Kp_igq + Ki_igq/s);

    %--------------------------------------------------------------------------
    % LINEARIZE SYSTEM WITH UPDATED CONTROLLERS
    %--------------------------------------------------------------------------
    cd ../CONFIGURATION
    nCONTROL = 7;  % Total number of control loops
    LIN_MODEL = LINEARIZE(LIN_MODEL,workerID);
    %--------------------------------------------------------------------------
    % EXTRACT PLANT MODELS AND CALCULATE STABILITY MARGINS
    %--------------------------------------------------------------------------

    % Configure fsolve nonlinear solver for crossover frequency calculation
    opt_fsolve = optimoptions('fsolve');
    opt_fsolve.MaxIterations = 5000;
    opt_fsolve.Display = 'off';

    % Extract state-space matrices from linearized model
    matA = LIN_MODEL.ssModel.a;  % System dynamics matrix
    matB = LIN_MODEL.ssModel.b;  % Input matrix
    matC = LIN_MODEL.ssModel.c;  % Output matrix
    matD = LIN_MODEL.ssModel.d;  % Feedthrough matrix

    % Collect all controller transfer functions in cell array
    Css = {
        LIN_MODEL.CONTROL_DESIGN.VSMP.frdCss   % VSMP: RF controller
        LIN_MODEL.CONTROL_DESIGN.VSMQ.frdCss   % VSMQ: P controller
        LIN_MODEL.CONTROL_DESIGN.RSC.frdCss{1} % RSCd: PI controller
        LIN_MODEL.CONTROL_DESIGN.RSC.frdCss{2} % RSCq: PI controller
        LIN_MODEL.CONTROL_DESIGN.VDC.frdCss    % VDC: PI controller
        LIN_MODEL.CONTROL_DESIGN.GSC.frdCss{1} % GSCd: PI controller
        LIN_MODEL.CONTROL_DESIGN.GSC.frdCss{2} % GSCq: PI controller
    };

    % Initialize transfer function storage
    Pss = cell(1,nCONTROL);  % Plant transfer functions
    Gss = cell(1,nCONTROL);  % Open-loop transfer functions
    Fss = cell(1,nCONTROL);  % Closed-loop transfer functions

    % Initialize stability margin arrays
    Am = NaN(1,7); AmdB = NaN(1,7);  % Gain margins [linear, dB]
    Fm = NaN(1,7);                    % Phase margins [deg]
    wu = NaN(1,7);                    % Phase crossover frequencies [rad/s]
    wo = NaN(1,7);                    % Gain crossover frequencies [rad/s]

    % Initial crossover frequency guesses for fsolve convergence [rad/s]
    % Source: FRD_SPECS.*.wo defined in CONFIG_POWER_SYSTEM.m
    w_ini = [
        LIN_MODEL.CONTROL_DESIGN.VSMP.frdSpecs.wo ...
        LIN_MODEL.CONTROL_DESIGN.VSMQ.frdSpecs.wo ...
        LIN_MODEL.CONTROL_DESIGN.RSC.frdSpecs.wo ...
        LIN_MODEL.CONTROL_DESIGN.VDC.frdSpecs.wo ...
        LIN_MODEL.CONTROL_DESIGN.GSC.frdSpecs.wo ...
        ];

    % Loop through all control loops to extract plants and calculate margins
    for ii = 1:nCONTROL
        % Calculate indices for selected DFIG control loop
        indT = nCONTROL*(selectedDFIG-1)+ii;  % Tracking output index
        indS = nCONTROL*nDFIG + nCONTROL*(selectedDFIG-1)+ii;  % Sensitivity output index

        % Extract tracking and sensitivity transfer functions from linearization
        Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
        Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));

        % Calculate open-loop, closed-loop, and plant transfer functions
        Gss{ii} = -Tss/Sss;           % Open-loop: G(s) = C(s)*P(s)
        Fss{ii} = -Tss;               % Closed-loop: F(s) = T(s)
        Pss{ii} = Gss{ii}/Css{ii};    % Plant: P(s) = G(s)/C(s)

        % Calculate gain crossover frequency wo: |G(jwo)| = 1
        [wo(ii),~,exitflag] = fsolve(@(w) abs(freqresp(Gss{ii},w))-1,w_ini(ii),opt_fsolve);
        if exitflag<1 || wo(ii)<0
            wo(ii) = NaN;
            Fm(ii) = NaN;
        else
            % Calculate phase margin at gain crossover
            Fm(ii) = 180 + 180/pi*angle(freqresp(Gss{ii},wo(ii)));
        end

        % Calculate phase crossover frequency wu: angle(G(jwu)) = -180°
        [wu(ii),~,exitflag] = fsolve(@(w) 180/pi*angle(freqresp(Gss{ii},w))+180,w_ini(ii),opt_fsolve);
        if exitflag<1 || wu(ii)<0
            wu(ii) = NaN;
            Am(ii) = NaN;
            AmdB(ii) = NaN;
        else
            % Calculate gain margin at phase crossover
            Am(ii) = 1/abs(freqresp(Gss{ii},wu(ii)));
            AmdB(ii) = 20*log10(Am(ii));
        end
    end
    %--------------------------------------------------------------------------
    % STORE PLANT TRANSFER FUNCTIONS
    %--------------------------------------------------------------------------
    LIN_MODEL.CONTROL_DESIGN.VSMP.frdDesignPss = Pss{1};
    LIN_MODEL.CONTROL_DESIGN.VSMQ.frdDesignPss = Pss{2};
    LIN_MODEL.CONTROL_DESIGN.RSC.frdDesignPss = [Pss{3} Pss{4}];
    LIN_MODEL.CONTROL_DESIGN.VDC.frdDesignPss = Pss{5};
    LIN_MODEL.CONTROL_DESIGN.GSC.frdDesignPss = [Pss{6} Pss{7}];

    %--------------------------------------------------------------------------
    % STORE OPEN-LOOP TRANSFER FUNCTIONS
    %--------------------------------------------------------------------------
    LIN_MODEL.CONTROL_DESIGN.VSMP.frdGss = Gss{1};
    LIN_MODEL.CONTROL_DESIGN.VSMQ.frdGss = Gss{2};
    LIN_MODEL.CONTROL_DESIGN.RSC.frdGss = [Gss{3} Gss{4}];
    LIN_MODEL.CONTROL_DESIGN.VDC.frdGss = Gss{5};
    LIN_MODEL.CONTROL_DESIGN.GSC.frdGss = [Gss{6} Gss{7}];

    %--------------------------------------------------------------------------
    % STORE CLOSED-LOOP TRANSFER FUNCTIONS
    %--------------------------------------------------------------------------
    LIN_MODEL.CONTROL_DESIGN.VSMP.frdFss = Fss{1};
    LIN_MODEL.CONTROL_DESIGN.VSMQ.frdFss = Fss{2};
    LIN_MODEL.CONTROL_DESIGN.RSC.frdFss = [Fss{3} Fss{4}];
    LIN_MODEL.CONTROL_DESIGN.VDC.frdFss = Fss{5};
    LIN_MODEL.CONTROL_DESIGN.GSC.frdFss = [Fss{6} Fss{7}];

    %--------------------------------------------------------------------------
    % STORE PHASE MARGINS [deg]
    %--------------------------------------------------------------------------
    LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.Fm = Fm(1);
    LIN_MODEL.CONTROL_DESIGN.VSMQ.frdMargins.Fm = Fm(2);
    LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.Fm = Fm(3:4);
    LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.Fm = Fm(5);
    LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.Fm = Fm(6:7);

    %--------------------------------------------------------------------------
    % STORE GAIN CROSSOVER FREQUENCIES [rad/s]
    %--------------------------------------------------------------------------
    LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.wo = wo(1);
    LIN_MODEL.CONTROL_DESIGN.VSMQ.frdMargins.wo = wo(2);
    LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.wo = wo(3:4);
    LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.wo = wo(5);
    LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.wo = wo(6:7);

    %--------------------------------------------------------------------------
    % STORE GAIN MARGINS [dB]
    %--------------------------------------------------------------------------
    LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.AmdB = AmdB(1);
    LIN_MODEL.CONTROL_DESIGN.VSMQ.frdMargins.AmdB = AmdB(2);
    LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.AmdB = AmdB(3:4);
    LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.AmdB = AmdB(5);
    LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.AmdB = AmdB(6:7);

    %--------------------------------------------------------------------------
    % STORE PHASE CROSSOVER FREQUENCIES [rad/s]
    %--------------------------------------------------------------------------
    LIN_MODEL.CONTROL_DESIGN.VSMP.frdMargins.wu = wu(1);
    LIN_MODEL.CONTROL_DESIGN.VSMQ.frdMargins.wu = wu(2);
    LIN_MODEL.CONTROL_DESIGN.RSC.frdMargins.wu = wu(3:4);
    LIN_MODEL.CONTROL_DESIGN.VDC.frdMargins.wu = wu(5);
    LIN_MODEL.CONTROL_DESIGN.GSC.frdMargins.wu = wu(6:7);
end
