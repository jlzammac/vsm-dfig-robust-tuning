function PLOT_SCOPE_SIM(SCOPE_SIM)
%--------------------------------------------------------------
% PLOT_SCOPE_SIM — NL Simulation Signal Visualizer
%--------------------------------------------------------------
% PURPOSE:
%   Plots any combination of the 45 internal signals logged by the
%   Monitoring scope block during a Simulink nonlinear simulation.
%   Edit the 'signals' matrix below to select which scopes/signals
%   to display. All system variables are accessible — no signal is
%   ever inaccessible via this function.
%
% USAGE:
%   results = RUN_PERTURBATION_SIM(LIN_MODEL, pertType, pertConfig);
%   PLOT_SCOPE_SIM(results.SCOPE_SIM)
%
%   % Direct access to any signal:
%   freq = results.SCOPE_SIM.signals(11).values(1,:);  % Grid frequency
%   vpcc = results.SCOPE_SIM.signals(6).values(3,:);   % PCC voltage
%   time = results.SCOPE_SIM.time;
%
% SIGNAL MAP (scope_index, signal_index → variable):
%   [1,1] DFIG P_REF    [1,2] DFIG P        [1,3] DFIG P_MECH
%   [2,1] GRID P_REF    [2,2] GRID P        [2,3] GRID P_MECH   [2,4] LOAD P
%   [3,1] VDC_REF       [3,2] VDC           [3,3] P_GSC         [3,4] P_RSC    [3,5] P_DC
%   [4,1] Q_STATOR      [4,2] Q_ROTOR       [4,3] Q_GSC_REF     [4,4] Q_GSC
%   [5,1] DFIG Q_REF    [5,2] DFIG Q        [5,3] GRID Q        [5,4] LOAD Q
%   [6,1] V_STATOR_REF  [6,2] V_STATOR      [6,3] V_PCC         [6,4] V_GRID
%   [7,1] RSC_ID_REF    [7,2] RSC_IQ_REF    [7,3] RSC_ID        [7,4] RSC_IQ
%   [8,1] GSC_ID_REF    [8,2] GSC_IQ_REF    [8,3] GSC_ID        [8,4] GSC_IQ
%   [9,1] RSC_VD        [9,2] RSC_VQ        [9,3] GSC_VD        [9,4] GSC_VQ
%   [10,1] FLUX_S_REF   [10,2] FLUX_STATOR  [10,3] FLUX_ROTOR
%   [11,1] GRID_FREQ    [11,2] VSMP_FREQ                        ← KEY: frequency
%   [12,1] ANG_PCC      [12,2] ANG_TRAFO    [12,3] ANG_FS       [12,4] ANG_VSMQ  [12,5] ANG_GRID
%   [13,1] SPEED_ROTOR  [13,2] SPEED_TURBINE
%   [14,1] WIND_SPEED
%   [15,1] PITCH_ANGLE
%
% KEY SIGNALS FOR PAPER FIGURES:
%   Frequency:     [11,1] Grid_freq,  [11,2] VSMP_freq
%   Voltage:       [6,2]  V_stator,   [6,3]  V_PCC
%   Active power:  [1,1]  P_ref,      [1,2]  P_DFIG,   [2,2] P_grid
%   Reactive power:[5,1]  Q_ref,      [5,2]  Q_DFIG
%   DC voltage:    [3,1]  VDC_ref,    [3,2]  VDC
%
% OUTPUT:
%   Figures auto-exported to FIGURES/PLOT_SCOPE_SIM/ as .fig + .pdf
%   (IEEE vector quality, white background, 300 dpi)
%--------------------------------------------------------------
% FLAG FOR SAVING FILE .mat
%--------------------------------------------------------------
SAVE_DATA_FLAG = false;
FILE_NAME = 'sim_step_Pref_DFIG1';
COMMENT = '';
%--------------------------------------------------------------
% FLAG FOR SELECTING TIME INTERVAL
%--------------------------------------------------------------
SELECT_TIME_FLAG = false;

