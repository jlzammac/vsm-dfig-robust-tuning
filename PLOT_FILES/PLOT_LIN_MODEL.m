function PLOT_LIN_MODEL(LIN_MODEL, figureType)
% PLOT_LIN_MODEL - Comprehensive visualization of DFIG linear control systems
%
% DESCRIPTION:
%   Generates analysis figures from linearized DFIG wind farm control models.
%   This is the main visualization function for LINEAR_ANALYSIS.m output data.
%   Supports 13 different figure types covering time-domain, frequency-domain,
%   and comparative analysis of control system performance.
%
% SYNTAX:
%   PLOT_LIN_MODEL(slug, figureType)
%
% INPUTS:
%   slug         - String identifier for the control design (e.g., 'TRD', 'FRD', 'GA_OPT')
%                  Automatically loads the corresponding file from:
%                    RESULTS/CONTROL/LIN_MODEL_<slug>.mat
%
%                  The loaded file must contain a structure named LIN_MODEL with:
%                    .MODEL          - System configuration and parameters
%                    .ssModel        - State-space representation (A,B,C,D matrices)
%                    .CONTROL        - Controller parameters (VSMP, VSMQ, RSC, GSC, VDC)
%                    .CONTROL_DESIGN - Design data (TRD/FRD methods, if available)
%
%   figureType   - Figure selection (integer 1-13):
%
%                  TIME-DOMAIN ANALYSIS:
%                    1  - Closed-loop step response (TRD design vs actual)
%                         Generates 2 figures: Fig 1 (SCR 10), Fig 2 (SCR 5)
%                         Each with 7 subplots comparing actual vs design reference
%
%                    3  - Impulse response interaction analysis (DFIG ↔ controllers)
%                         Generates 4 figures showing cross-coupling between loops
%
%                    6  - Frequency/PCC voltage response to P&Q reference steps
%                    10 - Frequency/PCC voltage response to load disturbances
%
%                    11 - TRD vs FRD comparison: step response
%                         Generates 2 figures: Fig 1 (SCR 10), Fig 2 (SCR 5)
%                         Each with 7 subplots comparing TRD vs FRD time response
%
%                  FREQUENCY-DOMAIN ANALYSIS:
%                    7  - Plant and loop transfer functions (Black diagram)
%                    8  - Sensitivity functions S(jω), T(jω) - robustness analysis
%                    9  - Closed-loop frequency response comparison (SCR analysis)
%
%                    12 - TRD vs FRD comparison: plant frequency response (Nichols)
%                         Generates 2 figures with 7 Nichols plots each
%
%                    13 - TRD vs FRD comparison: closed-loop frequency response (Bode)
%                         Generates 2 figures with 7 Bode magnitude plots each
%
%                  COMPARATIVE ANALYSIS:
%                    2  - DFIG performance comparison (SCR 10 vs SCR 5)
%                         Generates 1 figure with 7 subplots
%                         Compares grid strength impact on same controllers
%
%                    4  - Controller correlation heatmaps (same DFIG)
%                    5  - DFIG cross-correlation analysis (between DFIGs)
%
% CONTROL SYSTEM HIERARCHY:
%   Seven control loops analyzed (from slowest to fastest dynamics):
%
%   POWER SYSTEM LEVEL (Virtual Synchronous Machine):
%     VSMP - Active power / frequency droop (emulates generator inertia)
%     VSMQ - Reactive power / voltage control (emulates synchronous reactance)
%
%   CONVERTER LEVEL (PI controllers with setpoint weighting):
%     RSCd - Rotor-side d-axis: reactive power / torque control
%     RSCq - Rotor-side q-axis: active power / speed control
%     VDC  - DC-link voltage regulation (energy balance)
%     GSCd - Grid-side d-axis: reactive power injection
%     GSCq - Grid-side q-axis: active power / DC voltage support
%
% OUTPUT:
%   - Interactive MATLAB figures with subplot organization (typically 3×3 grid)
%   - All existing figures closed before generation (close all)
%   - Automatic export: Publication-quality .fig files saved to:
%       FIGURES/<slug>/<slug>_##_<DescriptiveName>[_Fig#].fig
%   Example: FIGURES/FRD_OPT/FRD_OPT_01_TRD_ClosedLoop_StepResponse_Fig1.fig
%
%   Publication formatting applied automatically:
%     • LaTeX interpreter for all text (titles, labels, tick marks)
%     • IEEE standard fonts: Times New Roman, 10pt
%     • Figure size: 7×5 inches (suitable for papers/presentations)
%     • Line width: 1.5pt for clear visibility
%     • Vector graphics renderer (painters) for scalability
%     • White background with subtle grid (30% alpha, dotted)
%
% EXAMPLES:
%   % Case 8: Sensitivity analysis (publication-ready)
%   PLOT_LIN_MODEL('TRD_DESIGN', 8)
%   % Loads: RESULTS/CONTROL/LIN_MODEL_TRD_DESIGN.mat
%   % Plots: Sensitivity functions S(jω), T(jω) with LaTeX formatting
%   % Saves: FIGURES/TRD_DESIGN/TRD_DESIGN_08_Sensitivity_Functions_Fig1.fig
%   %        FIGURES/TRD_DESIGN/TRD_DESIGN_08_Sensitivity_Functions_Fig2.fig
%
%   % Case 1: TRD Step response (shows TRD controllers from loaded file)
%   PLOT_LIN_MODEL('FRD_OPT', 1)
%   % Loads: RESULTS/CONTROL/LIN_MODEL_FRD_OPT.mat
%   % Saves: FIGURES/FRD_OPT/FRD_OPT_01_TRD_ClosedLoop_StepResponse_Fig1.fig
%   %        FIGURES/FRD_OPT/FRD_OPT_01_TRD_ClosedLoop_StepResponse_Fig2.fig
%   % Note: Shows TRD baseline controllers (from FRD_OPT file), not FRD!
%
%   % Case 7: Plant and open-loop analysis
%   PLOT_LIN_MODEL('PDS_OPT', 7)
%   % Saves: FIGURES/PDS_OPT/PDS_OPT_07_Plant_OpenLoop_Black_Fig1.fig
%   %        FIGURES/PDS_OPT/PDS_OPT_07_Plant_OpenLoop_Black_Fig2.fig
%
% FIGURE NAMING CONVENTION:
%   <slug>_##_<DescriptiveName>[_Fig#].fig
%   where ## is the two-digit case number (01-13)
%
%   Descriptive names by case:
%     1:  TRD_ClosedLoop_StepResponse
%     2:  DFIG_Comparison_SCR
%     3:  Interaction_ImpulseResponse
%     4:  Controller_Correlation
%     5:  DFIG_CrossCorrelation
%     6:  FreqPCC_PowerRefSteps
%     7:  Plant_OpenLoop_Black
%     8:  Sensitivity_Functions
%     9:  ClosedLoop_FreqResponse
%     10: FreqPCC_LoadSteps
%     11: TRDvsFRD_StepResponse
%     12: TRDvsFRD_PlantFreqResponse
%     13: TRDvsFRD_ClosedLoopFreqResponse
%
% CONTROLLER DESIGN DATA IN FILES:
%   Understanding what each file contains is critical for correct interpretation:
%
%   LIN_MODEL_TRD_DESIGN.mat contains:
%     • CONTROL_DESIGN.VSMP.trdCss         - Time-response designed controllers
%     • CONTROL_DESIGN.VSMP.trdDesignFss2  - 2nd-order reference model (TR specs)
%     • Does NOT contain frdCss (frequency-response design)
%
%   LIN_MODEL_FRD_OPT.mat contains BOTH designs:
%     • CONTROL_DESIGN.VSMP.trdCss         - Initial TRD controllers (baseline)
%     • CONTROL_DESIGN.VSMP.trdDesignFss2  - TR 2nd-order reference model
%     • CONTROL_DESIGN.VSMP.frdCss         - Frequency-response designed controllers
%     • CONTROL_DESIGN.VSMP.frdDesignFss   - FR closed-loop reference model
%
%   This dual-design structure allows direct comparison between methods.
%
%   IMPORTANT - CASE 1 BEHAVIOR:
%     Case 1 ALWAYS uses TRD controllers (trdCss) regardless of the slug:
%       PLOT_LIN_MODEL('TRD_DESIGN', 1) → Shows TRD_DESIGN controllers
%       PLOT_LIN_MODEL('FRD_OPT', 1)    → Shows TRD baseline from FRD_OPT file
%
%     This is intentional: Case 1 shows the time-response design performance.
%     To visualize FRD controllers, use Cases 11, 12, or 13 (TRD vs FRD comparison).
%
%   WHY FRD FILES CONTAIN TRD DATA:
%     The frequency-response design workflow (CONTROL_DESIGN_FR.m) uses TRD as
%     the starting point. The TRD controllers are preserved in FRD files to enable:
%       1. Before/after comparison (Cases 11-13)
%       2. Performance improvement quantification
%       3. Trade-off analysis between design methods
%
% NOTES:
%   - Requires MATLAB Control System Toolbox (ss, tf, freqresp, bodemag)
%   - Some cases require CONTROL_DESIGN field (TRD/FRD comparison)
%   - Typical analysis: Cases 1, 7, 8 for initial controller evaluation
%   - Grid strength comparison: Case 2 (requires nDFIG ≥ 3)
%   - Figure export directory FIGURES/<slug>/ is created automatically
%   - Existing figures with same name are overwritten without warning
%   - All text uses LaTeX interpreter - use LaTeX syntax in labels/titles
%   - Figures ready for direct inclusion in papers (export as PDF/EPS from .fig)
%   - To export for LaTeX: Open .fig → File → Export Setup → Format: EPS/PDF
%
% SEE ALSO:
%   LINEAR_ANALYSIS    - Generates LIN_MODEL input structure
%   CONTROL_DESIGN_FR  - Frequency-response control design
%   CONTROL_DESIGN_TR  - Time-response control design
%   PLOT_LIN_MODEL_v2  - Enhanced version with publication-quality export
%
% Version: 1.0 (legacy)
% Project: DFIG-Based Wind Farm Power Systems Analysis
%
%==========================================================================
% AVAILABLE FIGURE TYPES (detailed list)
%==========================================================================
% 1.  Closed-loop step response (TRD design with interactions)
% 2.  DFIG comparison: SCR 10 vs SCR 5 (grid strength analysis)
% 3.  Interaction impulse responses between DFIGs and controllers
% 4.  Controller correlation analysis with color maps (same DFIG)
% 5.  DFIG cross-correlation analysis with color maps (between DFIGs)
% 6.  Frequency and PCC voltage for P&Q reference steps
% 7.  Plant and open-loop frequency response (Black diagram)
% 8.  Sensitivity functions |S(jω)| and |T(jω)| (robustness metrics)
% 9.  Closed-loop frequency response comparison between DFIGs
% 10. Frequency and PCC voltage for active/reactive load steps
% 11. TRD vs FRD comparison: step response F(s)
% 12. TRD vs FRD comparison: plant frequency response G(jω)
% 13. TRD vs FRD comparison: closed-loop frequency response |F(jω)|

% Close all existing figures before generating new ones
close('all')

%==========================================================================
% INPUT HANDLING: Load LIN_MODEL from RESULTS/CONTROL using slug
%==========================================================================
% First argument must be a string slug
if ~(ischar(LIN_MODEL) || isstring(LIN_MODEL))
    error('PLOT_LIN_MODEL:InvalidInput', ...
          'First argument must be a string slug (e.g., ''TRD'', ''FRD'', ''GA_OPT'')');
end

slug = char(LIN_MODEL);  % Convert to char if string type

% Build file path relative to this script location
script_dir = fileparts(mfilename('fullpath'));
file_path = fullfile(script_dir, '..', 'RESULTS', 'CONTROL', ...
                     ['LIN_MODEL_' slug '.mat']);

% Check if file exists
if ~exist(file_path, 'file')
    error('PLOT_LIN_MODEL:FileNotFound', ...
          ['File not found: %s\n' ...
           'Available files in RESULTS/CONTROL/:\n%s'], ...
          file_path, ...
          list_available_files(fullfile(script_dir, '..', 'RESULTS', 'CONTROL')));
end

% Load the file
fprintf('Loading: %s\n', file_path);
loaded_data = load(file_path);

% Extract LIN_MODEL from loaded structure
% Try multiple possible variable names:
%   1. LIN_MODEL (standard name)
%   2. LIN_MODEL_<slug> (name with slug suffix)
if isfield(loaded_data, 'LIN_MODEL')
    LIN_MODEL = loaded_data.LIN_MODEL;
    fprintf('  Found variable: LIN_MODEL\n');
elseif isfield(loaded_data, ['LIN_MODEL_' slug])
    LIN_MODEL = loaded_data.(['LIN_MODEL_' slug]);
    fprintf('  Found variable: LIN_MODEL_%s\n', slug);
else
    % Show available variables in file
    var_names = fieldnames(loaded_data);
    error('PLOT_LIN_MODEL:InvalidFile', ...
          ['File does not contain expected variable.\n' ...
           'Expected: LIN_MODEL or LIN_MODEL_%s\n' ...
           'Available variables in file:\n  %s'], ...
          slug, strjoin(var_names, '\n  '));
end

% Validate structure has minimum required fields
required_fields = {'MODEL', 'ssModel', 'CONTROL'};
missing_fields = setdiff(required_fields, fieldnames(LIN_MODEL));

if ~isempty(missing_fields)
    error('PLOT_LIN_MODEL:InvalidStructure', ...
          'LIN_MODEL structure missing required fields: %s', ...
          strjoin(missing_fields, ', '));
end

fprintf('Successfully loaded LIN_MODEL from slug: %s\n', slug);

%==========================================================================
% FIGURE EXPORT CONFIGURATION
%==========================================================================
% Create export directory for saving figures
figure_export_dir = fullfile(script_dir, '..', 'FIGURES', slug);
if ~exist(figure_export_dir, 'dir')
    mkdir(figure_export_dir);
    fprintf('Created figure export directory: %s\n', figure_export_dir);
end

% Track generated figures for automatic saving
generated_figures = [];

%==========================================================================
% INITIALIZATION AND DATA EXTRACTION
%==========================================================================

% Extract system model configuration
MODEL = LIN_MODEL.MODEL;

% Create Laplace variable for transfer function construction
s = tf('s');

%--------------------------------------------------------------------------
% VSMP CONTROL PARAMETERS (Virtual Synchronous Machine - Active Power)
%--------------------------------------------------------------------------
% Emulates synchronous generator inertia and damping characteristics
% Transfer function: C_VSMP(s) = (1 + Dd·s) / (1 + 2H/Dp·s)

H = LIN_MODEL.CONTROL.VSMP.PARAM.H(1);              % Inertia constant [s]
Dp = LIN_MODEL.CONTROL.VSMP.PARAM.Dp(1);            % Steady-state damping [pu]
Dd = LIN_MODEL.CONTROL.VSMP.PARAM.Dd(1);            % Transient damping [pu]
der2error = LIN_MODEL.CONTROL.VSMP.PARAM.der2error(1); % Damping connection (1 or 2-DOF)

%--------------------------------------------------------------------------
% VSMQ CONTROL PARAMETERS (Virtual Synchronous Machine - Reactive Power)
%--------------------------------------------------------------------------
% Emulates synchronous generator voltage/reactive power droop
% Transfer function: C_VSMQ(s) = K_Fs_ref (proportional gain)

K_Fs_ref = LIN_MODEL.CONTROL.VSMQ.PARAM.K_Fs_ref(1); % Voltage control gain [pu]

%--------------------------------------------------------------------------
% RSC CURRENT CONTROL - d-axis (Reactive Power / Torque Control)
%--------------------------------------------------------------------------
% PI controller with setpoint weighting for rotor-side converter d-axis
% Transfer function: C_RSCd(s) = Kp + Ki/s, with setpoint weighting b

Kp_ird = LIN_MODEL.CONTROL.RSCd.PARAM.Kp(1);        % Proportional gain [pu]
Ki_ird = LIN_MODEL.CONTROL.RSCd.PARAM.Ki(1);        % Integral gain [pu/s]
b_ird = LIN_MODEL.CONTROL.RSCd.PARAM.b(1);          % Setpoint weighting (0-1)

%--------------------------------------------------------------------------
% RSC CURRENT CONTROL - q-axis (Active Power / Speed Control)
%--------------------------------------------------------------------------
% PI controller with setpoint weighting for rotor-side converter q-axis
% Transfer function: C_RSCq(s) = Kp + Ki/s, with setpoint weighting b

Kp_irq = LIN_MODEL.CONTROL.RSCq.PARAM.Kp(1);        % Proportional gain [pu]
Ki_irq = LIN_MODEL.CONTROL.RSCq.PARAM.Ki(1);        % Integral gain [pu/s]
b_irq = LIN_MODEL.CONTROL.RSCq.PARAM.b(1);          % Setpoint weighting (0-1)

%--------------------------------------------------------------------------
% DC-LINK VOLTAGE CONTROL (Energy Balance Regulation)
%--------------------------------------------------------------------------
% PI controller for DC capacitor voltage regulation
% Transfer function: C_VDC(s) = Kp + Ki/s, with setpoint weighting b

Kp_vdc = LIN_MODEL.CONTROL.VDC.PARAM.Kp(1);         % Proportional gain [pu]
Ki_vdc = LIN_MODEL.CONTROL.VDC.PARAM.Ki(1);         % Integral gain [pu/s]
b_vdc = LIN_MODEL.CONTROL.VDC.PARAM.b(1);           % Setpoint weighting (0-1)

%--------------------------------------------------------------------------
% GSC CURRENT CONTROL - d-axis (Reactive Power Injection)
%--------------------------------------------------------------------------
% PI controller with setpoint weighting for grid-side converter d-axis
% Transfer function: C_GSCd(s) = Kp + Ki/s, with setpoint weighting b

Kp_igd = LIN_MODEL.CONTROL.GSCd.PARAM.Kp(1);        % Proportional gain [pu]
Ki_igd = LIN_MODEL.CONTROL.GSCd.PARAM.Ki(1);        % Integral gain [pu/s]
b_igd = LIN_MODEL.CONTROL.GSCd.PARAM.b(1);          % Setpoint weighting (0-1)

%--------------------------------------------------------------------------
% GSC CURRENT CONTROL - q-axis (Active Power / DC Voltage Support)
%--------------------------------------------------------------------------
% PI controller with setpoint weighting for grid-side converter q-axis
% Transfer function: C_GSCq(s) = Kp + Ki/s, with setpoint weighting b

Kp_igq = LIN_MODEL.CONTROL.GSCq.PARAM.Kp(1);        % Proportional gain [pu]
Ki_igq = LIN_MODEL.CONTROL.GSCq.PARAM.Ki(1);        % Integral gain [pu/s]
b_igq = LIN_MODEL.CONTROL.GSCq.PARAM.b(1);          % Setpoint weighting (0-1) 

