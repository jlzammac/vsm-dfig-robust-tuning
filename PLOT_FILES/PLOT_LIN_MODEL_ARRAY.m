function PLOT_LIN_MODEL_ARRAY(slug, figureType)
% PLOT_LIN_MODEL_ARRAY - Visualize stability maps across parametric operating point sweeps
%
% SYNTAX:
%   PLOT_LIN_MODEL_ARRAY(slug, figureType)
%
% DESCRIPTION:
%   Generates 20 different visualization cases for linear analysis of DFIG-based wind farms
%   across multiple operating points. Analyzes stability maps, damping ratios, eigenvalue
%   distributions, and frequency responses for parametric sweeps of Vpcc, Pdfig, and SCRgrid.
%
% INPUTS:
%   slug       - String identifier for LINEAR_ANALYSIS .mat file in RESULTS/LINEAR_ANALYSIS/
%                Format: 'YYYYMMDD_HHMMSS_TYPE_CONTROL_nDFIG'
%                Example: '20251014_201712_ENDPOINTS_FRD_4DFIG'
%                        '20251014_173022_SWEEP_TRD_4DFIG'
%
%   figureType - Integer (1-20) specifying which visualization to generate
%
% OPERATING POINT SWEEPS:
%   - ENDPOINTS: 8 operating points (boundary analysis, RUN_MODE = 1)
%   - SWEEP: 225 operating points (full stability map, RUN_MODE = 2)
%
% FILE LOADING:
%   The function automatically loads: RESULTS/LINEAR_ANALYSIS/LINEAR_ANALYSIS_<slug>.mat
%   Required structure: LIN_MODEL_ARRAY with fields .OPset and .LIN_MODEL
%
% SUPPORTED FIGURE TYPES (20 cases):
%
%   --- TIME-DOMAIN ANALYSIS ---
%   1.  Closed-loop step response for all operating points (DFIGs 1 and 3)
%       - 7 control loops: VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq
%       - Shows control interaction effects across operating envelope
%       - Output: DC gain values for VSMP control
%
%   --- FREQUENCY-DOMAIN STEP RESPONSES ---
%   2.  Frequency and PCC voltage response to P and Q reference steps
%       - Computes ROCOF (Rate of Change of Frequency) and nadir
%       - Computes ROCOV (Rate of Change of Voltage) and voltage nadir
%       - Critical for grid code compliance analysis
%
%   6.  Frequency and PCC voltage response to active/reactive load steps - OP SWEEP
%       - Load disturbance rejection capability across operating envelope
%       - ROCOF/ROCOV and nadir metrics for grid code compliance
%       - Publication-quality formatting (Times New Roman, LaTeX, white background)
%       - 2×2 subplot grid: Active/Reactive disturbances × Frequency/Voltage outputs
%       - Results sorted by severity (worst cases first) for each metric
%
%   --- FREQUENCY-DOMAIN ANALYSIS (NICHOLS/BODE) ---
%   3.  Plant and open-loop frequency response (Nichols diagram)
%       - Gain margin (GM) and phase margin (PM) calculation
%       - Unity gain crossover frequency (wo) and -180° crossover (wu)
%       - Critical for stability margin assessment
%
%   4.  Sensitivity (S) and complementary sensitivity (T) Bode magnitude
%       - Maximum sensitivity (Ms) and frequency (ws)
%       - Maximum complementary sensitivity (Mt) and frequency (wt)
%       - Robustness and noise rejection analysis
%
%   5.  Closed-loop frequency response (T) Bode magnitude - OPERATING POINT SWEEP
%       - Resonance peak (Mr) and resonance frequency (wr)
%       - Bandwidth and damping characterization across operating envelope
%       - Publication-quality formatting (Times New Roman, LaTeX, white background)
%       - Frequency ranges optimized per controller (inherited from PLOT_LIN_MODEL case 9)
%       - Extended Y-axis range for current control loops (RSCd/RSCq: -35 to 15 dB)
%
%   --- STABILITY HEATMAPS (COLORMAPS) ---
%   7.  Minimum damping ratio heatmap (eigenvalues 5 to end)
%       - Identifies poorly damped oscillatory modes across operating envelope
%       - Color scale: low damping (red) to high damping (white)
%
%   8.  Natural frequency heatmap (rad/s) for minimum damping eigenvalue
%       - Shows oscillation frequency of critical modes
%       - Useful for resonance avoidance analysis
%
%   9.  Maximum real eigenvalue heatmap
%       - Direct stability indicator (positive = unstable)
%       - Critical for identifying unstable operating regions
%
%   10. Minimum damping ratio heatmap (eigenvalues 1 to 4)
%       - Focuses on fastest modes (typically current control loops)
%       - High-frequency stability assessment
%
%   11. Minimum time constant heatmap (μs)
%       - Identifies slowest (most critical) pole in the system
%       - Large τ → slow pole close to instability (HIGH criticality)
%       - Small τ → fast pole far from instability (LOW criticality)
%
%   12. Line angle heatmap (degrees)
%       - Power transfer angle between DFIG and grid
%       - Critical for voltage stability assessment
%
%   13. Wind speed heatmap (m/s)
%       - Mean wind speed distribution across operating points
%       - High wind speed → high power → approach stability limits (HIGH criticality)
%
%   14. Rotor speed heatmap (pu)
%       - Mean rotor speed distribution across operating points
%       - High rotor speed → super-synchronous → high power → stability limits (HIGH criticality)
%
%   18. Binary stability map (stable/unstable)
%       - White: stable (max real eigenvalue < 0)
%       - Black: unstable (max real eigenvalue > 0)
%       - Excludes SCR = 3, displays 2×2 grid for SCR < 3
%
%   --- ROOT LOCUS ANALYSIS ---
%   15. Root locus vs. Pdfig for fixed SCR=1 (DFIG power sweep at critical grid strength)
%       - Figure 1: Complex poles (natural frequency ωn and damping ζ) vs. Pdfig
%       - Figure 2: Real poles vs. Pdfig
%       - 2×2 grid: 4 subplots, each for one voltage (2 lowest + 2 highest)
%       - Shows power-dependent stability limits at most critical grid condition
%       - Unstable points marked with red circles (no line connection)
%
%   16. Root locus vs. Vpcc for fixed SCR=1 (PCC voltage sweep at critical grid strength)
%       - Figure 1: Complex poles (natural frequency ωn and damping ζ) vs. Vpcc
%       - Figure 2: Real poles vs. Vpcc
%       - 2×2 grid: 4 subplots, each for one power level (4 highest powers)
%       - Shows voltage-dependent stability boundaries at maximum power operation
%       - Unstable points marked with red circles (no line connection)
%
%   17. Root locus vs. SCRgrid for fixed Pdfig=1 (grid strength sweep at rated power)
%       - Figure 1: Complex poles (natural frequency ωn and damping ζ) vs. SCR
%       - Figure 2: Real poles vs. SCR
%       - 2×2 grid: 4 subplots, each for one voltage (2 lowest + 2 highest)
%       - Shows impact of grid stiffness on stability at rated power
%       - Critical for weak grid operation assessment
%       - Unstable points marked with red circles (no line connection)
%
%   --- COMPARATIVE ANALYSIS ---
%   19. Line angle vs. power for different SCR levels
%       - Maximum line angle (worst case) for each (SCRgrid, Pdfig) pair
%       - Identifies voltage collapse risk regions
%
%   20. 2×2 comparative stability and damping analysis
%       - Left column: SCR influence at minimum Vpcc
%       - Right column: Vpcc influence at SCR = 1
%       - Top row: Maximum real eigenvalue vs. power
%       - Bottom row: Minimum damping ratio vs. power
%       - Unstable points marked with 'X'
%
% PAPER-QUALITY FORMATTING:
%   - All plots use LaTeX interpreter for mathematical notation
%   - Times New Roman font throughout
%   - Professional color schemes (white-to-red heatmaps, lines colormap)
%   - Grid, legends, and axis labels formatted for IEEE publications
%
% ANALYSIS TYPE COMPARISON:
%   ENDPOINTS (8 OPs):  Quick boundary stability check, fast computation
%   SWEEP (225 OPs):    Full stability mapping, comprehensive analysis
%
% CUSTOMIZATION - Y-AXIS LIMITS:
%   Each figure case has independent Y-axis configuration in its header
%   CONFIGURATION SECTION. All subplots can have independent scales.
%
%   CASE 5 (Closed-loop frequency response - 7 subplots):
%     Location: ylim_dB array (7×2 matrix, one row per controller)
%     Units: dB
%     Options:
%       - Fixed:  [-15 10]     → Set explicit min/max
%       - Auto:   [NaN NaN]    → Automatic MATLAB scaling
%       - Mixed:  [-15 NaN]    → Fix min, auto max
%     Example: ylim_dB = [-20 15; NaN NaN; -40 20; -40 20; -15 10; NaN NaN; -15 10];
%
%   CASE 6 (Load disturbance response - 4 subplots):
%     Location: ylim_range array (4×2 matrix, one row per subplot)
%     Units: pu (per unit)
%     Subplot order: [Active→f, Active→V, Reactive→f, Reactive→V]
%     Options:
%       - Fixed:  [-0.05 0.05] → Set explicit min/max
%       - Auto:   [NaN NaN]    → Automatic MATLAB scaling
%       - Legacy: []           → All subplots auto (backward compatible)
%     Example: ylim_range = [-0.1 0.1; NaN NaN; -0.02 0.02; -0.08 0.08];
%
% EXAMPLES:
%   % Load ENDPOINTS analysis and plot closed-loop step responses
%   PLOT_LIN_MODEL_ARRAY('20251014_201712_ENDPOINTS_FRD_4DFIG', 1)
%
%   % Load SWEEP analysis and generate stability heatmap
%   PLOT_LIN_MODEL_ARRAY('20251014_173022_SWEEP_TRD_4DFIG', 7)
%
%   % Compare TRD vs FRD using binary stability map
%   PLOT_LIN_MODEL_ARRAY('20251014_201712_ENDPOINTS_TRD_4DFIG', 18)
%   PLOT_LIN_MODEL_ARRAY('20251014_201712_ENDPOINTS_FRD_4DFIG', 18)
%
% FILE DEPENDENCIES:
%   - RESULTS/LINEAR_ANALYSIS/LINEAR_ANALYSIS_<slug>.mat
%   - Generated by CONFIG_POWER_SYSTEM.m with RUN_MODE = 1 (ENDPOINTS) or 2 (SWEEP)
%
% SEE ALSO:
%   PLOT_LIN_MODEL, CONFIG_POWER_SYSTEM, LINEAR_ANALYSIS
%
% AUTHOR: DFIG Wind Farm Analysis Project
% DATE: 2025-01-14 (Project reorganization)
%       2025-01-21 (Cases 5 & 6 publication-quality optimization)
%       2025-01-21 (Independent Y-axis limits per subplot with auto/fixed/mixed modes)

%--------------------------------------------------------------
% Load LINEAR_ANALYSIS data from slug
%--------------------------------------------------------------
filename = ['LINEAR_ANALYSIS_' slug '.mat'];
filepath = ['../RESULTS/LINEAR_ANALYSIS/' filename];

if ~isfile(filepath)
    error('File not found: %s\nPlease verify the slug identifier.', filepath);
end

% Load LIN_MODEL_ARRAY structure
data = load(filepath);
if isfield(data, 'LIN_MODEL_ARRAY')
    LIN_MODEL_ARRAY = data.LIN_MODEL_ARRAY;
else
    % Display available variables to help debugging
    availableVars = fieldnames(data);
    fprintf('\nAvailable variables in file:\n');
    disp(availableVars);
    error(['File does not contain LIN_MODEL_ARRAY structure: %s\n', ...
           'This file may be incomplete or corrupted.\n', ...
           'Please run CONFIG_POWER_SYSTEM.m with RUN_MODE = 1 (ENDPOINTS) or 2 (SWEEP) to regenerate.'], ...
           filepath);
end

fprintf('Loaded: %s\n', filename);
fprintf('Operating points: %d\n', size(LIN_MODEL_ARRAY.OPset, 1));
fprintf('Figure type: %d\n\n', figureType);

%--------------------------------------------------------------
% Configurable Colors for Stability Plot (case 18)
%--------------------------------------------------------------
stabilityPlotColors.stable = [1 1 1];           % White 
stabilityPlotColors.unstable = [0 0 0];         % Black
% stabilityPlotColors.stable = [0.2 0.7 0.2];   % Green
% stabilityPlotColors.unstable = [0.8 0.2 0.2]; % Red

%--------------------------------------------------------------
% Set of operating points
%--------------------------------------------------------------
close('all')
OPset = LIN_MODEL_ARRAY.OPset;
LIN_MODEL = LIN_MODEL_ARRAY.LIN_MODEL;
numOP = size(OPset,1);

%--------------------------------------------------------------
% MODEL and CONTROL buses
%--------------------------------------------------------------
MODEL = LIN_MODEL{1}.MODEL;
CONTROL = LIN_MODEL{1}.CONTROL;
% Laplace variable
s = tf('s'); 
%--------------------------------------------------------------------------
% VSMP control parameters
%--------------------------------------------------------------------------
% Inertia [s]
H = CONTROL.VSMP.PARAM.H(1); 
% Steady-state damping
Dp = CONTROL.VSMP.PARAM.Dp(1); 
% Transient damping
Dd = CONTROL.VSMP.PARAM.Dd(1);
%--------------------------------------------------------------------------
% VSMQ control parameters
%--------------------------------------------------------------------------
% Voltage control
K_Fs_ref = CONTROL.VSMQ.PARAM.K_Fs_ref(1);
%--------------------------------------------------------------------------
% RSC current control (axid d) - Reactive power
%--------------------------------------------------------------------------
Kp_ird = CONTROL.RSCd.PARAM.Kp(1); 
Ki_ird = CONTROL.RSCd.PARAM.Ki(1); 
%--------------------------------------------------------------------------
% RSC current control (axid q) - Active power
%--------------------------------------------------------------------------
Kp_irq = CONTROL.RSCq.PARAM.Kp(1); 
Ki_irq = CONTROL.RSCq.PARAM.Ki(1); 
%--------------------------------------------------------------------------
% DC-Link voltage control
%--------------------------------------------------------------------------
Kp_vdc = CONTROL.VDC.PARAM.Kp(1);
Ki_vdc = CONTROL.VDC.PARAM.Ki(1);
%--------------------------------------------------------------------------
% GSC current control (axid d) - Reactive power
%--------------------------------------------------------------------------
Kp_igd = CONTROL.GSCd.PARAM.Kp(1); 
Ki_igd = CONTROL.GSCd.PARAM.Ki(1); 
%--------------------------------------------------------------------------
% GSC current control (axid q) - Active power
%--------------------------------------------------------------------------
Kp_igq = CONTROL.GSCq.PARAM.Kp(1); 
Ki_igq = CONTROL.GSCq.PARAM.Ki(1); 

%--------------------------------------------------------------
% Labels
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
DFIGLabel = {'SCR trafo = 10','SCR trafo = 5'};
nDFIG = MODEL.DFIG.PARAM.nDFIG;
nCONTROL = 7;
% Current controllers
currentCss = {    
    ss((1+Dd*s)/(1+2*H/Dp*s));
    ss(K_Fs_ref);
    ss(Kp_ird + Ki_ird/s);
    ss(Kp_irq + Ki_irq/s);
    ss(Kp_vdc + Ki_vdc/s);
    ss(Kp_igd + Ki_igd/s);
    ss(Kp_igq + Ki_igq/s);   
    };

