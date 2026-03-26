clear;clc;
load('bus.mat');
%% 中心天体参数
mu = 3.986004418e14;% m^3/s^2
Re = 6378137;       % 地球半径，m
Re2 = 4.0589641e13; % m^2
J2 = 1.08262668e-3; % 
omegaE = 7.2921159e-5; % rad/s
h_ref = 400e3;      % m
rho_ref = 3e-12;    % kg/m^3
H = 50e3;           % m
earth_theta0 = 0;
%% 环境与轨道动力学子系统
% 大气阻力
Cd = 2.2;           % 
area_d = 4;         % m^2
m = 500;            % 卫星全部质量，kg
% 初始位置和速度
x0 = 7e6;           % m
y0 = 0;             % m
z0 = 0;             % m
vx0 = 0;            % m/s
vy0 = 7546;         % m/s
vz0 = 0;            % m/s
% 太阳光压参数
P0 = 4.56e-6;       % N/m^2
Cr = 1.2;           % 1~1.8
area_s = 2;         % m^2
hat_s = [1;0;0];    % 惯性系
% 儒略日
utc0 = posixtime(datetime(2026,01,01,08,00,00,'TimeZone','UTC'));
year = 2026; month = 1; day = 1; hh = 8; mm = 0; ss = 0;
frac = (hh + (mm + ss/60.0)/60.0) / 24.0;
D = day + frac;
A = floor(year/100);
B = 2 - A + floor(A/4);
utc0_jd = floor(365.25*(year + 4716)) + ...
          floor(30.6001*(month + 1)) + D + B - 1524.5;

%% ----------------------电源子系统---------------------
% ************通信可见性判断************
sta_lat = 0;        % 地面站纬度，rad
sta_lon = 0;        % 地面站经度，rad
sta_h = 0;          % 地面站高度，rad
sta_vec = (Re+sta_h) * [
    cos(sta_lat)*cos(sta_lon);
    cos(sta_lat)*sin(sta_lon);
    sin(sta_lat)
];                  % 地面站位置向量
gamma_max = 60*pi/180;% 最大可见角，rad/s
cos_g_max = cos(gamma_max);
% ************太阳电池阵参数
V_bus0 = 28;        % 参考母线电压，适用于整星功率需求2000W以下的卫星，V
C_bus = 1;      % 母线等效电容，需根据纹波电压要求具体计算，F
V_uvlo_off = 24;    % 欠压下限，低于则进入欠压模式，V
V_uvlo_on = 26;    % 欠压上限，高于则退出欠压模式，V

