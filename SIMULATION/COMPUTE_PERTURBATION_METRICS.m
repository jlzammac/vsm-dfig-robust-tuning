function metrics = COMPUTE_PERTURBATION_METRICS(results, pertType, pertConfig)
% COMPUTE_PERTURBATION_METRICS - Compute perturbation response metrics
%
% DESCRIPTION:
%   Computes dynamic performance metrics from non-linear simulation results
%   produced by RUN_PERTURBATION_SIM. Metrics include integral absolute error
%   (IAE), rate of change (ROCOF/ROCOV), nadir, and settling time for both
%   frequency and voltage signals.
%
%   These metrics are designed to be used as fitness objectives in the GA
%   multi-objective optimizer (OPTIMIZER.m) for robust controller design.
%
% INPUTS:
%   results    - Output struct from RUN_PERTURBATION_SIM containing:
%                .t, .f (grid frequency), .Vpcc (PCC voltage), .success
%   pertType   - 'generation_loss' | 'voltage_sag' | 'both' |
%                'pref_step' | 'qref_step' | 'load_step' |
%                'wind_change' | 'custom'
%   pertConfig - Struct with perturbation timing info:
%                .breaker_time, .sag_start_time, .pref_time, .qref_time,
%                .load_time, .vw_time (used to determine t_pert)
%
% OUTPUTS:
%   metrics - Struct with:
%     .IAE_f        Integral Absolute Error of frequency deviation (pu·s)
%     .IAE_V        Integral Absolute Error of voltage deviation (pu·s)
%     .ITAE_f       Integral Time-weighted Absolute Error of frequency (pu·s²)
%     .ITAE_V       Integral Time-weighted Absolute Error of voltage (pu·s²)
%     .ROCOF        Rate of Change of Frequency (pu/s)
%     .ROCOV        Rate of Change of Voltage (pu/s)
%     .nadir_f      Frequency nadir - minimum value (pu)
%     .nadir_V      Voltage nadir - minimum value (pu)
%     .settling_f   Frequency 2% settling time after perturbation (s)
%     .settling_V   Voltage 2% settling time after perturbation (s)
%     .f_ref        Pre-perturbation frequency reference (pu)
%     .V_ref        Pre-perturbation voltage reference (pu)
%     .IAE_P        Integral Absolute Error of active power deviation (pu·s)
%     .IAE_Q        Integral Absolute Error of reactive power deviation (pu·s)
%     .success      boolean (false if simulation failed or metrics invalid)
%
% METRIC DEFINITIONS:
%   IAE:      ∫|x(t) - x_ref| dt from t_pert to t_end
%   ITAE:     ∫(t-t_pert)*|x(t) - x_ref| dt from t_pert to t_end
%             (penalizes persistent/late errors more heavily)
%   ROCOF/V:  max|dx/dt| in first 500ms after perturbation (smoothed)
%   nadir:    min(x(t)) for t > t_pert (worst-case deviation)
%   settling: time after t_pert for x(t) to stay within ±2% of x_final
%
% OPTIONAL FIELDS IN pertConfig:
%   .eval_window_f  [t_start, t_end] — evaluation window for frequency metrics
%   .eval_window_v  [t_start, t_end] — evaluation window for voltage metrics
%   If not provided, uses full post-perturbation window (backward compatible)
%
% USAGE:
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, 'generation_loss', pertConfig);
%   metrics = COMPUTE_PERTURBATION_METRICS(results, 'generation_loss', pertConfig);
%   fprintf('IAE_f=%.4f, ROCOF=%.4f, nadir_f=%.4f pu\n', ...
%       metrics.IAE_f, metrics.ROCOF, metrics.nadir_f);
%
% SEE ALSO:
%   RUN_PERTURBATION_SIM, OPTIMIZER, CONFIG_POWER_SYSTEM

%--------------------------------------------------------------------------
%% CHECK SIMULATION SUCCESS
%--------------------------------------------------------------------------
if ~results.success
    metrics = penalty_metrics();
    return;
end

%--------------------------------------------------------------------------
%% EXTRACT SIGNALS
%--------------------------------------------------------------------------
t = results.t;
f = results.f;
V = results.Vpcc;

% Validate signal lengths
if isempty(t) || length(t) < 100
    metrics = penalty_metrics();
    return;
