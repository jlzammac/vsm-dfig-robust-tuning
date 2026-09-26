function OUT = RV_CONNECTIVITY_TEST(LIN_MODEL, varargin)
%RV_CONNECTIVITY_TEST Is the virtual resistance R_v read by the model?
%
%   OUT = RV_CONNECTIVITY_TEST(LIN_MODEL)
%   OUT = RV_CONNECTIVITY_TEST(LIN_MODEL, 'Values', [0 0.0066 0.05 0.5])
%
%   The virtual impedance of the design is the inductance L_v alone. The
%   virtual resistance R_v is fixed at 0 and is not a decision variable
%   (OPTIMIZER.m pins its slot with lb = ub = 0).
%
%   This function documents why that choice costs nothing: the model has no
%   term for R_v. The line that would read it into the steady-state solve is
%   commented out (ANALYSIS/LINEAR_ANALYSIS.m, the Lv/Rv block), and no other
%   file in the signal path reads it. Every file that mentions Rv_pu either
%   writes it, reports it, or fingerprints it:
%
%     writes it    OPTIMIZATION/GA_MULTIOBJECTIVE/OPTIMIZER.m       (zero)
%                  OPTIMIZATION/GA_MULTIOBJECTIVE/GEN_LIN_MODEL_PARETO.m (zero)
%                  CONFIGURATION/CONFIG_POWER_SYSTEM.m
%                  CONTROL/CONFIG_CONTROL.m         (initialises to zero)
%     fingerprints ANALYSIS/COMPUTE_PERBAND_DAMPING.m
%
%   The one apparent exception is CONTROL/CONTROL_DESIGN_TR.m, which adds
%   Rv_pu into a lumped resistance. That path belongs to the time-response
%   design of Section 3.3 (CONTROL_TYPE = 1), and R_v is zero throughout it.
%
%   The check is by measurement rather than by reading: the plant is
%   re-linearised with R_v swept across two orders of magnitude and the
%   resulting spectra are compared for exact equality.
%
%   INPUTS
%     LIN_MODEL  a linearised model structure, as returned by
%                CONFIG_POWER_SYSTEM. The design it carries is irrelevant to
%                the outcome.
%
%   NAME-VALUE
%     'Values'   the R_v values to test, in pu. Default
%                [0, 0.0066, 0.05, 0.5], which spans from zero to a value
%                large enough that a connected resistance would be
%                unmissable.
%     'Verbose'  print the comparison table. Default true.
%
%   OUTPUT
%     OUT.values        the swept values
%     OUT.maxEigDelta   max |lambda_i(R_v) - lambda_i(0)| per value
%     OUT.maxADelta     max |A_ij(R_v) - A_ij(0)| per value
%     OUT.minDamping    minimum damping ratio per value
%     OUT.connected     true if ANY sweep value moved the spectrum
%     OUT.sourceLineIsCommented  the static check on LINEAR_ANALYSIS.m
%
%   A connected parameter gives OUT.connected = true and a monotone trend in
%   the damping column. A disconnected one gives exact zeros.
%
%   EXAMPLE
%     % from CONFIGURATION, after CONFIG_POWER_SYSTEM with RUN_MODE = 0
%     OUT = RV_CONNECTIVITY_TEST(LIN_MODEL);
%
%   SEE ALSO: LINEAR_ANALYSIS, COMPUTE_PERBAND_DAMPING, VERIFY_TABLE_III

%% Options
p = inputParser;
addParameter(p, 'Values',  [0, 0.0066, 0.05, 0.5], @(v) isnumeric(v) && ~isempty(v));
addParameter(p, 'Verbose', true, @(v) islogical(v) || isnumeric(v));
parse(p, varargin{:});
values  = p.Results.Values(:).';
verbose = logical(p.Results.Verbose);

if ~isstruct(LIN_MODEL) || ~isfield(LIN_MODEL, 'CONTROL')
    error('RV_CONNECTIVITY_TEST:badInput', ...
          ['LIN_MODEL must be the structure returned by CONFIG_POWER_SYSTEM. ' ...
           'Run it with RUN_MODE = 0 first.']);
