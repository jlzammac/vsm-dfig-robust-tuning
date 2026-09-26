function LIN_MODEL = CONFIG_CONTROL(LIN_MODEL)
% CONFIG_CONTROL - Initialize control structure with default values
%
% DESCRIPTION:
%   Creates a complete CONTROL structure with default parameter values for
%   all control loops in the N-DFIG wind farm system. This function is the
%   foundation for subsequent control design algorithms (CONTROL_DESIGN_FR
%   or CONTROL_DESIGN_TR) which optimize these parameters.
%
% ARCHITECTURE ROLE:
%   This function is part of the Universal Power System Framework:
%
%   CONFIG_MODEL → CONFIG_CONTROL → BusDefinition → Simulink Model
%   (N parameters)  (N controllers)  (N buses)      (N blocks)
%
%   The structure created here is:
%   1. Used by control design algorithms to store optimized parameters
%   2. Converted to Simulink buses by BusDefinition.m
%   3. Connected to POWER_SYSTEM_FULL Simulink model blocks
%
% CRITICAL COMPATIBILITY:
%   ⚠️ STRUCTURAL CHANGES REQUIRE SIMULINK BUS UPDATES
%   Any modification to field names, hierarchy, or dimensions must maintain
%   alignment with Simulink bus definitions. See CLAUDE.md section:
%   "CRITICAL COMPATIBILITY RULE - MATLAB/Simulink Integration"
%
% SCALABILITY:
%   All arrays use vectorial parametrization: ones(1,nDFIG)
%   - Works for ANY number of DFIGs: nDFIG = 1, 2, 4, 8, 16, ...
%   - No code changes needed for different system sizes
%   - Automatic bus generation scales accordingly
%
% CONTROL STRUCTURE HIERARCHY:
%   CONTROL
%   ├── VSMP   (Virtual Synchronous Machine - Active Power)
%   ├── VSMQ   (Virtual Synchronous Machine - Reactive Power)
%   ├── RSCd   (Rotor Side Converter - d-axis / Reactive Power)
%   ├── RSCq   (Rotor Side Converter - q-axis / Active Power)
%   ├── VDC    (DC-bus Voltage Control)
%   ├── GSCd   (Grid Side Converter - d-axis / Reactive Power)
%   ├── GSCq   (Grid Side Converter - q-axis / Active Power)
%   └── VIMP   (Virtual Impedance)
%
%   Each controller contains four sub-structures:
%   - PARAM  : Control parameters (Kp, Ki, b, H, Dp, Dd, etc.)
%   - TARGET : Reference values (setpoints)
%   - INPUT  : Measured feedback signals
%   - OUTPUT : Control actions and manipulated variables (MV)
%   - STATE  : Internal controller states (integrators, filters)
%
% SYNTAX:
%   LIN_MODEL = CONFIG_CONTROL(LIN_MODEL)
%
% INPUTS:
%   LIN_MODEL - Structure containing MODEL fields (requires MODEL.DFIG.PARAM.nDFIG)
%
% OUTPUTS:
%   LIN_MODEL - Input structure with added CONTROL field containing:
%               - Default control parameters for all 8 controllers
%               - Initialized to ones(1,nDFIG) or zeros(1,nDFIG) as appropriate
%
% EXECUTION TIME:
%   ~0.8 ms for nDFIG=4 (negligible in overall execution)
%   Optimization not recommended - focus on analysis/design functions
%
% MODIFICATION GUIDELINES:
%   ✅ SAFE: Add comments, improve documentation
%   ✅ SAFE: Change default numeric values (e.g., ones → 0.5*ones)
%   ⚠️ CAUTION: Add new fields (requires BusDefinition.m validation)
%   ❌ UNSAFE: Change field names (breaks Simulink bus compatibility)
%   ❌ UNSAFE: Change hierarchy (breaks CONTROL_DESIGN_* functions)
%
% SEE ALSO:
%   CONFIG_MODEL, CONTROL_DESIGN_FR, CONTROL_DESIGN_TR, BusDefinition
%
% REFERENCES:
%   - CLAUDE.md: Project architecture and compatibility rules
%   - WORKFLOWS.md: Control design workflow documentation
%
% AUTHOR: DFIG-Based Wind Farm Research Project
% VERSION: 1.1 - Enhanced documentation (2025-01-15)

