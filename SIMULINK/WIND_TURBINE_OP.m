function [turbinePower,turbineOperPoint] = WIND_TURBINE_OP(pitch,windSpeed,turbineSpeed,turbineData)

% Turbine data
ratedTurbineSpeed = turbineData.ratedTurbineSpeed;
Cp_coeff_matrix = turbineData.Cp_coeff_matrix;
turbineRadius = turbineData.turbineRadius;
airDensity = turbineData.airDensity;
ratedTurbinePower = turbineData.ratedTurbinePower;
% Tip speed ratio
lambda = ratedTurbineSpeed.*turbineSpeed.*turbineRadius./windSpeed;
% Cp computation
Cp = zeros(1,size(lambda,2));
for ii = 0:4
    for jj = 0:4
        Cp = Cp + Cp_coeff_matrix(ii+1,jj+1).*pitch.^ii.*lambda.^jj;
    end
end
Cp = Cp.*(Cp>0);
% Turbine power
turbinePower = 1/2*Cp.*(windSpeed.^3)*airDensity*pi.*turbineRadius.^2./ratedTurbinePower;
% Turbine operating point struct
turbineOperPoint = struct('pitch',pitch);
turbineOperPoint.windSpeed = windSpeed;
turbineOperPoint.windSpeed = turbineSpeed;
turbineOperPoint.lambda = lambda;
turbineOperPoint.Cp = Cp;
turbineOperPoint.turbinePower = turbinePower;

end
