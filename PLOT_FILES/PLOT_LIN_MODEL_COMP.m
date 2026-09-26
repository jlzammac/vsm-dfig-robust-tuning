function PLOT_LIN_MODEL_COMP(slug_1, slug_2, figureType)
% PLOT_LIN_MODEL_COMP - Compare linear model performance between two control designs
%
% SYNTAX:
%   PLOT_LIN_MODEL_COMP(slug_1, slug_2, figureType)
%
% INPUTS:
%   slug_1      - File slug for first control design (e.g., '20251104_061826_SWEEP_FRD_4DFIG')
%   slug_2      - File slug for second control design (e.g., '20251107_103038_SWEEP_VI_OPT_4DFIG')
%   figureType  - Integer (1-7) selecting plot type
%
% FIGURE TYPES:
%   1 - Closed-loop step response comparison (IEEE publication quality)
%       • Compares 7 control loops between two designs
%       • Controllers: VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq
%       • Operating points × DFIGs 1 and 3 (SCR = 10 and 5)
%       • Black lines: Design 1 | Red lines: Design 2
%       • Legend in first subplot (VSMP) for design identification
%       • Displays DC gains for VSMP controller
%       • Time windows: [1.5, 3, 0.01, 0.01, 0.1, 0.01, 0.01] seconds
%       • IEEE formatting: LaTeX labels, Times New Roman, white background
%       • 3×3 subplot grid with detailed performance tables
%
%   2 - Frequency/PCC voltage for P/Q reference steps
%       • Response to power reference changes
%       • Calculates ROCOF (Rate of Change of Frequency)
%       • Calculates ROCOV (Rate of Change of Voltage)
%       • Nadir metrics for frequency and voltage
%       • Time window: 5 seconds
%
%   3 - Open-loop frequency response (Nichols plot)
%       • Black diagram for loop transfer function L(s) = G(s)C(s)
%       • Gain margin (GM) and phase margin (PM) calculation
%       • Unity-gain crossover frequency (wo)
%       • -180° crossover frequency (wu)
%       • Frequency ranges: controller-dependent
%
%   4 - Sensitivity and complementary sensitivity
%       • S(s) = 1/(1+L(s)) - Sensitivity function
%       • T(s) = L(s)/(1+L(s)) - Complementary sensitivity
%       • Maximum sensitivity (Ms) and frequency (ws)
%       • Maximum complementary sensitivity (Mt) and frequency (wt)
%       • Y-axis limit: [-15, 10] dB
%
%   5 - Closed-loop frequency response
%       • Transfer function T(s) Bode magnitude
%       • Resonance peak (Mr) in dB
%       • Resonance frequency (wr) in rad/s
%       • Y-axis limit: [-15, 10] dB
%
%   6 - Frequency/PCC voltage for load steps
%       • Response to active/reactive load disturbances
%       • ROCOF and nadir for active load step
%       • ROCOV and nadir for reactive load step
%       • Time windows: [5, 10] seconds
%
%   7 - 2×2 comparison subplots
%       • P-step → Frequency and PCC voltage
%       • Q-step → Frequency and PCC voltage
%       • Configurable DFIG selection (default: DFIG 3)
%       • Optional Y-axis linking (default: false)
%       • Customizable colors and line widths
%       • Time window: 5 seconds
%
% FILE LOADING:
%   Files are automatically loaded from:
%   RESULTS/LINEAR_ANALYSIS/LINEAR_ANALYSIS_<slug>.mat
%
% EXAMPLES:
%   % Compare frequency-response design vs VI-optimized design
%   PLOT_LIN_MODEL_COMP('20251104_061826_SWEEP_FRD_4DFIG', ...
%                       '20251107_103038_SWEEP_VI_OPT_4DFIG', 7)
%
%   % Analyze sensitivity functions for both designs
%   PLOT_LIN_MODEL_COMP('20251104_061826_SWEEP_FRD_4DFIG', ...
%                       '20251107_103038_SWEEP_VI_OPT_4DFIG', 4)
%
% OUTPUTS:
%   Generates comparative plots and displays performance metrics tables
%   in the command window (OPset tables with calculated metrics)
%
% NOTES:
%   • All plots compare design 1 (black) vs design 2 (red)
%   • Metrics are calculated for DFIGs 1 and 3 (SCR = 10 and 5)
%   • Unstable operating points are excluded from plots
%   • Performance metrics are sorted in descending order
%
% See also: LINEARIZE, LINEAR_ANALYSIS, PLOT_LIN_MODEL
%
% Last modified: 2025-01-07

%==========================================================================
% SECTION 1: FILE LOADING AND VALIDATION
%==========================================================================
% Load linear analysis results for both control designs from the centralized
% RESULTS/LINEAR_ANALYSIS directory. Validates file existence and provides
% helpful error messages listing available files if slugs are incorrect.
%
% INPUT SLUGS FORMAT:
%   - Timestamp: YYYYMMDD_HHMMSS
%   - Analysis type: ENDPOINTS (8 OPs) or SWEEP (225 OPs)
%   - Design method: FRD, TRD, VI_OPT, QCP_OPT, etc.
%   - System size: 4DFIG, 8DFIG, etc.
%   Example: '20251104_061826_SWEEP_FRD_4DFIG'
%
% EXPECTED FILE STRUCTURE:
%   RESULTS/LINEAR_ANALYSIS/LINEAR_ANALYSIS_<slug>.mat
%   └── LIN_MODEL_ARRAY (struct)
%       ├── OPset (table): Operating point parameters
%       └── LIN_MODEL (cell array): Linearized models for each OP
%           └── {i} (struct for i-th operating point)
%               ├── ssModel: State-space representation
%               ├── MODEL: System parameters
%               ├── CONTROL: Controller parameters
%               └── stability: Boolean flag
%--------------------------------------------------------------------------

%--------------------------------------------------------------
% Step 1.1: Construct file paths from slugs
%--------------------------------------------------------------
% IMPORTANT: This script must be executed from PLOT_FILES directory
% Relative path from PLOT_FILES to RESULTS/LINEAR_ANALYSIS
resultsDir = fullfile('..', 'RESULTS', 'LINEAR_ANALYSIS');
filename_1 = sprintf('LINEAR_ANALYSIS_%s.mat', slug_1);
filename_2 = sprintf('LINEAR_ANALYSIS_%s.mat', slug_2);
filepath_1 = fullfile(resultsDir, filename_1);
filepath_2 = fullfile(resultsDir, filename_2);

%--------------------------------------------------------------
% Step 1.2: Validate file existence with helpful error messages
%--------------------------------------------------------------
if ~isfile(filepath_1)
    % List all available .mat files in the directory
    files = dir(fullfile(resultsDir, '*.mat'));
    fileList = strjoin({files.name}, '\n  ');
    error('File not found: %s\n\nAvailable files in %s:\n  %s', ...
          filepath_1, resultsDir, fileList);
end
if ~isfile(filepath_2)
    % List all available .mat files in the directory
    files = dir(fullfile(resultsDir, '*.mat'));
    fileList = strjoin({files.name}, '\n  ');
    error('File not found: %s\n\nAvailable files in %s:\n  %s', ...
          filepath_2, resultsDir, fileList);
end

%--------------------------------------------------------------
% Step 1.3: Load linear analysis data structures
%--------------------------------------------------------------
fprintf('Loading design 1: %s\n', filename_1);
data_1 = load(filepath_1);
LIN_MODEL_ARRAY_1 = data_1.LIN_MODEL_ARRAY;

fprintf('Loading design 2: %s\n', filename_2);
data_2 = load(filepath_2);
LIN_MODEL_ARRAY_2 = data_2.LIN_MODEL_ARRAY;

%==========================================================================
% SECTION 2: DATA EXTRACTION AND INITIALIZATION
%==========================================================================
% Extract operating point tables and linearized models from both designs.
% Close all existing figures to ensure clean visualization environment.
% Both designs must have identical operating point sets for valid comparison.
%
% OPERATING POINT TABLE (OPset):
%   - Vpcc: PCC voltage (pu)
%   - Pdfig: Mean DFIG active power (pu)
%   - SCRgrid: Short-circuit ratio of grid (dimensionless)
%   - Additional columns added during analysis (eigenvalues, metrics, etc.)
%
% LINEAR MODEL STRUCTURE:
%   Each cell LIN_MODEL{i} contains linearization at i-th operating point:
%   - ssModel: State-space matrices (A, B, C, D)
%   - MODEL: System parameters (DFIG, GRID, LOAD, etc.)
%   - CONTROL: Controller parameters (VSMP, VSMQ, RSC, VDC, GSC)
%   - stability: Boolean indicating if all eigenvalues have negative real parts
%--------------------------------------------------------------------------

%--------------------------------------------------------------
% Step 2.1: Extract operating points and linear models
%--------------------------------------------------------------
close('all')  % Clear all existing figures
OPset = LIN_MODEL_ARRAY_1.OPset;  % Operating point table (same for both designs)
numOP = size(OPset,1);             % Number of operating points analyzed
LIN_MODEL_1 = LIN_MODEL_ARRAY_1.LIN_MODEL;  % Linearized models for design 1
LIN_MODEL_2 = LIN_MODEL_ARRAY_2.LIN_MODEL;  % Linearized models for design 2

%--------------------------------------------------------------
% Step 2.2: Extract system and controller parameters
%--------------------------------------------------------------
% Use first operating point to extract MODEL and CONTROL structures
% (system configuration is constant across OPs, only linearization changes)
MODEL_1 = LIN_MODEL_1{1}.MODEL;      % System parameters for design 1
CONTROL_1 = LIN_MODEL_1{1}.CONTROL;  % Controller parameters for design 1
MODEL_2 = LIN_MODEL_2{1}.MODEL;      % System parameters for design 2
CONTROL_2 = LIN_MODEL_2{1}.CONTROL;  % Controller parameters for design 2

%--------------------------------------------------------------
% Step 2.3: Initialize Laplace variable for transfer functions
%--------------------------------------------------------------
% Required for constructing controller transfer functions C(s)
s = tf('s');

%==========================================================================
% SECTION 3: CONTROLLER PARAMETER EXTRACTION
%==========================================================================
% Extract all controller parameters from both designs for potential use in
% frequency-domain analysis (cases 3-5). Parameters are extracted from the
% first DFIG; vectorial parameters are available in CONTROL.*.PARAM arrays.
%
% CONTROLLER ARCHITECTURES:
%   1. VSMP (Virtual Synchronous Machine - Active Power):
%      - Transfer function: C(s) = (1 + Dd·s)/(1 + 2H/Dp·s)
%      - H: Inertia constant [s]
%      - Dp: Steady-state damping coefficient
%      - Dd: Transient damping coefficient
%      - der2error: 2-DOF parameter (1=1-DOF, ≠1=2-DOF)
%
%   2. VSMQ (Virtual Synchronous Machine - Reactive Power):
%      - Transfer function: C(s) = K_Fs_ref (proportional gain)
%      - K_Fs_ref: Voltage droop coefficient
%
%   3-7. PI Controllers (RSCd, RSCq, VDC, GSCd, GSCq):
%      - Transfer function: C(s) = Kp + Ki/s
%      - Kp: Proportional gain
%      - Ki: Integral gain
%      - b: 2-DOF setpoint weighting (1=1-DOF, ≠1=2-DOF)
%
% NOTE: Parameters indexed with (1) select first DFIG. For multi-DFIG
%       systems, full parameter vectors are available in CONTROL.*.PARAM
%--------------------------------------------------------------------------

%--------------------------------------------------------------
% VSMP (Virtual Synchronous Machine - Active Power)
%--------------------------------------------------------------
H_1 = CONTROL_1.VSMP.PARAM.H(1);          % Inertia [s] - Design 1
H_2 = CONTROL_2.VSMP.PARAM.H(1);          % Inertia [s] - Design 2
Dp_1 = CONTROL_1.VSMP.PARAM.Dp(1);        % Steady-state damping - Design 1
Dp_2 = CONTROL_2.VSMP.PARAM.Dp(1);        % Steady-state damping - Design 2
Dd_1 = CONTROL_1.VSMP.PARAM.Dd(1);        % Transient damping - Design 1
Dd_2 = CONTROL_2.VSMP.PARAM.Dd(1);        % Transient damping - Design 2
der2error_1 = CONTROL_1.VSMP.PARAM.der2error(1);  % 2-DOF parameter - Design 1
der2error_2 = CONTROL_2.VSMP.PARAM.der2error(1);  % 2-DOF parameter - Design 2

