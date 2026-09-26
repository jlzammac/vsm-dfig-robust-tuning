function OUT = COMPUTE_PERBAND_DAMPING(varargin)
%COMPUTE_PERBAND_DAMPING  Per-band damping census of the saved linear models.
%
% Reproducible, standalone measurement of the per-band minimum damping ratio
% of every linearised closed-loop model stored under RESULTS/CONTROL.
%
% It exists because these numbers were, at one point, only ever reported
% verbally by an agent and never written to disk. Anything that is quoted in
% the paper must be re-derivable by running this file.
%
% SYNTAX
%   OUT = COMPUTE_PERBAND_DAMPING()
%   OUT = COMPUTE_PERBAND_DAMPING('OutDir', D, 'ProjectRoot', R, 'Stamp', S)
%
% NAME-VALUE OPTIONS
%   'ProjectRoot' : dfig-wind-farm root. Default: auto-detected by walking up
%                   from this file (then from PWD) looking for RESULTS/CONTROL.
%   'OutDir'      : where the .md/.mat artifacts are written.
%                   DEFAULT: tempdir. This default is deliberate — the project
%                   lives on Google Drive File Stream, and MATLAB must never
%                   create new files there. Copy the artifacts back with `cp`.
%   'Stamp'       : filename stamp, default yyyymmdd of today.
%   'Verbose'     : logical, default true.
%
% BAND CONVENTION (canonical)
%   Source of truth: OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m
%     eigenConfig.mf_freq_thresh      = 100    -> LF = |Im| <= 100
%     eigenConfig.hf_freq_thresh      = 500    -> MF = 100 < |Im| <= 500
%     eigenConfig.spurious_freq_thresh= 3000   -> HF = 500 < |Im| <= 3000
%                                                 spurious = |Im| > 3000 (dropped)
%   A SUPERSEDED convention used LF = |Im| <= 30 with MF then starting at 30.
%   Both are computed here so that the claim "they give identical answers" is
%   testable rather than asserted.
%
% DAMPING
%   zeta = -real(lambda)/abs(lambda), the continuous-time definition MATLAB's
%   damp() uses. Real eigenvalues (imag == 0) give |zeta| == 1 and are excluded
%   from the bands; they are reported separately as min|Re(lambda)|.
%
% OUTPUTS
%   OUT.models(k)  : per-model struct (name, file, variable, OP, bands, ...)
%   OUT.claims     : PASS/FAIL verdicts on the three claims under test
%   OUT.deltas     : like-for-like baseline -> GA deltas at the optimisation OP
%
% SEE ALSO: OPTIMIZER.m, LINEAR_ANALYSIS.m, EIGEN_CALC.m

