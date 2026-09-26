%CHECK_RAW_VS_FILTERED_PCC  Raw against filtered PCC voltage, Section 6.2.
%
%   Several published PCC-voltage numbers are FILTERED-trace figures and others
%   are raw, and the two differ by enough to look like an inconsistency in the
%   paper. This settles which is which by measurement.
%
%   The display filter is the one stated in the measurement record: 4th-order
%   Butterworth, 1 kHz cut-off, zero phase (filtfilt). It is a DISPLAY filter --
%   nothing in the model or the metrics uses it.
%
%   MEASURED 2026-09-23, sag scenario, SCR = 1:
%
%                            baseline   optimised   change
%     PCC nadir, raw          0.9258     0.9216
%     deviation, raw          0.0743     0.0785     +5.67 %
%     PCC nadir, filtered     0.9509     0.9501
%     deviation, filtered     0.0491     0.0499     +1.64 %
%
%   Section 6.2 claims "about 2 %" and "approximately 0.95 pu". Both are the
%   FILTERED column, and both are correct. See
%   REPRODUCE/fig13_nl_voltage_sag.md, including why changing one of them to a
%   raw value without changing the other would reintroduce, one sentence over,
%   the defect being fixed in Section 6.1.
%
%   PREREQUISITE: a completed COMPARE_BASELINE_VS_V6 run, whose saved SCOPE
%   traces this replays. No simulation is performed.
%
%   SEE ALSO: COMPARE_BASELINE_VS_V6, PLOT_SCOPE_SIM

% Repository-relative, so this runs from a clone anywhere. Run from ANALYSIS.
d = fullfile(fileparts(pwd), 'RESULTS', 'SIMULATION', ...
             'COMPARISON_BASELINE_VS_V6');
f = dir(fullfile(d, 'comparison_v6_SCOPE_*.mat'));
assert(~isempty(f), ['no saved SCOPE traces in %s\n' ...
                     'Run COMPARE_BASELINE_VS_V6 first.'], d);
S = load(fullfile(d, f(end).name));
fprintf('file: %s\n', f(end).name);
fprintf('fields: %s\n\n', strjoin(fieldnames(S)', ', '));

CH_V_PCC = [6 3];   % from PLOT_SCOPE_SIM.m

function y = chan(r, ch)
    v = r.SCOPE_SIM.signals(ch(1)).values;
    if ndims(v) == 3
        y = squeeze(v(ch(2), 1, :));
    else
        y = v(:, ch(2));
    end
    y = y(:);
end

names = {'BASELINE', 'GAv6'};
res = struct();

for k = 1:2
    r = S.scope_data.(names{k}).v_dip;
    t = r.t(:);
    V = chan(r, CH_V_PCC);

    fs = 1/median(diff(t));
    [b, a] = butter(4, 1000/(fs/2));          % 4th order, 1 kHz, normalised
    Vf = filtfilt(b, a, V);                   % zero phase

    tEv  = 1.0;                                % the driver fires the sag here
    pre  = t < tEv & t > tEv - 0.2;
    post = t >= tEv & t <= tEv + 2.0;

    Vpre    = mean(V(pre));
    Vpre_f  = mean(Vf(pre));
    devRaw  = Vpre   - min(V(post));
    devFilt = Vpre_f - min(Vf(post));

    res.(names{k}) = struct('fs', fs, 'Vpre', Vpre, 'Vpre_f', Vpre_f, ...
                            'nadirRaw', min(V(post)), 'nadirFilt', min(Vf(post)), ...
                            'devRaw', devRaw, 'devFilt', devFilt);

    fprintf('%-9s  fs = %8.0f Hz\n', names{k}, fs);
    fprintf('           pre-event   raw %.4f   filtered %.4f\n', Vpre, Vpre_f);
    fprintf('           nadir       raw %.4f   filtered %.4f\n', min(V(post)), min(Vf(post)));
    fprintf('           deviation   raw %.4f   filtered %.4f\n\n', devRaw, devFilt);
end

B = res.BASELINE; G = res.GAv6;
chgRaw  = (G.devRaw  - B.devRaw ) / B.devRaw  * 100;
chgFilt = (G.devFilt - B.devFilt) / B.devFilt * 100;

fprintf('%s\n', repmat('=', 1, 58));
fprintf('  Peak PCC voltage deviation, optimised vs baseline\n');
fprintf('%s\n', repmat('=', 1, 58));
fprintf('  RAW signal        %+7.2f %%\n', chgRaw);
fprintf('  FILTERED signal   %+7.2f %%\n', chgFilt);
fprintf('  Paper claims      "about 2 %%"\n');
fprintf('%s\n', repmat('=', 1, 58));
if abs(chgFilt) < 3 && abs(chgRaw) > 3
    fprintf('  -> FILTERED matches the claim, RAW does not.\n');
    fprintf('     The ~2 %% is a filtered-trace figure.\n');
elseif abs(chgRaw) < 3
    fprintf('  -> RAW already matches; filtering is not the explanation.\n');
else
    fprintf('  -> NEITHER matches. The filter is not the explanation.\n');
end