%--------------------------------------------------------------
% VSMQ (Virtual Synchronous Machine - Reactive Power)
%--------------------------------------------------------------
K_Fs_ref_1 = CONTROL_1.VSMQ.PARAM.K_Fs_ref(1);  % Voltage droop - Design 1
K_Fs_ref_2 = CONTROL_2.VSMQ.PARAM.K_Fs_ref(1);  % Voltage droop - Design 2

%--------------------------------------------------------------
% RSCd (Rotor-Side Converter d-axis - Reactive Power)
%--------------------------------------------------------------
Kp_ird_1 = CONTROL_1.RSCd.PARAM.Kp(1);   % Proportional gain - Design 1
Ki_ird_1 = CONTROL_1.RSCd.PARAM.Ki(1);   % Integral gain - Design 1
b_ird_1 = CONTROL_1.RSCd.PARAM.b(1);     % 2-DOF parameter - Design 1
Kp_ird_2 = CONTROL_2.RSCd.PARAM.Kp(1);   % Proportional gain - Design 2
Ki_ird_2 = CONTROL_2.RSCd.PARAM.Ki(1);   % Integral gain - Design 2
b_ird_2 = CONTROL_2.RSCd.PARAM.b(1);     % 2-DOF parameter - Design 2

%--------------------------------------------------------------
% RSCq (Rotor-Side Converter q-axis - Active Power)
%--------------------------------------------------------------
Kp_irq_1 = CONTROL_1.RSCq.PARAM.Kp(1);   % Proportional gain - Design 1
Ki_irq_1 = CONTROL_1.RSCq.PARAM.Ki(1);   % Integral gain - Design 1
b_irq_1 = CONTROL_1.RSCq.PARAM.b(1);     % 2-DOF parameter - Design 1
Kp_irq_2 = CONTROL_2.RSCq.PARAM.Kp(1);   % Proportional gain - Design 2
Ki_irq_2 = CONTROL_2.RSCq.PARAM.Ki(1);   % Integral gain - Design 2
b_irq_2 = CONTROL_2.RSCq.PARAM.b(1);     % 2-DOF parameter - Design 2

%--------------------------------------------------------------
% VDC (DC-Link Voltage Control)
%--------------------------------------------------------------
Kp_vdc_1 = CONTROL_1.VDC.PARAM.Kp(1);    % Proportional gain - Design 1
Ki_vdc_1 = CONTROL_1.VDC.PARAM.Ki(1);    % Integral gain - Design 1
b_vdc_1 = CONTROL_1.VDC.PARAM.b(1);      % 2-DOF parameter - Design 1
Kp_vdc_2 = CONTROL_2.VDC.PARAM.Kp(1);    % Proportional gain - Design 2
Ki_vdc_2 = CONTROL_2.VDC.PARAM.Ki(1);    % Integral gain - Design 2
b_vdc_2 = CONTROL_2.VDC.PARAM.b(1);      % 2-DOF parameter - Design 2

%--------------------------------------------------------------
% GSCd (Grid-Side Converter d-axis - Reactive Power)
%--------------------------------------------------------------
Kp_igd_1 = CONTROL_1.GSCd.PARAM.Kp(1);   % Proportional gain - Design 1
Ki_igd_1 = CONTROL_1.GSCd.PARAM.Ki(1);   % Integral gain - Design 1
b_igd_1 = CONTROL_1.GSCd.PARAM.b(1);     % 2-DOF parameter - Design 1
Kp_igd_2 = CONTROL_2.GSCd.PARAM.Kp(1);   % Proportional gain - Design 2
Ki_igd_2 = CONTROL_2.GSCd.PARAM.Ki(1);   % Integral gain - Design 2
b_igd_2 = CONTROL_2.GSCd.PARAM.b(1);     % 2-DOF parameter - Design 2

%--------------------------------------------------------------
% GSCq (Grid-Side Converter q-axis - Active Power)
%--------------------------------------------------------------
Kp_igq_1 = CONTROL_1.GSCq.PARAM.Kp(1);   % Proportional gain - Design 1
Ki_igq_1 = CONTROL_1.GSCq.PARAM.Ki(1);   % Integral gain - Design 1
b_igq_1 = CONTROL_1.GSCq.PARAM.b(1);     % 2-DOF parameter - Design 1
Kp_igq_2 = CONTROL_2.GSCq.PARAM.Kp(1);   % Proportional gain - Design 2
Ki_igq_2 = CONTROL_2.GSCq.PARAM.Ki(1);   % Integral gain - Design 2
b_igq_2 = CONTROL_2.GSCq.PARAM.b(1);     % 2-DOF parameter - Design 2 

%==========================================================================
% SECTION 4: LABELS AND CONTROLLER TRANSFER FUNCTIONS
%==========================================================================
% Define labels for plots and construct controller transfer functions C(s).
%--------------------------------------------------------------------------

%--------------------------------------------------------------
% Labels for Plots
%--------------------------------------------------------------
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
DFIGLabel = {'SCR trafo = 10', 'SCR trafo = 5'};  % DFIG 1 and 3 labels

%--------------------------------------------------------------
% System Dimensions
%--------------------------------------------------------------
nDFIG = MODEL_1.DFIG.PARAM.nDFIG;  % Number of DFIGs (typically 4)
nCONTROL = 7;                       % Number of control loops per DFIG

%--------------------------------------------------------------
% Controller Transfer Functions C(s) - Design 1
%--------------------------------------------------------------
currentCss_1 = {
    ss((1 + Dd_1*s)/(1 + 2*H_1/Dp_1*s));  % VSMP: Lead-lag compensator
    ss(K_Fs_ref_1);                        % VSMQ: Proportional gain
    ss(Kp_ird_1 + Ki_ird_1/s);            % RSCd: PI controller
    ss(Kp_irq_1 + Ki_irq_1/s);            % RSCq: PI controller
    ss(Kp_vdc_1 + Ki_vdc_1/s);            % VDC:  PI controller
    ss(Kp_igd_1 + Ki_igd_1/s);            % GSCd: PI controller
    ss(Kp_igq_1 + Ki_igq_1/s);            % GSCq: PI controller
    };

%--------------------------------------------------------------
% Controller Transfer Functions C(s) - Design 2
%--------------------------------------------------------------
currentCss_2 = {
    ss((1 + Dd_2*s)/(1 + 2*H_2/Dp_2*s));  % VSMP: Lead-lag compensator
    ss(K_Fs_ref_2);                        % VSMQ: Proportional gain
    ss(Kp_ird_2 + Ki_ird_2/s);            % RSCd: PI controller
    ss(Kp_irq_2 + Ki_irq_2/s);            % RSCq: PI controller
    ss(Kp_vdc_2 + Ki_vdc_2/s);            % VDC:  PI controller
    ss(Kp_igd_2 + Ki_igd_2/s);            % GSCd: PI controller
    ss(Kp_igq_2 + Ki_igq_2/s);            % GSCq: PI controller
    };

%==========================================================================
% SECTION 5: FIGURE TYPE SELECTION AND COMPARATIVE ANALYSIS
%==========================================================================
% Execute the requested visualization/analysis case (1-7) based on
% figureType parameter. Each case generates comparative plots with IEEE
% publication formatting and displays performance metrics for both designs.
%--------------------------------------------------------------------------

