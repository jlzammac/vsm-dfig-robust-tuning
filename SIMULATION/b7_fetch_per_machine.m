function M = b7_fetch_per_machine(nDFIG)
%B7_FETCH_PER_MACHINE Per-machine traces of the run just completed.
%
% DESCRIPTION:
%   Reads the per-machine DFIG quantities from the Simulink Data Inspector run
%   that the last simulation produced, and returns the terminal-voltage
%   magnitude of every machine. This is the quantity Figure 14 plots.
%
% WHY THE DATA INSPECTOR
%   SCOPE_SIM does not carry per-machine data: every one of its fifteen signal
%   groups has a unit dimension of 1, verified on completed runs. The published
%   Figure 14 therefore cannot have been drawn from it. b7_enable_per_machine_logging
%   turns on port logging in the mirror, and those logs return inside the
%   SimulationOutput object rather than in the base workspace. RUN_PERTURBATION_SIM
%   does not hand that object back, so the logs are read from the Data
%   Inspector, which holds them regardless and needs no change to that function.
%
%   The signals used are
%       b7_dfig_out3.DFIG.OUTPUT.vs_r(1,k)
%       b7_dfig_out3.DFIG.OUTPUT.vs_i(1,k)     k = 1..nDFIG
%   the real and imaginary parts of each machine's stator voltage, from which
%   |u_dqs| follows directly.
%
% INPUT:
%   nDFIG - Number of machines. Default 4.
%
% OUTPUT:
%   M - Struct with
%         .t        time vector
%         .Vs       [nSamples x nDFIG] terminal-voltage magnitude per machine
%         .vs_r     [nSamples x nDFIG]
%         .vs_i     [nSamples x nDFIG]
%         .found    number of machines actually recovered
%
% SEE ALSO: b7_enable_per_machine_logging, b7_point

if nargin < 1 || isempty(nDFIG), nDFIG = 4; end

M = struct('t', [], 'Vs', [], 'vs_r', [], 'vs_i', [], 'found', 0);

ids = Simulink.sdi.getAllRunIDs;
if isempty(ids)
    warning('b7_fetch_per_machine:noRun', ...
            'No Data Inspector run found. Per-machine traces are unavailable.');
    return
end
run = Simulink.sdi.getRun(ids(end));

vr = cell(1, nDFIG);
vi = cell(1, nDFIG);
t  = [];

for k = 1:run.SignalCount
    sg = run.getSignalByIndex(k);
    nm = sg.Name;
    tok = regexp(nm, 'DFIG\.OUTPUT\.vs_([ri])\(1,(\d+)\)$', 'tokens', 'once');
    if isempty(tok), continue, end
    part = tok{1};
    idx  = str2double(tok{2});
    if idx < 1 || idx > nDFIG, continue, end
    d = sg.Values.Data(:);
    if isempty(t), t = sg.Values.Time(:); end
    if part == 'r', vr{idx} = d; else, vi{idx} = d; end
end

have = find(~cellfun(@isempty, vr) & ~cellfun(@isempty, vi));
if isempty(have)
    warning('b7_fetch_per_machine:noSignals', ...
            ['No per-machine stator-voltage signals in the run. Was ' ...
             'b7_enable_per_machine_logging called on this mirror?']);
    return
end

n = numel(t);
M.t     = t;
M.vs_r  = nan(n, nDFIG);
M.vs_i  = nan(n, nDFIG);
for k = have
    M.vs_r(:,k) = vr{k};
    M.vs_i(:,k) = vi{k};
end
M.Vs    = hypot(M.vs_r, M.vs_i);
M.found = numel(have);

fprintf('  Per-machine traces recovered for %d of %d machines\n', M.found, nDFIG);

end
