function r_src = b7_calibrate_depth(repoRoot, tag, SCR, P, V_target, dur, Thor, Vpcc, tol, maxIter)
%B7_CALIBRATE_DEPTH Find the source fraction that leaves a target PCC voltage.
%
% DESCRIPTION:
%   The fault is applied by scaling the Thevenin source behind Z_grid, but every
%   depth the paper quotes is the voltage RETAINED AT THE PCC. The two are not
%   proportional and the relation depends on grid strength and dispatch, so the
%   source fraction has to be found per operating point. This is the bisection
%   that produced the stored fractions of the campaign.
%
%   The mapping is monotonic — a deeper source event leaves a lower PCC voltage,
%   all else equal — which is what makes bisection appropriate. Monotonicity is
%   checked at the bracket ends before the search starts rather than assumed.
%
% INPUTS:
%   repoRoot - Repository root.
%   tag      - Run identifier, used to name working copies.
%   SCR, P   - Grid strength and dispatch of the operating point.
%   V_target - Retained PCC voltage to hit [pu].
%   dur,Thor - Fault duration and simulation horizon [s].
%   Vpcc     - Pre-fault PCC voltage [pu].
%   tol      - (optional) Tolerance on the retained PCC voltage. Default 0.002 pu,
%              which is tighter than the 0.006 pu the published campaign achieved
%              at its shallow level.
%   maxIter  - (optional) Maximum bisection steps. Default 12.
%
% OUTPUT:
%   r_src    - Retained fraction of the source voltage, in (0,1).
%
% COST:
%   One nonlinear simulation per iteration, plus two for the bracket.
%
% SEE ALSO: b7_campaign, b7_point

narginchk(8, 10);
if nargin < 9  || isempty(tol),     tol     = 0.002; end
if nargin < 10 || isempty(maxIter), maxIter = 12;    end

tmpDir = fullfile(tempdir, sprintf('b7_cal_%s', matlab.lang.makeValidName(tag)));
if ~exist(tmpDir, 'dir'), mkdir(tmpDir); end
cleanTmp = onCleanup(@() rmdirQuiet(tmpDir));

probe = @(r) probeRetained(repoRoot, tag, SCR, P, r, dur, Thor, Vpcc, tmpDir);

lo = 0.05;   % deep source event
hi = 0.98;   % barely any event
fprintf('    bracketing...\n');
Vlo = probe(lo);
Vhi = probe(hi);
fprintf('    r_src %.3f -> retained %.4f pu\n', lo, Vlo);
fprintf('    r_src %.3f -> retained %.4f pu\n', hi, Vhi);

if ~(Vlo < Vhi)
    error('b7_calibrate_depth:notMonotonic', ...
          ['Retained PCC voltage is not increasing with the source fraction ' ...
           '(%.4f at %.2f, %.4f at %.2f). Bisection is not valid here.'], ...
          Vlo, lo, Vhi, hi);
end
if V_target < Vlo || V_target > Vhi
    error('b7_calibrate_depth:outOfRange', ...
          ['A retained %.3f pu is outside the reachable range [%.4f, %.4f] at ' ...
           'SCR = %g, P = %g pu.'], V_target, Vlo, Vhi, SCR, P);
end

for it = 1:maxIter
    mid = 0.5*(lo + hi);
    V   = probe(mid);
    err = V - V_target;
    fprintf('    iter %2d: r_src %.5f -> retained %.4f pu (error %+.4f)\n', it, mid, V, err);
    if abs(err) <= tol
        r_src = mid;
        fprintf('    converged within %.4f pu\n', tol);
        return
    end
    if err > 0, hi = mid; else, lo = mid; end
end

r_src = 0.5*(lo + hi);
warning('b7_calibrate_depth:notConverged', ...
        ['Bisection stopped after %d iterations without reaching %.4f pu. ' ...
         'Returning %.5f. Report the achieved retained voltage, not the target.'], ...
        maxIter, tol, r_src);
end

%% ------------------------------------------------------------------------
function V = probeRetained(repoRoot, tag, SCR, P, r_src, dur, Thor, Vpcc, tmpDir)
%PROBERETAINED Retained PCC voltage for one source fraction.
s = b7_point(sprintf('%s_cal', tag), SCR, P, r_src, dur, Thor, tmpDir);
V = s.PCC_ret;
end

function rmdirQuiet(d)
try
    if exist(d, 'dir'), rmdir(d, 's'); end
catch
end
end
