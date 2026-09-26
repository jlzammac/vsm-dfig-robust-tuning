function mirrorRoot = b7_arm_mechanisms(repoRoot, tag, outRoot)
%B7_ARM_MECHANISMS Mirror the repository and arm the protection mechanisms.
%
% DESCRIPTION:
%   Copies the repository to a working mirror and, in that mirror only, sets the
%   three master enables from 0 to 1, so that the converter current limiters,
%   the DC-link chopper and the RSC voltage derate are armed. This is the
%   verification configuration of Section 2.2. The distributed repository is
%   never modified and stays in the design configuration on which the
%   optimisation and every small-signal result of the paper are computed.
%
% WHY A WHOLE MIRROR AND NOT JUST A COPY OF THE MODEL
%   LINEAR_ANALYSIS changes directory to ../SIMULINK and opens the model by
%   name from there. The model path is therefore fixed relative to the
%   repository root, and a copy of the .slx placed anywhere else is simply not
%   the file that gets simulated: the run would silently proceed on the
%   unarmed model while reporting that the mechanisms were armed.
%
%   That failure is not hypothetical. It was observed here: arming a detached
%   copy produced a peak rotor current of 2.12 pu against a 1.074 pu limiter
%   setpoint, because the limiter in the simulated model was off. Mirroring the
%   repository is what the original campaign did, and this is why.
%
%   The enables are literal constants in two MATLAB Function blocks, verified
%   against the model itself:
%
%     POWER_SYSTEM_FULL/CONTROL   LIM_EN     current-reference limiting
%                                 RSCBLK_EN  RSC voltage derate
%     POWER_SYSTEM_FULL/DFIG      CHOP_EN    DC-link chopper
%
%   The DC-link diode clamp has no enable. It applies unconditionally in both
%   configurations, which is why Section 2.2 names four mechanisms but three
%   enables.
%
% INPUTS:
%   repoRoot - Repository root directory.
%   tag      - Run identifier, used to name the mirror.
%   outRoot  - (optional) Parent directory for the mirror. Default tempdir.
%
% OUTPUT:
%   mirrorRoot - Root of the armed mirror. Pass this as the repository root to
%                everything downstream.
%
% SEE ALSO: b7_point, b7_cleanup

narginchk(2, 3);
if nargin < 3 || isempty(outRoot)
    outRoot = tempdir;
end

if exist(fullfile(repoRoot, 'SIMULINK', 'POWER_SYSTEM_FULL.slx'), 'file') ~= 2
    error('b7_arm_mechanisms:noModel', ...
          'Model not found under %s', fullfile(repoRoot, 'SIMULINK'));
end

mirrorRoot = fullfile(outRoot, sprintf('b7_mirror_%s', matlab.lang.makeValidName(tag)));
if exist(mirrorRoot, 'dir'), rmdir(mirrorRoot, 's'); end
mkdir(mirrorRoot);

% Directories the pipeline reads or changes into. RESULTS carries the saved
% designs; TEMP is created by the scripts themselves.
NEEDED = {'ANALYSIS','BUS_DEFINITIONS','CONFIGURATION','CONTROL','FIGURES', ...
          'MODEL','OPTIMIZATION','PLOT_FILES','RESULTS','SCRIPTS', ...
          'SIMULATION','SIMULINK'};
for k = 1:numel(NEEDED)
    src = fullfile(repoRoot, NEEDED{k});
    if exist(src, 'dir')
        copyfile(src, fullfile(mirrorRoot, NEEDED{k}));
    end
end
mkdir(fullfile(mirrorRoot, 'TEMP'));

workModel = fullfile(mirrorRoot, 'SIMULINK', 'POWER_SYSTEM_FULL.slx');

wanted = struct( ...
    'POWER_SYSTEM_FULL_CONTROL', {{'LIM_EN', 'RSCBLK_EN'}}, ...
    'POWER_SYSTEM_FULL_DFIG',    {{'CHOP_EN'}});

bdclose('all');
load_system(workModel);
rt     = sfroot;
charts = rt.find('-isa', 'Stateflow.EMChart');

for k = 1:numel(charts)
    c      = charts(k);
    script = c.Script;
    key    = matlab.lang.makeValidName(c.Path);
    if ~isfield(wanted, key), continue, end
    for v = wanted.(key)
        name = v{1};
        pat  = sprintf('(?m)^(\\s*%s\\s*=\\s*)0(\\s*;)', name);
        if isempty(regexp(script, pat, 'once'))
            if isempty(regexp(script, sprintf('(?m)^\\s*%s\\s*=\\s*1\\s*;', name), 'once'))
                bdclose('all');
                error('b7_arm_mechanisms:enableNotFound', ...
                      ['Could not find "%s = 0;" in block %s. The model does not ' ...
                       'match the configuration this harness expects.'], name, c.Path);
            end
        else
            script = regexprep(script, pat, '$11$2');
        end
    end
    c.Script = script;
end

save_system(workModel);

% Saving a model last saved in an earlier release leaves a *.slx.<release>
% backup beside it. Remove it so the mirror holds one model only.
bak = dir(fullfile(mirrorRoot, 'SIMULINK', 'POWER_SYSTEM_FULL.slx.*'));
for b = 1:numel(bak)
    delete(fullfile(mirrorRoot, 'SIMULINK', bak(b).name));
end

% Confirm on the saved file, not on the in-memory object.
bdclose('all');
load_system(workModel);
rt2       = sfroot;
charts    = rt2.find('-isa', 'Stateflow.EMChart');
confirmed = 0;
for k = 1:numel(charts)
    key = matlab.lang.makeValidName(charts(k).Path);
    if ~isfield(wanted, key), continue, end
    for v = wanted.(key)
        if ~isempty(regexp(charts(k).Script, ...
                sprintf('(?m)^\\s*%s\\s*=\\s*1\\s*;', v{1}), 'once'))
            confirmed = confirmed + 1;
        end
    end
end
bdclose('all');

if confirmed ~= 3
    error('b7_arm_mechanisms:verifyFailed', ...
          'Expected 3 armed enables in the saved mirror, found %d.', confirmed);
end

fprintf('  Verification configuration armed in the mirror (3/3 confirmed)\n');
fprintf('  Mirror: %s\n', mirrorRoot);

end
