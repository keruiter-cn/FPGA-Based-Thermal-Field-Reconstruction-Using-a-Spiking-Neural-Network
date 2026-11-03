import socket

import os
import numpy as np
import math
import binascii
import torch
import time
import matplotlib.pyplot as plt
from DRIVE_dataset_2_fpath import DRIVE_dataset, load_matfile # 导入数据集
from torchvision.transforms import transforms
from torch.utils.data import DataLoader


#file path
file_path = r'D:\workspace_snn/workspace_snn/'
#save fig path
save_fig_path = file_path + 'file/save_image/'
#load txt path
txtfile_weight_path = file_path + 'file/weight/'
txtfile_image_path = file_path + 'file/input_example/reversed_data/'



#load data
x_transforms = transforms.Compose([
transforms.ToTensor(), transforms.Normalize([0], [1])])

y_transforms = transforms.Compose([
transforms.ToTensor(), transforms.Normalize([0], [1])])

#udp 
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
udp_socket.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 100000000)
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
udp_socket.settimeout(1)   

#发送数据
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
    print("Sent done")
    file.close()
#接收数据

def recv_txt_data():
    data_rev = b''
    # udp_socket.settimeout(1)   
    for i in range(125):
        try:
            data, _ = udp_socket.recvfrom(1280)
            data_rev = data_rev + data[0:1280]
            success = 'True'
        except socket.timeout:
            success = 'False'
            print("Time out")
            return success , 0, 0

        print("Received {} packets.".format(i)) 
    time_end = time.time()
    data_rev_hex=data_rev.hex()
    data_bin_all = []
    data_int_all = []
    for i in range(0,len(data_rev_hex),8):
        single_hex = data_rev_hex[i:i+8]
        reversed_hex=''.join(single_hex[k:k+2] for k in range(8-2,-2,-2))
        data_bin = bin(int(reversed_hex,16))[2:]
        data_bin_all.append(data_bin)
        test = list(data_bin)
        if(len(list(data_bin))>=26):
            if(data_bin[0]=='1'):
                data_int = int(data_bin,2) - 67108864
        else:
            data_int = int(data_bin,2)
        data_int_all.append(data_int)
    data_rev = np.array(data_int_all)
    # data_rev=np.frombuffer(data_rev,dtype=np.int32)
    data_rev= data_rev/3
    data_rev = data_rev/(4096)
    data_rev.resize(200,200)
    data_rev = torch.tensor(data_rev)
    return success , data_rev, time_end
    
def sent_weight(net):

    file_path_weight = txtfile_weight_path + net + "_weights_reverse.txt"
    sent_txt_data(file_path_weight,udp_socket,dest_addr,SEND_NUM)
    print("Sent weight done")

