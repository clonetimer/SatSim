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
hat_s = [1;0;0];    % 惯性系

%% 电源子系统
% 外部环境
sunlit = 1;         % 日照标志,0/1
P_panel = 1000;      % 发电功率，W
% 通信功耗
P_comm = 40;        % 通信功耗，W
sta_lat = 0;        % 地面站纬度
sta_lon = 0;        % 地面站经度
sta_vec = Re * [
    cos(sta_lat)*cos(sta_lon);
    cos(sta_lat)*sin(sta_lon);
    sin(sta_lat)
];                  % 地面站位置向量
gamma_max = 60*pi/180;% 最大可见角，rad/s
cos_g_max = cos(gamma_max);
% 太阳板系数
n_solar = [1;0;0];  % 太阳板机体系法向量，X轴向
V_bus_ref = 28;     % 参考母线电压，V
C_bus = 0.02;       % 母线等效电容，F
I_sc = 18;          % 面板短路电流，A
V_oc = 40;          % 面板开路电压，V
G0 = 1361;          % 太阳光照常数，W/m^2
eta_mppt = 0.95;    % 最大功率点跟踪效率
% 负载功耗
P_base = 50;        % 基础功耗，W
P_adcs = 20;        % 姿态确认与控制功耗，W

E_max = 7.2e5;      % J，约200Wh
SOC0 = 0.6;         % 80%初始电量
E0 = E_max * SOC0;  % J，
SOC_low_comm = 0.2; % 低于 20% 关通信功耗
SOC_low_adcs = 0.1; % 低于 10% 关姿态功耗
% 充放电参数
P_trickle = 14/V_bus_ref;     % 涓流充电电流，A
P_cc = 220/V_bus_ref;         % 稳流充电电流，A
SOC1 = 0.2;         % 涓流|稳流
SOC2 = 0.8;         % 稳流|稳压
% 蓄电池参数
P_dis_lim = -200;   % 放电限流，W
I_chg_max = 8;      % 充电电流限幅，A
I_dis_max = 10;     % 放电电流限幅，A
eta_chg = 0.95;     % 充电效率
eta_dis = 0.95;     % 放电效率
Q = 20;             % 最大电量，Ah
V_max = 33;         % 最大电压，V
V_min = 24;         % 最小电压，V
Rb = 0.2;           % 蓄电池内阻，ohm
%% 姿态确定与控制子系统
% 航天器物理属性
Jx = 10;            % kg*m^2, 航天器框架转动惯量——X轴向
Jy = 12;            % kg*m^2, 航天器框架转动惯量——Y轴向
Jz = 8;             % kg*m^2, 航天器框架转动惯量——Z轴向
% 航天器状态属性
w0 = [0;0;0];       % 初始角速度
Q0 = [0.6;0.8;0;0]; % 初始四元数
quat = quaternion(Q0');
eAR = euler(quat, 'ZYX', 'frame');% eulerAnglesRad
angle0 = eAR';   % 初始角度
% 姿态控制器属性
Kp = [
    0.05;
    0.06;
    0.04
];                  % 姿态控制器-比例系数，见<adcs.md>
Kd = [
    1.10;
    1.32;
    0.88
];                  % 姿态控制器-积分系数
Torque_limit = 0.2; % N*m，控制力矩限幅
% 反作用轮属性
tau = 0.05;         % s，伺服时间常数
A_mw = [
    -1/tau, 0 , 0, 0;
    0, -1/tau, 0, 0;
    0, 0, -1/tau, 0;
    0, 0, 0, -1/tau
];
B_mw = [
    1/tau, 0 , 0, 0;
    0, 1/tau, 0, 0;
    0, 0, 1/tau, 0;
    0, 0, 0, 1/tau
];
C_mw = [
    1, 0, 0, 0;
    0, 1, 0, 0;
    0, 0, 1, 0;
    0, 0, 0, 1
];
T_max = 0.05;       % N·m，轮最大输出力矩
Iw = 0.02;          % kg·m^2，轮转动惯量
eta = 0.7;          % 机电效率
% alpha_w = atan(sqrt(2));% 金字塔构型角
% beta1 = pi/4;       % 1#飞轮方位角
% beta2 = 3*pi/4;     % 2#飞轮方位角
% beta3 = 5*pi/4;     % 3#飞轮方位角
% beta4 = 7*pi/4;     % 4#飞轮方位角

A_w = [
  1, -1, -1, 1;
  1, 1, -1, -1;
  2, 2, 2, 2;
]*sqrt(1/6);      % 安装矩阵，列为各轮轴向
K_w = -A_w' * inv(A_w * A_w');

%% 通信子系统
f = 2.2e9;          % 载波频率
c = physconst('LightSpeed');    % 光速，m/s
Pt_dBW = 10;        % 发射功率，W
Gt_dB = 3;          % 星上天线
Gr_dB = 20;         % 地面站天线
Noise_dBW = -170;   % N=kTB,k=1.38e-23J/K,T=290K,B=1MHz
%% 打印信息
disp("["+char(datetime('now'))+"]：初始化完成。");