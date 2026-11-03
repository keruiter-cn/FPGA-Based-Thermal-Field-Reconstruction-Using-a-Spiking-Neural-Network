# 基于脉冲神经网络的 FPGA 温度场重建系统

## 1. 项目简介

本项目面向稀疏测温条件下的二维温度场重建，在 FPGA 上部署脉冲神经网络（Spiking Neural Network，SNN），根据编码后的测温数据推理得到完整温度场。系统由 FPGA 加速器和 Python 图形化上位机组成，覆盖权重下发、输入传输、硬件推理、结果回传、热场可视化与误差分析的完整流程。

本提交版本以 **SNN U-Net** 为复现对象，输入与输出空间尺寸为 **200 × 200**，脉冲时间步为 **3**。FPGA 侧实现网络调度、并行计算、特征图缓存、DDR4 权重存取和以太网通信；PC 侧通过 UDP 下发权重与编码数据，接收重建结果，并与配套参考数据比较，展示 MAE、MRE、RMSE、热点位置和温度范围。

上位机还提供 AI 辅助分析功能，可选择 DeepSeek 云端服务或 Ollama 本地模型，对当前样本的误差与热点进行解释。AI 功能用于结果分析，温度场重建由 FPGA 完成。

```text
网络权重 + 编码测温数据
          │ PC → FPGA（UDP）
          ▼
 FPGA：权重存储 → SNN U-Net 推理 → 温度场输出
          │ FPGA → PC（UDP）
          ▼
 Python GUI：稀疏观测 / 重建热场 / 参考热场
          └─ 误差指标 + DeepSeek / Ollama 辅助分析
```

## 2. 工程目录

```text
fpga-contest/
├─ README.md                           # 项目介绍与复现说明
├─ pc_python/
│  ├─ requirements-host.txt             # 上位机基础依赖，PyTorch 另行安装
│  ├─ socket/
│  │  ├─ GUI_send2fpga.py               # 图形界面启动入口
│  │  ├─ dashboard_ui.py                # 工作台界面布局与指标展示
│  │  ├─ send2fpga_class.py             # UDP 通信、结果解码与参考数据对比
│  │  ├─ DRIVE_dataset_2_fpath.py       # MAT 参考数据读取
│  │  ├─ image_hot_generate.py          # 热场图生成
│  │  ├─ local_ai_client.py             # DeepSeek / Ollama 客户端
│  │  └─ ...                           # 网络定义、编码及数据转换脚本
│  └─ pre_process/                     # 网络定义、脉冲编码与数据预处理脚本
├─ snn_top_v3/
│  └─ eth_ddr_test/
│     ├─ udp_loop_axu15egb.xpr          # Vivado 工程入口
│     ├─ rtl/
│     │  ├─ snn_top.v                  # 硬件顶层
│     │  ├─ proj_snn.vh                # 网络选择及硬件参数
│     │  ├─ pe/                       # 并行计算单元及权重缓存控制
│     │  ├─ ilc/                      # 网络层间调度
│     │  ├─ brwc/                     # 特征图读写控制
│     │  ├─ fms/                      # 特征图存储
│     │  └─ eth/、ddr/                # 以太网通信与 DDR4 控制
│     ├─ ip/                          # IP 核及相关文件
│     ├─ udp_loop_axu15egb.srcs/       # 工程引用的 IP、导入源码、DCP 与引脚约束
│     └─ tb/                          # 仿真测试文件
├─ file/
│  ├─ bitstream/unet/snn_top.bit       # 已提供的 U-Net 位流
│  ├─ bitstream/segnet/                # SegNet 相关位流与调试文件
│  ├─ coe/                            # 网络控制与偏置初始化文件
│  ├─ weight/unet_weights_reverse.txt  # 本次复现使用的权重文件
│  ├─ input_example/reversed_data/unet/ # 本次复现使用的编码输入目录
│  └─ output_compare/                 # 与输入样本对应的 MAT 参考数据
└─ report/                            # 项目技术文档
```

Vivado 生成的 `.runs`、`.cache`、`.gen` 等目录为构建产物。源码编译时应保留 `.xpr`、`rtl`、`ip`、`.srcs` 和 `file/coe` 的相对目录关系，尤其不要遗漏工程导入的 DCP 文件。

### 仓库交付与大文件说明

本仓库用于向赛题方交付源码和复现材料，保留 Python 上位机、Vivado 工程与源码、约束、IP 配置、工程引用的 DCP、COE 初始化文件、预生成位流、模型权重、80 组输入及参考数据和技术文档。工程在 `.srcs/utils_1/imports/` 中引用的检查点也随仓库保留；这些文件不能仅按扩展名当作临时文件忽略。