def sent_image(net):
    fig, axs = plt.subplots(1, 2)
    for filepath, dirnames,filenames in os.walk(txtfile_image_path+net+"/"):
        print("filepath is {}".format(filepath))
        print("dirnames is {}".format(dirnames))
        total_mae = 0
        relative_errors_all = 0
        for index,filename in enumerate(filenames):
            print("filename is {}".format(filename))
            txtfile_image = os.path.join(filepath, filename)
            #发送数据

            sucess = 'False'
            while sucess == 'False':
                sent_txt_data(txtfile_image,udp_socket,dest_addr,SEND_NUM)
                time_start = time.time() 
                #接收数据
                sucess , data_rev ,time_end = recv_txt_data()
                time_sum = time_end - time_start
                print("Cost time is {}.".format(time_sum))

            #calculate mae of u-200 and data_rev
            #提取filename中的数字
            num_digital = ""
            for char in filename:
                if char.isdigit():
                    num_digital = num_digital + char
            #寻找对应的u-200
            u200_filepath = file_path + 'file/output_compare/Example'+num_digital+'.mat'
            #装载到dataloader
            test_dataset = DRIVE_dataset(
                u200_filepath,
                train=False,
                transform=x_transforms,
                label_transform=y_transforms)
            test_dataloader = DataLoader(test_dataset, batch_size=1)
            u_200 = torch.tensor(test_dataset.u200.squeeze(),dtype=torch.float32)
            # for i, data in test_dataloader:
            #     # print("{:d} / {:d}".format(i, len(test_dataloader)))
            #     u_200  = data
            #     u_200 = u_200.view(200,200)
            data_rev = data_rev*2

            # print(data_rev)
            # print(u_200)
            u_200 = u_200 + 298
            data_rev = data_rev + 298
            # 计算每个点的相对误差
            relative_errors = torch.abs(data_rev - u_200) / torch.abs(u_200)
            mean_relative_error = torch.mean(relative_errors)
            relative_errors_all += mean_relative_error.item()
            print("MRE is {}.".format(mean_relative_error.item()))

            mae = torch.nn.L1Loss()
            loss = mae(u_200, data_rev)
            print("MAE is {}.".format(loss))
            total_mae = total_mae + loss
            avg_mae = total_mae/(index+1)
            avg_mre = relative_errors_all/(index+1)
            print("Average MAE is {}.".format(avg_mae))
            print("Average MRE is {}.".format(avg_mre))
            # 计算两个数组的共同最小值和最大值
            vmin = min(torch.min(data_rev).item(), torch.min(u_200).item())
            vmax = max(torch.max(data_rev).item(), torch.max(u_200).item())

            # plt.close()  # 关闭当前图像，以便为下一个图像腾出空间
            # 使用共同的范围创建归一化对象
            norm = plt.Normalize(vmin=vmin, vmax=vmax)
            
            # plt.subplot(1, 2, 1)
            # plt.imshow(data_rev, cmap='hot',origin ='lower', norm = norm)
            # plt.colorbar(ticks=np.linspace(vmin, vmax, 5))  # 添加颜色条，显示每种颜色对应的数值
            # plt.title('img_predicted')
            # # plt.savefig(os.path.join(output_dir, name[0].replace('.mat', '') + 'pre.png' ))
            # # plt.close()  # 关闭当前图像，以便为下一个图像腾出空间
            # plt.subplot(1, 2, 2)
            # plt.imshow(u_200, cmap='hot',origin ='lower', norm = norm)
            # plt.colorbar(ticks=np.linspace(vmin, vmax, 5))  # 添加颜色条，显示每种颜色对应的数值
            # plt.title('img_u_200')
            # plt.subplots_adjust(wspace=0.5, hspace=0.3)
            # fig.text(0.5, 0.97, f"MRE = {mean_relative_error*100:.3f}%", ha='center', fontsize=16, va='top')
            # fig.text(0.5, 0.91, f"MAE = {loss.item():.8f}", ha='center', fontsize=16, va='top')
            # # fig.text(0.5, 0.91, f"MRE = {mean_relative_error*100:.3f}%, MAE = {test_loss_MAE_tensor:.8f}", ha='center', fontsize=16, va='top')
            # # fig.tight_layout()
            # plt.subplots_adjust(top=0.83, bottom=0.1, left=0.1, right=0.9)
            # plt.pause(0.01)
            # plt.savefig(save_fig_path + 'img_predicted_'+num_digital+'loss_'+str(loss.item())+'.jpg')
           

            # plt.clf()
            # # plt.suptitle("MAE Loss = "+str(loss.item()) , fontsize=20)
            # fig.text(0.5, 0.97, f"MRE = {mean_relative_error*100:.3f}%", ha='center', fontsize=16, va='top')
            # fig.text(0.5, 0.91, f"MAE = {loss.item():.8f}", ha='center', fontsize=16, va='top')
            #save image
            sensor_200 = test_dataset.sensor200
            # plt.subplot(1, 3, 1)
            # plt.imshow(sensor_200.reshape(200,200), cmap='hot',origin ='lower'), plt.axis("on")
            # # plt.colorbar(ticks=np.linspace(vmin, vmax, 5))  # 设置相同的刻度间隔
            # plt.title('sensor point')
            
            plt.subplot(1, 2, 1)
            # plt.tight_layout()
            plt.imshow(data_rev, cmap='hot',origin ='lower',norm = norm), plt.axis("on")
            plt.colorbar(ticks=np.linspace(vmin, vmax, 5))  # 设置相同的刻度间隔
            plt.title('img_predicted')
            # plt.colorbar()

            plt.subplot(1, 2, 2)
            # plt.tight_layout()
            img2 = plt.imshow(u_200, cmap='hot',origin ='lower',norm = norm), plt.axis("on")
            plt.colorbar(ticks=np.linspace(vmin, vmax, 5))  # 设置相同的刻度间隔
            plt.title('img_u_200')
            plt.subplots_adjust(wspace=0.5, hspace=0.3)
            # plt.colorbar()
            plt.subplots_adjust(wspace=0.5,hspace=0.3)
            # plt.show(block=False)   #显示
            plt.subplots_adjust(top=0.83, bottom=0.1, left=0.1, right=0.9)
            plt.pause(0.01)
            
            plt.savefig(save_fig_path + 'img_predicted_'+num_digital+'loss_'+str(loss.item())+'.jpg')
            

# sent_weight("segnet")
# sent_image("segnet")

sent_weight("unet")
sent_image("unet") 

# sent_weight("unet_new")
# sent_image("unet_new") 

# sent_weight("unet_new2")
# sent_image("unet_new2") 