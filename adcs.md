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