% ************太阳板参数*************
n_solar = [0;0;-1];  % 太阳板机体系法向量，X轴向
I_sc = 3.8;         % 面板短路电流，A
G0 = 1366.1;        % 太阳光照常数，地球轨道标准值，W/m^2
area_pannel = 1;    % 太阳板面积
I_f = 3.15e-7;      % 反向饱和电流，表示二极管的漏电流，A
R_s = 0.0042;       % 串联电阻，影响电池在负载下的性能，ohm
R_p = 10.1;         % 并联电阻，表示光伏电池的漏泄电流，ohm
V_t = 0.025;        % 热电压，V，通常为$V_t=kT/q$，其中k是玻尔兹曼常数，T是温度，q是电子电荷
n_diode = 1.4;            % 二极管的理想因子
Vmp = 7/15;          % 单结硅末期、高温下的工作电压
num_s = ceil((V_bus0+3)/Vmp);         % 光伏模块串联电池单元个数。
num_p = 2;         % 光伏模块并联电池单元个数。
V_oc = num_s*Vmp;   % 面板开路电压，需高于母线电压并留有余量，V
eta_mppt = 0.95;    % 最大功率点跟踪效率
eta_buck = 0.9;     % DC/DC Buck变换器效率
D_0 = 0.7;          % 初始占空比
Delta_D = 0.001;    % 占空比步长
D_min = V_bus0 / V_oc;        % 占空比最小值
D_max = 1;          % 占空比最大值
dP_th = 0.05;       % dP的有效变化阈值
% **************负载功耗*****************
P_base = 20;        % 基础功耗，W
P_adcs = 20;        % 姿态确认与控制固定功耗，W
P_prop = 5;         % 推进系统功耗（化学），W
P_comm = 30;        % 通信功耗，W
SOC_low_comm = 0.2; % 低于 20% 关通信功耗
SOC_low_prop = 0.2; % 低于 20% 关推进功耗
SOC_low_adcs = 0.1; % 低于 10% 关姿态功耗
beta = 0.3;         % 负载中电阻性占比
R_load = V_bus0^2/(beta*(P_base+P_adcs+P_prop+P_comm)); % 等效负载电阻
% *************充放电参数****************
P_trickle = 14/V_bus0;  % 涓流充电电流，A
P_cc = 220/V_bus0;      % 稳流充电电流，A
SOC1 = 0.2;         % 涓流|稳流
SOC2 = 0.8;         % 稳流|稳压
% *************蓄电池参数***************
P_dis_lim = -200;   % 放电限流，W
I_chg_max = 8;      % 充电电流限幅，A
I_dis_max = 10;     % 放电电流限幅，A
eta_chg = 0.95;     % 充电效率
eta_dis = 0.95;     % 放电效率
Qbat = 20;             % 最大电量，Ah
SOC0 = 0.6;         % 初始荷电状态
V_max = 33;         % 最大电压，V
V_min = 24;         % 最小电压，V
Rb = 0.2;           % 蓄电池内阻，ohm
%% ---------------------姿态确定与控制子系统-------------------
% ******************航天器物理属性*********************
Jx = 10;            % kg*m^2, 航天器框架转动惯量——X轴向
Jy = 12;            % kg*m^2, 航天器框架转动惯量——Y轴向
Jz = 8;             % kg*m^2, 航天器框架转动惯量——Z轴向
% ******************航天器状态属性******************
w0 = [0;0;0];       % 初始角速度
Q0 = [0.6;0.8;0;0]; % 初始四元数
quat = quaternion(Q0');
eAR = euler(quat, 'ZYX', 'frame');% eulerAngles,Rad
angle0 = eAR';   % 初始角度

% angleE = [-1.4326    0.3894   -0.3400];
% angleE = [0,0,0];
angleE = angle0';
QE = eul2quat(angleE, 'ZYX');

% ******************姿态控制器属性******************
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
control_flag = 0;   % 控制指令切换标志位
Torque_limit = 0.2; % N*m，控制力矩限幅
% ******************反作用轮属性******************
tau = 0.05;         % s，伺服时间常数
% 反作用轮组件等效状态空间
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
kp_w = 100;         % 力矩电机控制器-比例系数
ki_w = 0;           % 力矩电机控制器-积分系数
i_w_min = -2;       % 指令电流下限
i_w_max = 2;        % 指令电流上限
Cm = 0.01;          % 电磁转矩系数
d_f = 2e-5;         % 粘性摩擦力矩系数
d_c = 2e-5;         % 库仑摩擦力矩
T_max = 0.05;       % N·m，轮最大输出力矩
Iw = 0.02;          % kg·m^2，轮转动惯量
eta = 0.7;          % 机电效率
rpm_max = 6000;     % 反作用轮最大转速，rpm
h_max = Iw * rpm_max * sqrt(6);% 单轴角动量上限
sf_factor = 0.85;   % 安全系数
k_h = -0.05;         % 角动量卸载比例系数，1/s

% alpha_w = atan(sqrt(2));% 金字塔构型角
% beta1 = pi/4;       % 1#飞轮方位角
% beta2 = 3*pi/4;     % 2#飞轮方位角
% beta3 = 5*pi/4;     % 3#飞轮方位角
% beta4 = 7*pi/4;     % 4#飞轮方位角

A_w = [
  1, -1, -1, 1;
  1, 1, -1, -1;
  2, 2, 2, 2;
]*sqrt(1/6);                % 安装矩阵，列为各轮轴向
K_w = A_w' / (A_w * A_w');  % 分配矩阵，安装矩阵的伪逆
p_sat = 1*pi/180;            % 角速度限幅，rad/s
q_sat = 1*pi/180;            % 角速度限幅，rad/s
r_sat = 1*pi/180;            % 角速度限幅，rad/s
% ******************激光陀螺******************
% 几何参数
perimeter_m = 0.4;          % 谐振腔弦长，m
area_m2 = 0.0127;           % 谐振腔面积，m^2
wavelength_m = 632.8e-9;    % 波长，m

