clear;clc;

%% 中心天体参数
mu = 3.986004418e14;% m^3/s^2
Re = 6378137;       % m
J2 = 1.08262668e-3; % 
omegaE = 7.2921159e-5; % rad/s
h_ref = 400e3;      % m
rho_ref = 3e-12;    % kg/m^3
H = 50e3;           % m

%% 环境与轨道动力学子系统
% 大气阻力
Cd = 2.2;           % 
area_d = 4;         % m^2
m = 500;            % kg
% 初始位置和速度
x0 = 7e6;           % m
y0 = 0;             % m
z0 = 0;             % m
vx0 = 0;            % m/s
vy0 = 7546;       % m/s
vz0 = 0;            % m/s
% 太阳光压参数
P0 = 4.56e-6;       % N/m^2
Cr = 1.2;           % 1~1.8
area_s = 2;         % m^2
hat_s = [1,0,0];    % 惯性系

%% 电源子系统
% 外部环境
sunlit = 0;         % 日照标志,0/1
P_panel = 150;      % W
% 负载功耗
P_base = 50;        % W
P_adcs = 20;        % W
P_comm = 40;        % W
E_max = 7.2e5;      % J，约200Wh
E0 = 5.76e5;        % J，80%初始电量
SOC_low_comm = 0.2; % 低于 20% 关通信
SOC_low_adcs = 0.1; % 低于 10% 关姿态

% 蓄电池参数