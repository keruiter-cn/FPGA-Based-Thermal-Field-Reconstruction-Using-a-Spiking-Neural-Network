---
name: memory-scheduling
description: 设计FPGA神经网络的层控制字、BRAM/URAM/DDR存储规划、双缓冲与层间调度，使用可编解码schema核对控制ROM。适用于控制与访存架构设计，不代替DDR或CDC专项验证。
---

# 03 控制字、层间调度与存储协同设计

## 适用范围与使用方法

用于将网络层表变成调度ROM和FSM、规划特征图与权重存储、安排权重搬运和计算重叠。提供层图、硬件通道分组、端口数/读延迟、DDR UI协议和时钟域。先填 [存储规划表](assets/memory-plan.csv)，再用 [字段schema](assets/layer-fields.json) 与 [control_words.py](scripts/control_words.py) 生成/解读控制字。

## 工作流

1. 将每份数据从生产到最后一个消费者的生命周期画出来。常规层中间结果可复用bank，跨层保留的skip特征不能提前覆盖；是否使用拼接以实际数据通路为准。
2. 对每个bank列“写者/读者、时钟域、地址单位、占用范围、读延迟、切换条件”。`ping=1` 本身不说明读哪边：权重模板中1写ping读pong，FMS接口可能表示读ping。
3. 把层调度拆为权重装载、输入到达、初次搬权重、层参数加载、搬运/等待、推理完成、结果回传。请求发出不等于数据到齐，完成信号必须对应最后一次实际接收/写入。
4. 设计控制字从schema开始，明确MSB→LSB顺序和每字段范围；生成器拒绝溢出/缺失，不依赖字符串最小宽度格式化自动截断。硬件解包与软件编码做往返和边界测试。
5. DDR命令通道和写数据通道分别按实际ready计数，FIFO非空和最后一拍处理单独覆盖；跨域多bit地址用稳定窗口/握手或FIFO，不能逐bit双触发器同步。

## 当前控制字的可运行案例

`ilc.v` 使用95位层控制：最高两个9位字段用于当前/下一权重搬运距离；低77位为模式、8位输出组数、4位shift、URAM选择/基址、8位输入组数和前后尺寸。字段实际用途以 `r_brm_rd_data` 解包、`weight_rd_distance` 和输出赋值为依据。

```powershell
python skill/memory-scheduling/scripts/control_words.py decode --coe file/coe/unet/SNNUnet_control_200-200_no_cat.coe --output controls.json
python skill/memory-scheduling/scripts/control_words.py encode --rows controls.json --output regenerated.coe
```

这两个命令仅编解码本项目格式，后续换IP或schema需一起更新。生成文件默认放新路径，不覆盖原工程COE。本次对当前27个95位控制字逐条decode→encode，验证位模式一致；不等于所有层地址/状态转移已仿真通过。

## 可复制提示词

```text
请依据层表、IP端口/读延迟、DDR UI信号和现有FSM，设计层控制及存储调度。
先输出数据生命周期和bank所有权表；为权重ping-pong、FMS ping-pong和URAM分别定义0/1的含义。
列每个状态的进入条件、输出动作、ready接受条件、完成证据和超时观察点，区分请求发出与最后数据写入。
给出控制字MSB到LSB schema及软件编码/RTL解包，整数溢出、group计数减一、地址单位必须显式处理。
重点测试首层/末层、奇数尺寸、skip特征保留、同拍完成与切bank、DDR命令和数据ready不同步。
对跨时钟域逐条写同步方法和数据稳定条件。资料不足时标出缺口，不假设所有ready恒为1。
```

## 项目来源与踩坑

- `rtl/ilc/ilc.v` 的 `S_INIT_WEIGHT/S_INIT_FMS/S_INIT_MOVE_WEIGHT/S_ITLC/S_MOVE_WEIGHT/S_WAIT_WEIGHT/S_WAIT_INFER/S_OUT_FMS` 是层控制实例，COE中保存27个层记录。
- `itlc_out_ch_num=out_ch_num-1`、`pec_in_ch_num=in_ch_num-1` 表明字段值与硬件计数上限不同；硬件窄端口还可能截断，schema范围正确并不保证连接宽度正确。
- 该版本 `itlc_concat_or_not` 固定为0；U-Net的层12/15有专门尺寸/池化控制。改网络时不能认为27条ROM可任意换成新层表而无RTL改动。
- `pp_wgt_buf.v` 有256位写/512位读和一级写入寄存；切bank前需确认最后写拍落入目标bank。`fms.v` 中有独立计算/以太网时钟及bank选择往返同步，不能把所有切换简化成单周期翻转。
- `rtl/ddr/new/ddr_rwc.sv` 同时处理校准、命令ready、写data ready、读valid和FIFO；本包只提炼检查方法，不声称该DDR控制器对所有阻塞组合都已重测。

## 验证效果与失效条件

schema已对当前COE做往返及字段溢出反例测试；新增规划表是可填写模板。未进行完整ILC/DDR/URAM仿真。控制字版本不同、地址单位不明、动态shape、跨域协议变化时需重新定义并验证。总bit容量只是下限估计，BRAM颗粒/端口/宽深配置和复制开销以实现报告为准。