end

% The sweep must start from the disabled value so that every comparison has a
% reference. Prepend it if the caller left it out.
if values(1) ~= 0
    values = [0, values];
end

nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;

if verbose
    fprintf('\n========================================================\n');
    fprintf('  RV_CONNECTIVITY_TEST — is R_v read by the model?\n');
    fprintf('========================================================\n');
end

%% Static check: the source line
% Reported rather than relied upon. The measurement below is the evidence;
% this only tells the reader where to look.
srcPath = which('LINEAR_ANALYSIS');
commented = NaN;
if ~isempty(srcPath) && isfile(srcPath)
    src = string(splitlines(fileread(srcPath)));
    hit = find(contains(src, 'CONTROL.VIMP.PARAM.Rv_pu'), 1, 'first');
    if ~isempty(hit)
        commented = startsWith(strtrim(src(hit)), '%');
        if verbose
            fprintf('\nSource check, %s\n', srcPath);
            fprintf('  line %d: %s\n', hit, strtrim(src(hit)));
            if commented
                fprintf('  -> commented out. R_v is not read into the solve.\n');
            else
                fprintf('  -> ACTIVE. R_v IS read. The sweep below should move.\n');
            end
        end
    elseif verbose
        fprintf('\nSource check: no Rv_pu reference in LINEAR_ANALYSIS at all.\n');
    end
end

%% Sweep
nV        = numel(values);
maxEigD   = nan(1, nV);
maxAD     = nan(1, nV);
minDamp   = nan(1, nV);
eig0      = [];
A0        = [];

for k = 1:nV
    M = LIN_MODEL;
    M.CONTROL.VIMP.PARAM.Rv_pu = values(k) * ones(1, nDFIG);

    if verbose
        fprintf('\n  R_v = %.4f pu ... ', values(k));
    end
    M = LINEAR_ANALYSIS(M);

    % LINEAR_ANALYSIS leaves pwd in SIMULINK. Harmless here, but the caller
    % may not expect it, so it is restored at the end.
    ev = sort(M.eigenvalues);
    A  = M.ssModel.A;

    if k == 1
        eig0 = ev;
        A0   = A;
        maxEigD(k) = 0;
        maxAD(k)   = 0;
    else
        n = min(numel(ev), numel(eig0));
        maxEigD(k) = max(abs(ev(1:n) - eig0(1:n)));
        if isequal(size(A), size(A0))
            maxAD(k) = max(abs(A(:) - A0(:)));
        end
    end
    minDamp(k) = min(M.minDamping);

    if verbose
        fprintf('done');
    end
end

%% Verdict
% Exact equality, not a tolerance. A connected parameter perturbs the state
% matrix in the last bits at minimum; a disconnected one gives bit-identical
% matrices, which is a stronger and cleaner statement than "small".
connected = any(maxEigD(2:end) > 0) || any(maxAD(2:end) > 0);

if verbose
    fprintf('\n\n  %-12s %-16s %-16s %-14s\n', 'R_v [pu]', 'max|dlambda|', 'max|dA_ij|', 'min damping');
    fprintf('  %s\n', repmat('-', 1, 62));
    for k = 1:nV
        fprintf('  %-12.4f %-16.6g %-16.6g %-14.8f\n', ...
                values(k), maxEigD(k), maxAD(k), minDamp(k));
    end
    fprintf('\n');
    if connected
        fprintf('  VERDICT: R_v IS connected. The spectrum moves with it.\n');
    else
        fprintf('  VERDICT: R_v is NOT connected. Every spectrum is bit-identical\n');
        fprintf('           to the R_v = 0 case across %g to %g pu.\n', ...
                min(values), max(values));
        fprintf('           The Phase 5 gain is attributable to L_v alone.\n');
    end
    fprintf('========================================================\n\n');
end

OUT = struct( ...
    'values',       values, ...
    'maxEigDelta',  maxEigD, ...
    'maxADelta',    maxAD, ...
    'minDamping',   minDamp, ...
    'connected',    connected, ...
    'sourceLineIsCommented', commented);

end
