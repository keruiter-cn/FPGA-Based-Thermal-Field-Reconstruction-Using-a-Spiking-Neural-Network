import socket
import os
import numpy as np
import math
import binascii
import torch
import time
# SERVER=True
SERVER=False
SEND_NUM = 512
# 定义图片大小和每个像素点的字节数
IMG_WIDTH, IMG_HEIGHT = 200, 200
PIXEL_SIZE = 4  # 32位对应bytes
# 计算所需的总数据量
TOTAL_DATA_SIZE = IMG_WIDTH * IMG_HEIGHT * PIXEL_SIZE
buffer = bytearray()
# 查看默认发送接收缓冲区大小


udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)#这是地址族参数，指定了套接字的地址类型。AF_INET代表IPv4地址，用于创建基于IPv4的套接字。这是套接字类型参数，指定了套接字的通信协议。SOCK_DGRAM表示使用UDP协议，UDP是一种无连接的协议，适用于需要快速传输但可以容忍一定数据丢失的应用场景。

recv_buff = udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
send_buff = udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
print(f'默认接收缓冲区大小：{recv_buff}。默认发送缓冲区大小：{send_buff}')
udp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 655360)
recv_buff = udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
send_buff = udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
print(f'修改后接收缓冲区大小：{recv_buff}。默认发送缓冲区大小：{send_buff}')

host = socket.gethostname()
port=1234
if SERVER:
    source_addr = '113.54.153.22'  # des ip, des port   服务器的IP地址 ，端口号  服务器监听的IP地址
    dest_addr = '120.48.161.177'  # des ip, des port    客户端的IP地址，端口号 服务器将要发送数据到的客户端的IP地址
else:
    source_addr = ('192.168.137.1',6001)  #des ip, des port  source_addr是客户端的IP地址
    dest_addr = ('192.168.137.2',6002)  # des ip, des port     dest_addr是客户端将要发送数据到的服务器的IP地址,地址不清楚怎么确定
udp_socket.bind(source_addr)  # 绑定地址和端口号
# 输出文件路径


def sent_txt_data(file_path,udp_socket,dest_addr,SEND_NUM):
    file= open(file_path)
    lines=file.readlines()
    line = lines[0]
    line_list = list(lines[0])
    line_num=len(line_list)
    repeat_num = math.ceil(line_num/SEND_NUM)
    for i in range(repeat_num):
        line_send=line[i*SEND_NUM:(i+1)*SEND_NUM]
        line_int= int(line_send,16)
        line_byte= line_int.to_bytes(int(SEND_NUM/2),'big')
        udp_socket.sendto(line_byte,dest_addr)
        # print(i)
    print("Sent done")
    file.close()
#计算运行时间长度

txtfile_weight = "D:\System\Desktop\workspace_snn\pc_python\socket\data_to_fpga\weights_new_re.txt"
txtfile_image = "D:\System\Desktop\workspace_snn\pc_python\socket\data_to_fpga\incode_Example0_Unet_nocat_haodong_re.txt"
output_file = 'D:/System\Desktop\workspace_snn\socket/data_to_fpga/received_data.txt'
# sent_txt_data(txtfile_weight,udp_socket,dest_addr,SEND_NUM)
sent_txt_data(txtfile_image,udp_socket,dest_addr,SEND_NUM)
time_start = time.time() 
recv_buff = udp_socket.getsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF)
print("Buffer size: {}".format(recv_buff))

try:
    data_rev = b''
    for i in range(125):
        data, _ = udp_socket.recvfrom(1280)
        data_rev = data_rev + data[0:1280]
        # data_rev.append(data[0:800])
        # data_rev.append(data[800:1600])
        # if(i==1 or i==0 or i == 124):
            # hex_string = binascii.hexlify(data).decode('utf-8')
            # print("Received {} packets, data is {}. \n".format(i, hex_string))
        # print("Received {} packets. \n".format(i))
    #slice data every 4 bytes and convert bytes to int
    data_rev=np.frombuffer(data_rev,dtype=np.int32)/3
    data_rev.resize(200,200)
    time_end = time.time()
    time_sum = time_end - time_start
    # print(type(data_rev))
    hex_data = binascii.hexlify(data_rev)
    print(hex_data[0:8])
    test = int.from_bytes(data_rev[0:4],'little')
    print(test,type(test))
    data_int = [[int.from_bytes(data_rev[i][j:j+4],'little') for j in range(0, 800, 4)] for i in range(125)]/3
    data_tensor =  torch.tensor(data_int)
    time_sum = time_end - time_start
    print("Cost time is {}.".format(time_sum))
except KeyboardInterrupt:
    # 手动终止程序
    print("Shutting down the server.")
finally:
    udp_socket.close()