%--------------------------------------------------------------------------
%% INITIALIZATION
%--------------------------------------------------------------------------
% Extract number of DFIGs from MODEL structure
nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - VSMP (Virtual Synchronous Machine - Active Power)
%--------------------------------------------------------------------------
% VSMP emulates the inertial and damping behavior of synchronous machines
% for improved grid stability and power oscillation damping.
%
% Transfer function: C(s) = (1/Dp) * (1 + Dd*s) / (1 + 2*H*s/Dp)
%
% Controller parameters:
CONTROL.VSMP.PARAM.H = ones(1,nDFIG);            % Inertia constant [s]
CONTROL.VSMP.PARAM.Dp = ones(1,nDFIG);           % Steady-state damping coefficient [pu]
CONTROL.VSMP.PARAM.Dd = ones(1,nDFIG);           % Transient damping coefficient [s]
CONTROL.VSMP.PARAM.der2error = ones(1,nDFIG);   % Derivative applied to: 1=error, 0=measurement
%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - VSMQ (Virtual Synchronous Machine - Reactive Power)
%--------------------------------------------------------------------------
% VSMQ controls stator voltage and reactive power with droop characteristics
% for voltage regulation and reactive power sharing among DFIGs.
%
% Controller parameters:
CONTROL.VSMQ.PARAM.K_Fs_ref = ones(1,nDFIG);     % Stator flux reference gain [pu]
CONTROL.VSMQ.PARAM.K_droopQV = ones(1,nDFIG);    % Q-V droop coefficient [pu]
%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - RSC (Rotor Side Converter Current Control)
%--------------------------------------------------------------------------
% RSC controls rotor currents in dq reference frame for decoupled control
% of active and reactive power through the DFIG rotor windings.
%
% PI controller with anti-windup: C(s) = Kp + Ki/s
% Anti-windup back-calculation coefficient: b
%
% RSCd - d-axis current control (reactive power path):
CONTROL.RSCd.PARAM.Kp = ones(1,nDFIG);           % Proportional gain [pu]
CONTROL.RSCd.PARAM.Ki = ones(1,nDFIG);           % Integral gain [pu/s]
CONTROL.RSCd.PARAM.b = ones(1,nDFIG);            % Anti-windup back-calculation coefficient [1/s]
%
% RSCq - q-axis current control (active power path):
CONTROL.RSCq.PARAM.Kp = ones(1,nDFIG);           % Proportional gain [pu]
CONTROL.RSCq.PARAM.Ki = ones(1,nDFIG);           % Integral gain [pu/s]
CONTROL.RSCq.PARAM.b = ones(1,nDFIG);            % Anti-windup back-calculation coefficient [1/s]
%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - VDC (DC-Bus Voltage Control)
%--------------------------------------------------------------------------
% VDC maintains constant DC-link voltage by controlling active power flow
% from DFIG rotor to grid through the GSC.
%
% PI controller with anti-windup: C(s) = Kp + Ki/s
%
% Controller parameters:
CONTROL.VDC.PARAM.Kp = ones(1,nDFIG);            % Proportional gain [pu]
CONTROL.VDC.PARAM.Ki = ones(1,nDFIG);            % Integral gain [pu/s]
CONTROL.VDC.PARAM.b = ones(1,nDFIG);             % Anti-windup back-calculation coefficient [1/s]
%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - GSC (Grid Side Converter Current Control)
%--------------------------------------------------------------------------
% GSC controls grid-side currents in dq reference frame for active power
% injection to grid and optional reactive power support.
%
% PI controller with anti-windup: C(s) = Kp + Ki/s
% Anti-windup back-calculation coefficient: b
%
% GSCd - d-axis current control (reactive power path):
CONTROL.GSCd.PARAM.Kp = ones(1,nDFIG);           % Proportional gain [pu]
CONTROL.GSCd.PARAM.Ki = ones(1,nDFIG);           % Integral gain [pu/s]
CONTROL.GSCd.PARAM.b = ones(1,nDFIG);            % Anti-windup back-calculation coefficient [1/s]
%
% GSCq - q-axis current control (active power path):
CONTROL.GSCq.PARAM.Kp = ones(1,nDFIG);           % Proportional gain [pu]
CONTROL.GSCq.PARAM.Ki = ones(1,nDFIG);           % Integral gain [pu/s]
CONTROL.GSCq.PARAM.b = ones(1,nDFIG);            % Anti-windup back-calculation coefficient [1/s]
%--------------------------------------------------------------------------
%% CONTROL PARAMETERS - VIMP (Virtual Impedance)
%--------------------------------------------------------------------------
% Virtual impedance emulates additional grid impedance for:
% - Enhanced system stability and damping
% - Improved power sharing among multiple DFIGs
% - Mitigation of sub-synchronous resonances
%
% Impedance model: Z_v = R_v + j*X_v = R_v + j*(2*pi*f0*L_v)
%
% Controller parameters:
CONTROL.VIMP.PARAM.Lv_pu = zeros(1,nDFIG);       % Virtual inductance [pu] (typically 0.05-0.15)
CONTROL.VIMP.PARAM.Rv_pu = zeros(1,nDFIG);       % Virtual resistance [pu] (typically 0.0)

