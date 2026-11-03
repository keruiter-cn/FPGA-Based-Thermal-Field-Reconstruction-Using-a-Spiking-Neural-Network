"""Presentation layout for the existing FPGA client; no network calls here."""
import os
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QFont, QPixmap
from PyQt5.QtWidgets import (
    QApplication, QCheckBox, QComboBox, QFrame, QGroupBox, QHBoxLayout, QLabel, QLineEdit,
    QPlainTextEdit, QPushButton, QSizePolicy, QSplitter, QTabWidget,
    QTextEdit, QVBoxLayout, QWidget,
)


class HeatmapView(QLabel):
    """Retain the source image so resizing never stretches or crops a heatmap."""
    def __init__(self):
        super().__init__("暂无数据\n选择权重与数据后开始重建")
        self.source = QPixmap()
        self.setAlignment(Qt.AlignCenter)
        self.setMinimumSize(160, 180)
        self.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Expanding)
        self.setObjectName("heatmap")

    def setPixmap(self, pixmap):
        self.source = QPixmap(pixmap)
        self._fit()

    def _fit(self):
        if not self.source.isNull():
            super().setPixmap(self.source.scaled(
                self.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._fit()


STYLE = """
QWidget { font-family: 'Microsoft YaHei'; font-size: 14px; color: #243449; }
QWidget#dashboard { background: #f2f5f8; }
QFrame#sidebar { background: #172b40; border-radius: 14px; }
QFrame#sidebar QLabel { color: #c8d6e3; background: transparent; }
QFrame#sidebar QGroupBox { color: #ffffff; border-color: #36506a; background: #20374d; }
QFrame#sidebar QPushButton { background: #304b64; color: white; border-color: #426079; }
QFrame#sidebar QPushButton:hover { background: #3c607e; }
QFrame#sidebar QPushButton#primary { background: #10a59a; border: none; }
QFrame#sidebar QPushButton#primary:hover { background: #07897f; }
QGroupBox { background: white; border: 1px solid #e0e7ef; border-radius: 12px;
    margin-top: 16px; padding: 16px 12px 12px; font-weight: 600; }
QGroupBox::title { subcontrol-origin: margin; left: 14px; top: 2px; padding: 0 5px; }
QLabel#title { font-size: 26px; font-weight: 700; color: #172b40; }
QLabel#subtitle { color: #708197; font-size: 13px; }
QLabel#status { background: #e1f4f0; color: #087e71; border-radius: 12px; padding: 8px 16px; }
QLabel#heatmap { background: #f7f9fc; border: 1px dashed #d2dde8; border-radius: 8px; color: #8a9aad; }
QLabel#metric { font-size: 17px; font-weight: 600; color: #172b40; padding: 2px 3px; }
QLabel#path { font-size: 13px; padding: 6px 0; }
QLabel#section { font-size: 15px; font-weight: 600; }
QPushButton { background: #ffffff; border: 1px solid #d4dee9; border-radius: 7px;
    min-height: 20px; padding: 7px 12px; font-weight: 600; }
QPushButton:hover { background: #eaf4f5; border-color: #0e9b91; }
QPushButton:disabled { color: #9eaab7; background: #edf1f5; }
QPushButton#primary { background: #08988b; color: white; border: none; }
QLineEdit { background: white; border: 1px solid #d6e0ea; border-radius: 7px;
    min-height: 20px; padding: 6px; }
QComboBox { min-height: 24px; padding: 4px 6px; }
QLineEdit:focus { border-color: #08988b; }
QTextEdit, QPlainTextEdit { background: #f8fafc; border: 1px solid #e0e7ef;
    border-radius: 8px; padding: 6px; selection-background-color: #b5e6de; }
QTabWidget::pane { background: white; border: 1px solid #e0e7ef; border-radius: 10px; }
QTabBar::tab { background: transparent; color: #748499; padding: 9px 18px; }
QTabBar::tab:selected { color: #087e71; border-bottom: 3px solid #08988b; }
QSplitter::handle { background: transparent; height: 8px; width: 8px; }
"""


def box(title, parent_layout):
    widget = QGroupBox(title)
    layout = QVBoxLayout(widget)
    layout.setSpacing(8)
    parent_layout.addWidget(widget)
    return layout


def build_dashboard(ui, manual):
    ui.setObjectName("dashboard")
    ui.setWindowTitle("温度场重建 · FPGA 实验工作台")
    ui.resize(1440, 900)
    ui.setMinimumSize(1100, 740)
    ui.setFont(QFont("Microsoft YaHei", 11))
    ui.setStyleSheet(STYLE)
    root = QVBoxLayout(ui)
    root.setContentsMargins(24, 20, 24, 16)
    root.setSpacing(16)

    header = QHBoxLayout()
    titles = QVBoxLayout()
    title = QLabel("温度场重建工作台")
    title.setObjectName("title")
    subtitle = QLabel("FPGA  /  脉冲神经网络  /  稀疏测温与热场分析")
    subtitle.setObjectName("subtitle")
    titles.addWidget(title)
    titles.addWidget(subtitle)
    header.addLayout(titles)
    header.addStretch()
    ui.status_label = QLabel("● 等待数据")
    ui.status_label.setObjectName("status")
    ui.status_label.setToolTip("此状态表示任务进度，不表示 FPGA 连接已验证。")
    header.addWidget(ui.status_label)
    root.addLayout(header)

    body = QHBoxLayout()
    body.setSpacing(18)
    sidebar = QFrame()
    sidebar.setObjectName("sidebar")
    sidebar.setFixedWidth(250)
    side = QVBoxLayout(sidebar)
    side.setContentsMargins(16, 20, 16, 20)
    brand = QLabel("SNN  /  FPGA")
    brand.setStyleSheet("font-size: 24px; font-weight: 700; color: white;")
    side.addWidget(brand)
    side.addWidget(QLabel("实验控制台"))
    config = box("01  输入配置", side)
    ui.btn_select_weight = QPushButton("选择网络权重")
    ui.btn_select_weight.clicked.connect(ui.select_weight_file)
    ui.weight_path_label = QLabel("尚未选择权重文件")
    ui.weight_path_label.setObjectName("path")
    ui.weight_path_label.setWordWrap(True)
    ui.btn_select_data = QPushButton("选择测温数据")
    ui.btn_select_data.clicked.connect(ui.select_data_folder)
    ui.data_path_label = QLabel("尚未选择数据文件夹")
    ui.data_path_label.setObjectName("path")
    ui.data_path_label.setWordWrap(True)
    for w in (ui.btn_select_weight, ui.weight_path_label, ui.btn_select_data, ui.data_path_label):
        config.addWidget(w)
    control = box("02  重建任务", side)
    ui.btn_run = QPushButton("开始 FPGA 重建")
    ui.btn_run.setObjectName("primary")
    ui.btn_run.clicked.connect(ui.run_process)
    control.addWidget(ui.btn_run)
    if manual:
        row = QHBoxLayout()
        ui.last_img = QPushButton("上一帧")
        ui.next_img = QPushButton("下一帧")
        ui.last_img.clicked.connect(ui.last_img_opt)
        ui.next_img.clicked.connect(ui.next_img_opt)
        row.addWidget(ui.last_img)
        row.addWidget(ui.next_img)
        control.addLayout(row)
    ui.page_label = QLabel("当前帧  — / —")
    control.addWidget(ui.page_label)
    side.addStretch()
    body.addWidget(sidebar)

    split = QSplitter(Qt.Vertical)
    upper = QWidget()
    upper_layout = QHBoxLayout(upper)
    upper_layout.setContentsMargins(0, 0, 0, 0)
    upper_layout.setSpacing(14)
    fields = QGroupBox("热场可视化 / 数据对比")
    fields_layout = QVBoxLayout(fields)
    caption = QLabel("稀疏观测 → SNN 重建 → 参考真值")
    caption.setObjectName("subtitle")
    fields_layout.addWidget(caption)
    images = QHBoxLayout()
    images.setSpacing(10)
    for attr, name, description in (
        ("label_sensor", "01  稀疏观测", "传感器采样 / 归一化"),
        ("label_pred", "02  重建热场", "FPGA 推理输出"),
        ("label_true", "03  参考热场", "重建精度对比基准"),
    ):
        col = QVBoxLayout()
        label = QLabel(name)
        label.setObjectName("section")
        col.addWidget(label)
        view = HeatmapView()
        setattr(ui, attr, view)
        col.addWidget(view, 1)
        desc = QLabel(description)
        desc.setObjectName("subtitle")
        desc.setAlignment(Qt.AlignCenter)
        col.addWidget(desc)
        images.addLayout(col, 1)
    fields_layout.addLayout(images, 1)
    fields_layout.addWidget(QLabel("重建与真值使用同一色域 · 帧数据接收后自动展示"))
    upper_layout.addWidget(fields, 1)

    metrics = QGroupBox("重建指标")
    metrics.setFixedWidth(245)
    metrics_layout = QVBoxLayout(metrics)
    metrics_layout.setSpacing(6)
    for attr, text in (
        ("time_label", "运行时间：— s"), ("rate_label", "任务频率：—"),
        ("abs_err_label", "平均绝对误差：—"), ("rel_err_label", "平均相对误差：—"),
        ("rmse_label", "RMSE：—"), ("hotspot_label", "热点位置：—"),
        ("range_label", "重建范围：—"),
        ("truth_range_label", "参考范围：—"),
    ):
        label = QLabel(text)
        label.setWordWrap(True)
        label.setObjectName("metric")
        setattr(ui, attr, label)
        metrics_layout.addWidget(label)
    metrics_layout.addStretch()
    note = QLabel("数据就绪后更新指标\n任务频率按整批耗时计算")
    note.setObjectName("subtitle")
    note.setWordWrap(True)
    metrics_layout.addWidget(note)
    upper_layout.addWidget(metrics)
    split.addWidget(upper)

    tabs = QTabWidget()
    tabs.setMinimumHeight(320)
    ai = QWidget()
    ai_layout = QVBoxLayout(ai)
    ai_layout.setContentsMargins(14, 12, 14, 12)
    cfg = QHBoxLayout()
    ui.ai_provider_combo = QComboBox()
    ui.ai_provider_combo.addItem('DeepSeek 云端', 'deepseek')
    ui.ai_provider_combo.addItem('Ollama 本地', 'ollama')
    ui.ai_provider_combo.setCurrentIndex(max(0, ui.ai_provider_combo.findData(os.getenv('SNN_AI_PROVIDER', 'deepseek'))))
    cfg.addWidget(ui.ai_provider_combo)
    cfg.addWidget(QLabel("服务地址"))
    ui.ai_url_edit = QLineEdit()
    cfg.addWidget(ui.ai_url_edit)
    cfg.addWidget(QLabel("模型"))
    ui.ai_model_edit = QLineEdit()
    cfg.addWidget(ui.ai_model_edit)
    ui.ai_analyze_button = QPushButton("分析当前热场")
    ui.ai_analyze_button.clicked.connect(ui.analyze_current_result)
    cfg.addWidget(ui.ai_analyze_button)
    ai_layout.addLayout(cfg)
    key_row = QHBoxLayout()
    key_row.addWidget(QLabel('API Key'))
    ui.ai_api_key_edit = QLineEdit()
    ui.ai_api_key_edit.setEchoMode(QLineEdit.Password)
    ui.ai_api_key_edit.setPlaceholderText('DeepSeek API Key（留空时读取 DEEPSEEK_API_KEY）')
    ui.ai_api_key_edit.setToolTip('密钥仅用于本次会话，不写入工程文件。')
    key_row.addWidget(ui.ai_api_key_edit)
    ai_layout.addLayout(key_row)
    ui.ai_provider_combo.currentIndexChanged.connect(ui.on_ai_provider_changed)
    ui.on_ai_provider_changed()
    ui.ai_auto_analyze = QCheckBox("每5秒自动 AI 分析当前帧")
    ui.ai_auto_analyze.setChecked(True)
    ui.ai_auto_analyze.setToolTip("接收完成后分析首帧；轮播时每5秒抽取当前帧。同一帧只自动分析一次，AI 忙时跳过，最后一帧补查一次。云端模式会产生 API 调用。")
    ui.ai_auto_status_label = QLabel('等待重建结果')
    ui.ai_auto_status_label.setObjectName('subtitle')
    auto_row = QHBoxLayout()
    auto_row.addWidget(ui.ai_auto_analyze)
    auto_row.addWidget(ui.ai_auto_status_label)
    auto_row.addStretch()
    ai_layout.addLayout(auto_row)
    ui.ai_auto_analyze.toggled.connect(ui._on_auto_analysis_toggled)
    ui.ai_context_label = QLabel('提问对象：通用对话（尚无接收结果）')
    ui.ai_context_label.setWordWrap(True)
    ui.ai_context_label.setToolTip('提问绑定发送时显示的样本；每条回复保留原样本标签，翻帧不会改写正在进行的请求。')
    ai_layout.addWidget(ui.ai_context_label)
    ui.ai_chat = QPlainTextEdit()
    ui.ai_chat.setMinimumHeight(80)
    ui.ai_chat.setReadOnly(True)
    ui.ai_chat.setPlaceholderText("输入问题与所选 AI 服务对话，或点击“分析当前热场”解读误差与热点。")
    ai_layout.addWidget(ui.ai_chat, 1)
    entry = QHBoxLayout()
    ui.ai_input = QLineEdit()
    ui.ai_input.setPlaceholderText("例如：MAE 和 RMSE 分别反映什么？")
    ui.ai_input.returnPressed.connect(ui.send_ai_message)
    ui.ai_send_button = QPushButton("发送消息")
    ui.ai_send_button.setObjectName("primary")
    ui.ai_send_button.clicked.connect(ui.send_ai_message)
    entry.addWidget(ui.ai_input, 1)
    entry.addWidget(ui.ai_send_button)
    ai_layout.addLayout(entry)
    tabs.addTab(ai, "AI 助手")
    ui.log_text = QTextEdit()
    ui.log_text.setReadOnly(True)
    ui.log_text.setPlaceholderText("文件选择、运行状态与错误信息会显示在这里。")
    tabs.addTab(ui.log_text, "运行日志")
    split.addWidget(tabs)
    split.setSizes([440, 330])
    body.addWidget(split, 1)
    root.addLayout(body, 1)
    footer = QLabel("THERMAL FIELD RECONSTRUCTION   /   FPGA 实验工作台")
    footer.setObjectName("subtitle")
    root.addWidget(footer)

    def refresh_metrics():
        result = ui._calculate_metrics()
        if result:
            ui.abs_err_label.setText(f"平均绝对误差(MAE)：{result['mae']:.3f}")
            ui.rel_err_label.setText(f"平均相对误差(MRE)：{result['mre']:.6f}")
            ui.rmse_label.setText(f"RMSE：{result['rmse']:.4f}")
            ui.hotspot_label.setText(f"热点位置：{tuple(result['prediction_hotspot'])}")
            ui.range_label.setText(f"重建范围：\n{result['prediction_min']:.3f} ~ {result['prediction_max']:.3f}")
            ui.truth_range_label.setText(f"参考范围：\n{result['truth_min']:.3f} ~ {result['truth_max']:.3f}")
            ui.page_label.setText(f"当前帧  {getattr(ui, 'displayed_page', 0) + 1} / {getattr(ui, 'page_num', 1)}")
            sample = result['sample']
            if sample.get('sample_id'):
                ui.page_label.setText(ui.page_label.text() + f"\n样本：{sample['sample_id']}")
            ui.ai_context_label.setText(f"提问对象：{ui._frame_label(result)}（跟随当前显示样本）")
    ui.refresh_dashboard_metrics = refresh_metrics