switch (figureType)
   %======================================================================
   % CASE 1: Closed-Loop Step Response for All Operating Points
   %======================================================================
   % PURPOSE:
   %   Visualize closed-loop step responses T(s) = y/r for all 7 control
   %   loops across the entire operating envelope. Analyzes control
   %   interaction effects and DC gain variations with operating conditions.
   %
   % ANALYSIS TYPE:
   %   Compatible with both ENDPOINTS (8 OPs) and SWEEP (225 OPs)
   %
   % METHODOLOGY:
   %   1. Extract complementary sensitivity T(s) = -G(s)C(s)/(1+G(s)C(s))
   %   2. Compute step response for each OP and control loop
   %   3. Calculate DC gain for VSMP control
   %   4. Generate 3x3 subplot array (7 control loops + 2 empty)
   %
   % CONTROLS ANALYZED:
   %   - VSMP: Virtual Synchronous Machine active power (slow dynamics)
   %   - VSMQ: Virtual Synchronous Machine reactive power (slow dynamics)
   %   - RSCd: Rotor-side converter d-axis current (fast dynamics)
   %   - RSCq: Rotor-side converter q-axis current (fast dynamics)
   %   - VDC:  DC-link voltage control (medium dynamics)
   %   - GSCd: Grid-side converter d-axis current (fast dynamics)
   %   - GSCq: Grid-side converter q-axis current (fast dynamics)
   %
   % DFIGs ANALYZED:
   %   - DFIG 1: SCR_transformer = 10 (strong connection)
   %   - DFIG 3: SCR_transformer = 5 (weak connection)
   %
   % OUTPUTS:
   %   - Figure: 3x3 subplots with step responses for each control loop
   %   - Console: Extended OPset table with VSMP DC gain values
   %
   % INTERPRETATION:
   %   - Overshoot/oscillations indicate poor damping or control interaction
   %   - DC gain variation shows operating point dependency
   %   - Settling time differences reveal controller tuning quality
   %   - DFIG 1 vs DFIG 3 comparison shows grid strength impact
   %----------------------------------------------------------------------
    case 1  % Closed-loop step response for all operating points
   %----------------------------------------------------------------------
       % Step 1: Select DFIGs for comparison
       %----------------------------------------------------------------------
       hDFIG = [1 3];  % DFIG 1 (SCR=10) and DFIG 3 (SCR=5)
       SCRdfig = MODEL.DFIG.PARAM.SCR_transformer(hDFIG);

       % Extended operating point set (duplicate for each DFIG)
       OPsetExt = repmat(OPset, 2, 1);
       OPsetExt.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];

       %----------------------------------------------------------------------
       % Step 2: Define simulation time horizons for each control loop
       %----------------------------------------------------------------------
       % Time horizons optimized for each controller's dynamics
       tfin = [1.5;    % VSMP: slow power dynamics (seconds)
               3.0;    % VSMQ: very slow voltage dynamics (seconds)
               0.01;  % RSCd: fast rotor current control (milliseconds)
               0.01;  % RSCq: fast rotor current control (milliseconds)
               0.1;    % VDC: medium DC-link voltage dynamics (milliseconds)
               0.01;  % GSCd: very fast grid-side current control (milliseconds)
               0.01]; % GSCq: very fast grid-side current control (milliseconds)

       %----------------------------------------------------------------------
       % Step 3: Generate step response plots
       %----------------------------------------------------------------------
       fig = figure('Name', 'Case 1: Closed-Loop Step Response', ...
                    'Position', [100, 100, 1200, 900], ...
                    'Color', 'white');

       % Define grayscale colors for multiple curves (paper-quality)
       % Gradient from light gray to black (so darker lines are drawn last)
       numCurves = numOP * length(hDFIG);
       colormap_gray = [linspace(0.7, 0, numCurves)', ...
                        linspace(0.7, 0, numCurves)', ...
                        linspace(0.7, 0, numCurves)'];

       for nn = 1:nCONTROL
           subplot(3, 3, nn)
           hold on

           curveIndex = 0;
           % Loop over DFIGs and operating points
           for ii = 1:length(hDFIG)
               for jj = 1:numOP
                   curveIndex = curveIndex + 1;

                   % Extract state-space model for current operating point
                   ssModel = LIN_MODEL{jj}.ssModel;
                   matA = ssModel.a;
                   matB = ssModel.b;
                   matC = ssModel.c;
                   matD = ssModel.d;

                   % Extract complementary sensitivity T(s) for current control loop
                   indT = nCONTROL*(hDFIG(ii)-1) + nn;
                   Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));

                   % Compute step response
                   t = linspace(0, tfin(nn), 5000);
                   y = step(-Tss, t);

                   % Plot with paper-quality formatting (grayscale)
                   plot(t, y, 'LineWidth', 1.5, 'Color', colormap_gray(curveIndex,:));

                   % Store DC gain for VSMP control
                   if nn == 1
                       OPsetExt.VSMP_dcgain(numOP*(ii-1)+jj) = dcgain(-Tss);
                   end
               end
           end

           % Subplot formatting with LaTeX interpreter
           xlim([0 tfin(nn)]);
           xlabel('$t$ (s)', 'Interpreter', 'latex', 'FontSize', 11);
           ylabel(OutputLabel{nn}, 'Interpreter', 'latex', 'FontSize', 11);
           title(ControlLabel{nn}, 'Interpreter', 'latex', 'FontSize', 12, 'Color', 'k');
           grid on
           set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
                    'Color', 'white', 'XColor', 'k', 'YColor', 'k');
           hold off
       end

       %----------------------------------------------------------------------
       % Step 4: Display results table
       %----------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 1: Closed-Loop Step Response Analysis                   ║\n');
       fprintf('╠════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Operating Points Analyzed: %-3d                               ║\n', numOP);
       fprintf('║  DFIGs Analyzed: DFIG 1 (SCR=10), DFIG 3 (SCR=5)              ║\n');
       fprintf('║  Control Loops: 7 (VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq)   ║\n');
       fprintf('╚════════════════════════════════════════════════════════════════╝\n');
       fprintf('\nExtended Operating Point Set with VSMP DC Gain:\n');
       disp(OPsetExt);

       fprintf('\nInterpretation Guide:\n');
       fprintf('  • VSMP_dcgain: DC gain variation indicates operating point sensitivity\n');
       fprintf('  • Overshoot: High overshoot suggests poor damping or interaction\n');
       fprintf('  • Settling time: Fast controllers (RSC/GSC) settle in <250 ms\n');
       fprintf('  • DFIG comparison: SCR=5 typically shows more oscillatory behavior\n');
   %======================================================================
   % CASE 2: Frequency and PCC Voltage Response to P and Q Reference Steps
   %======================================================================
   % PURPOSE:
   %   Analyze grid frequency and PCC voltage response to active (P) and
   %   reactive (Q) power reference steps. Critical for grid code compliance
   %   analysis (ROCOF, ROCOV, nadir requirements).
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
   %
   % GRID CODE METRICS:
   %   - ROCOF: df/dt at half-rise time (pu/s) - Grid code limit typically 1 Hz/s
   %   - ROCOV: dV/dt at half-rise time (pu/s) - Grid code limit typically 3%/s
   %   - Frequency nadir: Maximum frequency deviation (pu) - Limit typically 0.5 Hz
   %   - Voltage nadir: Maximum voltage deviation (pu) - Limit typically 10%
   %
   % DFIGs ANALYZED:
   %   - DFIG 1: SCR_transformer = 10 (strong connection)
   %   - DFIG 3: SCR_transformer = 5 (weak connection)
   %
   % OUTPUTS:
   %   - Figure: 2×2 subplots (P step → f/Vpcc, Q step → f/Vpcc)
   %   - Console: 4 ranked tables (worst-case ROCOF, ROCOV, nadir_f, nadir_V)
   %
   % INTERPRETATION:
   %   - High ROCOF/ROCOV indicates insufficient inertia or damping
   %   - Deep nadir suggests weak grid or poor controller tuning
   %   - Unstable points excluded from plots and metrics
   %   - SCR=5 typically shows worse performance than SCR=10
   %----------------------------------------------------------------------
    case 2  % Frequency and PCC voltage response to P and Q reference steps
   %----------------------------------------------------------------------
       % Step 1: Select DFIGs and configure analysis
       %----------------------------------------------------------------------
       hDFIG = [1 3];  % DFIG 1 (SCR=10) and DFIG 3 (SCR=5)
       SCRdfig = MODEL.DFIG.PARAM.SCR_transformer(hDFIG);

       % Create figure with paper-quality formatting
       fig = figure('Name', 'Case 2: Grid Response to P/Q Steps', ...
                    'Position', [100, 100, 1200, 800], ...
                    'Color', 'white');

       % Time vectors for frequency and voltage (5-second window)
       t = {linspace(0, 5, 500); linspace(0, 5, 500)};
       outLabel = {'Frequency (pu)', 'PCC voltage (pu)'};
       titleLabel = {'P reference step', 'Q reference step'};

       %----------------------------------------------------------------------
       % Step 2: Initialize metrics storage
       %----------------------------------------------------------------------
       % ROCOX: Rate of Change (ROCOF for f, ROCOV for Vpcc)
       % nadir: Maximum deviation from steady state
       ROCOX = NaN(length(hDFIG)*numOP, 2);  % [ROCOF, ROCOV]
       nadir = NaN(length(hDFIG)*numOP, 2);  % [nadir_f, nadir_V]

       %----------------------------------------------------------------------
       % Step 3: Compute step responses and metrics
       %----------------------------------------------------------------------
       % Generate grayscale color map for all curves
       totalCurves = length(hDFIG) * numOP;
       grayColors = linspace(0, 0.7, totalCurves);  % Black (0) to light gray (0.7)

       for nn = 1:2  % Loop: 1=P step, 2=Q step
           for ii = 1:2  % Loop: 1=frequency, 2=voltage
               subplot(2, 2, 2*(nn-1)+ii)
               hold on

               curveIdx = 0;
               for jj = 1:length(hDFIG)  % DFIG 1 and 3
                   for kk = 1:numOP  % All operating points
                       curveIdx = curveIdx + 1;

                       % Extract state-space model
                       ssModel = LIN_MODEL{kk}.ssModel;
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

                       % Plot only stable operating points with grayscale colors
                       if LIN_MODEL{kk}.stability
                           grayLevel = grayColors(curveIdx);
                           plot(t{ii}, y, 'LineWidth', 1.5, 'Color', [grayLevel grayLevel grayLevel]);
                       end

                       % Compute ROCOF/ROCOV and nadir for relevant combinations
                       if (nn==1 && ii==1) || (nn==2 && ii==2)  % P→f or Q→Vpcc
                           % Find half-rise time index
                           [miny, ind] = min(abs(y - y(end)/2));

                           % Validate response quality
                           if abs(miny) > 10  % Poor response quality
                               ROCOX(numOP*(jj-1)+kk, ii) = NaN;
                               nadir(numOP*(jj-1)+kk, ii) = NaN;
                           else
                               % ROCOF/ROCOV: slope at half-rise time
                               ROCOX(numOP*(jj-1)+kk, ii) = abs(y(ind)/t{ii}(ind));
                               % Nadir: maximum absolute deviation
                               nadir(numOP*(jj-1)+kk, ii) = abs(max(abs(y)));
                           end
                       end
                   end
               end

               % Subplot formatting with LaTeX interpreter
               xlabel('$t$ (s)', 'Interpreter', 'latex', 'FontSize', 11);
               ylabel(outLabel{ii}, 'Interpreter', 'latex', 'FontSize', 11);
               title(titleLabel{nn}, 'Interpreter', 'latex', 'FontSize', 12, 'Color', 'k');
               xlim([0 t{ii}(end)]);
               grid on
               set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
                        'Color', 'white', 'XColor', 'k', 'YColor', 'k');
               hold off
           end
       end

       %----------------------------------------------------------------------
       % Step 4: Rank and display results
       %----------------------------------------------------------------------
       [sortedData, ind] = sort([ROCOX nadir], 'descend');
       OPsetExt = repmat(OPset, 2, 1);
       OPsetExt.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];
       OPsetCell = cell(1, 4);

       % Table 1: Worst-case ROCOF (ranked)
       OPsetCell{1} = OPsetExt(ind(:,1), :);
       OPsetCell{1}.ROCOF = sortedData(:,1);

       % Table 2: Worst-case ROCOV (ranked)
       OPsetCell{2} = OPsetExt(ind(:,2), :);
       OPsetCell{2}.ROCOV = sortedData(:,2);

       % Table 3: Worst-case frequency nadir (ranked)
       OPsetCell{3} = OPsetExt(ind(:,3), :);
       OPsetCell{3}.nadir_f = sortedData(:,3);

       % Table 4: Worst-case voltage nadir (ranked)
       OPsetCell{4} = OPsetExt(ind(:,4), :);
       OPsetCell{4}.nadir_V = sortedData(:,4);

       fprintf('\n');
       fprintf('╔════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 2: Grid Response to P/Q Reference Steps                 ║\n');
       fprintf('╠════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Operating Points: %-3d  |  DFIGs: 1 (SCR=10), 3 (SCR=5)     ║\n', numOP);
       fprintf('╚════════════════════════════════════════════════════════════════╝\n');
       fprintf('\n1. Worst-case ROCOF (Rate of Change of Frequency):\n');
       disp(OPsetCell{1});
       fprintf('\n2. Worst-case ROCOV (Rate of Change of Voltage):\n');
       disp(OPsetCell{2});
       fprintf('\n3. Worst-case Frequency Nadir:\n');
       disp(OPsetCell{3});
       fprintf('\n4. Worst-case Voltage Nadir:\n');
       disp(OPsetCell{4});

       fprintf('\nGrid Code Compliance Guide:\n');
       fprintf('  • ROCOF limit: Typically 1 Hz/s (0.02 pu/s @ 50 Hz)\n');
       fprintf('  • ROCOV limit: Typically 3%%/s (0.03 pu/s)\n');
       fprintf('  • Frequency nadir: Typically ±0.5 Hz (0.01 pu @ 50 Hz)\n');
       fprintf('  • Voltage nadir: Typically ±10%% (0.1 pu)\n');
        
   %======================================================================
   % CASE 3: Plant Open-Loop Frequency Response (Nichols Diagram)
   %======================================================================
   % PURPOSE:
   %   Analyze plant open-loop transfer function G(s) = -T(s)/S(s) to assess
   %   stability margins. Nichols diagram shows gain margin (GM) and phase
   %   margin (PM) across operating envelope for all 7 control loops.
   %
   % ANALYSIS TYPE:
   %   Compatible with both ENDPOINTS (8 OPs) and SWEEP (225 OPs)
   %
   % METHODOLOGY:
   %   1. Extract complementary sensitivity T(s) and sensitivity S(s)
   %   2. Compute plant G(s) = -T(s)/S(s)
   %   3. Plot Nichols diagram (gain vs phase)
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
   %   - Figure: 3×3 Nichols diagrams (7 control loops)
   %   - Console: 7 tables with GM, PM, wu, wo for each control loop
   %
   % INTERPRETATION:
   %   - Low GM/PM indicates marginal stability
   %   - Higher wu/wo suggests aggressive tuning
   %   - Operating point variation shows robustness
   %   - SCR=5 typically shows reduced margins vs SCR=10
   %----------------------------------------------------------------------
    case 3  % Plant open-loop frequency response (Nichols diagram)
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
       SCRdfig = MODEL.DFIG.PARAM.SCR_transformer(hDFIG);

       % Initialize stability margin arrays
       Am = NaN(length(hDFIG)*numOP, nCONTROL);    % Gain margin (linear)
       AmdB = NaN(length(hDFIG)*numOP, nCONTROL);  % Gain margin (dB)
       Fm = NaN(length(hDFIG)*numOP, nCONTROL);    % Phase margin (degrees)
       wu = NaN(length(hDFIG)*numOP, nCONTROL);    % -180° crossover freq (rad/s)
       wo = NaN(length(hDFIG)*numOP, nCONTROL);    % Unity gain crossover freq (rad/s)

       OPsetExt = repmat(OPset, 2, 1);
       OPsetExt.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];
       OPsetCell = cell(1, nCONTROL);

       %----------------------------------------------------------------------
       % Step 2: Configure fsolve for crossover frequency calculation
       %----------------------------------------------------------------------
       opt_fsolve = optimoptions('fsolve');
       opt_fsolve.MaxIterations = 5000;
       opt_fsolve.Display = 'off';

       % Initial guesses for crossover frequencies (rad/s)
       w_ini = [10, 2.5, 350, 350, 100, 500, 500];

       %----------------------------------------------------------------------
       % Step 3: Generate Nichols diagrams and compute margins
       %----------------------------------------------------------------------
       fig = figure('Name', 'Case 3: Plant Open-Loop Nichols Diagram', ...
                    'Position', [100, 100, 1200, 900], ...
                    'Color', 'white');

       % Generate grayscale color map for all curves
       totalCurves = length(hDFIG) * numOP;
       grayColors = linspace(0, 0.7, totalCurves);  % Black (0) to light gray (0.7)

       for nn = 1:nCONTROL
           subplot(3, 3, nn)
           hold on

           % Logarithmic frequency vector for current controller
           w = logspace(logw(nn,1), logw(nn,2), 1000);

           curveIdx = 0;
           for ii = 1:length(hDFIG)
               for jj = 1:numOP
                   curveIdx = curveIdx + 1;
                   % Extract state-space model
                   ssModel = LIN_MODEL{jj}.ssModel;
                   matA = ssModel.a;
                   matB = ssModel.b;
                   matC = ssModel.c;
                   matD = ssModel.d;

                   % Extract T(s) and S(s) transfer functions
                   indT = nCONTROL*(hDFIG(ii)-1) + nn;
                   indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + nn;
                   Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                   Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));

                   % Compute plant open-loop: G(s) = -T(s)/S(s)
                   Gss = -Tss/Sss;

                   %------------------------------------------------------
                   % Manual Nichols plot (EXACT method from PLOT_LIN_MODEL case 7)
                   %------------------------------------------------------
                   % Compute frequency response manually
                   [magG, phaseG] = bode(Gss, w);
                   magG_dB = 20*log10(squeeze(magG));
                   phaseG = squeeze(phaseG);

                   % Unwrap phase to get continuous curves (no jumps)
                   phaseG = unwrap(phaseG * pi/180) * 180/pi;

                   % Shift phase to be centered around -180° for better visualization
                   medianG = median(phaseG);
                   shiftG = round((medianG + 180) / 360) * 360;
                   phaseG = phaseG - shiftG;

                   % Plot with grayscale color for publication quality
                   grayLevel = grayColors(curveIdx);
                   plot(phaseG, magG_dB, 'LineWidth', 1.5, 'Color', [grayLevel grayLevel grayLevel]);

                   %------------------------------------------------------
                   % Calculate unity gain crossover frequency (wo)
                   %------------------------------------------------------
                   [wo(numOP*(ii-1)+jj,nn), ~, exitflag] = fsolve(@(w) abs(freqresp(Gss,w))-1, w_ini(nn), opt_fsolve);
                   if exitflag < 1 || wo(numOP*(ii-1)+jj,nn) < 0
                       wo(numOP*(ii-1)+jj,nn) = NaN;
                       Fm(numOP*(ii-1)+jj,nn) = NaN;
                   else
                       % Phase margin: phase at wo + 180°
                       Fm(numOP*(ii-1)+jj,nn) = 180 + 180/pi*angle(freqresp(Gss, wo(numOP*(ii-1)+jj,nn)));
                   end

                   %------------------------------------------------------
                   % Calculate -180° crossover frequency (wu)
                   %------------------------------------------------------
                   [wu(numOP*(ii-1)+jj,nn), ~, exitflag] = fsolve(@(w) 180/pi*angle(freqresp(Gss,w))+180, w_ini(nn), opt_fsolve);
                   if exitflag < 1 || wu(numOP*(ii-1)+jj,nn) < 0
                       wu(numOP*(ii-1)+jj,nn) = NaN;
                       Am(numOP*(ii-1)+jj,nn) = NaN;
                       AmdB(numOP*(ii-1)+jj,nn) = NaN;
                   else
                       % Gain margin: 1/|G(wu)|
                       Am(numOP*(ii-1)+jj,nn) = 1/abs(freqresp(Gss, wu(numOP*(ii-1)+jj,nn)));
                       AmdB(numOP*(ii-1)+jj,nn) = 20*log10(Am(numOP*(ii-1)+jj,nn));
                   end
               end
           end

           %------------------------------------------------------
           % Add reference lines: 0 dB and -180°
           %------------------------------------------------------
           % Capture final axis limits based ONLY on Nichols curves
           final_xlim = xlim;
           final_ylim = ylim;

           % Adjust phase axis to always include -180 degrees (critical stability point)
           if final_xlim(1) > -180
               final_xlim(1) = min(final_xlim(1), -200);
           end
           if final_xlim(2) < -180
               final_xlim(2) = max(final_xlim(2), -160);
           end

           % Draw reference lines extending far beyond plot limits
           plot([-1000 1000], [0 0], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');  % 0 dB
           plot([-180 -180], [-1000 1000], 'k-', 'LineWidth', 0.5, 'HandleVisibility', 'off');  % -180°

           % Restore axis limits
           xlim(final_xlim);
           ylim(final_ylim);

           % Subplot formatting with LaTeX interpreter
           xlabel('Open-Loop Phase (deg)', 'Interpreter', 'latex', 'FontSize', 11);
           ylabel('Open-Loop Gain (dB)', 'Interpreter', 'latex', 'FontSize', 11);
           title(ControlLabel{nn}, 'Interpreter', 'latex', 'FontSize', 12, 'Color', 'k');
           grid on
           set(gca, 'FontName', 'Times New Roman', 'FontSize', 10, ...
                    'Color', 'white', 'XColor', 'k', 'YColor', 'k');
           hold off

           % Store results for current control loop
           OPsetCell{nn} = OPsetExt;
           OPsetCell{nn}.GM_dB = AmdB(:,nn);
           OPsetCell{nn}.PM_deg = Fm(:,nn);
           OPsetCell{nn}.wu_rads = wu(:,nn);
           OPsetCell{nn}.wo_rads = wo(:,nn);
       end

       %----------------------------------------------------------------------
       % Step 4: Display stability margin tables
       %----------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 3: Plant Open-Loop Stability Margins                    ║\n');
       fprintf('╠════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Operating Points: %-3d  |  DFIGs: 1 (SCR=10), 3 (SCR=5)     ║\n', numOP);
       fprintf('╚════════════════════════════════════════════════════════════════╝\n');

       for nn = 1:nCONTROL
           fprintf('\n%d. %s Control Loop:\n', nn, ControlLabel{nn});
           disp(OPsetCell{nn});
       end

       fprintf('\nStability Margin Guidelines:\n');
       fprintf('  • Gain Margin (GM): > 6 dB recommended (adequate stability)\n');
       fprintf('  • Phase Margin (PM): > 30° recommended (good damping)\n');
       fprintf('  • High wo/wu: Aggressive tuning (faster response, lower margins)\n');
       fprintf('  • Low wo/wu: Conservative tuning (slower response, higher margins)\n');
   %--------------------------------------------------------------
    case 4 % Sensitivity and Complementary Sensitivity Bode Magnitude
   %--------------------------------------------------------------
       % CASE 4: ROBUSTNESS ANALYSIS VIA S/T FREQUENCY RESPONSES
       %
       % PURPOSE:
       %   Evaluate control system robustness across operating points by analyzing
       %   sensitivity (S) and complementary sensitivity (T) Bode magnitude plots.
       %   Both ENDPOINTS and SWEEP datasets are supported.
       %
       % THEORETICAL BACKGROUND:
       %   For a closed-loop system with plant G(s) and controller C(s):
       %   • Sensitivity: S(s) = 1/(1 + G(s)C(s))
       %     - Measures disturbance rejection and tracking error
       %     - |S(jw)| << 1 at low frequencies → good disturbance rejection
       %     - Peak Ms = max|S(jw)| indicates robustness to model uncertainty
       %
       %   • Complementary Sensitivity: T(s) = G(s)C(s)/(1 + G(s)C(s))
       %     - Measures reference tracking and noise sensitivity
       %     - |T(jw)| ≈ 1 at low frequencies → good reference tracking
       %     - |T(jw)| << 1 at high frequencies → good noise rejection
       %     - Peak Mt = max|T(jw)| indicates robustness to high-freq uncertainty
       %
       %   Important relation: S(s) + T(s) = 1 (algebraic constraint)
       %
       % ROBUSTNESS METRICS CALCULATED:
       %   • Ms (dB): Maximum sensitivity peak
       %   • ws (rad/s): Frequency at which Ms occurs
       %   • Mt (dB): Maximum complementary sensitivity peak
       %   • wt (rad/s): Frequency at which Mt occurs
       %
       % INTERPRETATION GUIDELINES:
       %   SENSITIVITY PEAK (Ms):
       %   • Ms < 2 dB (1.26 linear): Excellent robustness, conservative tuning
       %   • 2 dB < Ms < 6 dB: Good robustness, balanced performance/stability
       %   • Ms > 6 dB (2.0 linear): Poor robustness, aggressive tuning
       %   • High Ms → sensitive to model uncertainty and parameter variations
       %
       %   COMPLEMENTARY SENSITIVITY PEAK (Mt):
       %   • Mt < 2 dB: Excellent high-frequency robustness
       %   • 2 dB < Mt < 6 dB: Good noise rejection
       %   • Mt > 6 dB: Poor high-frequency robustness, noise amplification
       %
       %   FREQUENCY LOCATIONS (ws, wt):
       %   • ws near control bandwidth → critical operating region
       %   • wt at high frequency → potential resonance issues
       %   • Large ws/wt → aggressive control, fast response but reduced margins
       %
       % FIGURE OUTPUT:
       %   3×3 subplot grid (7 control loops):
       %   1. VSMPd (Virtual Synchronous Machine - Active Power)
       %   2. VSMQd (Virtual Synchronous Machine - Reactive Power)
       %   3. RSCd  (Rotor Side Converter - d-axis current)
       %   4. RSCq  (Rotor Side Converter - q-axis current)
       %   5. VDC   (DC-link voltage)
       %   6. GSCd  (Grid Side Converter - d-axis current)
       %   7. GSCq  (Grid Side Converter - q-axis current)
       %
       %   Each subplot shows S and T Bode magnitude for all operating points.
       %
       % CONSOLE OUTPUT:
       %   Tables for each control loop containing:
       %   • Operating point parameters (Vpcc, Pdfig, SCRgrid, SCRdfig)
       %   • Ms, ws: Sensitivity peak and frequency
       %   • Mt, wt: Complementary sensitivity peak and frequency
       %
       % DESIGN IMPLICATIONS:
       %   • High Ms/Mt → reduce controller gains or increase filter time constants
       %   • Low Ms/Mt → can increase gains for faster response
       %   • Ms and Mt cannot both be small (waterbed effect)
       %   • Trade-off: Low Ms (disturbance rejection) vs Low Mt (noise rejection)
       %--------------------------------------------------------------

        fprintf('\n')
        fprintf('=========================================================================\n')
        fprintf('  CASE 4: SENSITIVITY/COMPLEMENTARY SENSITIVITY ROBUSTNESS ANALYSIS\n')
        fprintf('=========================================================================\n')
        fprintf('Analyzing robustness metrics for %d operating point(s)\n', numOP)
        fprintf('Control loops: 7 (VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq)\n')
        fprintf('-------------------------------------------------------------------------\n')

        % Define frequency ranges for each control loop (log scale: [min, max])
        % Optimized for each loop's bandwidth characteristics
        logw = [-1 2.25 ;   % VSMPd: 0.1 to 178 rad/s
                -1 2.25 ;   % VSMQd: 0.1 to 178 rad/s
                2 4 ;       % RSCd: 100 to 10000 rad/s
                2 4 ;       % RSCq: 100 to 10000 rad/s
                0 3 ;       % VDC: 1 to 1000 rad/s
                2 4 ;       % GSCd: 100 to 10000 rad/s
                2 4];       % GSCq: 100 to 10000 rad/s

        % Initial guesses for peak search optimization (rad/s)
        % EXACT VALUES from PLOT_LIN_MODEL.m case 8
        ws_ini = [1 1 10 10 10 100 100];  % Sensitivity peak initial guess
        wt_ini = [1 1 10 10 10 100 100];  % Complementary sensitivity peak guess
        % Analyze DFIGs 1 and 3 (representative of different SCR transformers)
        hDFIG = [1 3];
        SCRdfig = MODEL.DFIG.PARAM.SCR_transformer(hDFIG);

        % Preallocate robustness metrics
        % Rows: operating points × DFIGs, Columns: control loops
        ws = NaN(length(hDFIG)*numOP, nCONTROL);  % Frequency at Ms (rad/s)
        Ms = NaN(length(hDFIG)*numOP, nCONTROL);  % Max sensitivity peak (dB)
        wt = NaN(length(hDFIG)*numOP, nCONTROL);  % Frequency at Mt (rad/s)
        Mt = NaN(length(hDFIG)*numOP, nCONTROL);  % Max complementary sens peak (dB)

        % Extend operating point set with DFIG-specific SCR values
        OPsetExt = repmat(OPset, 2, 1);
        OPsetExt.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];

        % Cell array to store results for each control loop
        OPsetCell = cell(1, nCONTROL);

        % Create figure with paper-quality formatting
        figure(1)

        % Generate grayscale color gradient for multiple operating points
        totalCurves = length(hDFIG) * numOP;
        grayColors = linspace(0.2, 0.6, totalCurves);  % Dark gray to medium gray

        % Loop through all 7 control loops
        for nn = 1:nCONTROL
            subplot(3, 3, nn)

            % Generate frequency vector for this control loop (EXACT from PLOT_LIN_MODEL case 8)
            w = logspace(logw(nn,1), logw(nn,2), 5000);

            curveIdx = 0;
            % Loop through selected DFIGs
            for ii = 1:length(hDFIG)
                % Loop through operating points
                for jj = 1:numOP
                    curveIdx = curveIdx + 1;

                    % Extract state-space model for this operating point
                    ssModel = LIN_MODEL{jj}.ssModel;
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;

                    % Indices for complementary sensitivity (T) and sensitivity (S)
                    % EXACT from PLOT_LIN_MODEL case 8
                    indT = nCONTROL*(hDFIG(ii)-1) + nn;  % Complementary sensitivity index
                    indS = nCONTROL*nDFIG + nCONTROL*(hDFIG(ii)-1) + nn;  % Sensitivity index

                    % Build T and S state-space models
                    Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));
                    Sss = ss(matA, matB(:,indT), matC(indS,:), matD(indS,indT));

                    % Compute frequency response manually (EXACT from PLOT_LIN_MODEL case 8)
                    [magS, ~] = bode(Sss, w);
                    [magT, ~] = bode(Tss, w);
                    magS_dB = 20*log10(squeeze(magS));
                    magT_dB = 20*log10(squeeze(magT));

                    % Plot with grayscale colors and different line styles for S and T
                    grayLevel = grayColors(curveIdx);
                    semilogx(w, magS_dB, '-', 'LineWidth', 1.5, 'Color', [grayLevel grayLevel grayLevel]);  % S: solid
                    hold on
                    semilogx(w, magT_dB, '--', 'LineWidth', 1.5, 'Color', [grayLevel grayLevel grayLevel]);  % T: dashed

                    % Calculate robustness metrics using optimization
                    % Sensitivity peak (Ms) and frequency (ws)
                    ws(numOP*(ii-1)+jj, nn) = fminsearch(@(w) -abs(freqresp(Sss,w)), ws_ini(nn));
                    Ms(numOP*(ii-1)+jj, nn) = 20*log10(abs(freqresp(Sss, ws(numOP*(ii-1)+jj,nn))));

                    % Complementary sensitivity peak (Mt) and frequency (wt)
                    wt(numOP*(ii-1)+jj, nn) = fminsearch(@(w) -abs(freqresp(Tss,w)), wt_ini(nn));
                    Mt(numOP*(ii-1)+jj, nn) = 20*log10(abs(freqresp(Tss, wt(numOP*(ii-1)+jj,nn))));
                end
            end

            hold off

            % Format axes - WHITE BACKGROUND, BLACK TEXT (EXACT from PLOT_LIN_MODEL case 8)
            ax = gca;
            set(ax, 'Color', 'white');
            set(ax, 'XColor', [0 0 0], 'YColor', [0 0 0]);
            set(ax, 'FontSize', 11, 'FontName', 'Times New Roman');
            set(ax, 'TickLabelInterpreter', 'latex');

            % Format labels (EXACT from PLOT_LIN_MODEL case 8)
            xlabel('Frequency (rad/s)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])
            ylabel('Magnitude (dB)', 'Interpreter', 'latex', 'FontSize', 11, 'Color', [0 0 0])

            % Format title (EXACT from PLOT_LIN_MODEL case 8)
            title(ControlLabel{nn}, 'Interpreter', 'latex', ...
                  'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0])

            % Format legend (only first subplot)
            if nn == 1
                leg = legend('$|S(j\omega)|$', '$|T(j\omega)|$', 'Location', 'best');
                set(leg, 'Interpreter', 'latex', 'FontSize', 9, 'Color', 'white', ...
                         'EdgeColor', 'black', 'TextColor', 'black')
            end

            % Set axis limits (after all plotting is done)
            % X-axis: full frequency range for this control loop
            xlim([10^logw(nn,1), 10^logw(nn,2)]);

            % Y-axis limits (use -15 to 10 for all, as this is for multiple OPs overlay)
            ylim([-15 10]);

            % Grid (EXACT from PLOT_LIN_MODEL case 8)
            grid on
            set(ax, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.3, 'GridLineStyle', ':')
            set(ax, 'GridLineWidth', 0.5);
            box on

            % Store metrics in cell array for console output
            OPsetCell{nn} = OPsetExt;
            OPsetCell{nn}.Ms = Ms(:,nn);
            OPsetCell{nn}.ws = ws(:,nn);
            OPsetCell{nn}.Mt = Mt(:,nn);
            OPsetCell{nn}.wt = wt(:,nn);
        end

        % Apply publication formatting to the figure (EXACT from PLOT_LIN_MODEL case 8)
        format_figure_for_publication(figure(1))

        % Console output with robustness metrics
        fprintf('=========================================================================\n')
        fprintf('  ROBUSTNESS METRICS (Ms, Mt) FOR EACH CONTROL LOOP\n')
        fprintf('=========================================================================\n')
        fprintf('INTERPRETATION GUIDELINES:\n')
        fprintf('  • Ms (Sensitivity Peak):\n')
        fprintf('    - Ms < 2 dB: Excellent robustness (conservative tuning)\n')
        fprintf('    - 2-6 dB: Good robustness (balanced performance/stability)\n')
        fprintf('    - Ms > 6 dB: Poor robustness (aggressive tuning)\n')
        fprintf('  • Mt (Complementary Sensitivity Peak):\n')
        fprintf('    - Mt < 2 dB: Excellent high-frequency robustness\n')
        fprintf('    - 2-6 dB: Good noise rejection\n')
        fprintf('    - Mt > 6 dB: Poor noise rejection, potential resonance\n')
        fprintf('  • High ws/wt: Aggressive control (fast response, reduced margins)\n')
        fprintf('  • Trade-off: Cannot minimize both Ms and Mt simultaneously\n')
        fprintf('-------------------------------------------------------------------------\n')

        for nn = 1:nCONTROL
            fprintf('\n--- %s CONTROL LOOP ---\n', ControlLabel{nn})
            disp(OPsetCell{nn})
        end

        fprintf('=========================================================================\n')
   %======================================================================
   % CASE 5: Closed-Loop Frequency Response (Operating Point Sweep)
   %======================================================================
   % PURPOSE:
   %   Visualize closed-loop complementary sensitivity |T(jω)| across multiple
   %   operating points to assess bandwidth, resonance peaks, and robustness
   %   variation throughout the operating envelope. Extends single-OP analysis
   %   (PLOT_LIN_MODEL case 9) to parametric sweeps.
   %
   % ANALYSIS TYPE:
   %   Compatible with both ENDPOINTS (8 OPs) and SWEEP (225 OPs)
   %
   % THEORETICAL BACKGROUND:
   %   Complementary sensitivity function: T(s) = y/r = G(s)C(s)/(1 + G(s)C(s))
   %   • |T(jω)| ≈ 1 at low frequencies → good reference tracking
   %   • |T(jω)| << 1 at high frequencies → noise rejection
   %   • Resonance peak Mr = max|T(jω)| indicates overshoot tendency
   %   • Resonance frequency ωr indicates closed-loop bandwidth
   %
   % KEY METRICS COMPUTED:
   %   • Mr [dB]: Resonance peak magnitude (robustness indicator)
   %   • ωr [rad/s]: Resonance frequency (bandwidth indicator)
   %
   % ROBUSTNESS INTERPRETATION:
   %   • Mr < 1.5 dB (1.19 linear) → Excellent robustness (recommended)
   %   • 1.5 < Mr < 3 dB → Good robustness (acceptable)
   %   • 3 < Mr < 6 dB → Moderate robustness (consider redesign)
   %   • Mr > 6 dB (2.0 linear) → Poor robustness (redesign required)
   %
   % DFIG CONFIGURATIONS:
   %   • DFIG #1: SCR transformer = 10 (strong grid connection)
   %   • DFIG #3: SCR transformer = 5 (weak grid connection)
   %
   % CONTROL LOOPS ANALYZED:
   %   1. VSMP: Virtual Synchronous Machine active power (slow dynamics)
   %   2. VSMQ: Virtual Synchronous Machine reactive power (slow dynamics)
   %   3. RSCd: Rotor-side converter d-axis current (fast dynamics)
   %   4. RSCq: Rotor-side converter q-axis current (fast dynamics)
   %   5. VDC:  DC-link voltage control (medium dynamics)
   %   6. GSCd: Grid-side converter d-axis current (fast dynamics)
   %   7. GSCq: Grid-side converter q-axis current (fast dynamics)
   %
   % OUTPUT:
   %   • Figure 1: 7 subplots (3×3 grid) with Bode magnitude overlays
   %   • Console: Tables with Mr and ωr for all OPs, DFIGs, and controllers
   %
   % USAGE NOTES:
   %   - Frequency ranges optimized per controller (inherited from case 9)
   %   - Y-axis limits: [-15, 10] dB (standard), [-35, 15] dB (RSCd/RSCq)
   %   - Publication-quality formatting applied (Times New Roman, LaTeX)
   %----------------------------------------------------------------------

    case 5 % Closed-loop frequency response (Bode magnitude)
   %----------------------------------------------------------------------
        %==================================================================
        % CONFIGURATION SECTION - Easy modification of plot parameters
        %==================================================================

        %------------------------------------------------------------------
        % Frequency ranges [low, high] for each controller (log10 scale)
        % Inherited from PLOT_LIN_MODEL case 9 for consistency
        %------------------------------------------------------------------
        logw = [-1   2.25;   % VSMP: 0.1 - 178 rad/s (slow power dynamics)
                -1   1.25;   % VSMQ: 0.1 - 18 rad/s (slow voltage dynamics)
                 1   4;      % RSCd: 10 - 10000 rad/s (rotor current control)
                 1   4;      % RSCq: 10 - 10000 rad/s (rotor current control)
                 0   2.477;  % VDC: 1 - 300 rad/s (DC-link voltage)
                 1   4;      % GSCd: 10 - 10000 rad/s (grid-side current control)
                 1   4];     % GSCq: 10 - 10000 rad/s (grid-side current control)

        %------------------------------------------------------------------
        % Y-axis limits [min, max] in dB for each controller
        % Row order: VSMP, VSMQ, RSCd, RSCq, VDC, GSCd, GSCq
        %
        % OPTIONS:
        %   1. Fixed limits: [min max] for each controller
        %   2. Auto scaling: Use NaN values → [NaN NaN] for automatic limits
        %   3. Mixed: Combine fixed and auto, e.g., [-15 NaN] fixes min only
        %------------------------------------------------------------------
        ylim_dB = [-15  10;   % VSMP: standard range
                   -15  10;   % VSMQ: standard range
                   -35  15;   % RSCd: extended range (fast current dynamics)
                   -35  15;   % RSCq: extended range (fast current dynamics)
                   -15  10;   % VDC:  standard range
                   -15  10;   % GSCd: standard range
                   -15  10];  % GSCq: standard range

        % EXAMPLES of alternative configurations:
        % ylim_dB = [NaN NaN; NaN NaN; NaN NaN; NaN NaN; NaN NaN; NaN NaN; NaN NaN];  % All auto
        % ylim_dB = [-20 15; -20 15; -40 20; -40 20; -20 15; -15 10; -15 10];  % Custom ranges

        %------------------------------------------------------------------
        % Color scheme for publication (grayscale palette)
        % Multiple operating points plotted per subplot - uses grayscale gradient
        %------------------------------------------------------------------
        % Grayscale gradient: from black (0) to light gray (0.7)
        % Automatically distributed across numOP operating points
        % Format: [R G B] where R=G=B for grayscale
        %------------------------------------------------------------------

        %------------------------------------------------------------------
        % Initial guesses for resonance frequency search [rad/s]
        %------------------------------------------------------------------
        wr_ini = [1 1 100 100 10 100 100];

        % DFIG indices to compare: 1 (SCR=10) and 3 (SCR=5)
        hDFIG = [1 3];
        SCRdfig = MODEL.DFIG.PARAM.SCR_transformer(hDFIG);

        %------------------------------------------------------------------
        % Step 2: Initialize result arrays [nDFIG×numOP × nControllers]
        %------------------------------------------------------------------
        wr = NaN(length(hDFIG)*numOP, nCONTROL);  % Resonance frequency [rad/s]
        Mr = NaN(length(hDFIG)*numOP, nCONTROL);  % Resonance peak [dB]

        % Extend operating point table to include DFIG configurations
        OPsetExt = repmat(OPset, 2, 1);
        OPsetExt.SCRdfig = [SCRdfig(1)*ones(numOP,1); SCRdfig(2)*ones(numOP,1)];

        % Cell array to store results per controller
        OPsetCell = cell(1, nCONTROL);

        %------------------------------------------------------------------
        % Step 3: Main plotting loop - generate 3×3 subplot grid
        %------------------------------------------------------------------
        figure(1)

        % Generate grayscale color map for all curves
        totalCurves = length(hDFIG) * numOP;
        grayColors = linspace(0, 0.7, totalCurves);  % Black (0) to light gray (0.7)

        for nn = 1:nCONTROL
            % Create subplot for this controller
            subplot(3, 3, nn)

            % Frequency vector (logarithmic spacing, 1000 points for smooth curves)
            w = logspace(logw(nn,1), logw(nn,2), 1000);

            % Initialize curve counter for color indexing
            curveIdx = 0;

            % Loop over DFIG configurations and operating points
            for ii = 1:length(hDFIG)
                for jj = 1:numOP
                    curveIdx = curveIdx + 1;

                    % Extract state-space model for this operating point
                    ssModel = LIN_MODEL{jj}.ssModel;
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;

                    % Construct closed-loop complementary sensitivity T(s)
                    indT = nCONTROL*(hDFIG(ii)-1) + nn;
                    Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));

                    % Compute frequency response manually for full control
                    [mag, ~] = bode(Tss, w);
                    mag_dB = 20*log10(squeeze(mag));

                    % Plot with grayscale color and publication-quality formatting
                    grayLevel = grayColors(curveIdx);
                    semilogx(w, mag_dB, 'LineWidth', 1.5, 'Color', [grayLevel grayLevel grayLevel]);
                    hold on

                    % Find resonance peak and frequency
                    idx = numOP*(ii-1) + jj;
                    wr(idx,nn) = fminsearch(@(w) -abs(freqresp(Tss,w)), wr_ini(nn));
                    Mr(idx,nn) = 20*log10(abs(freqresp(Tss, wr(idx,nn))));
                end
            end
            hold off

            %--------------------------------------------------------------
            % Step 4: Format subplot - axis limits only
            % (format_figure_for_publication will handle all other formatting)
            %--------------------------------------------------------------
            % Set Y-axis limits from configuration array
            if all(isnan(ylim_dB(nn, :)))
                % Auto scaling: do nothing (MATLAB default)
                ylim('auto')
            elseif any(isnan(ylim_dB(nn, :)))
                % Mixed: set only non-NaN values
                current_ylim = ylim;
                new_ylim = ylim_dB(nn, :);
                new_ylim(isnan(new_ylim)) = current_ylim(isnan(new_ylim));
                ylim(new_ylim)
            else
                % Fixed limits: set both min and max
                ylim(ylim_dB(nn, :))
            end

            % Set X-axis limit for VDC (limited to 300 rad/s)
            if nn == 5  % VDC
                xlim([1 300])
            end

            % Basic formatting (will be overridden by format_figure_for_publication)
            xlabel('Frequency (rad/s)', 'Interpreter', 'latex');
            ylabel('Magnitude (dB)', 'Interpreter', 'latex');
            title(ControlLabel{nn}, 'Interpreter', 'latex');
            grid on

            %--------------------------------------------------------------
            % Step 5: Store results for this controller
            %--------------------------------------------------------------
            OPsetCell{nn} = OPsetExt;
            OPsetCell{nn}.Mr = Mr(:,nn);
            OPsetCell{nn}.wr = wr(:,nn);
        end

        %------------------------------------------------------------------
        % Apply publication formatting to entire figure
        %------------------------------------------------------------------
        format_figure_for_publication(figure(1))

        %------------------------------------------------------------------
        % Step 6: Display computed metrics with professional formatting
        %------------------------------------------------------------------
        fprintf('\n');
        fprintf('╔════════════════════════════════════════════════════════════════╗\n');
        fprintf('║  CASE 5: Closed-Loop Frequency Response (Op. Point Sweep)    ║\n');
        fprintf('╠════════════════════════════════════════════════════════════════╣\n');
        fprintf('║  Operating Points: %-3d  |  DFIGs: 1 (SCR=10), 3 (SCR=5)     ║\n', numOP);
        fprintf('╚════════════════════════════════════════════════════════════════╝\n');
        fprintf('\n');

        for nn = 1:nCONTROL
            fprintf('--- %d. %s CONTROL LOOP ---\n', nn, ControlLabel{nn});
            disp(OPsetCell{nn});
            fprintf('\n');
        end

        fprintf('Robustness Interpretation (Resonance Peak Mr):\n');
        fprintf('  • Mr < 1.5 dB  → Excellent robustness (recommended)\n');
        fprintf('  • Mr < 3 dB    → Good robustness (acceptable)\n');
        fprintf('  • Mr < 6 dB    → Moderate robustness (review tuning)\n');
        fprintf('  • Mr > 6 dB    → Poor robustness (redesign required)\n');
        fprintf('\n');
        fprintf('Bandwidth Interpretation (Resonance Frequency ωr):\n');
        fprintf('  • Higher ωr → Wider bandwidth (faster tracking)\n');
        fprintf('  • Lower ωr  → Narrower bandwidth (slower, more filtered)\n');
        fprintf('=========================================================================\n')
        
   %======================================================================
   % CASE 6: Load Disturbance Response (Operating Point Sweep)
   %======================================================================
   % PURPOSE:
   %   Evaluate DFIG system response to active and reactive load step
   %   disturbances across multiple operating points. Assesses grid frequency
   %   and PCC voltage stability under sudden load changes throughout the
   %   operating envelope.
   %
   % ANALYSIS TYPE:
   %   Compatible with both ENDPOINTS (8 OPs) and SWEEP (225 OPs)
   %
   % THEORETICAL BACKGROUND:
   %   Disturbance rejection capability evaluated through:
   %   • Active load step ΔP_load → Frequency deviation Δf(t)
   %   • Reactive load step ΔQ_load → PCC voltage deviation ΔV_pcc(t)
   %   • ROCOF: Rate of Change of Frequency [pu/s]
   %   • ROCOV: Rate of Change of Voltage [pu/s]
   %   • Nadir: Maximum frequency/voltage deviation [pu]
   %
   % KEY METRICS COMPUTED:
   %   • ROCOF [pu/s]: df/dt at half steady-state (grid stability indicator)
   %   • ROCOV [pu/s]: dV/dt at half steady-state (voltage stability)
   %   • nadir_f [pu]: Maximum frequency deviation (grid code compliance)
   %   • nadir_V [pu]: Maximum voltage deviation (power quality)
   %
   % GRID CODE REQUIREMENTS (typical):
   %   • ROCOF < 0.5-1.0 Hz/s (0.01-0.02 pu/s @ 50 Hz)
   %   • Frequency nadir > 49.2 Hz (0.984 pu @ 50 Hz)
   %   • Voltage nadir > 0.85 pu during disturbance
   %
   % INTERPRETATION:
   %   • Lower ROCOF/ROCOV → Better initial transient response
   %   • Lower nadir → Better disturbance rejection capability
   %   • Faster settling → Better damping and control performance
   %   • Cross-coupling effects: P→V and Q→f interactions
   %
   % OUTPUT:
   %   • Figure 1: 2×2 subplot grid
   %     - Top row: Active load disturbance (Δf and ΔV_pcc)
   %     - Bottom row: Reactive load disturbance (Δf and ΔV_pcc)
   %   • Console: Tables with ROCOF/ROCOV and nadir for all OPs
   %
   % USAGE NOTES:
   %   - Only stable operating points are plotted
   %   - Time vectors: 15s for frequency, 15s for voltage (finer resolution)
   %   - Publication-quality formatting applied
   %----------------------------------------------------------------------

    case 6 % Load disturbance response (Frequency and PCC voltage)
   %----------------------------------------------------------------------
        %==================================================================
        % CONFIGURATION SECTION - Easy modification of plot parameters
        %==================================================================

        %------------------------------------------------------------------
        % Time vectors for step response simulation
        %------------------------------------------------------------------
        t = {linspace(0, 15, 500);    % Active load: frequency response
             linspace(0, 15, 5000)};  % Reactive load: voltage response (finer resolution)

        %------------------------------------------------------------------
        % Y-axis limits [min, max] for each subplot (2×2 grid)
        % 4×2 matrix: One row per subplot [row, col] in subplot(2,2,...)
        %
        % Subplot layout:
        %   [1,1] = Active load   → Frequency    (subplot index 1)
        %   [1,2] = Active load   → Voltage      (subplot index 2)
        %   [2,1] = Reactive load → Frequency    (subplot index 3)
        %   [2,2] = Reactive load → Voltage      (subplot index 4)
        %
        % OPTIONS:
        %   1. Fixed limits: [min max] for each subplot
        %   2. Auto scaling: Use NaN values → [NaN NaN] for automatic limits
        %   3. Leave empty [] to use auto for ALL subplots
        %------------------------------------------------------------------
        ylim_range = [-0.004  0;    % Subplot 1: Active load   → Frequency
                      0  0.35;    % Subplot 2: Active load   → Voltage
                      0  0.003    % Subplot 3: Reactive load → Frequency
                      0  0.7];   % Subplot 4: Reactive load → Voltage

        % EXAMPLES of alternative configurations:
        % ylim_range = [];                              % All auto (legacy mode)
        % ylim_range = [NaN NaN; NaN NaN; NaN NaN; NaN NaN];  % All auto (explicit)
        % ylim_range = [-0.1 0.1; -0.05 0.05; -0.02 0.02; -0.08 0.08];  % Independent

        %------------------------------------------------------------------
        % Color scheme for publication (grayscale palette)
        % Multiple operating points plotted per subplot - uses grayscale gradient
        %------------------------------------------------------------------
        % Grayscale gradient: from black (0) to light gray (0.7)
        % Automatically distributed across numOP operating points
        % Format: [R G B] where R=G=B for grayscale
        %------------------------------------------------------------------

        %------------------------------------------------------------------
        % Output labels and subplot titles
        %------------------------------------------------------------------
        outLabel = {'Frequency (pu)', 'PCC voltage (pu)'};
        titleLabel = {'Active load step', 'Reactive load step'};

        %------------------------------------------------------------------
        % Step 2: Initialize metrics arrays [numOP × 2]
        %------------------------------------------------------------------
        % Rate of Change of Frequency/Voltage [pu/s]
        ROCOX = NaN(numOP, 2);  % [ROCOF, ROCOV] per operating point

        % Maximum frequency/voltage deviation [pu]
        nadir = NaN(numOP, 2);  % [nadir_f, nadir_V] per operating point

        %------------------------------------------------------------------
        % Step 3: Main plotting loop - 2×2 grid (load types × outputs)
        %------------------------------------------------------------------
        figure(1)

        % Generate grayscale color map for all curves
        grayColors = linspace(0, 0.7, numOP);  % Black (0) to light gray (0.7)

        % Loop over disturbance types: (1) Active load, (2) Reactive load
        for ii = 1:2
            % Loop over outputs: (1) Frequency, (2) PCC voltage
            for jj = 1:2
                % Create subplot: [row, col] = [disturbance type, output]
                subplot(2, 2, 2*(ii-1) + jj)

                % Loop over operating points
                for kk = 1:numOP
                    % Extract state-space model for this operating point
                    ssModel = LIN_MODEL{kk}.ssModel;
                    matA = ssModel.a;
                    matB = ssModel.b;
                    matC = ssModel.c;
                    matD = ssModel.d;

                    % Extract matrix indices
                    % Input: load disturbances (active or reactive)
                    indI = nCONTROL*nDFIG + 8 + ii;

                    % Output: frequency (1) or PCC voltage (2)
                    indO = 2*nCONTROL*nDFIG + jj;

                    % Build state-space transfer function: output/disturbance
                    Fss = ss(matA, matB(:,indI), matC(indO,:), matD(indO,indI));

                    % Compute step response
                    y = step(Fss, t{jj});

                    % Plot only stable operating points with grayscale colors
                    if LIN_MODEL{kk}.stability
                        grayLevel = grayColors(kk);
                        plot(t{jj}, y, 'LineWidth', 1.5, 'Color', [grayLevel grayLevel grayLevel])
                        hold on
                    end

                    %------------------------------------------------------
                    % Compute performance metrics
                    %------------------------------------------------------
                    % ROCOF: Active load → Frequency (ii==1, jj==1)
                    % ROCOV: Reactive load → Voltage (ii==2, jj==2)
                    if (ii==1 && jj==1) || (ii==2 && jj==2)
                        % Find half-rise time point for rate estimation
                        [~, ind] = min(abs(y - y(end)/2));

                        % Rate of change [pu/s]
                        ROCOX(kk, jj) = abs(y(ind) / t{jj}(ind));

                        % Maximum deviation (nadir) [pu]
                        nadir(kk, jj) = max(abs(y));
                    end
                end
                hold off

                %----------------------------------------------------------
                % Step 4: Format subplot - basic formatting
                % (format_figure_for_publication will handle fine details)
                %----------------------------------------------------------
                xlabel('Time (s)', 'Interpreter', 'latex');
                ylabel(outLabel{jj}, 'Interpreter', 'latex');
                title(titleLabel{ii}, 'Interpreter', 'latex');
                xlim([0 t{jj}(end)])

                % Set Y-axis limits from configuration
                subplot_idx = 2*(ii-1) + jj;  % Linear index: 1, 2, 3, 4
                if ~isempty(ylim_range)
                    if all(isnan(ylim_range(subplot_idx, :)))
                        % Auto scaling for this subplot
                        ylim('auto')
                    elseif any(isnan(ylim_range(subplot_idx, :)))
                        % Mixed: set only non-NaN values
                        current_ylim = ylim;
                        new_ylim = ylim_range(subplot_idx, :);
                        new_ylim(isnan(new_ylim)) = current_ylim(isnan(new_ylim));
                        ylim(new_ylim)
                    else
                        % Fixed limits for this subplot
                        ylim(ylim_range(subplot_idx, :))
                    end
                end

                grid on
            end
        end

        %------------------------------------------------------------------
        % Apply publication formatting to entire figure
        %------------------------------------------------------------------
        format_figure_for_publication(figure(1))

        %------------------------------------------------------------------
        % Step 5: Organize results and display metrics
        %------------------------------------------------------------------
        % Sort results by metric values (descending) to identify worst cases
        [sortedData, ind] = sort([ROCOX nadir], 'descend');

        % Create cell array with sorted operating point tables
        OPsetCell = cell(1, 4);

        % ROCOF (Active load → Frequency)
        OPsetCell{1} = OPset(ind(:,1), :);
        OPsetCell{1}.ROCOF = sortedData(:,1);

        % ROCOV (Reactive load → Voltage)
        OPsetCell{2} = OPset(ind(:,2), :);
        OPsetCell{2}.ROCOV = sortedData(:,2);

        % Frequency nadir (Active load)
        OPsetCell{3} = OPset(ind(:,3), :);
        OPsetCell{3}.nadir_f = sortedData(:,3);

        % Voltage nadir (Reactive load)
        OPsetCell{4} = OPset(ind(:,4), :);
        OPsetCell{4}.nadir_V = sortedData(:,4);

        %------------------------------------------------------------------
        % Step 6: Display computed metrics with professional formatting
        %------------------------------------------------------------------
        fprintf('\n');
        fprintf('╔════════════════════════════════════════════════════════════════╗\n');
        fprintf('║  CASE 6: Load Disturbance Response (Op. Point Sweep)         ║\n');
        fprintf('╠════════════════════════════════════════════════════════════════╣\n');
        fprintf('║  Operating Points: %-3d  |  Sorted by metric (worst first)   ║\n', numOP);
        fprintf('╚════════════════════════════════════════════════════════════════╝\n');
        fprintf('\n');

        fprintf('--- 1. ROCOF (Active load → Frequency) [pu/s] ---\n');
        disp(OPsetCell{1});
        fprintf('\n');

        fprintf('--- 2. ROCOV (Reactive load → Voltage) [pu/s] ---\n');
        disp(OPsetCell{2});
        fprintf('\n');

        fprintf('--- 3. Frequency Nadir (Active load) [pu] ---\n');
        disp(OPsetCell{3});
        fprintf('\n');

        fprintf('--- 4. Voltage Nadir (Reactive load) [pu] ---\n');
        disp(OPsetCell{4});
        fprintf('\n');

        fprintf('Performance Interpretation:\n');
        fprintf('  • Lower ROCOF/ROCOV  → Slower initial transient (better)\n');
        fprintf('  • Lower nadir        → Smaller maximum deviation (better)\n');
        fprintf('  • Fast settling      → Good damping and control response\n');
        fprintf('  • Cross-coupling     → Visible in off-diagonal responses (P→V, Q→f)\n');
        fprintf('\n');
        fprintf('Grid Code Reference (typical):\n');
        fprintf('  • ROCOF limit: 0.5-1.0 Hz/s (0.01-0.02 pu/s @ 50 Hz)\n');
        fprintf('  • Frequency nadir: > 49.2 Hz (0.984 pu @ 50 Hz)\n');
        fprintf('  • Voltage nadir: > 0.85 pu during disturbance\n');
        fprintf('=========================================================================\n')

   %======================================================================
   % CASES 7-14: Stability Heatmaps (2D Operating Envelope Maps)
   %======================================================================
   % PURPOSE:
   %   Generate 2D heatmaps visualizing stability metrics across the 3D
   %   operating envelope (Vpcc × Pdfig × SCRgrid). Each heatmap slices
   %   the 3D space at fixed SCR values, creating multiple 2D plots.
   %
   % ANALYSIS TYPE:
   %   SWEEP dataset REQUIRED (225 OPs typical): Full parametric sweep
   %   ENDPOINTS not recommended: Only 8 points insufficient for heatmaps
   %
   % HEATMAP STRUCTURE:
   %   - X-axis: PCC voltage [pu]
   %   - Y-axis: DFIG power [pu]
   %   - Color: Metric value (grayscale)
   %   - Subplots: One per SCR value (up to 16 subplots max)
   %
   % CASE DESCRIPTIONS:
   %   7.  Minimum damping ratio (eigenvalues 5 to end) [dimensionless]
   %       - Identifies poorly damped oscillatory modes
   %       - Lower values → Higher oscillation risk
   %
   %   8.  Natural frequency at minimum damping [rad/s]
   %       - Shows oscillation frequency of critical modes
   %       - Important for resonance avoidance
   %
   %   9.  Maximum real eigenvalue [rad/s]
   %       - Direct stability indicator
   %       - Positive values → Unstable regions (exponential growth)
   %
   %   10. Minimum damping ratio (eigenvalues 1 to 4) [dimensionless]
   %       - Focuses on fastest modes (current control loops)
   %       - High-frequency stability assessment
   %
   %   11. Minimum time constant [μs]
   %       - Identifies slowest (most critical) pole: τ = 1/|Re(λ)|
   %       - Large τ → slow pole close to instability (HIGH criticality)
   %       - Small τ → fast pole far from instability (LOW criticality)
   %
   %   12. Line angle [degrees]
   %       - Power transfer angle between DFIG and grid
   %       - Related to voltage stability limits
   %
   %   13. Mean wind speed [m/s]
   %       - Environmental operating conditions
   %       - High wind speed → high power → approach stability limits (HIGH criticality)
   %
   %   14. Mean rotor speed [pu]
   %       - DFIG operating mode characterization
   %       - High rotor speed → super-synchronous → high power → stability limits (HIGH criticality)
   %
   % COLORMAP:
   %   - Grayscale gradient (white → black) for publication quality
   %   - Global color scale based ONLY on stable operating points
   %   - Single colorbar shared by all subplots (right side of figure)
   %   - Unstable points shown with diagonal hatch pattern (excluded from scale)
   %   - Inherited from PLOT_LIN_MODEL case 4 correlation heatmaps
   %
   % OUTPUT:
   %   - Figure with multiple subplots (1-16 depending on SCR values)
   %   - Single global colorbar (positioned on right side)
   %   - Console table with all operating point data
   %
   % USAGE NOTES:
   %   - Requires consistent grid structure in OPset
   %   - Maximum 16 subplots (SCR values) supported
   %   - Automatic subplot layout calculation (1×N, 2×N, 3×3, 4×4)
   %----------------------------------------------------------------------

    case {7,8,9,10,11,12,13,14} % Stability heatmaps
   %----------------------------------------------------------------------
       %------------------------------------------------------------------
       % Step 1: Extract metric values based on figure type
       %------------------------------------------------------------------
       N = size(OPset,1);
       OPsetExt = OPset;
       pValues = NaN(N,1);

       if figureType==7
           pValueLabel = 'Min damping (eig 5 to end)';
           for nn = 1:N
               pValues(nn) = LIN_MODEL{nn}.minDamping(2);
           end
           OPsetExt.minDamping = pValues;
       elseif figureType==8
           pValueLabel = 'Wn in rad/s (min damping)';
           for nn = 1:N
               pValues(nn) = LIN_MODEL{nn}.naturalFreq(2);
           end
           OPsetExt.naturalFreq = pValues;
       elseif figureType==9
           pValueLabel = 'Max real eig';
           for nn = 1:N
               pValues(nn) = LIN_MODEL{nn}.maxRealEig;
           end
           OPsetExt.naturalFreq = pValues;
       elseif figureType==10
           pValueLabel = 'Min damping (eig 1 to 4)';
           for nn = 1:N
               pValues(nn) = LIN_MODEL{nn}.minDamping(1);
           end
           OPsetExt.minDamping = pValues;
       elseif figureType==11
           pValueLabel = 'Min constant time (us)';
           for nn = 1:N
               pValues(nn) = 1e6*LIN_MODEL{nn}.minTimeConstant;
           end
           OPsetExt.minTimeConstant = pValues;
       elseif figureType==12
           pValueLabel = 'Line angle (deg)';
           for nn = 1:N
               pValues(nn) = LIN_MODEL{nn}.lineAngle;
           end
           OPsetExt.lineAngle = pValues;
       elseif figureType==13
           pValueLabel = 'Wind speed (m/s)';
           for nn = 1:N
               pValues(nn) = mean(LIN_MODEL{nn}.windSpeed);
           end
           OPsetExt.windSpeed = pValues;
       elseif figureType==14
           pValueLabel = 'Rotor speed (m/s)';
           for nn = 1:N
               pValues(nn) = mean(LIN_MODEL{nn}.rotorSpeed);
           end
           OPsetExt.rotorSpeed = pValues;
       elseif figureType==18
           pValueLabel = 'Stability';
           for nn = 1:N
               pValues(nn) = mean(LIN_MODEL{nn}.stability);
           end
           OPsetExt.stability = pValues;
       else
           disp('Figure type out of range')
           return
       end
       % Assigning axis values
       axisOrder = [1 2 3];
       xOPset = OPset(:,axisOrder(1));
       yOPset = OPset(:,axisOrder(2));
       zOPset = OPset(:,axisOrder(3));
       OPLabels = {'PCC voltage (pu)','DFIG Power (pu)','Grid SCR'};
       xValues = unique(xOPset);
       yValues = unique(yOPset);
       zValues = unique(zOPset);
       % Number of figures: number of grid SCR values
       Nfig = size(zValues,1);
       if Nfig>16
           disp('The number of grid SCR values should be less tnan 16')
           return
       end
       % Number of X values
       Nx = size(xValues,1);
       % Number of Y values
       Ny = size(yValues,1);
       % Subplot distribution
       if Nfig<=3
           sp1 = Nfig;
           sp2 = 1;
       elseif Nfig<=6
           sp1 = round((Nfig+0.5)/2);
           sp2 = 2;
       elseif Nfig<=9
           sp1 = 3;
           sp2 = 3;
       else
           sp1 = 4;
           sp2 = 4;
       end

       %------------------------------------------------------------------
       % Step 3: Create grayscale colormap for publication quality
       % Inherited from PLOT_LIN_MODEL case 4 (correlation heatmaps)
       %------------------------------------------------------------------
      % Colormap design: Dark colors for CRITICAL cases, light for SAFE cases
      %
      % Criticality interpretation by case:
      %   Case 7:  Min damping (eig 5-end)  → LOW is critical  → BLACK for low values
      %   Case 8:  Natural frequency        → HIGH is critical → WHITE for low, BLACK for high
      %   Case 9:  Max real eigenvalue      → HIGH is critical → WHITE for low, BLACK for high
      %   Case 10: Min damping (eig 1-4)    → LOW is critical  → BLACK for low values
      %   Case 11: Min time constant        → HIGH is critical → WHITE for low, BLACK for high
      %            (Large τ means slow pole close to instability)
      %   Case 12: Line angle               → HIGH is critical → WHITE for low, BLACK for high
      %   Case 13: Wind speed               → HIGH is critical → WHITE for low, BLACK for high
      %            (High wind → high power → approach stability limits)
      %   Case 14: Rotor speed              → HIGH is critical → WHITE for low, BLACK for high
      %            (High rotor speed → super-synchronous → high power → stability limits)
      %------------------------------------------------------------------
      kColorSteps = 101;
      myColorMap.map = zeros(kColorSteps, 3);

      % Determine colormap direction based on case criticality
      if ismember(figureType, [8, 9, 11, 12, 13, 14])
          % HIGH values are CRITICAL → Invert colormap (white→black)
          myColorMap.map(:,1) = linspace(1, 0, kColorSteps);  % Red: white→black
          myColorMap.map(:,2) = linspace(1, 0, kColorSteps);  % Green: white→black
          myColorMap.map(:,3) = linspace(1, 0, kColorSteps);  % Blue: white→black
      else
          % LOW values are CRITICAL or informative → Standard colormap (black→white)
          myColorMap.map(:,1) = linspace(0, 1, kColorSteps);  % Red: black→white
          myColorMap.map(:,2) = linspace(0, 1, kColorSteps);  % Green: black→white
          myColorMap.map(:,3) = linspace(0, 1, kColorSteps);  % Blue: black→white
      end

       %------------------------------------------------------------------
       % Step 4: Generate heatmap figure
       %------------------------------------------------------------------
       figure(1)
       % X-axis: tick labels
       xTickLabels = cell(1,Nx);
       ticks_x = 1:Nx;
       for ii = 1:Nx
           xTickLabels{ii} = num2str(xValues{ii,1});
       end
       yTickLabels = cell(1,Ny);
       ticks_y = 1:Ny;
       for ii = 1:Ny
           yTickLabels{ii} = num2str(yValues{ii,1});
       end
       %------------------------------------------------------------------
       % Step 5: Plot heatmap subplots with publication formatting
       %------------------------------------------------------------------
       % Calculate global color scale using ONLY STABLE operating points
       % This ensures unstable points (shown with hatch pattern) don't distort the scale
       stabilityFlags = false(N, 1);
       for nn = 1:N
           stabilityFlags(nn) = LIN_MODEL{nn}.stability == 1;
       end
       stableValues = pValues(stabilityFlags);

       if ~isempty(stableValues)
           minColorScale = min(stableValues);
           maxColorScale = max(stableValues);
       else
           % Fallback if no stable points (should not happen)
           minColorScale = min(pValues);
           maxColorScale = max(pValues);
       end

       for ii = 1:Nfig
           subplot(sp1, sp2, ii)

           % Extract data for this SCR value using explicit indexing
           % (same approach as case 18 to ensure correct mapping)
           dataPlot = nan(Ny, Nx);
           stabilityMatrix = nan(Ny, Nx);
           
           for row = 1:Ny
               for col = 1:Nx
                   % Find the exact operating point for this (Vpcc, Pdfig, SCR) combination
                   xVal = table2array(xValues(col,:));
                   yVal = table2array(yValues(row,:));
                   zVal = table2array(zValues(ii,:));
                   idx = find(table2array(xOPset) == xVal & ...
                              table2array(yOPset) == yVal & ...
                              table2array(zOPset) == zVal);
                   
                   if ~isempty(idx)
                       % Extract metric value
                       dataPlot(row, col) = pValues(idx(1));
                       % Extract stability flag
                       stabilityMatrix(row, col) = LIN_MODEL{idx(1)}.stability;
                   end
               end
           end
           
           
           % ========== DEBUG: Print detailed extraction info ==========
           fprintf('\n=== SUBPLOT %d: SCR = %.2f ===\n', ii, zVal);
           fprintf('Looking for: SCR=%.2f in zOPset\n', zVal);
           
           % Count matching points
           matchCount = sum(table2array(zOPset) == zVal);
           fprintf('Found %d points with SCR=%.2f\n', matchCount, zVal);
           
           % Print stability distribution for this SCR
           unstableCount = sum(stabilityMatrix(:) == 0);
           stableCount = sum(stabilityMatrix(:) == 1);
           nanCount = sum(isnan(stabilityMatrix(:)));
           fprintf('Stability: %d unstable, %d stable, %d NaN (total=%d)\n', ...
                   unstableCount, stableCount, nanCount, Ny*Nx);
           
           % Print first few indices found
           if ~isempty(idx)
               fprintf('Sample idx: %d (first match)\n', idx(1));
               fprintf('  Vpcc=%.3f, Pdfig=%.3f, SCR=%.3f\n', ...
                       table2array(xOPset(idx(1),:)), ...
                       table2array(yOPset(idx(1),:)), ...
                       table2array(zOPset(idx(1),:)));
           end
           % ==========================================================


           % DEBUG: Check dataPlot content
           fprintf('dataPlot stats:\n');
           fprintf('  NaN count: %d / %d\n', sum(isnan(dataPlot(:))), numel(dataPlot));
           fprintf('  Min (non-NaN): %.6f\n', min(dataPlot(:), [], 'omitnan'));
           fprintf('  Max (non-NaN): %.6f\n', max(dataPlot(:), [], 'omitnan'));
           fprintf('  Unique values: %d\n', length(unique(dataPlot(~isnan(dataPlot)))));
           % Create heatmap
           
           % DEBUG: Print stability flags for critical cells
           fprintf('\n=== STABILITY FLAGS FOR CRITICAL CELLS (SCR=%.2f) ===\n', zVal);
           
           % Check stability for Pdfig=1.2 row (should contain min/max values)
           for col = 1:Nx
               xVal_check = table2array(xValues(col,:));
               yVal_check = table2array(yValues(9,:));  % Assuming row 9 is Pdfig=1.2
               idx_check = find(table2array(xOPset) == xVal_check & ...
                               table2array(yOPset) == yVal_check & ...
                               table2array(zOPset) == zVal);
               if ~isempty(idx_check)
                   fprintf('Vpcc=%.3f, Pdfig=%.1f: minDamping=%.6f, stability=%d\n', ...
                           xVal_check, yVal_check, ...
                           LIN_MODEL{idx_check(1)}.minDamping(2), ...
                           LIN_MODEL{idx_check(1)}.stability);
               end
           end
           fprintf('=========================================\n');
           imagesc(dataPlot)
           colormap(gca, myColorMap.map)

           % Set axis ticks and labels with publication formatting
           xticks(ticks_x);
           xticklabels(xTickLabels);
           yticks(ticks_y);
           yticklabels(yTickLabels);

           % Format axes
           ax = gca;
           set(ax, 'FontName', 'Times New Roman', 'FontSize', 10, 'YDir', 'normal');
           set(ax, 'TickLabelInterpreter', 'latex');


          %------------------------------------------------------------------
          % Add hatch pattern for UNSTABLE operating points
          % Overlay diagonal lines (45°) on cells where stability == 0
          %------------------------------------------------------------------
          hold on
          
          
          % Draw simple diagonal hatch pattern for unstable cells (stability == 0)
          for row = 1:Ny
              for col = 1:Nx
                  if stabilityMatrix(row, col) == 0
                      % Cell boundaries in axis coordinates
                      x_cell = [col-0.5, col+0.5];
                      y_cell = [row-0.5, row+0.5];
                      
                      
                      % First, draw WHITE rectangle to override the heatmap color
                      rectangle('Position', [x_cell(1), y_cell(1), 1, 1], ...
                               'FaceColor', 'white', 'EdgeColor', 'none');
                      % Draw 3 diagonal lines at 45° spacing across the cell
                      for k = 0:2
                          % Starting point along bottom edge
                          t = k/3;
                          x_start = x_cell(1) + t;
                          y_start = y_cell(1);
                          
                          % Ending point along top or right edge
                          x_end = x_start + 1;
                          y_end = y_start + 1;
                          
                          % Clip to cell boundaries
                          if x_end > x_cell(2)
                              y_end = y_end - (x_end - x_cell(2));
                              x_end = x_cell(2);
                          end
                          if y_end > y_cell(2)
                              x_end = x_end - (y_end - y_cell(2));
                              y_end = y_cell(2);
                          end
                          
                          plot([x_start, x_end], [y_start, y_end], 'k-', ...
                               'LineWidth', 1.5, 'HandleVisibility', 'off');
                      end
                      
                      % Additional lines starting from left edge
                      for k = 1:2
                          t = k/3;
                          x_start = x_cell(1);
                          y_start = y_cell(1) + t;
                          
                          x_end = x_start + 1;
                          y_end = y_start + 1;
                          
                          if x_end > x_cell(2)
                              y_end = y_end - (x_end - x_cell(2));
                              x_end = x_cell(2);
                          end
                          if y_end > y_cell(2)
                              x_end = x_end - (y_end - y_cell(2));
                              y_end = y_cell(2);
                          end
                          
                          plot([x_start, x_end], [y_start, y_end], 'k-', ...
                               'LineWidth', 1.5, 'HandleVisibility', 'off');
                      end
                  end
              end
          end
          
          hold off

           % Labels with LaTeX interpreter
           ylabel(OPLabels{axisOrder(2)}, 'Interpreter', 'latex', ...
                  'FontSize', 11, 'Color', [0 0 0]);
           xlabel(OPLabels{axisOrder(1)}, 'Interpreter', 'latex', ...
                  'FontSize', 11, 'Color', [0 0 0]);

           % Title with LaTeX interpreter
           title([pValueLabel ': ' OPLabels{axisOrder(3)} ' = ' ...
                  num2str(zValues{ii,1})], 'Interpreter', 'latex', ...
                  'FontSize', 12, 'FontWeight', 'bold', 'Color', [0 0 0]);

           % Use GLOBAL color limits for consistent comparison across subplots
           clim([minColorScale, maxColorScale])

           % Grid off for clean heatmap appearance
           grid off
           axis tight
       end

       %------------------------------------------------------------------
       % Step 5b: Add single global colorbar for all subplots
       %------------------------------------------------------------------
       % Single colorbar positioned on the right side of the figure
       % This is more efficient and clearer than individual colorbars per subplot
       % since all subplots share the same global color scale
       cb = colorbar('Position', [0.92 0.15 0.02 0.7]);  % Right side, vertical
       set(cb, 'TickLabelInterpreter', 'latex');
       set(cb, 'FontName', 'Times New Roman');
       set(cb, 'FontSize', 11);
       set(cb, 'Color', [0 0 0]);  % Black text for colorbar


      %------------------------------------------------------------------
      % Step 6: Apply publication formatting (white background, IEEE standards)
      %------------------------------------------------------------------
      format_figure_for_publication(figure(1))


      %------------------------------------------------------------------
      % Add annotation explaining hatch pattern for unstable points
      %------------------------------------------------------------------
      % Create text annotation in figure coordinates (bottom-left corner)
      annotation(figure(1), 'textbox', [0.01, 0.01, 0.25, 0.03], ...
                 'String', '\textbf{Note:} Hatched cells indicate unstable operating points (stability flag = 0)', ...
                 'Interpreter', 'latex', ...
                 'FontSize', 9, ...
                 'FontName', 'Times New Roman', ...
                 'EdgeColor', 'none', ...
                 'BackgroundColor', 'white', ...
                 'FitBoxToText', 'on', ...
                 'Color', [0 0 0]);
       %------------------------------------------------------------------
       % Step 7: Display results table
       %------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASES 7-14: Stability Heatmap Analysis                       ║\n');
       fprintf('╠════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Case: %-2d  |  Metric: %-40s ║\n', figureType, pValueLabel);
       fprintf('║  Operating Points: %-3d  |  SCR values: %-2d                  ║\n', N, Nfig);
       fprintf('╚════════════════════════════════════════════════════════════════╝\n');
       fprintf('\n');
       fprintf('Metric Range:\n');
       fprintf('  Min: %.6f\n', minColorScale);
       fprintf('  Max: %.6f\n', maxColorScale);
       fprintf('\n');
       disp(OPsetExt)

   %======================================================================
   % CASES 15-17: Root Locus Analysis (Eigenvalue Migration)
   %======================================================================
   % PURPOSE:
   %   Visualize how system eigenvalues (poles) migrate as operating
   %   parameters vary. Shows natural frequency and damping evolution
   %   for complex conjugate poles, and real pole migration.
   %
   % ANALYSIS TYPE:
   %   SWEEP dataset SUPPORTED: Automatically selects representative cases
   %   For large datasets (e.g., 5×9×5 = 45 combinations), only first 4
   %   combinations plotted (most critical operating conditions)
   %   ENDPOINTS also supported (2×2×2 = 4 combinations max)
   %
   % CASE DESCRIPTIONS:
   %   15. Root locus vs. Vpcc (PCC voltage sweep)
   %       - Shows eigenvalue migration as grid voltage varies
   %       - Multiple figures for different (Pdfig, SCRgrid) combinations
   %       - Identifies voltage-dependent stability boundaries
   %
   %   16. Root locus vs. Pdfig (DFIG power sweep)
   %       - Eigenvalue trajectories as DFIG power increases
   %       - Critical for understanding power-dependent instabilities
   %       - Shows transition to unstable operation at high power
   %
   %   17. Root locus vs. SCRgrid (grid strength sweep)
   %       - Impact of grid stiffness on pole locations
   %       - Essential for weak grid operation assessment
   %       - Shows stabilizing effect of stronger grids
   %
   % PLOT STRUCTURE:
   %   Each case generates TWO figures with 2×2 subplot arrays:
   %   Figure 1: Complex conjugate poles
   %     - Dual y-axis: Natural frequency (wn) and damping ratio (ζ)
   %     - Unstable points (damping < 0) marked with red 'x' markers
   %     - Stable points shown with blue markers
   %   Figure 2: Real poles
   %     - Single y-axis: Maximum real eigenvalue
   %     - Unstable points (real pole > 0) marked with red 'x' markers
   %     - Stable points shown with blue markers
   %   Maximum 4 subplots per figure for publication quality
   %
   % OUTPUT:
   %   - Two figures per case, each with 2×2 grid layout
   %   - Publication-quality formatting (LaTeX, Times New Roman, white background)
   %   - Dual y-axis plots for complex poles (frequency + damping)
   %   - Single axis plots for real poles
   %   - Visual indicators for unstable operating points in both figures
   %   - Console table with operating point data
   %
   % UNSTABLE POINT MARKING:
   %   Figure 1 (Complex poles):
   %     - Unstable when damping < 0 → red 'x' markers
   %     - Stable points → blue circles and stars
   %   Figure 2 (Real poles):
   %     - Unstable when real pole > 0 → red 'x' markers
   %     - Stable points → blue stars
   %   Legend automatically adapts based on stability state
   %   This provides immediate visual feedback on stability boundaries
   %
   % USAGE NOTES:
   %   - SWEEP datasets: Automatically limits to first 4 combinations (most critical)
   %   - Warning displayed when combinations > 4
   %   - Each subplot shows eigenvalue trajectory for one (param1, param2) pair
   %   - Both complex and real pole plots show stability transitions clearly
   %   - For comprehensive analysis of all cases, use Cases 7-14 (Heatmaps)
   %
   % USAGE EXAMPLES:
   %   PLOT_LIN_MODEL_ARRAY('20251104_061432_ENDPOINTS_FRD_4DFIG', 15)  % 4 combinations
   %   PLOT_LIN_MODEL_ARRAY('20251104_061826_SWEEP_FRD_4DFIG', 15)      % 45→4 combinations (limited)
   %----------------------------------------------------------------------

    case {15,16,17} % Root locus analysis
   %----------------------------------------------------------------------
       %------------------------------------------------------------------
       % Step 1: Determine sweep variable and subplot layout
       %------------------------------------------------------------------
       % Determine sweep parameter and indices based on case
       if figureType==15 % Case 15: Power sweep at fixed SCR=1
           % Only case 15 uses this shared structure
           ind_z = 1;        % Sweep variable: Vpcc (column 1 of OPset)
           ind_xy = [2 3];   % Fixed variables: [Pdfig, SCRgrid]
           paramName = 'V_{pcc}';
           paramUnit = 'pu';

           %------------------------------------------------------------------
           % Step 2: Extract eigenvalue data for all operating points (CASE 15 ONLY)
           %------------------------------------------------------------------
           N = size(OPset,1);  % Total number of operating points

           % Get unique values of sweep parameter
           z = table2array(unique(OPset(:,ind_z)));
       Nz = length(z);

       % Pre-allocate arrays for eigenvalue data
       ind_array = NaN(round(N/Nz),Nz);      % Operating point indices
       xy_cell = cell(round(N/Nz),1);         % Fixed parameter pairs
       wn_array = NaN(round(N/Nz),Nz);        % Natural frequencies [rad/s]
       seta_array = NaN(round(N/Nz),Nz);      % Damping ratios [dimensionless]
       realPole_array = NaN(round(N/Nz),Nz);  % Real poles [rad/s]

       % Extract data loop: organize by sweep parameter value
       for jj = 1:Nz
           % Find indices for current sweep parameter value
           ind_array(:,jj) = find(table2array(OPset(:,ind_z)==z(jj)));

           for ii = 1:round(N/Nz)
               % Store fixed parameter values for subplot title
               xy_cell{ii,jj} = table2array([OPset(ind_array(ii,jj),ind_xy(1)) ...
                                             OPset(ind_array(ii,jj),ind_xy(2))]);

               % Extract eigenvalue metrics (using position 2: eigenvalues 5 to end)
               wn_array(ii,jj) = LIN_MODEL{ind_array(ii,jj)}.naturalFreq(2);
               seta_array(ii,jj) = LIN_MODEL{ind_array(ii,jj)}.minDamping(2);
               realPole_array(ii,jj) = LIN_MODEL{ind_array(ii,jj)}.maxRealEig;
           end
       end

       %------------------------------------------------------------------
       % Step 3: Calculate global axis limits for consistent scaling
       %------------------------------------------------------------------
       wn_max = max(wn_array(:));
       wn_min = min(wn_array(:));
       seta_max = max(seta_array(:));
       seta_min = min(seta_array(:));

       % Real pole limits (only stable points: realPole ≤ 0)
       % Mask unstable points with large penalty to exclude from min/max
       realPole_max = max(realPole_array(:).*(realPole_array(:)<=0) - ...
                          1e6*(realPole_array(:)>0));
       realPole_min = min(realPole_array(:).*(realPole_array(:)<=0) + ...
                          1e6*(realPole_array(:)>0));

       %------------------------------------------------------------------
       % Step 3b: Limit subplots for publication quality (2×2 grid)
       %------------------------------------------------------------------
       num_combinations = round(N/Nz);  % Number of (param1, param2) pairs
       max_subplots = 4;  % Maximum per figure for publication (2×2 grid)

       if num_combinations > max_subplots
           fprintf('\n');
           fprintf('╔═══════════════════════════════════════════════════════════════════╗\n');
           fprintf('║              ⚠️  PUBLICATION MODE: LIMITED SUBPLOTS ⚠️             ║\n');
           fprintf('╠═══════════════════════════════════════════════════════════════════╣\n');
           fprintf('║  Available combinations: %d                                       ║\n', num_combinations);
           fprintf('║  Publication limit: %d subplots (2×2 grid)                       ║\n', max_subplots);
           fprintf('║                                                                   ║\n');
           fprintf('║  Only the FIRST %d most critical cases will be plotted           ║\n', max_subplots);
           fprintf('║  (lowest Vpcc and Pdfig, lowest SCR - worst stability)          ║\n');
           fprintf('║                                                                   ║\n');
           fprintf('║  RATIONALE:                                                       ║\n');
           fprintf('║  • Publication-quality figures require clear, readable subplots  ║\n');
           fprintf('║  • 2×2 grid maintains adequate subplot size and font legibility  ║\n');
           fprintf('║  • First combinations represent most critical conditions         ║\n');
           fprintf('║                                                                   ║\n');
           fprintf('║  TIP: For comprehensive analysis, use Cases 7-14 (Heatmaps)     ║\n');
           fprintf('╚═══════════════════════════════════════════════════════════════════╝\n');
           fprintf('\n');

           % Limit to first max_subplots combinations
           num_combinations = max_subplots;
       end

           %------------------------------------------------------------------
           % Figure 1: Complex poles vs. Power for SCR=1 (2×2 grid, one subplot per voltage)
           %------------------------------------------------------------------
           figure(1)

           % Find all points with SCR=1 (most critical grid strength)
           SCR_target = 1.0;
           Vpcc_values_SCR1 = [];
           Pdfig_values_SCR1 = [];
           wn_values_SCR1 = [];
           seta_values_SCR1 = [];
           stability_values_SCR1 = [];

           for nn = 1:N
               current_SCR = table2array(OPset(nn,3));  % Column 3 = SCR
               if abs(current_SCR - SCR_target) < 0.01  % Tolerance for SCR=1
                   Vpcc_values_SCR1 = [Vpcc_values_SCR1; table2array(OPset(nn,1))];   % Column 1 = Vpcc
                   Pdfig_values_SCR1 = [Pdfig_values_SCR1; table2array(OPset(nn,2))]; % Column 2 = Pdfig
                   wn_values_SCR1 = [wn_values_SCR1; LIN_MODEL{nn}.naturalFreq(2)];
                   seta_values_SCR1 = [seta_values_SCR1; LIN_MODEL{nn}.minDamping(2)];
                   stability_values_SCR1 = [stability_values_SCR1; LIN_MODEL{nn}.stability];
               end
           end

           % Get unique Vpcc and Pdfig values
           Vpcc_all = unique(Vpcc_values_SCR1);
           Pdfig_unique_SCR1 = unique(Pdfig_values_SCR1);

           % Select 2 lowest and 2 highest voltages (robust selection)
           if length(Vpcc_all) >= 4
               Vpcc_unique_SCR1 = [Vpcc_all(1:2); Vpcc_all(end-1:end)];
           else
               Vpcc_unique_SCR1 = Vpcc_all;  % Use all available if less than 4
           end

           % Plot each voltage in a separate subplot
           for vv = 1:length(Vpcc_unique_SCR1)
               subplot(2, 2, vv)

               % Find all points with this Vpcc value and SCR=1
               idx_this_V = abs(Vpcc_values_SCR1 - Vpcc_unique_SCR1(vv)) < 0.001;
               P_this_V = Pdfig_values_SCR1(idx_this_V);
               wn_this_V = wn_values_SCR1(idx_this_V);
               seta_this_V = seta_values_SCR1(idx_this_V);
               stability_this_V = stability_values_SCR1(idx_this_V);

               % Sort by power for proper line connection
               [P_sorted, sort_idx] = sort(P_this_V);
               wn_sorted = wn_this_V(sort_idx);
               seta_sorted = seta_this_V(sort_idx);
               stability_sorted = stability_this_V(sort_idx);

               % Identify stable/unstable points using stability field
               stable_idx = stability_sorted == 1;
               unstable_idx = stability_sorted == 0;

               % Plot only stable points
               yyaxis left
               ax = gca;
               ax.YColor = [0 0 0];  % Force black color for left Y-axis
               hold on
               h1 = [];
               if any(stable_idx)
                   h1 = plot(P_sorted(stable_idx), wn_sorted(stable_idx), 'k*-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end
               ylim([wn_min wn_max])
               ylabel('$\omega_n$ (rad/s)', 'Interpreter', 'latex', 'Color', [0 0 0])

               yyaxis right
               ax = gca;
               ax.YColor = [0 0 0];  % Force black color for right Y-axis
               h2 = [];
               if any(stable_idx)
                   h2 = plot(P_sorted(stable_idx), seta_sorted(stable_idx), 'ko-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end
               ylim([seta_min seta_max])
               ylabel('Damping', 'Interpreter', 'latex', 'Color', [0 0 0])

               % Mark unstable points with red circles at midpoint of Y-axis
               h3 = [];
               if any(unstable_idx)
                   yyaxis left
                   middle_y = (wn_min + wn_max) / 2;
                   for uu = find(unstable_idx)'
                       h3 = plot(P_sorted(uu), middle_y, 'ro', 'LineWidth', 2, 'MarkerSize', 12, 'MarkerFaceColor', 'r');
                   end
               end
               hold off

               xlim([min(Pdfig_unique_SCR1) max(Pdfig_unique_SCR1)])
               xlabel('$P_{\mathrm{dfig}}$ (pu)', 'Interpreter', 'latex')
               title(sprintf('$V_{\\mathrm{pcc}}=%g$ pu (SCR=%.1f)', Vpcc_unique_SCR1(vv), SCR_target), 'Interpreter', 'latex')

               % Legend: adapt based on what's actually plotted
               if ~isempty(h1) && ~isempty(h2)
                   % Both stable lines exist
                   if any(unstable_idx)
                       legend([h1, h2, h3], {'$\omega_n$', '$\zeta$', 'Unstable'}, 'Location', 'southwest', 'Interpreter', 'latex')
                   else
                       legend([h1, h2], {'$\omega_n$', '$\zeta$'}, 'Location', 'southwest', 'Interpreter', 'latex')
                   end
               elseif any(unstable_idx)
                   % Only unstable markers exist (no stable points)
                   legend(h3, {'Unstable'}, 'Location', 'southwest', 'Interpreter', 'latex')
               end
               grid on
           end

           %------------------------------------------------------------------
           % Figure 2: Real poles vs. Power for SCR=1 (2×2 grid, one subplot per voltage)
           %------------------------------------------------------------------
           figure(2)

           % Find all points with SCR=1 (most critical grid strength)
           SCR_target = 1.0;
           Vpcc_values_SCR1 = [];
           Pdfig_values_SCR1 = [];
           realPole_values_SCR1 = [];

           for nn = 1:N
               current_SCR = table2array(OPset(nn,3));  % Column 3 = SCR
               if abs(current_SCR - SCR_target) < 0.01  % Tolerance for SCR=1
                   Vpcc_values_SCR1 = [Vpcc_values_SCR1; table2array(OPset(nn,1))];   % Column 1 = Vpcc
                   Pdfig_values_SCR1 = [Pdfig_values_SCR1; table2array(OPset(nn,2))]; % Column 2 = Pdfig
                   realPole_values_SCR1 = [realPole_values_SCR1; LIN_MODEL{nn}.maxRealEig];
               end
           end

           % Get unique Vpcc and Pdfig values
           Vpcc_all = unique(Vpcc_values_SCR1);
           Pdfig_unique_SCR1 = unique(Pdfig_values_SCR1);

           % Select 2 lowest and 2 highest voltages (robust selection)
           if length(Vpcc_all) >= 4
               Vpcc_unique_SCR1 = [Vpcc_all(1:2); Vpcc_all(end-1:end)];
           else
               Vpcc_unique_SCR1 = Vpcc_all;  % Use all available if less than 4
           end

           % Plot each voltage in a separate subplot
           for vv = 1:length(Vpcc_unique_SCR1)
               subplot(2, 2, vv)

               % Find all points with this Vpcc value and SCR=1
               idx_this_V = abs(Vpcc_values_SCR1 - Vpcc_unique_SCR1(vv)) < 0.001;
               P_this_V = Pdfig_values_SCR1(idx_this_V);
               realPole_this_V = realPole_values_SCR1(idx_this_V);

               % Sort by power for proper line connection
               [P_sorted, sort_idx] = sort(P_this_V);
               realPole_sorted = realPole_this_V(sort_idx);

               % Identify stable/unstable points
               unstable_idx = realPole_sorted > 0;
               stable_idx = ~unstable_idx;

               % Plot all points with black line (connecting only stable points for continuity)
               hold on

               % Plot line through all stable points (black)
               if any(stable_idx)
                   plot(P_sorted(stable_idx), realPole_sorted(stable_idx), ...
                        'k*-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end

               % Mark unstable points with red circles at midpoint of Y-axis
               if any(unstable_idx)
                   middle_y = (realPole_min + realPole_max) / 2;
                   for uu = find(unstable_idx)'
                       plot(P_sorted(uu), middle_y, ...
                            'ro', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
                   end
               end
               hold off

               % Set ylim based ONLY on stable points (realPole_min/max already calculated from stable points)
               ylim([realPole_min realPole_max])
               ylabel('Real pole (rad/s)', 'Interpreter', 'latex')
               xlim([min(Pdfig_unique_SCR1) max(Pdfig_unique_SCR1)])
               xlabel('$P_{\mathrm{dfig}}$ (pu)', 'Interpreter', 'latex')
               title(sprintf('$V_{\\mathrm{pcc}}=%g$ pu (SCR=%.1f)', Vpcc_unique_SCR1(vv), SCR_target), 'Interpreter', 'latex')

               % Legend: adapt based on what's actually plotted
               has_stable = any(stable_idx);
               has_unstable = any(unstable_idx);

               if has_stable && has_unstable
                   legend({'Stable (Real pole)', 'Unstable'}, 'Location', 'best', 'Interpreter', 'latex')
               elseif has_stable
                   legend({'Real pole'}, 'Location', 'best', 'Interpreter', 'latex')
               elseif has_unstable
                   legend({'Unstable'}, 'Location', 'best', 'Interpreter', 'latex')
               end
               grid on
           end
       elseif figureType==16 % Pdfig (voltage sweep for fixed powers)
           % Get total number of operating points
           N = size(OPset,1);
           paramName = 'V_{pcc}';
           Nz = length(unique(table2array(OPset(:,1))));  % Number of unique voltages

           % Calculate global axis limits for consistent scaling across all cases
           wn_values_all = [];
           seta_values_all = [];
           realPole_values_all = [];
           for nn = 1:N
               wn_values_all = [wn_values_all; LIN_MODEL{nn}.naturalFreq(2)];
               seta_values_all = [seta_values_all; LIN_MODEL{nn}.minDamping(2)];
               realPole_values_all = [realPole_values_all; LIN_MODEL{nn}.maxRealEig];
           end
           wn_max = max(wn_values_all);
           wn_min = min(wn_values_all);
           seta_max = max(seta_values_all);
           seta_min = min(seta_values_all);
           % Real pole limits (only stable points: realPole ≤ 0)
           stable_realPoles = realPole_values_all(realPole_values_all <= 0);
           if ~isempty(stable_realPoles)
               realPole_max = max(stable_realPoles);
               realPole_min = min(stable_realPoles);
           else
               realPole_max = 0;
               realPole_min = -100;
           end

           %------------------------------------------------------------------
           % Figure 1: Complex poles vs. Voltage for SCR=1 (2×2 grid, one subplot per power)
           %------------------------------------------------------------------
           figure(1)

           % Find all points with SCR=1 (most critical grid strength)
           SCR_target = 1.0;
           Vpcc_values_SCR1 = [];
           Pdfig_values_SCR1 = [];
           wn_values_SCR1 = [];
           seta_values_SCR1 = [];
           stability_values_SCR1 = [];

           for nn = 1:N
               current_SCR = table2array(OPset(nn,3));  % Column 3 = SCR
               if abs(current_SCR - SCR_target) < 0.01  % Tolerance for SCR=1
                   Vpcc_values_SCR1 = [Vpcc_values_SCR1; table2array(OPset(nn,1))];   % Column 1 = Vpcc
                   Pdfig_values_SCR1 = [Pdfig_values_SCR1; table2array(OPset(nn,2))]; % Column 2 = Pdfig
                   wn_values_SCR1 = [wn_values_SCR1; LIN_MODEL{nn}.naturalFreq(2)];
                   seta_values_SCR1 = [seta_values_SCR1; LIN_MODEL{nn}.minDamping(2)];
                   stability_values_SCR1 = [stability_values_SCR1; LIN_MODEL{nn}.stability];
               end
           end

           % Get unique Pdfig and Vpcc values
           Pdfig_all = unique(Pdfig_values_SCR1);
           Vpcc_unique_SCR1 = unique(Vpcc_values_SCR1);

           % Select 4 powers immediately below or equal to 1.0 pu (CASE 16 SPECIFIC)
           Pdfig_below_1 = Pdfig_all(Pdfig_all <= 1.0);
           if length(Pdfig_below_1) >= 4
               Pdfig_unique_SCR1 = Pdfig_below_1(end-3:end);  % 4 highest powers ≤ 1.0
           elseif ~isempty(Pdfig_below_1)
               Pdfig_unique_SCR1 = Pdfig_below_1;  % Use all available below 1.0
           else
               % Fallback: if no powers ≤ 1.0, use 4 lowest powers
               if length(Pdfig_all) >= 4
                   Pdfig_unique_SCR1 = Pdfig_all(1:4);
               else
                   Pdfig_unique_SCR1 = Pdfig_all;
               end
           end

           % Plot each power in a separate subplot
           for pp = 1:length(Pdfig_unique_SCR1)
               subplot(2, 2, pp)

               % Find all points with this Pdfig value and SCR=1
               idx_this_P = abs(Pdfig_values_SCR1 - Pdfig_unique_SCR1(pp)) < 0.001;
               V_this_P = Vpcc_values_SCR1(idx_this_P);
               wn_this_P = wn_values_SCR1(idx_this_P);
               seta_this_P = seta_values_SCR1(idx_this_P);
               stability_this_P = stability_values_SCR1(idx_this_P);

               % Sort by voltage for proper line connection
               [V_sorted, sort_idx] = sort(V_this_P);
               wn_sorted = wn_this_P(sort_idx);
               seta_sorted = seta_this_P(sort_idx);
               stability_sorted = stability_this_P(sort_idx);

               % Identify stable/unstable points using stability field
               stable_idx = stability_sorted == 1;
               unstable_idx = stability_sorted == 0;

               % Plot only STABLE points with black lines
               yyaxis left
               ax = gca;
               ax.YColor = [0 0 0];  % Force black color for left Y-axis
               hold on
               h1 = [];
               if any(stable_idx)
                   h1 = plot(V_sorted(stable_idx), wn_sorted(stable_idx), 'k*-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end
               ylim([wn_min wn_max])
               ylabel('$\omega_n$ (rad/s)', 'Interpreter', 'latex', 'Color', [0 0 0])

               yyaxis right
               ax = gca;
               ax.YColor = [0 0 0];  % Force black color for right Y-axis
               h2 = [];
               if any(stable_idx)
                   h2 = plot(V_sorted(stable_idx), seta_sorted(stable_idx), 'ko-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end
               ylim([seta_min seta_max])
               ylabel('Damping', 'Interpreter', 'latex', 'Color', [0 0 0])

               % Mark unstable points with red circles at midpoint of Y-axis
               h3 = [];
               if any(unstable_idx)
                   yyaxis left
                   middle_y = (wn_min + wn_max) / 2;
                   for uu = find(unstable_idx)'
                       h3 = plot(V_sorted(uu), middle_y, 'ro', 'LineWidth', 2, 'MarkerSize', 12, 'MarkerFaceColor', 'r');
                   end
               end
               hold off

               if ~isempty(V_sorted)
                   xlim([min(V_sorted) max(V_sorted)])
               end
               xlabel('$V_{\mathrm{pcc}}$ (pu)', 'Interpreter', 'latex')
               title(sprintf('$P_{\\mathrm{dfig}}=%g$ pu (SCR=%.1f)', Pdfig_unique_SCR1(pp), SCR_target), 'Interpreter', 'latex')

               % Legend: adapt based on what's actually plotted
               if ~isempty(h1) && ~isempty(h2)
                   % Both stable lines exist
                   if any(unstable_idx)
                       legend([h1, h2, h3], {'$\omega_n$', '$\zeta$', 'Unstable'}, 'Location', 'southwest', 'Interpreter', 'latex')
                   else
                       legend([h1, h2], {'$\omega_n$', '$\zeta$'}, 'Location', 'southwest', 'Interpreter', 'latex')
                   end
               elseif any(unstable_idx)
                   % Only unstable markers exist (no stable points)
                   legend(h3, {'Unstable'}, 'Location', 'southwest', 'Interpreter', 'latex')
               end
               grid on
           end

           %------------------------------------------------------------------
           % Figure 2: Real poles vs. Voltage for SCR=1 (2×2 grid, one subplot per power)
           %------------------------------------------------------------------
           figure(2)

           % Find all points with SCR=1 (reuse extraction or re-extract if needed)
           % Already have: Vpcc_values_SCR1, Pdfig_values_SCR1 from Figure 1
           realPole_values_SCR1 = [];
           for nn = 1:N
               current_SCR = table2array(OPset(nn,3));
               if abs(current_SCR - SCR_target) < 0.01
                   realPole_values_SCR1 = [realPole_values_SCR1; LIN_MODEL{nn}.maxRealEig];
               end
           end

           % Plot each power in a separate subplot
           for pp = 1:length(Pdfig_unique_SCR1)
               subplot(2, 2, pp)

               % Find all points with this Pdfig value and SCR=1
               idx_this_P = abs(Pdfig_values_SCR1 - Pdfig_unique_SCR1(pp)) < 0.001;
               V_this_P = Vpcc_values_SCR1(idx_this_P);
               realPole_this_P = realPole_values_SCR1(idx_this_P);

               % Sort by voltage for proper line connection
               [V_sorted, sort_idx] = sort(V_this_P);
               realPole_sorted = realPole_this_P(sort_idx);

               % Identify stable/unstable points
               unstable_idx = realPole_sorted > 0;
               stable_idx = ~unstable_idx;

               % Plot only STABLE points with black line
               hold on
               if any(stable_idx)
                   plot(V_sorted(stable_idx), realPole_sorted(stable_idx), ...
                        'k*-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end

               % Mark unstable points with red circles at midpoint of Y-axis
               if any(unstable_idx)
                   middle_y = (realPole_min + realPole_max) / 2;
                   for uu = find(unstable_idx)'
                       plot(V_sorted(uu), middle_y, ...
                            'ro', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
                   end
               end
               hold off

               % Set ylim based ONLY on stable points (realPole_min/max already calculated from stable points)
               ylim([realPole_min realPole_max])
               ylabel('Real pole (rad/s)', 'Interpreter', 'latex')
               if ~isempty(V_sorted)
                   xlim([min(V_sorted) max(V_sorted)])
               end
               xlabel('$V_{\mathrm{pcc}}$ (pu)', 'Interpreter', 'latex')
               title(sprintf('$P_{\\mathrm{dfig}}=%g$ pu (SCR=%.1f)', Pdfig_unique_SCR1(pp), SCR_target), 'Interpreter', 'latex')

               % Legend: adapt based on what's actually plotted
               has_stable = any(stable_idx);
               has_unstable = any(unstable_idx);

               if has_stable && has_unstable
                   legend({'Stable (Real pole)', 'Unstable'}, 'Location', 'best', 'Interpreter', 'latex')
               elseif has_stable
                   legend({'Real pole'}, 'Location', 'best', 'Interpreter', 'latex')
               elseif has_unstable
                   legend({'Unstable'}, 'Location', 'best', 'Interpreter', 'latex')
               end
               grid on
           end
       elseif figureType==17 % SCR sweep for fixed power (Pdfig = 1 pu)
           % Get total number of operating points
           N = size(OPset,1);
           paramName = 'SCR';
           Nz = length(unique(table2array(OPset(:,3))));  % Number of unique SCR values

           % Calculate global axis limits for consistent scaling across all cases
           wn_values_all = [];
           seta_values_all = [];
           realPole_values_all = [];
           for nn = 1:N
               wn_values_all = [wn_values_all; LIN_MODEL{nn}.naturalFreq(2)];
               seta_values_all = [seta_values_all; LIN_MODEL{nn}.minDamping(2)];
               realPole_values_all = [realPole_values_all; LIN_MODEL{nn}.maxRealEig];
           end
           wn_max = max(wn_values_all);
           wn_min = min(wn_values_all);
           seta_max = max(seta_values_all);
           seta_min = min(seta_values_all);
           % Real pole limits (only stable points: realPole ≤ 0)
           stable_realPoles = realPole_values_all(realPole_values_all <= 0);
           if ~isempty(stable_realPoles)
               realPole_max = max(stable_realPoles);
               realPole_min = min(stable_realPoles);
           else
               realPole_max = 0;
               realPole_min = -100;
           end

           %------------------------------------------------------------------
           % Figure 1: Complex poles vs. SCR for Pdfig=1 (2×2 grid, one subplot per voltage)
           %------------------------------------------------------------------
           figure(1)

           % Find all points with Pdfig = 1.0 pu (rated power)
           Pdfig_target = 1.0;
           Vpcc_values_P1 = [];
           SCR_values_P1 = [];
           wn_values_P1 = [];
           seta_values_P1 = [];
           stability_values_P1 = [];

           for nn = 1:N
               current_Pdfig = table2array(OPset(nn,2));  % Column 2 = Pdfig
               if abs(current_Pdfig - Pdfig_target) < 0.01  % Tolerance for Pdfig=1
                   Vpcc_values_P1 = [Vpcc_values_P1; table2array(OPset(nn,1))];   % Column 1 = Vpcc
                   SCR_values_P1 = [SCR_values_P1; table2array(OPset(nn,3))];     % Column 3 = SCR
                   wn_values_P1 = [wn_values_P1; LIN_MODEL{nn}.naturalFreq(2)];
                   seta_values_P1 = [seta_values_P1; LIN_MODEL{nn}.minDamping(2)];
                   stability_values_P1 = [stability_values_P1; LIN_MODEL{nn}.stability];
               end
           end

           % Get unique Vpcc and SCR values
           Vpcc_all = unique(Vpcc_values_P1);
           SCR_unique_P1 = unique(SCR_values_P1);

           % Select 2 lowest and 2 highest voltages (CASE 17 SPECIFIC)
           if length(Vpcc_all) >= 4
               Vpcc_unique_P1 = [Vpcc_all(1:2); Vpcc_all(end-1:end)];
           else
               Vpcc_unique_P1 = Vpcc_all;  % Use all available if less than 4
           end

           % Plot each voltage in a separate subplot
           for vv = 1:length(Vpcc_unique_P1)
               subplot(2, 2, vv)

               % Find all points with this Vpcc value and Pdfig=1
               idx_this_V = abs(Vpcc_values_P1 - Vpcc_unique_P1(vv)) < 0.001;
               SCR_this_V = SCR_values_P1(idx_this_V);
               wn_this_V = wn_values_P1(idx_this_V);
               seta_this_V = seta_values_P1(idx_this_V);
               stability_this_V = stability_values_P1(idx_this_V);

               % Sort by SCR for proper line connection
               [SCR_sorted, sort_idx] = sort(SCR_this_V);
               wn_sorted = wn_this_V(sort_idx);
               seta_sorted = seta_this_V(sort_idx);
               stability_sorted = stability_this_V(sort_idx);

               % Identify stable/unstable points using stability field
               stable_idx = stability_sorted == 1;
               unstable_idx = stability_sorted == 0;

               % Plot only stable points
               yyaxis left
               ax = gca;
               ax.YColor = [0 0 0];  % Force black color for left Y-axis
               hold on
               h1 = [];
               if any(stable_idx)
                   h1 = plot(SCR_sorted(stable_idx), wn_sorted(stable_idx), 'k*-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end
               ylim([wn_min wn_max])
               ylabel('$\omega_n$ (rad/s)', 'Interpreter', 'latex', 'Color', [0 0 0])

               yyaxis right
               ax = gca;
               ax.YColor = [0 0 0];  % Force black color for right Y-axis
               h2 = [];
               if any(stable_idx)
                   h2 = plot(SCR_sorted(stable_idx), seta_sorted(stable_idx), 'ko-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end
               ylim([seta_min seta_max])
               ylabel('Damping', 'Interpreter', 'latex', 'Color', [0 0 0])

               % Mark unstable points with red circles at midpoint of Y-axis
               h3 = [];
               if any(unstable_idx)
                   yyaxis left
                   middle_y = (wn_min + wn_max) / 2;
                   for uu = find(unstable_idx)'
                       h3 = plot(SCR_sorted(uu), middle_y, 'ro', 'LineWidth', 2, 'MarkerSize', 12, 'MarkerFaceColor', 'r');
                   end
               end
               hold off

               if ~isempty(SCR_sorted)
                   xlim([min(SCR_sorted) max(SCR_sorted)])
               end
               xlabel('SCR', 'Interpreter', 'latex')
               title(sprintf('$V_{\\mathrm{pcc}}=%g$ pu ($P_{\\mathrm{dfig}}=%.1f$ pu)', Vpcc_unique_P1(vv), Pdfig_target), 'Interpreter', 'latex')

               % Legend: adapt based on what's actually plotted
               if ~isempty(h1) && ~isempty(h2)
                   % Both stable lines exist
                   if any(unstable_idx)
                       legend([h1, h2, h3], {'$\omega_n$', '$\zeta$', 'Unstable'}, 'Location', 'southwest', 'Interpreter', 'latex')
                   else
                       legend([h1, h2], {'$\omega_n$', '$\zeta$'}, 'Location', 'southwest', 'Interpreter', 'latex')
                   end
               elseif any(unstable_idx)
                   % Only unstable markers exist (no stable points)
                   legend(h3, {'Unstable'}, 'Location', 'southwest', 'Interpreter', 'latex')
               end
               grid on
           end

           %------------------------------------------------------------------
           % Figure 2: Real poles vs. SCR for Pdfig=1 (2×2 grid, one subplot per voltage)
           %------------------------------------------------------------------
           figure(2)

           % Find all points with Pdfig = 1.0 pu (rated power)
           Pdfig_target = 1.0;
           Vpcc_values_P1 = [];
           SCR_values_P1 = [];
           realPole_values_P1 = [];

           for nn = 1:N
               current_Pdfig = table2array(OPset(nn,2));  % Column 2 = Pdfig
               if abs(current_Pdfig - Pdfig_target) < 0.01  % Tolerance for Pdfig=1
                   Vpcc_values_P1 = [Vpcc_values_P1; table2array(OPset(nn,1))];   % Column 1 = Vpcc
                   SCR_values_P1 = [SCR_values_P1; table2array(OPset(nn,3))];     % Column 3 = SCR
                   realPole_values_P1 = [realPole_values_P1; LIN_MODEL{nn}.maxRealEig];
               end
           end

           % Get unique Vpcc and SCR values
           Vpcc_all = unique(Vpcc_values_P1);
           SCR_unique_P1 = unique(SCR_values_P1);

           % Select 2 lowest and 2 highest voltages (robust selection)
           if length(Vpcc_all) >= 4
               Vpcc_unique_P1 = [Vpcc_all(1:2); Vpcc_all(end-1:end)];
           else
               Vpcc_unique_P1 = Vpcc_all;  % Use all available if less than 4
           end

           % Plot each voltage in a separate subplot
           for vv = 1:length(Vpcc_unique_P1)
               subplot(2, 2, vv)

               % Find all points with this Vpcc value and Pdfig=1
               idx_this_V = abs(Vpcc_values_P1 - Vpcc_unique_P1(vv)) < 0.001;
               SCR_this_V = SCR_values_P1(idx_this_V);
               realPole_this_V = realPole_values_P1(idx_this_V);

               % Sort by SCR for proper line connection
               [SCR_sorted, sort_idx] = sort(SCR_this_V);
               realPole_sorted = realPole_this_V(sort_idx);

               % Identify stable/unstable points
               unstable_idx = realPole_sorted > 0;
               stable_idx = ~unstable_idx;

               % Plot all points with black line (connecting only stable points for continuity)
               hold on

               % Plot line through all stable points (black)
               if any(stable_idx)
                   plot(SCR_sorted(stable_idx), realPole_sorted(stable_idx), ...
                        'k*-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', [0 0 0]);
               end

               % Mark unstable points with red circles at midpoint of Y-axis
               if any(unstable_idx)
                   middle_y = (realPole_min + realPole_max) / 2;
                   for uu = find(unstable_idx)'
                       plot(SCR_sorted(uu), middle_y, ...
                            'ro', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
                   end
               end
               hold off

               % Set ylim based ONLY on stable points (realPole_min/max already calculated from stable points)
               ylim([realPole_min realPole_max])
               ylabel('Real pole (rad/s)', 'Interpreter', 'latex')
               if ~isempty(SCR_sorted)
                   xlim([min(SCR_sorted) max(SCR_sorted)])
               end
               xlabel('SCR', 'Interpreter', 'latex')
               title(sprintf('$V_{\\mathrm{pcc}}=%g$ pu ($P_{\\mathrm{dfig}}=%.1f$ pu)', Vpcc_unique_P1(vv), Pdfig_target), 'Interpreter', 'latex')

               % Legend: adapt based on what's actually plotted
               has_stable = any(stable_idx);
               has_unstable = any(unstable_idx);

               if has_stable && has_unstable
                   legend({'Stable (Real pole)', 'Unstable'}, 'Location', 'best', 'Interpreter', 'latex')
               elseif has_stable
                   legend({'Real pole'}, 'Location', 'best', 'Interpreter', 'latex')
               elseif has_unstable
                   legend({'Unstable'}, 'Location', 'best', 'Interpreter', 'latex')
               end
               grid on
           end
       end

       %------------------------------------------------------------------
       % Step 4: Apply publication formatting to both figures
       %------------------------------------------------------------------
       % Apply white background, LaTeX fonts, and IEEE standards
       % Cases 15-17 now generate 2 figures (2×2 grid each) with unstable point marking
       format_figure_for_publication(figure(1));  % Complex poles (wn + damping) with stability indicators
       format_figure_for_publication(figure(2));  % Real poles with stability indicators

       %------------------------------------------------------------------
       % Step 5: Display results summary
       %------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔════════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASES 15-17: Root Locus Analysis                             ║\n');
       fprintf('╠════════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Case: %-2d  |  Sweep Parameter: %-28s ║\n', figureType, paramName);
       fprintf('║  Operating Points: %-3d  |  Sweep Values: %-2d                ║\n', N, Nz);
       fprintf('╚════════════════════════════════════════════════════════════════╝\n');
       fprintf('\n');
       fprintf('Natural Frequency Range:\n');
       fprintf('  Min: %.6f rad/s\n', wn_min);
       fprintf('  Max: %.6f rad/s\n', wn_max);
       fprintf('\n');
       fprintf('Damping Ratio Range:\n');
       fprintf('  Min: %.6f\n', seta_min);
       fprintf('  Max: %.6f\n', seta_max);
       fprintf('\n');
       fprintf('Real Pole Range (stable points only):\n');
       fprintf('  Min: %.6f rad/s\n', realPole_min);
       fprintf('  Max: %.6f rad/s\n', realPole_max);
       fprintf('\n');

   %--------------------------------------------------------------
   case 18 % Binary Stability Map - IEEE Paper Format
  %--------------------------------------------------------------
      % CASE 18: BINARY STABILITY COLOR MAP FOR IEEE PUBLICATIONS
      %
      % PURPOSE:
      %   Generates publication-quality 2x2 stability maps showing stable/unstable
      %   operating regions as a function of PCC voltage and DFIG power for
      %   different SCR values. Designed for IEEE paper figure generation.
      %
      % METHODOLOGY:
      %   1. Stability Determination: Binary classification based on maximum real eigenvalue
      %      - Stable:   maxRealEig <= 0 (white/value=1)
      %      - Unstable: maxRealEig > 0  (black/value=0)
      %
      %   2. Grid Variables:
      %      - X-axis (columns): PCC voltage (Vpcc) in pu
      %      - Y-axis (rows):    DFIG power (Pdfig) in pu
      %      - Subplots:         Grid SCR values (up to 4 in 2x2 layout)
      %
      %   3. Visualization:
      %      - imagesc() for binary heatmap rendering
      %      - Custom colormap: Black (unstable) / White (stable)
      %      - No colorbar (binary map is self-explanatory)
      %      - IEEE publication formatting applied
      %
      % TYPICAL USE CASES:
      %   - Identify safe operating regions for different grid strengths
      %   - Visualize stability boundaries in voltage-power plane
      %   - Compare SCR influence on stability margins
      %   - Generate figures for power systems stability papers
      %
      % DESIGN CHOICES:
      %   - Fixed 2x2 layout: Maximum 4 SCR values for clarity
      %   - SCR filtering: Excludes SCR >= 3 to focus on weak grid scenarios
      %   - Binary classification: Clear stable/unstable distinction
      %   - White background: IEEE publication standard
      %
      % OUTPUT:
      %   - Single figure with 2x2 subplot layout
      %   - Each subplot: Stability map for one SCR value
      %   - No colorbar (binary classification is visually clear)
      %   - Console output: Statistics summary with metrics
      %
      % IEEE COMPATIBILITY:
      %   - LaTeX interpreter for all text elements
      %   - Times New Roman font, 10-12pt
      %   - High-contrast black/white colormap
      %   - Proper axis labeling and units
      %--------------------------------------------------------------

      disp('╔════════════════════════════════════════════════════════════╗');
      disp('║  CASE 18: Binary Stability Map Generation                 ║');
      disp('╚════════════════════════════════════════════════════════════╝');

      %------------------------------------------------------------------
      % Step 1: Stability Classification
      %------------------------------------------------------------------
      N = size(OPset,1);
      OPsetExt = OPset;
      pValues = NaN(N,1);

      % Binary stability determination based on maximum real eigenvalue
      for nn = 1:N
          if LIN_MODEL{nn}.maxRealEig > 0
              pValues(nn) = 0; % Unstable (black)
          else
              pValues(nn) = 1; % Stable (white)
          end
      end
      OPsetExt.stability_derived = pValues;

      % Compute stability statistics
      num_stable = sum(pValues == 1);
      num_unstable = sum(pValues == 0);
      stability_percentage = (num_stable / N) * 100;

      %------------------------------------------------------------------
      % Step 2: Variable Assignment and Grid Configuration
      %------------------------------------------------------------------
      % Assign physical variables to plot axes
      xVarData = OPset.Vpcc;      % X-axis: PCC voltage
      yVarData = OPset.Pdfig;     % Y-axis: DFIG power
      zVarData = OPset.SCRgrid;   % Subplots: Grid SCR

      % Axis labels with proper formatting
      xLabel = 'PCC voltage (pu)';
      yLabel = 'DFIG Power (pu)';
      zLabel = '\mathrm{SCR}';

      % Extract unique values for grid construction
      xValues = unique(xVarData);
      yValues = unique(yVarData);

      % Filter SCR values: Exclude SCR >= 3 (focus on weak grids)
      zValues = unique(zVarData);
      zValues = zValues(zValues < 3);

      % Validate subplot count for 2x2 layout
      Nfig = length(zValues);
      if Nfig > 4
          warning('CASE 18: More than 4 SCR values detected. Displaying first 4 in 2x2 grid.');
          Nfig = 4;
          zValues = zValues(1:4);
      end

      % Subplot layout configuration
      sp1 = 2;  % Rows
      sp2 = 2;  % Columns

      %------------------------------------------------------------------
      % Step 3: Colormap Configuration
      %------------------------------------------------------------------
      % Custom binary colormap: [unstable; stable]
      % Values: 0 = unstable (black), 1 = stable (white)
      myColorMap = [stabilityPlotColors.unstable; stabilityPlotColors.stable];

      %------------------------------------------------------------------
      % Step 4: Figure Generation - 2x2 Stability Maps
      %   IEEE single-column: 3.5 x 3.0 inches
      %------------------------------------------------------------------
      figure('Name', 'System Stability Map', 'Units', 'inches', ...
             'Position', [1, 1, 3.5, 3.0]);

      for ii = 1:Nfig
          subplot(sp1, sp2, ii)

          % Initialize data grid for current SCR value
          dataPlot = nan(length(yValues), length(xValues));

          % Populate grid with stability values
          for row = 1:length(yValues)
              for col = 1:length(xValues)
                  % Find operating point matching (Vpcc, Pdfig, SCR)
                  idx = find(OPset.Vpcc == xValues(col) & ...
                             OPset.Pdfig == yValues(row) & ...
                             OPset.SCRgrid == zValues(ii));

                  if ~isempty(idx)
                      dataPlot(row, col) = pValues(idx(1));
                  end
              end
          end

          % Render stability map using imagesc
          imagesc(xValues, yValues, dataPlot);

          % Apply custom colormap to current axes
          colormap(gca, myColorMap)

          % Reduced tick marks for readability in small subplots
          xticks([0.95, 1.0, 1.05]);
          xticklabels({'0.95', '1.0', '1.05'});
          yticks([0.4, 0.6, 0.8, 1.0, 1.2]);

          % Axis labels with LaTeX interpreter (BLACK text) — 8pt for single-col subplots
          xlabel(xLabel, 'Interpreter', 'latex', 'FontSize', 8, 'Color', [0 0 0]);
          ylabel(yLabel, 'Interpreter', 'latex', 'FontSize', 8, 'Color', [0 0 0]);

          % Subplot title with SCR value (BLACK text) — 9pt for single-col subplots
          title_str = sprintf('$%s = %.2f$', zLabel, zValues(ii));
          title(title_str, 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);

          % Set color limits for binary mapping (global scale)
          clim([0 1]);

          % Axes formatting (BLACK text for all elements) — 7pt for single-col subplots
          set(gca, 'FontName', 'Times New Roman', 'FontSize', 7, ...
                   'YDir', 'normal', ...
                   'TickLabelInterpreter', 'latex', ...
                   'XColor', [0 0 0], 'YColor', [0 0 0], ...
                   'XTickLabelRotation', 0, ...  % Horizontal labels
                   'GridColor', [0 0 0], 'MinorGridColor', [0 0 0]);
      end

      %------------------------------------------------------------------
      % Step 4b: Add Global Colorbar (shared across all subplots)
      %------------------------------------------------------------------
      % DISABLED: Colorbar removed as it provides no useful information
      % The binary stability map is self-explanatory (black/white)
      %
      % % Create a single colorbar for the entire figure
      % % Position it on the right side of the figure
      % cb = colorbar('Position', [0.92, 0.15, 0.02, 0.7]);
      % cb.Ticks = [0.25 0.75];  % Center ticks in each color region
      % cb.TickLabels = {'Unstable', 'Stable'};
      % set(cb, 'TickLabelInterpreter', 'latex', 'FontSize', 11, ...
      %         'Color', [0 0 0]);  % BLACK text

      %------------------------------------------------------------------
      % Step 5: Apply IEEE Publication Formatting (single-column: 3.5 x 3.0 in)
      %------------------------------------------------------------------
      format_figure_for_publication(figure(1), 3.5, 3.0)

      %------------------------------------------------------------------
      % Step 6: Display Stability Metrics
      %------------------------------------------------------------------
      fprintf('\n');
      fprintf('╔════════════════════════════════════════════════════════════╗\n');
      fprintf('║  CASE 18: Binary Stability Map - Results Summary          ║\n');
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Total Operating Points: %-33d ║\n', N);
      fprintf('║  Stable Points:          %-33d ║\n', num_stable);
      fprintf('║  Unstable Points:        %-33d ║\n', num_unstable);
      fprintf('║  Stability Rate:         %-30.2f %%  ║\n', stability_percentage);
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Grid Configuration:                                       ║\n');
      fprintf('║    - Vpcc values:        %-33d ║\n', length(xValues));
      fprintf('║    - Pdfig values:       %-33d ║\n', length(yValues));
      fprintf('║    - SCR values plotted: %-33d ║\n', Nfig);
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Figure Layout: 2x2 subplots (no colorbar)                ║\n');
      fprintf('║  Colormap: Black (unstable) / White (stable)               ║\n');
      fprintf('║  IEEE Formatting: Applied                                  ║\n');
      fprintf('╚════════════════════════════════════════════════════════════╝\n');
      fprintf('\n');

      % Display grid ranges
      fprintf('Operating Point Ranges:\n');
      fprintf('  Vpcc range:  %.3f - %.3f pu\n', min(xValues), max(xValues));
      fprintf('  Pdfig range: %.3f - %.3f pu\n', min(yValues), max(yValues));
      fprintf('  SCR values:  %s\n', mat2str(zValues, 3));
      fprintf('\n');


   %--------------------------------------------------------------
    case 19 % Line Angle vs. Power Analysis - IEEE Paper Format
   %--------------------------------------------------------------
      % CASE 19: MAXIMUM LINE ANGLE VS. DFIG POWER FOR DIFFERENT SCR VALUES
      %
      % PURPOSE:
      %   Generates publication-quality line plots showing the relationship between
      %   maximum transmission line angle and DFIG power output for different grid
      %   strength conditions (SCR values). Designed for IEEE paper figure generation.
      %
      % METHODOLOGY:
      %   1. Data Extraction: For each (SCR, Power) combination, extract maximum
      %      line angle across all PCC voltage conditions (worst-case scenario)
      %
      %   2. Line Plot Generation: One line per SCR value showing how maximum line
      %      angle varies with DFIG power output
      %
      %   3. Worst-Case Analysis: Uses max() over all Vpcc values to identify
      %      critical operating conditions for each power level
      %
      % PHYSICAL INTERPRETATION:
      %   - Line Angle: Phase difference between sending and receiving end voltages
      %   - High angles indicate stress on transmission system stability
      %   - Critical threshold: Typically 30-45 degrees for transient stability
      %   - Weaker grids (lower SCR) → Higher line angles at same power
      %
      % TYPICAL USE CASES:
      %   - Assess transmission line loading limits
      %   - Compare grid strength impact on power transfer capability
      %   - Identify safe operating regions for different SCR scenarios
      %   - Support grid code compliance analysis
      %
      % DESIGN CHOICES:
      %   - Worst-case approach: Maximum angle across all voltages
      %   - Black lines with different markers: IEEE B&W publication standard
      %   - Distinct marker styles: One per SCR value (circle, square, diamond, triangle, etc.)
      %   - No title: Clean layout for paper inclusion
      %
      % OUTPUT:
      %   - Single figure with multiple overlaid lines
      %   - Each line: One SCR value
      %   - X-axis: DFIG power (pu)
      %   - Y-axis: Maximum line angle (degrees)
      %   - Console output: Metrics summary
      %
      % IEEE COMPATIBILITY:
      %   - LaTeX interpreter for all text elements
      %   - Times New Roman font, 10-11pt
      %   - Black lines with distinct markers (IEEE B&W standard)
      %   - Professional line width (1.5pt) and marker size (8pt)
      %   - Suitable for grayscale printing
      %--------------------------------------------------------------

      disp('╔════════════════════════════════════════════════════════════╗');
      disp('║  CASE 19: Line Angle vs. Power Analysis                   ║');
      disp('╚════════════════════════════════════════════════════════════╝');

      %------------------------------------------------------------------
      % Step 1: Data Preparation
      %------------------------------------------------------------------
      % Extract unique values for power and SCR from operating point set
      power_values = unique(OPset.Pdfig);
      scr_values = unique(OPset.SCRgrid);
      
      % Define marker styles for IEEE B&W publication (distinct shapes)
      marker_styles = {'o', 's', 'd', '^', 'v', '>', '<', 'p', 'h', '*'};
      line_styles = {'-', '--', '-.', ':'};
      
      % Initialize statistics tracking
      max_angle_overall = -inf;
      min_angle_overall = inf;
      critical_scr = NaN;
      critical_power = NaN;

      %------------------------------------------------------------------
      % Step 2: Create Figure and Enable Grid
      %------------------------------------------------------------------
      figure('Name', 'Line Angle vs. Power', 'Units', 'inches', ...
             'Position', [1, 1, 3.5, 2.8]);
      hold on;
      grid on;

      %------------------------------------------------------------------
      % Step 3: Extract and Plot Data for Each SCR Value
      %------------------------------------------------------------------
      for i = 1:length(scr_values)
          current_scr = scr_values(i);
          
          % Initialize data vectors for current SCR
          x_data = [];
          y_data = [];
          
          % For each power level, find maximum line angle (worst case across all Vpcc)
          for j = 1:length(power_values)
              current_p = power_values(j);
              
              % Find all operating points matching (SCR, Power) combination
              indices = find(OPset.SCRgrid == current_scr & OPset.Pdfig == current_p);
              
              if ~isempty(indices)
                  % Extract line angles for all Vpcc values at this (SCR, Power)
                  angles_at_op = cellfun(@(x) x.lineAngle, LIN_MODEL(indices));
                  
                  % Take maximum angle (worst-case scenario)
                  max_angle = max(angles_at_op);
                  
                  % Store data point
                  x_data(end+1) = current_p;
                  y_data(end+1) = max_angle;
                  
                  % Update overall statistics
                  if max_angle > max_angle_overall
                      max_angle_overall = max_angle;
                      critical_scr = current_scr;
                      critical_power = current_p;
                  end
                  min_angle_overall = min(min_angle_overall, max_angle);
              end
          end
          
          % Plot line for current SCR if data exists (BLACK with unique marker)
          if ~isempty(x_data)
              % Select marker and line style (cycle through if more SCR values than styles)
              marker_idx = mod(i-1, length(marker_styles)) + 1;
              line_idx = mod(floor((i-1)/length(marker_styles)), length(line_styles)) + 1;
              
              plot(x_data, y_data, ...
                   'Color', [0 0 0], ...                           % BLACK line
                   'LineStyle', line_styles{line_idx}, ...         % Cycle line styles
                   'LineWidth', 1.5, ...                           % IEEE standard width
                   'Marker', marker_styles{marker_idx}, ...        % Unique marker per SCR
                   'MarkerSize', 8, ...                            % Visible markers
                   'MarkerFaceColor', [1 1 1], ...                 % White fill
                   'MarkerEdgeColor', [0 0 0], ...                 % Black edge
                   'DisplayName', sprintf('SCR = %.2f', current_scr));
          end
      end
      
      hold off;

      %------------------------------------------------------------------
      % Step 4: Format Plot with LaTeX and IEEE Standards
      %------------------------------------------------------------------
      % Axis labels (BLACK text) — 9pt for single-column
      xlabel('DFIG Power (pu)', 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);
      ylabel('Maximum Line Angle ($^{\circ}$)', 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);

      % Legend configuration — 7pt for single-column
      lgd = legend('show', 'Location', 'northwest');
      set(lgd, 'Interpreter', 'latex', 'FontSize', 7);

      % Axis limits and formatting — 8pt for single-column
      xlim([min(power_values), max(power_values)]);
      set(gca, 'FontName', 'Times New Roman', 'FontSize', 8, ...
               'XColor', [0 0 0], 'YColor', [0 0 0]);  % Black axes

      %------------------------------------------------------------------
      % Step 5: Apply IEEE Publication Formatting (single-column: 3.5 x 2.8 in)
      %------------------------------------------------------------------
      format_figure_for_publication(figure(1), 3.5, 2.8)

      % Nudge legend after formatting
      drawnow;
      lgd.Units = 'normalized';
      lp = lgd.Position;
      lp(1) = lp(1) + 0.04;   % shift right to center
      lp(2) = lp(2) + 0.003;  % slight shift up
      lgd.Position = lp;

      %------------------------------------------------------------------
      % Step 6: Display Analysis Metrics
      %------------------------------------------------------------------
      fprintf('\n');
      fprintf('╔════════════════════════════════════════════════════════════╗\n');
      fprintf('║  CASE 19: Line Angle Analysis - Results Summary           ║\n');
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Power Levels Analyzed:  %-33d ║\n', length(power_values));
      fprintf('║  SCR Values Analyzed:    %-33d ║\n', length(scr_values));
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Line Angle Statistics (degrees):                          ║\n');
      fprintf('║    - Minimum Angle:      %-30.2f °  ║\n', min_angle_overall);
      fprintf('║    - Maximum Angle:      %-30.2f °  ║\n', max_angle_overall);
      fprintf('║    - Angle Range:        %-30.2f °  ║\n', max_angle_overall - min_angle_overall);
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Critical Operating Point (Maximum Line Angle):            ║\n');
      fprintf('║    - SCR:                %-33.2f ║\n', critical_scr);
      fprintf('║    - DFIG Power:         %-30.3f pu  ║\n', critical_power);
      fprintf('║    - Line Angle:         %-30.2f °  ║\n', max_angle_overall);
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Plot Format: IEEE B&W (black lines, distinct markers)    ║\n');
      fprintf('║  Analysis Method: Worst-case (max over all Vpcc values)   ║\n');
      fprintf('║  IEEE Formatting: Applied                                  ║\n');
      fprintf('╚════════════════════════════════════════════════════════════╝\n');
      fprintf('\n');

      % Display operating ranges
      fprintf('Operating Parameter Ranges:\n');
      fprintf('  Power range:  %.3f - %.3f pu\n', min(power_values), max(power_values));
      fprintf('  SCR values:   %s\n', mat2str(scr_values, 3));
      fprintf('\n');



  %--------------------------------------------------------------
   case 20 % Comparative Stability Analysis (2x2) - IEEE Paper Format
  %--------------------------------------------------------------
      % CASE 20: 2x2 COMPARATIVE STABILITY AND DAMPING ANALYSIS
      %
      % PURPOSE:
      %   Generates publication-quality 2x2 subplot figure comparing the impact of
      %   grid strength (SCR) and PCC voltage on system stability metrics. Designed
      %   for comprehensive parameter sensitivity analysis in IEEE papers.
      %
      % METHODOLOGY:
      %   Four-quadrant comparative analysis:
      %
      %   LEFT COLUMN (SCR Influence at lowest Vpcc):
      %     - Top-Left:    Maximum real eigenvalue vs. DFIG power
      %     - Bottom-Left: Minimum damping ratio vs. DFIG power
      %
      %   RIGHT COLUMN (Vpcc Influence at SCR=1):
      %     - Top-Right:    Maximum real eigenvalue vs. DFIG power
      %     - Bottom-Right: Minimum damping ratio vs. DFIG power
      %
      % PHYSICAL INTERPRETATION:
      %   - Maximum Real Eigenvalue: Stability margin (negative = stable)
      %   - Minimum Damping Ratio: Oscillation decay rate (higher = better damped)
      %   - SCR Influence: Shows impact of grid strength on stability
      %   - Vpcc Influence: Shows impact of voltage level on stability
      %   - Unstable points marked with 'x' at y=0
      %
      % TYPICAL USE CASES:
      %   - Compare relative importance of SCR vs. Vpcc on stability
      %   - Identify critical operating regions for control design
      %   - Support grid code compliance documentation
      %   - Validate operating envelope across parameter space
      %
      % DESIGN CHOICES:
      %   - 2x2 layout: Enables direct visual comparison
      %   - Linked x-axes: Common power scale for all subplots
      %   - Black lines with distinct markers: IEEE B&W standard
      %   - Unstable point markers: Clear identification of stability boundaries
      %   - Zero reference line: Stability threshold visualization
      %
      % OUTPUT:
      %   - Single figure with 2x2 subplot layout
      %   - Left column: SCR sensitivity (at min Vpcc)
      %   - Right column: Vpcc sensitivity (at SCR=1)
      %   - Console output: Comprehensive statistics
      %
      % IEEE COMPATIBILITY:
      %   - LaTeX interpreter for all mathematical notation
      %   - Times New Roman font, 11-14pt
      %   - Black lines with distinct markers per series
      %   - Professional spacing and alignment
      %   - Suitable for B&W printing
      %--------------------------------------------------------------

      disp('╔════════════════════════════════════════════════════════════╗');
      disp('║  CASE 20: Comparative Stability Analysis (2x2 Layout)     ║');
      disp('╚════════════════════════════════════════════════════════════╝');

      %------------------------------------------------------------------
      % Step 1: Figure Initialization and Data Preparation
      %------------------------------------------------------------------
      figure('Name', 'Comparative Stability and Damping Analysis', ...
             'Units', 'inches', 'Position', [1, 1, 7.16, 4.0]);
      
      power_values_full = unique(OPset.Pdfig);
      ax_handles = gobjects(4, 1);  % Handle array for 4 subplots
      
      % Define marker styles for IEEE B&W publication
      marker_styles_left = {'o', 's', 'd', '^', 'v'};   % Left column (SCR)
      marker_styles_right = {'o', 's', 'd', '^', 'v'};  % Right column (Vpcc)
      line_styles = {'-', '--', '-.', ':'};
      
      % Initialize statistics tracking
      stats = struct();
      stats.scr_range = [inf, -inf];
      stats.vpcc_range = [inf, -inf];
      stats.eig_range = [inf, -inf];
      stats.damp_range = [inf, -inf];
      stats.unstable_count_left = 0;
      stats.unstable_count_right = 0;

      %------------------------------------------------------------------
      % Step 2: LEFT COLUMN - SCR Influence (at lowest Vpcc)
      %------------------------------------------------------------------
      % Data filtering
      min_vpcc = min(OPset.Vpcc);
      op_indices_left = find(OPset.Vpcc == min_vpcc);
      OPset_left = OPset(op_indices_left, :);
      LIN_MODEL_left = LIN_MODEL(op_indices_left);
      scr_values = unique(OPset_left.SCRgrid);
      
      title_left = sprintf('SCR Influence (at $V_{\\mathrm{pcc}}$=%.3f pu)', min_vpcc);
      stats.scr_range = [min(scr_values), max(scr_values)];

      % --- Subplot 1: Maximum Real Eigenvalue vs Power (SCR) ---
      ax_handles(1) = subplot(2, 2, 1);
      hold on; grid on;
      plot(NaN, NaN, 'kx', 'MarkerSize', 10, 'LineWidth', 2, ...
           'DisplayName', 'Unstable Point');

      for i = 1:length(scr_values)
          current_scr = scr_values(i);
          y_data_eig = nan(size(power_values_full));
          unstable_points = [];
          
          for j = 1:length(power_values_full)
              current_p = power_values_full(j);
              index = find(OPset_left.SCRgrid == current_scr & ...
                          OPset_left.Pdfig == current_p);
              if ~isempty(index)
                  if LIN_MODEL_left{index}.stability == 1
                      y_data_eig(j) = LIN_MODEL_left{index}.maxRealEig;
                      stats.eig_range(1) = min(stats.eig_range(1), y_data_eig(j));
                      stats.eig_range(2) = max(stats.eig_range(2), y_data_eig(j));
                  else
                      unstable_points(end+1) = current_p;
                      stats.unstable_count_left = stats.unstable_count_left + 1;
                  end
              end
          end
          
          % Plot with black line and unique marker
          marker_idx = mod(i-1, length(marker_styles_left)) + 1;
          line_idx = mod(floor((i-1)/length(marker_styles_left)), length(line_styles)) + 1;
          
          plot(power_values_full, y_data_eig, ...
               'Color', [0 0 0], ...
               'LineStyle', line_styles{line_idx}, ...
               'LineWidth', 1.5, ...
               'Marker', marker_styles_left{marker_idx}, ...
               'MarkerSize', 7, ...
               'MarkerFaceColor', [1 1 1], ...
               'MarkerEdgeColor', [0 0 0], ...
               'DisplayName', sprintf('SCR = %.2f', current_scr));
          
          if ~isempty(unstable_points)
              plot(unstable_points, zeros(size(unstable_points)), 'x', ...
                   'Color', [0 0 0], 'MarkerSize', 10, 'LineWidth', 2, ...
                   'HandleVisibility', 'off');
          end
      end
      
      plot(xlim, [0 0], 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
      hold off;
      title(title_left, 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);
      ylabel('$\max(\Re(\lambda))$ (rad/s)', 'Interpreter', 'latex', ...
             'FontSize', 9, 'Color', [0 0 0]);
      legend('show', 'Location', 'best', 'Interpreter', 'latex', 'FontSize', 7);
      set(gca, 'FontName', 'Times New Roman', 'FontSize', 8, ...
               'XColor', [0 0 0], 'YColor', [0 0 0]);

      % --- Subplot 3: Minimum Damping vs Power (SCR) ---
      ax_handles(3) = subplot(2, 2, 3);
      hold on; grid on;
      plot(NaN, NaN, 'kx', 'MarkerSize', 10, 'LineWidth', 2, ...
           'DisplayName', 'Unstable Point');
      
      for i = 1:length(scr_values)
          current_scr = scr_values(i);
          y_data_damp = nan(size(power_values_full));
          unstable_points = [];
          
          for j = 1:length(power_values_full)
              current_p = power_values_full(j);
              index = find(OPset_left.SCRgrid == current_scr & ...
                          OPset_left.Pdfig == current_p);
              if ~isempty(index)
                  if LIN_MODEL_left{index}.stability == 1
                      y_data_damp(j) = LIN_MODEL_left{index}.minDamping(2);
                      stats.damp_range(1) = min(stats.damp_range(1), y_data_damp(j));
                      stats.damp_range(2) = max(stats.damp_range(2), y_data_damp(j));
                  else
                      unstable_points(end+1) = current_p;
                  end
              end
          end
          
          % Plot with black line and unique marker
          marker_idx = mod(i-1, length(marker_styles_left)) + 1;
          line_idx = mod(floor((i-1)/length(marker_styles_left)), length(line_styles)) + 1;
          
          plot(power_values_full, y_data_damp, ...
               'Color', [0 0 0], ...
               'LineStyle', line_styles{line_idx}, ...
               'LineWidth', 1.5, ...
               'Marker', marker_styles_left{marker_idx}, ...
               'MarkerSize', 7, ...
               'MarkerFaceColor', [1 1 1], ...
               'MarkerEdgeColor', [0 0 0], ...
               'DisplayName', sprintf('SCR = %.2f', current_scr));
          
          if ~isempty(unstable_points)
              plot(unstable_points, zeros(size(unstable_points)), 'x', ...
                   'Color', [0 0 0], 'MarkerSize', 10, 'LineWidth', 2, ...
                   'HandleVisibility', 'off');
          end
      end

      hold off;
      title(title_left, 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);
      xlabel('DFIG Power (pu)', 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);
      ylabel('Minimum Damping Ratio ($\zeta$)', 'Interpreter', 'latex', ...
             'FontSize', 9, 'Color', [0 0 0]);
      legend('show', 'Location', 'best', 'Interpreter', 'latex', 'FontSize', 7);
      set(gca, 'FontName', 'Times New Roman', 'FontSize', 8, ...
               'XColor', [0 0 0], 'YColor', [0 0 0]);

      %------------------------------------------------------------------
      % Step 3: RIGHT COLUMN - Vpcc Influence (at SCR=1)
      %------------------------------------------------------------------
      % Data filtering
      op_indices_right = find(OPset.SCRgrid == 1);
      OPset_right = OPset(op_indices_right, :);
      LIN_MODEL_right = LIN_MODEL(op_indices_right);
      vpcc_values = unique(OPset_right.Vpcc);
      
      title_right = '$V_{\mathrm{pcc}}$ Influence (at SCR=1)';
      stats.vpcc_range = [min(vpcc_values), max(vpcc_values)];

      % --- Subplot 2: Maximum Real Eigenvalue vs Power (Vpcc) ---
      ax_handles(2) = subplot(2, 2, 2);
      hold on; grid on;
      plot(NaN, NaN, 'kx', 'MarkerSize', 10, 'LineWidth', 2, ...
           'DisplayName', 'Unstable Point');
      
      for i = 1:length(vpcc_values)
          current_vpcc = vpcc_values(i);
          y_data_eig = nan(size(power_values_full));
          unstable_points = [];
          
          for j = 1:length(power_values_full)
              current_p = power_values_full(j);
              index = find(OPset_right.Vpcc == current_vpcc & ...
                          OPset_right.Pdfig == current_p);
              if ~isempty(index)
                  if LIN_MODEL_right{index}.stability == 1
                      y_data_eig(j) = LIN_MODEL_right{index}.maxRealEig;
                  else
                      unstable_points(end+1) = current_p;
                      stats.unstable_count_right = stats.unstable_count_right + 1;
                  end
              end
          end
          
          % Plot with black line and unique marker
          marker_idx = mod(i-1, length(marker_styles_right)) + 1;
          line_idx = mod(floor((i-1)/length(marker_styles_right)), length(line_styles)) + 1;
          
          plot(power_values_full, y_data_eig, ...
               'Color', [0 0 0], ...
               'LineStyle', line_styles{line_idx}, ...
               'LineWidth', 1.5, ...
               'Marker', marker_styles_right{marker_idx}, ...
               'MarkerSize', 7, ...
               'MarkerFaceColor', [1 1 1], ...
               'MarkerEdgeColor', [0 0 0], ...
               'DisplayName', sprintf('$V_{\\mathrm{pcc}}$ = %.3f pu', current_vpcc));
          
          if ~isempty(unstable_points)
              plot(unstable_points, zeros(size(unstable_points)), 'x', ...
                   'Color', [0 0 0], 'MarkerSize', 10, 'LineWidth', 2, ...
                   'HandleVisibility', 'off');
          end
      end

      plot(xlim, [0 0], 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
      hold off;
      title(title_right, 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);
      legend('show', 'Location', 'best', 'Interpreter', 'latex', 'FontSize', 7);
      set(gca, 'FontName', 'Times New Roman', 'FontSize', 8, ...
               'XColor', [0 0 0], 'YColor', [0 0 0]);

      % --- Subplot 4: Minimum Damping vs Power (Vpcc) ---
      ax_handles(4) = subplot(2, 2, 4);
      hold on; grid on;
      plot(NaN, NaN, 'kx', 'MarkerSize', 10, 'LineWidth', 2, ...
           'DisplayName', 'Unstable Point');

      for i = 1:length(vpcc_values)
          current_vpcc = vpcc_values(i);
          y_data_damp = nan(size(power_values_full));
          unstable_points = [];
          
          for j = 1:length(power_values_full)
              current_p = power_values_full(j);
              index = find(OPset_right.Vpcc == current_vpcc & ...
                          OPset_right.Pdfig == current_p);
              if ~isempty(index)
                  if LIN_MODEL_right{index}.stability == 1
                      y_data_damp(j) = LIN_MODEL_right{index}.minDamping(2);
                  else
                      unstable_points(end+1) = current_p;
                  end
              end
          end
          
          % Plot with black line and unique marker
          marker_idx = mod(i-1, length(marker_styles_right)) + 1;
          line_idx = mod(floor((i-1)/length(marker_styles_right)), length(line_styles)) + 1;
          
          plot(power_values_full, y_data_damp, ...
               'Color', [0 0 0], ...
               'LineStyle', line_styles{line_idx}, ...
               'LineWidth', 1.5, ...
               'Marker', marker_styles_right{marker_idx}, ...
               'MarkerSize', 7, ...
               'MarkerFaceColor', [1 1 1], ...
               'MarkerEdgeColor', [0 0 0], ...
               'DisplayName', sprintf('$V_{\\mathrm{pcc}}$ = %.3f pu', current_vpcc));
          
          if ~isempty(unstable_points)
              plot(unstable_points, zeros(size(unstable_points)), 'x', ...
                   'Color', [0 0 0], 'MarkerSize', 10, 'LineWidth', 2, ...
                   'HandleVisibility', 'off');
          end
      end
      
      hold off;
      title(title_right, 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);
      xlabel('DFIG Power (pu)', 'Interpreter', 'latex', 'FontSize', 9, 'Color', [0 0 0]);
      legend('show', 'Location', 'best', 'Interpreter', 'latex', 'FontSize', 7);
      set(gca, 'FontName', 'Times New Roman', 'FontSize', 8, ...
               'XColor', [0 0 0], 'YColor', [0 0 0]);

      %------------------------------------------------------------------
      % Step 4: Link Axes and Apply IEEE Formatting
      %------------------------------------------------------------------
      % Link x-axes for consistent power scale
      linkaxes(ax_handles, 'x');
      xlim(ax_handles(1), [min(power_values_full), max(power_values_full)]);
      
      % Apply IEEE publication formatting (double-column: 7.16 x 4.0 in)
      format_figure_for_publication(figure(1), 7.16, 4.0)

      %------------------------------------------------------------------
      % Step 5: Display Comprehensive Statistics
      %------------------------------------------------------------------
      fprintf('\n');
      fprintf('╔════════════════════════════════════════════════════════════╗\n');
      fprintf('║  CASE 20: Comparative Analysis - Results Summary          ║\n');
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  LEFT COLUMN: SCR Influence (at Vpcc=%.3f pu)            ║\n', min_vpcc);
      fprintf('║    - SCR values analyzed:    %-29d ║\n', length(scr_values));
      fprintf('║    - SCR range:              %.2f - %.2f                    ║\n', ...
              stats.scr_range(1), stats.scr_range(2));
      fprintf('║    - Unstable points found:  %-29d ║\n', stats.unstable_count_left);
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  RIGHT COLUMN: Vpcc Influence (at SCR=1.00)               ║\n');
      fprintf('║    - Vpcc values analyzed:   %-29d ║\n', length(vpcc_values));
      fprintf('║    - Vpcc range:             %.3f - %.3f pu                ║\n', ...
              stats.vpcc_range(1), stats.vpcc_range(2));
      fprintf('║    - Unstable points found:  %-29d ║\n', stats.unstable_count_right);
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Stability Metrics Ranges:                                 ║\n');
      fprintf('║    - Max Real Eigenvalue:    %.4f to %.4f rad/s       ║\n', ...
              stats.eig_range(1), stats.eig_range(2));
      fprintf('║    - Min Damping Ratio:      %.4f to %.4f              ║\n', ...
              stats.damp_range(1), stats.damp_range(2));
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Power Levels Analyzed:      %-29d ║\n', length(power_values_full));
      fprintf('║  Power Range:                %.3f - %.3f pu                ║\n', ...
              min(power_values_full), max(power_values_full));
      fprintf('╠════════════════════════════════════════════════════════════╣\n');
      fprintf('║  Figure Layout: 2x2 comparative analysis                  ║\n');
      fprintf('║  Plot Format: IEEE B&W (black lines, distinct markers)    ║\n');
      fprintf('║  X-axes: Linked for direct comparison                     ║\n');
      fprintf('║  IEEE Formatting: Applied                                  ║\n');
      fprintf('╚════════════════════════════════════════════════════════════╝\n');
      fprintf('\n');

   %======================================================================
   % CASE 21: Simplified Step Response - 4 Key Controllers with Colored Endpoints
   %======================================================================
   % PURPOSE:
   %   Publication-quality step response visualization focusing on 4 key
   %   controllers (VSMP, VSMQ, RSCd, GSCd) with distinct colors for each
   %   endpoint condition to facilitate visual identification of operating
   %   point influence on control performance.
   %
   % ANALYSIS TYPE:
   %   Optimized for ENDPOINTS analysis (8 operating points)
   %   Compatible with SWEEP but may have visual clutter
   %
   % METHODOLOGY:
   %   1. Extract complementary sensitivity T(s) for 4 key controllers
   %   2. Assign distinct colors to each endpoint (8 colors for DFIG 1)
   %   3. Generate 4×1 vertical subplot layout for publication clarity
   %   4. Legend removed - see separate LaTeX table for endpoint details
   %
   % CONTROLLERS ANALYZED (reduced from 7 to 4):
   %   - VSMP: Virtual Synchronous Machine active power (outer loop)
   %   - VSMQ: Virtual Synchronous Machine reactive power (outer loop)
   %   - RSCd: Rotor-side converter d-axis current (inner loop)
   %   - GSCd: Grid-side converter d-axis current (inner loop)
   %
   % RATIONALE FOR CONTROLLER SELECTION:
   %   - VSMP/VSMQ: Critical outer loops for grid-forming behavior
   %   - RSCd/GSCd: Representative fast inner current loops (d-axis)
   %   - Omitted: RSCq, VDC, GSCq (similar dynamics to included loops)
   %
   % DFIGs ANALYZED:
   %   - DFIG 1: SCR_transformer = 10 (strong connection) - Solid lines
   %
   % COLOR SCHEME (8 endpoints):
   %   Distinguishable palette designed for color-blind accessibility:
   %   - EP1: Blue [0 0.447 0.741]
   %   - EP2: Red [0.85 0.325 0.098]
   %   - EP3: Yellow [0.929 0.694 0.125]
   %   - EP4: Purple [0.494 0.184 0.556]
   %   - EP5: Green [0.466 0.674 0.188]
   %   - EP6: Cyan [0.301 0.745 0.933]
   %   - EP7: Magenta [0.635 0.078 0.184]
   %   - EP8: Orange [0.8 0.4 0]
   %
   % LEGEND:
   %   Removed from figure - see separate LaTeX table in PAPERS directory
   %   Table provides color-coded endpoint parameters for publication
   %
   % OUTPUTS:
   %   - Figure: 4×1 subplots (vertical layout, ~800×1000 pixels)
   %   - Total curves: 8 (8 endpoints for DFIG 1)
   %   - Legend table: legend_table_case21.pdf in PAPERS directory
   %
   % INTERPRETATION:
   %   - Color grouping reveals operating point effects on control performance
   %   - DFIG 1 selected due to strong grid connection (SCR_transformer=10)
   %   - Vertical layout provides better time-domain resolution
   %   - See legend table for precise endpoint parameter identification
   %----------------------------------------------------------------------
    case 21  % Simplified 4-controller step response with colored endpoints
   %----------------------------------------------------------------------
       % Step 1: Select DFIGs and controllers
       %----------------------------------------------------------------------
       hDFIG = 1;  % DFIG 1 (SCR_transformer=10, strong grid connection)

       % Select 4 key controllers: VSMP(1), VSMQ(2), RSCd(3), GSCd(6)
       selected_controllers = [1, 2, 3, 6];
       num_controllers = length(selected_controllers);

       % Time horizons for each selected controller
       tfin_full = [1.5; 3.0; 0.01; 0.01; 0.1; 0.01; 0.01];
       tfin = tfin_full(selected_controllers);

       % Labels for selected controllers
       ControlLabel_selected = ControlLabel(selected_controllers);
       OutputLabel_selected = OutputLabel(selected_controllers);

       %----------------------------------------------------------------------
       % Step 2: Define color palette for endpoints (color-blind friendly)
       %----------------------------------------------------------------------
       % 8 distinct colors for 8 endpoints
       endpoint_colors = [
           0.000, 0.447, 0.741;  % EP1: Blue
           0.850, 0.325, 0.098;  % EP2: Red
           0.929, 0.694, 0.125;  % EP3: Yellow
           0.494, 0.184, 0.556;  % EP4: Purple
           0.466, 0.674, 0.188;  % EP5: Green
           0.301, 0.745, 0.933;  % EP6: Cyan
           0.635, 0.078, 0.184;  % EP7: Magenta
           0.800, 0.400, 0.000;  % EP8: Orange
       ];

       %----------------------------------------------------------------------
       % Step 3: Create figure with 4×1 vertical layout
       %----------------------------------------------------------------------
       figure('Name', 'Case 21: Simplified Step Response (4 Controllers)', ...
              'Position', [100, 100, 800, 1000], ...
              'Color', 'white');

       % Preallocate storage for legend entries (8 curves = 8 endpoints for DFIG 1)
       max_legend_entries = numOP;
       legend_handles = gobjects(max_legend_entries, 1);
       legend_labels = cell(max_legend_entries, 1);
       legend_counter = 0;

       %----------------------------------------------------------------------
       % Step 4: Generate step response plots
       %----------------------------------------------------------------------
       for ctrl_idx = 1:num_controllers
           nn = selected_controllers(ctrl_idx);  % Actual controller index

           subplot(num_controllers, 1, ctrl_idx)
           hold on

           % Loop over endpoints
           for jj = 1:numOP
               % Skip unstable operating points
               if LIN_MODEL{jj}.stability == 0
                   continue
               end

               % Extract state-space model
               ssModel = LIN_MODEL{jj}.ssModel;
               matA = ssModel.a;
               matB = ssModel.b;
               matC = ssModel.c;
               matD = ssModel.d;

               % Extract complementary sensitivity T(s) for DFIG 1
               indT = nCONTROL*(hDFIG-1) + nn;
               Tss = ss(matA, matB(:,indT), matC(indT,:), matD(indT,indT));

               % Compute step response
               t = linspace(0, tfin(ctrl_idx), 5000);
               y = step(-Tss, t);

               % Plot with endpoint-specific color (solid line)
               h = plot(t, y, 'LineWidth', 2.0, ...
                        'Color', endpoint_colors(jj,:), ...
                        'LineStyle', '-');

               % Store legend info (only for first subplot)
               if ctrl_idx == 1
                   % Extract endpoint parameters
                   Vpcc_ep = OPset.Vpcc(jj);
                   Pdfig_ep = OPset.Pdfig(jj);
                   SCRgrid_ep = OPset.SCRgrid(jj);

                   % Create legend label (DFIG 1 only)
                   legend_label = sprintf('EP%d (V=%.2f, P=%.2f, SCR=%.1f)', ...
                                      jj, Vpcc_ep, Pdfig_ep, SCRgrid_ep);

                   % Store in preallocated arrays
                   legend_counter = legend_counter + 1;
                   legend_handles(legend_counter) = h;
                   legend_labels{legend_counter} = legend_label;
               end
           end

           % Subplot formatting
           xlim([0 tfin(ctrl_idx)]);
           xlabel('$t$ (s)', 'Interpreter', 'latex', 'FontSize', 12);
           ylabel(OutputLabel_selected{ctrl_idx}, 'Interpreter', 'latex', 'FontSize', 12);
           title(ControlLabel_selected{ctrl_idx}, 'Interpreter', 'latex', ...
                 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
           grid on
           set(gca, 'FontName', 'Times New Roman', 'FontSize', 11, ...
                    'Color', 'white', 'XColor', 'k', 'YColor', 'k', ...
                    'LineWidth', 1.2);

           % Legend removed - see separate LaTeX table in PAPERS folder
           % if ctrl_idx == 1
           %     legend_handles_trimmed = legend_handles(1:legend_counter);
           %     legend_labels_trimmed = legend_labels(1:legend_counter);
           %     leg = legend(legend_handles_trimmed, legend_labels_trimmed, ...
           %                 'Interpreter', 'latex', 'FontSize', 8, ...
           %                 'Location', 'eastoutside', 'NumColumns', 1);
           %     title(leg, 'Operating Points', 'FontSize', 9);
           % end

           hold off
       end

       %----------------------------------------------------------------------
       % Step 5: Display endpoint summary table
       %----------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 21: Simplified Step Response (4 Controllers)           ║\n');
       fprintf('╠═══════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Endpoints Analyzed: %-3d                                     ║\n', numOP);
       fprintf('║  DFIGs Analyzed: DFIG 1 only (SCR_transformer=10)            ║\n');
       fprintf('║  Controllers: VSMP, VSMQ, RSCd, GSCd                          ║\n');
       fprintf('║  Total Curves: %-3d (8 endpoints for DFIG 1)                 ║\n', numOP);
       fprintf('╠═══════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Color Coding: 8 distinct colors for endpoints               ║\n');
       fprintf('║  Line Style: Solid lines for all curves                      ║\n');
       fprintf('║  Legend: Removed (see legend_table_case21.pdf in PAPERS)     ║\n');
       fprintf('╚═══════════════════════════════════════════════════════════════╝\n');
       fprintf('\nEndpoint Parameters:\n');
       disp(OPset);

   %======================================================================
   % CASE 22: Load Disturbance Response - Colored Endpoints (4×1 Layout)
   %======================================================================
   % PURPOSE:
   %   Publication-quality load disturbance response with colored endpoints
   %   Similar to Case 6 but with 4×1 vertical layout and color-coded
   %   operating points for better visual identification.
   %
   % ANALYSIS TYPE:
   %   Optimized for ENDPOINTS analysis (8 operating points)
   %   Load rejection capability: frequency and voltage response
   %
   % METHODOLOGY:
   %   1. Compute step responses to active/reactive load disturbances
   %   2. Assign distinct colors to each endpoint (8 colors for DFIG 1)
   %   3. Generate 4×1 vertical subplot layout
   %   4. Calculate ROCOF/ROCOV and nadir metrics
   %
   % SUBPLOTS (4×1 layout):
   %   1. Active load step → Frequency response
   %   2. Active load step → PCC voltage response
   %   3. Reactive load step → Frequency response
   %   4. Reactive load step → PCC voltage response
   %
   % DFIGs ANALYZED:
   %   - DFIG 1: SCR_transformer = 10 (strong connection)
   %
   % COLOR SCHEME (8 endpoints):
   %   Same as Case 21 - color-blind accessible palette
   %
   % LEGEND:
   %   Removed from figure - see separate LaTeX table in PAPERS directory
   %
   % OUTPUTS:
   %   - Figure: 4×1 subplots (vertical layout)
   %   - Metrics: ROCOF, ROCOV, frequency nadir, voltage nadir
   %   - Legend table: legend_table_case22.pdf in PAPERS directory
   %----------------------------------------------------------------------
    case 22  % Load disturbance response with colored endpoints
   %----------------------------------------------------------------------
       %-------------------------------------------------------------------
       % Step 1: Configuration
       %-------------------------------------------------------------------
       hDFIG = 1;  % DFIG 1 only

       % Time vectors for step response
       t = {linspace(0, 15, 500);    % Active load: frequency
            linspace(0, 15, 5000)};  % Reactive load: voltage

       % Y-axis limits for each subplot [min, max]
       ylim_range = [-0.004  0;    % Subplot 1: Active → Frequency
                     0  0.35;      % Subplot 2: Active → Voltage
                     0  0.003;     % Subplot 3: Reactive → Frequency
                     0  0.7];      % Subplot 4: Reactive → Voltage

       % Output labels and titles
       outLabel = {'Frequency (pu)', 'PCC voltage (pu)'};
       titleLabel = {'Active load step', 'Reactive load step'};

       % Color palette (8 endpoints)
       endpoint_colors = [
           0.000, 0.447, 0.741;  % EP1: Blue
           0.850, 0.325, 0.098;  % EP2: Red
           0.929, 0.694, 0.125;  % EP3: Yellow
           0.494, 0.184, 0.556;  % EP4: Purple
           0.466, 0.674, 0.188;  % EP5: Green
           0.301, 0.745, 0.933;  % EP6: Cyan
           0.635, 0.078, 0.184;  % EP7: Magenta
           0.800, 0.400, 0.000;  % EP8: Orange
       ];

       %-------------------------------------------------------------------
       % Step 2: Initialize metrics arrays
       %-------------------------------------------------------------------
       ROCOX = NaN(numOP, 2);  % [ROCOF, ROCOV]
       nadir = NaN(numOP, 2);  % [nadir_f, nadir_V]

       %-------------------------------------------------------------------
       % Step 3: Create figure with 4×1 layout
       %-------------------------------------------------------------------
       figure('Name', 'Case 22: Load Disturbance Response (Colored Endpoints)', ...
              'Position', [100, 100, 800, 1000], ...
              'Color', 'white');

       %-------------------------------------------------------------------
       % Step 4: Generate plots - 4×1 layout
       %-------------------------------------------------------------------
       % Loop structure: 4 subplots (disturbance type × output type)
       for subplot_idx = 1:4
           % Determine disturbance type and output type
           % Layout: [1: Active→Freq, 2: Active→Volt, 3: Reactive→Freq, 4: Reactive→Volt]
           if subplot_idx <= 2
               ii = 1;  % Active load disturbance
               jj = subplot_idx;  % Output: 1=Frequency, 2=Voltage
           else
               ii = 2;  % Reactive load disturbance
               jj = subplot_idx - 2;  % Output: 1=Frequency, 2=Voltage
           end

           subplot(4, 1, subplot_idx)
           hold on

           % Loop over endpoints
           for kk = 1:numOP
               % Skip unstable operating points
               if LIN_MODEL{kk}.stability == 0
                   continue
               end

               % Extract state-space model
               ssModel = LIN_MODEL{kk}.ssModel;
               matA = ssModel.a;
               matB = ssModel.b;
               matC = ssModel.c;
               matD = ssModel.d;

               % Matrix indices
               % Input: load disturbances (active=1, reactive=2)
               indI = nCONTROL*nDFIG + 8 + ii;

               % Output: frequency (1) or PCC voltage (2)
               indO = 2*nCONTROL*nDFIG + jj;

               % Build transfer function
               Fss = ss(matA, matB(:,indI), matC(indO,:), matD(indO,indI));

               % Compute step response
               y = step(Fss, t{jj});

               % Plot with endpoint color
               plot(t{jj}, y, 'LineWidth', 2.0, ...
                    'Color', endpoint_colors(kk,:), ...
                    'LineStyle', '-');

               %-----------------------------------------------------------
               % Compute performance metrics
               %-----------------------------------------------------------
               % ROCOF: Active load → Frequency (ii==1, jj==1)
               % ROCOV: Reactive load → Voltage (ii==2, jj==2)
               if (ii==1 && jj==1) || (ii==2 && jj==2)
                   % Half-rise time for rate estimation
                   [~, ind] = min(abs(y - y(end)/2));

                   % Rate of change [pu/s]
                   ROCOX(kk, jj) = abs(y(ind) / t{jj}(ind));

                   % Maximum deviation (nadir) [pu]
                   nadir(kk, jj) = max(abs(y));
               end
           end
           hold off

           %----------------------------------------------------------------
           % Subplot formatting
           %----------------------------------------------------------------
           xlabel('Time (s)', 'Interpreter', 'latex', 'FontSize', 12);
           ylabel(outLabel{jj}, 'Interpreter', 'latex', 'FontSize', 12);
           title(titleLabel{ii}, 'Interpreter', 'latex', ...
                 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
           xlim([0 t{jj}(end)])

           % Set Y-axis limits
           if ~isempty(ylim_range)
               ylim(ylim_range(subplot_idx, :))
           end

           grid on
           set(gca, 'FontName', 'Times New Roman', 'FontSize', 11, ...
                    'Color', 'white', 'XColor', 'k', 'YColor', 'k', ...
                    'LineWidth', 1.2);
       end

       %-------------------------------------------------------------------
       % Step 5: Display metrics summary
       %-------------------------------------------------------------------
       fprintf('\n');
       fprintf('╔═══════════════════════════════════════════════════════════════╗\n');
       fprintf('║  CASE 22: Load Disturbance Response (Colored Endpoints)      ║\n');
       fprintf('╠═══════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Endpoints Analyzed: %-3d                                     ║\n', numOP);
       fprintf('║  DFIGs Analyzed: DFIG 1 only (SCR_transformer=10)            ║\n');
       fprintf('║  Subplots: 4×1 (Active/Reactive × Frequency/Voltage)         ║\n');
       fprintf('╠═══════════════════════════════════════════════════════════════╣\n');
       fprintf('║  Color Coding: 8 distinct colors for endpoints               ║\n');
       fprintf('║  Legend: Removed (see legend_table_case22.pdf in PAPERS)     ║\n');
       fprintf('╚═══════════════════════════════════════════════════════════════╝\n');
       fprintf('\n');

       % Display metrics
       fprintf('Performance Metrics:\n');
       fprintf('  ROCOF (Active→Freq):   max=%.4f pu/s\n', max(ROCOX(:,1)));
       fprintf('  ROCOV (Reactive→Volt): max=%.4f pu/s\n', max(ROCOX(:,2)));
       fprintf('  Freq nadir:            max=%.4f pu\n', max(nadir(:,1)));
       fprintf('  Volt nadir:            max=%.4f pu\n', max(nadir(:,2)));
       fprintf('\nEndpoint Parameters:\n');
       disp(OPset);

   %======================================================================
   % CASE 23: Per-Band Eigenvalue Stability Envelope - IEEE Paper Format
   %======================================================================
   % PURPOSE:
   %   Generates publication-quality per-band stability analysis showing
   %   minimum damping ratio in each frequency band (LF, MF, HF) plus
   %   aperiodic mode stability, versus dispatched power for different SCR.
   %
   % BAND BOUNDARIES (justified by spectral gap analysis):
   %   Aperiodic: Im(lambda) = 0 (real eigenvalues) -> voltage stability
   %   LF:  |Im(lambda)| in (0, 85] rad/s  -> VSM P-Q interaction
   %   MF:  |Im(lambda)| in (85, 665] rad/s -> power swing + current loops
   %   HF:  |Im(lambda)| in (665, 3000] rad/s -> current loop resonances
   %   Spurious: |Im(lambda)| > 3000 rad/s -> excluded (PCC parasitics)
   %
   % LAYOUT: 2x2 subplots (Aperiodic | LF | MF | HF) vs power, per SCR
   %----------------------------------------------------------------------
    case 23
   %----------------------------------------------------------------------
      % Band boundaries (rad/s) — consistent with OPTIMIZER.m eigenConfig
      BND_LF_MF  = 100;   % LF ≤ 100 rad/s (grid/electromechanical modes)
      BND_MF_HF  = 500;   % MF = (100, 500] rad/s (VSM power loops)
      BND_SPUR   = 3000;  % Spurious > 3000 rad/s (PCC parasitics)

      % Target SCR values for plotting (match GA multi-endpoint: 1, 2, 3)
      target_scr = [1.0, 2.0, 3.0];

      % Extract unique parameter values
      vpcc_all   = table2array(OPset(:,1));
      power_all  = table2array(OPset(:,2));
      scr_all    = table2array(OPset(:,3));

      power_values = unique(power_all);
      vpcc_values  = unique(vpcc_all);

      % Use stability-boundary voltage (matches OPTIMIZER worst-case OP)
      target_vpcc = 0.975;

      % IEEE B&W: 3 SCR curves with distinct grayscale + markers
      nSCR = length(target_scr);
      grays     = {[0 0 0], [0.4 0.4 0.4], [0.65 0.65 0.65]};  % black, dark gray, light gray
      markers   = {'o', 's', 'd'};
      lstyles   = {'-', '--', '-.'};
      lineWidth = 1.2;
      markerSz  = 4;

      % Pre-allocate: rows=power, cols=SCR, depth=band
      nP = length(power_values);
      zeta_LF   = NaN(nP, nSCR);
      zeta_MF   = NaN(nP, nSCR);
      zeta_HF   = NaN(nP, nSCR);
      sigma_AP  = NaN(nP, nSCR);  % max Re(lambda) of real eigenvalues

      % Compute per-band metrics
      for iSCR = 1:nSCR
          for pp = 1:nP
              % Find operating point (worst voltage for this SCR, power)
              idx = find(abs(vpcc_all - target_vpcc) < 0.001 & ...
                         abs(power_all - power_values(pp)) < 0.01 & ...
                         abs(scr_all - target_scr(iSCR)) < 0.01);
              if isempty(idx), continue; end
              idx = idx(1);

              if ~LIN_MODEL{idx}.stability
                  % Mark unstable: leave NaN (will show as gap in plot)
                  continue;
              end

              z = LIN_MODEL{idx}.eigenvalues;
              omega_abs = abs(imag(z));
              zetaV = -real(z) ./ abs(z);

              % Aperiodic modes (real eigenvalues)
              mask_real = omega_abs < 1e-6;
              if any(mask_real)
                  sigma_AP(pp, iSCR) = max(real(z(mask_real)));
              end

              % LF band: 0 < |Im| <= BND_LF_MF
              mask_lf = omega_abs > 1e-6 & omega_abs <= BND_LF_MF;
              if any(mask_lf)
                  zeta_LF(pp, iSCR) = min(zetaV(mask_lf));
              end

              % MF band: BND_LF_MF < |Im| <= BND_MF_HF
              mask_mf = omega_abs > BND_LF_MF & omega_abs <= BND_MF_HF;
              if any(mask_mf)
                  zeta_MF(pp, iSCR) = min(zetaV(mask_mf));
              end

              % HF band: BND_MF_HF < |Im| <= BND_SPUR
              mask_hf = omega_abs > BND_MF_HF & omega_abs <= BND_SPUR;
              if any(mask_hf)
                  zeta_HF(pp, iSCR) = min(zetaV(mask_hf));
              end
          end
      end

      % ---- FIGURE ----
      fig23 = figure(1);
      format_figure_for_publication(fig23, 7.16, 4.5);

      % Subplot titles and data
      titles = {'(a) Aperiodic modes', ...
                '(b) LF band ($|\omega| \leq 100$ rad/s)', ...
                '(c) MF band ($100 < |\omega| \leq 500$ rad/s)', ...
                '(d) HF band ($500 < |\omega| \leq 3000$ rad/s)'};
      % Panel (a) reports the DISTANCE of the rightmost real eigenvalue from
      % the imaginary axis, min|Re(lambda)| = |max Re(lambda)| for a stable
      % system.  That is what the manuscript caption of Fig. 7 states, so
      % plot the positive quantity and reverse the axis (0 on top) —
      % 2026-08-27.
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

          % Horizontal reference line
          if sp == 1
              yline(0, 'r--', 'LineWidth', 0.8);  % stability boundary
              set(gca, 'YDir', 'reverse');  % 0 on top; distance to jw axis grows downwards
          end

          xlabel('$P$ (pu)', 'Interpreter', 'latex', 'FontSize', 8);
          ylabel(ylabels{sp}, 'Interpreter', 'latex', 'FontSize', 8);
          title(titles{sp}, 'Interpreter', 'latex', 'FontSize', 9);

          set(gca, 'FontSize', 7, 'TickLabelInterpreter', 'latex');
          xlim([min(power_values) max(power_values)]);

          % Legend only in first subplot
          if sp == 1
              leg_entries = cell(1, nSCR);
              for iSCR = 1:nSCR
                  leg_entries{iSCR} = sprintf('SCR = %.0f', target_scr(iSCR));
              end
              lgd23 = legend(hPlots, leg_entries, 'Interpreter', 'latex', 'FontSize', 6, ...
                     'Orientation', 'horizontal');
          end
      end

      % Position legend centered in the gap between subplot rows
      drawnow;
      ax_top = subplot(2,2,1);  % top-left subplot
      ax_bot = subplot(2,2,3);  % bottom-left subplot
      pos_top = get(ax_top, 'Position');
      pos_bot = get(ax_bot, 'Position');
      gap_bottom = pos_bot(2) + pos_bot(4);  % top edge of bottom subplot
      gap_top = pos_top(2);                   % bottom edge of top subplot
      gap_center = (gap_bottom + gap_top) / 2;
      lgd23.Units = 'normalized';
      lp23 = lgd23.Position;
      lp23(1) = 0.5 - lp23(3)/2 + 0.02;     % center + slight right shift
      lp23(2) = gap_center - lp23(4)/2;      % center in gap
      lgd23.Position = lp23;

      % Export (exportgraphics auto-crops whitespace)
      paperDir = '../PAPERS/Paper_VSM_DFIG_Optimization_Robustness/figures/';
      outFile = [paperDir 'baseline_perband_stability_envelope.pdf'];
      set(fig23, 'Color', 'white');
      set(fig23, 'InvertHardcopy', 'off');
      exportgraphics(fig23, outFile, 'ContentType', 'vector', 'BackgroundColor', 'white');
      fprintf('Exported: %s\n', outFile);

      % Summary
      fprintf('\n=== CASE 23: Per-Band Stability Envelope ===\n');
      fprintf('Band boundaries: LF/MF = %d rad/s, MF/HF = %d rad/s, Spurious = %d rad/s\n', ...
              BND_LF_MF, BND_MF_HF, BND_SPUR);
      fprintf('Voltage condition: Vpcc = %.3f pu (worst case)\n', target_vpcc);
      fprintf('SCR values: '); fprintf('%.0f ', target_scr); fprintf('\n');
      fprintf('Power range: %.2f - %.2f pu\n', min(power_values), max(power_values));
      for iSCR = 1:nSCR
          fprintf('SCR=%.0f: zeta_LF_min=%.4f, zeta_MF_min=%.4f, zeta_HF_min=%.4f, sigma_AP_max=%.4f\n', ...
              target_scr(iSCR), min(zeta_LF(:,iSCR)), min(zeta_MF(:,iSCR)), ...
              min(zeta_HF(:,iSCR)), max(sigma_AP(:,iSCR)));
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
    % Get the directory where this script is located (PLOT_FILES)
    script_path = fileparts(mfilename('fullpath'));
    % Navigate to project root (one level up from PLOT_FILES)
    project_root = fileparts(script_path);
    base_export_dir = fullfile(project_root, 'FIGURES', 'PLOT_LIN_MODEL_ARRAY');

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

        % Apply publication formatting (preserve case-specific size)
        cur_pos = get(fig_handle, 'Position');
        format_figure_for_publication(fig_handle, cur_pos(3), cur_pos(4));

        % Generate descriptive filename: SLUG_##_DescriptiveName[_Fig#]
        if length(all_figs) == 1
            % Single figure
            filename_base = sprintf('%s_%02d_%s', slug, figureType, base_name);
        else
            % Multiple figures
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

end  % End of main function PLOT_LIN_MODEL_ARRAY

%==========================================================================
% LOCAL FUNCTION: Apply publication formatting to figure
%==========================================================================
function format_figure_for_publication(fig_handle, target_width, target_height)
% FORMAT_FIGURE_FOR_PUBLICATION - Apply IEEE publication standards to figure
%
% SYNTAX:
%   format_figure_for_publication(fig_handle)                    % Legacy (10x7 in)
%   format_figure_for_publication(fig_handle, width_in, height_in)  % IEEE target size
%
% IEEE STANDARD WIDTHS:
%   Single-column: 3.5 in (88.9 mm)
%   Double-column: 7.16 in (181.6 mm)
%
% The figure is exported at the EXACT target size so that fonts (8-10pt)
% appear at the correct size in the final paper without LaTeX scaling.

    % Default to legacy size if not specified
    if nargin < 2, target_width  = 10;  end
    if nargin < 3, target_height = 7;   end

    % Set figure properties - WHITE BACKGROUND
    set(fig_handle, 'Color', 'white');
    set(fig_handle, 'InvertHardcopy', 'off');  % Preserve colors when saving
    set(fig_handle, 'Units', 'inches');

    % Set figure to EXACT target size for IEEE publication
    fig_pos = get(fig_handle, 'Position');
    set(fig_handle, 'Position', [fig_pos(1:2), target_width, target_height]);

    % Paper settings for export - MUST match figure size
    set(fig_handle, 'PaperPositionMode', 'auto');
    set(fig_handle, 'PaperUnits', 'inches');
    set(fig_handle, 'PaperSize', [target_width, target_height]);

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
% GET_FIGURE_SUBFOLDER_NAMES - Returns subfolder names for FIGURES/PLOT_LIN_MODEL_ARRAY/
%
% Maps figure types to existing subdirectory structure in FIGURES/PLOT_LIN_MODEL_ARRAY/

    subfolder_names = {
        "01_StepResponse"           % Case 1  - Step response
        "02_FreqPCC_RefSteps"       % Case 2  - Freq/PCC ref steps
        "03_Plant_Nichols"          % Case 3  - Plant Nichols
        "04_Sensitivity"            % Case 4  - Sensitivity
        "05_ClosedLoop_Bode"        % Case 5  - Closed-loop Bode
        "06_FreqPCC_LoadSteps"      % Case 6  - Freq/PCC load steps
        "07_Heatmap_DampingRatio"   % Case 7  - Damping ratio heatmap
        "08_Heatmap_NaturalFreq"    % Case 8  - Natural frequency heatmap
        "09_Heatmap_MaxRealEig"     % Case 9  - Max real eigenvalue
        "10_Heatmap_FastModes"      % Case 10 - Fast modes damping
        "11_Heatmap_TimeConstant"   % Case 11 - Time constant
        "12_Heatmap_LineAngle"      % Case 12 - Line angle
        "13_Heatmap_WindSpeed"      % Case 13 - Wind speed
        "14_Heatmap_RotorSpeed"     % Case 14 - Rotor speed
        "15_RootLocus_Power"        % Case 15 - Root locus power
        "16_RootLocus_Voltage"      % Case 16 - Root locus voltage
        "17_RootLocus_SCR"          % Case 17 - Root locus SCR
        "18_StabilityMap"           % Case 18 - Stability map
        "19_LineAngle_vs_Power"     % Case 19 - Line angle vs power
        "20_Comparative_Analysis"   % Case 20 - Comparative analysis
        "21_StepResponse_Simplified"% Case 21 - Simplified 4-controller step response
        "22_LoadDisturbance_Colored"% Case 22 - Load disturbance with colored endpoints
        "23_PerBand_Stability"      % Case 23 - Per-band eigenvalue stability envelope
    };
end

%==========================================================================
% HELPER FUNCTION: Get descriptive names for each case
%==========================================================================
function case_names = get_case_descriptive_names()
% GET_CASE_DESCRIPTIVE_NAMES - Returns descriptive names for figure export
%
% Returns cell array with publication-ready names for each of the 23 cases

    case_names = {
        "ClosedLoop_StepResponse"       % Case 1  - Step response
        "FreqPCC_PowerRefSteps"         % Case 2  - Freq/PCC ref steps
        "Plant_OpenLoop_Nichols"        % Case 3  - Plant Nichols
        "Sensitivity_Functions"         % Case 4  - Sensitivity S(s), T(s)
        "ClosedLoop_FreqResponse"       % Case 5  - Closed-loop Bode
        "FreqPCC_LoadSteps"             % Case 6  - Freq/PCC load steps
        "Heatmap_DampingRatio"          % Case 7  - Damping ratio heatmap
        "Heatmap_NaturalFrequency"      % Case 8  - Natural frequency
        "Heatmap_MaxRealEigenvalue"     % Case 9  - Max real eigenvalue
        "Heatmap_FastModes_Damping"     % Case 10 - Fast modes damping
        "Heatmap_TimeConstant"          % Case 11 - Time constant
        "Heatmap_LineAngle"             % Case 12 - Line angle
        "Heatmap_WindSpeed"             % Case 13 - Wind speed
        "Heatmap_RotorSpeed"            % Case 14 - Rotor speed
        "RootLocus_ActivePower"         % Case 15 - Root locus power
        "RootLocus_PCCVoltage"          % Case 16 - Root locus voltage
        "RootLocus_SCR"                 % Case 17 - Root locus SCR
        "StabilityMap_Binary"           % Case 18 - Stability map
        "LineAngle_vs_Power"            % Case 19 - Line angle vs power
        "Comparative_Analysis"          % Case 20 - Comparative analysis
        "StepResponse_4Controllers"     % Case 21 - Simplified step response (4 controllers)
        "LoadDisturbance_4Subplots"     % Case 22 - Load disturbance colored endpoints (4×1)
        "PerBand_Stability_Envelope"    % Case 23 - Per-band eigenvalue stability envelope
    };
end