%==========================================================================
%% CONTROL TARGET - Reference values (setpoints) for all controllers
%==========================================================================
% VSMP - Active power control setpoints
CONTROL.VSMP.TARGET.P_ref = ones(1,nDFIG);                % Active power reference [pu]

% VSMQ - Reactive power and voltage control setpoints
CONTROL.VSMQ.TARGET.Vs_ref = ones(1,nDFIG);               % Stator voltage reference [pu]
CONTROL.VSMQ.TARGET.Q_ref = ones(1,nDFIG);                % Reactive power reference [pu]

% RSCd - Rotor d-axis current control setpoint
CONTROL.RSCd.TARGET.iRSCd_ref = ones(1,nDFIG);            % Rotor d-axis current reference [pu]

% RSCq - Rotor q-axis current control setpoint
CONTROL.RSCq.TARGET.iRSCq_ref = ones(1,nDFIG);            % Rotor q-axis current reference [pu]

% VDC - DC-bus voltage control setpoint
CONTROL.VDC.TARGET.Vdc2_ref = ones(1,nDFIG);              % DC voltage squared reference [pu²]

% GSCd - Grid d-axis current and reactive power setpoints
CONTROL.GSCd.TARGET.Qg_ref = ones(1,nDFIG);               % Grid reactive power reference [pu]
CONTROL.GSCd.TARGET.iGSCd_ref = ones(1,nDFIG);            % Grid d-axis current reference [pu]

% GSCq - Grid q-axis current control setpoint
CONTROL.GSCq.TARGET.iGSCq_ref = ones(1,nDFIG);            % Grid q-axis current reference [pu]

%==========================================================================
%% CONTROL INPUT - Measured feedback signals for all controllers
%==========================================================================
% VSMP - Active power measurement
CONTROL.VSMP.INPUT.P = ones(1,nDFIG);                      % Measured active power [pu]

% VSMQ - Voltage and reactive power measurements
CONTROL.VSMQ.INPUT.Vs = ones(1,nDFIG);                     % Measured stator voltage [pu]
CONTROL.VSMQ.INPUT.Q = ones(1,nDFIG);                      % Measured reactive power [pu]

% RSCd - Rotor d-axis current measurement
CONTROL.RSCd.INPUT.iRSCd = ones(1,nDFIG);                  % Measured rotor d-axis current [pu]

% RSCq - Rotor q-axis current measurement
CONTROL.RSCq.INPUT.iRSCq = ones(1,nDFIG);                  % Measured rotor q-axis current [pu]

% VDC - DC voltage measurement (initialized to target for steady-state)
CONTROL.VDC.INPUT.Vdc2 = CONTROL.VDC.TARGET.Vdc2_ref;      % Measured DC voltage squared [pu²]

% GSCd - Grid d-axis current measurement (initialized to target)
CONTROL.GSCd.INPUT.iGSCd = CONTROL.GSCd.TARGET.iGSCd_ref;  % Measured grid d-axis current [pu]

% GSCq - Grid q-axis current measurement (initialized to target)
CONTROL.GSCq.INPUT.iGSCq = CONTROL.GSCq.TARGET.iGSCq_ref;  % Measured grid q-axis current [pu]

