## 关于控制律的设计
1. 无轮
- 被控对象：$G(s)=\frac{1}{J\cdot s^2}=\frac{1}{10s^2}$
- PD控制器：$C(s)=K_p+K_d\cdot s$
- 开环传函：$L(s)=C(s)G(s)=\frac{K_d*s+K_p}{J\cdot s^2}$
- 闭环传函：$P(s)=\frac{K_d\cdot s+K_p}{J\cdot s^2+K_d\cdot s+K_p}$
- 自然频率：$\omega_n = \sqrt{K_p/J}$
- 阻尼比：$\zeta = \frac{K_d}{2\sqrt{J\cdot K_p}}$
- 选取超调量$\sigma=5\%，\zeta=0.69$
- 选取调节时间ts~(±2%)=10，
- $\omega_n=\frac{4}{\zeta\cdot t_s}=\frac{4}{0.69*10}=0.58 \;\text{rad/s}$
- $K_p=J\cdot \omega_n^2=3.36$
- $K_d=2\zeta\omega_nJ=8$

2. 简化轮
- 被控对象：$G(s)=\frac{1}{\tau \cdot s+1}\cdot\frac{1}{J_w\cdot s}\cdot\frac{1}{J\cdot s}$
- PD控制器：$C(s)=K_p+K_d\cdot s$
- 开环传函：$L(s)=C(s)G(s)=\frac{K_d*s+K_p}{J_w J\cdot s^2(\tau \cdot s + 1)}$
- 闭环传函：$P(s)=\frac{K_d\cdot s+K_p}{J_w\tau J\cdot s^3+J_wJ\cdot s^2+K_d\cdot s+K_p}$
- 劳斯判据：
    $$
    \[
    \begin{array}{c|cc}
    s^3 & a_3 & a_1 \\
    s^2 & a_2 & a_0 \\
    s^1 & b_1 & 0 \\
    s^0 & c_1 & 0 \\
    \end{array}
    \]
    $$
    其中，
    $$
    \[
    b_1 = \frac{a_2 a_1 - a_3 a_0}{a_2} = \frac{J_w J \cdot K_d - J_w J \tau \cdot K_p}{J_w J} = K_d - \tau K_p
    \]
    $$
    $$
    \[
    c_1 = \frac{b_1 a_0 - a_2 \cdot 0}{b_1} = a_0 = K_p \quad (\text{当 } b_1 > 0 \text{ 时})
    \]
    $$
- 闭环系统稳定的充分必要条件是：   
    -  $K_p > 0$
    -  $K_d > 0$
    -  $K_d-\tau K_p > 0$
- 极点配置：$(s^2 + 2\zeta\omega_n s + \omega_n^2)(s + p) = s^3 + (p + 2\zeta\omega_n)s^2 + (2\zeta\omega_n p + \omega_n^2)s + p \omega_n^2$
    - 即：
    $$
    \begin{cases}
    p + 2\zeta\omega_n = \frac{J_w J}{J_w J \tau} = \frac{1}{\tau} \\
    2\zeta\omega_n p + \omega_n^2 = \frac{K_d}{J_w J \tau} \\
    p \omega_n^2 = \frac{K_p}{J_w J \tau}
    \end{cases}
    $$
    - 选取超调量$\sigma=0\%，\zeta=1$
    - 选取调节时间ts~(±2%)=1，$\omega_n=4\;\text{rad/s}$
    - 选取主导极点$p=12\;\text{rad/s}$
    - $K_p=(p\omega_n^2)\cdot(J_wJ\tau)=1.92$
    - $K_d=(2\zeta\omega_np+\omega^2_n)\cdot(J_wJ\tau)=1.12$

3. 退饱和力矩计算
- 在航天器姿态动力学中，反作用轮产生的力矩通常通过角动量变化率 $\dot{h}_w$ 来体现，而外部执行器（如磁力矩器、喷气等）产生的力矩则作为外力矩直接作用。你提到的"退饱和力矩"是为了卸载反作用轮角动量而施加的外部力矩，其方向应与当前反作用轮总角动量 $h_w$ 相反，以减小轮子转速。

- 符号说明
    + 原方程：  
  $$
  I \frac{d\omega}{dt} + \omega \times (I\omega + h_w) = T_c + T_d
  $$
  其中 $T_c$ 为控制力矩（包括反作用轮力矩和其他执行器力矩），$T_d$ 为干扰力矩。

    + 若反作用轮力矩单独写出，则 $T_c = -\dot{h}_w + T_{ext}$，代入得：
  $$
  I \dot{\omega} + \omega \times (I\omega + h_w) = -\dot{h}_w + T_{ext} + T_d
  $$
  其中 $T_{ext}$ 为外部执行器力矩（如磁力矩器、推力器）。

- 退饱和力矩的引入 </br>
退饱和力矩 $T_{desat}$ 属于外部力矩，因此应放在 $T_{ext}$ 中。为使反作用轮角动量减小，该力矩方向应与 $h_w$ 相反，即：
$$
T_{desat} = -k \, h_w
$$
式中 $k>0$ 为系数（你取 $k=0.05$，可能每个轴独立）。注意 $h_w$ 是矢量，因此 $T_{desat}$ 也是矢量，其符号由 $h_w$ 的方向决定。

- 新的姿态动力学方程 </br>
将退饱和力矩纳入后，总外部力矩为 $T_{ext} = T_{other} + T_{desat}$，其中 $T_{other}$ 为其他外部控制力矩（如姿态控制所需）。则完整方程为：
$$
I \dot{\omega} + \omega \times (I\omega + h_w) = -\dot{h}_w + T_{other} - k h_w + T_d
$$
或等价地写作：
$$
I \dot{\omega} = -\omega \times (I\omega + h_w) - \dot{h}_w + T_{other} - k h_w + T_d
$$

- 总结
    + 退饱和力矩在方程中作为 **外部力矩** 项出现，符号为 **正**（即直接相加），但其具体数值为 **负的系数乘以当前反作用轮角动量**。
    + 如果你直接使用 $T_c$ 表示总控制力矩，则可将退饱和力矩与反作用轮力矩合并，但需注意符号一致性。通常建议将退饱和力矩单独列出，以明确其卸载作用。

目前控制律中已包含反作用轮力矩 $-\dot{h}_w$，则只需在方程右侧加上 $-0.05\,h_w$（或你设定的系数）即可。