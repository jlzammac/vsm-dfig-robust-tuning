function b7_cleanup(mirrorRoot)
%B7_CLEANUP Close and remove the working copy left by b7_arm_mechanisms.
%
% DESCRIPTION:
%   Closes the armed model and deletes its working directory. Called through
%   ONCLEANUP by b7_point, so it runs whether the point completes or fails.
%
%   Removing the working copy is not housekeeping. The copy carries the three
%   protection mechanisms armed, and Section 2.2 is explicit that results from
%   the armed configuration are not interchangeable with anything else in the
%   paper. Leaving armed copies on disk invites exactly the mistake that
%   distinction exists to prevent.
%
%   The function never throws: it is a cleanup handler, and an error raised
%   here would mask the error that triggered the cleanup.
%
% INPUT:
%   workModel - Full path to the working copy.
%
% SEE ALSO: b7_point, b7_arm_mechanisms

if nargin < 1 || isempty(mirrorRoot) || (~ischar(mirrorRoot) && ~isstring(mirrorRoot))
    return
end
mirrorRoot = char(mirrorRoot);

try
    bdclose('all');

    % Only remove directories this harness created. A path without the
    % b7_mirror_ prefix is not ours and is left alone.
    [~, leaf] = fileparts(mirrorRoot);
    if startsWith(leaf, 'b7_mirror_') && exist(mirrorRoot, 'dir')
        rmdir(mirrorRoot, 's');
    end
catch
    % Deliberately silent. See the note above.
end

end

function tf = bdIsLoaded(name)
tf = false;
try
    tf = any(strcmp(find_system('SearchDepth', 0), name));
catch
end
end
