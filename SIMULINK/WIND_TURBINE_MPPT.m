function turbineMPPT = WIND_TURBINE_MPPT(pitch,turbineData)

% Turbine data
ratedTurbineSpeed = turbineData.ratedTurbineSpeed;
ratedWindSpeed = turbineData.ratedWindSpeed;
Cp_coeff_matrix = turbineData.Cp_coeff_matrix;
turbineRadius = turbineData.turbineRadius;
airDensity = turbineData.airDensity;
ratedTurbinePower = turbineData.ratedTurbinePower;
% Number of points
N1 = 100;
N2 = 25;
% Turbine speed [rad/s]
turbineSpeedValues = linspace(0.5*ratedTurbineSpeed,ratedTurbineSpeed*1.3,N1);
% WindSpeedValues [m/s]
windSpeedValues = linspace(0.6*ratedWindSpeed,ratedWindSpeed*1.3,N2);
% Mechanical power computation
Cp_aux = zeros(N1,N2);
lambdaValues = turbineSpeedValues(:)*turbineRadius*(1./windSpeedValues);
for ii = 0:4
    for jj = 0:4
        Cp_aux = Cp_aux + Cp_coeff_matrix(ii+1,jj+1)*pitch^ii*(lambdaValues.^jj);
    end
end
% Turbine power = 1/2*Cp(lambda,pitch)*ro*pi*R^2*windSpeed^3
turbinePowerValues = 1/2*Cp_aux*diag(windSpeedValues.^3)*airDensity*pi*turbineRadius^2/ratedTurbinePower;
turbinePowerValues = turbinePowerValues.*(turbinePowerValues>0);
% Maximum turbine power [pu]
[mpptTurbinePower,ind] = max(turbinePowerValues);
% Minimum turbine speed [pu]
mpptTurbineSpeed = turbineSpeedValues(ind)/ratedTurbineSpeed;
% MPPT windSpeed [m/s]
mpptWindSpeed = windSpeedValues;
% lambda
mpptLambda = mpptTurbineSpeed*ratedTurbineSpeed*turbineRadius.*(1./mpptWindSpeed);
% Cp maximum value
maxCp = NaN(1,size(Cp_aux,2));
for nn = 1:size(Cp_aux,2)
    maxCp(nn) = Cp_aux(ind(nn),nn);
end
% Turbine mppt struct
turbineMPPT = struct('pitch',pitch);
turbineMPPT.turbinePower = mpptTurbinePower;
turbineMPPT.turbineSpeed = mpptTurbineSpeed;
turbineMPPT.windSpeed = mpptWindSpeed;
turbineMPPT.lambda = mpptLambda;
turbineMPPT.Cp = maxCp;

end