%--------------------------------------------------------------
%% SCOPE DATA DEFINITION
%--------------------------------------------------------------
SCOPE_DATA = SCOPE_SIM;
% Signals and values to be plotted
N = length(SCOPE_DATA.signals);
%--------------------------------------------------------------
% SIGNALS IN SCOPE_PC (structure with time)
%--------------------------------------------------------------
signals = [
1 1 % DFIG P REF (pu)
1 2 % DFIG P (pu)
1 3 % DFIG P MECH (pu)
2 1 % GRID P REF (pu/DFIG)
2 2 % GRID P (pu/DFIG)
2 3 % GRID P MECH (pu/DFIG)
2 4 % LOAD P (pu/DFIG)
3 1 % DC V REF (pu)
3 2 % DC V (pu)
3 3 % GSC P (pu)
3 4 % RSC P (pu)
3 5 % DC P (pu)
4 1 % STATOR Q(pu)
4 2 % ROTOR Q (pu)
4 3 % GSC Q REF (pu)
4 4 % GSC Q (pu)
5 1 % DFIG Q REF (pu)
5 2 % DFIG Q (pu)
5 3 % GRID Q (pu/DFIG)
5 4 % LOAD Q (pu/DFIG)
6 1 % STATOR V REF (pu)
6 2 % STATOR V (pu)
6 3 % PCC V (pu)
6 4 % GRID V (pu)
7 1 % RSC ID REF (pu)
7 2 % RSC IQ REF (pu)
7 3 % RSC ID (pu)
7 4 % RSC IQ (pu)
8 1 % GSC ID REF (pu)
8 2 % GSC IQ REF (pu)
8 3 % GSC ID (pu)
8 4 % GSC IQ (pu)
9 1 % RSC VD (pu)
9 2 % RSC VQ (pu)
9 3 % GSC VD (pu)
9 4 % GSC VQ (pu)
10 1 % STATOR FLUX REF (pu)
10 2 % STATOR FLUX (pu)
10 3 % ROTOR FLUX (pu)
11 1 % GRID FREQ (pu)
11 2 % VSMP FREQ (pu)
12 1 % PCC ANGLE (deg)
12 2 % TRAFO ANGLE (deg)
12 3 % STATOR FLUX ANGLE (deg)
12 4 % VSMQ FLUX ANGLE (deg)
12 5 % GRID ANGLE (deg)
13 1 % ROTOR SPEED (pu)
13 2 % TURBINE SPEED (pu)
14 1 % WIND SPEED (m/s)
15 1 % TURBINE PITCH (deg)
];

LEGEND = { ...
{'DFIG REF','DFIG','MECH'}
{'GRID REF','GRID','MECH','LOAD'}
{'VDC REF','VDC','PGSC','PRSC','PDC'}
{'STATOR','ROTOR','GSC REF','GSC'}
{'DFIG REF','DFIG','GRID','LOAD'}
{'DFIG REF','DFIG','PCC','GRID'}
{'D-AXIS REF','Q-AXIS REF','D-AXIS','Q-AXIS'}
{'D-AXIS REF','Q-AXIS REF','D-AXIS','Q-AXIS'}
{'RSC D-AXIS','RSC Q-AXIS','GSC D-AXIS','GSC Q-AXIS'}
{'STATOR REF','STATOR','ROTOR'}
{'GRID','VSMP'}
{'PCC','TRAFO','FS','FS VSMQ','GRID'}
{'ROTOR','TURBINE'}
{}
{}
};

%--------------------------------------------------------------
% SELECT TIME INTERVAL
%--------------------------------------------------------------
% Close all the figures
% close('all')
if SELECT_TIME_FLAG
    % Select time interval in samples
    plot(SCOPE_DATA.signals(13).values(1,:))
    xlabel('Samples')
    ylabel('pu')
    title('ROTOR SPEED')
    grid
    disp('ZOOM TO SELECT THE DATA INTERVAL')
    disp('FINALLY, HIT ANY KEY')
    pause
    k = round(ginput(2));
    k = k(:,1);
else
    k = [1 ; length(SCOPE_DATA.time)];
end

%--------------------------------------------------------------
% PLOT SIGNALS
%--------------------------------------------------------------
% Select signals
signal_sel = unique(signals(:,1));
Nfig = length(signal_sel);
% Subplot distribution
if Nfig<=3
    sp1 = Nfig;
    sp2 = 1;
elseif Nfig<=6
    sp1 = round((Nfig+0.5)/2);
    sp2 = 2;
elseif Nfig<=9
    sp1 = 3;
    sp2 = 3;
else
    sp1 = 4;
    sp2 = 4;
