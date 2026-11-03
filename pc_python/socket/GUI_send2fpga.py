import sys
import os
import time
import json
from copy import deepcopy
from uuid import uuid4
try:
    import torch
    import torch.nn.functional as F
    TORCH_ERROR = None
except (ImportError, OSError) as exc:
    torch = None
    F = None
    TORCH_ERROR = str(exc)
from PyQt5.QtWidgets import (
    QApplication, QWidget, QPushButton, QLabel, QFileDialog,
    QVBoxLayout, QHBoxLayout, QGridLayout, QTextEdit, QGroupBox,
    QLineEdit, QPlainTextEdit
)
from PyQt5.QtGui import QPixmap, QImage
from PyQt5.QtCore import Qt
from PyQt5.QtWidgets import QSizePolicy
from PyQt5.QtGui import QFont
from image_hot_generate import array_to_qpixmap_heatmap
from PyQt5.QtCore import QTimer, QObject, QThread, pyqtSignal
import numpy as np
from local_ai_client import (
    OllamaClient, DeepSeekClient, LocalAIError, build_result_context, RESULT_ANALYSIS_REQUEST,
    ASSISTANT_SYSTEM_PROMPT,
    DEFAULT_URL, DEFAULT_MODEL, DEEPSEEK_URL, DEEPSEEK_MODEL,
)
from dashboard_ui import build_dashboard

manual_opt = False


class AIWorker(QObject):
    finished = pyqtSignal(str)
    failed = pyqtSignal(str)

    def __init__(self, client, messages):
        super().__init__()
        self.client = client
        self.messages = messages

    def run(self):
        try:
            self.finished.emit(self.client.chat(self.messages))
        except LocalAIError as exc:
            self.failed.emit(str(exc))
        except Exception as exc:
            self.failed.emit(f"AI 请求失败: {exc}")