switch (figureType)
   %======================================================================
   % CASE 1: Closed-Loop Step Response Comparison
   %======================================================================
   % PURPOSE:
   %   Compare closed-loop step responses for all 7 control loops between
   %   two different control designs across multiple operating points.
   %   Evaluates control performance, interaction effects, and robustness.
   %
   % ANALYSIS TYPE:
   %   Compatible with both ENDPOINTS (8 OPs) and SWEEP (225 OPs)
   %
   % METHODOLOGY:
   %   1. Extract complementary sensitivity T(s) for each controller
   %   2. Compute step response y(t) = -T(s) × u_step(t)
   %   3. Plot overlaid responses for design 1 (black) vs design 2 (red)
   %   4. Calculate DC gains for VSMP controller as performance metric
   %   5. Display comparison tables with operating point details
   %
   % CONTROL LOOPS ANALYZED:
   %   - VSMP: Virtual Synchronous Machine active power control
   %   - VSMQ: Virtual Synchronous Machine reactive power control
   %   - RSCd: Rotor-side converter d-axis current (reactive power)
   %   - RSCq: Rotor-side converter q-axis current (active power)
   %   - VDC: DC-link voltage control
   %   - GSCd: Grid-side converter d-axis current (reactive power)
   %   - GSCq: Grid-side converter q-axis current (active power)
   %
   % DFIGS ANALYZED:
   %   - DFIG 1: SCR_transformer = 10 (strong connection)
   %   - DFIG 3: SCR_transformer = 5 (weak connection)
   %
   % TIME HORIZONS (user-configurable in Step 2 below):
   %   - VSMP: 1.5 s (slow power dynamics)
   %   - VSMQ: 3.0 s (very slow voltage dynamics)
   %   - RSCd: 0.01 s = 10 ms (fast rotor current control)
   %   - RSCq: 0.01 s = 10 ms (fast rotor current control)
   %   - VDC: 0.1 s = 100 ms (medium DC-link dynamics)
   %   - GSCd: 0.01 s = 10 ms (very fast grid-side current)
   %   - GSCq: 0.01 s = 10 ms (very fast grid-side current)
   %
   % OUTPUTS:
   %   - Figure: 3×3 subplot grid (7 controllers + 2 empty)
   %   - Console: Extended OPset tables with VSMP DC gains for both designs
   %   - Formatting: IEEE publication standards (LaTeX, Times New Roman)
   %
   % INTERPRETATION:
   %   - Black curves: Design 1 baseline performance
   %   - Red curves: Design 2 performance (overlaid for comparison)
   %   - Overshoot: Indicates damping quality and interaction effects
   %   - Settling time: Controller speed and stability margin
   %   - DC gain variation: Operating point sensitivity (VSMP only)
   %   - Design comparison: Direct visual assessment of improvements
   %----------------------------------------------------------------------
    case 1 % Closed-loop step response comparison
   %----------------------------------------------------------------------
       % Step 1: Select DFIGs for comparison
       %----------------------------------------------------------------------
       hDFIG = [1 3];  % DFIG 1 (SCR=10) and DFIG 3 (SCR=5)
       SCRdfig = MODEL_1.DFIG.PARAM.SCR_transformer(hDFIG);

       % Extended operating point sets (duplicate for each DFIG)
       OPsetExt_1 = repmat(OPset, 2, 1);
       OPsetExt_1.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];
       OPsetExt_2 = repmat(OPset, 2, 1);
       OPsetExt_2.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];

       %----------------------------------------------------------------------
       % Step 2: Define simulation time horizons for each control loop
       %----------------------------------------------------------------------
       % USER-CONFIGURABLE: Adjust time windows to zoom in/out on dynamics
       % Time horizons optimized for each controller's dynamics
       % (matched to PLOT_LIN_MODEL_ARRAY.m case 1 for consistency)
       %
       % RECOMMENDED VALUES:
       %   - Slow dynamics (VSMP, VSMQ): 1-5 seconds
       %   - Fast current loops (RSC, GSC): 0.005-0.05 seconds (5-50 ms)
       %   - Medium dynamics (VDC): 0.05-0.5 seconds (50-500 ms)
       %----------------------------------------------------------------------
       tfin = [1.5;    % VSMP: slow power dynamics (seconds)
               3.0;    % VSMQ: very slow voltage dynamics (seconds)
               0.02;   % RSCd: fast rotor current control (10 ms)
               0.02;   % RSCq: fast rotor current control (10 ms)
               0.1;    % VDC: medium DC-link voltage dynamics (100 ms)
               0.02;   % GSCd: very fast grid-side current control (10 ms)
               0.02];  % GSCq: very fast grid-side current control (10 ms)

       %----------------------------------------------------------------------
       % Step 3: Create figure with publication formatting
       %----------------------------------------------------------------------
       fig = figure('Name', 'Case 1: Closed-Loop Step Response Comparison', ...
                    'Position', [100, 100, 1200, 900], ...
                    'Color', 'white');

       %----------------------------------------------------------------------
       % Step 4: Generate step response plots
       %----------------------------------------------------------------------
       for nn = 1:nCONTROL
           subplot(3, 3, nn)
           hold on

           % Loop over DFIGs and operating points
           for ii = 1:length(hDFIG)
               for jj = 1:numOP
                   % ---- Design 1 (Black) ----
                   ssModel = LIN_MODEL_1{jj}.ssModel;
                   matA = ssModel.a;
                   matB = ssModel.b;
                   matC = ssModel.c;
                   matD = ssModel.d;

                   % Extract complementary sensitivity T(s) for current control loop
                   indT = nCONTROL*(hDFIG(ii)-1) + nn;
                   Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));

                   % Compute step response
                   t = linspace(0, tfin(nn), 5000);
                   y1 = step(-Tss, t);

                   % Plot with black color (design 1)
                   plot(t, y1, 'k', 'LineWidth', 1.5)

                   % Store DC gain for VSMP control
                   if nn == 1
                       OPsetExt_1.VSMP_dcgain(numOP*(ii-1)+jj) = dcgain(-Tss);
                   end

                   % ---- Design 2 (Red) ----
                   ssModel = LIN_MODEL_2{jj}.ssModel;
                   matA = ssModel.a;
                   matB = ssModel.b;
                   matC = ssModel.c;
                   matD = ssModel.d;

                   % Extract complementary sensitivity T(s)
                   indT = nCONTROL*(hDFIG(ii)-1) + nn;
                   Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));

                   % Compute step response
                   y2 = step(-Tss, t);

                   % Plot with red color (design 2)
                   plot(t, y2, 'r', 'LineWidth', 1.5)

                   % Store DC gain for VSMP control
                   if nn == 1
                       OPsetExt_2.VSMP_dcgain(numOP*(ii-1)+jj) = dcgain(-Tss);
                   end
               end
           end

           % Subplot formatting with LaTeX interpreter
           xlim([0 tfin(nn)]);
           xlabel('$t$ (s)', 'Interpreter', 'latex', 'FontSize', 11);
           ylabel(OutputLabel{nn}, 'Interpreter', 'latex', 'FontSize', 11);
           title(ControlLabel{nn}, 'Interpreter', 'latex', 'FontSize', 12, ...
                 'FontWeight', 'bold', 'Color', 'k');
           grid on
           set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
                    'Color', 'white', 'XColor', 'k', 'YColor', 'k', ...
                    'GridLineStyle', ':', 'GridColor', 'k', 'GridAlpha', 0.15);
           box on

           % Add legend to first subplot (VSMP)
           if nn == 1
               % Create dummy invisible lines for legend
               h1 = plot(NaN, NaN, 'k', 'LineWidth', 1.5);
               h2 = plot(NaN, NaN, 'r', 'LineWidth', 1.5);
               legend([h1, h2], {'Design 1', 'Design 2'}, ...
                      'Interpreter', 'latex', 'FontSize', 9, ...
                      'Location', 'best', 'Box', 'on');
           end

           hold off
       end

       % Apply IEEE publication formatting
       format_figure_for_publication(fig);

       %----------------------------------------------------------------------
       % Step 5: Display results tables
       %----------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 1: Closed-Loop Step Response Comparison                   ║\n');
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Design 1: %-53s ║\n', slug_1);
       fprintf('║  Design 2: %-53s ║\n', slug_2);
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Operating Points Analyzed: %-3d                                  ║\n', numOP);
       fprintf('║  DFIGs Analyzed: DFIG 1 (SCR=10), DFIG 3 (SCR=5)                ║\n');
       fprintf('║  Control Loops: 7 (VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq)     ║\n');
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Plot Colors:                                                    ║\n');
       fprintf('║    - Black: Design 1 (baseline)                                  ║\n');
       fprintf('║    - Red:   Design 2 (comparison)                                ║\n');
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Figure Layout: 3x3 subplot grid                                 ║\n');
       fprintf('║  Plot Format: IEEE B&W compatible (distinct colors)              ║\n');
       fprintf('║  IEEE Formatting: Applied                                        ║\n');
       fprintf('╚══════════════════════════════════════════════════════════════════╝\n');
       fprintf('\n');

       fprintf('═══ DESIGN 1: Extended Operating Point Set with VSMP DC Gain ═══\n');
       disp(OPsetExt_1);
       fprintf('\n');

       fprintf('═══ DESIGN 2: Extended Operating Point Set with VSMP DC Gain ═══\n');
       disp(OPsetExt_2);
       fprintf('\n');

       fprintf('Interpretation Guide:\n');
       fprintf('  • VSMP_dcgain: DC gain variation indicates operating point sensitivity\n');
       fprintf('  • Overshoot: High overshoot suggests poor damping or interaction\n');
       fprintf('  • Settling time: Fast controllers (RSC/GSC) settle in <250 ms\n');
       fprintf('  • DFIG comparison: SCR=5 typically shows more oscillatory behavior\n');
       fprintf('  • Design comparison: Red vs black curves show control improvements\n');
       fprintf('\n');
   %======================================================================
   % CASE 2: Frequency and PCC Voltage Response Comparison
   %======================================================================
   % PURPOSE:
   %   Compare grid frequency and PCC voltage response to active (P) and
   %   reactive (Q) power reference steps between two control designs.
   %   Critical for grid code compliance analysis (ROCOF, ROCOV, nadir).
   %
   % ANALYSIS TYPE:
   %   Compatible with both ENDPOINTS (8 OPs) and SWEEP (225 OPs)
   %
   % METHODOLOGY:
   %   1. Extract frequency response F(s) from P/Q steps to f/Vpcc outputs
   %   2. Compute step response for 5-second window
   %   3. Calculate ROCOF (Rate of Change of Frequency) from P step
   %   4. Calculate ROCOV (Rate of Change of Voltage) from Q step
   %   5. Identify frequency and voltage nadir (maximum deviation)
   %   6. Generate 2×2 subplot: P step (f, Vpcc) and Q step (f, Vpcc)
   %   7. Compare metrics between both designs
   %
   % GRID CODE METRICS:
   %   - ROCOF: df/dt at half-rise time (pu/s)
   %     Limit: Typically 1 Hz/s (0.02 pu/s @ 50 Hz)
   %   - ROCOV: dV/dt at half-rise time (pu/s)
   %     Limit: Typically 3%/s (0.03 pu/s)
   %   - Frequency nadir: Maximum frequency deviation (pu)
   %     Limit: Typically ±0.5 Hz (0.01 pu @ 50 Hz)
   %   - Voltage nadir: Maximum voltage deviation (pu)
   %     Limit: Typically ±10% (0.1 pu)
   %
   % DFIGS ANALYZED:
   %   - DFIG 1: SCR_transformer = 10 (strong connection)
   %   - DFIG 3: SCR_transformer = 5 (weak connection)
   %
   % OUTPUTS:
   %   - Figure: 2×2 subplots (P step → f/Vpcc, Q step → f/Vpcc)
   %   - Console: 4 ranked tables per design (ROCOF, ROCOV, nadir_f, nadir_V)
   %   - Formatting: IEEE publication standards
   %
   % INTERPRETATION:
   %   - Black curves: Design 1 performance
   %   - Red curves: Design 2 performance
   %   - High ROCOF/ROCOV: Insufficient inertia or damping
   %   - Deep nadir: Weak grid or poor controller tuning
   %   - Unstable points: Excluded from plots and metrics
   %   - SCR=5: Typically shows worse performance than SCR=10
   %----------------------------------------------------------------------
    case 2 % Frequency and PCC voltage response comparison
   %----------------------------------------------------------------------
       % Step 1: Select DFIGs and configure analysis
       %----------------------------------------------------------------------
       hDFIG = [1 3];  % DFIG 1 (SCR=10) and DFIG 3 (SCR=5)
       SCRdfig = MODEL_1.DFIG.PARAM.SCR_transformer(hDFIG);

       %----------------------------------------------------------------------
       % Step 2: Create figure with publication formatting
       %----------------------------------------------------------------------
       fig = figure('Name', 'Case 2: Grid Response to P/Q Steps Comparison', ...
                    'Position', [100, 100, 1200, 800], ...
                    'Color', 'white');

       %----------------------------------------------------------------------
       % Step 3: Define time vectors and labels
       %----------------------------------------------------------------------
       t = {linspace(0, 5, 500); linspace(0, 5, 500)};  % 5-second windows
       outLabel = {'Frequency (pu)', 'PCC voltage (pu)'};
       titleLabel = {'P reference step', 'Q reference step'};

       %----------------------------------------------------------------------
       % Step 4: Initialize metrics storage
       %----------------------------------------------------------------------
       % ROCOX: Rate of Change (ROCOF for f, ROCOV for Vpcc)
       % nadir: Maximum deviation from steady state
       ROCOX_1 = NaN(length(hDFIG)*numOP, 2);  % [ROCOF, ROCOV] - Design 1
       nadir_1 = NaN(length(hDFIG)*numOP, 2);  % [nadir_f, nadir_V] - Design 1
       ROCOX_2 = NaN(length(hDFIG)*numOP, 2);  % [ROCOF, ROCOV] - Design 2
       nadir_2 = NaN(length(hDFIG)*numOP, 2);  % [nadir_f, nadir_V] - Design 2

       %----------------------------------------------------------------------
       % Step 5: Generate step response plots and compute metrics
       %----------------------------------------------------------------------
       for nn = 1:2  % Loop: 1=P step, 2=Q step
           for ii = 1:2  % Loop: 1=frequency, 2=voltage
               subplot(2, 2, 2*(nn-1)+ii)
               hold on

               for jj = 1:length(hDFIG)  % DFIG 1 and 3
                   for kk = 1:numOP  % All operating points
                       % ---- Design 1 (Black) ----
                       ssModel = LIN_MODEL_1{kk}.ssModel;
                       matA = ssModel.a;
                       matB = ssModel.b;
                       matC = ssModel.c;
                       matD = ssModel.d;

                       % Input index: P or Q reference for selected DFIG
                       indI = nCONTROL*nDFIG + nDFIG*(nn-1) + hDFIG(jj);
                       % Output index: frequency or PCC voltage
                       indO = 2*nCONTROL*nDFIG + ii;

                       % Extract transfer function F(s) = output/input
                       Fss = ss(matA, matB(:,indI), matC(indO,:), matD(indO,indI));
                       y = step(Fss, t{ii});

                       % Plot only stable operating points
                       if LIN_MODEL_1{kk}.stability
                           plot(t{ii}, y, 'k', 'LineWidth', 1.5)
                       end

                       % Compute ROCOF/ROCOV and nadir for relevant combinations
                       if (nn==1 && ii==1) || (nn==2 && ii==2)  % P→f or Q→Vpcc
                           % Find half-rise time index
                           [miny, ind] = min(abs(y - y(end)/2));

                           % Validate response quality
                           if abs(miny) > 10  % Poor response quality
                               ROCOX_1(numOP*(jj-1)+kk, ii) = NaN;
                               nadir_1(numOP*(jj-1)+kk, ii) = NaN;
                           else
                               % ROCOF/ROCOV: slope at half-rise time
                               ROCOX_1(numOP*(jj-1)+kk, ii) = abs(y(ind)/t{ii}(ind));
                               % Nadir: maximum absolute deviation
                               nadir_1(numOP*(jj-1)+kk, ii) = abs(max(abs(y)));
                           end
                       end

                       % ---- Design 2 (Red) ----
                       ssModel = LIN_MODEL_2{kk}.ssModel;
                       matA = ssModel.a;
                       matB = ssModel.b;
                       matC = ssModel.c;
                       matD = ssModel.d;

                       % Extract transfer function F(s)
                       indI = nCONTROL*nDFIG + nDFIG*(nn-1) + hDFIG(jj);
                       indO = 2*nCONTROL*nDFIG + ii;
                       Fss = ss(matA, matB(:,indI), matC(indO,:), matD(indO,indI));
                       y = step(Fss, t{ii});

                       % Plot only stable operating points
                       if LIN_MODEL_2{kk}.stability
                           plot(t{ii}, y, 'r', 'LineWidth', 1.5)
                       end

                       % Compute ROCOF/ROCOV and nadir
                       if (nn==1 && ii==1) || (nn==2 && ii==2)  % P→f or Q→Vpcc
                           [miny, ind] = min(abs(y - y(end)/2));

                           if abs(miny) > 10
                               ROCOX_2(numOP*(jj-1)+kk, ii) = NaN;
                               nadir_2(numOP*(jj-1)+kk, ii) = NaN;
                           else
                               ROCOX_2(numOP*(jj-1)+kk, ii) = abs(y(ind)/t{ii}(ind));
                               nadir_2(numOP*(jj-1)+kk, ii) = abs(max(abs(y)));
                           end
                       end
                   end
               end

               % Subplot formatting with LaTeX interpreter
               xlabel('$t$ (s)', 'Interpreter', 'latex', 'FontSize', 11);
               ylabel(outLabel{ii}, 'Interpreter', 'latex', 'FontSize', 11);
               title(titleLabel{nn}, 'Interpreter', 'latex', 'FontSize', 12, ...
                     'FontWeight', 'bold', 'Color', 'k');
               xlim([0 t{ii}(end)]);
               grid on
               set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
                        'Color', 'white', 'XColor', 'k', 'YColor', 'k', ...
                        'GridLineStyle', ':', 'GridColor', 'k', 'GridAlpha', 0.15);
               box on

               % Add legend to first subplot
               if nn == 1 && ii == 1
                   h1 = plot(NaN, NaN, 'k', 'LineWidth', 1.5);
                   h2 = plot(NaN, NaN, 'r', 'LineWidth', 1.5);
                   legend([h1, h2], {'Design 1', 'Design 2'}, ...
                          'Interpreter', 'latex', 'FontSize', 9, ...
                          'Location', 'best', 'Box', 'on');
               end

               hold off
           end
       end

       % Apply IEEE publication formatting
       format_figure_for_publication(fig);

       %----------------------------------------------------------------------
       % Step 5: Rank and display grid code compliance metrics for both designs
       %----------------------------------------------------------------------
       % This section ranks operating points by worst-case performance for
       % each grid code metric and displays professional output tables.
       %
       % METRICS ANALYZED:
       %   1. ROCOF (Rate of Change of Frequency) - Frequency stability
       %   2. ROCOV (Rate of Change of Voltage)   - Voltage stability
       %   3. Frequency nadir                     - Maximum frequency deviation
       %   4. Voltage nadir                       - Maximum voltage deviation
       %
       % OUTPUT: Four ranked tables per design showing worst-case operating
       %         points for each metric, including SCR information.

       % Design 1: Rank metrics and create extended operating point tables
       [sortedData, ind] = sort([ROCOX_1 nadir_1], 'descend');
       OPsetExt_1 = repmat(OPset, 2, 1);
       OPsetExt_1.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];
       OPsetCell_1 = cell(1, 4);

       % Table 1: Worst-case ROCOF
       OPsetCell_1{1} = OPsetExt_1(ind(:,1), :);
       OPsetCell_1{1}.ROCOF = sortedData(:,1);

       % Table 2: Worst-case ROCOV
       OPsetCell_1{2} = OPsetExt_1(ind(:,2), :);
       OPsetCell_1{2}.ROCOV = sortedData(:,2);

       % Table 3: Worst-case frequency nadir
       OPsetCell_1{3} = OPsetExt_1(ind(:,3), :);
       OPsetCell_1{3}.nadir_f = sortedData(:,3);

       % Table 4: Worst-case voltage nadir
       OPsetCell_1{4} = OPsetExt_1(ind(:,4), :);
       OPsetCell_1{4}.nadir_V = sortedData(:,4);

       % Design 2: Rank metrics and create extended operating point tables
       [sortedData, ind] = sort([ROCOX_2 nadir_2], 'descend');
       OPsetExt_2 = repmat(OPset, 2, 1);
       OPsetExt_2.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];
       OPsetCell_2 = cell(1, 4);

       % Table 1: Worst-case ROCOF
       OPsetCell_2{1} = OPsetExt_2(ind(:,1), :);
       OPsetCell_2{1}.ROCOF = sortedData(:,1);

       % Table 2: Worst-case ROCOV
       OPsetCell_2{2} = OPsetExt_2(ind(:,2), :);
       OPsetCell_2{2}.ROCOV = sortedData(:,2);

       % Table 3: Worst-case frequency nadir
       OPsetCell_2{3} = OPsetExt_2(ind(:,3), :);
       OPsetCell_2{3}.nadir_f = sortedData(:,3);

       % Table 4: Worst-case voltage nadir
       OPsetCell_2{4} = OPsetExt_2(ind(:,4), :);
       OPsetCell_2{4}.nadir_V = sortedData(:,4);

       % Display professional comparison output with box-drawing characters
       fprintf('\n');
       fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 2: Grid Response to P/Q Reference Steps Comparison        ║\n');
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Design 1: %-53s ║\n', slug_1);
       fprintf('║  Design 2: %-53s ║\n', slug_2);
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Operating Points: %-3d  |  DFIGs: 1 (SCR=10), 3 (SCR=5)       ║\n', numOP);
       fprintf('╚══════════════════════════════════════════════════════════════════╝\n');
       fprintf('\n');

       % Display Design 1 metrics
       fprintf('═══════════════════════════════════════════════════════════════════\n');
       fprintf('                         DESIGN 1 METRICS                          \n');
       fprintf('═══════════════════════════════════════════════════════════════════\n');
       fprintf('\n1. Worst-case ROCOF (Rate of Change of Frequency):\n');
       disp(OPsetCell_1{1});
       fprintf('\n2. Worst-case ROCOV (Rate of Change of Voltage):\n');
       disp(OPsetCell_1{2});
       fprintf('\n3. Worst-case Frequency Nadir:\n');
       disp(OPsetCell_1{3});
       fprintf('\n4. Worst-case Voltage Nadir:\n');
       disp(OPsetCell_1{4});

       % Display Design 2 metrics
       fprintf('\n');
       fprintf('═══════════════════════════════════════════════════════════════════\n');
       fprintf('                         DESIGN 2 METRICS                          \n');
       fprintf('═══════════════════════════════════════════════════════════════════\n');
       fprintf('\n1. Worst-case ROCOF (Rate of Change of Frequency):\n');
       disp(OPsetCell_2{1});
       fprintf('\n2. Worst-case ROCOV (Rate of Change of Voltage):\n');
       disp(OPsetCell_2{2});
       fprintf('\n3. Worst-case Frequency Nadir:\n');
       disp(OPsetCell_2{3});
       fprintf('\n4. Worst-case Voltage Nadir:\n');
       disp(OPsetCell_2{4});

       % Grid code compliance guide
       fprintf('\n');
       fprintf('───────────────────────────────────────────────────────────────────\n');
       fprintf('                   Grid Code Compliance Guide                      \n');
       fprintf('───────────────────────────────────────────────────────────────────\n');
       fprintf('  • ROCOF limit: Typically 1 Hz/s (0.02 pu/s @ 50 Hz)\n');
       fprintf('  • ROCOV limit: Typically 3%%/s (0.03 pu/s)\n');
       fprintf('  • Frequency nadir: Typically ±0.5 Hz (0.01 pu @ 50 Hz)\n');
       fprintf('  • Voltage nadir: Typically ±10%% (0.1 pu)\n');
       fprintf('  • Design comparison: Compare metrics between designs to assess\n');
       fprintf('                       improvements in grid code compliance\n');
       fprintf('───────────────────────────────────────────────────────────────────\n');
       fprintf('\n')
  %======================================================================
   % CASE 3: Plant Open-Loop Frequency Response Comparison (Nichols Diagram)
   %======================================================================
   % PURPOSE:
   %   Compare plant open-loop transfer function G(s) = -T(s)/S(s) between
   %   two control designs to assess relative stability margins. Nichols
   %   diagrams show gain margin (GM) and phase margin (PM) differences.
   %
   % METHODOLOGY:
   %   1. Extract complementary sensitivity T(s) and sensitivity S(s)
   %   2. Compute plant G(s) = -T(s)/S(s)
   %   3. Plot Nichols diagram (gain vs phase) for both designs
   %   4. Calculate gain margin GM at -180° crossover frequency (wu)
   %   5. Calculate phase margin PM at unity gain crossover frequency (wo)
   %   6. Generate 3×3 subplot array for 7 control loops
   %
   % STABILITY MARGINS:
   %   - Gain Margin (GM): Additional gain before instability (dB)
   %     Typical requirement: GM > 6 dB
   %   - Phase Margin (PM): Additional phase before instability (degrees)
   %     Typical requirement: PM > 30°
   %   - Unity gain crossover (wo): Bandwidth indicator (rad/s)
   %   - -180° crossover (wu): Gain margin frequency (rad/s)
   %
   % DFIGs ANALYZED:
   %   - DFIG 1: SCR_transformer = 10 (strong connection)
   %   - DFIG 3: SCR_transformer = 5 (weak connection)
   %
   % OUTPUTS:
   %   - Figure: 3×3 Nichols diagrams comparing both designs
   %   - Console: 14 tables (7 per design) with GM, PM, wu, wo
   %
   % INTERPRETATION:
   %   - Compare Design 1 vs Design 2 stability margins
   %   - Identify which design has better robustness
   %   - Assess trade-offs between performance (wo) and stability (GM/PM)
   %----------------------------------------------------------------------
   case 3  % Plant open-loop frequency response comparison (Nichols diagram)
   %----------------------------------------------------------------------

       %----------------------------------------------------------------------
       % Step 1: Configuration and initialization
       %----------------------------------------------------------------------
       % Frequency ranges optimized for each controller (log scale)
       logw = [-1   2.25;  % VSMP: 0.1 - 178 rad/s (slow power dynamics)
               -1   2.0;   % VSMQ: 0.1 - 100 rad/s (slow voltage dynamics)
                1   3.5;   % RSCd: 10 - 3162 rad/s (fast rotor current)
                1   3.5;   % RSCq: 10 - 3162 rad/s (fast rotor current)
                1   3.0;   % VDC: 10 - 1000 rad/s (medium DC-link)
                2   3.5;   % GSCd: 100 - 3162 rad/s (very fast grid current)
                2   3.5];  % GSCq: 100 - 3162 rad/s (very fast grid current)

       hDFIG = [1 3];  % DFIG 1 (SCR=10) and DFIG 3 (SCR=5)
       SCRdfig = MODEL_1.DFIG.PARAM.SCR_transformer(hDFIG);

       % Initialize stability margin arrays for Design 1
       Am_1 = NaN(length(hDFIG)*numOP, nCONTROL);    % Gain margin (linear)
       AmdB_1 = NaN(length(hDFIG)*numOP, nCONTROL);  % Gain margin (dB)
       Fm_1 = NaN(length(hDFIG)*numOP, nCONTROL);    % Phase margin (degrees)
       wu_1 = NaN(length(hDFIG)*numOP, nCONTROL);    % -180° crossover freq (rad/s)
       wo_1 = NaN(length(hDFIG)*numOP, nCONTROL);    % Unity gain crossover freq (rad/s)

       % Initialize stability margin arrays for Design 2
       Am_2 = NaN(length(hDFIG)*numOP, nCONTROL);
       AmdB_2 = NaN(length(hDFIG)*numOP, nCONTROL);
       Fm_2 = NaN(length(hDFIG)*numOP, nCONTROL);
       wu_2 = NaN(length(hDFIG)*numOP, nCONTROL);
       wo_2 = NaN(length(hDFIG)*numOP, nCONTROL);

       % Operating point tables with SCR information
       OPsetExt_1 = repmat(OPset, 2, 1);
       OPsetExt_1.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];
       OPsetCell_1 = cell(1, nCONTROL);

       OPsetExt_2 = repmat(OPset, 2, 1);
       OPsetExt_2.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];
       OPsetCell_2 = cell(1, nCONTROL);

       %----------------------------------------------------------------------
       % Step 2: Configure fsolve for crossover frequency calculation
       %----------------------------------------------------------------------
       opt_fsolve = optimoptions('fsolve');
       opt_fsolve.MaxIterations = 5000;
       opt_fsolve.Display = 'off';
       % OPTIMIZATION: Relaxed tolerances for ~30-50% speedup
       opt_fsolve.OptimalityTolerance = 1e-4;   % Default: 1e-6
       opt_fsolve.StepTolerance = 1e-6;         % Default: 1e-10
       opt_fsolve.FunctionTolerance = 1e-6;     % Default: 1e-6

       % Initial guesses for crossover frequencies (rad/s)
       w_ini = [10, 2.5, 350, 350, 100, 500, 500];

       % Check if Parallel Computing Toolbox is available
       hasParallelToolbox = license('test', 'Distrib_Computing_Toolbox') && ...
                            ~isempty(ver('parallel'));
       if hasParallelToolbox
           try
               poolObj = gcp('nocreate');
               if isempty(poolObj)
                   parpool('local');
                   poolObj = gcp('nocreate');
               end
               fprintf('║  Parallel mode: ENABLED (%d workers)                            ║\n', poolObj.NumWorkers);
           catch
               hasParallelToolbox = false;
               fprintf('║  Parallel mode: DISABLED (parpool failed, using serial)         ║\n');
           end
       else
           fprintf('║  Parallel mode: DISABLED (Parallel Toolbox not available)       ║\n');
       end

       %----------------------------------------------------------------------
       % Step 3: Compute stability margins (PARALLEL or SERIAL)
       %----------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 3: Processing Nichols Diagrams and Stability Margins      ║\n');
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Total: %d control loops × 2 DFIGs × %d OPs = %d analyses      ║\n', nCONTROL, numOP, nCONTROL*2*numOP);
       fprintf('╚══════════════════════════════════════════════════════════════════╝\n');
       fprintf('\n');

       % Prepare data structures for parallel computation
       plotData_1 = cell(nCONTROL, 1);
       plotData_2 = cell(nCONTROL, 1);

       if hasParallelToolbox
           %------------------------------------------------------------------
           % PARALLEL COMPUTATION (Phase 1: Compute all margins)
           %------------------------------------------------------------------
           fprintf('► Starting parallel computation on %d control loops...\n', nCONTROL);

           parfor nn = 1:nCONTROL
               % Initialize local storage for this control loop
               localPlotData_1 = struct('phase', [], 'mag', []);
               localPlotData_2 = struct('phase', [], 'mag', []);
               phaseArray_1 = cell(length(hDFIG)*numOP, 1);
               magArray_1 = cell(length(hDFIG)*numOP, 1);
               phaseArray_2 = cell(length(hDFIG)*numOP, 1);
               magArray_2 = cell(length(hDFIG)*numOP, 1);

               % Local copies of results arrays for this control loop
               local_wo_1 = NaN(length(hDFIG)*numOP, 1);
               local_wu_1 = NaN(length(hDFIG)*numOP, 1);
               local_Fm_1 = NaN(length(hDFIG)*numOP, 1);
               local_Am_1 = NaN(length(hDFIG)*numOP, 1);
               local_AmdB_1 = NaN(length(hDFIG)*numOP, 1);

               local_wo_2 = NaN(length(hDFIG)*numOP, 1);
               local_wu_2 = NaN(length(hDFIG)*numOP, 1);
               local_Fm_2 = NaN(length(hDFIG)*numOP, 1);
               local_Am_2 = NaN(length(hDFIG)*numOP, 1);
               local_AmdB_2 = NaN(length(hDFIG)*numOP, 1);

               % Frequency vector for this control loop
               w = logspace(logw(nn,1), logw(nn,2), 1000);

               idx = 0;
               for ii = 1:length(hDFIG)
                   for jj = 1:numOP
                       idx = idx + 1;

                       % ============================================================
                       % DESIGN 1 Analysis
                       % ============================================================
                       ssModel = LIN_MODEL_1{jj}.ssModel;
                       matA = ssModel.a;
                       matB = ssModel.b;
                       matC = ssModel.c;
                       matD = ssModel.d;

                       indT = nCONTROL*(hDFIG(ii)-1) + nn;
                       indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + nn;
                       Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                       Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));
                       Gss = -Tss/Sss;

                       [magG, phaseG] = bode(Gss, w);
                       magG_dB = 20*log10(squeeze(magG));
                       phaseG = squeeze(phaseG);
                       phaseG = unwrap(phaseG * pi/180) * 180/pi;
                       medianG = median(phaseG);
                       shiftG = round((medianG + 180) / 360) * 360;
                       phaseG = phaseG - shiftG;

                       % Store plot data
                       phaseArray_1{idx} = phaseG;
                       magArray_1{idx} = magG_dB;

                       % Compute margins
                       [local_wo_1(idx), ~, exitflag] = fsolve(@(w) abs(freqresp(Gss,w))-1, w_ini(nn), opt_fsolve);
                       if exitflag < 1 || local_wo_1(idx) < 0
                           local_wo_1(idx) = NaN;
                           local_Fm_1(idx) = NaN;
                       else
                           local_Fm_1(idx) = 180 + 180/pi*angle(freqresp(Gss, local_wo_1(idx)));
                       end

                       [local_wu_1(idx), ~, exitflag] = fsolve(@(w) 180/pi*angle(freqresp(Gss,w))+180, w_ini(nn), opt_fsolve);
                       if exitflag < 1 || local_wu_1(idx) < 0
                           local_wu_1(idx) = NaN;
                           local_Am_1(idx) = NaN;
                           local_AmdB_1(idx) = NaN;
                       else
                           local_Am_1(idx) = 1/abs(freqresp(Gss, local_wu_1(idx)));
                           local_AmdB_1(idx) = 20*log10(local_Am_1(idx));
                       end

                       % ============================================================
                       % DESIGN 2 Analysis
                       % ============================================================
                       ssModel = LIN_MODEL_2{jj}.ssModel;
                       matA = ssModel.a;
                       matB = ssModel.b;
                       matC = ssModel.c;
                       matD = ssModel.d;

                       indT = nCONTROL*(hDFIG(ii)-1) + nn;
                       indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + nn;
                       Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                       Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));
                       Gss = -Tss/Sss;

                       [magG, phaseG] = bode(Gss, w);
                       magG_dB = 20*log10(squeeze(magG));
                       phaseG = squeeze(phaseG);
                       phaseG = unwrap(phaseG * pi/180) * 180/pi;
                       medianG = median(phaseG);
                       shiftG = round((medianG + 180) / 360) * 360;
                       phaseG = phaseG - shiftG;

                       % Store plot data
                       phaseArray_2{idx} = phaseG;
                       magArray_2{idx} = magG_dB;

                       % Compute margins
                       [local_wo_2(idx), ~, exitflag] = fsolve(@(w) abs(freqresp(Gss,w))-1, w_ini(nn), opt_fsolve);
                       if exitflag < 1 || local_wo_2(idx) < 0
                           local_wo_2(idx) = NaN;
                           local_Fm_2(idx) = NaN;
                       else
                           local_Fm_2(idx) = 180 + 180/pi*angle(freqresp(Gss, local_wo_2(idx)));
                       end

                       [local_wu_2(idx), ~, exitflag] = fsolve(@(w) 180/pi*angle(freqresp(Gss,w))+180, w_ini(nn), opt_fsolve);
                       if exitflag < 1 || local_wu_2(idx) < 0
                           local_wu_2(idx) = NaN;
                           local_Am_2(idx) = NaN;
                           local_AmdB_2(idx) = NaN;
                       else
                           local_Am_2(idx) = 1/abs(freqresp(Gss, local_wu_2(idx)));
                           local_AmdB_2(idx) = 20*log10(local_Am_2(idx));
                       end
                   end
               end

               % Store results for this control loop
               localPlotData_1.phase = phaseArray_1;
               localPlotData_1.mag = magArray_1;
               plotData_1{nn} = localPlotData_1;

               localPlotData_2.phase = phaseArray_2;
               localPlotData_2.mag = magArray_2;
               plotData_2{nn} = localPlotData_2;

               % Copy results to global arrays
               wo_1(:,nn) = local_wo_1;
               wu_1(:,nn) = local_wu_1;
               Fm_1(:,nn) = local_Fm_1;
               Am_1(:,nn) = local_Am_1;
               AmdB_1(:,nn) = local_AmdB_1;

               wo_2(:,nn) = local_wo_2;
               wu_2(:,nn) = local_wu_2;
               Fm_2(:,nn) = local_Fm_2;
               Am_2(:,nn) = local_Am_2;
               AmdB_2(:,nn) = local_AmdB_2;
           end

           fprintf('  ✓ Parallel computation completed\n');
       else
           %------------------------------------------------------------------
           % SERIAL COMPUTATION (Fallback when Parallel Toolbox unavailable)
           %------------------------------------------------------------------
           for nn = 1:nCONTROL
               fprintf('► Processing %s (%d/%d)...\n', ControlLabel{nn}, nn, nCONTROL);

               % Initialize storage for this control loop
               localPlotData_1 = struct('phase', [], 'mag', []);
               localPlotData_2 = struct('phase', [], 'mag', []);
               phaseArray_1 = cell(length(hDFIG)*numOP, 1);
               magArray_1 = cell(length(hDFIG)*numOP, 1);
               phaseArray_2 = cell(length(hDFIG)*numOP, 1);
               magArray_2 = cell(length(hDFIG)*numOP, 1);

               w = logspace(logw(nn,1), logw(nn,2), 1000);

               totalAnalyses = length(hDFIG) * numOP;
               analysisCount = 0;

               idx = 0;
               for ii = 1:length(hDFIG)
                   for jj = 1:numOP
                       idx = idx + 1;
                       analysisCount = analysisCount + 1;
                       if mod(analysisCount, 4) == 1 || analysisCount == totalAnalyses
                           fprintf('  Progress: %d/%d (DFIG %d, OP %d/%d)\n', ...
                                   analysisCount, totalAnalyses, hDFIG(ii), jj, numOP);
                       end

                       % ============================================================
                       % DESIGN 1 Analysis
                       % ============================================================
                       ssModel = LIN_MODEL_1{jj}.ssModel;
                       matA = ssModel.a;
                       matB = ssModel.b;
                       matC = ssModel.c;
                       matD = ssModel.d;

                       indT = nCONTROL*(hDFIG(ii)-1) + nn;
                       indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + nn;
                       Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                       Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));
                       Gss = -Tss/Sss;

                       [magG, phaseG] = bode(Gss, w);
                       magG_dB = 20*log10(squeeze(magG));
                       phaseG = squeeze(phaseG);
                       phaseG = unwrap(phaseG * pi/180) * 180/pi;
                       medianG = median(phaseG);
                       shiftG = round((medianG + 180) / 360) * 360;
                       phaseG = phaseG - shiftG;

                       phaseArray_1{idx} = phaseG;
                       magArray_1{idx} = magG_dB;

                       [wo_1(numOP*(ii-1)+jj,nn), ~, exitflag] = fsolve(@(w) abs(freqresp(Gss,w))-1, w_ini(nn), opt_fsolve);
                       if exitflag < 1 || wo_1(numOP*(ii-1)+jj,nn) < 0
                           wo_1(numOP*(ii-1)+jj,nn) = NaN;
                           Fm_1(numOP*(ii-1)+jj,nn) = NaN;
                       else
                           Fm_1(numOP*(ii-1)+jj,nn) = 180 + 180/pi*angle(freqresp(Gss, wo_1(numOP*(ii-1)+jj,nn)));
                       end

                       [wu_1(numOP*(ii-1)+jj,nn), ~, exitflag] = fsolve(@(w) 180/pi*angle(freqresp(Gss,w))+180, w_ini(nn), opt_fsolve);
                       if exitflag < 1 || wu_1(numOP*(ii-1)+jj,nn) < 0
                           wu_1(numOP*(ii-1)+jj,nn) = NaN;
                           Am_1(numOP*(ii-1)+jj,nn) = NaN;
                           AmdB_1(numOP*(ii-1)+jj,nn) = NaN;
                       else
                           Am_1(numOP*(ii-1)+jj,nn) = 1/abs(freqresp(Gss, wu_1(numOP*(ii-1)+jj,nn)));
                           AmdB_1(numOP*(ii-1)+jj,nn) = 20*log10(Am_1(numOP*(ii-1)+jj,nn));
                       end

                       % ============================================================
                       % DESIGN 2 Analysis
                       % ============================================================
                       ssModel = LIN_MODEL_2{jj}.ssModel;
                       matA = ssModel.a;
                       matB = ssModel.b;
                       matC = ssModel.c;
                       matD = ssModel.d;

                       indT = nCONTROL*(hDFIG(ii)-1) + nn;
                       indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + nn;
                       Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                       Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));
                       Gss = -Tss/Sss;

                       [magG, phaseG] = bode(Gss, w);
                       magG_dB = 20*log10(squeeze(magG));
                       phaseG = squeeze(phaseG);
                       phaseG = unwrap(phaseG * pi/180) * 180/pi;
                       medianG = median(phaseG);
                       shiftG = round((medianG + 180) / 360) * 360;
                       phaseG = phaseG - shiftG;

                       phaseArray_2{idx} = phaseG;
                       magArray_2{idx} = magG_dB;

                       [wo_2(numOP*(ii-1)+jj,nn), ~, exitflag] = fsolve(@(w) abs(freqresp(Gss,w))-1, w_ini(nn), opt_fsolve);
                       if exitflag < 1 || wo_2(numOP*(ii-1)+jj,nn) < 0
                           wo_2(numOP*(ii-1)+jj,nn) = NaN;
                           Fm_2(numOP*(ii-1)+jj,nn) = NaN;
                       else
                           Fm_2(numOP*(ii-1)+jj,nn) = 180 + 180/pi*angle(freqresp(Gss, wo_2(numOP*(ii-1)+jj,nn)));
                       end

                       [wu_2(numOP*(ii-1)+jj,nn), ~, exitflag] = fsolve(@(w) 180/pi*angle(freqresp(Gss,w))+180, w_ini(nn), opt_fsolve);
                       if exitflag < 1 || wu_2(numOP*(ii-1)+jj,nn) < 0
                           wu_2(numOP*(ii-1)+jj,nn) = NaN;
                           Am_2(numOP*(ii-1)+jj,nn) = NaN;
                           AmdB_2(numOP*(ii-1)+jj,nn) = NaN;
                       else
                           Am_2(numOP*(ii-1)+jj,nn) = 1/abs(freqresp(Gss, wu_2(numOP*(ii-1)+jj,nn)));
                           AmdB_2(numOP*(ii-1)+jj,nn) = 20*log10(Am_2(numOP*(ii-1)+jj,nn));
                       end
                   end
               end

               localPlotData_1.phase = phaseArray_1;
               localPlotData_1.mag = magArray_1;
               plotData_1{nn} = localPlotData_1;

               localPlotData_2.phase = phaseArray_2;
               localPlotData_2.mag = magArray_2;
               plotData_2{nn} = localPlotData_2;

               fprintf('  ✓ %s completed\n', ControlLabel{nn});
           end
       end

       %----------------------------------------------------------------------
       % Step 4: Generate Nichols diagrams (SERIAL plotting with precomputed data)
       %----------------------------------------------------------------------
       fprintf('\n► Generating Nichols diagrams...\n');

       fig = figure('Name', 'Case 3: Plant Open-Loop Nichols Diagram Comparison', ...
                    'Position', [100, 100, 1200, 900], ...
                    'Color', 'white');

       for nn = 1:nCONTROL
           subplot(3, 3, nn)
           hold on

           % Plot all curves for Design 1 (black)
           for idx = 1:length(plotData_1{nn}.phase)
               plot(plotData_1{nn}.phase{idx}, plotData_1{nn}.mag{idx}, 'k', 'LineWidth', 1.5);
           end

           % Plot all curves for Design 2 (red)
           for idx = 1:length(plotData_2{nn}.phase)
               plot(plotData_2{nn}.phase{idx}, plotData_2{nn}.mag{idx}, 'r', 'LineWidth', 1.5);
           end

           % Add reference lines and legend
           final_xlim = xlim;
           final_ylim = ylim;

           if final_xlim(1) > -180
               final_xlim(1) = min(final_xlim(1), -200);
           end
           if final_xlim(2) < -180
               final_xlim(2) = max(final_xlim(2), -160);
           end

           plot([-1000 1000], [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');
           plot([-180 -180], [-1000 1000], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');

           xlim(final_xlim);
           ylim(final_ylim);

           if nn == 1
               h1 = plot(NaN, NaN, 'k', 'LineWidth', 1.5);
               h2 = plot(NaN, NaN, 'r', 'LineWidth', 1.5);
               legend([h1, h2], {'Design 1', 'Design 2'}, ...
                      'Interpreter', 'latex', 'FontSize', 9, ...
                      'Location', 'best', 'Box', 'on');
           end

           xlabel('Open-Loop Phase (deg)', 'Interpreter', 'latex', 'FontSize', 11);
           ylabel('Open-Loop Gain (dB)', 'Interpreter', 'latex', 'FontSize', 11);
           title(ControlLabel{nn}, 'Interpreter', 'latex', 'FontSize', 12, 'Color', 'k');
           grid on
           set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
                    'Color', 'white', 'XColor', 'k', 'YColor', 'k');
           hold off

           % Store results for current control loop
           OPsetCell_1{nn} = OPsetExt_1;
           OPsetCell_1{nn}.GM_dB = AmdB_1(:,nn);
           OPsetCell_1{nn}.PM_deg = Fm_1(:,nn);
           OPsetCell_1{nn}.wu_rads = wu_1(:,nn);
           OPsetCell_1{nn}.wo_rads = wo_1(:,nn);

           OPsetCell_2{nn} = OPsetExt_2;
           OPsetCell_2{nn}.GM_dB = AmdB_2(:,nn);
           OPsetCell_2{nn}.PM_deg = Fm_2(:,nn);
           OPsetCell_2{nn}.wu_rads = wu_2(:,nn);
           OPsetCell_2{nn}.wo_rads = wo_2(:,nn);
       end

       fprintf('  ✓ Nichols diagrams completed\n');
       fprintf('\n► Applying IEEE publication formatting...\n');
       format_figure_for_publication(fig);
       fprintf('  ✓ Figure formatting completed\n');

       %----------------------------------------------------------------------
       % Step 5: Display stability margin comparison tables
       %----------------------------------------------------------------------
       %----------------------------------------------------------------------
       % Step 4: Display stability margin comparison tables
       %----------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔══════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 3: Plant Open-Loop Stability Margins Comparison           ║\n');
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Design 1: %-53s ║\n', slug_1);
       fprintf('║  Design 2: %-53s ║\n', slug_2);
       fprintf('╠══════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Operating Points: %-3d  |  DFIGs: 1 (SCR=10), 3 (SCR=5)       ║\n', numOP);
       fprintf('╚══════════════════════════════════════════════════════════════════╝\n');

       % Display Design 1 stability margins
       fprintf('\n');
       fprintf('═══════════════════════════════════════════════════════════════════\n');
       fprintf('                    DESIGN 1 STABILITY MARGINS                     \n');
       fprintf('═══════════════════════════════════════════════════════════════════\n');
       for nn = 1:nCONTROL
           fprintf('\n%d. %s Control Loop:\n', nn, ControlLabel{nn});
           disp(OPsetCell_1{nn});
       end

       % Display Design 2 stability margins
       fprintf('\n');
       fprintf('═══════════════════════════════════════════════════════════════════\n');
       fprintf('                    DESIGN 2 STABILITY MARGINS                     \n');
       fprintf('═══════════════════════════════════════════════════════════════════\n');
       for nn = 1:nCONTROL
           fprintf('\n%d. %s Control Loop:\n', nn, ControlLabel{nn});
           disp(OPsetCell_2{nn});
       end

       % Stability margin guidelines
       fprintf('\n');
       fprintf('───────────────────────────────────────────────────────────────────\n');
       fprintf('                  Stability Margin Guidelines                      \n');
       fprintf('───────────────────────────────────────────────────────────────────\n');
       fprintf('  • Gain Margin (GM): > 6 dB recommended (adequate stability)\n');
       fprintf('  • Phase Margin (PM): > 30° recommended (good damping)\n');
       fprintf('  • High wo/wu: Aggressive tuning (faster response, lower margins)\n');
       fprintf('  • Low wo/wu: Conservative tuning (slower response, higher margins)\n');
       fprintf('  • Design comparison: Compare GM/PM to assess robustness improvements\n');
       fprintf('───────────────────────────────────────────────────────────────────\n');
       fprintf('\n')

   %--------------------------------------------------------------
    case 4 % Bodemag of sensitivity and complementary sensitivity frequency responses
   %--------------------------------------------------------------
        logw = [0 2.25 ; -1 2 ; 1.5 3.5 ; 1.5 4 ; 1 3 ; 1.5 4 ; 1.5 4];
        ws_ini = [1 1 1000 1000 10 1000 1000];
        wt_ini = [1 1 1000 100 10 1000 1000];
        hDFIG = [1 3];
        SCRdfig = MODEL_1.DFIG.PARAM.SCR_transformer(hDFIG);
        ws_1 = NaN(length(hDFIG)*numOP,nCONTROL); Ms_1 = NaN(length(hDFIG)*numOP,nCONTROL); 
        wt_1 = NaN(length(hDFIG)*numOP,nCONTROL); Mt_1 = NaN(length(hDFIG)*numOP,nCONTROL); 
        ws_2 = NaN(length(hDFIG)*numOP,nCONTROL); Ms_2 = NaN(length(hDFIG)*numOP,nCONTROL); 
        wt_2 = NaN(length(hDFIG)*numOP,nCONTROL); Mt_2 = NaN(length(hDFIG)*numOP,nCONTROL); 
        OPsetExt_1 = repmat(OPset,2,1);
        OPsetExt_1.SCRdfig = [SCRdfig(1)*ones(numOP,1) ; SCRdfig(2)*ones(numOP,1)];
        OPsetCell_1 = cell(1,nCONTROL);
        OPsetExt_2 = repmat(OPset,2,1);
        OPsetExt_2.SCRdfig = [SCRdfig(1)*ones(numOP,1) ; SCRdfig(2)*ones(numOP,1)];
        OPsetCell_2 = cell(1,nCONTROL);
        figure(1)
        for nn = 1:nCONTROL
            subplot(3,3,nn)
            w = logspace(logw(nn,1),logw(nn,2),5000);
            for ii = 1:length(hDFIG)
                for jj = 1:numOP
                    ssModel = LIN_MODEL_1{jj}.ssModel;
                    % State space matrices
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;
                    indT = nCONTROL*(hDFIG(ii)-1)+nn;
                    indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1)+nn;
                    Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
                    Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));
                    bodemag(Sss,Tss,w)
                    % Frequency for sensitivity maximum
                    ws_1(numOP*(ii-1)+jj,nn) = fminsearch(@(w) -abs(freqresp(Sss,w)),ws_ini(nn));
                    % Sensitivity maximum
                    Ms_1(numOP*(ii-1)+jj,nn) = 20*log10(abs(freqresp(Sss,ws_1(numOP*(ii-1)+jj,nn))));
                    % Frequency for complementary sensitivity maximum
                    wt_1(numOP*(ii-1)+jj,nn) = fminsearch(@(w) -abs(freqresp(Tss,w)),wt_ini(nn));
                    % Complementary sensitivity maximum
                    Mt_1(numOP*(ii-1)+jj,nn) = 20*log10(abs(freqresp(Tss,wt_1(numOP*(ii-1)+jj,nn))));
                    hold on
                    ax = gca;
                    ax.Children(1).Children.LineWidth = 1.5;
                    ax.Children(1).Children.Color = 'black';
                    ax.Children(2).Children.LineWidth = 1.5;
                    ax.Children(2).Children.Color = 'black';
                    %--------------------------------------------------
                    ssModel = LIN_MODEL_2{jj}.ssModel;
                    % State space matrices
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;
                    indT = nCONTROL*(hDFIG(ii)-1)+nn;
                    indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1)+nn;
                    Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
                    Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));
                    bodemag(Sss,Tss,w)
                    % Frequency for sensitivity maximum
                    ws_2(numOP*(ii-1)+jj,nn) = fminsearch(@(w) -abs(freqresp(Sss,w)),ws_ini(nn));
                    % Sensitivity maximum
                    Ms_2(numOP*(ii-1)+jj,nn) = 20*log10(abs(freqresp(Sss,ws_2(numOP*(ii-1)+jj,nn))));
                    % Frequency for complementary sensitivity maximum
                    wt_2(numOP*(ii-1)+jj,nn) = fminsearch(@(w) -abs(freqresp(Tss,w)),wt_ini(nn));
                    % Complementary sensitivity maximum
                    Mt_2(numOP*(ii-1)+jj,nn) = 20*log10(abs(freqresp(Tss,wt_2(numOP*(ii-1)+jj,nn))));
                    hold on
                    ax = gca;
                    ax.Children(1).Children.LineWidth = 1.5;
                    ax.Children(1).Children.Color = 'red';
                    ax.Children(2).Children.LineWidth = 1.5;
                    ax.Children(2).Children.Color = 'red';
                end
            end
            ylim([-15 10])
            title(ControlLabel{nn})
            OPsetCell_1{nn} = OPsetExt_1;
            OPsetCell_1{nn}.Ms = Ms_1(:,nn);
            OPsetCell_1{nn}.ws = ws_1(:,nn);
            OPsetCell_1{nn}.Mt = Mt_1(:,nn);
            OPsetCell_1{nn}.wt = wt_1(:,nn);
            disp([ControlLabel{nn} '_1'])
            disp(OPsetCell_1{nn})
            %--------------------------------------------------
            OPsetCell_2{nn} = OPsetExt_2;
            OPsetCell_2{nn}.Ms = Ms_2(:,nn);
            OPsetCell_2{nn}.ws = ws_2(:,nn);
            OPsetCell_2{nn}.Mt = Mt_2(:,nn);
            OPsetCell_2{nn}.wt = wt_2(:,nn);
            disp([ControlLabel{nn} '_2'])
            disp(OPsetCell_2{nn})
        end
   %--------------------------------------------------------------
    case 5 % Bodemag of closed-loop frequency response
   %--------------------------------------------------------------
        logw = [-1 2.25 ; -1 1.25 ; 1.5 3.5 ; 1.5 3.5 ; 0 2.5 ; 1.5 3.5 ; 1.5 3.5];
        wr_ini = [1 1 10 10 10 100 100];
        hDFIG = [1 3];
        SCRdfig = MODEL_1.DFIG.PARAM.SCR_transformer(hDFIG);
        wr_1 = NaN(length(hDFIG)*numOP,nCONTROL); Mr_1 = NaN(length(hDFIG)*numOP,nCONTROL); 
        wr_2 = NaN(length(hDFIG)*numOP,nCONTROL); Mr_2 = NaN(length(hDFIG)*numOP,nCONTROL); 
        OPsetExt_1 = repmat(OPset,2,1);
        OPsetExt_1.SCRdfig = [SCRdfig(1)*ones(numOP,1) ; SCRdfig(2)*ones(numOP,1)];
        OPsetCell_1 = cell(1,nCONTROL);
        OPsetExt_2 = repmat(OPset,2,1);
        OPsetExt_2.SCRdfig = [SCRdfig(1)*ones(numOP,1) ; SCRdfig(2)*ones(numOP,1)];
        OPsetCell_2 = cell(1,nCONTROL);
        figure(1)
        for nn = 1:nCONTROL
            subplot(3,3,nn)
            w = logspace(logw(nn,1),logw(nn,2),1000);
            for ii = 1:length(hDFIG)
                for jj = 1:numOP
                    ssModel = LIN_MODEL_1{jj}.ssModel;
                    % State space matrices
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;
                    indT = nCONTROL*(hDFIG(ii)-1)+nn;
                    Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
                    bodemag(Tss,w)
                    % Pulsacion de resonancia
                    wr_1(numOP*(ii-1)+jj,nn) = fminsearch(@(w) -abs(freqresp(Tss,w)),wr_ini(nn));
                    % Pico de resonancia
                    Mr_1(numOP*(ii-1)+jj,nn) = 20*log10(abs(freqresp(Tss,wr_1(numOP*(ii-1)+jj,nn))));
                    hold on
                    ax = gca;
                    ax.Children(1).Children.LineWidth = 1.5;
                    ax.Children(1).Children.Color = 'black';
                    %--------------------------------------------------
                    ssModel = LIN_MODEL_2{jj}.ssModel;
                    % State space matrices
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;
                    indT = nCONTROL*(hDFIG(ii)-1)+nn;
                    Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
                    bodemag(Tss,w)
                    % Pulsacion de resonancia
                    wr_2(numOP*(ii-1)+jj,nn) = fminsearch(@(w) -abs(freqresp(Tss,w)),wr_ini(nn));
                    % Pico de resonancia
                    Mr_2(numOP*(ii-1)+jj,nn) = 20*log10(abs(freqresp(Tss,wr_2(numOP*(ii-1)+jj,nn))));
                    hold on
                    ax = gca;
                    ax.Children(1).Children.LineWidth = 1.5;
                    ax.Children(1).Children.Color = 'red';
                end
            end
            ylim([-15 10])
            title(ControlLabel{nn})
            OPsetCell_1{nn} = OPsetExt_1;
            OPsetCell_1{nn}.Mr = Mr_1(:,nn);
            OPsetCell_1{nn}.wr = wr_1(:,nn);
            disp([ControlLabel{nn} '_1'])
            disp(OPsetCell_1{nn})
            %--------------------------------------------------
            OPsetCell_2{nn} = OPsetExt_2;
            OPsetCell_2{nn}.Mr = Mr_2(:,nn);
            OPsetCell_2{nn}.wr = wr_2(:,nn);
            disp([ControlLabel{nn} '_2'])
            disp(OPsetCell_2{nn})
        end
   %--------------------------------------------------------------
    case 6 % Frequency and PCC voltage for steps in active and reactive load
   %--------------------------------------------------------------
        figure(1)
        % Time for f & Vpcc
        t = {linspace(0,5,500); linspace(0,10,5000)};
        outLabel = {'Frequency (pu)','PCC voltage (pu)'};
        titleLabel = {'Active load step','Reactive load step'};
        % ROCOX & nadir
        ROCOX_1 = NaN(numOP,2); % row (OP) & column (f & Vpcc)
        nadir_1 = NaN(numOP,2); % the same than before
        ROCOX_2 = NaN(numOP,2); % row (OP) & column (f & Vpcc)
        nadir_2 = NaN(numOP,2); % the same than before
        for nn = 1:2 % % Active and reactive load
            for ii = 1:2 % f & Vpcc
                subplot(2,2,2*(nn-1)+ii)
                for kk = 1:numOP % Operating point
                    ssModel = LIN_MODEL_1{kk}.ssModel;
                    % State space matrices
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;
                    indI = nCONTROL*nDFIG + 8 + nn;
                    indO = 2*nCONTROL*nDFIG + ii;
                    Fss = ss(matA,matB(:,indI),matC(indO,:),matD(indO,indI));
                    y = step(Fss,t{ii});
                    if LIN_MODEL_1{kk}.stability
                        plot(t{ii},y,'k','LineWidth',1.5)
                        hold on
                    end
                    % Computation of ROCOF (ROCOV) and nadir
                    if nn==1 && ii==1 % P & f
                        [~,ind] = min(abs(y-y(end)/2));
                        ROCOX_1(kk,ii) = abs(y(ind)/t{ii}(ind));
                        nadir_1(kk,ii) = abs(max(abs(y)));
                    end
                    if nn==2 && ii==2 % Q & Vpcc
                        [~,ind] = min(abs(y-y(end)/2));
                        ROCOX_1(kk,ii) = abs(y(ind)/t{ii}(ind));
                        nadir_1(kk,ii) = abs(max(abs(y)));
                    end
                    %--------------------------------------------------
                    ssModel = LIN_MODEL_2{kk}.ssModel;
                    % State space matrices
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;
                    indI = nCONTROL*nDFIG + 8 + nn;
                    indO = 2*nCONTROL*nDFIG + ii;
                    Fss = ss(matA,matB(:,indI),matC(indO,:),matD(indO,indI));
                    y = step(Fss,t{ii});
                    if LIN_MODEL_2{kk}.stability
                        plot(t{ii},y,'r','LineWidth',1.5)
                        hold on
                    end
                    % Computation of ROCOF (ROCOV) and nadir
                    if nn==1 && ii==1 % P & f
                        [~,ind] = min(abs(y-y(end)/2));
                        ROCOX_2(kk,ii) = abs(y(ind)/t{ii}(ind));
                        nadir_2(kk,ii) = abs(max(abs(y)));
                    end
                    if nn==2 && ii==2 % Q & Vpcc
                        [~,ind] = min(abs(y-y(end)/2));
                        ROCOX_2(kk,ii) = abs(y(ind)/t{ii}(ind));
                        nadir_2(kk,ii) = abs(max(abs(y)));
                    end
                end
                xlabel('t (s)')
                ylabel(outLabel{ii})
                xlim([0 t{ii}(end)])
                title(titleLabel{nn})
                hold off
            end
        end
        [sortedData,ind] = sort([ROCOX_1 nadir_1],'descend');
        OPsetCell_1 = cell(1,4);
        OPsetCell_1{1} = OPset(ind(:,1),:);
        OPsetCell_1{1}.ROCOF = sortedData(:,1);
        disp(OPsetCell_1{1})
        OPsetCell_1{3} = OPset(ind(:,3),:);
        OPsetCell_1{3}.nadir_f = sortedData(:,3);
        disp(OPsetCell_1{3})
        OPsetCell_1{2} = OPset(ind(:,2),:);
        OPsetCell_1{2}.ROCOV = sortedData(:,2);
        disp(OPsetCell_1{2})
        OPsetCell_1{4} = OPset(ind(:,4),:);
        OPsetCell_1{4}.nadir_V = sortedData(:,4);
        disp(OPsetCell_1{4})
        %--------------------------------------------------
        [sortedData,ind] = sort([ROCOX_2 nadir_2],'descend');
        OPsetCell_2 = cell(1,4);
        OPsetCell_2{1} = OPset(ind(:,1),:);
        OPsetCell_2{1}.ROCOF = sortedData(:,1);
        disp(OPsetCell_2{1})
        OPsetCell_2{3} = OPset(ind(:,3),:);
        OPsetCell_2{3}.nadir_f = sortedData(:,3);
        disp(OPsetCell_1{3})
        OPsetCell_2{2} = OPset(ind(:,2),:);
        OPsetCell_2{2}.ROCOV = sortedData(:,2);
        disp(OPsetCell_2{2})
        OPsetCell_2{4} = OPset(ind(:,4),:);
        OPsetCell_2{4}.nadir_V = sortedData(:,4);
        disp(OPsetCell_2{4})

   %--------------------------------------------------------------
    case 7 % 2x2 Subplots comparing step responses for two control designs
   %--------------------------------------------------------------
        % --- Configuration ---
        % DFIG where the step is applied (1 or 3). Default is 3.
        hDFIG_p = 3; 
        
        % Option to link Y-axes for direct comparison or use individual scales
        % true:  links frequency plots together and voltage plots together.
        % false: each subplot has its own optimal y-axis scale.
        link_y_axes = false;

        % Colors and style for the two controller sets
        color_1 = 'k';           % Black for baseline/control 1
        color_2 = 'r';           % Red for robust-optimized/control 2
        line_width_1 = 2;      % Linewidth for first controller
        line_width_2 = 2;      % Double linewidth for second controller

        % --- Figure Setup ---
        figure('Name', sprintf('Step Response Comparison (Pert. on DFIG%d)', hDFIG_p), 'Position', [100, 100, 900, 700]);
        
        % Create subplot handles to manage them easily
        ax = gobjects(4,1);
        
        % --- Subplot 1: P-step -> Frequency Response ---
        ax(1) = subplot(2,2,1);
        hold on; grid on;
        title('Frequency Response to P-step', 'Interpreter', 'latex', 'FontSize', 12);
        ylabel('$\Delta f$ (pu)', 'Interpreter', 'latex', 'FontSize', 11);
        
        % --- Subplot 2: P-step -> Vpcc Response ---
        ax(2) = subplot(2,2,2);
        hold on; grid on;
        title('PCC Voltage Response to P-step', 'Interpreter', 'latex', 'FontSize', 12);
        ylabel('$\Delta V_{pcc}$ (pu)', 'Interpreter', 'latex', 'FontSize', 11);

        % --- Subplot 3: Q-step -> Frequency Response ---
        ax(3) = subplot(2,2,3);
        hold on; grid on;
        title('Frequency Response to Q-step', 'Interpreter', 'latex', 'FontSize', 12);
        ylabel('$\Delta f$ (pu)', 'Interpreter', 'latex', 'FontSize', 11);
        xlabel('Time (s)', 'Interpreter', 'latex', 'FontSize', 11);

        % --- Subplot 4: Q-step -> Vpcc Response ---
        ax(4) = subplot(2,2,4);
        hold on; grid on;
        title('PCC Voltage Response to Q-step', 'Interpreter', 'latex', 'FontSize', 12);
        ylabel('$\Delta V_{pcc}$ (pu)', 'Interpreter', 'latex', 'FontSize', 11);
        xlabel('Time (s)', 'Interpreter', 'latex', 'FontSize', 11);

        % Initialize arrays to store all y-data for dynamic axis scaling
        y_data_all = {[], [], [], []}; % {ax1, ax2, ax3, ax4}

        % Loop through all operating points
        for kk = 1:numOP
            % --- Controller 1 (e.g., Baseline) ---
            ssModel_1 = LIN_MODEL_1{kk}.ssModel;
            if LIN_MODEL_1{kk}.stability
                indI_p = nCONTROL*nDFIG + hDFIG_p;
                Fss_f_p1 = ss(ssModel_1.a, ssModel_1.b(:,indI_p), ssModel_1.c(2*nCONTROL*nDFIG + 1,:), ssModel_1.d(2*nCONTROL*nDFIG + 1,indI_p));
                Fss_v_p1 = ss(ssModel_1.a, ssModel_1.b(:,indI_p), ssModel_1.c(2*nCONTROL*nDFIG + 2,:), ssModel_1.d(2*nCONTROL*nDFIG + 2,indI_p));
                indI_q = nCONTROL*nDFIG + nDFIG + hDFIG_p;
                Fss_f_q1 = ss(ssModel_1.a, ssModel_1.b(:,indI_q), ssModel_1.c(2*nCONTROL*nDFIG + 1,:), ssModel_1.d(2*nCONTROL*nDFIG + 1,indI_q));
                Fss_v_q1 = ss(ssModel_1.a, ssModel_1.b(:,indI_q), ssModel_1.c(2*nCONTROL*nDFIG + 2,:), ssModel_1.d(2*nCONTROL*nDFIG + 2,indI_q));
                
                [y, t] = step(Fss_f_p1, 5); subplot(2,2,1); plot(t, y, 'Color', color_1, 'LineWidth', line_width_1); y_data_all{1} = [y_data_all{1}; y];
                [y, t] = step(Fss_v_p1, 5); subplot(2,2,2); plot(t, y, 'Color', color_1, 'LineWidth', line_width_1); y_data_all{2} = [y_data_all{2}; y];
                [y, t] = step(Fss_f_q1, 5); subplot(2,2,3); plot(t, y, 'Color', color_1, 'LineWidth', line_width_1); y_data_all{3} = [y_data_all{3}; y];
                [y, t] = step(Fss_v_q1, 5); subplot(2,2,4); plot(t, y, 'Color', color_1, 'LineWidth', line_width_1); y_data_all{4} = [y_data_all{4}; y];
            end

            % --- Controller 2 (e.g., Robust-Optimized) ---
            ssModel_2 = LIN_MODEL_2{kk}.ssModel;
            if LIN_MODEL_2{kk}.stability
                indI_p = nCONTROL*nDFIG + hDFIG_p;
                Fss_f_p2 = ss(ssModel_2.a, ssModel_2.b(:,indI_p), ssModel_2.c(2*nCONTROL*nDFIG + 1,:), ssModel_2.d(2*nCONTROL*nDFIG + 1,indI_p));
                Fss_v_p2 = ss(ssModel_2.a, ssModel_2.b(:,indI_p), ssModel_2.c(2*nCONTROL*nDFIG + 2,:), ssModel_2.d(2*nCONTROL*nDFIG + 2,indI_p));
                indI_q = nCONTROL*nDFIG + nDFIG + hDFIG_p;
                Fss_f_q2 = ss(ssModel_2.a, ssModel_2.b(:,indI_q), ssModel_2.c(2*nCONTROL*nDFIG + 1,:), ssModel_2.d(2*nCONTROL*nDFIG + 1,indI_q));
                Fss_v_q2 = ss(ssModel_2.a, ssModel_2.b(:,indI_q), ssModel_2.c(2*nCONTROL*nDFIG + 2,:), ssModel_2.d(2*nCONTROL*nDFIG + 2,indI_q));

                [y, t] = step(Fss_f_p2, 5); subplot(2,2,1); plot(t, y, 'Color', color_2, 'LineWidth', line_width_2); y_data_all{1} = [y_data_all{1}; y];
                [y, t] = step(Fss_v_p2, 5); subplot(2,2,2); plot(t, y, 'Color', color_2, 'LineWidth', line_width_2); y_data_all{2} = [y_data_all{2}; y];
                [y, t] = step(Fss_f_q2, 5); subplot(2,2,3); plot(t, y, 'Color', color_2, 'LineWidth', line_width_2); y_data_all{3} = [y_data_all{3}; y];
                [y, t] = step(Fss_v_q2, 5); subplot(2,2,4); plot(t, y, 'Color', color_2, 'LineWidth', line_width_2); y_data_all{4} = [y_data_all{4}; y];
            end
        end
        
        % --- Final Formatting ---
        % Add dummy plots to the first subplot for a single, clean legend
        subplot(2,2,1);
        h1 = plot(NaN, NaN, 'Color', color_1, 'LineWidth', line_width_1);
        h2 = plot(NaN, NaN, 'Color', color_2, 'LineWidth', line_width_2);
        legend([h1, h2], {'Baseline Design', 'Robust-Optimized Design'}, 'Interpreter', 'latex', 'FontSize', 11, 'Location', 'best');
        
        % --- Set Y-axis scaling based on user configuration ---
        if link_y_axes
            % Link y-axis for frequency plots
            linkaxes([ax(1), ax(3)], 'y'); 
            % Link y-axis for voltage plots
            linkaxes([ax(2), ax(4)], 'y'); 
        else
            % Set individual Y-axis limits for each subplot
            for i = 1:4
                if ~isempty(y_data_all{i})
                    min_y = min(y_data_all{i});
                    max_y = max(y_data_all{i});
                    range = max_y - min_y;
                    if range == 0; range = 0.1; end % Avoid range being zero, give a small default range
                    padding = range * 0.1; % 10% padding
                    ylim(ax(i), [min_y - padding, max_y + padding]);
                end
            end
        end

    otherwise