% PZT控制参数
V_pzt_min = 0;              % PZT最小工作电压 [V]
V_pzt_max = 100;            % PZT最大工作电压 [V]

% 扫模控制参数
sweep_frequency = 50;       % 扫模频率 [Hz]

% 热模型参数
tau_th_s = 200;
k_sf1_ppm = 1.0;k_sf2_ppm = 0.0;
bias0_deg_h = 0.01;
k_bias1_deg_h_per_C = 1;k_bias2_deg_h_per_C = 0.0;

% 抖动参数
f_n_hz = 400;
zeta = 0.01;
v_peak_deg_s = 1.0;
initial_phase = 0;

% 扫模参数
% 光强控模阈值
I_triggle = 8;
% 光强门槛阈值
I_gate = 0.5;
% 期望光强,峰值的80%~90%
I_e = 11;
kP = 10;
kI = 0.01;
V_center = 50;

% Lamb 方程参数
% 动态增益灵敏度
k_a = 4e-4;
% 增益系数
alpha1 = 0.1; alpha2 = 0.1;
% 自饱和系数
beta1 = 0.01; beta2 = 0.01;
% 交叉饱和系数
theta12 = 0.005; theta21 = 0.005;
% 频率基准频率
sigma1 = 0; sigma2 = 0;
% 互聚焦系数
tau12 = 0.001; tau21 = 0.001;
% 反向散射系数
r1 = 1e-4; r2 = 1e-4;
% 反向散射固有相移
epsilon = 0.01;

% 噪声参数
ARW_deg_per_sqrt_h = 0.01;
white_rate_std_deg_s = 0;

% ******************星敏*********************
f_st = 5;           % 星敏更新率，Hz
Ts_st = 1/f_st;     % 星敏更新周期，s
T_delay_st = 0.2;   % 星敏延迟，s
sigma_arcsec = 30;  % 1sigma姿态噪声，角秒
sigma_rad = sigma_arcsec / 3600 * pi/180;   % 弧度,rad
p_drop = 0.02;      % 掉帧概率
% ******************太敏*********************
sigma_sun = 0.5*pi/180;    % 噪声，rad
fov = 60*pi/180;    % FOV半角，rad
n_sun = [0;0;1];    % 传感器安装朝向轴
% ******************地敏*********************
sigma_earth = 0.2*pi/180;   % 噪声，rad

% ******************姿态解算******************
t_a = 1;            % 姿态解算周期，s
kp_f = 1;           % 姿态纠正强度，rad/s per rad
ki_f = 0.01;        % 偏执估计速率，rad/s^2 per rad
Tcorr_limit = 0.05; % kp*e限幅
%% -------------------通信子系统--------------------------
f = 2.2e9;          % 载波频率
c = physconst('LightSpeed');    % 光速，m/s
Pt_dBW = 10;        % 发射功率，W
Gt_dB = 3;          % 星上天线
Gr_dB = 20;         % 地面站天线
Noise_dBW = -170;   % N=kTB,k=1.38e-23J/K,T=290K,B=1MHz
% *******************微波和射频固态功率放大器****************
P_in_driver_dBW = -6;   % 前级驱动功率，dBW
G_sspa_dB = 20;         % 小信号增益功率，dB
P_sspa_dBW = 15;        % 最大输出功率，dBW
eta_sspa = 0.35;        % 效率    
% *******************行波管功率放大器****************
G_twta_dB = 20;         % 小信号增益功率，dB
P_twta_dBW = 15;        % 最大输出功率，dBW
eta_twta = 0.35;        % 效率  

