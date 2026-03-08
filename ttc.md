1. `comm_allow`, `comm_on`, `cmd_comm_enable`, `downlink_enable` 的关系 <br>
1.1 cmd_comm_enable（地面命令请求）
- 含义：地面"想要你开通信"的意图（1=请求开，0=请求关）
- 来源：TT&C/地面计划（通常还会受 in_view 约束）

1.2 comm_allow（星上允许）

- 含义：星上健康/电源/热控等综合判断"是否允许通信",例如 SOC 够不够、是否安全模式、温度是否超限……
- 来源：Power / FDIR / Mode Manager

1.3 comm_on（通信设备实际开关状态）

- 含义：最终送到通信子系统/发射机的"物理使能"
- 这是执行层信号，必须是单一来源的最终结果

1.4 downlink_enable（链路窗口使能）
- 含义：在"通信已允许且已请求"的前提下，还要满足"几何可见/链路条件"才允许下行
- 常见包含：in_view、FSPL门限、地面站窗口等