end

%==========================================================================
% AUTOMATIC FIGURE EXPORT - IEEE QUALITY (.fig + .pdf)
%==========================================================================

% Get all open figures
all_figs = findall(0, 'Type', 'figure');

if ~isempty(all_figs)
    % Create export directory structure
    project_root = pwd;
    base_export_dir = fullfile(project_root, 'FIGURES', 'PLOT_LIN_MODEL_COMP');

    % Get descriptive subfolder name based on figure type
    subfolder_names = get_figure_subfolder_names();
    subfolder = subfolder_names{figureType};

    % Full export directory path
    figure_export_dir = fullfile(base_export_dir, subfolder);

    % Create directory if it doesn't exist
    if ~exist(figure_export_dir, 'dir')
        mkdir(figure_export_dir);
        fprintf('Created figure export directory: %s\n', figure_export_dir);
    end

    % Define descriptive base name
    case_names = get_case_descriptive_names();
    base_name = case_names{figureType};

    % Save each figure in dual format (.fig + .pdf)
    for i = 1:length(all_figs)
        fig_handle = all_figs(i);
        fig_number = fig_handle.Number;

        % Apply publication formatting
        format_figure_for_publication(fig_handle);

        % Generate descriptive filename: COMP_Slug1_vs_Slug2_##_DescriptiveName[_Fig#]
        if length(all_figs) == 1
            % Single figure
            filename_base = sprintf('COMP_%s_vs_%s_%02d_%s', slug_1, slug_2, figureType, base_name);
        else
            % Multiple figures
            filename_base = sprintf('COMP_%s_vs_%s_%02d_%s_Fig%d', slug_1, slug_2, figureType, base_name, fig_number);
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