%==========================================================================
%% CONTROL OUTPUT - Control actions and manipulated variables
%==========================================================================
% VSMP - Virtual synchronous machine outputs
CONTROL.VSMP.OUTPUT.w_pu = ones(1,nDFIG);                  % Angular frequency [pu]
CONTROL.VSMP.OUTPUT.dth = ones(1,nDFIG);                   % Angle derivative [rad/s]
CONTROL.VSMP.OUTPUT.th = ones(1,nDFIG);                    % Rotor angle [rad]
CONTROL.VSMP.OUTPUT.MV = ones(1,nDFIG);                    % Manipulated variable (controller output)

% VSMQ - Virtual synchronous machine reactive power outputs
CONTROL.VSMQ.OUTPUT.Fs_ref = ones(1,nDFIG);                % Stator flux reference [pu]
CONTROL.VSMQ.OUTPUT.MV = ones(1,nDFIG);                    % Manipulated variable (controller output)

% RSCd - Rotor d-axis voltage command
CONTROL.RSCd.OUTPUT.vRSCd = ones(1,nDFIG);                 % RSC d-axis voltage [pu]
CONTROL.RSCd.OUTPUT.MV = ones(1,nDFIG);                    % Manipulated variable (PI output)

% RSCq - Rotor q-axis voltage command
CONTROL.RSCq.OUTPUT.vRSCq = ones(1,nDFIG);                 % RSC q-axis voltage [pu]
CONTROL.RSCq.OUTPUT.MV = ones(1,nDFIG);                    % Manipulated variable (PI output)

% VDC - Grid active power reference from DC voltage control
CONTROL.VDC.OUTPUT.Pg_ref = ones(1,nDFIG);                 % Grid active power reference [pu]
CONTROL.VDC.OUTPUT.MV = ones(1,nDFIG);                     % Manipulated variable (PI output)

% GSCd - Grid d-axis voltage command
CONTROL.GSCd.OUTPUT.vGSCd = ones(1,nDFIG);                 % GSC d-axis voltage [pu]
CONTROL.GSCd.OUTPUT.MV = ones(1,nDFIG);                    % Manipulated variable (PI output)

% GSCq - Grid q-axis voltage command
CONTROL.GSCq.OUTPUT.vGSCq = ones(1,nDFIG);                 % GSC q-axis voltage [pu]
CONTROL.GSCq.OUTPUT.MV = ones(1,nDFIG);                    % Manipulated variable (PI output)

%==========================================================================
%% CONTROL STATE - Internal controller states (integrators, filters, etc.)
%==========================================================================
% VSMP - 2 states per DFIG
% State variables:
%   Row 1: Angular frequency state (integrator state for frequency dynamics)
%   Row 2: Angle state (integrator state for rotor angle)
CONTROL.VSMP.STATE = ones(2,nDFIG);

% VSMQ - 1 state per DFIG
% State variable: Stator flux reference integrator state
CONTROL.VSMQ.STATE = ones(1,nDFIG);

% RSCd - 1 state per DFIG
% State variable: PI controller integral action state
CONTROL.RSCd.STATE = ones(1,nDFIG);

% RSCq - 1 state per DFIG
% State variable: PI controller integral action state
CONTROL.RSCq.STATE = ones(1,nDFIG);

% VDC - 1 state per DFIG
% State variable: DC voltage PI controller integral action state
CONTROL.VDC.STATE = ones(1,nDFIG);

% GSCd - 1 state per DFIG
% State variable: Grid d-axis PI controller integral action state
CONTROL.GSCd.STATE = ones(1,nDFIG);

% GSCq - 1 state per DFIG
% State variable: Grid q-axis PI controller integral action state
CONTROL.GSCq.STATE = ones(1,nDFIG);

%==========================================================================
%% FINAL STRUCTURE ASSIGNMENT
%==========================================================================
% Assign complete CONTROL structure to LIN_MODEL
% This structure will be:
%   1. Used by CONTROL_DESIGN_FR/TR to populate optimized parameters
%   2. Converted to Simulink buses by BusDefinition.m
%   3. Connected to POWER_SYSTEM_FULL Simulink model
LIN_MODEL.CONTROL = CONTROL;

% End of CONFIG_CONTROL.m 



