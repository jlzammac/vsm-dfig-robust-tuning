function names = b7_enable_per_machine_logging(mirrorRoot)
%B7_ENABLE_PER_MACHINE_LOGGING Log the DFIG bus so per-machine traces exist.
%
% DESCRIPTION:
%   Turns on Simulink signal logging for the output ports of the DFIG subsystem
%   in the armed mirror, so that quantities carried per machine can be read back
%   after a run.
%
% WHY THIS IS NEEDED
%   Figure 14 plots the terminal voltage of all four machines. The scope block
%   that produces SCOPE_SIM does not carry them: every one of its fifteen
%   signal groups has a unit dimension of 1, verified on a completed run. The
%   published figure therefore cannot have been drawn from this logging
%   configuration, and the campaign that produced it must have added logging of
%   its own. This function adds it back.
%
%   The change is made in the mirror only. The distributed model keeps the
%   logging configuration it was published with.
%
% INPUT:
%   mirrorRoot - Root of the armed mirror from b7_arm_mechanisms.
%
% OUTPUT:
%   names - Cell array of the log names assigned, in port order.
%
% SEE ALSO: b7_arm_mechanisms, b7_point

narginchk(1, 1);

mdlFile = fullfile(mirrorRoot, 'SIMULINK', 'POWER_SYSTEM_FULL.slx');
if exist(mdlFile, 'file') ~= 2
    error('b7_enable_per_machine_logging:noModel', 'Model not found: %s', mdlFile);
end

bdclose('all');
load_system(mdlFile);
m = 'POWER_SYSTEM_FULL';

set_param(m, 'SignalLogging', 'on', 'SignalLoggingName', 'b7_logs');

ph    = get_param([m '/DFIG'], 'PortHandles');
names = cell(1, numel(ph.Outport));
for k = 1:numel(ph.Outport)
    ln = get_param(ph.Outport(k), 'Line');
    if ln == -1
        names{k} = '';
        continue
    end
    % Logging is a PORT property, not a line property. The line carries only
    % the signal name; DataLogging and its companions live on the output port.
    nm = sprintf('b7_dfig_out%d', k);
    set_param(ln, 'Name', nm);
    set_param(ph.Outport(k), 'DataLogging', 'on');
    set_param(ph.Outport(k), 'DataLoggingNameMode', 'Custom');
    set_param(ph.Outport(k), 'DataLoggingName', nm);
    names{k} = nm;
end

save_system(mdlFile);

bak = dir(fullfile(mirrorRoot, 'SIMULINK', 'POWER_SYSTEM_FULL.slx.*'));
for b = 1:numel(bak)
    delete(fullfile(mirrorRoot, 'SIMULINK', bak(b).name));
end
bdclose('all');

nOn = nnz(~cellfun(@isempty, names));
fprintf('  Per-machine logging enabled on %d DFIG output ports\n', nOn);

end
