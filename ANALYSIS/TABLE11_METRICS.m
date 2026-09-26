function res = TABLE11_METRICS(baseDir, gaDir)
%TABLE11_METRICS  Peak deviations for Table 11 from the TABLE11_SCR_SWEEP runs.
%
%   res = TABLE11_METRICS(baseDir, gaDir)
%
%   Conventions of Section 6.1: reference = the sample at t = 0.010 s (the
%   settled pre-disturbance state), peak |y - y_ref| on each run's own solver
%   grid over [0.505, 3.010] s (generation loss) or [0.5005, 3.010] s (sag).
%   Channels: frequency SCOPE_SIM.signals(11) comp. 1 (x 50 Hz), DC-link
%   voltage of DFIG 1 signals(3) comp. 2, and PCC voltage signals(6) comp. 3.
%
%   The PCC voltage is filtered exactly as it is drawn in Figures 12 and 13:
%   resampled to 10 us and passed through a zero-phase fourth-order
%   Butterworth low-pass at 1 kHz. Unfiltered, its peak is dominated by the
%   numerical ripple of the averaged model (0.054 against 0.018 pu for the
%   baseline under generation loss) and depends on where the variable-step
%   solver places its samples, so two identical runs disagree. Filtered, the
%   run behind Figure 12 and a fresh run agree to 1e-4 pu.
%
%   res(event, scr, design, metric): event 1 generation loss, 2 sag;
%   scr [1 1.5 2 3]; design 1 BASE, 2 GA; metric [df_mHz dVpcc dVdc].

T_REF = 0.010; T_END = 3.010; CUT = [0.505 0.5005];
P = {'generation_loss', 'voltage_sag'};
S = [1 1.5 2 3]; D = {'BASE', 'GA'}; dirs = {baseDir, gaDir};
res = nan(2, 4, 2, 3);
tt = (0:1e-5:T_END)'; [bf, af] = butter(4, 1000/(1e5/2));
for d = 1:2, for k = 1:2, for s = 1:4
    L  = load(fullfile(dirs{d}, sprintf('%s_%s_SCR%.1f.mat', D{d}, P{k}, S(s))));
    sc = L.r.SCOPE_SIM; t = sc.time(:);
    y  = {squeeze(sc.signals(11).values(1,1,:)), [], squeeze(sc.signals(3).values(2,1,:))};
    i0 = find(t >= T_REF, 1); js = find(t >= CUT(k), 1); je = min(find(t >= T_END, 1), numel(t));
    for m = [1 3], yy = y{m}(:); res(k,s,d,m) = max(abs(yy(js:je) - yy(i0))); end
    res(k,s,d,1) = res(k,s,d,1) * 50e3;     % pu of 50 Hz -> mHz
    % PCC voltage, filtered as drawn
    [tu, iu] = unique(t); v = squeeze(sc.signals(6).values(3,1,:)); v = v(iu);
    vf = filtfilt(bf, af, interp1(tu, v, tt));
    w  = tt >= CUT(k) & tt <= T_END; i0f = find(tt >= T_REF, 1);
    res(k,s,d,2) = max(abs(vf(w) - vf(i0f)));
end, end, end

names = {'df (mHz)', 'dVpcc filt (pu)', 'dVdc (pu)'};
for k = 1:2
    fprintf('\n=== %s ===\n', P{k});
    for s = 1:4
        fprintf('SCR %.1f', S(s));
        for m = 1:3
            b0 = res(k,s,1,m); g = res(k,s,2,m);
            fprintf(' | %s %.4g -> %.4g (%+.1f %%)', names{m}, b0, g, 100*(g-b0)/b0);
        end
        fprintf('\n');
    end
end
end
