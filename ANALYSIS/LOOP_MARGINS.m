function [Fm, wo, diag] = LOOP_MARGINS(LIN_MODEL, loops)
%LOOP_MARGINS  Phase margin and gain crossover of each loop, from the current
%   linearisation, without redesigning anything.
%
%   [Fm, wo] = LOOP_MARGINS(LIN_MODEL)
%   [Fm, wo] = LOOP_MARGINS(LIN_MODEL, loops)
%
%   The same computation as the margin block of the local function
%   update_structs in CONTROL/CONTROL_DESIGN_FR.m, taken out so that it can
%   evaluate a FIXED design at any operating point. CONTROL_DESIGN_FR only
%   computes margins while it designs, and LINEAR_ANALYSIS never computes
%   them, so the frdMargins stored in a design file are the ones left by its
%   last design pass. See REPRODUCE/tab06_achieved_margins.md.
%
%   Loop order: 1 VSMP | 2 VSMQ | 3 RSCd | 4 RSCq | 5 VDC | 6 GSCd | 7 GSCq
%
%   Fm(ii) = NaN means the gain-crossover fsolve did not converge or returned a
%   negative frequency. That is a solver failure, never an infinite margin.
%
%   loops (optional) selects which loops to solve; the others are NaN. Each
%   loop is solved independently, so a subset gives identical values.

    nCONTROL = 7;
    if nargin < 2 || isempty(loops), loops = 1:nCONTROL; end
    loops = loops(:).';
    nDFIG = LIN_MODEL.MODEL.DFIG.PARAM.nDFIG;
    sd    = LIN_MODEL.CONTROL_DESIGN.selectedDFIG;
    s     = tf('s');

    % --- controller transfer functions from the CURRENT parameters ----------
    % CONTROL_DESIGN_FR.m:634-667
    H  = LIN_MODEL.CONTROL.VSMP.PARAM.H(sd);
    Dp = LIN_MODEL.CONTROL.VSMP.PARAM.Dp(sd);
    Dd = LIN_MODEL.CONTROL.VSMP.PARAM.Dd(sd);
    Css = cell(1,nCONTROL);
    Css{1} = ss((1 + Dd*s)/(1 + 2*H/Dp*s));
    Css{2} = LIN_MODEL.CONTROL.VSMQ.PARAM.K_Fs_ref(sd);
    Css{3} = ss(LIN_MODEL.CONTROL.RSCd.PARAM.Kp(sd) + LIN_MODEL.CONTROL.RSCd.PARAM.Ki(sd)/s);
    Css{4} = ss(LIN_MODEL.CONTROL.RSCq.PARAM.Kp(sd) + LIN_MODEL.CONTROL.RSCq.PARAM.Ki(sd)/s);
    Css{5} = ss(LIN_MODEL.CONTROL.VDC.PARAM.Kp(sd)  + LIN_MODEL.CONTROL.VDC.PARAM.Ki(sd)/s);
    Css{6} = ss(LIN_MODEL.CONTROL.GSCd.PARAM.Kp(sd) + LIN_MODEL.CONTROL.GSCd.PARAM.Ki(sd)/s);
    Css{7} = ss(LIN_MODEL.CONTROL.GSCq.PARAM.Kp(sd) + LIN_MODEL.CONTROL.GSCq.PARAM.Ki(sd)/s);

    matA = LIN_MODEL.ssModel.a; matB = LIN_MODEL.ssModel.b;
    matC = LIN_MODEL.ssModel.c; matD = LIN_MODEL.ssModel.d;

    opt_fsolve = optimoptions('fsolve');
    opt_fsolve.MaxIterations = 5000;
    opt_fsolve.Display = 'off';

    CD = LIN_MODEL.CONTROL_DESIGN;
    w_ini = [CD.VSMP.frdSpecs.wo, CD.VSMQ.frdSpecs.wo, CD.RSC.frdSpecs.wo, ...
             CD.VDC.frdSpecs.wo,  CD.GSC.frdSpecs.wo];

    Fm = NaN(1,nCONTROL); wo = NaN(1,nCONTROL);
    diag = struct('exitflag', NaN(1,nCONTROL));

    for ii = loops
        indT = nCONTROL*(sd-1)+ii;
        indS = nCONTROL*nDFIG + nCONTROL*(sd-1)+ii;
        Tss = ss(matA,matB(:,indT),matC(indT,:),matD(indT,indT));
        Sss = ss(matA,matB(:,indT),matC(indS,:),matD(indS,indT));
        Gss = -Tss/Sss;
        try
            [woi,~,ef] = fsolve(@(w) abs(freqresp(Gss,w))-1, w_ini(ii), opt_fsolve);
            diag.exitflag(ii) = ef;
            if ef < 1 || woi < 0
                wo(ii) = NaN; Fm(ii) = NaN;              % solver failure
            else
                wo(ii) = woi;
                Fm(ii) = 180 + 180/pi*angle(freqresp(Gss,woi));
            end
        catch
            wo(ii) = NaN; Fm(ii) = NaN; diag.exitflag(ii) = -99;
        end
    end
end
