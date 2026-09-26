function S = SEED_STUDY_SUMMARY()
%SEED_STUDY_SUMMARY  Section 5.7 numbers from the five seed runs.
%
%   S = SEED_STUDY_SUMMARY()
%
%   Reads RESULTS/SEED_STUDY/seed<k>_final_front.mat, the Pareto front
%   returned by the last GA run (Phase 5) of each of the five complete
%   workflows run with different random-number seeds, 20 individuals x 10
%   generations per GA run. Every front is degenerate (all members share
%   the same objective values and the same 20 effective parameters), so
%   the first member represents it.
%
%   Prints J1 and J2 per seed, their spread, and how many of the 20
%   effective design parameters differ between each pair of seeds. Slot 21
%   of the parameter vector is the virtual resistance, which is fixed at
%   zero and not a design variable, so it is excluded from the count.
%
%   Re-running the five workflows themselves takes 35 GA runs (about 3 h per
%   seed); see REPRODUCE/sec057_seed_sensitivity.md.

R = fileparts(fileparts(mfilename('fullpath')));
J = zeros(5, 2); P = zeros(5, 20);
for k = 1:5
    g = load(fullfile(R, 'RESULTS', 'SEED_STUDY', sprintf('seed%d_final_front.mat', k)));
    J(k, :) = g.GAM.fval_opt(1, :);
    P(k, :) = g.GAM.param_opt(1, 1:20);
end
D = zeros(5);
for a = 1:5, for b = 1:5, D(a, b) = sum(P(a, :) ~= P(b, :)); end, end
off = D(triu(true(5), 1));

fprintf('\nSeed   J1       J2\n');
for k = 1:5, fprintf('%d      %.4f   %.4f\n', k, J(k, 1), J(k, 2)); end
fprintf('\nSpread (range / smallest): J1 %.1f %%, J2 %.1f %%\n', ...
    100*range(J(:, 1))/min(J(:, 1)), 100*range(J(:, 2))/min(J(:, 2)));
fprintf('Between any two seeds, %d to %d of the 20 design parameters differ.\n', min(off), max(off));
S = struct('J', J, 'params', P, 'nDiffer', D);
end
