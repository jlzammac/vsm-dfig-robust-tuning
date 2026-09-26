function T = b7_campaign(varargin)
%B7_CAMPAIGN The symmetric-fault campaign of Section 6.3.
%
% DESCRIPTION:
%   Runs the matrix of Table 10 and writes, for every point, both the full state
%   trajectories and the summary metrics. Figure 14 is drawn from the
%   trajectories of the four P = 0.8 pu shallow points.
%
%   Matrix: SCR in {1, 1.5, 2, 3} x P in {0.4, 0.8} pu/DFIG x two fault depths.
%   Every run is a 150 ms symmetric event with a 3 s horizon, at a pre-fault PCC
%   voltage of 0.975 pu.
%
% HOW THE DEPTH IS SPECIFIED, AND WHY IT IS CALIBRATED PER RUN
%   The fault is applied by scaling the Thevenin source behind Z_grid. Every
%   depth the paper quotes is the voltage RETAINED AT THE PCC, because that is
%   where interconnection requirements define it. The two are not proportional:
%   the divider between Z_grid and the farm differs with grid strength, so one
%   source-side fraction leaves a different PCC voltage at each SCR. Each point
%   therefore carries its own source fraction, obtained by bisection against the
%   target retained PCC voltage.
%
%   The consequence is worth stating rather than leaving to be inferred: the
%   source-side event is NOT identical across cells of the matrix. The matrix
%   compares grid strengths at equal severity in the farm's own terminals, not
%   at equal fault severity in the network.
%
% ONE STORED FRACTION IS MISSING AND IS NOT INVENTED
%   The campaign record holds the source fraction for fifteen of the sixteen
%   points. The deep event at SCR = 1, P = 0.4 pu has no stored value. Running
%   that point calibrates it by bisection, which is how all of them were
%   obtained originally. Calibration costs a few extra simulations; the stored
%   fractions are a fast path, not a separate method.
%
% USAGE:
%   T = b7_campaign();                     % all sixteen points
%   T = b7_campaign('Points', 'figure14'); % the four points of Figure 14
%   T = b7_campaign('Points', {'m_S1_P0.8_V90'});
%   T = b7_campaign('OutDir', '/path/to/output');
%
% OUTPUT:
%   T - Table with one row per run, in the column order of Table 10. Also
%       written to <OutDir>/b7_campaign_table.csv, with the per-run .mat files
%       alongside.
%
% SEE ALSO: b7_point, b7_calibrate_depth, b7_metrics

p = inputParser;
addParameter(p, 'Points', 'all');
addParameter(p, 'OutDir', '');
addParameter(p, 'Vpcc',   0.975);
parse(p, varargin{:});

repoRoot = fileparts(fileparts(mfilename('fullpath')));
outDir   = p.Results.OutDir;
if isempty(outDir)
    outDir = fullfile(repoRoot, 'RESULTS', 'B7_CAMPAIGN');
end
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% The campaign matrix.
% Columns: tag, SCR, P, r_src, target retained PCC, duration, horizon.
% r_src NaN means "calibrate by bisection".
% Source fractions are from the campaign record; the target retained values are
% the levels the matrix specifies.
SPEC = {
  'm_S1_P0.4_V90',   1.0, 0.4, 0.67469, 0.90, 0.15, 3.0
  'm_S1_P0.4_V70',   1.0, 0.4, NaN,     0.70, 0.15, 3.0   % no stored fraction
  'm_S1_P0.8_V90',   1.0, 0.8, 0.73064, 0.90, 0.15, 3.0
  'm_S1_P0.8_V70',   1.0, 0.8, 0.40638, 0.70, 0.15, 3.0
  'm_S1.5_P0.4_V90', 1.5, 0.4, 0.75633, 0.90, 0.15, 3.0
  'm_S1.5_P0.4_V70', 1.5, 0.4, 0.34934, 0.70, 0.15, 3.0
  'm_S1.5_P0.8_V90', 1.5, 0.8, 0.74868, 0.90, 0.15, 3.0
  'm_S1.5_P0.8_V70', 1.5, 0.8, 0.51558, 0.70, 0.15, 3.0
  'm_S2_P0.4_V90',   2.0, 0.4, 0.79453, 0.90, 0.15, 3.0
  'm_S2_P0.4_V70',   2.0, 0.4, 0.47591, 0.70, 0.15, 3.0
  'm_S2_P0.8_V90',   2.0, 0.8, 0.78953, 0.90, 0.15, 3.0
  'm_S2_P0.8_V70',   2.0, 0.8, 0.57320, 0.70, 0.15, 3.0
  'm_S3_P0.4_V90',   3.0, 0.4, 0.84801, 0.90, 0.15, 3.0
  'm_S3_P0.4_V70',   3.0, 0.4, 0.57297, 0.70, 0.15, 3.0
  'm_S3_P0.8_V90',   3.0, 0.8, 0.83352, 0.90, 0.15, 3.0
  'm_S3_P0.8_V70',   3.0, 0.8, 0.62943, 0.70, 0.15, 3.0
};