end  % End of main function PLOT_LIN_MODEL_COMP

%==========================================================================
% LOCAL FUNCTION: Apply publication formatting to figure
%==========================================================================
function format_figure_for_publication(fig_handle)
% FORMAT_FIGURE_FOR_PUBLICATION - Apply IEEE publication standards to figure
%
% FORMATTING APPLIED:
%   - LaTeX interpreter for all text (titles, labels, legends)
%   - IEEE standard fonts: Times New Roman, 10pt
%   - Figure size: 10×7 inches (suitable for subplots)
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

        % Line properties (all lines in this axes)
        lines = findall(ax, 'Type', 'line');
        set(lines, 'LineWidth', 1.5);

        % Grid settings (BLACK on white background)
        grid(ax, 'on');
        set(ax, 'GridLineStyle', ':');
        set(ax, 'GridColor', [0 0 0]);  % BLACK grid
        set(ax, 'GridAlpha', 0.15);  % Subtle transparency for visibility

        % Box around plot
        box(ax, 'on');
        set(ax, 'LineWidth', 1);
    end

    % Handle all legends in the figure (searched globally after axes loop)
    % This ensures legends created in subplots are properly formatted
    all_legends = findall(fig_handle, 'Type', 'legend');
    for leg_idx = 1:length(all_legends)
        legend_obj = all_legends(leg_idx);
        set(legend_obj, 'Interpreter', 'latex');
        set(legend_obj, 'FontSize', 9);
        set(legend_obj, 'TextColor', [0 0 0]);  % Black text
        set(legend_obj, 'Color', [1 1 1]);      % White background
        set(legend_obj, 'EdgeColor', [0 0 0]);  % Black border
    end

    % Renderer settings for high quality
    set(fig_handle, 'Renderer', 'painters');  % Vector graphics