`.gitignore` 排除 Vivado 的 `.runs`、`.cache`、`.gen`、`.hw`、`.sim`、`.ip_user_files`、`.Xil`、日志及 Python 缓存。这些内容保留在本机，不随 Git 提交；赛题方可按下文步骤重新生成构建产物。

本次提交的单个文件均小于 100 MiB，直接通过普通 Git 保存，未使用 Git LFS，下载仓库即可取得实际材料。后续若增加超过 100 MiB 的文件，或频繁更新大型二进制文件，可改用 Git LFS；用于一次性交付的大型数据包也可放到 GitHub Release，并在此记录下载链接、版本和 SHA-256 校验值。GitHub 对普通 Git 文件超过 50 MiB 给出警告，超过 100 MiB 则拒绝接收，详见 [GitHub 大文件说明](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)。

交付可使用仓库页面的 **Code → Download ZIP**，或执行 `git clone`。请从仓库根目录开始使用，保留目录层级；仅下载 `.xpr` 无法复现工程。

## 3. 复现环境与材料

| 项目      | 配置                                                          |
| --------- | ------------------------------------------------------------- |
| PC        | Windows，安装 Anaconda 或 Miniconda                           |
| Python    | 3.12；依赖安装见下文                                          |
| FPGA 工具 | Vivado 2023.1，安装对应器件支持及下载驱动                     |
| FPGA 器件 | `xczu15eg-ffvb1156-2-i`，开发板接口与工程引脚约束匹配       |
| 硬件连接  | 开发板电源、JTAG 下载连接、PC 与 FPGA PL 侧以太网口之间的网线 |
| AI 服务   | DeepSeek API Key，或已安装并启动的 Ollama 本地服务            |

复现使用工程中已有的权重、编码输入和参考数据，无需先运行训练或预处理脚本。请确认以下材料完整：

- `file/weight/unet_weights_reverse.txt`
- `file/input_example/reversed_data/unet/` 下的输入 TXT 文件。
- `file/output_compare/` 下对应的 `Example*.mat` 文件。

当前材料包含 80 个 U-Net 输入样本与 80 个对应参考文件。上位机从输入文件名提取样本编号，例如 `incode_unet_Example1000_re.txt` 对应 `file/output_compare/Example1000.mat`；参考文件中的 `u` 和 `u_obs` 分别用于参考热场和稀疏观测显示。请保留文件名及对应关系，并保持输入目录只包含待发送的编码 TXT 数据。

## 4. 复现步骤

### 步骤一：创建 Conda 环境并安装依赖

在支持 `conda` 的 PowerShell 或 Anaconda PowerShell Prompt 中进入工程根目录，依次执行：

```powershell
conda create -n fpga-snn python=3.12 -y
conda activate fpga-snn
python -m pip install --upgrade pip
python -m pip install -r .\pc_python\requirements-host.txt
python -m pip install torch==2.14.0 torchvision==0.29.0 --index-url https://download.pytorch.org/whl/cpu
```

`requirements-host.txt` 安装 NumPy、SciPy、Matplotlib 和 PyQt5；通信模块还会使用 PyTorch 与 torchvision，因此需执行最后一条安装命令。这里采用 CPU 版本即可运行上位机，不要求 PC 配置 CUDA。上述 Python 与依赖版本组合已在本机通过 GUI 及通信模块导入检查。

安装完成后检查依赖：

```powershell
python -c "import numpy, scipy, matplotlib, torch, torchvision; from PyQt5 import QtWidgets; print('Dependencies OK')"
python -m pip check
```

### 步骤二：编译、综合与实现 Vivado 工程

