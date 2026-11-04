---
name: verification-closure
description: 为FPGA神经网络建立整数参考、模块自检、事务轨迹记分板与系统回归，并基于实现报告审查资源、setup、hold和约束覆盖。用于RTL验证与实现收敛，不将仿真或旧报告代替当前板级验收。
---

# 05 分层仿真、黄金参考与实现收敛

## 适用范围与用法

用于RTL模块开发、集成修改和性能/时序优化后的回归。输入为设计契约、整数参考、DUT/存储模型、工具报告和验收目标。复制 [测试矩阵](assets/test-matrix.csv) 补充覆盖项，使用 [trace_scoreboard.py](scripts/trace_scoreboard.py) 对比事务轨迹。先定位最小失败层级，再改设计。

## 分层工作流

1. **四级参考：**目标热场衡量任务质量；浮点网络衡量模型；量化整数网络衡量量化差异；RTL对同一整数输入的结果衡量实现差异。硬件对目标热场误差大，不足以独立证明RTL错误。
2. **模块：**先验证PE数值、fire/last/clear、延迟与空拍；再验证BRC窗口地址/边界，BWC写回位置/时间步，最后验证ILC/权重bank切换和DDR接受/完成。随机激励须有独立参考或不变量。
3. **协议：**将有效事务记录为 `cycle,valid,data,last,tag`；只有valid才消费数据，但valid丢失、多发、元数据错配都判失败。固定流水检查周期差，变延迟接口按接受顺序检查并另定最大等待时间。
4. **集成：**用小尺寸非对称输入覆盖padding、pool、反卷积奇偶位置、首末层和skip生命周期；再跑真实样本。旧TB中的层次force、固定ready和绝对路径必须先识别。
5. **实现：**同时查资源容量、setup/hold/pulse width、失败端点、无时钟/未约束路径、I/O delay及DRC/CDC。与同一源码/约束/工具配置的构建绑定，不能只给“生成bit成功”。

## 可复制提示词：从RTL构造验证

```text
请为附带RTL及接口契约建立最小自检验证。先说明独立参考如何得到，不以DUT同一表达式复制一遍作为证明。
列输入事务接受条件、输出延迟、状态优先级和覆盖矩阵；对空拍、reset/clear、负数、阈值相等、边界地址和阻塞组合给确定性反例。
使用scoreboard比较数据、valid、last、tag和周期，设置超时与$ fatal失败条件；随机测试使用固定seed。
如TB强制ready或直接写内部RAM，说明哪些行为被旁路，不能声称DDR/CDC已验证。
输出运行命令和通过/失败判据，明确模板测试、原项目模块测试和系统上板测试的区别。
```

## 可复制提示词：报告驱动优化

```text
请分析附带同一构建的routed timing、utilization、DRC/CDC、XDC和关键路径。
先列报告日期、器件、阶段、WNS/TNS、WHS/THS、WPWS、失败端点和约束覆盖；每项引用原字段。
区分容量、关键路径、带宽和板级吞吐证据。资源占用高不等于已经证明运行速度瓶颈。
只提出至多3个最小修改实验，各写预期影响、可能破坏的数值/协议行为和需要重跑的回归。
不以任意false_path或降低约束掩盖违例；例外约束必须有真实时钟/协议依据。
```

## 案例与踩坑

- 原 `tb/tb_snn_top.v` 强制DDR校准和ready，并直接操作内部RAM，含历史绝对路径；它是特定观察场景，不能证明DDR阻塞组合正确。`pe/tb_pec.v` 还有FSDB调用，换仿真器需确认支持或加条件编译。
- 本次新增PE模板TB使用独立顺序参考检查数值与逐拍valid，覆盖清空在途事务；不将结果记为原 `pe.v` 全模式验证。
- 本机历史 `impl_3` 报告有 WNS=0.179 ns、WHS=-3.025 ns、hold失败端点5，说明setup正裕量不能代替完整时序判断。历史placed BRAM为98.45%，资源优化应先看存储结构/端口与生命周期，再决定是否减少PE。报告未与当前位流建立构建对应，不能当当前结果。

## 工具接口、验证效果与失效条件

```powershell
python skill/verification-closure/scripts/trace_scoreboard.py --expected golden.csv --actual rtl.csv --latency 1 --output comparison.json
```

CSV中的周期必须采用同一采样沿/更新后定义；`latency` 是实际cycle差，不是寄存器级数。省略 `--latency` 仅按有效事务顺序比较，并在输出明确不检查周期。`tag` 可编码 `(layer,timestep,row,col,channel)`，没有tag时填一致空串，不能据此保证身份。

本次测试了轨迹匹配、数据/数量/last/tag/延迟不符、非法CSV和无时序检查模式；实际RTL仿真记录见 `../validation/README.md`。记分板不推导黄金值，参考错误或DUT缺少观测点时结论受限。CDC、DDR、时序关闭及板级精度需各自证据，不能合并为一个“全部通过”。
