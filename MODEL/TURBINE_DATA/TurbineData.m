%==========================================================================
% TURBINE DATA PROCESSING AND COEFFICIENT EXTRACTION
%==========================================================================
% Purpose: Process wind turbine power coefficient (Cp) curves from raw data
%          and generate polynomial approximation for use in system models
%
% Inputs:  Cp_Pitch_*.mat files (power coefficient vs tip speed ratio data)
% Outputs: TurbineData.mat (structure with turbine parameters and Cp model)
%
% Author:  Power Systems Research Group
% Date:    2025-01-15 (Optimized)
%==========================================================================

clear
clc
close('all')

% Add path to plotting utilities if needed
if ~exist('data2figCoord', 'file')
    addpath('../../PLOT_FILES/SCRIPTS');
end

%==========================================================================
%% SECTION 1: Load Power Coefficient Curve Data
%==========================================================================
% Load experimental Cp(lambda, pitch) data from multiple pitch angles
% Data format: [lambda, Cp] for each pitch angle
%
% Lambda (λ): Tip speed ratio = (turbine speed × radius) / wind speed
% Cp: Power coefficient (dimensionless, theoretical max = 0.593 Betz limit)
% Pitch: Blade pitch angle in degrees
%--------------------------------------------------------------------------

% Initialize data arrays
Cp_aux = [];       % Power coefficient values
Lambda_aux = [];   % Tip speed ratio values
Pitch_aux = [];    % Pitch angle values

% Define pitch angles for which we have experimental data
pitch_angles = [1, 3, 5, 7, 9, 11, 13]; % degrees

% Load and concatenate data from all pitch angle files
fprintf('Loading power coefficient data...\n');
for pitch = pitch_angles
    % Load data file for current pitch angle
    filename = sprintf('Cp_Pitch_%d', pitch);
    data = load(filename);

    % Extract data (column 1: lambda, column 2: Cp)
    data_matrix = data.(filename);

    % Append to consolidated arrays
    Cp_aux = [Cp_aux; data_matrix(:,2)];              % Cp values
    Lambda_aux = [Lambda_aux; data_matrix(:,1)];      % Lambda values
    Pitch_aux = [Pitch_aux; pitch*ones(size(data_matrix,1),1)]; % Pitch values

    fprintf('  Loaded %s: %d data points\n', filename, size(data_matrix,1));
end
fprintf('Total data points loaded: %d\n\n', length(Cp_aux));

%==========================================================================
%% SECTION 2: Polynomial Curve Fitting
%==========================================================================
% Fit a 2D polynomial to the experimental Cp data:
% Cp(pitch, lambda) = Σ Σ a_ij * pitch^i * lambda^j  (i,j = 0 to 4)
%
% This creates a smooth analytical approximation for Cp at any pitch/lambda
% combination, enabling efficient interpolation in real-time simulations.
%--------------------------------------------------------------------------

fprintf('Performing polynomial curve fitting...\n');

% Build regression matrix for least-squares fitting
% Each column represents a term: pitch^i * lambda^j
n_data = length(Cp_aux);
n_terms = 5 * 5; % 5x5 polynomial (degree 4 in both variables)
R_mat = zeros(n_data, n_terms); % Preallocate for efficiency

col_idx = 1;
for ii = 0:4
    for jj = 0:4
        R_mat(:, col_idx) = (Pitch_aux.^ii) .* (Lambda_aux.^jj);
        col_idx = col_idx + 1;
    end
end

% Solve least-squares problem: Cp_aux ≈ R_mat * a_ij
% Uses MATLAB's backslash operator for efficient solution
aij = R_mat \ Cp_aux;

% Reshape coefficient vector into 5x5 matrix for easier indexing
% Cp_coeff_matrix(i+1,j+1) = coefficient for pitch^i * lambda^j
Cp_coeff_matrix = reshape(aij, [5, 5])';

fprintf('  Polynomial coefficients computed successfully\n');
fprintf('  Regression matrix size: %d × %d\n', size(R_mat,1), size(R_mat,2));
fprintf('  Coefficient matrix: 5×5 (degree 4 polynomial)\n\n');