% The four traces of Figure 14: P = 0.8 pu, shallow event, one per grid strength.
FIGURE14 = {'m_S1_P0.8_V90','m_S1.5_P0.8_V90','m_S2_P0.8_V90','m_S3_P0.8_V90'};

sel = p.Results.Points;
if ischar(sel) || isstring(sel)
    switch lower(char(sel))
        case 'all',      wanted = SPEC(:,1);
        case 'figure14', wanted = FIGURE14(:);
        otherwise,       wanted = {char(sel)};
    end
else
    wanted = sel(:);
end

keep = ismember(SPEC(:,1), wanted);
if ~any(keep)
    error('b7_campaign:noSuchPoint', ...
          'None of the requested points is in the matrix. Available: %s', ...
          strjoin(SPEC(:,1)', ', '));
end
RUN = SPEC(keep, :);
n   = size(RUN, 1);

fprintf('=========================================================================\n');
fprintf('  Section 6.3 symmetric-fault campaign — %d of %d points\n', n, size(SPEC,1));
fprintf('  Pre-fault PCC voltage %.3f pu; output in %s\n', p.Results.Vpcc, outDir);
fprintf('=========================================================================\n');

rows = cell(n, 1);
for k = 1:n
    tag   = RUN{k,1};
    SCR   = RUN{k,2};
    P     = RUN{k,3};
    r_src = RUN{k,4};
    Vtgt  = RUN{k,5};
    dur   = RUN{k,6};
    Thor  = RUN{k,7};

    fprintf('\n[%d/%d] %s\n', k, n, tag);

    if isnan(r_src)
        fprintf('  No stored source fraction. Calibrating to a retained %.2f pu at the PCC.\n', Vtgt);
        r_src = b7_calibrate_depth(repoRoot, tag, SCR, P, Vtgt, dur, Thor, p.Results.Vpcc);
        fprintf('  Calibrated source fraction: %.5f\n', r_src);
    end

    try
        s = b7_point(tag, SCR, P, r_src, dur, Thor, outDir);
        s.r_src_used = r_src;
        s.V_target   = Vtgt;
        rows{k} = s;
    catch ME
        fprintf('  RUN FAILED: %s — %s\n', ME.identifier, ME.message);
        rows{k} = struct('tag', tag, 'outcome', 'Run failed', ...
                         'outcome_reason', ME.message, 'r_src_used', r_src, ...
                         'V_target', Vtgt);
    end
end

%% Table, in the column order of Table 10
T = b7_table(rows);
csv = fullfile(outDir, 'b7_campaign_table.csv');
writetable(T, csv);

fprintf('\n=========================================================================\n');
fprintf('  Campaign complete. Table written to %s\n', csv);
fprintf('=========================================================================\n');
disp(T);

end

%% ------------------------------------------------------------------------
function T = b7_table(rows)
%B7_TABLE Assemble the per-run summaries into Table 10's column order.
get = @(s,f,d) ternary(isfield(s,f) && ~isempty(s.(f)), @() s.(f), @() d);

tag=[]; SCR=[]; P=[]; dpre=[]; Vret=[]; udcmin=[]; irpk=[]; dmax=[]; dwr=[]; vpp=[]; out=[];
for k = 1:numel(rows)
    s = rows{k};
    if isempty(s), continue, end
    tag    = [tag;    string(get(s,'tag',""))];                              %#ok<AGROW>
    sp     = get(s,'spec',struct('SCR',NaN,'P',NaN));
    SCR    = [SCR;    get(sp,'SCR',NaN)];                                    %#ok<AGROW>
    P      = [P;      get(sp,'P',NaN)];                                      %#ok<AGROW>
    dpre   = [dpre;   get(s,'delta_pre',NaN)];                               %#ok<AGROW>
    Vret   = [Vret;   get(s,'PCC_ret',NaN)];                                 %#ok<AGROW>
    udcmin = [udcmin; get(s,'vdc_min_run',NaN)];                             %#ok<AGROW>
    irpk   = [irpk;   get(s,'ir_peak',NaN)];                                 %#ok<AGROW>
    dmax   = [dmax;   get(s,'delta_max',NaN)];                               %#ok<AGROW>
    dwr    = [dwr;    get(s,'dwr_max',NaN)];                                 %#ok<AGROW>
    vpp    = [vpp;    get(s,'Vpost_Vpre',NaN)];                              %#ok<AGROW>
    out    = [out;    string(get(s,'outcome',"unknown"))];                   %#ok<AGROW>
end
T = table(tag, SCR, P, dpre, Vret, udcmin, irpk, dmax, dwr, vpp, out, ...
    'VariableNames', {'tag','SCR','P_pu','delta_pre_deg','V_ret_pu', ...
                      'udc_min_pu','ir_peak_pu','delta_max_deg', ...
                      'dwr_max_pu','Vpost_over_Vpre','outcome'});
end

function v = ternary(c, a, b)
if c, v = a(); else, v = b(); end
end