%% -------------------推进子系统--------------------------
% 化推
T_nominal = 100;    % 固定推力，N
Isp = 220;          % 化推比冲，s
g0 = 9.80665;       % 重力加速度
m0 = 20;            % 初始工质质量，kg
tau_thr = 0.2;      % 推力时间常数
r_ref = 7.026e6;    % 轨道半径维持
D_thr = 0.4;        % 推力输出占空比
T_thr = 1;          % 推力输出周期
% 电推
eta_et = 0.9;       % 电推推进效率，0~1
P_et_max = 25;      % 电推功耗，W
m0_et = 5;          % 电推推进剂初始质量，kg
tau_et = 0.5;       % 电推响应时间常数 
Isp_et = 1500;      % 电推比冲，s
L = 0.5;            % 电推推力方向与卫星质心距离，m
P_overhead = 1;     % 电子、控制器、阀门等固定开销（开机就有
%% -------------------测控子系统--------------------------
comm_allow = 1;     % 通信允许，0/1
cmd_on_step = 500;  % 发射机开机指令时刻，s
cmd_off_step = 2000;% 发射机关机指令时刻，s
R_data = 1e6;       % 数据生成速率
cmd_comm = 1;       % 通信指令
%% -------------------故障注入部分-------------------------
% 光纤陀螺
%# 偏差
gyro_bias_on = 0;           % 使能
gyro_bias_time = 0;         % 注入时间
gyro_bias_value = [0;0;0];  % 幅度
%# 漂移
gyro_drift_on = 0;           % 使能
gyro_drift_time = 0;         % 注入时间
gyro_drift_value = [0;0;0];  % 幅度
gyro_drift_max = 0.1;        % 限幅
%# 锁定
gyro_lock_on = 0;           % 使能
gyro_lock_time = 0;         % 注入时间
%# 掉线
gyro_drop_on = 0;           % 使能
gyro_drop_time = 0;         % 注入时间
gyro_drop_value = [0;0;0];  % 幅度
%# 延迟
gyro_delay_on = 0;           % 使能
gyro_delay_time = 0;         % 注入时间
gyro_delay_value = 0;        % 延迟步长，整数
% 星敏
%# 偏差
star_bias_on = 0;           % 使能
star_bias_time = 0;         % 注入时间
star_bias_value = [0;0;0];  % 幅度
%# 漂移
star_drift_on = 0;           % 使能
star_drift_time = 0;         % 注入时间
star_drift_value = [0;0;0];  % 幅度
star_drift_max = 0.1;        % 限幅
%# 锁定
star_lock_on = 0;           % 使能
star_lock_time = 0;         % 注入时间
%# 掉线
star_drop_on = 0;           % 使能
star_drop_time = 0;         % 注入时间
star_drop_value = [0;0;0];  % 幅度
%# 延迟
star_delay_on = 0;           % 使能
star_delay_time = 0;         % 注入时间
star_delay_value = 0;        % 延迟步长，整数
% 太敏
%# 偏差
dss_bias_on = 0;           % 使能
dss_bias_time = 0;         % 注入时间
dss_bias_value = [0;0;0];  % 幅度
%# 漂移
dss_drift_on = 0;           % 使能
dss_drift_time = 0;         % 注入时间
dss_drift_value = [0;0;0];  % 幅度
dss_drift_max = 0.1;        % 限幅
%# 锁定
dss_lock_on = 0;           % 使能
dss_lock_time = 0;         % 注入时间
%# 掉线
dss_drop_on = 0;           % 使能
dss_drop_time = 0;         % 注入时间
dss_drop_value = [1;0;0];  % 幅度
%# 延迟
dss_delay_on = 0;           % 使能
dss_delay_time = 0;         % 注入时间
dss_delay_value = 0;        % 延迟步长，整数
%-----------------------------
% 反作用轮组件
%# 力矩退化
rw1_deg_on = 0;           % 使能
rw1_deg_time = 0;         % 注入时间
rw1_deg_value = 1;        % 幅度
%# 力矩饱和
rw1_sat_on = 0;           % 使能
rw1_sat_time = 0;         % 注入时间
rw1_sat_value = 1;        % 幅度
%# 力矩延迟
rw1_delay_on = 0;           % 使能
rw1_delay_time = 0;         % 注入时间
rw1_delay_value = 0;        % 幅度
%# 力矩掉线
rw1_drop_on = 0;           % 使能
rw1_drop_time = 0;         % 注入时间
rw1_drop_value = 0;        % 幅度
%# 力矩迟缓
rw1_slow_on = 0;           % 使能
rw1_slow_time = 0;         % 注入时间
rw1_slow_value = 0;        % 幅度
%# 力矩锁定
rw1_lock_on = 0;           % 使能
rw1_lock_time = 0;         % 注入时间
%# 摩擦力矩乘性
rw1_fric_on = 0;           % 使能
rw1_fric_time = 0;         % 注入时间
rw1_fric_value = 0;        % 幅度
%# 摩擦力矩加性
rw1_bias_on = 0;           % 使能
rw1_bias_time = 0;         % 注入时间
rw1_bias_value = 0;        % 幅度
%------------------------
%# 力矩退化
rw2_deg_on = 0;           % 使能
rw2_deg_time = 0;         % 注入时间
rw2_deg_value = 1;        % 幅度
%# 力矩饱和
rw2_sat_on = 0;           % 使能
rw2_sat_time = 0;         % 注入时间
rw2_sat_value = 1;        % 幅度
%# 力矩延迟
rw2_delay_on = 0;           % 使能
rw2_delay_time = 0;         % 注入时间
rw2_delay_value = 0;        % 幅度
%# 力矩掉线
rw2_drop_on = 0;           % 使能
rw2_drop_time = 0;         % 注入时间
rw2_drop_value = 0;        % 幅度
%# 力矩迟缓
rw2_slow_on = 0;           % 使能
rw2_slow_time = 0;         % 注入时间
rw2_slow_value = 0;        % 幅度
%# 力矩锁定
rw2_lock_on = 0;           % 使能
rw2_lock_time = 0;         % 注入时间
%# 摩擦力矩乘性
rw2_fric_on = 0;           % 使能
rw2_fric_time = 0;         % 注入时间
rw2_fric_value = 0;        % 幅度
%# 摩擦力矩加性
rw2_bias_on = 0;           % 使能
rw2_bias_time = 0;         % 注入时间
rw2_bias_value = 0;        % 幅度
% 3----------------------------
%# 力矩退化
rw3_deg_on = 0;           % 使能
rw3_deg_time = 0;         % 注入时间
rw3_deg_value = 1;        % 幅度
%# 力矩饱和
rw3_sat_on = 0;           % 使能
rw3_sat_time = 0;         % 注入时间
rw3_sat_value = 1;        % 幅度
%# 力矩延迟
rw3_delay_on = 0;           % 使能
rw3_delay_time = 0;         % 注入时间
rw3_delay_value = 0;        % 幅度
%# 力矩掉线
rw3_drop_on = 0;           % 使能
rw3_drop_time = 0;         % 注入时间
rw3_drop_value = 0;        % 幅度
%# 力矩迟缓
rw3_slow_on = 0;           % 使能
rw3_slow_time = 0;         % 注入时间
rw3_slow_value = 0;        % 幅度
%# 力矩锁定
rw3_lock_on = 0;           % 使能
rw3_lock_time = 0;         % 注入时间
%# 摩擦力矩乘性
rw3_fric_on = 0;           % 使能
rw3_fric_time = 0;         % 注入时间
rw3_fric_value = 0;        % 幅度
%# 摩擦力矩加性
rw3_bias_on = 0;           % 使能
rw3_bias_time = 0;         % 注入时间
rw3_bias_value = 0;        % 幅度
% -----------------------------
%# 力矩退化
rw4_deg_on = 0;           % 使能
rw4_deg_time = 0;         % 注入时间
rw4_deg_value = 1;        % 幅度
%# 力矩饱和
rw4_sat_on = 0;           % 使能
rw4_sat_time = 0;         % 注入时间
rw4_sat_value = 1;        % 幅度
%# 力矩延迟
rw4_delay_on = 0;           % 使能
rw4_delay_time = 0;         % 注入时间
rw4_delay_value = 0;        % 幅度
%# 力矩掉线
rw4_drop_on = 0;           % 使能
rw4_drop_time = 0;         % 注入时间
rw4_drop_value = 0;        % 幅度
%# 力矩迟缓
rw4_slow_on = 0;           % 使能
rw4_slow_time = 0;         % 注入时间
rw4_slow_value = 0;        % 幅度
%# 力矩锁定
rw4_lock_on = 0;           % 使能
rw4_lock_time = 0;         % 注入时间
%# 摩擦力矩乘性
rw4_fric_on = 0;           % 使能
rw4_fric_time = 0;         % 注入时间
rw4_fric_value = 0;        % 幅度
%# 摩擦力矩加性
rw4_bias_on = 0;           % 使能
rw4_bias_time = 0;         % 注入时间
rw4_bias_value = 0;        % 幅度
% 化学推进故障
%------------------------
%# 推力退化
cT_deg_on = 0;           % 使能
cT_deg_time = 0;         % 注入时间
cT_deg_value = 1;        % 幅度
%# 推力延迟
cT_delay_on = 0;           % 使能
cT_delay_time = 0;         % 注入时间
cT_delay_value = 0;        % 幅度
%# 推力掉线
cT_drop_on = 0;           % 使能
cT_drop_time = 0;         % 注入时间
cT_drop_value = 0;        % 幅度
%# 推力锁定
cT_lock_on = 0;           % 使能
cT_lock_time = 0;         % 注入时间
% 电推
%# 推力退化
eT_deg_on = 0;           % 使能
eT_deg_time = 0;         % 注入时间
eT_deg_value = 1;        % 幅度
%# 推力延迟
eT_delay_on = 0;           % 使能
eT_delay_time = 0;         % 注入时间
eT_delay_value = 0;        % 幅度
%# 推力掉线
eT_drop_on = 0;           % 使能
eT_drop_time = 0;         % 注入时间
eT_drop_value = [0;0;0];        % 幅度
%# 推力锁定
eT_lock_on = 0;           % 使能
eT_lock_time = 0;         % 注入时间
% 母线电压
%# 压降
Vbus_bias_on = 0;           % 使能
Vbus_bias_time = 0;         % 注入时间
Vbus_bias_value = 0;        % 幅度
%# 掉线
Vbus_drop_on = 0;           % 使能
Vbus_drop_time = 0;         % 注入时间
Vbus_drop_value = 0;        % 幅度
% 蓄电池组
%# 容量衰减乘性
bat_cap_on = 0;           % 使能
bat_cap_time = 0;         % 注入时间
bat_cap_value = 1;        % 幅度
%# 容量衰减加性
bat_bias_on = 0;           % 使能
bat_bias_time = 0;         % 注入时间
bat_bias_value = 0;        % 幅度
% 太阳翼故障
%# 输出退化
wing_deg_on = 0;           % 使能
wing_deg_time = 0;         % 注入时间
wing_deg_value = 1;        % 幅度
%# 掉线
wing_drop_on = 0;           % 使能
wing_drop_time = 0;         % 注入时间
wing_drop_value = 0;        % 幅度
%% -------------------仿真参数----------------------------
dt = 0.1;             % 仿真步长
disp("["+char(datetime('now'))+"]：初始化完成。");