end

%--------------------------------------------------------------------------
%% DEFAULT PERTCONFIG FIELDS (for sparse configs, esp. 'custom' type)
%--------------------------------------------------------------------------
if ~isfield(pertConfig, 'breaker_time'),   pertConfig.breaker_time = 999; end
if ~isfield(pertConfig, 'sag_start_time'), pertConfig.sag_start_time = 999; end
if ~isfield(pertConfig, 'pref_time'),      pertConfig.pref_time = 999; end
if ~isfield(pertConfig, 'qref_time'),      pertConfig.qref_time = 999; end
if ~isfield(pertConfig, 'load_time'),      pertConfig.load_time = 999; end
if ~isfield(pertConfig, 'vw_time'),        pertConfig.vw_time = 999; end

%--------------------------------------------------------------------------
%% DETERMINE PERTURBATION START TIME
%--------------------------------------------------------------------------
switch pertType
    case 'generation_loss'
        t_pert = pertConfig.breaker_time;
    case 'voltage_sag'
        t_pert = pertConfig.sag_start_time;
    case 'both'
        t_pert = min(pertConfig.breaker_time, pertConfig.sag_start_time);
    case 'pref_step'
        t_pert = pertConfig.pref_time;
    case 'qref_step'
        t_pert = pertConfig.qref_time;
    case 'load_step'
        t_pert = pertConfig.load_time;
    case 'wind_change'
        t_pert = pertConfig.vw_time;
    case 'custom'
        % Use earliest perturbation time across all configured types
        times = [pertConfig.breaker_time, pertConfig.sag_start_time, ...
                 pertConfig.pref_time, pertConfig.qref_time, ...
                 pertConfig.load_time, pertConfig.vw_time];
        t_pert = min(times);
    otherwise
        metrics = penalty_metrics();
        return;
end

%--------------------------------------------------------------------------
%% PRE-PERTURBATION REFERENCE VALUES
%--------------------------------------------------------------------------
% When pertConfig provides explicit f_ref/V_ref → use analytical OP values
% (perturbation at t=0, no pre-perturbation window needed)
% Otherwise → backward-compatible: average over 100ms before perturbation
if isfield(pertConfig, 'f_ref') && isfield(pertConfig, 'V_ref')
    f_ref = pertConfig.f_ref;
    V_ref = pertConfig.V_ref;
else
    t_pre_start = max(t_pert - 0.1, t(1));
    idx_pre = (t >= t_pre_start) & (t < t_pert);
    if sum(idx_pre) < 10
        % Not enough pre-perturbation samples; use first available values
        idx_pre = 1:min(100, length(t));
    end
    f_ref = mean(f(idx_pre));
    V_ref = mean(V(idx_pre));
end

%--------------------------------------------------------------------------
%% POST-PERTURBATION SIGNAL EXTRACTION
%--------------------------------------------------------------------------
idx_post = t >= t_pert;
t_post = t(idx_post);
f_post = f(idx_post);
V_post = V(idx_post);

if isempty(t_post)
    metrics = penalty_metrics();
    return;
end

%--------------------------------------------------------------------------
%% EVALUATION WINDOWS (optional, backward-compatible)
%--------------------------------------------------------------------------
% Frequency evaluation window
if isfield(pertConfig, 'eval_window_f') && ~isempty(pertConfig.eval_window_f)
    ew_f = pertConfig.eval_window_f;
    idx_ew_f = (t_post >= ew_f(1)) & (t_post <= ew_f(2));
    t_f_eval = t_post(idx_ew_f);
    f_f_eval = f_post(idx_ew_f);
else
    t_f_eval = t_post;
    f_f_eval = f_post;
end

% Voltage evaluation window
if isfield(pertConfig, 'eval_window_v') && ~isempty(pertConfig.eval_window_v)
    ew_v = pertConfig.eval_window_v;
    idx_ew_v = (t_post >= ew_v(1)) & (t_post <= ew_v(2));
    t_v_eval = t_post(idx_ew_v);
    V_v_eval = V_post(idx_ew_v);
else
    t_v_eval = t_post;
    V_v_eval = V_post;
end

