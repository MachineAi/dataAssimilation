% function [] = twinExperimentETKF
% twinExperimentETKF.m : Assimilate some real data
% LM,JBB,TB 8/26/13 ASU
% Input: No input
% Output: A whole DA twin experiment


%% Initialisation
clear all
randn('state',100*sum(clock));  % so we don't get fucked by MATLAB's rng.
addpath(genpath('../'));



% sim_no = str2num(getenv('PASS')); % for farmed-out parallel jobs
sim_no = 1;

fprintf('Simulation: %d\n',sim_no)

D = 1;  % number of model variables
z0 = 0; % default initial condition

%% ETKF ensemble size and forecast length

N_ens = 10;   % number of ensemble members
dt_f = 1/12;  % forecast length (years)


%% Inflation and Localization

%%%%% multiplicative and additive inflation factors %%%%%
% dInfMult = str2num(getenv('dInf'))/100  % for farmed-out shit
dInfMult = 1.0;
dInfAdd = 0.0;

%%%%% no localization necessary...
rho = ones(D);

% %% load SIE data
% 
% SIEData = load('../seaIce/data/sea_ice_extent_1979_2009.txt');
% 
% t = load('../seaIce/data/SIE_dates.txt');
% 
% N_obs = D;            % number of observations
% % H = eye(N_obs);       % simple observation operator
% H = -1;               % linearized observation operator
% R = 0.05*eye(N_obs);  % specified ob error covariance matrix
% 
% y = SIEData(:,4)';

%% Make truth and observations (toy twin experiment)

loadDefaultParams;  % load default parameters into struct 'defaultParams'

Tf = 10;  % length of simulation (years)
t = 0:dt_f:Tf;

fprintf('Creating truth\n')
zt(:,1) = z0;
for n = 2:length(t)
   thisForecast = run_sea_ice_params(zt(:,n-1),dt_f,t(n-1), params );
   zt(n) = thisForecast(end,2);
end



N_obs = D;            % number of observations
% H = eye(N_obs);       % simple observation operator
H = -1;       % linearized observation operator
R = 0.1*eye(N_obs);  % specified ob error covariance matrix

% y = H*zt + sqrtm(R)*randn(size(zt(1:N_obs,:)));
y = enthalpyToSIE(zt) + sqrtm(R)*randn(size(zt(1:N_obs,:)));




%% Make initial ensemble with guess at F


% %%%%% real observations version %%%%%
% % zb = SIEToEnthalpy(y(1) + R*randn(D,N_ens));  % perturb observation
% zb = SIEToEnthalpy(y(1)) + 3*randn(D,N_ens);  % perturb observation
% zb0 = zb;                                     % store initial zb


%%%%% toy experiment version %%%%%
zb = zt(:,1)*ones(1,N_ens) + randn(D,N_ens);  % perturb true inital state
zb0 = zb;   

%% ETKF

zf_m = zeros(D,length(t));
za_m = zeros(D,length(t));

za_mean = mean(zb,2);
za_m(:,1) = za_mean;

fprintf('Doin'' the ETKF\n')
tic

% for n_a = 2:length(t)
for n_a = 2:length(t)

  if(~mod(round(n_a/length(t)*100),10))
    tElapsed = toc;
    fprintf('%d%% complete, %ds elapsed\n',...
      round(n_a/length(t)*100),round(tElapsed)); 
  end

  %%%%% Forecast Step %%%%%
  zf = zeros(D,N_ens);
  for k = 1:N_ens
    this_zf = run_sea_ice_params(zb(:,k),dt_f,t(n_a-1),params);
    zf(:,k) = this_zf(end,2);
  end
  
  Pf(n_a) = cov(zf');
  zf_m(:,n_a) = mean(zf,2);
  
  %%%%% adaptive inflation (Wang & Bishop 2003) %%%%%
  dOMB = (y(:,n_a) - enthalpyToSIE(zf_m(:,n_a)));
  dInfMult = max((dOMB'*dOMB - trace(R))/trace(H*Pf(n_a)*H'),1);
  adInf(n_a) = dInfMult;
  
%   %%%%% give obs same weight as forecast %%%%%
%   dInfMult = trace(R)/trace(H*Pf(n_a)*H');
%   adInf(n_a) = max(dInfMult,1);

  
  [za,Pa(n_a)] = ...
    ETKF_onestep_obsOperator(zf,y(:,n_a),...
    @enthalpyToSIE,H,R,dInfMult,dInfAdd,rho);
  
  za_m(:,n_a) = mean(za,2);
  
  zb = za;
  
end
toc



% startPointRMSE = round(size(za_m,2)*0.2);
% fprintf('RMSE: %.2f\n',RMSE(za_m(:,startPointRMSE:end) - zt_o(1:I,startPointRMSE:end)));

%   save(['long/N',num2str(N_ens),'_l',num2str(locLength),'_d',num2str(dInfMult),'_',num2str(sim_no),'.mat'])


%% Pretty pictures
figure(1)
clf(1)
% plot(t,zt(1,:),t(2:end),za_m(1:end-1),t,y,'x')
% plot(t,zt(1,:),t,za_m,t,y,'x')
plot(t,zt(1,:),t,za_m,t,SIEToEnthalpy(y),'x',t(2:end),zf_m(2:end))
xlabel('Time (years)')
ylabel('Energy')

