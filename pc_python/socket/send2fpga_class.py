import socket
import os
import numpy as np
import torch
import time
from datetime import datetime, timezone
from uuid import uuid4
import matplotlib.pyplot as plt
from torchvision.transforms import transforms
from torch.utils.data import DataLoader
from DRIVE_dataset_2_fpath import DRIVE_dataset


class UDPImageClient:
    def __init__(self,
                 file_path,
                 server=False,
                 send_num=512,
                 img_width=200,
                 img_height=200,
                 pixel_size=4,
                 txtfile_weight_path=None,
                 txtfile_image_path=None):
        """
        UDP 图像通信客户端类

        参数:
            file_path (str): 工程根路径
            server (bool): 是否为服务器模式
            send_num (int): 每次发送的字节数
            img_width (int): 图像宽度
            img_height (int): 图像高度
            pixel_size (int): 每个像素占用字节数
            txtfile_weight_path (str): 权重文件所在路径
            txtfile_image_path (str): 图像输入txt文件路径
        """
        # === 基本路径 ===
        self.file_path = file_path
        self.save_fig_path = os.path.join(file_path, 'file/save_image/')
        # self.txtfile_weight_path = txtfile_weight_path or os.path.join(file_path, 'file/weight/')
        self.txtfile_weight_path = txtfile_weight_path
        # self.txtfile_image_path = txtfile_image_path or os.path.join(file_path, 'file/input_example/reversed_data/')
        self.txtfile_image_path = txtfile_image_path

        # === UDP相关 ===
        self.SERVER = server
        self.SEND_NUM = send_num
        self.IMG_WIDTH = img_width
        self.IMG_HEIGHT = img_height
        self.PIXEL_SIZE = pixel_size
        self.TOTAL_DATA_SIZE = img_width * img_height * pixel_size
        self.buffer = bytearray()

        # === 初始化socket ===
        self.udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.configure_socket()

        # === 数据集transform ===
        self.x_transforms = transforms.Compose([
            transforms.ToTensor(), transforms.Normalize([0], [1])
        ])
        self.y_transforms = transforms.Compose([
            transforms.ToTensor(), transforms.Normalize([0], [1])
        ])

    # ----------------------------------------------------------------------
    def configure_socket(self):
        """配置UDP套接字"""
        recv_buff = self.udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
        send_buff = self.udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
        print(f'默认接收缓冲区大小：{recv_buff}，默认发送缓冲区大小：{send_buff}')

        self.udp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 100000000)
        recv_buff = self.udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
        send_buff = self.udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
        print(f'修改后接收缓冲区大小：{recv_buff}，默认发送缓冲区大小：{send_buff}')

        if self.SERVER:
            self.source_addr = ('113.54.153.22', 6001)
            self.dest_addr = ('120.48.161.177', 6002)
        else:
            self.source_addr = ('192.168.137.1', 6001)
            self.dest_addr = ('192.168.137.2', 6002)

        self.udp_socket.bind(self.source_addr)
        self.udp_socket.settimeout(1)
        print(f"绑定UDP地址：{self.source_addr}")

    # ----------------------------------------------------------------------
    def send_txt_data(self, file_path):
        """发送TXT数据"""
        with open(file_path, 'r', encoding='ascii') as file:
            payload = bytes.fromhex(file.read())
        # SEND_NUM is the historical number of hex characters, not bytes.
        packet_bytes = self.SEND_NUM // 2
        if packet_bytes <= 0 or self.SEND_NUM % 2:
            raise ValueError("send_num 必须是正偶数")
        for offset in range(0, len(payload), packet_bytes):
            self.udp_socket.sendto(payload[offset:offset + packet_bytes], self.dest_addr)

        print(f"[发送完成] {file_path}")

    # ----------------------------------------------------------------------
    def recv_txt_data(self):
        """接收TXT数据"""
        data_rev = bytearray()
        for offset in range(0, self.TOTAL_DATA_SIZE, 1280):
            try:
                data, _ = self.udp_socket.recvfrom(65535)
            except socket.timeout:
                print("接收超时！")
                return False, None, None
            expected = min(1280, self.TOTAL_DATA_SIZE - offset)
            if len(data) != expected:
                raise ValueError(f"FPGA 回包长度异常：需要 {expected} 字节，实际 {len(data)} 字节；请重新下载位流后重试")
            data_rev.extend(data)
            print(f"接收第{offset // 1280}个数据包")

        time_end = time.time()
        # pe.v and bram_write_control.v transmit the full signed 32-bit
        # accumulator, low byte first. Subtracting 2**26 turns negative
        # accumulators into values near 688000 after temperature scaling.
        words = np.frombuffer(data_rev, dtype='<i4')
        print(f"回包累加值范围：{words.min()} ~ {words.max()}，负数像素：{(words < 0).sum()}")
        data_rev = words.astype(np.float64).reshape(self.IMG_HEIGHT, self.IMG_WIDTH) / 3 / 4096
        data_rev = torch.tensor(data_rev)

        return True, data_rev, time_end

    def close(self):
        self.udp_socket.close()

    # ----------------------------------------------------------------------
    def send_weight(self, net_name):
        """发送权重文件"""
        # file_path_weight = os.path.join(self.txtfile_weight_path, f"{net_name}_weights_reverse.txt")
        file_path_weight = self.txtfile_weight_path
        self.send_txt_data(file_path_weight)
        print(f"[{net_name}] 权重文件发送完成")

    # ----------------------------------------------------------------------
    def send_image(self, net_name):
        """发送图像数据并计算误差"""
        # fig, axs = plt.subplots(1, 3)
        # image_dir = os.path.join(self.txtfile_image_path, net_name)
        image_dir = self.txtfile_image_path
        batch_id = uuid4().hex
        self.frame_metadata = []
        received_count = 0
        sensor_200_combined = torch.empty(0, 200, 200)
        data_rev_combined = torch.empty(0, 200, 200)
        u_200_combined = torch.empty(0, 200, 200)

        for root, _, files in os.walk(image_dir):
            total_mae, total_mre = 0, 0

            for index, filename in enumerate(files):
                txt_path = os.path.join(root, filename)
                success = False

                while not success:
                    self.send_txt_data(txt_path)
                    time_start = time.time()
                    success, data_rev, time_end = self.recv_txt_data()
                    if not success:
                        raise TimeoutError("FPGA 接收超时，当前无帧序号协议，不能直接重发；请重新下载位流后重试")
                    time_sum = time_end - time_start
                    print(f"单次耗时：{time_end - time_start:.4f}s")

                # 对比结果
                num_str = ''.join([c for c in filename if c.isdigit()])
                u200_path = os.path.join(self.file_path, f'file/output_compare/Example{num_str}.mat')
                test_dataset = DRIVE_dataset(
                    u200_path, train=False,
                    transform=self.x_transforms,
                    label_transform=self.y_transforms
                )
                u_200 = torch.tensor(test_dataset.u200.squeeze(), dtype=torch.float32)
                sensor_200 = torch.tensor(test_dataset.sensor200.squeeze(), dtype=torch.float32)

                data_rev = data_rev * 2 + 298
                u_200 = u_200 + 298

                relative_errors = torch.abs(data_rev - u_200) / torch.abs(u_200)
                mean_relative_error = torch.mean(relative_errors)
                total_mre += mean_relative_error.item()

                mae = torch.nn.L1Loss()(u_200, data_rev)
                total_mae += mae.item()

                avg_mae = total_mae / (index + 1)
                avg_mre = total_mre / (index + 1)

                print(f"文件[{filename}] → MRE: {mean_relative_error:.4f}, MAE: {mae:.4f}")
                print(f"平均MAE: {avg_mae:.4f}, 平均MRE: {avg_mre:.4f}")

                # 绘图保存
                # vmin, vmax = min(torch.min(data_rev).item(), torch.min(u_200).item()), \
                #              max(torch.max(data_rev).item(), torch.max(u_200).item())
                # norm = plt.Normalize(vmin=vmin, vmax=vmax)
                #
                # plt.clf()
                # plt.subplot(1, 3, 2)
                # plt.imshow(data_rev, cmap='hot', origin='lower', norm=norm)
                # plt.colorbar()
                # plt.title('Predicted')
                #
                # plt.subplot(1, 3, 3)
                # plt.imshow(u_200, cmap='hot', origin='lower', norm=norm)
                # plt.colorbar()
                # plt.title('Ground Truth')
                #
                # # plt.suptitle(f"MRE={mean_relative_error*100:.3f}%, MAE={mae:.6f}")
                # plt.savefig(os.path.join(self.save_fig_path, f"img_predicted_{num_str}.jpg"))
                # plt.pause(0.01)
                sensor_200_combined = torch.cat([sensor_200.unsqueeze(0), sensor_200_combined], dim=0)
                data_rev_combined = torch.cat([data_rev.unsqueeze(0), data_rev_combined], dim=0)
                u_200_combined = torch.cat([u_200.unsqueeze(0), u_200_combined], dim=0)
                received_count += 1
                # Match the existing reversed display order of the three arrays.
                # This is a host-side association, not a board-verified frame ID.
                self.frame_metadata.insert(0, {
                    'batch_id': batch_id,
                    'frame_id': f'{batch_id}:{received_count}',
                    'sample_id': f'Example{num_str}',
                    'input_file': os.path.relpath(txt_path, image_dir),
                    'reference_file': os.path.basename(u200_path),
                    'receive_index': received_count,
                    'received_at': datetime.now(timezone.utc).isoformat(),
                    'identity_source': 'host_receive_order',
                })


        print(f"[{net_name}] 图像测试完成 ✅")
        page_num = received_count

        return sensor_200, data_rev, u_200, mae, mean_relative_error, time_sum, page_num, sensor_200_combined, data_rev_combined, u_200_combined


# ----------------------------------------------------------------------
# 使用示例
if __name__ == "__main__":
    client = UDPImageClient(
        file_path=r"D:\Research\Competition\FPGA2024\workspace_snn",
        txtfile_weight_path=r"D:\Research\Competition\FPGA2024\workspace_snn\file/weight/unet_weights_reverse.txt",
        txtfile_image_path=r"D:\Research\Competition\FPGA2024\workspace_snn\file/input_example/reversed_data/unet/",
        server=False
    )
    client.send_weight("unet")
    client.send_image("unet")
