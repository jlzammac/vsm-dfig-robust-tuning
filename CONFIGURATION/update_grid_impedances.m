function MODEL = update_grid_impedances(MODEL)
%UPDATE_GRID_IMPEDANCES  Recalculate grid impedances from SCR
%
% Recalculates Lg_H, Rg_Ohm, Lg_pu, Rg_pu after a change to
% MODEL.GRID.PARAM.SCR_grid.
%
% USAGE:
%   MODEL = update_grid_impedances(MODEL)

Ub  = MODEL.BASE.Ub;
Sb  = MODEL.GRID.BASE.Sb;
f0  = MODEL.BASE.f0;
SCR = MODEL.GRID.PARAM.SCR_grid;
XR  = MODEL.GRID.PARAM.XR_grid;

MODEL.GRID.PARAM.Lg_H   = Ub^2 / Sb / (2*pi*f0) / SCR;
MODEL.GRID.PARAM.Rg_Ohm = MODEL.GRID.PARAM.Lg_H * (2*pi*f0) / XR;
MODEL.GRID.PARAM.Lg_pu  = MODEL.GRID.PARAM.Lg_H  ./ MODEL.BASE.Lb;
MODEL.GRID.PARAM.Rg_pu  = MODEL.GRID.PARAM.Rg_Ohm ./ MODEL.BASE.Zb;

end