end
% New structure with time
SCOPE_DATA.time = double(SCOPE_DATA.time(k(1):k(2))-SCOPE_DATA.time(k(1)));
for nn=1:N
    SCOPE_DATA.signals(nn).values = double(SCOPE_DATA.signals(nn).values(:,k(1):k(2)));    
end
figure('units','normalized','outerposition',[0 0 1 1])
sizeTitle = 8;
sizeLabel = 8;
sizeAxis = 8;
axis_sp = zeros(N,1);
for ii = 1:Nfig
    nn = signal_sel(ii);
    % Select values for each signal
    value_sel = signals((signals(:,1)==nn),2)';
    SCOPE_DATA.signals(nn).values = double(SCOPE_DATA.signals(nn).values(value_sel,:));
    subplot(sp1,sp2,ii)
    plot(SCOPE_DATA.time,SCOPE_DATA.signals(nn).values,'LineWidth',2);
    grid
    SCOPE_DATA.signals(nn).label = {'Time (s)',char(SCOPE_DATA.signals(nn).title)};
    xlabel(SCOPE_DATA.signals(nn).label(1),'fontsize',sizeLabel,'fontweight','b')
    ylabel(SCOPE_DATA.signals(nn).label(2),'fontsize',sizeLabel,'fontweight','b')
    SCOPE_DATA.signals(nn).legend = LEGEND{nn};
    title(SCOPE_DATA.signals(nn).title,'fontsize',sizeTitle,'fontweight','b')
    try legend(SCOPE_DATA.signals(nn).legend(value_sel),'Location','best'), catch, end
    set(gca,'fontsize',sizeAxis,'fontweight','b')
    xlim([0 SCOPE_DATA.time(end)])
    axis_sp(nn)=gca;    
end
linkaxes(axis_sp,'x')
subplot

%--------------------------------------------------------------
% SAVE FILE .mat
%--------------------------------------------------------------
if SAVE_DATA_FLAG
    command = ['save ' FILE_NAME ' COMMENT SCOPE_DATA'];
    eval(command)
end
clear command COMMENT FILE_NAME

%--------------------------------------------------------------
% AUTOMATIC FIGURE EXPORT - IEEE QUALITY (.fig + .pdf)
%--------------------------------------------------------------

% Get all open figures
all_figs = findall(0, 'Type', 'figure');

if ~isempty(all_figs)
    % Create export directory
    project_root = pwd;
    figure_export_dir = fullfile(project_root, 'FIGURES', 'PLOT_SCOPE_SIM');

    % Create directory if it doesn't exist
    if ~exist(figure_export_dir, 'dir')
        mkdir(figure_export_dir);
        fprintf('Created figure export directory: %s\n', figure_export_dir);
    end

    % Save each figure in dual format (.fig + .pdf)
    for i = 1:length(all_figs)
        fig_handle = all_figs(i);

        % Generate filename based on FILE_NAME or figure title
        if exist('FILE_NAME', 'var') && ~isempty(FILE_NAME)
            filename_base = FILE_NAME;
        else
            % Use figure title or generic name
            fig_title = get(get(fig_handle, 'CurrentAxes'), 'Title');
            if ~isempty(fig_title) && ~isempty(get(fig_title, 'String'))
                title_str = get(fig_title, 'String');
                % Clean title string for filename
                filename_base = regexprep(title_str, '[^a-zA-Z0-9_]', '_');
            else
                filename_base = sprintf('SimScope_Fig%d', fig_handle.Number);
            end
        end

        % Save in dual format: .fig (editable) + .pdf (IEEE publication)
        fig_path = fullfile(figure_export_dir, [filename_base, '.fig']);
        pdf_path = fullfile(figure_export_dir, [filename_base, '.pdf']);

        % Save .fig format
        savefig(fig_handle, fig_path);

        % Save .pdf format (IEEE quality - vector graphics)
        if exist('exportgraphics', 'file')
            exportgraphics(fig_handle, pdf_path, ...
                'ContentType', 'vector', ...
                'Resolution', 300, ...
                'BackgroundColor', 'white');
        else
            print(fig_handle, pdf_path, '-dpdf', '-r300', '-painters', '-fillpage');
        end

        fprintf('  Saved: %s (.fig + .pdf)\n', filename_base);
    end

    fprintf('Total figures saved: %d × 2 formats (publication-ready .fig + .pdf)\n', length(all_figs));
end

return