%--------------------------------------------------------------------------
% CONTROLLER TRANSFER FUNCTIONS (State-Space Form)
%--------------------------------------------------------------------------
% Cell array containing all seven controller transfer functions
% Converted to state-space representation for frequency/time response analysis
% Order matches control hierarchy: VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq
currentCss = {
    ss((1+Dd*s)/(1+2*H/Dp*s));      % VSMP: Lead-lag compensator (inertia emulation)
    ss(K_Fs_ref);                    % VSMQ: Proportional gain (voltage droop)
    ss(Kp_ird + Ki_ird/s);           % RSCd: PI controller (reactive power)
    ss(Kp_irq + Ki_irq/s);           % RSCq: PI controller (active power)
    ss(Kp_vdc + Ki_vdc/s);           % VDC:  PI controller (DC voltage)
    ss(Kp_igd + Ki_igd/s);           % GSCd: PI controller (grid reactive power)
    ss(Kp_igq + Ki_igq/s);           % GSCq: PI controller (grid active power)
};

%--------------------------------------------------------------------------
% STATE-SPACE MODEL (Linearized System)
%--------------------------------------------------------------------------
% Extract linearized state-space representation from LINEAR_ANALYSIS.m
% Matrices: dx/dt = A·x + B·u,  y = C·x + D·u

ssModel = LIN_MODEL.ssModel;        % Complete state-space model
matA = ssModel.a;                   % System dynamics matrix [n×n]
matB = ssModel.b;                   % Input matrix [n×m]
matC = ssModel.c;                   % Output matrix [p×n]
matD = ssModel.d;                   % Feedthrough matrix [p×m]

%--------------------------------------------------------------------------
% LABELS AND SYSTEM DIMENSIONS
%--------------------------------------------------------------------------
% Human-readable labels for plots and analysis

% Output variable labels (controlled variables)
OutputLabel = {
    'DFIG active power (pu)'
    'DFIG reactive power (pu)'
    'd-axis rotor current (pu)'
    'q-axis rotor current (pu)'
    'DC-link squared voltage (pu)'
    'd-axis GSC current (pu)'
    'q-axis GSC current (pu)'
};
ControlLabel = {
    'VSMP'
    'VSMQ'
    'RSCd'
    'RSCq'
    'VDC'
    'GSCd'
    'GSCq'
    };

% Abbreviated units for compact display in labels
OutputUnits = {
    'pu'    % VSMP: Active power
    'pu'    % VSMQ: Reactive power
    'pu'    % RSCd: d-axis rotor current
    'pu'    % RSCq: q-axis rotor current
    'pu'    % VDC: DC-link squared voltage
    'pu'    % GSCd: d-axis GSC current
    'pu'    % GSCq: q-axis GSC current
    };

DFIGLabel = {'SCR trafo = 10','SCR trafo = 5'};
nDFIG = MODEL.DFIG.PARAM.nDFIG;
nCONTROL = 7;
if isfield(LIN_MODEL,'CONTROL_DESIGN')
    CONTROL_DESIGN = LIN_MODEL.CONTROL_DESIGN;
    % Second-order closed-loop model used in the time-response controller design
    % Used in option 1 as comparison with the current closed-loop TF
    trdDesignFss2 = {
        CONTROL_DESIGN.VSMP.trdDesignFss2
        CONTROL_DESIGN.VSMQ.trdDesignFss2
        CONTROL_DESIGN.RSC.trdDesignFss2
        CONTROL_DESIGN.RSC.trdDesignFss2
        CONTROL_DESIGN.VDC.trdDesignFss2
        CONTROL_DESIGN.GSC.trdDesignFss2
        CONTROL_DESIGN.GSC.trdDesignFss2
        };
    % Time-response designed controllers
    trdCss = {
        CONTROL_DESIGN.VSMP.trdCss
        CONTROL_DESIGN.VSMQ.trdCss
        CONTROL_DESIGN.RSC.trdCss
        CONTROL_DESIGN.RSC.trdCss
        CONTROL_DESIGN.VDC.trdCss
        CONTROL_DESIGN.GSC.trdCss
        CONTROL_DESIGN.GSC.trdCss
        };
    % Frequency-response designed controllers
    if isfield(LIN_MODEL.CONTROL_DESIGN.VSMP,'frdCss')
        frdCss = {
            CONTROL_DESIGN.VSMP.frdCss
            CONTROL_DESIGN.VSMQ.frdCss
            CONTROL_DESIGN.RSC.frdCss{1}
            CONTROL_DESIGN.RSC.frdCss{2}
            CONTROL_DESIGN.VDC.frdCss
            CONTROL_DESIGN.GSC.frdCss{1}
            CONTROL_DESIGN.GSC.frdCss{2}
            };
    end
end