% Low-pass filter V_v_eval AFTER windowing (eval window starts after spike)
% filtfilt: zero-phase, no group-delay distortion on slow VSM voltage dynamics
% fc=20 Hz: preserves voltage control response, rejects HF grid-converter resonances
% Applied here (not on full V) so the spike at t_pert never enters the filter
if length(V_v_eval) >= 30
    dt_vals = diff(t_v_eval);
    Ts = median(dt_vals(dt_vals > 0));
    fs = 1 / Ts;
    fc = 20;  % [Hz] low-pass cutoff
    if fs > 2*fc
        [b_lp, a_lp] = butter(2, fc/(fs/2), 'low');
        V_v_eval = filtfilt(b_lp, a_lp, double(V_v_eval));
    end
end

%--------------------------------------------------------------------------
%% IAE (Integral Absolute Error)
%--------------------------------------------------------------------------
% IAE = ∫|x(t) - x_ref| dt over evaluation window
if ~isempty(t_f_eval) && length(t_f_eval) >= 2
    metrics.IAE_f = trapz(t_f_eval, abs(f_f_eval - f_ref));
else
    metrics.IAE_f = trapz(t_post, abs(f_post - f_ref));
end
if ~isempty(t_v_eval) && length(t_v_eval) >= 2
    metrics.IAE_V = trapz(t_v_eval, abs(V_v_eval - V_ref));
else
    metrics.IAE_V = trapz(t_post, abs(V_post - V_ref));
end

%--------------------------------------------------------------------------
%% ITAE (Integral Time-weighted Absolute Error)
%--------------------------------------------------------------------------
% ITAE = ∫(t-t_pert)*|x(t) - x_ref| dt — penalizes persistent late errors
t_rel_f = t_f_eval - t_pert;
t_rel_v = t_v_eval - t_pert;
if ~isempty(t_f_eval) && length(t_f_eval) >= 2
    metrics.ITAE_f = trapz(t_f_eval, t_rel_f .* abs(f_f_eval - f_ref));
else
    t_rel_post = t_post - t_pert;
    metrics.ITAE_f = trapz(t_post, t_rel_post .* abs(f_post - f_ref));
end
if ~isempty(t_v_eval) && length(t_v_eval) >= 2
    metrics.ITAE_V = trapz(t_v_eval, t_rel_v .* abs(V_v_eval - V_ref));
else
    t_rel_post = t_post - t_pert;
    metrics.ITAE_V = trapz(t_post, t_rel_post .* abs(V_post - V_ref));
end

%--------------------------------------------------------------------------
%% IAE_P / IAE_Q (Active/Reactive Power Tracking Error)
%--------------------------------------------------------------------------
% Compute power tracking IAE if P_dfig/Q_dfig data is available
% P_dfig columns: [P_ref, P, P_mech] — IAE uses |P - P_ref|
% Q_dfig columns: [Q_ref, Q, Grid_Q, Load_Q] — IAE uses |Q - Q_ref|
if isfield(results, 'P_dfig') && ~isempty(results.P_dfig) && size(results.P_dfig,2) >= 2
    P_post = results.P_dfig(idx_post,:);
    P_ref_sig = P_post(:,1);  % P_ref channel
    P_act_sig = P_post(:,2);  % P actual channel
    metrics.IAE_P = trapz(t_post, abs(P_act_sig - P_ref_sig));
else
    metrics.IAE_P = NaN;
end

if isfield(results, 'Q_dfig') && ~isempty(results.Q_dfig) && size(results.Q_dfig,2) >= 2
    Q_post = results.Q_dfig(idx_post,:);
    Q_ref_sig = Q_post(:,1);  % Q_ref channel
    Q_act_sig = Q_post(:,2);  % Q actual channel
    metrics.IAE_Q = trapz(t_post, abs(Q_act_sig - Q_ref_sig));
else
    metrics.IAE_Q = NaN;
end

%--------------------------------------------------------------------------
%% ROCOF / ROCOV (Rate of Change)
%--------------------------------------------------------------------------
% Maximum |dx/dt| in first 500ms after perturbation
% Uses smoothed derivative to reduce noise from high-frequency sampling
t_rate_end = t_pert + 0.5;
idx_rate = (t_post >= t_pert) & (t_post <= t_rate_end);
t_rate = t_post(idx_rate);
f_rate = f_post(idx_rate);
V_rate = V_post(idx_rate);