%==========================================================================
%% SECTION 3: Generate High-Resolution Cp Surface
%==========================================================================
% Evaluate the fitted polynomial over a dense grid to visualize the
% Cp(pitch, lambda) surface and validate the curve fit quality.
%--------------------------------------------------------------------------

fprintf('Generating Cp surface for visualization...\n');

% Define evaluation grid
N_lambda = 500;                      % Number of lambda points
Lambda_data = linspace(0, 20, N_lambda)'; % Tip speed ratio range
Pitch_data = 1:2:13;                 % Pitch angles [deg] (1, 3, 5, ..., 13)
N_pitch = length(Pitch_data);

% Create meshgrid for 3D surface plotting
[Lambda_mat, Pitch_mat] = meshgrid(Lambda_data, Pitch_data);

% Vectorized polynomial evaluation (OPTIMIZED)
% Evaluate Cp = Σ Σ a_ij * pitch^i * lambda^j over entire grid
Cp_est = zeros(N_pitch, N_lambda);
for ii = 0:4
    for jj = 0:4
        % Vectorized computation across all grid points
        Cp_est = Cp_est + Cp_coeff_matrix(ii+1, jj+1) * ...
                 (Pitch_mat.^ii) .* (Lambda_mat.^jj);
    end
end

% Physical constraint: Cp cannot be negative
Cp_est(Cp_est < 0) = 0;

fprintf('  Surface generated: %d × %d grid points\n', N_pitch, N_lambda);
fprintf('  Cp range: [%.4f, %.4f]\n\n', min(Cp_est(:)), max(Cp_est(:)));

%==========================================================================
%% SECTION 4: Visualization - 3D Surface Plot
%==========================================================================
% Plot Cp as a function of tip speed ratio and pitch angle
%--------------------------------------------------------------------------

fig = figure(1);
clf; % Clear figure for clean redraw

surf(Lambda_mat, Pitch_mat, Cp_est, 'EdgeColor', 'none', 'FaceAlpha', 0.9)
xlabel('\lambda (Tip Speed Ratio)', 'FontSize', 12, 'FontWeight', 'bold')
ylabel('Pitch Angle (°)', 'FontSize', 12, 'FontWeight', 'bold')
zlabel('C_p (Power Coefficient)', 'FontSize', 12, 'FontWeight', 'bold')
title('Power Coefficient Surface: C_p(\lambda, pitch)', 'FontSize', 14)
colorbar('FontSize', 10)
colormap(jet) % Jet colormap works well in both light and dark modes
grid on
view(-37.5, 30) % Standard 3D view angle
set(gca, 'FontSize', 11, 'LineWidth', 1.5)
lighting gouraud
shading interp
fig.Position = [50 100 800 600]; % [left bottom width height] in pixels

%==========================================================================
%% SECTION 5: Visualization - 2D Cp Curves by Pitch Angle
%==========================================================================
% Plot Cp vs lambda for each pitch angle (family of curves)
%--------------------------------------------------------------------------

fig = figure(2);
clf; % Clear figure for clean redraw

% Plot curves with vibrant colors that work in both light and dark modes
% Using distinct, highly saturated colors for maximum visibility
colors = [
    0.8500 0.3250 0.0980;  % Red-Orange
    0.9290 0.6940 0.1250;  % Golden Yellow
    0.4660 0.6740 0.1880;  % Green
    0.0000 0.4470 0.7410;  % Blue
    0.4940 0.1840 0.5560;  % Purple
    0.8500 0.1000 0.5500;  % Magenta
    0.3010 0.7450 0.9330   % Cyan
];

hold on
for nn = 1:N_pitch
    plot(Lambda_data, Cp_est(nn,:), 'LineWidth', 2.5, 'Color', colors(nn,:), ...
         'DisplayName', sprintf('%d°', Pitch_data(nn)))
end
hold off