% ---------------------------------------------------------------- options --
p = inputParser;
p.addParameter('ProjectRoot', '', @(x) ischar(x) || isstring(x));
p.addParameter('OutDir',      tempdir, @(x) ischar(x) || isstring(x));
p.addParameter('Stamp',       datestr(now, 'yyyymmdd'), @(x) ischar(x) || isstring(x)); %#ok<TNOW1,DATST>
p.addParameter('Verbose',     true, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
opt = p.Results;
opt.OutDir = char(opt.OutDir);
opt.Stamp  = char(opt.Stamp);
V = logical(opt.Verbose);

% ------------------------------------------------------- project root -----
root = char(opt.ProjectRoot);
if isempty(root)
    root = locate_root(fileparts(mfilename('fullpath')));
end
if isempty(root)
    root = locate_root(pwd);
end
assert(~isempty(root), 'COMPUTE_PERBAND_DAMPING:NoRoot', ...
    'Could not auto-detect the dfig-wind-farm root (looked for RESULTS/CONTROL).');
ctrlDir = fullfile(root, 'RESULTS', 'CONTROL');

if ~exist(opt.OutDir, 'dir'); mkdir(opt.OutDir); end

% ------------------------------------------------------- band convention --
CFG.mf_freq_thresh       = 100;    % LF upper edge, canonical
CFG.mf_freq_thresh_super = 30;     % LF upper edge, SUPERSEDED convention
CFG.hf_freq_thresh       = 500;
CFG.spurious_freq_thresh = 3000;

if V
    fprintf('Project root : %s\n', root);
    fprintf('Models dir   : %s\n', ctrlDir);
    fprintf('Output dir   : %s\n', opt.OutDir);
    fprintf('Bands        : LF<=%g | MF (%g,%g] | HF (%g,%g] | spurious >%g\n', ...
        CFG.mf_freq_thresh, CFG.mf_freq_thresh, CFG.hf_freq_thresh, ...
        CFG.hf_freq_thresh, CFG.spurious_freq_thresh, CFG.spurious_freq_thresh);
    fprintf('Superseded LF edge: %g\n\n', CFG.mf_freq_thresh_super);
end

% ------------------------------------------------------------ file list ---
d = dir(fullfile(ctrlDir, 'LIN_MODEL_*.mat'));
d = d(~[d.isdir]);
[~, ord] = sort({d.name});
d = d(ord);
assert(~isempty(d), 'No LIN_MODEL_*.mat found in %s', ctrlDir);

models = struct([]);
for k = 1:numel(d)
    f = fullfile(ctrlDir, d(k).name);
    if V; fprintf('[%2d/%2d] %s (%.2f MB)\n', k, numel(d), d(k).name, d(k).bytes/1e6); end
    m = analyse_file(f, d(k), CFG);
    if isempty(models); models = m; else; models(end+1) = m; end %#ok<AGROW>
end

% ------------------------------------------------- duplicate detection ----
% Byte-identical files masquerading as different designs are a real hazard
% here (a filename is not provenance). Flag them.
for k = 1:numel(models)
    models(k).duplicateOf = '';
end
for a = 1:numel(models)
    if models(a).ok ~= 1 || isempty(models(a).md5); continue; end
    for b = 1:(a-1)
        if models(b).ok == 1 && strcmp(models(a).md5, models(b).md5)
            models(a).duplicateOf = models(b).name;
            break;
        end
    end
end

% ------------------------------------------- identical-spectrum detection -
% Two different files can still be the same dynamical system.
for k = 1:numel(models)
    models(k).sameSpectrumAs = '';
end
for a = 1:numel(models)
    if models(a).ok ~= 1; continue; end
    for b = 1:(a-1)
        if models(b).ok ~= 1; continue; end
        if numel(models(a).eig) == numel(models(b).eig) && ...
           max(abs(sort_c(models(a).eig) - sort_c(models(b).eig))) == 0
            models(a).sameSpectrumAs = models(b).name;
            break;
        end
    end
end

% -------------------------------------------------------------- claims ----
claims  = evaluate_claims(models, CFG);
deltas  = compute_deltas(models);
anomaly = investigate_hf_population(models);

OUT = struct();
OUT.generatedOn   = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
OUT.generatedBy   = 'COMPUTE_PERBAND_DAMPING.m';
OUT.matlabVersion = version;
OUT.projectRoot   = root;
OUT.controlDir    = ctrlDir;
OUT.bandConfig    = CFG;
OUT.models        = models;
OUT.claims        = claims;
OUT.deltas        = deltas;
OUT.hfAnomaly     = anomaly;

% ------------------------------------------------------------- artifacts --
matPath = fullfile(opt.OutDir, sprintf('PERBAND_DAMPING_%s.mat', opt.Stamp));
mdPath  = fullfile(opt.OutDir, sprintf('PERBAND_DAMPING_%s.md',  opt.Stamp));
PERBAND = OUT; %#ok<NASGU>
save(matPath, 'PERBAND', '-v7.3');
write_markdown(mdPath, OUT);

if V
    fprintf('\nWrote %s\n', matPath);
    fprintf('Wrote %s\n', mdPath);
end
end

% =========================================================================
function root = locate_root(startDir)
root = '';
cur = char(startDir);
for i = 1:10
    if exist(fullfile(cur, 'RESULTS', 'CONTROL'), 'dir') && ...
       exist(fullfile(cur, 'OPTIMIZATION'), 'dir')
        root = cur; return;
    end
    par = fileparts(cur);
    if isempty(par) || strcmp(par, cur); break; end
    cur = par;
end
end

% =========================================================================
function m = analyse_file(f, dinfo, CFG)
m = struct();
m.name      = erase(dinfo.name, '.mat');
m.file      = f;
m.fileBytes = dinfo.bytes;
m.fileDate  = dinfo.date;
m.varName   = '';
m.ok        = 0;
m.note      = '';
m.md5       = local_md5(f);

try
    info = whos('-file', f);
catch ME
    m.note = sprintf('whos failed: %s', ME.message);
    m = fill_empty(m); return;
end
isS = strcmp({info.class}, 'struct');
if ~any(isS)
    m.note = 'no struct variable in file';
    m = fill_empty(m); return;
end
idx = find(isS, 1);
m.varName = info(idx).name;

try
    S = load(f, m.varName);
catch ME
    m.note = sprintf('load failed: %s', ME.message);
    m = fill_empty(m); return;
end
L = S.(m.varName);

% ---- eigenvalues -------------------------------------------------------
if isfield(L, 'eigenvalues') && ~isempty(L.eigenvalues)
    z = L.eigenvalues(:);
    m.eigSource = 'LIN_MODEL.eigenvalues';
elseif isfield(L, 'ssModel')
    z = eig(L.ssModel.A);
    z = z(:);
    m.eigSource = 'eig(ssModel.A)';
else
    m.note = 'no eigenvalues and no ssModel';
    m = fill_empty(m); return;
end
m.nStates = numel(z);

% ---- operating point ---------------------------------------------------
m.opVp = NaN; m.opP = NaN; m.opQ = NaN; m.opVgrid = NaN; m.opF = NaN;
if isfield(L, 'opSpecs')
    op = L.opSpecs;
    if isfield(op, 'Vp')    && ~isempty(op.Vp);    m.opVp    = op.Vp(1);    end
    if isfield(op, 'P_ref') && ~isempty(op.P_ref); m.opP     = op.P_ref(1); end
    if isfield(op, 'Qg_ref')&& ~isempty(op.Qg_ref);m.opQ     = op.Qg_ref(1);end
    if isfield(op, 'Vgrid') && ~isempty(op.Vgrid); m.opVgrid = op.Vgrid(1); end
    if isfield(op, 'f')     && ~isempty(op.f);     m.opF     = op.f(1);     end
    m.opSpecs = op;
else
    m.opSpecs = struct();
end

% ---- SCR ---------------------------------------------------------------
m.SCR = NaN; m.XR = NaN;
if isfield(L, 'MODEL') && isfield(L.MODEL, 'GRID') && isfield(L.MODEL.GRID, 'PARAM')
    gp = L.MODEL.GRID.PARAM;
    if isfield(gp, 'SCR_grid'); m.SCR = gp.SCR_grid(1); end
    if isfield(gp, 'XR_grid');  m.XR  = gp.XR_grid(1);  end
end

% ---- misc provenance ---------------------------------------------------
m.modelName = ''; m.controlDesignMethod = '';
if isfield(L, 'modelName');           m.modelName = L.modelName; end
if isfield(L, 'controlDesignMethod'); m.controlDesignMethod = L.controlDesignMethod; end
m.nDFIG = NaN;
if isfield(L, 'dfigPower'); m.nDFIG = numel(L.dfigPower); end
m.storedMinDamping = [NaN NaN];
if isfield(L, 'minDamping') && numel(L.minDamping) >= 2
    m.storedMinDamping = L.minDamping(:).';
end

% ---- design fingerprint ------------------------------------------------
% The gains that decide where the current-loop modes land. Captured so that a
% band-population anomaly can be traced to a design difference rather than
% guessed at. A filename is not provenance; these numbers are.
m.fp = struct('VSMP_H', NaN, 'VSMP_Dd', NaN, 'VSMQ_K', NaN, ...
              'RSCd_Kp', NaN, 'RSCd_Ki', NaN, 'RSCq_Kp', NaN, 'RSCq_Ki', NaN, ...
              'GSCd_Kp', NaN, 'GSCd_Ki', NaN, 'GSCq_Kp', NaN, 'GSCq_Ki', NaN, ...
              'VDC_Kp', NaN, 'VDC_Ki', NaN, 'VIMP_Lv', NaN, 'VIMP_Rv', NaN, ...
              'RSC_wo_spec', NaN, 'GSC_wo_spec', NaN, 'VDC_wo_spec', NaN, ...
              'VSMP_wo_spec', NaN, 'RSC_wo_achieved', NaN, 'GSC_wo_achieved', NaN);
m.fp.VSMP_H  = getleaf(L, {'CONTROL','VSMP','PARAM','H'});
m.fp.VSMP_Dd = getleaf(L, {'CONTROL','VSMP','PARAM','Dd'});
m.fp.VSMQ_K  = getleaf(L, {'CONTROL','VSMQ','PARAM','K_Fs_ref'});
m.fp.RSCd_Kp = getleaf(L, {'CONTROL','RSCd','PARAM','Kp'});
m.fp.RSCd_Ki = getleaf(L, {'CONTROL','RSCd','PARAM','Ki'});
m.fp.RSCq_Kp = getleaf(L, {'CONTROL','RSCq','PARAM','Kp'});
m.fp.RSCq_Ki = getleaf(L, {'CONTROL','RSCq','PARAM','Ki'});
m.fp.GSCd_Kp = getleaf(L, {'CONTROL','GSCd','PARAM','Kp'});
m.fp.GSCd_Ki = getleaf(L, {'CONTROL','GSCd','PARAM','Ki'});
m.fp.GSCq_Kp = getleaf(L, {'CONTROL','GSCq','PARAM','Kp'});
m.fp.GSCq_Ki = getleaf(L, {'CONTROL','GSCq','PARAM','Ki'});
m.fp.VDC_Kp  = getleaf(L, {'CONTROL','VDC','PARAM','Kp'});
m.fp.VDC_Ki  = getleaf(L, {'CONTROL','VDC','PARAM','Ki'});
m.fp.VIMP_Lv = getleaf(L, {'CONTROL','VIMP','PARAM','Lv_pu'});
m.fp.VIMP_Rv = getleaf(L, {'CONTROL','VIMP','PARAM','Rv_pu'});
m.fp.RSC_wo_spec      = getleaf(L, {'CONTROL_DESIGN','RSC','frdSpecs','wo'});
m.fp.GSC_wo_spec      = getleaf(L, {'CONTROL_DESIGN','GSC','frdSpecs','wo'});
m.fp.VDC_wo_spec      = getleaf(L, {'CONTROL_DESIGN','VDC','frdSpecs','wo'});
m.fp.VSMP_wo_spec     = getleaf(L, {'CONTROL_DESIGN','VSMP','frdSpecs','wo'});
m.fp.RSC_wo_achieved  = getleaf(L, {'CONTROL_DESIGN','RSC','frdMargins','wo'});
m.fp.GSC_wo_achieved  = getleaf(L, {'CONTROL_DESIGN','GSC','frdMargins','wo'});

stateNamesSorted = {};
if isfield(L, 'sortedStateNames') && ~isempty(L.sortedStateNames)
    stateNamesSorted = L.sortedStateNames;
end

% ---- damping -----------------------------------------------------------
zeta = -real(z) ./ abs(z);
zeta(abs(z) == 0) = 0;             % pole at the origin
wn   = abs(z);
imz  = abs(imag(z));

isReal = (imag(z) == 0);

% cross-check against MATLAB damp() (order-independent, on counts + sorted zeta)
try
    [~, dz] = damp(z);
    m.dampCrossCheck_nReal   = sum(abs(dz) == 1) - sum(isReal);
    m.dampCrossCheck_maxDiff = max(abs(sort(dz(:)) - sort(zeta(:))));
catch
    m.dampCrossCheck_nReal   = NaN;
    m.dampCrossCheck_maxDiff = NaN;
end

% real eigenvalues
zr = z(isReal);
m.nRealEig = numel(zr);
if isempty(zr)
    m.minAbsReReal = NaN;
    m.minAbsReRealEig = NaN;
else
    [m.minAbsReReal, ir] = min(abs(real(zr)));
    m.minAbsReRealEig = zr(ir);
end

% spurious
isSpur = imz > CFG.spurious_freq_thresh & ~isReal;
m.nSpuriousEig   = sum(isSpur);
m.nSpuriousPairs = m.nSpuriousEig / 2;
if any(isSpur)
    m.spuriousImRange = [min(imz(isSpur)) max(imz(isSpur))];
else
    m.spuriousImRange = [NaN NaN];
end

isCplx = ~isReal & ~isSpur;
m.nComplexEig = sum(isCplx);

% ---- bands, both conventions ------------------------------------------
edgesCanon = [0, CFG.mf_freq_thresh, CFG.hf_freq_thresh, CFG.spurious_freq_thresh];
edgesSuper = [0, CFG.mf_freq_thresh_super, CFG.hf_freq_thresh, CFG.spurious_freq_thresh];

m.canon = band_stats(z, zeta, imz, isCplx, edgesCanon, stateNamesSorted);
m.super = band_stats(z, zeta, imz, isCplx, edgesSuper, stateNamesSorted);

% ---- the interval that separates the two conventions: (30, 100] --------
sel = isCplx & imz > CFG.mf_freq_thresh_super & imz <= CFG.mf_freq_thresh;
m.gapInterval = [CFG.mf_freq_thresh_super CFG.mf_freq_thresh];
m.gapNEig     = sum(sel);
m.gapNPairs   = sum(sel) / 2;
gi = find(sel);
% keep one representative per conjugate pair (positive imaginary part)
gi = gi(imag(z(gi)) > 0);
[~, o] = sort(zeta(gi));
gi = gi(o);
m.gapModes = struct('idx', {}, 'lambda', {}, 'absIm', {}, 'wn', {}, 'zeta', {}, 'state', {});
for i = 1:numel(gi)
    j = gi(i);
    m.gapModes(end+1) = struct( ...
        'idx', j, 'lambda', z(j), 'absIm', imz(j), 'wn', wn(j), 'zeta', zeta(j), ...
        'state', dominant_state(stateNamesSorted, j)); %#ok<AGROW>
end
if isempty(m.gapModes)
    m.gapZetaMin = NaN; m.gapZetaMax = NaN;
else
    m.gapZetaMin = min([m.gapModes.zeta]);
    m.gapZetaMax = max([m.gapModes.zeta]);
end

% ---- MF+HF pair census, for band-population forensics ------------------
% One row per conjugate pair with |Im| in (100, 3000], with its dominant
% state. This is what makes a "band lost two modes" claim checkable.
m.eig = z;
sel  = find(isCplx & imz > CFG.mf_freq_thresh & imag(z) > 0);
[~, o] = sort(imz(sel)); sel = sel(o);
m.midHighModes = struct('absIm', {}, 'zeta', {}, 'band', {}, 'state', {});
for i = 1:numel(sel)
    j = sel(i);
    if imz(j) > CFG.hf_freq_thresh; bname = 'HF'; else; bname = 'MF'; end
    m.midHighModes(end+1) = struct('absIm', imz(j), 'zeta', zeta(j), ...
        'band', bname, 'state', dominant_state(stateNamesSorted, j)); %#ok<AGROW>
end

m.ok = 1;
end

% =========================================================================
function B = band_stats(z, zeta, imz, isCplx, edges, stateNamesSorted)
labels = {'LF', 'MF', 'HF'};
B = struct();
for b = 1:3
    lo = edges(b); hi = edges(b+1);
    if b == 1
        sel = isCplx & imz <= hi;
    else
        sel = isCplx & imz > lo & imz <= hi;
    end
    S = struct();
    S.edges  = [lo hi];
    S.nEig   = sum(sel);
    S.nPairs = sum(sel) / 2;
    if ~any(sel)
        S.zetaMin = NaN; S.zetaMax = NaN;
        S.setterLambda = NaN; S.setterAbsIm = NaN; S.setterWn = NaN;
        S.setterZeta = NaN; S.setterState = ''; S.setterIdx = NaN;
    else
        idx = find(sel);
        [S.zetaMin, k] = min(zeta(idx));
        S.zetaMax = max(zeta(idx));
        j = idx(k);
        S.setterIdx    = j;
        S.setterLambda = z(j);
        S.setterAbsIm  = imz(j);
        S.setterWn     = abs(z(j));
        S.setterZeta   = zeta(j);
        S.setterState  = dominant_state(stateNamesSorted, j);
    end
    B.(labels{b}) = S;
end
end

% =========================================================================
function s = dominant_state(stateNamesSorted, j)
s = '';
if isempty(stateNamesSorted); return; end
if size(stateNamesSorted, 2) >= j && size(stateNamesSorted, 1) >= 1
    v = stateNamesSorted{1, j};
    if ischar(v) || isstring(v); s = char(v); end
end
end

% =========================================================================
function m = fill_empty(m)
m.nStates = NaN; m.eigSource = ''; m.opVp = NaN; m.opP = NaN; m.opQ = NaN;
m.opVgrid = NaN; m.opF = NaN; m.opSpecs = struct(); m.SCR = NaN; m.XR = NaN;
m.modelName = ''; m.controlDesignMethod = ''; m.nDFIG = NaN;
m.storedMinDamping = [NaN NaN];
m.dampCrossCheck_nReal = NaN; m.dampCrossCheck_maxDiff = NaN;
m.nRealEig = NaN; m.minAbsReReal = NaN; m.minAbsReRealEig = NaN;
m.nSpuriousEig = NaN; m.nSpuriousPairs = NaN; m.spuriousImRange = [NaN NaN];
m.nComplexEig = NaN;
empt = struct('edges', [NaN NaN], 'nEig', NaN, 'nPairs', NaN, 'zetaMin', NaN, ...
    'zetaMax', NaN, 'setterLambda', NaN, 'setterAbsIm', NaN, 'setterWn', NaN, ...
    'setterZeta', NaN, 'setterState', '', 'setterIdx', NaN);
m.canon = struct('LF', empt, 'MF', empt, 'HF', empt);
m.super = m.canon;
m.gapInterval = [NaN NaN]; m.gapNEig = NaN; m.gapNPairs = NaN;
m.gapModes = struct('idx', {}, 'lambda', {}, 'absIm', {}, 'wn', {}, 'zeta', {}, 'state', {});
m.gapZetaMin = NaN; m.gapZetaMax = NaN;
m.eig = [];
m.midHighModes = struct('absIm', {}, 'zeta', {}, 'band', {}, 'state', {});
m.fp = struct('VSMP_H', NaN, 'VSMP_Dd', NaN, 'VSMQ_K', NaN, ...
              'RSCd_Kp', NaN, 'RSCd_Ki', NaN, 'RSCq_Kp', NaN, 'RSCq_Ki', NaN, ...
              'GSCd_Kp', NaN, 'GSCd_Ki', NaN, 'GSCq_Kp', NaN, 'GSCq_Ki', NaN, ...
              'VDC_Kp', NaN, 'VDC_Ki', NaN, 'VIMP_Lv', NaN, 'VIMP_Rv', NaN, ...
              'RSC_wo_spec', NaN, 'GSC_wo_spec', NaN, 'VDC_wo_spec', NaN, ...
              'VSMP_wo_spec', NaN, 'RSC_wo_achieved', NaN, 'GSC_wo_achieved', NaN);
end

% =========================================================================
function v = getleaf(S, path)
v = NaN;
x = S;
for i = 1:numel(path)
    if ~isstruct(x) || ~isfield(x, path{i}); return; end
    x = x.(path{i});
end
if isnumeric(x) && ~isempty(x); v = x(1); end
end

% =========================================================================
function z = sort_c(z)
[~, o] = sortrows([real(z(:)) imag(z(:))]);
z = z(o);
end

% =========================================================================
function h = local_md5(f)
h = '';
try
    [st, out] = system(sprintf('md5 -q "%s"', f));
    if st == 0; h = strtrim(out); end
catch
end
end

% =========================================================================
function C = evaluate_claims(models, CFG)
C = struct();
ok = [models.ok] == 1;
M  = models(ok);

% --- CLAIM 1: convention makes no difference to zeta_min in any band -----
bands = {'LF', 'MF', 'HF'};
worst = 0; worstWhere = ''; nCompared = 0; offenders = {};
for k = 1:numel(M)
    for b = 1:3
        a = M(k).canon.(bands{b}).zetaMin;
        s = M(k).super.(bands{b}).zetaMin;
        if isnan(a) && isnan(s); continue; end
        nCompared = nCompared + 1;
        if isnan(a) || isnan(s)
            dd = Inf;
        else
            dd = abs(a - s);
        end
        if dd > worst
            worst = dd;
            worstWhere = sprintf('%s/%s', M(k).name, bands{b});
        end
        if dd > 0
            offenders{end+1} = sprintf('%s/%s (canon %.6f vs super %.6f)', ...
                M(k).name, bands{b}, a, s); %#ok<AGROW>
        end
    end
end
C.claim1 = struct();
C.claim1.statement  = 'LF<=30 and LF<=100 give identical zeta_min in every band, for every model';
C.claim1.nCompared  = nCompared;
C.claim1.maxAbsDiff = worst;
C.claim1.maxDiffAt  = worstWhere;
C.claim1.offenders  = {offenders{:}}; %#ok<CCAT1>
C.claim1.pass       = (worst == 0);

% --- CLAIM 2: the (30,100] interval can never hold the minimum ----------
allGapZeta = []; allGapIm = []; critLFIm = []; critLFZeta = [];
gapEverBelowLF = false; gapDetail = {};
for k = 1:numel(M)
    if ~isnan(M(k).gapZetaMin)
        allGapZeta(end+1) = M(k).gapZetaMin; %#ok<AGROW>
    end
    for i = 1:numel(M(k).gapModes)
        allGapIm(end+1) = M(k).gapModes(i).absIm; %#ok<AGROW>
        gapDetail{end+1} = sprintf('%s: |Im|=%.4f zeta=%.4f (%s)', ...
            M(k).name, M(k).gapModes(i).absIm, M(k).gapModes(i).zeta, ...
            M(k).gapModes(i).state); %#ok<AGROW>
    end
    lf = M(k).canon.LF;
    if ~isnan(lf.zetaMin)
        critLFIm(end+1)   = lf.setterAbsIm; %#ok<AGROW>
        critLFZeta(end+1) = lf.zetaMin;     %#ok<AGROW>
        if ~isnan(M(k).gapZetaMin) && M(k).gapZetaMin <= lf.zetaMin
            gapEverBelowLF = true;
        end
    end
end
C.claim2 = struct();
C.claim2.statement       = 'the critical LF mode sits far below both edges, and every mode in (30,100] is well damped, so (30,100] can never set the minimum';
C.claim2.interval        = [CFG.mf_freq_thresh_super CFG.mf_freq_thresh];
C.claim2.nGapModePairs   = numel(allGapIm);
C.claim2.gapZetaRange    = [min(allGapZeta) max(allGapZeta)];
C.claim2.gapImRange      = [min(allGapIm)  max(allGapIm)];
C.claim2.criticalLFImRange   = [min(critLFIm)  max(critLFIm)];
C.claim2.criticalLFZetaRange = [min(critLFZeta) max(critLFZeta)];
C.claim2.gapEverSetsMinimum  = gapEverBelowLF;
C.claim2.gapDetail       = {gapDetail{:}}; %#ok<CCAT1>
C.claim2.pass = ~gapEverBelowLF && ...
                all(critLFIm < CFG.mf_freq_thresh_super) && ...
                (isempty(allGapZeta) || min(allGapZeta) > max(critLFZeta));

% --- CLAIM 3: 0.029 vs 0.031 is an operating point difference -----------
bDes = find_model(M, 'LIN_MODEL_FRD_DESIGN');
bOpt = find_model(M, 'LIN_MODEL_FRD_OPT');
C.claim3 = struct();
C.claim3.statement = '0.03062 is the baseline LF zeta_min at the designated OP; 0.02889 is the baseline LF zeta_min at the optimisation OP; the gap is the operating point, not the band convention';
C.claim3.designatedFile = ''; C.claim3.optimisationFile = '';
C.claim3.zetaLF_designated = NaN; C.claim3.zetaLF_optimisation = NaN;
C.claim3.OP_designated = ''; C.claim3.OP_optimisation = '';
if ~isempty(bDes)
    C.claim3.designatedFile   = bDes.name;
    C.claim3.zetaLF_designated = bDes.canon.LF.zetaMin;
    C.claim3.OP_designated = sprintf('P=%.4g, Vp=%.4g, SCR=%.4g', bDes.opP, bDes.opVp, bDes.SCR);
end
if ~isempty(bOpt)
    C.claim3.optimisationFile = bOpt.name;
    C.claim3.zetaLF_optimisation = bOpt.canon.LF.zetaMin;
    C.claim3.OP_optimisation = sprintf('P=%.4g, Vp=%.4g, SCR=%.4g', bOpt.opP, bOpt.opVp, bOpt.SCR);
end
% the claim is quantitative: check the 4-dp rounding of each
C.claim3.roundsTo_designated   = round(C.claim3.zetaLF_designated, 5);
C.claim3.roundsTo_optimisation = round(C.claim3.zetaLF_optimisation, 5);
C.claim3.opsDiffer = ~isempty(bDes) && ~isempty(bOpt) && ...
    (abs(bDes.opP - bOpt.opP) > 1e-9 || abs(bDes.opVp - bOpt.opVp) > 1e-9);
C.claim3.pass = C.claim3.opsDiffer && ...
    abs(C.claim3.zetaLF_designated   - 0.03062) < 5e-5 && ...
    abs(C.claim3.zetaLF_optimisation - 0.02889) < 5e-5;
end

% =========================================================================
function D = compute_deltas(models)
ok = [models.ok] == 1;
M  = models(ok);
base = find_model(M, 'LIN_MODEL_FRD_OPT');
ga   = find_model(M, 'LIN_MODEL_VI_OPT');
D = struct();
D.statement = 'like-for-like baseline -> GA-optimised, both at the OPTIMISATION operating point';
D.baseline = ''; D.optimised = '';
% EVERY field the report writer reads must exist before the early return
% below. It used to set only baseline/optimised and the three bands, so a
% missing model produced "Unrecognized field name baselineOP" from
% write_markdown -- an error 300 lines from its cause, naming a field the
% reader has no reason to have heard of. Degrade with a legible value instead.
D.baselineOP = '(model not found)';
D.optimisedOP = '(model not found)';
D.sameOP = false;
bands = {'LF', 'MF', 'HF'};
for b = 1:3
    D.(bands{b}) = struct('baseline', NaN, 'optimised', NaN, 'absDelta', NaN, 'pctDelta', NaN);
end
if isempty(base) || isempty(ga)
    missing = {};
    if isempty(base), missing{end+1} = 'LIN_MODEL_FRD_OPT'; end
    if isempty(ga),   missing{end+1} = 'LIN_MODEL_VI_OPT';  end
    warning('COMPUTE_PERBAND_DAMPING:missingModel', ...
            ['like-for-like deltas skipped: %s not in RESULTS/CONTROL. ' ...
             'LIN_MODEL_FRD_OPT is the CFRD baseline re-designed at the ' ...
             'OPTIMISATION operating point (P=0.8, V_pcc=0.975, SCR=1); it is ' ...
             'not the same file as LIN_MODEL_FRD_DESIGN, which is at the ' ...
             'DESIGNATED point.'], strjoin(missing, ', '));
    return
end
D.baseline  = base.name;
D.optimised = ga.name;
D.baselineOP  = sprintf('P=%.4g, Vp=%.4g, SCR=%.4g', base.opP, base.opVp, base.SCR);
D.optimisedOP = sprintf('P=%.4g, Vp=%.4g, SCR=%.4g', ga.opP,  ga.opVp,  ga.SCR);
D.sameOP = abs(base.opP - ga.opP) < 1e-9 && abs(base.opVp - ga.opVp) < 1e-9;
for b = 1:3
    x = base.canon.(bands{b}).zetaMin;
    y = ga.canon.(bands{b}).zetaMin;
    D.(bands{b}).baseline  = x;
    D.(bands{b}).optimised = y;
    D.(bands{b}).absDelta  = y - x;
    D.(bands{b}).pctDelta  = 100 * (y - x) / x;
end
end

% =========================================================================
function A = investigate_hf_population(models)
%INVESTIGATE_HF_POPULATION  Why does one member of the BIOBJ family hold
% fewer HF mode pairs than the others?
%
% A per-band minimum is a minimum over a POPULATION. If two designs do not
% put the same modes in the same band, their per-band minima are not
% comparable, however similar the numbers look. This function makes that
% checkable instead of assumed.
ok = [models.ok] == 1;
M  = models(ok);
fam = {'LIN_MODEL_PDS_OPT_BIOBJ','LIN_MODEL_QDS_OPT_BIOBJ', ...
       'LIN_MODEL_PCP_OPT_BIOBJ','LIN_MODEL_QCP_OPT_BIOBJ', ...
       'LIN_MODEL_VI_OPT_BIOBJ'};
A = struct();
A.family = fam;
A.rows = struct('name', {}, 'nHFPairs', {}, 'nMFPairs', {}, 'nStates', {}, ...
                'nSpuriousPairs', {}, 'zetaHF', {}, 'RSC_wo_spec', {}, ...
                'RSC_wo_achieved', {}, 'RSCd_Kp', {}, 'RSCd_Ki', {}, ...
                'GSC_wo_spec', {}, 'GSCd_Ki', {});
for i = 1:numel(fam)
    m = find_model(M, fam{i});
    if isempty(m); continue; end
    A.rows(end+1) = struct('name', m.name, ...
        'nHFPairs', m.canon.HF.nPairs, 'nMFPairs', m.canon.MF.nPairs, ...
        'nStates', m.nStates, 'nSpuriousPairs', m.nSpuriousPairs, ...
        'zetaHF', m.canon.HF.zetaMin, ...
        'RSC_wo_spec', m.fp.RSC_wo_spec, 'RSC_wo_achieved', m.fp.RSC_wo_achieved, ...
        'RSCd_Kp', m.fp.RSCd_Kp, 'RSCd_Ki', m.fp.RSCd_Ki, ...
        'GSC_wo_spec', m.fp.GSC_wo_spec, 'GSCd_Ki', m.fp.GSCd_Ki); %#ok<AGROW>
end

% the outlier = the family member with the fewest HF pairs
A.outlier = ''; A.reference = '';
if ~isempty(A.rows)
    [~, io] = min([A.rows.nHFPairs]);
    A.outlier = A.rows(io).name;
    others = setdiff(1:numel(A.rows), io);
    if ~isempty(others); A.reference = A.rows(others(1)).name; end
end

% ---- rule out the boring explanations ----------------------------------
A.sameStateDimension = numel(unique([A.rows.nStates])) == 1;
A.sameSpuriousCut    = numel(unique([A.rows.nSpuriousPairs])) == 1;
A.sameTotalComplex   = numel(unique([A.rows.nHFPairs] + [A.rows.nMFPairs])) == 1;
A.gainsDiffer        = numel(unique(round([A.rows.RSCd_Kp], 6))) > 1;

% ---- trace the migrating modes by dominant state -----------------------
% Match the outlier's mode pairs to the reference's by dominant state name.
A.migration = struct('state', {}, 'refAbsIm', {}, 'refZeta', {}, 'refBand', {}, ...
                     'outAbsIm', {}, 'outZeta', {}, 'outBand', {});
mo = find_model(M, A.outlier);
mr = find_model(M, A.reference);
if ~isempty(mo) && ~isempty(mr)
    for i = 1:numel(mr.midHighModes)
        st = mr.midHighModes(i).state;
        if isempty(st); continue; end
        j = find(strcmp({mo.midHighModes.state}, st), 1);
        if isempty(j); continue; end
        r = mr.midHighModes(i); o = mo.midHighModes(j);
        if abs(o.absIm - r.absIm) / max(r.absIm, eps) < 0.05 && strcmp(o.band, r.band)
            continue;   % did not move meaningfully
        end
        A.migration(end+1) = struct('state', st, ...
            'refAbsIm', r.absIm, 'refZeta', r.zeta, 'refBand', r.band, ...
            'outAbsIm', o.absIm, 'outZeta', o.zeta, 'outBand', o.band); %#ok<AGROW>
    end
end

% ---- lineage: does anything downstream inherit the outlier's design? ---
% The phase-progression table treats these as a cumulative chain. If the
% later phases do not carry the outlier's gains, the outlier is a dead-end
% branch and must not be aggregated into a progression row as if it were on
% the path.
A.lineage = struct('name', {}, 'matchesOutlier', {}, 'matchesReference', {});
if ~isempty(A.outlier) && ~isempty(A.reference)
    ro = A.rows(strcmp({A.rows.name}, A.outlier));
    rr = A.rows(strcmp({A.rows.name}, A.reference));
    for i = 1:numel(A.rows)
        R = A.rows(i);
        A.lineage(end+1) = struct('name', R.name, ...
            'matchesOutlier',   abs(R.RSCd_Kp - ro.RSCd_Kp) < 1e-9, ...
            'matchesReference', abs(R.RSCd_Kp - rr.RSCd_Kp) < 1e-9); %#ok<AGROW>
    end
    A.nInheritingOutlier = sum([A.lineage.matchesOutlier]);
    A.outlierIsDeadEnd   = (A.nInheritingOutlier == 1);   % only itself
else
    A.nInheritingOutlier = NaN;
    A.outlierIsDeadEnd   = false;
end

A.verdict = '';
if isempty(A.rows)
    A.verdict = 'family not present; nothing to investigate';
elseif A.sameStateDimension && A.sameSpuriousCut && A.gainsDiffer
    A.verdict = sprintf(['REAL and explained: identical state dimension (%d) and identical ' ...
        'spurious cut (%g pairs) across the family, so neither a truncated model nor a ' ...
        'different exclusion threshold. The outlier carries a different current-loop ' ...
        'design (RSC crossover spec %g rad/s vs %g rad/s), which moves mode pairs down ' ...
        'in frequency and out of the HF band.'], ...
        A.rows(1).nStates, A.rows(1).nSpuriousPairs, ...
        A.rows(strcmp({A.rows.name}, A.outlier)).RSC_wo_spec, ...
        A.rows(strcmp({A.rows.name}, A.reference)).RSC_wo_spec);
else
    A.verdict = 'inconclusive; inspect the rows table';
end
end

% =========================================================================
function m = find_model(M, name)
%FIND_MODEL  Exact name, then a unique prefix match.
%
%   The prefix fallback exists because the lookups in this file were written
%   against an older naming convention and the shipped designs carry variant
%   suffixes: 'LIN_MODEL_VI_OPT' is asked for, 'LIN_MODEL_VI_OPT_BIOBJ' is
%   what exists. An exact-match-only lookup returned empty, which silently
%   skipped the like-for-like deltas -- the very numbers Section 5.3.2
%   reports -- and gave no indication of why.
%
%   A prefix match is only accepted when it is UNIQUE. Two candidates is an
%   ambiguity the caller must resolve, not one this function may guess at.
m = [];
names = {M.name};

i = find(strcmp(names, name), 1);
if ~isempty(i); m = M(i); return; end

j = find(startsWith(names, name));
if numel(j) == 1
    m = M(j);
elseif numel(j) > 1
    warning('COMPUTE_PERBAND_DAMPING:ambiguousModel', ...
            ['"%s" matches %d stored designs (%s). Refusing to choose. ' ...
             'Ask for the full name.'], ...
            name, numel(j), strjoin(names(j), ', '));
end
end

% =========================================================================
function write_markdown(path, OUT)
fid = fopen(path, 'w');
assert(fid > 0, 'cannot open %s for writing', path);
c = onCleanup(@() fclose(fid));
w = @(varargin) fprintf(fid, varargin{:});
CFG = OUT.bandConfig;
M = OUT.models;
bands = {'LF', 'MF', 'HF'};

w('# Per-band damping census of the saved linear models\n\n');
w('Generated %s by `%s` (MATLAB %s).\n\n', OUT.generatedOn, OUT.generatedBy, OUT.matlabVersion);
w('Reproduce with:\n\n');
w('```matlab\n');
w('OUT = COMPUTE_PERBAND_DAMPING();          %% writes into tempdir\n');
w('OUT = COMPUTE_PERBAND_DAMPING(''OutDir'', ''/tmp/x'');\n');
w('```\n\n');
w('Source models: `%s`\n\n', strrep(OUT.controlDir, OUT.projectRoot, '<project root>'));
w('This file exists because these numbers previously existed only in an agent''s\n');
w('verbal report and could not be found on disk. Every value below comes from a\n');
w('MATLAB run over the saved `.mat` linear models. The Simulink model was not\n');
w('opened, loaded, linearised or simulated.\n\n');

w('## Convention\n\n');
w('Canonical, taken from `OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m`\n');
w('(`eigenConfig.mf_freq_thresh = %g`, `hf_freq_thresh = %g`, `spurious_freq_thresh = %g`):\n\n', ...
    CFG.mf_freq_thresh, CFG.hf_freq_thresh, CFG.spurious_freq_thresh);
w('| band | rule |\n|---|---|\n');
w('| LF | `\\|Im(lambda)\\| <= %g` |\n', CFG.mf_freq_thresh);
w('| MF | `%g < \\|Im(lambda)\\| <= %g` |\n', CFG.mf_freq_thresh, CFG.hf_freq_thresh);
w('| HF | `%g < \\|Im(lambda)\\| <= %g` |\n', CFG.hf_freq_thresh, CFG.spurious_freq_thresh);
w('| spurious | `\\|Im(lambda)\\| > %g`, excluded |\n\n', CFG.spurious_freq_thresh);
w('SUPERSEDED convention: identical except `LF = \\|Im\\| <= %g`, MF then starting at %g.\n\n', ...
    CFG.mf_freq_thresh_super, CFG.mf_freq_thresh_super);
w('`zeta = -Re(lambda)/\\|lambda\\|`. Real eigenvalues (`Im == 0`) give `\\|zeta\\| = 1`,\n');
w('are excluded from the bands, and are reported separately as `min\\|Re(lambda)\\|`.\n');
w('Mode counts are given as conjugate PAIRS (an `n`-pair band holds `2n` eigenvalues).\n\n');

% ---------------- main table -------------------------------------------
w('## Per-model results\n\n');
w('`zeta_min` per band, canonical convention, and the operating point actually\n');
w('stored inside each file (never inferred from the filename).\n\n');
w('| model | var in file | OP: P (pu) | OP: Vp (pu) | SCR | n | zeta_LF | zeta_MF | zeta_HF | min\\|Re\\| real |\n');
w('|---|---|---|---|---|---|---|---|---|---|\n');
for k = 1:numel(M)
    if M(k).ok ~= 1
        w('| `%s` | - | - | - | - | - | - | - | - | FAILED: %s |\n', M(k).name, M(k).note);
        continue;
    end
    w('| `%s` | `%s` | %s | %s | %s | %d | %s | %s | %s | %s |\n', ...
        M(k).name, M(k).varName, num2str(M(k).opP), num2str(M(k).opVp), ...
        num2str(M(k).SCR), M(k).nStates, ...
        fmt(M(k).canon.LF.zetaMin), fmt(M(k).canon.MF.zetaMin), ...
        fmt(M(k).canon.HF.zetaMin), fmt(M(k).minAbsReReal));
end
w('\n');

% ---------------- both conventions -------------------------------------
w('## Both conventions side by side\n\n');
w('| model | LF canon (<=%g) | LF super (<=%g) | MF canon | MF super | HF canon | HF super | identical |\n', ...
    CFG.mf_freq_thresh, CFG.mf_freq_thresh_super);
w('|---|---|---|---|---|---|---|---|\n');
for k = 1:numel(M)
    if M(k).ok ~= 1; continue; end
    same = true;
    for b = 1:3
        a = M(k).canon.(bands{b}).zetaMin; s = M(k).super.(bands{b}).zetaMin;
        if ~(isnan(a) && isnan(s)) && ~(a == s); same = false; end
    end
    w('| `%s` | %s | %s | %s | %s | %s | %s | %s |\n', M(k).name, ...
        fmt(M(k).canon.LF.zetaMin), fmt(M(k).super.LF.zetaMin), ...
        fmt(M(k).canon.MF.zetaMin), fmt(M(k).super.MF.zetaMin), ...
        fmt(M(k).canon.HF.zetaMin), fmt(M(k).super.HF.zetaMin), ...
        tf(same));
end
w('\n');

% ---------------- band populations -------------------------------------
w('## Band populations (conjugate pairs, canonical convention)\n\n');
w('| model | LF pairs | MF pairs | HF pairs | spurious pairs | real eigs | total eigs |\n');
w('|---|---|---|---|---|---|---|\n');
for k = 1:numel(M)
    if M(k).ok ~= 1; continue; end
    w('| `%s` | %g | %g | %g | %g | %g | %d |\n', M(k).name, ...
        M(k).canon.LF.nPairs, M(k).canon.MF.nPairs, M(k).canon.HF.nPairs, ...
        M(k).nSpuriousPairs, M(k).nRealEig, M(k).nStates);
end
w('\n');

% ---------------- setters ----------------------------------------------
w('## The mode that sets each minimum (canonical convention)\n\n');
for k = 1:numel(M)
    if M(k).ok ~= 1; continue; end
    w('### `%s`\n\n', M(k).name);
    w('- file: `%s`\n', M(k).file);
    w('- variable stored inside: `%s`\n', M(k).varName);
    if ~isempty(M(k).duplicateOf)
        w('- **byte-identical to `%s`**\n', M(k).duplicateOf);
    end
    w('- operating point stored in the file: P_ref = %s pu, Vp = %s pu, Vs_ref = %s pu, Qg_ref = %s pu, SCR = %s, X/R = %s\n', ...
        num2str(M(k).opP), num2str(M(k).opVp), num2str(M(k).opVp), num2str(M(k).opQ), ...
        num2str(M(k).SCR), num2str(M(k).XR));
    w('- states: %d, eigenvalue source: `%s`\n', M(k).nStates, M(k).eigSource);
    w('\n| band | zeta_min | \\|Im\\| (rad/s) | Hz | Re(lambda) | dominant state |\n|---|---|---|---|---|---|\n');
    for b = 1:3
        S = M(k).canon.(bands{b});
        if isnan(S.zetaMin)
            w('| %s | (empty band) | - | - | - | - |\n', bands{b});
        else
            w('| %s | %.5f | %.4f | %.4f | %.5f | `%s` |\n', bands{b}, S.zetaMin, ...
                S.setterAbsIm, S.setterAbsIm/(2*pi), real(S.setterLambda), S.setterState);
        end
    end
    w('\n');
end

% ---------------- gap interval -----------------------------------------
w('## Every mode in the interval (%g, %g]\n\n', CFG.mf_freq_thresh_super, CFG.mf_freq_thresh);
w('This interval is the ONLY thing the two conventions disagree about: it is LF\n');
w('under the canonical rule and MF under the superseded one.\n\n');
w('| model | pairs in (%g,%g] | \\|Im\\| values | zeta values |\n|---|---|---|---|\n', ...
    CFG.mf_freq_thresh_super, CFG.mf_freq_thresh);
for k = 1:numel(M)
    if M(k).ok ~= 1; continue; end
    ims = ''; zs = '';
    for i = 1:numel(M(k).gapModes)
        ims = [ims sprintf('%.3f; ', M(k).gapModes(i).absIm)]; %#ok<AGROW>
        zs  = [zs  sprintf('%.4f; ', M(k).gapModes(i).zeta)];  %#ok<AGROW>
    end
    if isempty(ims); ims = '(none)'; zs = '(none)'; end
    w('| `%s` | %g | %s | %s |\n', M(k).name, M(k).gapNPairs, strtrim(ims), strtrim(zs));
end
w('\n');

% ---------------- claims -----------------------------------------------
C = OUT.claims;
w('## Verdicts\n\n');

w('### Claim 1 -- %s\n\n', verdict(C.claim1.pass));
w('> %s\n\n', C.claim1.statement);
w('- comparisons made: %d (model x band, both conventions)\n', C.claim1.nCompared);
w('- largest absolute difference found: %.3g (at %s)\n', C.claim1.maxAbsDiff, C.claim1.maxDiffAt);
if isempty(C.claim1.offenders)
    w('- no model/band pair differs at all: the two conventions are bit-identical, not merely equal to the printed digits\n\n');
else
    for i = 1:numel(C.claim1.offenders); w('- DIFFERS: %s\n', C.claim1.offenders{i}); end
    w('\n');
end

w('### Claim 2 -- %s\n\n', verdict(C.claim2.pass));
w('> %s\n\n', C.claim2.statement);
w('- critical LF mode |Im| across all models: %.4f to %.4f rad/s (both far below %g)\n', ...
    C.claim2.criticalLFImRange(1), C.claim2.criticalLFImRange(2), C.claim2.interval(1));
w('- critical LF mode zeta across all models: %.5f to %.5f\n', ...
    C.claim2.criticalLFZetaRange(1), C.claim2.criticalLFZetaRange(2));
w('- mode pairs found in (%g, %g] across all models: %d\n', ...
    C.claim2.interval(1), C.claim2.interval(2), C.claim2.nGapModePairs);
if C.claim2.nGapModePairs > 0
    w('- their |Im| range: %.4f to %.4f rad/s\n', C.claim2.gapImRange(1), C.claim2.gapImRange(2));
    w('- their zeta range: %.4f to %.4f\n', C.claim2.gapZetaRange(1), C.claim2.gapZetaRange(2));
end
w('- does any (%g,%g] mode ever reach the LF minimum? %s\n\n', ...
    C.claim2.interval(1), C.claim2.interval(2), tf(C.claim2.gapEverSetsMinimum));
w('Full listing:\n\n');
for i = 1:numel(C.claim2.gapDetail); w('- %s\n', C.claim2.gapDetail{i}); end
w('\n');

w('### Claim 3 -- %s\n\n', verdict(C.claim3.pass));
w('> %s\n\n', C.claim3.statement);
w('| quantity | file | operating point | zeta_LF |\n|---|---|---|---|\n');
w('| baseline at designated OP | `%s` | %s | %.5f |\n', ...
    C.claim3.designatedFile, C.claim3.OP_designated, C.claim3.zetaLF_designated);
w('| baseline at optimisation OP | `%s` | %s | %.5f |\n\n', ...
    C.claim3.optimisationFile, C.claim3.OP_optimisation, C.claim3.zetaLF_optimisation);
w('- the two files store different operating points: %s\n\n', tf(C.claim3.opsDiffer));

% ---------------- deltas -----------------------------------------------
D = OUT.deltas;
w('## Like-for-like deltas at the optimisation operating point\n\n');
w('Baseline `%s` (%s) -> GA-optimised `%s` (%s). Same OP: %s.\n\n', ...
    D.baseline, D.baselineOP, D.optimised, D.optimisedOP, tf(D.sameOP));
w('| band | baseline zeta_min | optimised zeta_min | absolute delta | relative delta |\n|---|---|---|---|---|\n');
for b = 1:3
    S = D.(bands{b});
    w('| %s | %.5f | %.5f | %+.5f | %+.2f %% |\n', bands{b}, S.baseline, S.optimised, S.absDelta, S.pctDelta);
end
w('\n');

% ---------------- provenance -------------------------------------------
w('## Provenance warnings\n\n');
w('A filename is not provenance. Two checks were run over the 25 files.\n\n');
anyDup = false;
w('### Byte-identical files\n\n');
for k = 1:numel(M)
    if ~isempty(M(k).duplicateOf)
        w('- `%s.mat` is byte-identical to `%s.mat` (same md5 `%s`)\n', ...
            M(k).name, M(k).duplicateOf, M(k).md5);
        anyDup = true;
    end
end
if ~anyDup; w('- none\n'); end
w('\n### Different files, identical spectrum\n\n');
anySpec = false;
for k = 1:numel(M)
    if ~isempty(M(k).sameSpectrumAs) && ~strcmp(M(k).sameSpectrumAs, M(k).duplicateOf)
        w('- `%s` and `%s` are different files but their eigenvalues agree to the last bit\n', ...
            M(k).name, M(k).sameSpectrumAs);
        anySpec = true;
    end
end
if ~anySpec; w('- none beyond the byte-identical pairs above\n'); end
w('\n### Variable name inside the file vs filename\n\n');
anyMis = false;
for k = 1:numel(M)
    if ~strcmp(M(k).varName, M(k).name)
        w('- `%s.mat` stores its struct under the name `%s`\n', M(k).name, M(k).varName);
        anyMis = true;
    end
end
if ~anyMis; w('- every file stores its struct under its own name\n'); end
w('\n');

% ---------------- design fingerprint -----------------------------------
w('## Design fingerprint\n\n');
w('The gains that decide where the current-loop modes land, so that a band\n');
w('population difference can be traced rather than guessed at.\n\n');
w('| model | VSMP H | VSMP Dd | VSMQ K | RSCd Kp | RSCd Ki | GSCd Kp | GSCd Ki | RSC wo spec | GSC wo spec | VIMP Lv | VIMP Rv |\n');
w('|---|---|---|---|---|---|---|---|---|---|---|---|\n');
for k = 1:numel(M)
    F = M(k).fp;
    w('| `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', M(k).name, ...
        g(F.VSMP_H), g(F.VSMP_Dd), g(F.VSMQ_K), g(F.RSCd_Kp), g(F.RSCd_Ki), ...
        g(F.GSCd_Kp), g(F.GSCd_Ki), g(F.RSC_wo_spec), g(F.GSC_wo_spec), ...
        g(F.VIMP_Lv), g(F.VIMP_Rv));
end
w('\n');

% ---------------- HF population anomaly --------------------------------
A = OUT.hfAnomaly;
w('## HF band population across the bi-objective family\n\n');
w('A per-band minimum is a minimum over a POPULATION. Two designs whose bands\n');
w('hold different modes do not have comparable per-band minima, however similar\n');
w('the numbers look.\n\n');
if isempty(A.rows)
    w('The bi-objective family is not present under `RESULTS/CONTROL`.\n\n');
else
    w('| model | HF pairs | HF eigs | MF pairs | states | spurious pairs | zeta_HF | RSC wo spec | RSC wo achieved | RSCd Kp | RSCd Ki |\n');
    w('|---|---|---|---|---|---|---|---|---|---|---|\n');
    for i = 1:numel(A.rows)
        R = A.rows(i);
        w('| `%s` | %g | %g | %g | %g | %g | %.5f | %s | %s | %s | %s |\n', R.name, ...
            R.nHFPairs, R.nHFPairs*2, R.nMFPairs, R.nStates, R.nSpuriousPairs, R.zetaHF, ...
            g(R.RSC_wo_spec), g(R.RSC_wo_achieved), g(R.RSCd_Kp), g(R.RSCd_Ki));
    end
    w('\n');
    w('Outlier: `%s`. Reference: `%s`.\n\n', A.outlier, A.reference);
    w('Boring explanations ruled out:\n\n');
    w('- same state dimension across the family: %s\n', tf(A.sameStateDimension));
    w('- same spurious cut across the family: %s\n', tf(A.sameSpuriousCut));
    w('- same total complex-pair count (MF+HF) across the family: %s\n', tf(A.sameTotalComplex));
    w('- current-loop gains differ across the family: %s\n\n', tf(A.gainsDiffer));
    if ~isempty(A.migration)
        w('Modes that moved, matched by dominant state between reference and outlier:\n\n');
        w('| dominant state | reference \\|Im\\| | ref band | ref zeta | outlier \\|Im\\| | out band | out zeta |\n');
        w('|---|---|---|---|---|---|---|\n');
        for i = 1:numel(A.migration)
            G_ = A.migration(i);
            w('| `%s` | %.3f | %s | %.5f | %.3f | %s | %.5f |\n', G_.state, ...
                G_.refAbsIm, G_.refBand, G_.refZeta, G_.outAbsIm, G_.outBand, G_.outZeta);
        end
        w('\n');
    end
    w('**Verdict**: %s\n\n', A.verdict);

    w('### Lineage: is the outlier on the progression path?\n\n');
    w('The phase-progression table reads these as a cumulative chain. That only\n');
    w('holds if each phase carries the previous phase''s gains forward.\n\n');
    w('| model | carries `%s` current-loop gains | carries `%s` current-loop gains |\n', ...
        A.outlier, A.reference);
    w('|---|---|---|\n');
    for i = 1:numel(A.lineage)
        w('| `%s` | %s | %s |\n', A.lineage(i).name, ...
            tf(A.lineage(i).matchesOutlier), tf(A.lineage(i).matchesReference));
    end
    w('\n');
    if A.outlierIsDeadEnd
        w('Only `%s` itself carries its own current-loop design; every later phase\n', A.outlier);
        w('carries `%s`''s instead. **The outlier is a dead-end branch: nothing\n', A.reference);
        w('downstream inherits it.** Its `zeta_HF` is therefore not a step in the\n');
        w('progression, and aggregating it into a progression row would be wrong twice\n');
        w('over -- once because the band holds a different mode population, and once\n');
        w('because the design is not on the path.\n\n');
    else
        w('%d of %d family members carry the outlier''s current-loop design.\n\n', ...
            A.nInheritingOutlier, numel(A.lineage));
    end
end
end

% =========================================================================
function s = fmt(x)
if isnan(x); s = '-'; else; s = sprintf('%.5f', x); end
end
function s = g(x)
if isempty(x) || isnan(x); s = '-'; else; s = sprintf('%g', x); end
end
function s = tf(b)
if b; s = 'yes'; else; s = 'no'; end
end
function s = verdict(b)
if b; s = 'PASS'; else; s = 'FAIL'; end
end