switch (figureType)
   %--------------------------------------------------------------
    case 1 % TIME-RESPONSE DESIGN (TRD) - Closed-loop step response analysis
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   Step response of each control loop using TIME-RESPONSE designed controllers.
    %   Compares actual closed-loop behavior (with interactions) vs. design reference.
    %
    % IMPORTANT: This case ALWAYS uses TRD controllers (trdCss), regardless of slug:
    %   - PLOT_LIN_MODEL('TRD_DESIGN', 1) → TRD controllers from TRD_DESIGN file
    %   - PLOT_LIN_MODEL('FRD_OPT', 1)    → TRD baseline controllers from FRD_OPT file
    %   - PLOT_LIN_MODEL('PDS_OPT', 1)    → TRD controllers from PDS_OPT file
    %
    % WHY: TRD is the baseline design method. FRD files contain both TRD (baseline)
    %      and FRD (improved) controllers for comparison. Case 1 shows TRD performance.
    %
    % LEGEND INTERPRETATION:
    %   Blue line  (Actual closed-loop): Real system response with controller
    %                                     interactions between all 7 control loops
    %   Orange line (Design reference):  Idealized 2nd-order model from TR specs
    %                                     (settling time, overshoot, no interactions)
    %
    % WHAT TO LOOK FOR:
    %   - Good match → Loop is well-decoupled from other controllers
    %   - Differences → Significant interactions with other control loops
    %   - Oscillations → Potential stability issues or excessive coupling
    %
    % OUTPUT: 2 figures (one per DFIG configuration: SCR 10 and SCR 5)
    %         Each figure has 7 subplots (one per control loop)
    %
        hDFIG = [1 3];  % DFIG indices: 1=SCR 10, 3=SCR 5
        tfin = [3 ; 3 ; 0.1 ; 0.1 ; 0.1 ; 0.02 ; 0.02];  % Simulation time per loop
        % VSMP: 3s, VSMQ: 3s, RSCd/q: 100ms, VDC: 100ms, GSCd/q: 20ms
        for ii = 1:length(hDFIG)
            figure(ii)
            subplot
            for jj = 1:nCONTROL
                subplot(3,3,jj)
                % Extract T(s) and S(s) from linearized model
                indT = nCONTROL*(hDFIG(ii)-1)+jj;
                indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1)+jj;
                Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));  % Complementary sensitivity
                Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));  % Sensitivity function

                % Reconstruct plant: P = -T/S
                Gss = -Tss/Sss;  % Open-loop transfer function (includes current controller)
                Pss = Gss/currentCss{jj};  % Plant = Open-loop / Current controller

                % Closed-loop with TRD controller (from loaded file)
                Fss = trdCss{jj}*Pss/(1+trdCss{jj}*Pss);  % Actual closed-loop TF

                % Time simulation
                t = linspace(0,tfin(jj),5000);
                y1 = step(Fss,t);  % Actual response (with interactions)
                y2 = step(trdDesignFss2{jj},t);  % Design reference (2nd-order ideal)

                % Plot and format
                plot(t,[y1 y2],'LineWidth',1.5)
                xlim([t(1) tfin(jj)]);
                xlabel('t (s)')
                ylabel(OutputLabel{jj})
                title([ControlLabel{jj} ': ' DFIGLabel{ii}])

                % Set y-axis limit for VSMP (controller 1)
                if jj == 1  % VSMP controller
                    yl = ylim;
                    ylim([yl(1), 1.5]);  % Cap maximum at 1.5
                end

                leg = legend('Actual closed-loop','Design reference','Location','best');
                set(leg, 'Interpreter', 'latex', 'Color', 'white', 'EdgeColor', 'black', 'TextColor', 'black')
            end
        end
   %--------------------------------------------------------------
    case 2 % DFIG COMPARISON - Grid strength impact (SCR 10 vs SCR 5)
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   Complementary sensitivity function T(s) step response for each control loop,
    %   comparing system behavior under different grid strengths (SCR = Short Circuit Ratio).
    %
    % IMPORTANT: This compares DFIG 1 (SCR trafo = 10, strong grid) vs
    %            DFIG 3 (SCR trafo = 5, weak grid) using the SAME controllers.
    %
    % LEGEND INTERPRETATION:
    %   Blue line   (SCR trafo = 10): Strong grid - higher short-circuit capacity
    %   Orange line (SCR trafo = 5):  Weak grid - lower short-circuit capacity
    %
    % WHAT TO LOOK FOR:
    %   - Faster response on strong grid (SCR 10) → Less grid impedance
    %   - Oscillations on weak grid (SCR 5) → Grid-controller interactions
    %   - Overshoot differences → Stability margin degradation on weak grids
    %   - Controllers designed for strong grid may struggle on weak grids
    %
    % OUTPUT: 1 figure with 7 subplots (one per control loop)
    %
        % Simulation time for each controller (optimized to show transient dynamics)
        % Carefully adjusted to show settling without excessive steady-state
        tfin = [25 ; 25 ; 0.01 ; 0.01 ; 0.1 ; 0.01 ; 0.01];  % Simulation time per loop
        % VSMP: 25s, VSMQ: 25s, RSCd/q: 10ms, VDC: 100ms, GSCd/q: 10ms

        figure(1)
        for jj = 1:nCONTROL
            subplot(3,3,jj)
            hold on

            % Generate time vector for this controller
            t = linspace(0, tfin(jj), 5000);

            for ii = [1 3]  % DFIG indices: 1=SCR 10, 3=SCR 5
                indT = nCONTROL*(ii-1)+jj;
                Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));  % Complementary sensitivity T(s)
                y = step(-Tss, t);  % Step response (negated for correct sign)
                plot(t, y, 'LineWidth', 1.5)
            end

            xlabel('t (s)')
            ylabel(OutputLabel{jj})
            title(ControlLabel{jj})
            xlim([0 tfin(jj)]);  % Set x-axis limits to full simulation time

            % Set y-axis limit for VDC (controller 5)
            if jj == 5  % VDC controller
                yl = ylim;
                ylim([yl(1), 1.5]);  % Cap maximum at 1.5
            end

            leg = legend(DFIGLabel,'Location','best');
            set(leg, 'Interpreter', 'latex', 'Color', 'white', 'EdgeColor', 'black', 'TextColor', 'black')
            hold off
        end
   %--------------------------------------------------------------
    case 3 % CONTROLLER INTERACTIONS - Input-based impulse response analysis
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   Impulse response analysis organized by INPUT DFIG:
    %   - Figure N: Impulse applied to DFIG hDFIG(N)
    %   - Each subplot shows responses on ALL DFIGs (overlaid)
    %   - Reveals both self-regulation and cross-coupling simultaneously
    %
    % TRANSFER FUNCTION ANALYZED:
    %   S(s) = Sensitivity function from controller input to controller output
    %   Input:  Controller reference signal (impulse excitation on specific DFIG)
    %   Output: Controller output signal (tracking error response on all DFIGs)
    %
    % CONFIGURATION:
    %   hDFIG = [1 3]  → Generates 2 figures (input on DFIG 1, input on DFIG 3)
    %   hDFIG = 1      → Generates only 1 figure (input on DFIG 1)
    %
    % OUTPUT STRUCTURE:
    %   Figure 1: Input on DFIG 1 (7×7 matrix = 49 subplots)
    %     - Blue line:   DFIG 1 → DFIG 1 (self-regulation)
    %     - Orange line: DFIG 1 → DFIG 3 (cross-coupling)
    %
    %   Figure 2: Input on DFIG 3 (7×7 matrix = 49 subplots)
    %     - Blue line:   DFIG 3 → DFIG 1 (cross-coupling)
    %     - Orange line: DFIG 3 → DFIG 3 (self-regulation)
    %
    % SUBPLOT ORGANIZATION (row = input controller, column = output controller):
    %   Row 1: VSMP input  → [VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq] outputs
    %   Row 2: VSMQ input  → [VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq] outputs
    %   ...
    %   Row 7: GSCq input  → [VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq] outputs
    %
    % INTERPRETATION GUIDE:
    %   - Diagonal (ii=jj): Direct controller self-dynamics
    %   - Off-diagonal: Cross-coupling between different controllers
    %   - Line separation: Difference between blue/orange shows cross-DFIG coupling strength
    %   - Small responses: Good decoupling (desired for stability)
    %

        %------------------------------------------------------------------
        % CONFIGURATION SECTION - Customize here
        %------------------------------------------------------------------

        % Font sizes (adjust for better readability in dense 7×7 layouts)
        fontsize_title = 6;       % Subplot titles
        fontsize_label = 5;       % Axis labels (x, y)
        fontsize_tick = 4;        % Tick labels (numbers on axes)
        fontsize_legend = 5;      % Legend text
        fontsize_suptitle = 11;   % Figure super title

        % Manual time override (optional)
        % Set to NaN for automatic detection, or specify time [s] per controller:
        % Order: [VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq]
        % Values from case 2: VSMP: 25s, VSMQ: 25s, RSCd/q: 10ms, VDC: 100ms, GSCd/q: 10ms
        tfin_manual = [0.5; 0.5; 0.01; 0.01; 0.1; 0.01; 0.01];

        % Alternative: Use automatic detection
        % tfin_manual = [NaN; NaN; NaN; NaN; NaN; NaN; NaN];

        % Maximum time scale cap [s]
        % CRITICAL: All time scales are capped at this value to prevent excessive scales
        % Set to 25s to accommodate slow controllers (VSMP, VSMQ)
        max_time_cap = 25;  % 25 s maximum (adjustable here)

        % Zero-phase low-pass filter to remove spurious high-frequency dynamics
        % Set to true to enable filtering (removes capacitor node oscillations)
        enable_filter = true;     % Enable/disable filtering

        % Filter design (Butterworth low-pass)
        % Spurious frequency: ~6425 Hz (40376 rad/s)
        % Control dynamics: RSC/GSC ~50-100 Hz, VDC ~10 Hz, VSM <1 Hz
        % Filter cutoff: 500 Hz (preserves control dynamics, attenuates spurious)
        % With order 8: Good balance between attenuation and numerical stability
        % Attenuation at 6425 Hz: (6425/500)^8 ≈ -73 dB (sufficient for spurious removal)
        filter_cutoff_hz = 500;   % Cutoff frequency [Hz]
        filter_order = 8;         % Filter order (balance between effectiveness and stability)

        %------------------------------------------------------------------
        % STEP 1: DFIG selection and initialization
        %------------------------------------------------------------------
        hDFIG = [1 3];  % DFIG indices: 1=SCR 10, 3=SCR 5
        time_analysis = linspace(0, 10, 10000);  % 10s generous window for analysis

        % Determine all output DFIGs (for overlay plotting)
        all_output_DFIGs = hDFIG;

        fprintf('Case 3: Computing automatic settling times...\n');

        %------------------------------------------------------------------
        % STEP 2: Automatic settling time detection
        %------------------------------------------------------------------
        tfin_auto = NaN(nCONTROL, nCONTROL, length(hDFIG), length(all_output_DFIGs));

        for nn_idx = 1:length(hDFIG)
            nn = hDFIG(nn_idx);
            for kk_idx = 1:length(all_output_DFIGs)
                kk = all_output_DFIGs(kk_idx);
                for ii = 1:nCONTROL
                    for jj = 1:nCONTROL
                        % Construct sensitivity transfer function
                        indI = nCONTROL*(nn-1)+ii;
                        indO = nCONTROL*nDFIG + nCONTROL*(kk-1)+jj;
                        Sss = ss(matA,matB(:,indI),matC(indO,:),matD(indO,indI));

                        % Compute impulse response
                        y_impulse = impulse(Sss, time_analysis);

                        % Detect settling time (2% of peak criterion)
                        y_max = max(abs(y_impulse));
                        if y_max > 1e-10  % Avoid division by zero
                            settling_idx = find(abs(y_impulse(end:-1:1)) > 0.02*y_max, 1, 'first');
                            if ~isempty(settling_idx)
                                t_settle = time_analysis(end - settling_idx + 1);
                                tfin_auto(ii,jj,nn_idx,kk_idx) = min(max(1.3*t_settle, 0.005), 10);
                            else
                                tfin_auto(ii,jj,nn_idx,kk_idx) = 0.5;
                            end
                        else
                            tfin_auto(ii,jj,nn_idx,kk_idx) = 0.5;
                        end
                    end
                end
            end
        end

        fprintf('  Automatic settling time detection completed.\n');

        %------------------------------------------------------------------
        % STEP 3: Compute impulse responses with optimized time windows
        %------------------------------------------------------------------
        InterCellArray = cell(nCONTROL,nCONTROL,length(hDFIG),length(all_output_DFIGs));
        TimeArray = cell(nCONTROL,nCONTROL,length(hDFIG),length(all_output_DFIGs));

        % Design COMMON zero-phase low-pass filter (if enabled)
        % Use fixed sampling frequency based on typical fast dynamics
        filter_fs = 10000;  % 10 kHz sampling (sufficient for control dynamics)
        filter_designed = false;
        filter_b = [];  % Initialize filter coefficients
        filter_a = [];
        if enable_filter
            fprintf('  Designing common zero-phase filter (cutoff = %d Hz, order = %d)...\n', ...
                    filter_cutoff_hz, filter_order);

            % Design filter with fixed sampling frequency
            Wn = filter_cutoff_hz / (filter_fs/2);  % Normalized cutoff
            fprintf('    Normalized cutoff Wn = %.4f (must be in (0,1))\n', Wn);

            if Wn > 0 && Wn < 1
                try
                    [filter_b, filter_a] = butter(filter_order, Wn, 'low');
                    filter_designed = true;
                    fprintf('  Filter designed successfully (fs = %d Hz, Wn = %.4f).\n', filter_fs, Wn);
                    fprintf('    Filter coefficients b = [%s]\n', num2str(filter_b, '%.6f '));
                    fprintf('    Filter coefficients a = [%s]\n', num2str(filter_a, '%.6f '));
                catch ME
                    fprintf('  Warning: Filter design failed: %s\n', ME.message);
                    fprintf('           Disabling filtering.\n');
                    filter_designed = false;
                end
            else
                fprintf('  Warning: Invalid normalized cutoff Wn = %.4f (must be in (0,1))\n', Wn);
                fprintf('           Disabling filtering.\n');
                filter_designed = false;
            end
        else
            fprintf('  Filtering is DISABLED (enable_filter = false).\n');
        end

        % STEP 3A: Calculate column-wise time (before simulation)
        % All signals in a column must be simulated to the same time
        % Each column corresponds to an OUTPUT controller (jj)
        fprintf('  Calculating column-wise times...\n');
        column_tfin = zeros(nCONTROL, 1);
        for jj = 1:nCONTROL  % Output controller (columns)
            % Use manual time for this OUTPUT controller (column)
            if ~isnan(tfin_manual(jj))
                column_tfin(jj) = tfin_manual(jj);
                fprintf('    Column %d (%s OUT): tfin = %.4f s (manual)\n', jj, ControlLabel{jj}, column_tfin(jj));
            else
                % Use automatic detection: find maximum among all rows in this column
                for nn_idx = 1:length(hDFIG)
                    for kk_idx = 1:length(all_output_DFIGs)
                        for ii = 1:nCONTROL  % Input controller (rows)
                            tfin_candidate = tfin_auto(ii,jj,nn_idx,kk_idx);
                            column_tfin(jj) = max(column_tfin(jj), tfin_candidate);
                        end
                    end
                end
                % Cap at maximum allowed time scale
                column_tfin(jj) = min(column_tfin(jj), max_time_cap);
                fprintf('    Column %d (%s OUT): tfin = %.4f s (auto)\n', jj, ControlLabel{jj}, column_tfin(jj));
            end
        end

        % STEP 3B: Compute impulse responses using column-wise times
        fprintf('  Computing impulse responses with column-wise times...\n');

        % Counters for debugging
        filter_success_count = 0;
        filter_fail_count = 0;
        filter_skip_count = 0;

        for nn_idx = 1:length(hDFIG)
            nn = hDFIG(nn_idx);
            for kk_idx = 1:length(all_output_DFIGs)
                kk = all_output_DFIGs(kk_idx);
                for ii = 1:nCONTROL
                    for jj = 1:nCONTROL
                        % Use column-specific time (already capped)
                        tfin = column_tfin(jj);

                        % Generate time vector with COMMON sampling frequency for filtering
                        num_samples = max(ceil(tfin * filter_fs), 1000);  % At least 1000 points
                        TimeArray{ii,jj,nn_idx,kk_idx} = linspace(0, tfin, num_samples);
                        time_vec = TimeArray{ii,jj,nn_idx,kk_idx};

                        % Construct and evaluate impulse response
                        indI = nCONTROL*(nn-1)+ii;
                        indO = nCONTROL*nDFIG + nCONTROL*(kk-1)+jj;
                        Sss = ss(matA,matB(:,indI),matC(indO,:),matD(indO,indI));

                        % Standard impulse response (Dirac delta with area=1)
                        y_raw = impulse(Sss, time_vec);

                        % Apply COMMON filter to all signals
                        if ~filter_designed
                            % Filter not designed - store raw
                            InterCellArray{ii,jj,nn_idx,kk_idx} = y_raw;
                            filter_skip_count = filter_skip_count + 1;
                        elseif length(y_raw) <= 3*filter_order
                            % Signal too short for filtering
                            InterCellArray{ii,jj,nn_idx,kk_idx} = y_raw;
                            filter_skip_count = filter_skip_count + 1;
                        else
                            % Attempt to filter
                            try
                                % Apply zero-phase filtering with common filter
                                y_filtered = filtfilt(filter_b, filter_a, y_raw);

                                % Validate filtered signal
                                if any(isnan(y_filtered)) || any(isinf(y_filtered))
                                    InterCellArray{ii,jj,nn_idx,kk_idx} = y_raw;
                                    filter_fail_count = filter_fail_count + 1;
                                else
                                    InterCellArray{ii,jj,nn_idx,kk_idx} = y_filtered;
                                    filter_success_count = filter_success_count + 1;
                                end
                            catch ME
                                % Filtering failed for this signal
                                InterCellArray{ii,jj,nn_idx,kk_idx} = y_raw;
                                filter_fail_count = filter_fail_count + 1;
                                if filter_fail_count <= 5  % Only show first 5 errors
                                    fprintf('  Warning: Filter failed for IN=%s, OUT=%s: %s\n', ...
                                            ControlLabel{ii}, ControlLabel{jj}, ME.message);
                                end
                            end
                        end
                    end
                end
            end
        end

        if filter_designed
            fprintf('  Zero-phase filtering completed:\n');
            fprintf('    - Success: %d signals\n', filter_success_count);
            fprintf('    - Failed: %d signals\n', filter_fail_count);
            fprintf('    - Skipped: %d signals (length <= %d)\n', filter_skip_count, 3*filter_order);
        end

        %------------------------------------------------------------------
        % STEP 4: GENERATE FIGURES (One 7×7 figure per input DFIG)
        %------------------------------------------------------------------
        for nn_idx = 1:length(hDFIG)
            nn = hDFIG(nn_idx);

            figure(nn_idx)
            set(gcf, 'Position', [50 + 50*nn_idx, 50, 1400, 900]);
            set(gcf, 'Color', 'w');

            % Array to store all axes handles for linking (organized by column)
            column_axes = cell(nCONTROL, 1);  % One cell per column
            for jj = 1:nCONTROL
                column_axes{jj} = gobjects(nCONTROL, 1);  % nCONTROL axes per column
            end

            % Plot all 7×7 combinations with column-specific time scales
            for ii = 1:nCONTROL  % Input controller (rows)
                for jj = 1:nCONTROL  % Output controller (columns)
                    column_axes{jj}(ii) = subplot(nCONTROL, nCONTROL, (ii-1)*nCONTROL + jj);
                    hold on

                    % Plot response for each output DFIG (overlay)
                    for kk_idx = 1:length(all_output_DFIGs)
                        kk = all_output_DFIGs(kk_idx);
                        time = TimeArray{ii,jj,nn_idx,kk_idx};
                        y = InterCellArray{ii,jj,nn_idx,kk_idx};
                        plot(time, y, 'LineWidth', 1.2)
                    end

                    grid on
                    % Use column-specific time scale (all signals in column simulated to same time)
                    xlim([0 column_tfin(jj)])

                    % Auto y-axis for better visibility (calculated AFTER plotting)
                    axis tight
                    ylims = ylim;
                    % Add 10% margin, handle zero-crossing signals
                    if ylims(1) < 0 && ylims(2) > 0
                        % Signal crosses zero
                        ylim([ylims(1)*1.1, ylims(2)*1.1]);
                    elseif abs(ylims(2) - ylims(1)) < 1e-10
                        % Flat signal (avoid division by zero)
                        ylim([ylims(1)-0.1, ylims(2)+0.1]);
                    else
                        % Normal signal
                        ylim([ylims(1)*1.1, ylims(2)*1.1]);
                    end

                    % TEXT OPTIMIZATION: Edge-only labels
                    % Column title only in top row (output controller name with OUT)
                    if ii == 1
                        title([ControlLabel{jj} ' (OUT)'], 'FontSize', fontsize_title, 'Interpreter', 'latex');
                    end

                    % X-label only in bottom row
                    if ii == nCONTROL
                        xlabel('t (s)', 'FontSize', fontsize_label);
                    else
                        set(gca, 'XTickLabel', []);
                    end

                    % Y-label: First column shows input controller name with IN
                    % All columns show Y-tick labels (independent scales per subplot)
                    if jj == 1
                        % First column: Show input controller name with IN
                        ylabel([ControlLabel{ii} ' (IN)'], 'FontSize', fontsize_label, 'Interpreter', 'latex');
                    end
                    % Note: YTickLabel is NOT removed - all subplots show their scale

                    % Tick label size and scientific notation fix
                    set(gca, 'FontSize', fontsize_tick);
                    % Disable automatic exponent notation (fixes ×10⁻³ issue)
                    ax = gca;
                    ax.XAxis.Exponent = 0;  % Force no exponent on X-axis

                    hold off
                end
            end

            % Link axes within each column for synchronized zoom and pan (X-axis only)
            % Each column has its own time scale
            % Y-axis remains independent per subplot for better visibility
            for jj = 1:nCONTROL
                linkaxes(column_axes{jj}, 'x');  % Link only X-axis (time axis) within column
            end

            % Super title with input DFIG information and simple text legend
            % Build legend with color indicators in brackets
            legend_str = sprintf('[Blue] %s  |  [Orange] %s', DFIGLabel{1}, DFIGLabel{2});
            title_str = sprintf('Impulse Response -- Input on DFIG %d (%s) -- %s', nn, DFIGLabel{nn_idx}, legend_str);
            h_title = sgtitle(title_str, 'FontSize', fontsize_suptitle, 'FontWeight', 'bold', 'Interpreter', 'none');
            set(h_title, 'Color', 'black');  % Force black color
        end

        fprintf('Case 3: Generated %d figure(s) with 7x7 layout.\n', length(hDFIG));
   %--------------------------------------------------------------
    case 4 % Correlation between controllers in the same DFIG and color maps
   %--------------------------------------------------------------
        % =====================================================================
        % CASE 4: CONTROLLER INTERACTION ANALYSIS WITHIN SAME DFIG
        % =====================================================================
        %
        % PURPOSE:
        %   Quantify and visualize the interaction level between different
        %   controllers within the same DFIG using correlation analysis of
        %   impulse responses. This reveals which controllers are strongly
        %   coupled and how active/reactive power control paths interact.
        %
        % METHODOLOGY:
        %   1. Compute impulse responses for all 7×7 input-output combinations
        %      (each controller as input, each controller as output)
        %   2. Calculate Pearson correlation coefficients between impulse
        %      response pairs to quantify interaction strength
        %   3. Analyze active power vs reactive power controller interactions
        %   4. Visualize correlation matrices as color maps (heat maps)
        %
        % CORRELATION INTERPRETATION:
        %   - corr ≈ 1.0: Strong interaction (output highly influenced by input)
        %   - corr ≈ 0.5: Moderate interaction
        %   - corr ≈ 0.0: Weak interaction (minimal coupling between controllers)
        %   - Diagonal elements = 1.0 (self-correlation, always perfect)
        %
        % CONTROLLER CLASSIFICATION:
        %   Active power controllers:   VSMP, RSCd, VDC, GSCq [indices 1,4,5,7]
        %   Reactive power controllers: VSMQ, RSCq, GSCd [indices 2,3,6]
        %
        % OUTPUT:
        %   - 1 figure with 2 subplots (SCR trafo = 10 and SCR trafo = 5)
        %   - Color maps showing 7×7 correlation matrices
        %   - Annotations showing average interaction per controller
        %   - Console output: sorted controllers by interaction level
        %   - Console output: active vs reactive interaction statistics
        %
        % FIGURE FORMAT (PAPER-READY):
        %   - Figure size: 17 cm width × 5 cm height (IEEE standard)
        %   - Color map: White (0) to Black (1) in 10 steps
        %   - Controllers ordered: [VSMP RSCd VDC GSCq VSMQ RSCq GSCd]
        %     (active first, then reactive for clear block structure)
        %   - Single shared colorbar on the right
        %   - Average interaction values annotated for each controller
        %
        % =====================================================================

        % Time vector for impulse response computation
        time = linspace(0,1,2000);  % 1s duration, 2000 points (paper tf=1s, page 6)

        % DFIGs to analyze (1 = SCR trafo 10, 3 = SCR trafo 5)
        hDFIG = [1 3];

        % ---------------------------------------------------------------
        % STEP 1: COMPUTE ALL IMPULSE RESPONSES (7×7×2 tensor)
        % ---------------------------------------------------------------
        % Storage: InterCellArray{input_controller, output_controller, DFIG}
        InterCellArray = cell(nCONTROL,nCONTROL,length(hDFIG));

        for nn = 1:2  % Loop over DFIGs
           for ii = 1:nCONTROL  % Loop over input controllers
               for jj = 1:nCONTROL  % Loop over output controllers
                   % Input index: controller ii in DFIG hDFIG(nn)
                   indI = nCONTROL*(hDFIG(nn)-1)+ii;

                   % Output index: controller jj in same DFIG (closed-loop output)
                   indO = nCONTROL*nDFIG + nCONTROL*(hDFIG(nn)-1)+jj;

                   % Extract sensitivity transfer function S(s) = y_out / r_in
                   % This represents how reference input ii affects output jj
                   Sss = ss(matA,matB(:,indI),matC(indO,:),matD(indO,indI));

                   % Compute and store impulse response
                   InterCellArray{ii,jj,nn} = impulse(Sss,time);
               end
           end
        end

        % ---------------------------------------------------------------
        % STEP 2: COMPUTE CORRELATION MATRIX (7×7×2)
        % ---------------------------------------------------------------
        % Correlation measures similarity between impulse responses:
        %   - Compare reference response (ii,ii) with cross-response (ii,jj)
        %   - High correlation → strong interaction between controllers
        %   - Uses Pearson correlation coefficient (MATLAB corrcoef)
        %
        corrMatrix = NaN(nCONTROL,nCONTROL,length(hDFIG));

        for nn = 1:2  % Loop over DFIGs
           for ii = 1:nCONTROL  % Loop over input controllers
               for jj = 1:nCONTROL  % Loop over output controllers
                   % Compute correlation between:
                   %   - Reference: input ii → output ii (diagonal element)
                   %   - Cross-term: input ii → output jj (off-diagonal)
                   % This quantifies how much output jj is affected by input ii
                   % NOTE: Correlation preserves sign (-1 to +1), as per paper equation (17)
                   %       Absolute value is only applied for means and visualization
                   aux = corrcoef(InterCellArray{ii,ii,nn},InterCellArray{ii,jj,nn});
                   corrMatrix(ii,jj,nn) = aux(1,2);  % Extract signed correlation value
               end
           end
        end

        % ---------------------------------------------------------------
        % STEP 3: ANALYZE INTERACTION STATISTICS
        % ---------------------------------------------------------------
        % Create single figure with 2 subplots (IEEE paper format)
        % TALL figure so square heatmaps fill the colorbar height
        fig = figure('Position', [100 100 1600 900], 'Color', 'w', 'Renderer', 'painters');
        annText = zeros(7,1,2);  % Storage for average correlation per controller
        ax_handles = gobjects(2,1);  % Store axis handles for later formatting

        for nn = 1:2  % Loop over DFIGs
            % Extract correlation matrix for current DFIG (signed values -1 to +1)
            aux = squeeze(corrMatrix(:,:,nn));

            % Compute average interaction per controller (row mean excluding diagonal)
            % NOTE: Paper equation (18) defines IIdx = (1/(n-1)) * Σ |ρij| (j≠i)
            % Means are calculated using ABSOLUTE values of correlations
            % Diagonal elements = 1 (perfect self-correlation)
            % Average correlation = (sum(abs(row)) - 1) / (n-1)
            % Subtract 1 to exclude perfect self-correlation on diagonal
            corrRowMean = (sum(abs(aux),2) - 1) / (nCONTROL-1);
            annText(:,:,nn) = corrRowMean(:);  % Store for later annotation

            % Sort controllers by interaction level (highest to lowest)
            [~,indControl] = sort(corrRowMean,'descend');

            % Display ranking of controllers by interaction strength
            disp(['DFIG with ' DFIGLabel{nn} ': Controllers sorted by their interaction level'])
            disp(ControlLabel(indControl)')
            disp(corrRowMean(indControl)')

            % ---------------------------------------------------------------
            % ANALYZE ACTIVE vs REACTIVE POWER CONTROLLER INTERACTIONS
            % ---------------------------------------------------------------
            % Active power path:   VSMP(1), RSCd(4), VDC(5), GSCq(7)
            % Reactive power path: VSMQ(2), RSCq(3), GSCd(6)
            %
            activeControl = [1 4 5 7];
            reactiveControl = [2 3 6];

            % Average correlation within active power controllers (using absolute values)
            corrActiveControl = (sum(sum(abs(aux(activeControl,activeControl))))-length(activeControl))/(length(activeControl)*(length(activeControl)-1));

            % Average correlation within reactive power controllers (using absolute values)
            corrReactiveControl = (sum(sum(abs(aux(reactiveControl,reactiveControl))))-length(reactiveControl))/(length(reactiveControl)*(length(reactiveControl)-1));

            % Average cross-correlation: active → reactive (using absolute values)
            corrARControl = sum(sum(abs(aux(activeControl,reactiveControl))))/(length(reactiveControl)*length(activeControl));

            % Average cross-correlation: reactive → active (using absolute values)
            corrRAControl = sum(sum(abs(aux(reactiveControl,activeControl))))/(length(reactiveControl)*length(activeControl));

            % Display interaction matrix:
            %   [Active-Active    Active-Reactive  ]
            %   [Reactive-Active  Reactive-Reactive]
            disp(['DFIG with ' DFIGLabel{nn} ': Correlation mean between active and reactive controllers'])
            disp([corrActiveControl corrARControl ; corrRAControl  corrReactiveControl])

            % ---------------------------------------------------------------
            % STEP 4: GENERATE CORRELATION COLOR MAP (HEAT MAP)
            % ---------------------------------------------------------------
            % Controller ordering: Active first [1 4 5 7], then reactive [2 3 6]
            % This ordering creates clear block structure showing:
            %   - Top-left block: Active-Active interactions
            %   - Bottom-right block: Reactive-Reactive interactions
            %   - Off-diagonal blocks: Active-Reactive cross-coupling
            %
            idxControlOrder = [1 4 5 7 2 3 6];  % Active and reactive grouping
            % Alternative: idxControlOrder = indControl;  % Sorted by interaction level

            % Display reordered correlation matrix in console
            disp(['DFIG with ' DFIGLabel{nn} ': Correlation matrix'])
            disp(ControlLabel(idxControlOrder)')
            disp(squeeze(corrMatrix(idxControlOrder,idxControlOrder,nn)))
        end

        % ---------------------------------------------------------------
        % CREATE CUSTOM GRAYSCALE COLORMAP (WHITE → BLACK)
        % ---------------------------------------------------------------
        % Colormap design:
        %   - White (RGB = 1,1,1) for correlation = 0 (no interaction)
        %   - Black (RGB = 0,0,0) for correlation = 1 (perfect interaction)
        %   - 10 discrete steps for clear visual distinction
        %
        kColorSteps = 10;
        myColorMap.map = zeros(kColorSteps,3);
        myColorMap.map(:,1) = linspace(1,0,kColorSteps);  % Red: 1→0
        myColorMap.map(:,2) = linspace(1,0,kColorSteps);  % Green: 1→0
        myColorMap.map(:,3) = linspace(1,0,kColorSteps);  % Blue: 1→0

        % ---------------------------------------------------------------
        % STEP 5: PLOT SELF-INTERACTION MATRICES WITH MODERN FORMATTING
        % ---------------------------------------------------------------
        for nn = 1:2  % Loop over DFIGs
            % ---------------------------------------------------------------
            % PLOT COLOR MAP FOR CURRENT DFIG (IEEE STYLE)
            % ---------------------------------------------------------------
            ax = subplot(1,2,nn);
            ax_handles(nn) = ax;

            % Plot heatmap using SIMPLE imagesc (like original JGA code)
            imagesc(abs(squeeze(corrMatrix(idxControlOrder,idxControlOrder,nn))))

            colormap(gca,myColorMap.map)
            clim([0 1])

            % CRITICAL: Force square cells
            axis equal tight

            % CRITICAL: Disable ALL grids and move ticks outside
            grid off
            set(ax, 'XGrid', 'off', 'YGrid', 'off', 'XMinorGrid', 'off', 'YMinorGrid', 'off');
            set(ax, 'GridLineStyle', 'none', 'MinorGridLineStyle', 'none');
            set(ax, 'TickDir', 'out');  % Move tick marks OUTSIDE plot area
            set(ax, 'TickLength', [0.01 0.01]);  % Short tick marks
            set(ax, 'Layer', 'top');  % Draw axis on top

            % Set axis limits to show only the 7x7 matrix
            xlim([0.5 7.5]);
            ylim([0.5 7.5]);

            % Set axis labels (controller names) - CRITICAL: LARGEST font
            set(ax, 'XTick', 1:7, 'YTick', 1:7);
            set(ax, 'XTickLabel', ControlLabel(idxControlOrder));
            if nn == 1
                set(ax, 'YTickLabel', ControlLabel(idxControlOrder));
            else
                set(ax, 'YTickLabel', {});  % No Y labels on second subplot
            end
            % Set font properties - LARGE for visibility in IEEE paper
            ax.FontSize = 14;  % Tick labels font size
            ax.FontName = 'Times New Roman';
            ax.XColor = [0 0 0];
            ax.YColor = [0 0 0];
            set(ax, 'TickLabelInterpreter', 'none');

            % Rotate X-axis labels
            xtickangle(90);

            % Set box with proper line width
            box on
            set(ax, 'LineWidth', 1.5);

            % Add DFIG label above matrix - LARGER font
            text(4, -0.5, sprintf('DFIG%d', hDFIG(nn)), 'FontSize', 18, 'FontName', 'Times New Roman', ...
                 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', 'k', 'Interpreter', 'none');

            % Set fixed position - SQUARE axes to match colorbar height
            % Position: [left bottom width height]
            % Width must equal height to maintain square aspect with 'axis equal tight'
            % ULTRA COMPACT Layout (zero gaps): Left(0.40) + AV1(0.06) + Right(0.40) + AV2(0.06) + CB(0.02) = 0.94
            if nn == 1
                set(ax, 'Position', [0.05 0.20 0.40 0.40]);  % Left subplot - minimal left margin
            else
                set(ax, 'Position', [0.51 0.20 0.40 0.40]);  % Right subplot - no gap, starts where AV1 ends
            end
        end

        % Add single global colorbar on the far right (IEEE formatting)
        cb = colorbar(ax_handles(2), 'Location', 'manual', 'FontName', 'Times New Roman', 'FontSize', 14);
        cb.Label.String = '';  % No label, just scale
        cb.Label.FontSize = 18;
        cb.Label.FontName = 'Times New Roman';
        cb.Label.Color = [0 0 0];
        cb.Color = [0 0 0];
        set(cb, 'TickLabelInterpreter', 'none');

        % Position colorbar - after AV2 column ends (~0.968)
        cb.Position = [0.97 0.20 0.02 0.40];

        % Set colorbar ticks - ONLY 0 and 1 at extremes
        cb.Ticks = [0 1];
        cb.TickLabels = {'0', '1'};
        cb.TickDirection = 'out';
        cb.AxisLocation = 'out';

        % ---------------------------------------------------------------
        % ADD AV COLUMNS AS ANNOTATIONS (outside axes, like JGA code)
        % ---------------------------------------------------------------
        % Calculate positions for AV columns - NO GAP with checkerboards
        pos1 = get(ax_handles(1), 'Position');
        pos2 = get(ax_handles(2), 'Position');
        x0 = [
            sum(pos1([1 3])) - 0.002  % RIGHT EDGE minus offset to eliminate visual gap
            sum(pos2([1 3])) - 0.002  % RIGHT EDGE minus offset to eliminate visual gap
        ];
        y0 = pos1(2);  % Bottom position (matches subplot)
        dy = pos1(4) / 7;  % Height per row (matches subplot height / 7)
        dx = 0.06;  % Width of annotation box (wider for better readability)

        % Add AV columns for both subplots
        for subplot_idx = 1:2
            % Define AV label based on DFIG (Av1 or Av3)
            av_label = sprintf('Av%d', hDFIG(subplot_idx));

            % Add AV header - BLACK text, no border
            annotation(fig, 'textbox', [x0(subplot_idx) y0+dy*6.8 dx dy], ...
                'String', av_label, ...
                'EdgeColor', 'none', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 14, ...
                'FontName', 'Times New Roman', ...
                'FontWeight', 'bold', ...
                'Color', [0 0 0], ...
                'Interpreter', 'none');

            % Add average values for each controller row
            for row_idx = 1:7
                % Calculate y position (bottom to top, matching matrix rows)
                y_pos = y0 + dy * (row_idx - 1);

                % Get average value for this controller (already stored in annText)
                avg_value = annText(idxControlOrder(8-row_idx), 1, subplot_idx);

                % Add annotation box with value
                annotation(fig, 'textbox', [x0(subplot_idx) y_pos dx dy], ...
                    'String', sprintf('%.2f', avg_value), ...
                    'EdgeColor', [0 0 0], ...
                    'LineWidth', 1.0, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 14, ...
                    'FontName', 'Times New Roman', ...
                    'Color', [0 0 0], ...
                    'Interpreter', 'none');
            end
        end
   %--------------------------------------------------------------
    case 5 % Cross-correlation between DFIGs and color maps
   %--------------------------------------------------------------
        % =====================================================================
        % CASE 5: CROSS-CORRELATION BETWEEN DIFFERENT DFIGs
        % =====================================================================
        %
        % PURPOSE:
        %   Quantify and visualize the interaction level between controllers
        %   in DIFFERENT DFIGs (inter-turbine coupling). This reveals how
        %   controllers in one DFIG affect controllers in another DFIG through
        %   the electrical network.
        %
        % METHODOLOGY:
        %   1. Compute impulse responses for all input-output combinations
        %      between two different DFIGs (7×7×2×2 tensor)
        %   2. Calculate Pearson correlation between impulse response pairs
        %   3. Generate 4 correlation matrices (2×2 DFIG combinations):
        %      - DFIG 1 → DFIG 1 (self-interaction, same as case 4)
        %      - DFIG 1 → DFIG 3 (cross-interaction)
        %      - DFIG 3 → DFIG 1 (cross-interaction, reverse)
        %      - DFIG 3 → DFIG 3 (self-interaction, same as case 4)
        %
        % KEY DIFFERENCE FROM CASE 4:
        %   - Case 4: Input and output in SAME DFIG (nn = kk)
        %   - Case 5: Input in one DFIG (nn), output in another DFIG (kk)
        %
        % CORRELATION INTERPRETATION:
        %   - corrMatrix(ii,jj,nn,kk): Correlation when controller ii in
        %     DFIG nn is excited and controller jj in DFIG kk is measured
        %   - High correlation in cross-terms (nn≠kk) → strong electrical
        %     coupling between turbines
        %
        % OUTPUT:
        %   - 4 separate figures (one per DFIG combination)
        %   - Color maps showing 7×7 correlation matrices
        %   - Console output: correlation matrices for each combination
        %
        % =====================================================================

        % Time vector for impulse response computation
        time = linspace(0,1,2000);  % 1s duration, 2000 points (paper tf=1s, page 6)

        % DFIGs to analyze (1 = SCR trafo 10, 3 = SCR trafo 5)
        hDFIG = [1 3];

        % ---------------------------------------------------------------
        % STEP 1: COMPUTE ALL CROSS-DFIG IMPULSE RESPONSES (7×7×2×2)
        % ---------------------------------------------------------------
        % Storage: InterCellArray{input_ctrl, output_ctrl, input_DFIG, output_DFIG}
        InterCellArray = cell(nCONTROL,nCONTROL,length(hDFIG),length(hDFIG));

        for nn = 1:2  % Loop over input DFIGs
            for kk = 1:2  % Loop over output DFIGs
                for ii = 1:nCONTROL  % Loop over input controllers
                    for jj = 1:nCONTROL  % Loop over output controllers
                        % Input index: controller ii in DFIG hDFIG(nn)
                        indI = nCONTROL*(hDFIG(nn)-1)+ii;

                        % Output index: controller jj in DFIG hDFIG(kk)
                        % Note: Output can be in a DIFFERENT DFIG (kk ≠ nn)
                        indO = nCONTROL*nDFIG + nCONTROL*(hDFIG(kk)-1)+jj;

                        % Extract sensitivity transfer function
                        % S(s) = output in DFIG kk / input in DFIG nn
                        Sss = ss(matA,matB(:,indI),matC(indO,:),matD(indO,indI));

                        % Compute and store impulse response
                        InterCellArray{ii,jj,nn,kk} = impulse(Sss,time);
                    end
                end
            end
        end

        % ---------------------------------------------------------------
        % STEP 2: COMPUTE CROSS-CORRELATION MATRICES (7×7×2×2)
        % ---------------------------------------------------------------
        % Correlation measures similarity between impulse responses:
        %   - Reference: input ii → output ii in SAME DFIG nn
        %   - Cross-term: input ii in DFIG nn → output jj in DFIG kk
        %
        corrMatrix = NaN(nCONTROL,nCONTROL,length(hDFIG),length(hDFIG));

        for nn = 1:2  % Loop over input DFIGs
            for kk = 1:2  % Loop over output DFIGs
                for ii = 1:nCONTROL  % Loop over input controllers
                    for jj = 1:nCONTROL  % Loop over output controllers
                        % Compute correlation between:
                        %   - Reference: input ii → output ii in DFIG nn (diagonal, self)
                        %   - Cross-term: input ii in DFIG nn → output jj in DFIG kk
                        % This quantifies inter-DFIG coupling strength
                        % NOTE: Correlation preserves sign (-1 to +1), as per paper equation (17)
                        %       Absolute value is only applied for means and visualization
                        aux = corrcoef(InterCellArray{ii,ii,nn,nn},InterCellArray{ii,jj,nn,kk});
                        corrMatrix(ii,jj,nn,kk) = aux(1,2);  % Extract signed correlation value
                    end
                end
            end
        end
        % ---------------------------------------------------------------
        % STEP 3: GENERATE CROSS-CORRELATION COLOR MAPS (2 SUBPLOTS)
        % ---------------------------------------------------------------
        % Create 1 figure with 2 subplots showing only cross-interactions:
        %   - Left subplot: DFIG 1 → DFIG 3 (SCR 10 → SCR 5)
        %   - Right subplot: DFIG 3 → DFIG 1 (SCR 5 → SCR 10)
        % Skip self-interactions (nn=kk) as they are shown in case 4
        %
        % Controller ordering: Active first [VSMP RSCd VDC GSCq], then reactive [VSMQ RSCq GSCd]
        % Same ordering as case 4 for consistency
        idxControlOrder = [1 4 5 7 2 3 6];

        % ---------------------------------------------------------------
        % CREATE CUSTOM GRAYSCALE COLORMAP (WHITE → BLACK)
        % ---------------------------------------------------------------
        kColorSteps = 10;
        myColorMap.map = zeros(kColorSteps,3);
        myColorMap.map(:,1) = linspace(1,0,kColorSteps);  % Red: 1→0
        myColorMap.map(:,2) = linspace(1,0,kColorSteps);  % Green: 1→0
        myColorMap.map(:,3) = linspace(1,0,kColorSteps);  % Blue: 1→0

        % Create single figure with 2 subplots (IEEE paper format)
        % TALL figure so square heatmaps fill the colorbar height
        fig = figure('Position', [100 100 1600 900], 'Color', 'w', 'Renderer', 'painters');

        % ---------------------------------------------------------------
        % COMPUTE AVERAGE CROSS-CORRELATION PER ROW
        % ---------------------------------------------------------------
        % Calculate mean correlation for each input controller (row-wise)
        % This shows how strongly each input controller affects outputs
        % in the OTHER DFIG
        annText = zeros(7,1,2);  % Storage: [7 controllers, 1, 2 cross-cases]
        cross_idx = 0;
        for nn = 1:2
            for kk = 1:2
                if nn == kk
                    continue;  % Skip self-interactions
                end
                cross_idx = cross_idx + 1;

                % Extract cross-correlation matrix for current combination (signed values -1 to +1)
                aux = squeeze(corrMatrix(:,:,nn,kk));

                % Compute average correlation per input controller (row mean INCLUDING diagonal)
                % NOTE: For cross-correlation, diagonal represents same controller type in different DFIGs
                % This is INFORMATIVE (shows inter-DFIG coupling), so we INCLUDE it
                % Means are calculated using ABSOLUTE values of correlations
                % Average correlation = sum(abs(row)) / n (all 7 elements)
                corrRowMean = sum(abs(aux),2) / nCONTROL;
                annText(:,:,cross_idx) = corrRowMean(:);
            end
        end

        subplot_idx = 0;
        ax_handles = zeros(1,2);  % Preallocate axis handles for performance
        for nn = 1:2  % Loop over input DFIGs
            for kk = 1:2  % Loop over output DFIGs
                % Skip self-interactions (diagonal cases)
                if nn == kk
                    continue;
                end

                subplot_idx = subplot_idx + 1;

                % Display correlation matrix in console
                disp(['DFIGs ' num2str(hDFIG(nn)) ' -> ' num2str(hDFIG(kk)) ': Cross-correlation matrix'])
                disp(ControlLabel(idxControlOrder)')
                disp(squeeze(corrMatrix(idxControlOrder,idxControlOrder,nn,kk)))

                % ---------------------------------------------------------------
                % PLOT COLOR MAP FOR CURRENT DFIG COMBINATION (IEEE STYLE)
                % ---------------------------------------------------------------
                ax = subplot(1,2,subplot_idx);
                ax_handles(subplot_idx) = ax;

                % Plot heatmap using SIMPLE imagesc (like original JGA code)
                imagesc(abs(squeeze(corrMatrix(idxControlOrder,idxControlOrder,nn,kk))))

                colormap(gca,myColorMap.map)
                clim([0 1])

                % CRITICAL: Force square cells
                axis equal tight

                % CRITICAL: Disable ALL grids and move ticks outside
                grid off
                set(ax, 'XGrid', 'off', 'YGrid', 'off', 'XMinorGrid', 'off', 'YMinorGrid', 'off');
                set(ax, 'GridLineStyle', 'none', 'MinorGridLineStyle', 'none');
                set(ax, 'TickDir', 'out');  % Move tick marks OUTSIDE plot area
                set(ax, 'TickLength', [0.01 0.01]);  % Short tick marks
                set(ax, 'Layer', 'top');  % Draw axis on top

                % Set axis limits to show only the 7x7 matrix
                xlim([0.5 7.5]);
                ylim([0.5 7.5]);

                % Set axis labels (controller names) - CRITICAL: LARGEST font
                set(ax, 'XTick', 1:7, 'YTick', 1:7);
                set(ax, 'XTickLabel', ControlLabel(idxControlOrder));
                if subplot_idx == 1
                    set(ax, 'YTickLabel', ControlLabel(idxControlOrder));
                else
                    set(ax, 'YTickLabel', {});  % No Y labels on second subplot
                end
                % Set font properties - LARGE for visibility in IEEE paper
                ax.FontSize = 14;  % Tick labels font size
                ax.FontName = 'Times New Roman';
                ax.XColor = [0 0 0];
                ax.YColor = [0 0 0];
                set(ax, 'TickLabelInterpreter', 'none');

                % Rotate X-axis labels
                xtickangle(90);

                % Set box with proper line width
                box on
                set(ax, 'LineWidth', 1.5);

                % Add DFIG cross-interaction label above matrix - LARGER font
                text(4, -0.5, sprintf('From DFIG%d to DFIG%d', hDFIG(nn), hDFIG(kk)), 'FontSize', 18, 'FontName', 'Times New Roman', ...
                     'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', 'k', 'Interpreter', 'none');

                % Set fixed position - SQUARE axes to match colorbar height
                % Position: [left bottom width height]
                % Width must equal height to maintain square aspect with 'axis equal tight'
                % ULTRA COMPACT Layout (zero gaps): Left(0.40) + AV1(0.06) + Right(0.40) + AV2(0.06) + CB(0.02) = 0.94
                if subplot_idx == 1
                    set(ax, 'Position', [0.05 0.20 0.40 0.40]);  % Left subplot - minimal left margin
                else
                    set(ax, 'Position', [0.51 0.20 0.40 0.40]);  % Right subplot - no gap, starts where AV1 ends
                end
            end
        end

        % Add single global colorbar on the far right (IEEE formatting)
        cb = colorbar(ax_handles(2), 'Location', 'manual', 'FontName', 'Times New Roman', 'FontSize', 14);
        cb.Label.String = '';  % No label, just scale
        cb.Label.FontSize = 18;
        cb.Label.FontName = 'Times New Roman';
        cb.Label.Color = [0 0 0];
        cb.Color = [0 0 0];
        set(cb, 'TickLabelInterpreter', 'none');

        % Position colorbar - after AV2 column ends (~0.968)
        cb.Position = [0.97 0.20 0.02 0.40];

        % Set colorbar ticks - ONLY 0 and 1 at extremes
        cb.Ticks = [0 1];
        cb.TickLabels = {'0', '1'};
        cb.TickDirection = 'out';
        cb.AxisLocation = 'out';

        % ---------------------------------------------------------------
        % ADD AV COLUMNS AS ANNOTATIONS (outside axes, like JGA code)
        % ---------------------------------------------------------------
        % Calculate positions for AV columns - NO GAP with checkerboards
        pos1 = get(ax_handles(1), 'Position');
        pos2 = get(ax_handles(2), 'Position');
        x0 = [
            sum(pos1([1 3])) - 0.002  % RIGHT EDGE minus offset to eliminate visual gap
            sum(pos2([1 3])) - 0.002  % RIGHT EDGE minus offset to eliminate visual gap
        ];
        y0 = pos1(2);  % Bottom position (matches subplot)
        dy = pos1(4) / 7;  % Height per row (matches subplot height / 7)
        dx = 0.06;  % Width of annotation box (wider for better readability)

        % Add AV columns for both subplots
        % Define cross-interaction labels: Av13 (DFIG1→DFIG3) and Av31 (DFIG3→DFIG1)
        av_labels = {'Av13', 'Av31'};  % subplot_idx 1 = 1→3, subplot_idx 2 = 3→1

        for subplot_idx = 1:2
            % Add AV header - BLACK text, no border
            annotation(fig, 'textbox', [x0(subplot_idx) y0+dy*6.8 dx dy], ...
                'String', av_labels{subplot_idx}, ...
                'EdgeColor', 'none', ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'bottom', ...
                'FontSize', 14, ...
                'FontName', 'Times New Roman', ...
                'FontWeight', 'bold', ...
                'Color', [0 0 0], ...
                'Interpreter', 'none');

            % Add AV values with borders - BLACK text
            for row = 1:7
                % Create textbox with border and BLACK text
                annotation(fig, 'textbox', [x0(subplot_idx) y0+dy*(row-1) dx dy], ...
                    'String', sprintf('%.2f', annText(idxControlOrder(8-row), 1, subplot_idx)), ...
                    'EdgeColor', 'k', ...
                    'LineWidth', 1.0, ...
                    'BackgroundColor', 'w', ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 14, ...
                    'FontName', 'Times New Roman', ...
                    'Color', [0 0 0], ...
                    'Interpreter', 'none');
            end
        end

        % Apply post-processing for paper-ready format (reuse case 4 script)
        % postProcessing_Dameros_Interacciones_Cross  % COMMENTED: Script not found

   %--------------------------------------------------------------
    case 6 % System-level response to power reference steps (f and PCC voltage)
   %--------------------------------------------------------------
        % WHAT THIS FIGURE SHOWS:
        %   Grid frequency (f) and PCC voltage (Vpcc) responses to step changes in
        %   active (P) and reactive (Q) power references. Demonstrates system-level
        %   impact of wind farm control actions on grid stability.
        %
        % CONTROL THEORY:
        %   - Closed-loop system response from P_ref → f, Q_ref → Vpcc
        %   - Transfer function: Y(s)/U(s) where U = [Pref, Qref], Y = [f, Vpcc]
        %   - Extracted from linearized state-space model (matA, matB, matC, matD)
        %
        % SUBPLOT STRUCTURE (2×2 grid):
        %   Row 1 (P reference step):
        %     - (1,1): Frequency response to P step
        %     - (1,2): PCC voltage response to P step
        %   Row 2 (Q reference step):
        %     - (2,1): Frequency response to Q step
        %     - (2,2): PCC voltage response to Q step
        %
        % LEGEND INTERPRETATION:
        %   Blue line:   DFIG 1 response (strong grid, SCR_trafo = 10)
        %   Orange line: DFIG 3 response (weak grid, SCR_trafo = 5)
        %
        % WHAT TO LOOK FOR:
        %   - P-f coupling: Active power affects frequency (primary control)
        %   - Q-V coupling: Reactive power affects voltage (voltage control)
        %   - Cross-coupling: P→Vpcc and Q→f interactions (weak grids)
        %   - ROCOF: Rate of change of frequency (grid stability metric)
        %   - Nadir: Minimum frequency deviation (protection threshold)
        %   - Grid strength impact: Weak grids show larger deviations
        %
        % KEY METRICS COMPUTED:
        %   ROCOF: Rate at half steady-state (df/dt or dV/dt)
        %   Nadir: Maximum deviation from initial value
        %
        % OUTPUT: Single figure with 4 subplots, metrics displayed in console
        %

        % Select DFIGs for comparison: strong grid vs weak grid
        hDFIG = [1 3];

        figure(1)

        % Time vector and labels (extended to reach steady-state)
        t = {linspace(0,50,1000); linspace(0,50,1000)};
        outLabel = {'Frequency (pu)', 'PCC voltage (pu)'};
        titleLabel = {'P reference step', 'Q reference step'};

        % Initialize metric matrices [nDFIG × nOutputs]
        ROCOX = NaN(2,2);  % Rate of change: row = DFIG, col = [f, Vpcc]
        nadir = NaN(2,2);  % Maximum deviation (same structure)

        % Generate 2×2 subplot grid
        for nn = 1:2  % Loop over input references: 1=P, 2=Q
            subplot
            for ii = 1:2  % Loop over outputs: 1=f, 2=Vpcc
                for jj = 1:length(hDFIG)  % Loop over DFIGs
                    subplot(2,2,2*(nn-1)+ii)

                    % Extract input-output indices from linearized model
                    % Input structure: [T1...T14, S1...S14, Pref1, Qref1, Pref2, Qref2, ...]
                    indI = nCONTROL*nDFIG + nDFIG*(nn-1) + hDFIG(jj);
                    % Output structure: [..., f, Vpcc]
                    indO = 2*nCONTROL*nDFIG + ii;

                    % Build closed-loop transfer function: Y(s)/U(s)
                    Fss = ss(matA, matB(:,indI), matC(indO,:), matD(indO,indI));

                    % Compute step response
                    y = step(Fss, t{ii});

                    % Plot with publication-ready formatting
                    hold on
                    plot(t{ii}, y, 'LineWidth', 1.5)

                    % Compute ROCOF/ROCOV at half steady-state (linear region)
                    if nn==1 && ii==1  % P reference → Frequency
                        [~,ind] = min(abs(y - y(end)/2));
                        ROCOX(jj,ii) = y(ind) / t{ii}(ind);
                        nadir(jj,ii) = max(abs(y));
                    end
                    if nn==2 && ii==2  % Q reference → PCC voltage
                        [~,ind] = min(abs(y - y(end)/2));
                        ROCOX(jj,ii) = y(ind) / t{ii}(ind);
                        nadir(jj,ii) = max(abs(y));
                    end
                end

                % Format subplot
                xlabel('$t$ (s)', 'Interpreter', 'latex')
                ylabel(outLabel{ii}, 'Interpreter', 'latex')
                xlim([0 t{ii}(end)])
                title(titleLabel{nn}, 'Interpreter', 'latex')
                grid on
                box on

                % Add legend (only for first subplot to avoid clutter)
                if nn==1 && ii==1
                    leg = legend('SCR trafo = 10', 'SCR trafo = 5', 'Location', 'best');
                    set(leg, 'Interpreter', 'latex', 'Color', 'white', ...
                             'EdgeColor', 'black', 'TextColor', 'black')
                end

                hold off
            end
        end

        % Apply publication formatting
        format_figure_for_publication(figure(1))

        % Display computed metrics
        disp('=== CASE 6: System-level response metrics ===')
        disp('DFIG configuration: [1 (SCR=10), 3 (SCR=5)]')
        disp(' ')
        disp('ROCOF/ROCOV [pu/s] - Rate at half steady-state:')
        disp('           f        Vpcc')
        disp(ROCOX)
        disp(' ')
        disp('Nadir [pu] - Maximum deviation:')
        disp('           f        Vpcc')
        disp(nadir)
        
   %--------------------------------------------------------------
    case 7 % PLANT & OPEN-LOOP ANALYSIS - Nichols plot (Black diagram)
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   Nichols plots comparing plant P(jω) and open-loop L(jω) = C(jω)P(jω).
    %   Essential for understanding how the controller shapes the plant dynamics.
    %
    % LEGEND INTERPRETATION:
    %   Blue line   (Plant):     P(jω) = Plant transfer function (no controller)
    %   Orange line (Open loop): L(jω) = C(jω)P(jω) (controller × plant)
    %
    % WHAT TO LOOK FOR:
    %   - Separation between lines → Controller gain/phase contribution
    %   - Open-loop crossing of 0dB at -180° → Critical stability point
    %   - Phase margin (horizontal distance from -180° at 0dB)
    %   - Gain margin (vertical distance from 0dB at -180°)
    %   - Orange line farther from critical point → Controller improves stability
    %
    % OUTPUT: 2 figures (SCR 10 and SCR 5), each with 7 Nichols plots
    %         Also computes and displays stability margins (console output)
    %
        logf = [-2 2.25 ; -2 2 ; 0 3 ; 0 3 ; 0.5 3 ; 1.5 3 ; 1.5 3];
        hDFIG = [1 3];  % DFIG indices
        Am = NaN(length(hDFIG),7); Fm = NaN(length(hDFIG),7);
        wu = NaN(length(hDFIG),7); wo = NaN(length(hDFIG),7);
        plant_stab = NaN(length(hDFIG),7); plant_minDamp = NaN(length(hDFIG),7);
        plant_wn = NaN(length(hDFIG),7); plant_maxRealEig = NaN(length(hDFIG),7);
        % fsolve options
        opt_fsolve = optimoptions('fsolve');
        opt_fsolve.MaxIterations = 5000;
        opt_fsolve.Display = 'off';
        % plot options
        plotoptions = nicholsoptions;
        plotoptions.PhaseWrapping = 'off';
        plotoptions.PhaseMatching = 'on';
        plotoptions.PhaseMatchingFreq = 5;
        plotoptions.PhaseMatchingValue = -180;
        % Initial crossover frequency (rad/s)
        w_ini = [10 2.5*2*pi 350 350 100 500 500];
        for ii = 1:length(hDFIG)
            figure(ii)
            subplot
            for jj = 1:nCONTROL
                subplot(3,3,jj)
                % Extract T(s) and S(s)
                indT = nCONTROL*(hDFIG(ii)-1)+jj;
                indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1)+jj;
                Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
                Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));

                % Reconstruct plant and open-loop
                Gss = -Tss/Sss;  % Open-loop L(s)
                Pss = Gss/currentCss{jj};  % Plant P(s)

                % Manual Nichols plot for full formatting control
                w = 2*pi*logspace(logf(jj,1),logf(jj,2),1000);

                % Compute frequency response manually
                [magP, phaseP] = bode(Pss, w);
                [magG, phaseG] = bode(Gss, w);
                magP_dB = 20*log10(squeeze(magP));
                magG_dB = 20*log10(squeeze(magG));
                phaseP = squeeze(phaseP);
                phaseG = squeeze(phaseG);

                % Unwrap phase to get continuous curves (no jumps)
                phaseP = unwrap(phaseP * pi/180) * 180/pi;
                phaseG = unwrap(phaseG * pi/180) * 180/pi;

                % Shift phase to be centered around -180° for better visualization
                % Find the median phase and shift accordingly
                medianP = median(phaseP);
                shiftP = round((medianP + 180) / 360) * 360;
                phaseP = phaseP - shiftP;

                medianG = median(phaseG);
                shiftG = round((medianG + 180) / 360) * 360;
                phaseG = phaseG - shiftG;

                % Plot on regular axes (full control)
                plot(phaseP, magP_dB, 'LineWidth', 2, 'Color', [0 0.4470 0.7410]);  % Blue - Plant
                hold on
                plot(phaseG, magG_dB, 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980]);  % Orange - Open loop

                % Get axes and format - WHITE BACKGROUND, BLACK TEXT
                ax = gca;
                set(ax, 'Color', 'white');
                set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0]);
                set(ax, 'FontSize', 11, 'FontName', 'Times New Roman');
                set(ax, 'TickLabelInterpreter', 'latex');

                % Adjust phase axis to always include -180 degrees (critical stability point)
                current_xlim = xlim;
                if current_xlim(1) > -180
                    xlim([min(current_xlim(1), -200), current_xlim(2)]);
                end
                if current_xlim(2) < -180
                    xlim([current_xlim(1), max(current_xlim(2), -160)]);
                end

                % Capture final axis limits based ONLY on Nichols curves
                final_xlim = xlim;
                final_ylim = ylim;

                % Add reference lines with very large extents: 0 dB (horizontal) and -180° (vertical)
                % Draw lines that extend far beyond typical plot limits
                plot([-1000 1000], [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');  % 0 dB horizontal
                plot([-180 -180], [-1000 1000], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');  % -180° vertical

                % Restore axis limits to those determined by the Nichols curves only
                xlim(final_xlim);
                ylim(final_ylim);

                hold off

                % Format labels
                xlabel('Open-Loop Phase (deg)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])
                ylabel('Open-Loop Gain (dB)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])

                % Format title
                title([ControlLabel{jj} ': ' DFIGLabel{ii}], 'Interpreter', 'latex', ...
                      'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0])

                % Compact legend
                leg = legend('Plant', 'Open loop', 'Location', 'best');
                set(leg, 'Interpreter', 'latex', 'FontSize', 9, 'Color', 'white', ...
                         'EdgeColor', 'black', 'TextColor', 'black')

                % Grid
                grid on
                set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.3, 'GridLineStyle', ':')
                box on
                [wo(ii,jj),~,exitflag] = fsolve(@(w) abs(freqresp(Gss,w))-1,w_ini(jj),opt_fsolve);
                if exitflag<1 || wo(ii)<0
                    wo(ii,jj) = NaN;
                    Fm(ii,jj) = NaN;
                else
                    Fm(ii,jj) = 180 + 180/pi*angle(freqresp(Gss,wo(ii,jj)));
                end
                [wu(ii,jj),~,exitflag] = fsolve(@(w) 180/pi*angle(freqresp(Gss,w))+180,w_ini(jj),opt_fsolve);
                if exitflag<1 || wu(ii)<0
                    wu(ii,jj) = NaN;
                    Am(ii,jj) = NaN;
                    AmdB(ii,jj) = NaN;
                else
                    Am(ii,jj) = 1/abs(freqresp(Gss,wu(ii,jj)));
                    AmdB(ii,jj) = 20*log10(Am(ii,jj));
                end
            end

            % Apply publication formatting to each figure
            format_figure_for_publication(figure(ii))
        end

        % Display computed stability margins with improved formatting
        disp('=========================================================================')
        disp('=== CASE 7: Stability margins (Plant & Open-loop Nichols analysis) ===')
        disp('=========================================================================')
        disp(' ')
        disp('DFIG configuration: [1 (SCR=10), 3 (SCR=5)]')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('Control loops:')
        disp('-------------------------------------------------------------------------')
        for jj = 1:nCONTROL
            fprintf('%d. %s\n', jj, ControlLabel{jj});
        end
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('PHASE MARGIN (PM) [deg]:')
        disp('(Distance from -180° when |L(jω)| = 0 dB, typical spec: PM > 45°)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', Fm(1,:));
        fprintf('SCR=5:  %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', Fm(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('CROSSOVER FREQUENCY (ωc) [rad/s]:')
        disp('(Frequency where |L(jωc)| = 0 dB, bandwidth indicator)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', wo(1,:));
        fprintf('SCR=5:  %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', wo(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('GAIN MARGIN (GM) [dB]:')
        disp('(Distance from 0 dB when ∠L(jω) = -180°, typical spec: GM > 6 dB)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', AmdB(1,:));
        fprintf('SCR=5:  %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', AmdB(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('ULTIMATE FREQUENCY (ωu) [rad/s]:')
        disp('(Frequency where ∠L(jωu) = -180°)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', wu(1,:));
        fprintf('SCR=5:  %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', wu(2,:));
        disp(' ')
        disp('=========================================================================')
        disp(' ')

   %--------------------------------------------------------------
    case 8 % SENSITIVITY FUNCTIONS - Robustness analysis (S and T)
   %--------------------------------------------------------------
        % WHAT THIS FIGURE SHOWS:
        %   Bode magnitude plots of sensitivity S(jω) and complementary sensitivity T(jω).
        %   Essential for evaluating closed-loop robustness and disturbance rejection.
        %
        % CONTROL THEORY FOUNDATIONS:
        %   For closed-loop system: r -->[+]--> C(s) --> G(s) --+--> y
        %                                  ^-                    |
        %                                    +-------- [-] -------+
        %
        % SENSITIVITY FUNCTIONS:
        %   S(s) = 1/(1 + L(s))         - Sensitivity to disturbances/variations
        %   T(s) = L(s)/(1 + L(s))      - Complementary sensitivity (tracking)
        %   where L(s) = C(s)G(s) is the loop transfer function
        %   Fundamental relation: S(s) + T(s) = 1 (algebraic constraint)
        %
        % PHYSICAL INTERPRETATION:
        %   |S(jω)| < 1: Disturbance attenuation at frequency ω
        %   |S(jω)| > 1: Disturbance amplification (avoid!)
        %   |T(jω)| ≈ 1: Good reference tracking at frequency ω
        %   |T(jω)| << 1: Reference signal filtered out (beyond bandwidth)
        %
        % ROBUSTNESS METRICS:
        %   Ms = max|S(jω)| [dB] - Maximum sensitivity (typical spec: ≤ 2 dB = 1.26 pu)
        %   Mt = max|T(jω)| [dB] - Maximum comp. sensitivity (typical spec: ≤ 1.5 dB = 1.19 pu)
        %   ωs, ωt [rad/s] - Frequencies at which maxima occur
        %
        % WHAT TO LOOK FOR:
        %   - Low |S(jω)| at low frequencies → Good disturbance rejection
        %   - Moderate Ms peak (< 2 dB) → Good robustness margins
        %   - |T(jω)| ≈ 0 dB at low freq → Good tracking
        %   - Smooth roll-off → Good stability
        %   - Grid strength impact → Peaks increase in weak grids
        %
        % OUTPUT: 2 figures (SCR 10 and SCR 5), each with 7 Bode magnitude plots
        %         Console displays Ms, Mt, ωs, ωt for each controller
        %

        % Frequency ranges [log10(min), log10(max)] in rad/s for each controller
        logw = [0 2.25;   % VSMP:  1 to 178 rad/s
                -1 2;     % VSMQ:  0.1 to 100 rad/s
                0.5 3.5;  % RSCd:  3.16 to 3162 rad/s (extended for current loops)
                0.5 3.5;  % RSCq:  3.16 to 3162 rad/s (extended for current loops)
                1 2.7;    % VDC:   10 to 500 rad/s (full range, no filtering)
                1.5 3.5;  % GSCd:  31.6 to 3162 rad/s (extended for current loops)
                1.5 3.5]; % GSCq:  31.6 to 3162 rad/s (extended for current loops)

        % Initial guesses for peak frequency optimization [rad/s]
        ws_ini = [1 1 10 10 10 100 100];    % Sensitivity peaks
        wt_ini = [1 1 10 10 10 100 100];    % Complementary sensitivity peaks
        % Select representative DFIGs: strong grid (SCR=10) vs weak grid (SCR=5)
        hDFIG = [1 3];

        % Initialize result matrices [nDFIG × nControllers]
        ws = NaN(length(hDFIG), 7);     % Sensitivity peak frequency [rad/s]
        Ms = NaN(length(hDFIG), 7);     % Maximum sensitivity [dB]
        wt = NaN(length(hDFIG), 7);     % Complementary sensitivity peak freq [rad/s]
        Mt = NaN(length(hDFIG), 7);     % Maximum complementary sensitivity [dB]

        % Generate figures for each DFIG
        for ii = 1:length(hDFIG)
            figure(ii)
            subplot

            % Loop through all seven controllers
            for jj = 1:nCONTROL
                subplot(3, 3, jj)

                % Extract matrix indices for this DFIG-controller pair
                % Output structure: [T1...T14, S1...S14] for 2 DFIGs × 7 controllers
                indT = nCONTROL*(hDFIG(ii)-1) + jj;  % Complementary sensitivity index
                indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + jj;  % Sensitivity index

                % Build state-space transfer functions
                Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));

                % Frequency vector (logarithmic spacing, 5000 points for smooth curves)
                w = logspace(logw(jj,1), logw(jj,2), 5000);

                % Compute frequency response manually
                [magS, ~] = bode(Sss, w);
                [magT, ~] = bode(Tss, w);
                magS_dB = 20*log10(squeeze(magS));
                magT_dB = 20*log10(squeeze(magT));

                % Special handling for VDC (jj=5): always show full range 1-200 rad/s
                if jj == 5
                    % VDC: Use full specified range without filtering
                    w_plot = w;
                    magS_plot = magS_dB;
                    magT_plot = magT_dB;
                else
                    % For other controllers: filter to show only above -20 dB
                    % Find where each curve is above -20 dB
                    S_above = magS_dB > -20;
                    T_above = magT_dB > -20;
                    both_above = S_above & T_above;

                    % Find the last point where both are still above -20 dB
                    valid_indices = find(both_above);

                    % Check if we have a reasonable range (at least 10% of total points)
                    min_points_threshold = 0.10 * length(w);

                    if ~isempty(valid_indices) && length(valid_indices) > min_points_threshold
                        % We have enough valid points, use the filtered range
                        first_idx = 1;

                        % Check if there's a continuous segment from the start
                        if valid_indices(1) == 1
                            % Find where it breaks (first gap in valid_indices)
                            diff_indices = diff(valid_indices);
                            break_point = find(diff_indices > 1, 1);

                            if ~isempty(break_point)
                                last_idx = valid_indices(break_point);
                            else
                                last_idx = valid_indices(end);
                            end
                        else
                            % Start from the first valid point
                            first_idx = valid_indices(1);
                            % Find continuous segment
                            diff_indices = diff(valid_indices);
                            break_point = find(diff_indices > 1, 1);

                            if ~isempty(break_point)
                                last_idx = valid_indices(break_point);
                            else
                                last_idx = valid_indices(end);
                            end
                        end

                        % Extract relevant frequency range
                        w_plot = w(first_idx:last_idx);
                        magS_plot = magS_dB(first_idx:last_idx);
                        magT_plot = magT_dB(first_idx:last_idx);
                    else
                        % Very few points above -20 dB, use full range
                        w_plot = w;
                        magS_plot = magS_dB;
                        magT_plot = magT_dB;
                    end
                end

                % Plot Bode magnitude manually (full formatting control)
                semilogx(w_plot, magS_plot, 'LineWidth', 2, 'Color', [0 0.4470 0.7410]);  % Blue - S
                hold on
                semilogx(w_plot, magT_plot, 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980]);  % Orange - T

                % Find sensitivity maximum using numerical optimization
                ws(ii,jj) = fminsearch(@(w) -abs(freqresp(Sss,w)), ws_ini(jj));
                Ms(ii,jj) = 20*log10(abs(freqresp(Sss, ws(ii,jj))));

                % Find complementary sensitivity maximum
                wt(ii,jj) = fminsearch(@(w) -abs(freqresp(Tss,w)), wt_ini(jj));
                Mt(ii,jj) = 20*log10(abs(freqresp(Tss, wt(ii,jj))));

                hold off

                % Format axes - WHITE BACKGROUND, BLACK TEXT
                ax = gca;
                set(ax, 'Color', 'white');
                set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0]);
                set(ax, 'FontSize', 11, 'FontName', 'Times New Roman');
                set(ax, 'TickLabelInterpreter', 'latex');

                % Format labels
                xlabel('Frequency (rad/s)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])
                ylabel('Magnitude (dB)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])

                % Format title
                title([ControlLabel{jj} ': ' DFIGLabel{ii}], 'Interpreter', 'latex', ...
                      'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0])

                % Format legend
                leg = legend('$|S(j\omega)|$', '$|T(j\omega)|$', 'Location', 'best');
                set(leg, 'Interpreter', 'latex', 'FontSize', 9, 'Color', 'white', ...
                         'EdgeColor', 'black', 'TextColor', 'black')

                % Adjust Y-axis limits based on filtered data range
                % Find min/max considering both S and T in the displayed range
                ymin = min([min(magS_plot), min(magT_plot)]);
                ymax = max([max(magS_plot), max(magT_plot)]);
                yrange = ymax - ymin;

                % Set lower limit to -20 dB and upper limit with margin
                ylim_lower = max(-20, floor((ymin - 0.1*yrange)/5)*5);
                ylim_upper = ceil((ymax + 0.1*yrange)/5)*5;
                ylim([ylim_lower, ylim_upper]);

                % X-axis limits based on filtered frequency range
                xlim([w_plot(1), w_plot(end)]);

                % Grid
                grid on
                set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.3, 'GridLineStyle', ':')
                set(ax, 'GridLineWidth', 0.5);
                box on
            end

            % Apply publication formatting to each figure
            format_figure_for_publication(figure(ii))
        end

        % Display computed robustness metrics with professional formatting
        disp('=========================================================================')
        disp('===== CASE 8: Robustness metrics (Sensitivity functions S & T) =========')
        disp('=========================================================================')
        disp(' ')
        disp('DFIG configuration: [1 (SCR=10), 3 (SCR=5)]')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('Control loops:')
        disp('-------------------------------------------------------------------------')
        for jj = 1:nCONTROL
            fprintf('%d. %s\n', jj, ControlLabel{jj});
        end
        disp(' ')
        disp('=========================================================================')
        disp('SENSITIVITY FUNCTION S(s) = 1/(1 + L(s)) - Disturbance rejection')
        disp('=========================================================================')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('MAXIMUM SENSITIVITY Ms [dB]:')
        disp('(Peak of |S(jω)|, typical spec: Ms ≤ 2 dB for good robustness)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Ms(1,:));
        fprintf('SCR=5:  %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Ms(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('SENSITIVITY PEAK FREQUENCY ωs [rad/s]:')
        disp('(Frequency where |S(jω)| reaches maximum)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', ws(1,:));
        fprintf('SCR=5:  %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', ws(2,:));
        disp(' ')
        disp('=========================================================================')
        disp('COMPLEMENTARY SENSITIVITY T(s) = L(s)/(1 + L(s)) - Reference tracking')
        disp('=========================================================================')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('MAXIMUM COMPLEMENTARY SENSITIVITY Mt [dB]:')
        disp('(Peak of |T(jω)|, typical spec: Mt ≤ 1.5 dB for good robustness)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Mt(1,:));
        fprintf('SCR=5:  %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Mt(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('COMPLEMENTARY SENSITIVITY PEAK FREQUENCY ωt [rad/s]:')
        disp('(Frequency where |T(jω)| reaches maximum, near bandwidth)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', wt(1,:));
        fprintf('SCR=5:  %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', wt(2,:));
        disp(' ')
        disp('=========================================================================')
        disp('ROBUSTNESS INTERPRETATION:')
        disp('  • Ms, Mt < 2 dB    → Excellent robustness (recommended)')
        disp('  • Ms, Mt < 3 dB    → Good robustness (acceptable)')
        disp('  • Ms, Mt > 6 dB    → Poor robustness (redesign required)')
        disp('  • Low ωs           → Good low-frequency disturbance rejection')
        disp('  • High ωt          → Wide bandwidth, fast tracking')
        disp('=========================================================================')
        disp(' ')
   %--------------------------------------------------------------
    case 9 % DFIG COMPARISON: Closed-loop frequency response (Reference tracking)
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   Complementary sensitivity function |T(jω)| for different DFIG configurations
    %   comparing SCR transformer = 10 (strong grid) vs SCR = 5 (weak grid).
    %   Shows how grid strength affects closed-loop bandwidth and resonance peaks.
    %
    % KEY FEATURES:
    %   • Closed-loop transfer function: T(s) = output/reference
    %   • Resonance peak Mr [dB]: indicates overshoot and robustness
    %   • Resonance frequency ωr [rad/s]: bandwidth indicator
    %   • Comparison between DFIG#1 (SCR=10) and DFIG#3 (SCR=5)
    %
    % INTERPRETATION:
    %   • Mr < 1.5 dB    → Good robustness (recommended)
    %   • Mr < 3 dB      → Acceptable robustness
    %   • Mr > 6 dB      → Poor robustness (redesign needed)
    %   • Higher ωr      → Faster response (higher bandwidth)
    %   • Lower SCR      → More resonance (weaker grid)
    %
    % OUTPUT:
    %   • 1 figure with 7 subplots (3×3 grid, one per controller)
    %   • Each subplot: overlaid Bode magnitude plots for 2 DFIGs
    %   • Console: resonance metrics (Mr, ωr) tabulated by DFIG and controller
    %

        %------------------------------------------------------------------
        % Configuration: frequency ranges and initial guesses
        %------------------------------------------------------------------
        % Frequency ranges [low, high] for each controller (log10 scale)
        % Optimized to show relevant bandwidth for each control loop
        logw = [-1   2.25;   % VSMP: 0.1 - 178 rad/s (slow power dynamics)
                -1   1.25;   % VSMQ: 0.1 - 18 rad/s (slow voltage dynamics)
                 1   4;      % RSCd: 10 - 10000 rad/s (rotor current control)
                 1   4;      % RSCq: 10 - 10000 rad/s (rotor current control)
                 0   2.477;  % VDC: 1 - 300 rad/s (DC-link voltage)
                 1   4;      % GSCd: 10 - 10000 rad/s (grid-side current control)
                 1   4];     % GSCq: 10 - 10000 rad/s (grid-side current control)

        % Initial guesses for resonance frequency search [rad/s]
        wr_ini = [1 1 100 100 10 100 100];

        % DFIG indices to compare: 1 (SCR=10) and 3 (SCR=5)
        hDFIG = [1 3];

        %------------------------------------------------------------------
        % Initialize result matrices [nDFIG × nControllers]
        %------------------------------------------------------------------
        wr = NaN(length(hDFIG), 7);  % Resonance frequency [rad/s]
        Mr = NaN(length(hDFIG), 7);  % Resonance peak [dB]

        % Cell array to store state-space models for each DFIG
        Tss = cell(1, nDFIG);

        %------------------------------------------------------------------
        % Main plotting loop: generate single figure with all controllers
        %------------------------------------------------------------------
        figure(1)

        for jj = 1:nCONTROL
            % Create subplot for this controller (3×3 grid)
            subplot(3, 3, jj)

            % Build state-space models for both DFIGs
            for ii = 1:length(hDFIG)
                % Extract matrix index for this DFIG-controller pair
                % Closed-loop output: y_output / u_reference (complementary sensitivity)
                indT = nCONTROL*(hDFIG(ii)-1) + jj;

                % Construct closed-loop state-space model
                Tss{ii} = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
            end

            % Frequency vector (logarithmic spacing, 1000 points for smooth curves)
            w = logspace(logw(jj,1), logw(jj,2), 1000);

            % Compute frequency response manually for full control over plotting
            [mag1, ~] = bode(-Tss{1}, w);
            [mag2, ~] = bode(-Tss{2}, w);
            mag1_dB = 20*log10(squeeze(mag1));
            mag2_dB = 20*log10(squeeze(mag2));

            % Plot using semilogx with paper-quality formatting
            semilogx(w, mag1_dB, 'LineWidth', 2, 'Color', [0 0.4470 0.7410]);  % Blue - SCR=10
            hold on
            semilogx(w, mag2_dB, 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980]);  % Orange - SCR=5

            % Find resonance peak and frequency for each DFIG
            wr(1,jj) = fminsearch(@(w) -abs(freqresp(-Tss{1}, w)), wr_ini(jj));
            wr(2,jj) = fminsearch(@(w) -abs(freqresp(-Tss{2}, w)), wr_ini(jj));
            Mr(1,jj) = 20*log10(abs(freqresp(-Tss{1}, wr(1,jj))));
            Mr(2,jj) = 20*log10(abs(freqresp(-Tss{2}, wr(2,jj))));

            hold off

            % Format axes - WHITE BACKGROUND, BLACK TEXT
            ax = gca;
            set(ax, 'Color', 'white');
            set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0]);
            set(ax, 'FontSize', 11, 'FontName', 'Times New Roman');
            set(ax, 'TickLabelInterpreter', 'latex');

            % Format labels
            xlabel('Frequency (rad/s)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])
            ylabel('Magnitude (dB)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])

            % Format title
            title(ControlLabel{jj}, 'Interpreter', 'latex', ...
                  'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0])

            % Format legend (only for first subplot to avoid repetition)
            if jj == 1
                leg = legend('SCR = 10 (strong)', 'SCR = 5 (weak)', 'Location', 'best');
                set(leg, 'Interpreter', 'latex', 'FontSize', 9, 'Color', 'white', ...
                         'EdgeColor', 'black', 'TextColor', 'black')
            end

            % Set Y-axis limits (adjusted for RSCd and RSCq)
            if jj == 3 || jj == 4  % RSCd (3) and RSCq (4)
                ylim([-35 15])
            else
                ylim([-15 10])
            end

            % Set X-axis limits (VDC limited to 300 rad/s)
            if jj == 5  % VDC
                xlim([1 300])
            end

            % Grid
            grid on
            set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.3, 'GridLineStyle', ':')
            set(ax, 'GridLineWidth', 0.5);
            box on
        end

        % Apply publication formatting to figure
        format_figure_for_publication(figure(1))

        %------------------------------------------------------------------
        % Display computed metrics with professional formatting
        %------------------------------------------------------------------
        disp('=========================================================================')
        disp('===== CASE 9: DFIG comparison - Closed-loop frequency response =========')
        disp('=========================================================================')
        disp(' ')
        disp('DFIG configuration: [1 (SCR=10), 3 (SCR=5)]')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('Control loops:')
        disp('-------------------------------------------------------------------------')
        for jj = 1:nCONTROL
            fprintf('%d. %s\n', jj, ControlLabel{jj});
        end
        disp(' ')
        disp('=========================================================================')
        disp('CLOSED-LOOP FREQUENCY RESPONSE: T(s) = output/reference')
        disp('=========================================================================')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('RESONANCE PEAK Mr [dB]:')
        disp('(Maximum of |T(jω)|, indicates overshoot tendency and robustness)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Mr(1,:));
        fprintf('SCR=5:  %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Mr(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('RESONANCE FREQUENCY ωr [rad/s]:')
        disp('(Frequency where |T(jω)| reaches maximum, bandwidth indicator)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', wr(1,:));
        fprintf('SCR=5:  %8.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f\n', wr(2,:));
        disp(' ')
        disp('=========================================================================')
        disp('ROBUSTNESS INTERPRETATION:')
        disp('  • Mr < 1.5 dB      → Excellent robustness (recommended)')
        disp('  • Mr < 3 dB        → Good robustness (acceptable)')
        disp('  • Mr > 6 dB        → Poor robustness (redesign required)')
        disp('  • Higher ωr        → Wider bandwidth, faster tracking response')
        disp('  • SCR=10 vs SCR=5  → Strong grid vs weak grid comparison')
        disp('=========================================================================')
        disp(' ')
   %--------------------------------------------------------------
    case 10 % LOAD DISTURBANCE RESPONSE: Frequency and PCC voltage transients
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   System response to active and reactive load step disturbances.
    %   Evaluates how DFIG control maintains grid frequency and PCC voltage
    %   stability under sudden load changes.
    %
    % KEY FEATURES:
    %   • Active load step → Frequency deviation Δf(t)
    %   • Reactive load step → PCC voltage deviation ΔV_pcc(t)
    %   • ROCOF/ROCOV: Rate of Change of Frequency/Voltage
    %   • Nadir: Maximum frequency/voltage deviation
    %
    % INTERPRETATION:
    %   • Lower ROCOF/ROCOV → Better transient response
    %   • Lower nadir → Better disturbance rejection
    %   • Faster settling → Better damping and control performance
    %   • Cross-coupling effects visible (P→V, Q→f)
    %
    % OUTPUT:
    %   • 1 figure with 2×2 subplots
    %   • Top row: Active load disturbance (Δf and ΔV_pcc)
    %   • Bottom row: Reactive load disturbance (Δf and ΔV_pcc)
    %   • Console: ROCOF, ROCOV, and nadir metrics
    %

        %------------------------------------------------------------------
        % Configuration: time vectors and labels
        %------------------------------------------------------------------
        % Time vectors for step response simulation
        t = {linspace(0, 15, 500);    % Active load: frequency response
             linspace(0, 15, 5000)};  % Reactive load: voltage response (finer resolution)

        % Output labels for plots
        outLabel = {'Frequency (pu)', 'PCC voltage (pu)'};

        % Subplot titles
        titleLabel = {'Active load step', 'Reactive load step'};

        %------------------------------------------------------------------
        % Initialize metrics: ROCOF, ROCOV, and nadir
        %------------------------------------------------------------------
        % Rate of Change of Frequency/Voltage [pu/s]
        ROCOX = NaN(1, 2);  % [ROCOF, ROCOV]

        % Maximum frequency/voltage deviation [pu]
        nadir = NaN(1, 2);  % [nadir_f, nadir_V]

        %------------------------------------------------------------------
        % Main plotting loop: 2×2 grid (load types × outputs)
        %------------------------------------------------------------------
        figure(1)

        % Loop over disturbance types: (1) Active load, (2) Reactive load
        for ii = 1:2
            % Loop over outputs: (1) Frequency, (2) PCC voltage
            for jj = 1:2
                % Create subplot: [row, col] = [disturbance type, output]
                subplot(2, 2, 2*(ii-1) + jj)

                % Extract matrix indices
                % Input: load disturbances (active or reactive)
                indI = nCONTROL*nDFIG + 8 + ii;

                % Output: frequency (1) or PCC voltage (2)
                indO = 2*nCONTROL*nDFIG + jj;

                % Build state-space transfer function: output/disturbance
                Fss = ss(matA, matB(:,indI), matC(indO,:), matD(indO,indI));

                % Compute step response
                y = step(Fss, t{jj});

                % Plot with paper-quality formatting
                plot(t{jj}, y, 'LineWidth', 2, 'Color', [0 0.4470 0.7410])  % Blue line
                hold on

                %----------------------------------------------------------
                % Compute performance metrics
                %----------------------------------------------------------
                % ROCOF: Active load → Frequency (ii==1, jj==1)
                % ROCOV: Reactive load → Voltage (ii==2, jj==2)
                if (ii==1 && jj==1) || (ii==2 && jj==2)
                    % Find half-rise time point for rate estimation
                    [~, ind] = min(abs(y - y(end)/2));

                    % Rate of change [pu/s]
                    ROCOX(jj) = abs(y(ind) / t{jj}(ind));

                    % Maximum deviation (nadir) [pu]
                    nadir(jj) = max(abs(y));
                end

                hold off

                % Format axes - WHITE BACKGROUND, BLACK TEXT
                ax = gca;
                set(ax, 'Color', 'white');
                set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0]);
                set(ax, 'FontSize', 11, 'FontName', 'Times New Roman');
                set(ax, 'TickLabelInterpreter', 'latex');

                % Format labels
                xlabel('Time (s)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])
                ylabel(outLabel{jj}, 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])

                % Format title
                title(titleLabel{ii}, 'Interpreter', 'latex', ...
                      'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0])

                % Set X-axis limits
                xlim([0 t{jj}(end)])

                % Grid
                grid on
                set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.3, 'GridLineStyle', ':')
                set(ax, 'GridLineWidth', 0.5);
                box on
            end
        end

        % Apply publication formatting to figure
        format_figure_for_publication(figure(1))

        %------------------------------------------------------------------
        % Display computed metrics with professional formatting
        %------------------------------------------------------------------
        disp('=========================================================================')
        disp('===== CASE 10: Load disturbance response (Frequency & Voltage) =========')
        disp('=========================================================================')
        disp(' ')
        disp('DISTURBANCE REJECTION METRICS:')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('RATE OF CHANGE:')
        disp('-------------------------------------------------------------------------')
        fprintf('  ROCOF (Active load → Frequency):   %.4f pu/s\n', ROCOX(1));
        fprintf('  ROCOV (Reactive load → Voltage):   %.4f pu/s\n', ROCOX(2));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('MAXIMUM DEVIATION (NADIR):')
        disp('-------------------------------------------------------------------------')
        fprintf('  Frequency nadir (Active load):     %.4f pu\n', nadir(1));
        fprintf('  Voltage nadir (Reactive load):     %.4f pu\n', nadir(2));
        disp(' ')
        disp('=========================================================================')
        disp('PERFORMANCE INTERPRETATION:')
        disp('  • Lower ROCOF/ROCOV  → Slower initial transient (better)')
        disp('  • Lower nadir        → Smaller maximum deviation (better)')
        disp('  • Fast settling      → Good damping and control response')
        disp('  • Cross-coupling     → Visible in off-diagonal responses (P→V, Q→f)')
        disp('=========================================================================')
        disp(' ')
   %--------------------------------------------------------------
    case 11 % TRD vs FRD COMPARISON: Closed-loop step response
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   Direct comparison of time-domain performance between TRD and FRD controllers.
    %   Both controller designs are applied to the same linearized plant model
    %   with full cross-coupling interactions between all control loops.
    %
    % DESIGN METHODS COMPARED:
    %   • TRD (Time-Response Design): Baseline controllers optimized in time domain
    %   • FRD (Frequency-Response Design): Controllers optimized in frequency domain
    %
    % REQUIREMENTS:
    %   Loaded LIN_MODEL must contain both trdCss and frdCss controller arrays
    %   (e.g., generated from CONTROL_DESIGN_FR.m with FRD optimization enabled)
    %
    % KEY FEATURES:
    %   • Same plant model for both designs (fair comparison)
    %   • Step response: reference tracking performance
    %   • Full MIMO interactions included
    %   • Separate figures for each DFIG (SCR 10 and SCR 5)
    %
    % INTERPRETATION:
    %   • Faster settling (FRD) → Frequency design improved time-domain response
    %   • Reduced overshoot (FRD) → Better damping from frequency-domain tuning
    %   • Similar responses → Frequency design preserves time-domain specs
    %   • Worse FRD response → Trade-off for frequency-domain robustness gains
    %
    % OUTPUT:
    %   • 2 figures: one per DFIG configuration (SCR=10, SCR=5)
    %   • Each figure: 7 subplots (3×3 grid, one per control loop)
    %   • Blue line: TRD baseline
    %   • Orange line: FRD optimized
    %

        %------------------------------------------------------------------
        % Check for FRD controller availability
        %------------------------------------------------------------------
        if ~isfield(LIN_MODEL.CONTROL_DESIGN.VSMP, 'frdCss')
            disp('=========================================================================')
            disp('ERROR: Frequency-Response Design (FRD) controllers not found!')
            disp('=========================================================================')
            disp(' ')
            disp('The loaded LIN_MODEL does not contain FRD controllers.')
            disp('Please run CONTROL_DESIGN_FR.m with FRD optimization enabled.')
            disp(' ')
            disp('Required field: LIN_MODEL.CONTROL_DESIGN.VSMP.frdCss')
            disp(' ')
            return
        end

        %------------------------------------------------------------------
        % Configuration: DFIG indices and simulation times
        %------------------------------------------------------------------
        % DFIG configurations to compare: 1 (SCR=10), 3 (SCR=5)
        hDFIG = [1 3];

        % Simulation time per control loop [s]
        % Adjusted to capture complete transient response for each loop
        tfin = [1.5;   % VSMP: slow power dynamics
                3;     % VSMQ: slow voltage dynamics
                0.25;  % RSCd: medium-speed current
                0.25;  % RSCq: medium-speed current
                0.5;   % VDC: DC-link voltage
                0.15;  % GSCd: fast current
                0.15]; % GSCq: fast current

        %------------------------------------------------------------------
        % Main plotting loop: generate figures for each DFIG
        %------------------------------------------------------------------
        for ii = 1:length(hDFIG)
            % Create figure for this DFIG configuration
            figure(ii)

            % Loop through all seven control loops
            for jj = 1:nCONTROL
                % Create subplot for this controller (3×3 grid)
                subplot(3, 3, jj)

                %----------------------------------------------------------
                % Extract closed-loop transfer functions from linear model
                %----------------------------------------------------------
                % Matrix indices for this DFIG-controller pair
                indT = nCONTROL*(hDFIG(ii)-1) + jj;  % Complementary sensitivity
                indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + jj;  % Sensitivity

                % Build state-space models
                Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));

                %----------------------------------------------------------
                % Reconstruct plant from closed-loop functions
                %----------------------------------------------------------
                % Open-loop transfer function: L(s) = C(s)P(s)
                Gss = -Tss/Sss;

                % Plant model: P(s) = L(s)/C(s)
                % Remove current controller to get bare plant
                Pss = Gss / currentCss{jj};

                %----------------------------------------------------------
                % Compute step responses for both controller designs
                %----------------------------------------------------------
                % Time vector (5000 points for smooth curves)
                t = linspace(0, tfin(jj), 5000);

                % TRD closed-loop: T_trd(s) = C_trd(s)P(s) / [1 + C_trd(s)P(s)]
                trdFss = trdCss{jj}*Pss / (1 + trdCss{jj}*Pss);
                y1 = step(trdFss, t);

                % FRD closed-loop: T_frd(s) = C_frd(s)P(s) / [1 + C_frd(s)P(s)]
                frdFss = frdCss{jj}*Pss / (1 + frdCss{jj}*Pss);
                y2 = step(frdFss, t);

                %----------------------------------------------------------
                % Plot with paper-quality formatting
                %----------------------------------------------------------
                plot(t, y1, 'LineWidth', 2, 'Color', [0 0.4470 0.7410])  % Blue - TRD
                hold on
                plot(t, y2, 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980])  % Orange - FRD
                hold off

                % Format axes - WHITE BACKGROUND, BLACK TEXT
                ax = gca;
                set(ax, 'Color', 'white');
                set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0]);
                set(ax, 'FontSize', 11, 'FontName', 'Times New Roman');
                set(ax, 'TickLabelInterpreter', 'latex');

                % Format labels
                xlabel('Time (s)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])
                ylabel(OutputLabel{jj}, 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])

                % Format title
                title([ControlLabel{jj} ': ' DFIGLabel{ii}], 'Interpreter', 'latex', ...
                      'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0])

                % Format legend (only for first subplot)
                if jj == 1
                    leg = legend('TRD (baseline)', 'FRD (optimized)', 'Location', 'best');
                    set(leg, 'Interpreter', 'latex', 'FontSize', 9, 'Color', 'white', ...
                             'EdgeColor', 'black', 'TextColor', 'black')
                end

                % Set X-axis limits
                xlim([t(1) tfin(jj)])

                % Grid
                grid on
                set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.3, 'GridLineStyle', ':')
                set(ax, 'GridLineWidth', 0.5);
                box on
            end

            % Apply publication formatting to this figure
            format_figure_for_publication(figure(ii))
        end

        %------------------------------------------------------------------
        % Display information message
        %------------------------------------------------------------------
        disp('=========================================================================')
        disp('===== CASE 11: TRD vs FRD - Closed-loop step response comparison =======')
        disp('=========================================================================')
        disp(' ')
        disp('CONTROLLER DESIGN METHODS:')
        disp(' ')
        disp('  TRD (Time-Response Design):')
        disp('    • Baseline controllers optimized for time-domain specifications')
        disp('    • Tuned for settling time, overshoot, rise time')
        disp(' ')
        disp('  FRD (Frequency-Response Design):')
        disp('    • Controllers optimized for frequency-domain robustness')
        disp('    • Tuned for gain margin, phase margin, bandwidth')
        disp(' ')
        disp('FIGURES GENERATED:')
        disp('  • Figure 1: DFIG #1 (SCR transformer = 10, strong grid)')
        disp('  • Figure 2: DFIG #3 (SCR transformer = 5, weak grid)')
        disp(' ')
        disp('PERFORMANCE COMPARISON GUIDELINES:')
        disp('  • Compare settling times: FRD faster → improved bandwidth')
        disp('  • Compare overshoot: FRD lower → better damping')
        disp('  • Check steady-state: both should reach 1.0 (unity gain)')
        disp('  • Evaluate trade-offs: time vs frequency domain optimization')
        disp('=========================================================================')
        disp(' ')

   %--------------------------------------------------------------
    case 12 % TRD vs FRD COMPARISON: Open-loop frequency response (Nichols chart)
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   Nichols chart comparison of open-loop transfer functions L(jω) = C(jω)P(jω)
    %   for TRD and FRD controller designs. Directly visualizes stability margins
    %   (gain and phase margins) and closed-loop resonance characteristics.
    %
    % DESIGN METHODS COMPARED:
    %   • TRD (Time-Response Design): Baseline open-loop
    %   • FRD (Frequency-Response Design): Frequency-optimized open-loop
    %
    % REQUIREMENTS:
    %   Loaded LIN_MODEL must contain both trdCss and frdCss controller arrays
    %   (e.g., generated from CONTROL_DESIGN_FR.m with FRD optimization enabled)
    %
    % KEY FEATURES:
    %   • Nichols chart: Phase (x-axis) vs Gain (y-axis)
    %   • Critical point: (-180°, 0 dB) - system becomes unstable if crossed
    %   • Gain margin: Vertical distance from -180° line to curve at 0 dB
    %   • Phase margin: Horizontal distance from curve to -180° at 0 dB crossing
    %   • Closed-loop contours: Show closed-loop resonance peaks
    %
    % INTERPRETATION:
    %   • Greater distance from critical point → Better stability margins
    %   • FRD curve further from critical point → Improved robustness
    %   • Tighter contours around critical point → Higher resonance
    %   • Phase margin > 45° and Gain margin > 6 dB → Good robustness
    %
    % OUTPUT:
    %   • 2 figures: one per DFIG configuration (SCR=10, SCR=5)
    %   • Each figure: 7 subplots (3×3 grid, one per control loop)
    %   • Blue line: TRD baseline
    %   • Orange line: FRD optimized
    %

        %------------------------------------------------------------------
        % Configuration: frequency ranges (in Hz) and Nichols plot options
        %------------------------------------------------------------------
        % Frequency ranges [low, high] in Hz (log10 scale)
        % Converted to rad/s with 2π factor in plotting
        logf = [-2   2.25;   % VSMP: 0.01 - 178 Hz
                -2   2;      % VSMQ: 0.01 - 100 Hz
                 0   3;      % RSCd: 1 - 1000 Hz
                 0   3;      % RSCq: 1 - 1000 Hz
                 0.5 3;      % VDC: 3.16 - 1000 Hz
                 1.5 3;      % GSCd: 31.6 - 1000 Hz
                 1.5 3];     % GSCq: 31.6 - 1000 Hz

        % DFIG configurations: 1 (SCR=10), 3 (SCR=5)
        hDFIG = [1 3];

        %------------------------------------------------------------------
        % Nichols plot formatting options
        %------------------------------------------------------------------
        plotoptions = nicholsoptions;
        plotoptions.PhaseWrapping = 'off';         % Don't wrap phase at ±180°
        plotoptions.PhaseMatching = 'on';          % Align phase at reference frequency
        plotoptions.PhaseMatchingFreq = 5;         % Reference frequency [rad/s]
        plotoptions.PhaseMatchingValue = -180;     % Phase value at reference

        %------------------------------------------------------------------
        % Main plotting loop: generate figures for each DFIG
        %------------------------------------------------------------------
        for ii = 1:length(hDFIG)
            % Create figure for this DFIG configuration
            figure(ii)

            % Loop through all seven control loops
            for jj = 1:nCONTROL
                % Create subplot for this controller (3×3 grid)
                subplot(3, 3, jj)

                %----------------------------------------------------------
                % Extract plant from closed-loop functions
                %----------------------------------------------------------
                % Matrix indices for this DFIG-controller pair
                indT = nCONTROL*(hDFIG(ii)-1) + jj;  % Complementary sensitivity
                indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + jj;  % Sensitivity

                % Build state-space models
                Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));

                % Reconstruct open-loop and plant
                Gss = -Tss/Sss;                    % Open-loop with current controller
                Pss = Gss / currentCss{jj};        % Plant model

                %----------------------------------------------------------
                % Compute open-loop transfer functions for both designs
                %----------------------------------------------------------
                % Frequency vector (1000 points, converted from Hz to rad/s)
                w = 2*pi * logspace(logf(jj,1), logf(jj,2), 1000);

                % Open-loop transfer functions
                L_trd = Pss * trdCss{jj};  % TRD: L(s) = P(s)C_trd(s)
                L_frd = Pss * frdCss{jj};  % FRD: L(s) = P(s)C_frd(s)

                %----------------------------------------------------------
                % Plot Nichols chart with paper-quality formatting
                % Using exact pattern from case 7 in same file
                %----------------------------------------------------------
                % Compute frequency response manually
                [magTRD, phaseTRD] = bode(L_trd, w);
                [magFRD, phaseFRD] = bode(L_frd, w);
                magTRD_dB = 20*log10(squeeze(magTRD));
                magFRD_dB = 20*log10(squeeze(magFRD));
                phaseTRD = squeeze(phaseTRD);
                phaseFRD = squeeze(phaseFRD);

                % Unwrap phase to get continuous curves (no jumps)
                phaseTRD = unwrap(phaseTRD * pi/180) * 180/pi;
                phaseFRD = unwrap(phaseFRD * pi/180) * 180/pi;

                % Shift phase to be centered around -180° for better visualization
                medianTRD = median(phaseTRD);
                shiftTRD = round((medianTRD + 180) / 360) * 360;
                phaseTRD = phaseTRD - shiftTRD;

                medianFRD = median(phaseFRD);
                shiftFRD = round((medianFRD + 180) / 360) * 360;
                phaseFRD = phaseFRD - shiftFRD;

                % Plot on regular axes (full control)
                plot(phaseTRD, magTRD_dB, 'LineWidth', 2, 'Color', [0 0.4470 0.7410]);  % Blue - TRD
                hold on
                plot(phaseFRD, magFRD_dB, 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980]);  % Orange - FRD

                % Get axes and format - WHITE BACKGROUND, BLACK TEXT
                ax = gca;
                set(ax, 'Color', 'white');
                set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0]);
                set(ax, 'FontSize', 11, 'FontName', 'Times New Roman');
                set(ax, 'TickLabelInterpreter', 'latex');

                % Adjust phase axis to always include -180 degrees (critical stability point)
                current_xlim = xlim;
                if current_xlim(1) > -180
                    xlim([min(current_xlim(1), -200), current_xlim(2)]);
                end
                if current_xlim(2) < -180
                    xlim([current_xlim(1), max(current_xlim(2), -160)]);
                end

                % Capture final axis limits based ONLY on Nichols curves
                final_xlim = xlim;
                final_ylim = ylim;

                % Add reference lines: 0 dB (horizontal) and -180° (vertical)
                plot([-1000 1000], [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');  % 0 dB horizontal
                plot([-180 -180], [-1000 1000], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');  % -180° vertical

                % Restore axis limits to those determined by the Nichols curves only
                xlim(final_xlim);
                ylim(final_ylim);

                hold off

                % Format labels
                xlabel('Open-Loop Phase (deg)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])
                ylabel('Open-Loop Gain (dB)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])

                % Format title
                title([ControlLabel{jj} ': ' DFIGLabel{ii}], 'Interpreter', 'latex', ...
                      'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0])

                % Compact legend
                leg = legend('TRD', 'FRD', 'Location', 'best');
                set(leg, 'Interpreter', 'latex', 'FontSize', 9, 'Color', 'white', ...
                         'EdgeColor', 'black', 'TextColor', 'black')

                % Grid
                grid on
                set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.3, 'GridLineStyle', ':')
                box on
            end

            % Apply publication formatting to this figure
            format_figure_for_publication(figure(ii))
        end

        %------------------------------------------------------------------
        % Display information message
        %------------------------------------------------------------------
        disp('=========================================================================')
        disp('===== CASE 12: TRD vs FRD - Open-loop Nichols chart comparison ==========')
        disp('=========================================================================')
        disp(' ')
        disp('NICHOLS CHART INTERPRETATION:')
        disp(' ')
        disp('  Critical Point: (-180°, 0 dB)')
        disp('    • System becomes unstable if open-loop crosses this point')
        disp('    • Distance from critical point indicates stability margins')
        disp(' ')
        disp('  Gain Margin (GM):')
        disp('    • Vertical distance from -180° line to curve at 0 dB')
        disp('    • GM > 6 dB recommended for good robustness')
        disp(' ')
        disp('  Phase Margin (PM):')
        disp('    • Horizontal distance from curve to -180° at 0 dB crossing')
        disp('    • PM > 45° recommended for good robustness')
        disp(' ')
        disp('  Closed-loop Contours:')
        disp('    • Background grid shows closed-loop magnitude peaks')
        disp('    • Curves closer to contours → higher resonance')
        disp(' ')
        disp('FIGURES GENERATED:')
        disp('  • Figure 1: DFIG #1 (SCR transformer = 10, strong grid)')
        disp('  • Figure 2: DFIG #3 (SCR transformer = 5, weak grid)')
        disp(' ')
        disp('COMPARISON GUIDELINES:')
        disp('  • FRD further from critical point → Improved stability margins')
        disp('  • Similar curves → Frequency design preserves stability')
        disp('  • Check both GM and PM for comprehensive robustness assessment')
        disp('=========================================================================')
        disp(' ')

   %--------------------------------------------------------------
    case 13 % TRD vs FRD COMPARISON - Closed-loop frequency response (Bode magnitude)
   %--------------------------------------------------------------
    % WHAT THIS FIGURE SHOWS:
    %   Bode magnitude plots of closed-loop transfer functions F(jω) = L/(1+L)
    %   for TRD and FRD controllers. Shows bandwidth and resonance peaks.
    %
    % REQUIREMENTS:
    %   Loaded file must contain both trdCss and frdCss (e.g., LIN_MODEL_FRD_OPT.mat)
    %
    % LEGEND INTERPRETATION:
    %   Blue line  (TRD): Time-Response Design closed-loop magnitude
    %   Orange line (FRD): Frequency-Response Design closed-loop magnitude
    %
    % WHAT TO LOOK FOR:
    %   - Bandwidth (frequency at -3dB) → Speed of response
    %   - Resonance peak height → Damping (lower is better)
    %   - High-frequency roll-off → Noise rejection
    %   - FRD typically shows smoother response, reduced peaks
    %
    % OUTPUT: 2 figures (SCR 10 and SCR 5), each with 7 Bode magnitude plots
    %
        %------------------------------------------------------------------
        % Check if FRD controllers are available
        %------------------------------------------------------------------
        if ~isfield(LIN_MODEL.CONTROL_DESIGN.VSMP, 'frdCss')
            disp(' ')
            disp('=========================================================================')
            disp('ERROR: FRD controllers not found in the loaded linear model.')
            disp('=========================================================================')
            disp(' ')
            disp('SOLUTION:')
            disp('  Load a linear model that contains FRD controller data')
            disp('  Example: PLOT_LIN_MODEL(''FRD_DESIGN'', 13)')
            disp(' ')
            disp('AVAILABLE FILES WITH FRD CONTROLLERS:')
            disp('  • LIN_MODEL_FRD_OPT.mat (optimized frequency-response design)')
            disp(' ')
            return
        end

        %------------------------------------------------------------------
        % Frequency ranges for each controller (rad/s, log scale)
        % Using EXACTLY the same scales as case 9
        %------------------------------------------------------------------
        logw = [-1   2.25;   % VSMP: 0.1 - 178 rad/s (slow power dynamics)
                -1   1.25;   % VSMQ: 0.1 - 18 rad/s (slow voltage dynamics)
                 1   4;      % RSCd: 10 - 10000 rad/s (rotor current control)
                 1   4;      % RSCq: 10 - 10000 rad/s (rotor current control)
                 0   2.477;  % VDC: 1 - 300 rad/s (DC-link voltage)
                 1   4;      % GSCd: 10 - 10000 rad/s (grid-side current control)
                 1   4];     % GSCq: 10 - 10000 rad/s (grid-side current control)

        hDFIG = [1 3];  % DFIG indices: 1 (SCR=10), 3 (SCR=5)

        % Initial guesses for resonance frequency search [rad/s]
        % Using EXACTLY the same initial guesses as case 9
        wr_ini_trd = [1 1 100 100 10 100 100];
        wr_ini_frd = wr_ini_trd;  % Same initial guess for FRD

        % Arrays to store resonance peaks and frequencies
        Mr_trd = NaN(length(hDFIG), nCONTROL);
        Mr_frd = NaN(length(hDFIG), nCONTROL);
        wr_trd = NaN(length(hDFIG), nCONTROL);
        wr_frd = NaN(length(hDFIG), nCONTROL);

        %------------------------------------------------------------------
        % Main plotting loop: generate figures for each DFIG
        %------------------------------------------------------------------
        for ii = 1:length(hDFIG)
            figure(ii)
            subplot

            for jj = 1:nCONTROL
                % Create subplot for this controller (3×3 grid)
                subplot(3, 3, jj)

                % Extract plant transfer function P(s)
                indT = nCONTROL*(hDFIG(ii)-1)+jj;
                indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1)+jj;
                Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
                Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));
                Gss = -Tss/Sss;  % Open-loop L(s)
                Pss = Gss/currentCss{jj};  % Plant P(s)

                % Closed-loop transfer functions F(s) = C(s)P(s) / (1 + C(s)P(s))
                trdFss = trdCss{jj}*Pss/(1+trdCss{jj}*Pss);  % TRD closed-loop
                frdFss = frdCss{jj}*Pss/(1+frdCss{jj}*Pss);  % FRD closed-loop

                % Frequency vector (logarithmic spacing, 1000 points for smooth curves)
                w = logspace(logw(jj,1), logw(jj,2), 1000);

                % Compute frequency response manually for full control over plotting
                [magTRD, ~] = bode(trdFss, w);
                [magFRD, ~] = bode(frdFss, w);
                magTRD_dB = 20*log10(squeeze(magTRD));
                magFRD_dB = 20*log10(squeeze(magFRD));

                % Plot using semilogx with paper-quality formatting
                semilogx(w, magTRD_dB, 'LineWidth', 2, 'Color', [0 0.4470 0.7410]);  % Blue - TRD
                hold on
                semilogx(w, magFRD_dB, 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980]);  % Orange - FRD

                % Find resonance peak and frequency (suppress ill-conditioning warnings)
                warnState = warning('off', 'all');

                % Find resonance peak and frequency for TRD
                wr_trd(ii,jj) = fminsearch(@(w) -abs(freqresp(trdFss, w)), wr_ini_trd(jj));
                Mr_trd(ii,jj) = 20*log10(abs(freqresp(trdFss, wr_trd(ii,jj))));

                % Find resonance peak and frequency for FRD
                wr_frd(ii,jj) = fminsearch(@(w) -abs(freqresp(frdFss, w)), wr_ini_frd(jj));
                Mr_frd(ii,jj) = 20*log10(abs(freqresp(frdFss, wr_frd(ii,jj))));

                warning(warnState);

                hold off

                % Format axes - WHITE BACKGROUND, BLACK TEXT
                ax = gca;
                set(ax, 'Color', 'white');
                set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0]);
                set(ax, 'FontSize', 11, 'FontName', 'Times New Roman');
                set(ax, 'TickLabelInterpreter', 'latex');

                % Format labels
                xlabel('Frequency (rad/s)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])
                ylabel('Magnitude (dB)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])

                % Format title
                title([ControlLabel{jj} ': ' DFIGLabel{ii}], 'Interpreter', 'latex', ...
                      'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0])

                % Format legend (only for first subplot to avoid repetition)
                if jj == 1
                    leg = legend('TRD (baseline)', 'FRD (optimized)', 'Location', 'best');
                    set(leg, 'Interpreter', 'latex', 'FontSize', 9, 'Color', 'white', ...
                             'EdgeColor', 'black', 'TextColor', 'black')
                end

                % Set Y-axis limits (adjusted for VSMP and VDC)
                if jj == 1  % VSMP
                    current_ylim = ylim;
                    ylim([current_ylim(1) 5])
                elseif jj == 5  % VDC
                    current_ylim = ylim;
                    ylim([current_ylim(1) 4])
                end

                % Set X-axis limits (VDC limited to 300 rad/s)
                if jj == 5  % VDC
                    xlim([1 300])
                end

                % Grid
                grid on
                set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.3, 'GridLineStyle', ':')
                set(ax, 'GridLineWidth', 0.5);
                box on
            end

            % Apply publication formatting to this figure
            format_figure_for_publication(figure(ii))
        end

        %------------------------------------------------------------------
        % Display computed metrics with professional formatting
        %------------------------------------------------------------------
        disp('=========================================================================')
        disp('===== CASE 13: TRD vs FRD - Closed-loop frequency response ============')
        disp('=========================================================================')
        disp(' ')
        disp('DFIG configuration: [1 (SCR=10), 3 (SCR=5)]')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('Control loops:')
        disp('-------------------------------------------------------------------------')
        for jj = 1:nCONTROL
            fprintf('%d. %s\n', jj, ControlLabel{jj});
        end
        disp(' ')
        disp('=========================================================================')
        disp('CLOSED-LOOP FREQUENCY RESPONSE: F(s) = C(s)P(s)/(1+C(s)P(s))')
        disp('=========================================================================')
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('RESONANCE PEAK Mr [dB] - TRD (Time-Response Design):')
        disp('(Maximum of |F(jω)|, indicates overshoot tendency and robustness)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Mr_trd(1,:));
        fprintf('SCR=5:  %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Mr_trd(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('RESONANCE PEAK Mr [dB] - FRD (Frequency-Response Design):')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Mr_frd(1,:));
        fprintf('SCR=5:  %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', Mr_frd(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('RESONANCE FREQUENCY ωr [rad/s] - TRD:')
        disp('(Frequency where |F(jω)| reaches maximum, bandwidth indicator)')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', wr_trd(1,:));
        fprintf('SCR=5:  %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', wr_trd(2,:));
        disp(' ')
        disp('-------------------------------------------------------------------------')
        disp('RESONANCE FREQUENCY ωr [rad/s] - FRD:')
        disp('-------------------------------------------------------------------------')
        disp('             VSMP    VSMQ    RSCd    RSCq     VDC    GSCd    GSCq')
        fprintf('SCR=10: %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', wr_frd(1,:));
        fprintf('SCR=5:  %8.3f %7.3f %7.3f %7.3f %7.3f %7.3f %7.3f\n', wr_frd(2,:));
        disp(' ')
        disp('=========================================================================')
        disp('INTERPRETATION GUIDELINES:')
        disp('=========================================================================')
        disp(' ')
        disp('RESONANCE PEAK (Mr):')
        disp('  • Mr < 3 dB:    Excellent damping, minimal overshoot')
        disp('  • Mr = 3-6 dB:  Good damping, acceptable overshoot')
        disp('  • Mr > 6 dB:    Low damping, significant overshoot')
        disp(' ')
        disp('COMPARISON (TRD vs FRD):')
        disp('  • Lower Mr in FRD → Improved damping and robustness')
        disp('  • Similar Mr → Frequency design preserves time-domain performance')
        disp('  • Higher ωr in FRD → Faster response (higher bandwidth)')
        disp(' ')
        disp('DESIGN TRADE-OFFS:')
        disp('  • Bandwidth vs Damping: Higher bandwidth may reduce damping')
        disp('  • Robustness vs Performance: Lower peaks improve stability margins')
        disp('  • Grid Strength Impact: Weaker grid (SCR=5) typically shows higher Mr')
        disp(' ')
        disp('FIGURES GENERATED:')
        disp('  • Figure 1: DFIG #1 (SCR transformer = 10, strong grid)')
        disp('  • Figure 2: DFIG #3 (SCR transformer = 5, weak grid)')
        disp('=========================================================================')
        disp(' ')
   %--------------------------------------------------------------
   %--------------------------------------------------------------
    otherwise
end  % End of switch figureType

%==========================================================================
% AUTOMATIC FIGURE EXPORT (Publication Quality)
%==========================================================================
% Save all generated figures to FIGURES/<slug>/ directory with:
%   - Descriptive filenames
%   - LaTeX interpreter for all text
%   - Publication-quality formatting (IEEE standards)

% Get all open figure handles
all_figs = findobj('Type', 'figure');

if ~isempty(all_figs)
    fprintf('\n--- Preparing figures for publication and saving ---\n');
    fprintf('Export directory: %s\n', figure_export_dir);

    % Define descriptive names for each case
    case_names = get_case_descriptive_names();
    base_name = case_names{figureType};

    for i = 1:length(all_figs)
        fig_handle = all_figs(i);
        fig_number = fig_handle.Number;

        % Apply publication formatting (LaTeX, fonts, size, etc.)
        format_figure_for_publication(fig_handle);

        % Generate descriptive filename: SLUG_##_DescriptiveName[_Fig#]
        % Example: FRD_OPT_01_TRD_ClosedLoop_StepResponse_Fig1
        if length(all_figs) == 1
            % Single figure: SLUG_##_DescriptiveName
            filename_base = sprintf('%s_%02d_%s', slug, figureType, base_name);
        else
            % Multiple figures: SLUG_##_DescriptiveName_Fig#
            filename_base = sprintf('%s_%02d_%s_Fig%d', slug, figureType, base_name, fig_number);
        end

        % Save in dual format: .fig (editable) + .pdf (IEEE publication)
        fig_path = fullfile(figure_export_dir, [filename_base, '.fig']);
        pdf_path = fullfile(figure_export_dir, [filename_base, '.pdf']);

        % Save .fig format
        savefig(fig_handle, fig_path);

        % Save .pdf format (IEEE quality - vector graphics)
        if exist('exportgraphics', 'file')
            % Use exportgraphics (R2020a+) for best quality
            exportgraphics(fig_handle, pdf_path, ...
                'ContentType', 'vector', ...
                'Resolution', 300, ...
                'BackgroundColor', 'white');
        else
            % Fallback to print for older MATLAB versions
            print(fig_handle, pdf_path, '-dpdf', '-r300', '-painters', '-fillpage');
        end

        fprintf('  Saved: %s (.fig + .pdf)\n', filename_base);
    end

    fprintf('Total figures saved: %d × 2 formats (publication-ready .fig + .pdf)\n', length(all_figs));
else
    fprintf('No figures generated for case %d\n', figureType);
end

end  % End of main function PLOT_LIN_MODEL

%==========================================================================
% HELPER FUNCTION: Get descriptive names for each case
%==========================================================================
function case_names = get_case_descriptive_names()
% GET_CASE_DESCRIPTIVE_NAMES - Returns descriptive names for figure export
%
% Returns a cell array with publication-ready names for each of the 13 cases

    case_names = {
        'TRD_ClosedLoop_StepResponse'       % Case 1  - TRD controllers step response
        'DFIG_Comparison_SCR'               % Case 2  - Grid strength comparison
        'Interaction_ImpulseResponse'       % Case 3  - Control loop interactions
        'Controller_Correlation'            % Case 4  - Correlation heatmaps
        'DFIG_CrossCorrelation'             % Case 5  - Cross-DFIG correlation
        'FreqPCC_PowerRefSteps'             % Case 6  - Freq/PCC response to ref steps
        'Plant_OpenLoop_Black'              % Case 7  - Plant and open-loop Nichols
        'Sensitivity_Functions'             % Case 8  - S(s) and T(s) robustness
        'ClosedLoop_FreqResponse'           % Case 9  - Closed-loop Bode magnitude
        'FreqPCC_LoadSteps'                 % Case 10 - Freq/PCC response to load
        'TRDvsFRD_StepResponse'             % Case 11 - TRD vs FRD time comparison
        'TRDvsFRD_PlantFreqResponse'        % Case 12 - TRD vs FRD plant Nichols
        'TRDvsFRD_ClosedLoopFreqResponse'   % Case 13 - TRD vs FRD closed-loop Bode
    };
end

%==========================================================================
% HELPER FUNCTION: Format figure for publication
%==========================================================================
function format_figure_for_publication(fig_handle)
% FORMAT_FIGURE_FOR_PUBLICATION - Apply IEEE publication standards to figure
%
% FORMATTING APPLIED:
%   - LaTeX interpreter for all text (titles, labels, legends)
%   - IEEE standard fonts: Times New Roman, 10pt
%   - Figure size: 7×5 inches (suitable for single-column or slides)
%   - Line widths: 1.5pt for visibility
%   - Grid: subtle dotted lines
%   - White background
%   - High-resolution rendering settings

    % Set figure properties - WHITE BACKGROUND
    set(fig_handle, 'Color', 'white');
    set(fig_handle, 'InvertHardcopy', 'off');  % Preserve colors when saving
    set(fig_handle, 'Units', 'inches');

    % IEEE standard figure size (can be scaled for double-column: 3.5 inches)
    fig_pos = get(fig_handle, 'Position');
    set(fig_handle, 'Position', [fig_pos(1:2), 10, 7]);  % Larger for subplots

    % Paper settings for export
    set(fig_handle, 'PaperPositionMode', 'auto');
    set(fig_handle, 'PaperUnits', 'inches');
    set(fig_handle, 'PaperSize', [10, 7]);

    % Find all axes in the figure
    all_axes = findall(fig_handle, 'Type', 'axes');

    for ax_idx = 1:length(all_axes)
        ax = all_axes(ax_idx);

        % Skip legend and colorbar axes
        if strcmp(get(ax, 'Tag'), 'legend') || strcmp(get(ax, 'Tag'), 'Colorbar')
            continue;
        end

        % WHITE BACKGROUND for axes (with error handling for special plot types)
        try
            set(ax, 'Color', 'white');
            set(ax, 'XColor', [0 0 0]);  % Black X-axis
            set(ax, 'YColor', [0 0 0]);  % Black Y-axis
        catch
            % Some plot types (like Nichols) don't support these properties
            % Continue with other formatting
        end

        % Font settings (IEEE standard) - BLACK TEXT
        set(ax, 'FontName', 'Times New Roman');
        set(ax, 'FontSize', 10);
        set(ax, 'FontWeight', 'normal');

        % LaTeX interpreter for all text
        set(ax, 'TickLabelInterpreter', 'latex');

        % Title - BLACK TEXT
        title_obj = get(ax, 'Title');
        if ~isempty(title_obj)
            set(title_obj, 'Interpreter', 'latex');
            set(title_obj, 'FontSize', 11);
            set(title_obj, 'FontWeight', 'bold');
            set(title_obj, 'Color', [0 0 0]);  % Black text
        end

        % X-axis label - BLACK TEXT
        xlabel_obj = get(ax, 'XLabel');
        if ~isempty(xlabel_obj)
            set(xlabel_obj, 'Interpreter', 'latex');
            set(xlabel_obj, 'FontSize', 10);
            set(xlabel_obj, 'Color', [0 0 0]);  % Black text
        end

        % Y-axis label - BLACK TEXT
        ylabel_obj = get(ax, 'YLabel');
        if ~isempty(ylabel_obj)
            set(ylabel_obj, 'Interpreter', 'latex');
            set(ylabel_obj, 'FontSize', 10);
            set(ylabel_obj, 'Color', [0 0 0]);  % Black text
        end

        % Legend - BLACK TEXT on WHITE BACKGROUND
        legend_obj = findobj(ax, 'Type', 'legend');
        if ~isempty(legend_obj)
            set(legend_obj, 'Interpreter', 'latex');
            set(legend_obj, 'FontSize', 9);
            set(legend_obj, 'TextColor', [0 0 0]);  % Black text
            set(legend_obj, 'Color', [1 1 1]);      % White background
            set(legend_obj, 'EdgeColor', [0 0 0]);  % Black border
        end

        % Line properties (all lines in this axes)
        lines = findall(ax, 'Type', 'line');
        set(lines, 'LineWidth', 1.5);

        % Grid settings (subtle dark gray on white background)
        grid(ax, 'on');
        set(ax, 'GridLineStyle', ':');
        set(ax, 'GridColor', [0.15 0.15 0.15]);  % Dark gray
        set(ax, 'GridAlpha', 0.25);  % Subtle transparency

        % Box around plot
        box(ax, 'on');
        set(ax, 'LineWidth', 1);
    end

    % Renderer settings for high quality
    set(fig_handle, 'Renderer', 'painters');  % Vector graphics
end

%==========================================================================
% HELPER FUNCTION: List available files in directory
%==========================================================================
function file_list = list_available_files(directory)
% LIST_AVAILABLE_FILES - List LIN_MODEL_*.mat files in directory
%
% Helper function to provide user-friendly error messages when file not found

    if ~exist(directory, 'dir')
        file_list = '  (Directory does not exist)';
        return;
    end

    % Find all LIN_MODEL_*.mat files
    files = dir(fullfile(directory, 'LIN_MODEL_*.mat'));

    if isempty(files)
        file_list = '  (No LIN_MODEL files found)';
    else
        % Extract slugs from filenames
        slugs = cell(length(files), 1);
        for i = 1:length(files)
            % Extract slug from LIN_MODEL_XXX.mat
            name = files(i).name;
            slug = extractBetween(name, 'LIN_MODEL_', '.mat');
            if ~isempty(slug)
                slugs{i} = sprintf('  - %s  (%s)', slug{1}, name);
            end
        end

        % Create formatted list
        file_list = strjoin(slugs, '\n');
    end
end