% Enhanced labels and formatting
xlabel('\lambda (Tip Speed Ratio)', 'FontSize', 12, 'FontWeight', 'bold')
ylabel('C_p (Power Coefficient)', 'FontSize', 12, 'FontWeight', 'bold')
title('Power Coefficient vs Tip Speed Ratio', 'FontSize', 14)
xlim([2 17])
ylim([0 0.5])
grid on
legend('Location', 'eastoutside', 'FontSize', 10)
set(gca, 'FontSize', 11, 'LineWidth', 1.5)

% Resize figure for better visibility on screen
fig.Position = [100 100 900 500]; % [left bottom width height] in pixels

%==========================================================================
%% SECTION 6: Turbine Operating Characteristics - Power Curves
%==========================================================================
% Generate mechanical power vs turbine speed curves for different wind
% speeds, showing MPPT (Maximum Power Point Tracking) trajectory
%
% Uses the aerodynamic power equation:
% P_m = (1/2) * ρ * π * R² * C_p(λ,β) * v_w³
%
% where: ρ = air density, R = turbine radius, v_w = wind speed
%        λ = tip speed ratio, β = pitch angle
%--------------------------------------------------------------------------

fprintf('Generating turbine power curves...\n');

% Turbine physical parameters
airDensity = 1.225;                    % Air density [kg/m³] at sea level
turbineRadius = 35;                    % Turbine radius [m]
ratedTurbinePower = 2e6;               % Rated power [W] = 2 MW
ratedWindSpeed = 12.5;                 % Rated wind speed [m/s]
ratedTurbineSpeed = 26.8 * pi / 30;    % Rated turbine speed [rad/s]

% Operating point ranges
windSpeed = 6:1:13;                    % Wind speed range [m/s]
windSpeedPlot = 8:1:13;                % Wind speeds to annotate
turbineSpeed = ratedTurbineSpeed * (0.4:0.01:1.3); % Turbine speed range [rad/s]

% Preallocate arrays for MPPT tracking
N1 = length(windSpeed);
N2 = length(turbineSpeed);
N3 = length(windSpeedPlot);
Pm_mppt = zeros(N1, 1);                % Maximum power for each wind speed
wt_mppt = zeros(N1, 1);                % Optimal turbine speed for MPPT
powerEnds = zeros(1, N3);              % Power at curve endpoints (for annotation)

% Generate power curves for pitch = 1° (maximum power extraction)
fig = figure(3);
clf; % Clear figure for clean redraw

pitch = 1; % Fixed pitch angle for MPPT operation

% Define vibrant colors for wind speed curves (works in both light/dark modes)
colors_wind = [
    0.8500 0.3250 0.0980;  % Red-Orange
    0.9290 0.6940 0.1250;  % Golden Yellow
    0.4660 0.6740 0.1880;  % Green
    0.0000 0.4470 0.7410;  % Blue
    0.3010 0.7450 0.9330;  % Cyan
    0.4940 0.1840 0.5560;  % Purple
    0.8500 0.1000 0.5500;  % Magenta
    0.6350 0.0780 0.1840   % Dark Red
];

hold on
for nn = 1:N1
    % Calculate tip speed ratio for current wind speed
    lambda = turbineSpeed * turbineRadius / windSpeed(nn);

    % Evaluate Cp using polynomial model (vectorized)
    Cp_aux = zeros(1, N2);
    for ii = 0:4
        for jj = 0:4
            Cp_aux = Cp_aux + Cp_coeff_matrix(ii+1, jj+1) * pitch^ii * lambda.^jj;
        end
    end

    % Calculate mechanical power in per-unit
    % P_m = (1/2) * Cp * ρ * π * R² * v_w³  [normalized by rated power]
    Pm = 0.5 * Cp_aux * (windSpeed(nn)^3) * airDensity * pi * turbineRadius^2 / ratedTurbinePower;
    Pm = Pm .* (Pm > 0); % Enforce non-negative power

    % Find maximum power point for MPPT trajectory
    [Pm_max, ind] = max(Pm);
    Pm_mppt(nn) = Pm_max;
    wt_mppt(nn) = turbineSpeed(ind) / ratedTurbineSpeed;

    % Plot curves with distinct colors
    plot(turbineSpeed / ratedTurbineSpeed, Pm, 'LineWidth', 2.5, ...
         'Color', colors_wind(nn,:), 'DisplayName', sprintf('%.1f m/s', windSpeed(nn)))
