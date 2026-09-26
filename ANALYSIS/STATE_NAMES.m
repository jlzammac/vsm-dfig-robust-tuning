function LIN_MODEL = STATE_NAMES(LIN_MODEL)

%--------------------------------------------------------------
% STATE NAMES
%--------------------------------------------------------------
% CORRECTED BLOCK ORDER (fixed 2026-08-27)
%--------------------------------------------------------------
% The label vector must follow the state ordering that Simulink's
% linearisation actually produces, which is:
%
%     DFIG_INT    ( 1 .. 10*nDFIG )   <-- 10 states per machine
%     CONTROL_INT ( 10*nDFIG+1 .. 18*nDFIG )  <--  8 states per machine
%     GRID_INT    ( 18*nDFIG+1 .. 18*nDFIG+8 )
%
% For nDFIG = 4 that is: DFIG 1-40, CONTROL 41-72, GRID/LINE 73-80.
%
% NOTE: the GRID_INT block carries BOTH the 4 grid states and the 4 line
% states (see MF_003_LINE_GRID.m, where STATE_DERIVATIVE is
% [dxsg ; dxt1 ; dxt2 ; dw ; real(di) ; imag(di) ; real(dv1) ; imag(dv1)]),
% hence stateNamesGRID followed by stateNamesLINE below.
%
% BUG HISTORY: until 2026-08-27 this function emitted the CONTROL loop
% BEFORE the DFIG loop, so every label was displaced -- indices 1..32 were
% labelled with CONTROL names when they are in fact DFIG states, and
% indices 33..72 were labelled with DFIG names when 41..72 are CONTROL
% states. The GRID/LINE block happened to land correctly because both
% blocks together are 18*nDFIG states long either way.
%
% VERIFICATION (2026-08-27), against RESULTS/CONTROL/LIN_MODEL_FRD_OPT.mat
% and RESULTS/CONTROL/LIN_MODEL_VI_OPT.mat (both 80 states, ssModel.StateName
% fully populated):
%   1) ssModel.StateName reads DFIG_INT(1..40), CONTROL_INT(1..32),
%      GRID_INT(1..8) in that order.
%   2) C-matrix unit-row check: output 'f' (grid frequency) is a unit row on
%      state 76 = GRID_INT(4). GRID FREQUENCY is the 4th entry of the GRID
%      block, which starts at 73 -- consistent.
%   3) C-matrix unit-row check: outputs dfigAuxSignals(i,4) (= Vdc, since
%      outSignals = [|Vs|, P_dfig, Q_dfig, Vdc] in MF_002_DFIG.m) are unit
%      rows on states 6, 16, 26, 36. DC VOLTAGE is the 6th entry of the DFIG
%      block, so machine i sits at (i-1)*10+6 -- confirms the 10-state
%      per-machine DFIG layout AND that the DFIG block starts at index 1.
%
% WARNING: this block order is decided by Simulink's linearisation, not by
% this file. If the subsystem structure of the model changes (blocks added,
% removed, reordered, or resolved into a different compile order), the order
% above MUST be re-verified by reading ssModel.StateName from a freshly
% linearised model before trusting any label produced here.
%--------------------------------------------------------------
nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
stateNamesCONTROL = {
'VSMP FREQ'
'VSMP ANGLE'
'STATOR FLUX REF'
'RSCd INT'
'RSCq INT'
'VDC2 INT'
'GSCd INT'
'GSCq INT'
};
stateNamesDFIG = { 
'STATOR-TRAFO FLUX REAL'
'STATOR-TRAFO FLUX IMAG'
'ROTOR FLUX REAL'
'ROTOR FLUX IMAG'
'ROTOR SPEED'
'DC VOLTAGE'
'GSC-TRAFO FLUX REAL'
'GSC-TRAFO FLUX IMAG'
'TURBINE SPEED'
'SHAFT TORQUE'
};
stateNamesGRID = {
'SPEED GOVERNOR STATE'
'TURBINE STATE 1'
'TURBINE STATE 2'
'GRID FREQUENCY'    
};
stateNamesLINE = {
'LINE CURRENT REAL'
'LINE CURRENT IMAG'
'NODE 1 VOLTAGE REAL'
'NODE 1 VOLTAGE IMAG'
};
stateNames = [];
% DFIG block first: states 1 .. 10*nDFIG
for ii = 1:nDFIG
    aux = cell(length(stateNamesDFIG),1);
    for jj = 1:length(stateNamesDFIG)
        aux{jj} = [stateNamesDFIG{jj} ' DFIG ' num2str(ii)];
    end
    stateNames = [stateNames ; aux];
end
% CONTROL block second: states 10*nDFIG+1 .. 18*nDFIG
for ii = 1:nDFIG
    aux = cell(length(stateNamesCONTROL),1);
    for jj = 1:length(stateNamesCONTROL)
        aux{jj} = [stateNamesCONTROL{jj} ' DFIG ' num2str(ii)];
    end
    stateNames = [stateNames ; aux];
end
stateNames = [stateNames ; stateNamesGRID];
if strcmp(LIN_MODEL.modelName(end-3:end),'FULL')
    stateNames = [stateNames ; stateNamesLINE];
end

LIN_MODEL.stateNames = stateNames;