class SNNApp(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("基于SNN的高能效物理场求解加速器")
        self.setGeometry(100, 100, 1400, 800)
        self.file_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        self.txtfile_weight_path = ""
        self.txtfile_image_path = ""
        self.client = None
        self.fpga_running = False
        self.current_page = 0
        self.current_metrics = None
        self.ai_history = []
        self.frame_conversations = {}
        self.active_ai_request = None
        self.batch_id = uuid4().hex
        self.frame_metadata = []
        self.ai_thread = None
        self.ai_worker = None
        self.pending_auto_analyses = []
        self.auto_analyzed_frames = set()
        self.auto_ai_timer = QTimer(self)
        self.auto_ai_timer.setInterval(5000)
        self.auto_ai_timer.timeout.connect(self._periodic_auto_analysis)

        self.setup_ui()
        if TORCH_ERROR:
            self.status_label.setText("● 推理环境不可用")
            self.log_text.append("PyTorch 加载失败，FPGA 推理暂不可用：\n" + TORCH_ERROR)
            self.btn_run.setEnabled(False)
            self.btn_run.setToolTip(TORCH_ERROR)

    # ----------------------------------------------------------------------
    def setup_ui(self):
        build_dashboard(self, manual_opt)

    def on_ai_provider_changed(self):
        cloud = self.ai_provider_combo.currentData() == 'deepseek'
        self.ai_api_key_edit.setEnabled(cloud)
        if cloud:
            self.ai_url_edit.setText(os.getenv('DEEPSEEK_BASE_URL', DEEPSEEK_URL))
            self.ai_model_edit.setText(os.getenv('DEEPSEEK_MODEL', DEEPSEEK_MODEL))
        else:
            self.ai_url_edit.setText(os.getenv('SNN_AI_URL', DEFAULT_URL))
            self.ai_model_edit.setText(os.getenv('SNN_AI_MODEL', DEFAULT_MODEL))

    def log(self, text):
        """日志输出"""
        self.log_text.append(text)
        QApplication.processEvents()

    def _start_ai_request(self, messages):
        if self.ai_thread is not None:
            self.ai_chat.appendPlainText("[AI] 上一个请求尚未完成，请稍候。")
            return
        settings = {
            'base_url': self.ai_url_edit.text().strip(),
            'model': self.ai_model_edit.text().strip(),
        }
        if self.ai_provider_combo.currentData() == 'deepseek':
            client = DeepSeekClient(api_key=self.ai_api_key_edit.text().strip(), **settings)
        else:
            client = OllamaClient(**settings)
        self.ai_thread = QThread(self)
        self.ai_worker = AIWorker(client, messages)
        self.ai_worker.moveToThread(self.ai_thread)
        self.ai_thread.started.connect(self.ai_worker.run)
        self.ai_worker.finished.connect(self._on_ai_finished)
        self.ai_worker.failed.connect(self._on_ai_failed)
        self.ai_worker.finished.connect(self.ai_thread.quit)
        self.ai_worker.failed.connect(self.ai_thread.quit)
        self.ai_thread.finished.connect(self._clear_ai_worker)
        self.ai_send_button.setEnabled(False)
        self.ai_analyze_button.setEnabled(False)
        self.ai_thread.start()

    def _clear_ai_worker(self):
        if self.ai_worker is not None:
            self.ai_worker.deleteLater()
        if self.ai_thread is not None:
            self.ai_thread.deleteLater()
        self.ai_worker = None
        self.ai_thread = None
        self.ai_send_button.setEnabled(True)
        self.ai_analyze_button.setEnabled(True)
        if not self.ai_auto_analyze.isChecked():
            self.pending_auto_analyses.clear()
        elif self.pending_auto_analyses:
            metrics = self.pending_auto_analyses.pop(0)
            self._analyze_metrics(metrics, automatic=True)

    def _on_auto_analysis_toggled(self, enabled):
        if not enabled:
            self.auto_ai_timer.stop()
            self.pending_auto_analyses.clear()
            self.ai_auto_status_label.setText('自动检测已关闭')
        elif not self.fpga_running and self._calculate_metrics() is not None:
            self.auto_ai_timer.start()
            self.ai_auto_status_label.setText('每5秒检测当前帧')
        else:
            self.ai_auto_status_label.setText('等待重建结果')

    def _periodic_auto_analysis(self):
        """Sample the displayed frame without queueing requests behind a slow AI."""
        if not self.ai_auto_analyze.isChecked():
            self._on_auto_analysis_toggled(False)
            return
        if self.fpga_running:
            return
        if self.ai_thread is not None:
            self.ai_auto_status_label.setText('AI 正忙，本轮检测跳过')
            return
        metrics = self._calculate_metrics()
        if metrics is None:
            self.auto_ai_timer.stop()
            self.ai_auto_status_label.setText('等待重建结果')
            return
        frame_id = metrics['sample']['frame_id']
        if frame_id not in self.auto_analyzed_frames:
            self.auto_analyzed_frames.add(frame_id)
            self._analyze_metrics(metrics, automatic=True)
            self.ai_auto_status_label.setText('当前帧已提交，等待 AI 反馈')
        if getattr(self, 'displayed_page', 0) == self.page_num - 1:
            self.auto_ai_timer.stop()
            self.ai_auto_status_label.setText('已检测最后一帧；结果将在 AI 助手反馈')

    def _on_ai_finished(self, content):
        active = self.active_ai_request
        self.active_ai_request = None
        if active is None:
            self.ai_chat.appendPlainText("[AI] " + content)
            return
        history = (self.ai_history if active['frame_id'] is None else
                   self.frame_conversations.setdefault(active['frame_id'], []))
        history.extend([
            {'role': 'user', 'content': active['question']},
            {'role': 'assistant', 'content': content},
        ])
        del history[:-8]
        self.ai_chat.appendPlainText(f"[AI · {active['label']}] " + content)

    def _on_ai_failed(self, message):
        active = self.active_ai_request
        self.active_ai_request = None
        label = active['label'] if active else '通用对话'
        self.ai_chat.appendPlainText(f"[AI · {label}] " + message)

    def _frame_identity(self, page):
        if page < len(self.frame_metadata):
            sample = deepcopy(self.frame_metadata[page])
        else:
            sample = {
                'batch_id': self.batch_id,
                'frame_id': f'{self.batch_id}:display:{page + 1}',
                'sample_id': None,
                'input_file': None,
                'reference_file': None,
                'identity_source': 'display_index_only',
            }
        sample['display_index'] = page + 1
        return sample

    def _frame_label(self, metrics):
        if metrics is None:
            return '通用对话'
        sample = metrics['sample']
        name = sample.get('sample_id') or '未记录文件名'
        return f"{name} · 显示帧{sample['display_index']} · 批次{sample['batch_id'][:8]}"

    def _submit_context_request(self, question, metrics=None):
        # Snapshot both the facts and identity before the displayed frame changes.
        snapshot = deepcopy(metrics)
        frame_id = snapshot['sample']['frame_id'] if snapshot is not None else None
        history = self.ai_history if frame_id is None else self.frame_conversations.get(frame_id, [])
        system = ASSISTANT_SYSTEM_PROMPT
        if snapshot is not None:
            system = build_result_context(snapshot)
            self.current_metrics = snapshot
        self.active_ai_request = {
            'frame_id': frame_id,
            'label': self._frame_label(snapshot),
            'question': question,
            'metrics': snapshot,
        }
        messages = [{'role': 'system', 'content': system}] + deepcopy(history[-8:])
        messages.append({'role': 'user', 'content': question})
        self._start_ai_request(messages)

    def send_ai_message(self):
        if self.ai_thread is not None:
            self.ai_chat.appendPlainText("[AI] 上一个请求尚未完成，请稍候；输入内容已保留。")
            return
        message = self.ai_input.text().strip()
        if not message:
            return
        metrics = self._calculate_metrics()
        self.ai_input.clear()
        self.ai_chat.appendPlainText(f"[你 · {self._frame_label(metrics)}] " + message)
        self._submit_context_request(message, metrics)

    def _calculate_metrics(self):
        prediction_batch = getattr(self, "data_rev_combined", None)
        truth_batch = getattr(self, "u_200_combined", None)
        if prediction_batch is None or truth_batch is None:
            return None
        page = min(getattr(self, "displayed_page", 0), len(prediction_batch) - 1)
        def to_array(data):
            if hasattr(data, "detach"):
                data = data.detach().cpu().numpy()
            return np.asarray(data, dtype=np.float64).squeeze()
        pred = to_array(prediction_batch[page])
        truth = to_array(truth_batch[page])
        residual = pred - truth
        error = np.abs(residual)
        denominator = np.maximum(np.abs(truth), 1e-6)
        mre = float((error / denominator).mean())
        hotspot_index = np.unravel_index(np.argmax(pred), pred.shape)
        truth_hotspot_index = np.unravel_index(np.argmax(truth), truth.shape)
        error_index = np.unravel_index(np.argmax(error), error.shape)
        threshold = float(np.percentile(truth, 95))
        return {
            "sample": self._frame_identity(page),
            "shape": list(pred.shape),
            "pixel_count": int(pred.size),
            "mae": float(error.mean()),
            "mre": mre,
            "mre_percent": mre * 100,
            "rmse": float(np.sqrt(np.mean(np.square(residual)))),
            "mean_signed_error": float(residual.mean()),
            "prediction_min": float(pred.min()),
            "prediction_max": float(pred.max()),
            "truth_min": float(truth.min()),
            "truth_max": float(truth.max()),
            "max_error": float(error.max()),
            "max_error_position": [int(error_index[0]), int(error_index[1])],
            "prediction_hotspot": [int(hotspot_index[0]), int(hotspot_index[1])],
            "truth_hotspot": [int(truth_hotspot_index[0]), int(truth_hotspot_index[1])],
            "p95_truth_threshold": threshold,
            "prediction_pixels_above_truth_p95": int((pred >= threshold).sum()),
            "truth_pixels_above_truth_p95": int((truth >= threshold).sum()),
        }

    def analyze_current_result(self):
        if self.ai_thread is not None:
            self.ai_chat.appendPlainText("[AI] 上一个请求尚未完成，请稍候。")
            return
        metrics = self._calculate_metrics()
        if metrics is None:
            self.ai_chat.appendPlainText("[AI] 请先完成一次 FPGA 推理，再分析当前结果。")
            return
        self._analyze_metrics(metrics)

    def _analyze_metrics(self, metrics, automatic=False):
        metrics = deepcopy(metrics)
        metrics.setdefault('sample', self._frame_identity(getattr(self, 'displayed_page', 0)))
        label = self._frame_label(metrics)
        if automatic:
            self.ai_chat.appendPlainText(f"[自动分析 · {label}] 已采样当前帧指标，等待 AI 反馈。")
        self.ai_chat.appendPlainText(f"[指标 · {label}] " + json.dumps(metrics, ensure_ascii=False))
        self._submit_context_request(RESULT_ANALYSIS_REQUEST, metrics)

    def _auto_analyze_received_result(self):
        """Analyze the first displayed frame, then periodically sample playback."""
        if not self.ai_auto_analyze.isChecked():
            return
        metrics = self._calculate_metrics()
        if metrics is None:
            return
        self.auto_ai_timer.start()
        frame_id = metrics['sample']['frame_id']
        if frame_id in self.auto_analyzed_frames:
            return
        self.auto_analyzed_frames.add(frame_id)
        if self.ai_thread is not None:
            self.pending_auto_analyses[:] = [deepcopy(metrics)]
            self.ai_auto_status_label.setText('AI 正忙，首帧已保存；后续每5秒检测')
            self.ai_chat.appendPlainText(f"[自动分析 · {self._frame_label(metrics)}] AI 正忙，已保存此样本指标，等待当前请求结束。")
        else:
            self._analyze_metrics(metrics, automatic=True)
            self.ai_auto_status_label.setText('首帧已提交；后续每5秒检测')

    # ----------------------------------------------------------------------
    def select_weight_file(self):
        file_path, _ = QFileDialog.getOpenFileName(self, "选择权重TXT文件", "", "Text Files (*.txt)")
        if file_path:
            self.txtfile_weight_path = file_path
            self.weight_path_label.setText(os.path.basename(file_path))
            self.weight_path_label.setToolTip(file_path)
            self.log(f"选择权重文件：{file_path}")

    # ----------------------------------------------------------------------
    def select_data_folder(self):
        folder_path = QFileDialog.getExistingDirectory(self, "选择原始数据文件夹")
        if folder_path:
            self.txtfile_image_path = folder_path
            self.data_path_label.setText(os.path.basename(folder_path))
            self.data_path_label.setToolTip(folder_path)
            self.log(f"选择原始数据文件夹：{folder_path}")

    # ----------------------------------------------------------------------
    def next_img_opt(self):
        self._display_page(min(self.displayed_page + 1, self.page_num - 1))

    def last_img_opt(self):
        self._display_page(max(self.displayed_page - 1, 0))

    def run_process(self):
        if TORCH_ERROR:
            self.log("无法启动推理：" + TORCH_ERROR)
            return
        if self.fpga_running:
            return
        if not self.txtfile_weight_path or not self.txtfile_image_path:
            self.log("请先选择权重文件和编码数据文件夹。")
            return
        self.fpga_running = True
        self.auto_ai_timer.stop()
        self.pending_auto_analyses.clear()
        self.auto_analyzed_frames.clear()
        self.ai_auto_status_label.setText('等待本批重建结果')
        self.btn_run.setEnabled(False)
        self.status_label.setText("● 正在处理")
        if hasattr(self, "timer"):
            self.timer.stop()
        started_transfer = False
        try:
            from send2fpga_class import UDPImageClient
            self.client = UDPImageClient(
                file_path=self.file_path,
                txtfile_weight_path=self.txtfile_weight_path,
                txtfile_image_path=self.txtfile_image_path,
                server=False,
            )
            start_time = time.time()
            started_transfer = True
            self.client.send_weight("unet")
            result = self.client.send_image("unet")
            (_, _, _, _, _, time_sum, self.page_num,
             self.sensor_200_combined, self.data_rev_combined, self.u_200_combined) = result
            metadata = getattr(self.client, 'frame_metadata', None)
            self.frame_metadata = deepcopy(metadata) if isinstance(metadata, list) else []
            if self.frame_metadata and len(self.frame_metadata) != self.page_num:
                raise ValueError('样本身份记录与接收帧数不一致，不能绑定分析。')
            self.batch_id = self.frame_metadata[0]['batch_id'] if self.frame_metadata else uuid4().hex
            run_time = time.time() - start_time
            self.time_label.setText(f"末帧接收耗时：{time_sum:.4f} s")
            self.rate_label.setText(f"整批任务频率：{1.0 / run_time if run_time > 0 else 0.0:.3f} Hz")
            self.status_label.setText("● 结果已接收")
            self._display_page(0)
            self.current_page = 1
            metrics = self._calculate_metrics()
            self.log_text.append(
                f"接收完成，共 {self.page_num} 帧。首个显示帧："
                f"重建范围 {metrics['prediction_min']:.3f} ~ {metrics['prediction_max']:.3f}；"
                f"参考范围 {metrics['truth_min']:.3f} ~ {metrics['truth_max']:.3f}。"
                "两图共用色域，黑色不代表数值为零。"
            )
            self._auto_analyze_received_result()
            if not manual_opt:
                if not hasattr(self, "timer"):
                    self.timer = QTimer(self)
                    self.timer.timeout.connect(self.update_image)
                self.timer.start(1000)
        except Exception as exc:
            self.auto_ai_timer.stop()
            self.pending_auto_analyses.clear()
            self.ai_auto_status_label.setText('重建失败，自动检测已停止')
            self.status_label.setText("● 重建失败")
            self.log_text.append(f"重建失败：{exc}")
            if started_transfer:
                self.log_text.append("请重新下载位流并重启 GUI 后再测，避免重复权重或残留回包污染图像。")
        finally:
            if self.client is not None:
                self.client.close()
                self.client = None
            self.fpga_running = False
            self.btn_run.setEnabled(True)

    # ----------------------------------------------------------------------
    def get_latest_image(self, folder):
        """获取最新保存的图片"""
        imgs = [os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".jpg")]
        if not imgs:
            return None
        return max(imgs, key=os.path.getmtime)

    def _display_page(self, page):
        if not 0 <= page < self.page_num:
            return
        self.displayed_page = page
        metrics = self._calculate_metrics()
        sensor = self.sensor_200_combined[page]
        prediction = self.data_rev_combined[page]
        truth = self.u_200_combined[page]
        vmin = min(metrics["prediction_min"], metrics["truth_min"])
        vmax = max(metrics["prediction_max"], metrics["truth_max"])
        self.show_sensor_data(sensor, self.label_sensor, vmin=0, vmax=1, cmap='hot', origin='lower')
        self.show_sensor_data(prediction, self.label_pred, vmin=vmin, vmax=vmax, cmap='hot', origin='lower')
        self.show_sensor_data(truth, self.label_true, vmin=vmin, vmax=vmax, cmap='hot', origin='lower')
        self.refresh_dashboard_metrics()
        if (not self.fpga_running and self.ai_auto_analyze.isChecked()
                and metrics['sample']['frame_id'] not in self.auto_analyzed_frames
                and not self.auto_ai_timer.isActive()):
            self.auto_ai_timer.start()
            self.ai_auto_status_label.setText('每5秒检测当前帧')

    def update_image(self):
        if self.current_page < self.page_num:
            self._display_page(self.current_page)
            self.current_page += 1
        elif hasattr(self, "timer"):
            self.timer.stop()

    def closeEvent(self, event):
        self.auto_ai_timer.stop()
        if hasattr(self, 'timer'):
            self.timer.stop()
        self.pending_auto_analyses.clear()
        super().closeEvent(event)

    # ----------------------------------------------------------------------
    def show_result_images(self, image_path):
        """在界面中显示结果图片"""
        pixmap = QPixmap(image_path).scaled(400, 400, Qt.KeepAspectRatio)
        self.label_pred.setPixmap(pixmap)
        self.label_true.setPixmap(pixmap)
        self.label_sensor.setPixmap(pixmap)

    # def show_sensor_data(self, data, label):
    #     """
    #     data: numpy 数组 HxW 或 HxWxC (0~255 或浮点)
    #     """
    #     import numpy as np
    #
    #     if isinstance(data, np.ndarray):
    #         # 转为 uint8
    #         if data.dtype != np.uint8:
    #             data = (255 * (data - np.min(data)) / (np.max(data) - np.min(data) + 1e-8)).astype(np.uint8)
    #
    #         h, w = data.shape[:2]
    #         if data.ndim == 2:
    #             qimg = QImage(data.data, w, h, w, QImage.Format_Grayscale8)
    #         elif data.ndim == 3 and data.shape[2] == 3:
    #             qimg = QImage(data.data, w, h, 3*w, QImage.Format_RGB888)
    #         else:
    #             raise ValueError("不支持的 data 维度")
    #         pixmap = QPixmap.fromImage(qimg).scaled(label.width(), label.height(), Qt.KeepAspectRatio)
    #         label.setPixmap(pixmap)
    #         label.setAlignment(Qt.AlignCenter)
    #     else:
    #         # 如果 data 是路径或其他格式
    #         label.setText(str(data))

    def show_sensor_data(self, data, label, vmin=None, vmax=None, cmap='hot', origin='lower'):
        """
        在 QLabel 上显示 data 的热力图（类似 plt.imshow 的效果）。
        你可以把 vmin/vmax 传进来实现多图统一色域。
        """
        pixmap, vmin, vmax = array_to_qpixmap_heatmap(
            data, cmap_name=cmap, vmin=vmin, vmax=vmax, origin=origin
        )

        # 根据 label 尺寸做等比缩放（更清晰）
        if label.width() > 0 and label.height() > 0:
            pixmap = pixmap.scaled(label.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation)

        label.setPixmap(pixmap)
        # 如果你希望随着窗口变化自动缩放，可以：
        #   1) label.setScaledContents(True)  简单但会拉伸
        #   2) 在窗口的 resizeEvent 里再次 setPixmap(scaled(...)) 更精细

    # 创建高斯滤波器核（这里假设使用一个3x3的高斯核）


def gaussian_kernel(size, sigma):
    """生成一个高斯核"""
    kernel = torch.tensor(
        [[np.exp(-(x ** 2 + y ** 2) / (2 * sigma ** 2)) for x in range(-size // 2 + 1, size // 2 + 1)]
         for y in range(-size // 2 + 1, size // 2 + 1)])
    kernel /= kernel.sum()  # 归一化
    return kernel.unsqueeze(0).unsqueeze(0)  # 变成形状 (1, 1, size, size)
# ----------------------------------------------------------------------
if __name__ == "__main__":
    app = QApplication(sys.argv)
    win = SNNApp()
    win.show()
    sys.exit(app.exec_())