if length(t_rate) > 20
    % Smooth derivative: compute slope over sliding 20ms window
    metrics.ROCOF = smoothed_max_derivative(t_rate, f_rate, 0.02);
    metrics.ROCOV = smoothed_max_derivative(t_rate, V_rate, 0.02);
else
    % Fallback: simple finite difference
    dt = diff(t_rate);
    dt(dt == 0) = eps;  % Avoid division by zero
    metrics.ROCOF = max(abs(diff(f_rate) ./ dt));
    metrics.ROCOV = max(abs(diff(V_rate) ./ dt));
end

%--------------------------------------------------------------------------
%% NADIR (Maximum deviation)
%--------------------------------------------------------------------------
% Frequency nadir: minimum value after perturbation (drops in gen loss)
% Voltage nadir: minimum value after perturbation (drops in voltage sag)
metrics.nadir_f = min(f_post);
metrics.nadir_V = min(V_post);

%--------------------------------------------------------------------------
%% SETTLING TIME (2% criterion)
%--------------------------------------------------------------------------
% Time after perturbation for signal to remain within ±2% of final value
f_final = f(end);
V_final = V(end);
f_band = 0.02 * abs(f_ref);  % 2% of reference
V_band = 0.02 * abs(V_ref);

metrics.settling_f = compute_settling_time(t_post, f_post, f_final, f_band, t_pert);
metrics.settling_V = compute_settling_time(t_post, V_post, V_final, V_band, t_pert);

%--------------------------------------------------------------------------
%% REFERENCE VALUES AND STATUS
%--------------------------------------------------------------------------
metrics.f_ref = f_ref;
metrics.V_ref = V_ref;
metrics.success = true;

end

%==========================================================================
%% LOCAL FUNCTIONS
%==========================================================================

function ts = compute_settling_time(t, y, y_final, band, t0)
% COMPUTE_SETTLING_TIME - Find 2% settling time
%   Returns time (relative to t0) when signal last exits the ±band around y_final
    settled = abs(y - y_final) <= band;
    last_outside = find(~settled, 1, 'last');
    if isempty(last_outside)
        ts = 0;        % Already settled at perturbation start
    elseif last_outside >= length(t)
        ts = Inf;      % Never settles within simulation window
    else
        ts = t(last_outside + 1) - t0;
    end
end

function roc_max = smoothed_max_derivative(t, y, window)
% SMOOTHED_MAX_DERIVATIVE - Max |dy/dt| with smoothing window
%   Computes derivative using centered differences over a time window
%   to reduce noise from high-frequency sampling (dt ~ 1e-6 s)
    n = length(t);
    roc = zeros(n, 1);

    for i = 1:n
        % Find indices within ±window/2 of current time
        t_lo = t(i) - window/2;
        t_hi = t(i) + window/2;
        idx = (t >= t_lo) & (t <= t_hi);

        if sum(idx) >= 2
            t_win = t(idx);
            y_win = y(idx);
            % Linear regression slope = derivative estimate
            dt_win = t_win(end) - t_win(1);
            if dt_win > 0
                roc(i) = abs((y_win(end) - y_win(1)) / dt_win);
            end
        end
    end

    roc_max = max(roc);
    if isempty(roc_max) || isnan(roc_max)
        roc_max = 0;
    end
end

function metrics = penalty_metrics()
% PENALTY_METRICS - Return penalty values for failed simulations
%   Used when simulation fails or produces invalid results.
%   Penalty values signal the GA optimizer to reject this individual.
    metrics.IAE_f      = 1e6;
    metrics.IAE_V      = 1e6;
    metrics.ITAE_f     = 1e6;
    metrics.ITAE_V     = 1e6;
    metrics.IAE_P      = 1e6;
    metrics.IAE_Q      = 1e6;
    metrics.ROCOF      = 1e6;
    metrics.ROCOV      = 1e6;
    metrics.nadir_f    = 0;
    metrics.nadir_V    = 0;
    metrics.settling_f = 1e6;
    metrics.settling_V = 1e6;
    metrics.f_ref      = NaN;
    metrics.V_ref      = NaN;
    metrics.success    = false;
end