1. 使用 **Vivado 2023.1** 打开 `snn_top_v3/eth_ddr_test/udp_loop_axu15egb.xpr`。
2. 确认工程器件为 `xczu15eg-ffvb1156-2-i`，顶层模块为 `snn_top`，引脚约束为 `.srcs/constrs_1/imports/04_pin/fpga_pin.xdc`。
3. 检查 `rtl/proj_snn.vh` 中已启用 `` `define UNET ``，保持本提交的 U-Net 参数。工程同时保留 SegNet 相关文件，本流程使用 U-Net 的硬件配置、权重与输入。
4. 检查 Sources 中无缺失文件。若需要重新生成 IP 输出文件，使用 **Generate Output Products**；U-Net 使用的 `unet_control` 初始化文件为 `file/coe/unet/SNNUnet_control_200-200_no_cat.coe`，`dram_bias_ram` 初始化文件为 `file/coe/unet/biases_10_28_fpga.coe`。迁移路径后如提示找不到 COE，请在对应 IP 配置中重新指定这两个文件并生成输出。
5. 在 Flow Navigator 中依次执行 **Run Synthesis → Run Implementation → Generate Bitstream**，等待各阶段完成。当前工程活动综合任务名为 `serial`，实现任务名为 `impl_3`。重新从源码编译时，可先在 Design Runs 中对相应任务执行 **Reset Run**，再启动构建。
6. 在实现结果中检查时序和 DRC 报告，确认位流生成成功。按当前任务配置，生成文件通常位于 `udp_loop_axu15egb.runs/impl_3/snn_top.bit`。

### 步骤三：下载 FPGA 位流

1. 为开发板上电，并通过 JTAG 将开发板连接到 PC。
2. 在 Vivado 中打开 **Hardware Manager → Open Target → Auto Connect**。
3. 选择目标器件，点击 **Program Device**，选择步骤二生成的 `snn_top.bit` 并下载。
4. 等待下载完成及 DDR4 初始化完成后，再进行数据传输。

提交材料也提供 `file/bitstream/unet/snn_top.bit`，可直接下载用于 U-Net 演示。请选择 U-Net 位流，与后续权重和输入配套使用。

### 步骤四：连接网线并配置 IP 地址

使用网线将 PC 有线网口连接到 FPGA 工程所使用的 **PL 侧以太网口**，并在 Windows 的该以太网适配器 IPv4 属性中配置静态地址：

| 参数           | PC                | FPGA               |
| -------------- | ----------------- | ------------------ |
| IPv4 地址      | `192.168.137.1` | `192.168.137.2`  |
| 子网掩码       | `255.255.255.0` | 与 PC 位于同一子网 |
| UDP 端口       | `6001`          | `6002`           |
| 默认网关 / DNS | 直连网卡留空      | 由硬件逻辑处理     |

PC 的绑定地址写在 `pc_python/socket/send2fpga_class.py` 中；FPGA 的本机及目标 IP、端口写在 `rtl/eth/eth_top.v` 中，下载位流后生效。保持上表配置即可使用，无需修改代码。

可在 PowerShell 中执行以下命令辅助检查连通性：

```powershell
ping 192.168.137.2
```

确保防火墙允许当前 Python 程序通过该网卡收发 UDP，且 PC 的 `6001` 端口未被其他程序占用。若选择 DeepSeek 云端分析，PC 还需保留一条可访问互联网的网络连接；FPGA 直连网卡保持以上静态配置。

### 步骤五：启动 GUI 并配置 AI 服务

在工程根目录、已激活的 Conda 环境中执行：

```powershell
conda activate fpga-snn
python .\pc_python\socket\GUI_send2fpga.py
```

界面打开后，在下方“AI 助手”中选择一种服务：

**方式 A：DeepSeek 云端**

- 选择“DeepSeek 云端”。
- 在 `API Key` 输入框填写自己的 DeepSeek 密钥，也可通过启动 GUI 前设置的 `DEEPSEEK_API_KEY` 环境变量提供。
- 服务地址默认读取代码配置 `https://api.deepseek.com`，模型字段默认读取 `deepseek-flash`。如账户使用其他模型名称，可在界面填写该账户实际可用的模型。

**方式 B：Ollama 本地模型**

安装 Ollama 后，先在终端下载代码默认使用的模型：

```powershell
ollama pull qwen2.5:0.5b
```

确保 Ollama 服务已运行；若尚未启动，可在另一个终端执行 `ollama serve` 并保持运行。然后在 GUI 中选择“Ollama 本地”，服务地址填写 `http://127.0.0.1:11434`，模型填写 `qwen2.5:0.5b`，无需 API Key。也可填写已安装的其他本地模型名称。

界面默认启用“每5秒自动 AI 分析当前帧”，在接收结果后进行分析；也可取消勾选，手动点击“分析当前热场”。AI 服务暂不可用时，可关闭自动分析继续验证 FPGA 重建流程。

### 步骤六：选择权重、输入并开始运行

1. 点击左侧 **“选择网络权重”**，选择：

   ```text
   file\weight\unet_weights_reverse.txt
   ```
2. 点击 **“选择测温数据”**，选择以下**文件夹**：

   ```text
   file\input_example\reversed_data\unet
   ```
3. 确认位流已下载、网络已配置，点击 **“开始 FPGA 重建”**。
4. 上位机依次发送网络权重和各样本编码数据，接收 FPGA 输出，并读取对应 MAT 文件完成对比。整批任务执行期间请等待结果接收完成。
5. 状态显示“结果已接收”后，查看稀疏观测、重建热场、参考热场及重建指标。当前默认每秒轮播一帧，样本编号与处理信息可在界面和“运行日志”中查看；AI 助手可结合当前显示样本进行分析。

重建热场与参考热场使用相同色域，黑色表示该色域中的低值。界面的“末帧接收耗时”从末帧输入发送完成后开始计时，“整批任务频率”为整批任务总耗时的倒数，包含权重下发、通信和数据处理，不等同于单帧硬件推理吞吐率。