end

%==========================================================================
% HELPER FUNCTION: Get subfolder names for figure organization
%==========================================================================
function subfolder_names = get_figure_subfolder_names()
% GET_FIGURE_SUBFOLDER_NAMES - Returns subfolder names for FIGURES/PLOT_LIN_MODEL_COMP/
%
% Maps figure types to existing subdirectory structure

    subfolder_names = {
        '01_StepResponse'           % Case 1 - Step response comparison
        '02_FreqPCC_RefSteps'       % Case 2 - Freq/PCC ref steps
        '03_Plant_Nichols'          % Case 3 - Plant Nichols
        '04_Sensitivity'            % Case 4 - Sensitivity functions
        '05_ClosedLoop_Bode'        % Case 5 - Closed-loop Bode
        '06_FreqPCC_LoadSteps'      % Case 6 - Freq/PCC load steps
        '07_Comparative_2x2'        % Case 7 - 2×2 comparative plots
    };
end

%==========================================================================
% HELPER FUNCTION: Get descriptive names for each case
%==========================================================================
function case_names = get_case_descriptive_names()
% GET_CASE_DESCRIPTIVE_NAMES - Returns descriptive names for figure export
%
% Returns cell array with publication-ready names for each of the 7 cases

    case_names = {
        'ClosedLoop_StepResponse'       % Case 1 - Step response comparison
        'FreqPCC_PowerRefSteps'         % Case 2 - Freq/PCC ref steps
        'Plant_OpenLoop_Nichols'        % Case 3 - Plant Nichols
        'Sensitivity_Functions'         % Case 4 - Sensitivity S(s), T(s)
        'ClosedLoop_FreqResponse'       % Case 5 - Closed-loop Bode
        'FreqPCC_LoadSteps'             % Case 6 - Freq/PCC load steps
        'Comparative_2x2'               % Case 7 - 2×2 comparative plots
    };
end