end

% Plot MPPT trajectory with thick white line with black edge (visible in both modes)
plot(wt_mppt, Pm_mppt, 'LineWidth', 5.0, 'Color', [1 1 1], ...
     'DisplayName', 'MPPT Trajectory')
plot(wt_mppt, Pm_mppt, '--', 'LineWidth', 3.0, 'Color', [0 0 0])
hold off

% Enhanced labels and formatting
xlabel('Turbine Speed (pu)', 'FontSize', 12, 'FontWeight', 'bold')
ylabel('Mechanical Power (pu)', 'FontSize', 12, 'FontWeight', 'bold')
title('Turbine Power Curves at Pitch = 1°', 'FontSize', 14)
xlim([0.4 1.49])
ylim([0 1.35])
grid on
legend('Location', 'eastoutside', 'FontSize', 9)
set(gca, 'FontSize', 11, 'LineWidth', 1.5)

% Resize figure for better visibility on screen
fig.Position = [100 150 950 500]; % [left bottom width height] in pixels

fprintf('  Power curves generated for wind speeds: %d to %d m/s\n', ...
        min(windSpeed), max(windSpeed));
fprintf('  MPPT trajectory computed\n\n');

%==========================================================================
%% SECTION 7: Package Results and Save Output
%==========================================================================
% Create turbineData structure with all parameters and polynomial model
% This structure is used by CONFIG_MODEL.m for system initialization
%--------------------------------------------------------------------------

fprintf('Packaging turbine data structure...\n');

% Create output structure with all turbine parameters
turbineData = struct();
turbineData.ratedTurbinePower = ratedTurbinePower;    % [W] Rated power
turbineData.ratedTurbineSpeed = ratedTurbineSpeed;    % [rad/s] Rated speed
turbineData.ratedWindSpeed = ratedWindSpeed;          % [m/s] Rated wind speed
turbineData.turbineRadius = turbineRadius;            % [m] Rotor radius
turbineData.airDensity = airDensity;                  % [kg/m³] Air density
turbineData.Cp_coeff_matrix = Cp_coeff_matrix;        % 5×5 polynomial coefficients

% Save turbineData structure to .mat file
% This file is loaded by CONFIG_MODEL.m and other analysis scripts
save('TurbineData.mat', 'turbineData');
fprintf('  Turbine data saved to: TurbineData.mat\n');

% Display summary of saved data
fprintf('\n========== TURBINE DATA SUMMARY ==========\n');
fprintf('  Rated Power:       %.2f MW\n', ratedTurbinePower/1e6);
fprintf('  Rated Wind Speed:  %.2f m/s\n', ratedWindSpeed);
fprintf('  Rated Turbine RPM: %.1f rpm\n', ratedTurbineSpeed*30/pi);
fprintf('  Rotor Radius:      %.1f m\n', turbineRadius);
fprintf('  Rotor Diameter:    %.1f m\n', 2*turbineRadius);
fprintf('  Air Density:       %.3f kg/m³\n', airDensity);
fprintf('  Cp Model:          5×5 polynomial (degree 4)\n');
fprintf('  Max Cp (fitted):   %.4f (at λ≈%.1f, pitch=1°)\n', ...
        max(Cp_est(:)), Lambda_data(Cp_est(1,:)==max(Cp_est(1,:))));
fprintf('==========================================\n\n');

fprintf('TurbineData processing completed successfully!\n');
fprintf('Generated files:\n');
fprintf('  - TurbineData.mat (turbine parameters and Cp model)\n');
fprintf('  - 3 figures (Cp surface, Cp curves, power curves)\n\n');

%==========================================================================
% End of script
%==========================================================================