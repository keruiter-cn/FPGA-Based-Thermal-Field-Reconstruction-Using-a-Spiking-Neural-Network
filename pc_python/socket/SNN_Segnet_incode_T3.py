import os
import gc
#import cv2
import torch
import random
import argparse
import datetime
import numpy as np
from tqdm import tqdm
from torch import optim
#from conversion import Parser
from our_snntorch_segnet_vth_0999_train_static_coding_in_32_layer_16_1_min_outc_1 import SNN_SegNet

#from Unet_model_add_relu1_without_bias import *
import matplotlib.pyplot as plt
import torch.nn as nn
import snntorch as snn
from snntorch import utils

#from fuse_bn_into_conv import fuse_bn_into_conv
#import simulation  # 模拟脉冲神经网络（SNN）的性能，并计算相关指标
#from BN_conversion import BN_conversion
# from snn.tools.file_tools import check_exist_makedirs  用于确保目录存在
from DRIVE_dataset_2_fpath import DRIVE_dataset, load_matfile # 导入数据集
from torchvision.transforms import transforms
from torch.utils.data import DataLoader

x_transforms = transforms.Compose([
transforms.ToTensor(), transforms.Normalize([0], [1])])

y_transforms = transforms.Compose([
transforms.ToTensor(), transforms.Normalize([0], [1])])

def recursive_reset(module):
    # 先调用 utils.reset 重置当前模块
    utils.reset(module)
    # 递归遍历并重置子模块
    for submodule in module.children():
        recursive_reset(submodule)

def append_tensor_to_file(tensor, file_path):
    """
    将形状为 torch.Size([200, 200]) 的张量数据追加到一个文本文件中。
    参数:
    tensor (torch.Tensor): 形状为 [ 200, 200] 的张量。
    file_path (str): 文本文件的路径。
    """
    if tensor.size() != (200, 200):
        raise ValueError("张量的形状必须为 [200, 200]")

    # 展平成一维并转换为整数
    flattened_tensor = tensor.view(-1).cpu().numpy().astype(int)

    # 以追加模式打开文件
    with open(file_path, "a") as f:
        for value in flattened_tensor:
            # 在每行前面插入31个0，并写入整数值
            f.write("0" * 7 + f"{value}\n")

def forward_pass(net, data, num_steps, device):

    print(data.shape)
    #data = data[:, : , 0:56, 0:56]

    spk_rec = []  # 记录多个时间步长的脉冲输出
    utils.reset(net)  # 重置/初始化所有 LIF 神经元的隐藏状态
    recursive_reset(net)  # 递归重置所有模块的状态
    count_ones = 0  # 用于统计 spk_rec 中 1 的数量
    for step in range(num_steps):  # 时间步长循环
        spk_out = net(data)  # 一个时间步长的前向传播
        tensor_squeezed = torch.squeeze(spk_out, dim=0)  # 移除第0个维度
        tensor_squeezed = torch.squeeze(tensor_squeezed, dim=0)  # 移除第1个维度
        spk_rec.append(tensor_squeezed)  # 记录脉冲输出
        # file_path = "D:/Research/Project/SNN_jss/top_pc_code/file/incode_Example0_Unet.txt"
        # append_tensor_to_file(spk_out, file_path)  # 存入txt
        # 统计当前 spk_out 中的 1 的数量
        count_ones += (spk_out == 1).sum().item()
        print(spk_out)
        print(spk_out.shape)
    print(f"Total number of 1s in spk_rec: {count_ones}")
    # outputs = torch.stack(spk_rec)
    # output = outputs.mean(dim=0)
    return spk_rec  # 将列表中的脉冲输出堆叠成一个张量


import torch
import torch.nn as nn
import math

def adjust_conv_and_deconv_weights(model, n): # 量化
    def find_power_of_two(value):
        power = 1
        while power < value:
            power *= 2
        return power

    def process_module(module , n):
        for name, sub_module in module.named_children():
            if isinstance(sub_module, (nn.Conv2d, nn.ConvTranspose2d)):
                p = 2 ** n
                # 获取卷积层的权重
                weight = sub_module.weight.data
                #print(weight.max())
                # 计算权重绝对值的最大值
                conv_max = weight.abs().max().item()
                # 找到大于conv_max的最小2的整数幂
                k = find_power_of_two(conv_max)
                print(name)
                print(k)
                power_k = int(math.log2(k))
                # 乘以2的k次幂
                weight *= (2 ** (n-1))
                weight /= (2 ** power_k)
                #print(weight.max())
                # 去除小数部分
                weight = weight.round().clamp(-(2 ** (n-1)), (2 ** (n-1))-1)
                # 除以2的k次幂，将权重缩放回来
                weight /= (2 ** (n-1))
                weight *= (2 ** power_k)
                # 更新卷积层的权重
                print(weight.max())
                sub_module.weight.data = weight

                if sub_module.bias is not None:
                    bias = sub_module.bias.data
                    # 计算偏置绝对值的最大值
                    bias_max = bias.abs().max().item()
                    # 找到大于bias_max的最小2的整数幂
                    k = find_power_of_two(bias_max)
                    print(f"{name} bias")
                    print(k)
                    power_k = int(math.log2(k))
                    # 乘以2的k次幂
                    bias *= (2 ** (n-1))
                    bias /= (2 ** power_k)
                    # 去除小数部分
                    bias = bias.round().clamp(-(2 ** (n-1)), (2 ** (n-1))-1)
                    # 除以2的k次幂，将偏置缩放回来
                    bias /= (2 ** (n-1))
                    bias *= (2 ** power_k)
                    # 更新卷积层的偏置
                    print(bias.max())
                    sub_module.bias.data = bias
            else:
                # 递归处理子模块
                process_module(sub_module, n)

    # 开始处理模型
    process_module(model , n)
    return model


def load_model_ignore_state(model, state_dict):
    model_dict = model.state_dict()

    # 过滤掉与模型不匹配的参数
    filtered_dict = {k: v for k, v in state_dict.items() if k in model_dict and model_dict[k].shape == v.shape}
    filtered_checkpoint = {k: v for k, v in filtered_dict.items() if "relu" not in k}
    filtered_checkpoint = {k: v for k, v in filtered_checkpoint.items() if "avgpool" not in k}

    # 更新模型参数
    model_dict.update(filtered_dict)
    model.load_state_dict(filtered_checkpoint, strict=False)

def check_exist_makedirs(path):
    if not os.path.exists(path):
        os.makedirs(path)

def evaluate(snn_model, test_dataloader, timesteps, device, test):
    MSE_LOSS = torch.nn.MSELoss()
    MAE_LOSS = torch.nn.L1Loss()
    snn_model.eval()
    test_loss_MSE = 0
    test_loss_MAE = 0
    #device = torch.device("cuda:2" if torch.cuda.is_available() else "cpu")
    snn_model.to(device)
    outputs = []

    #from SNN_set_train import simulator
    mae_loss = 0.0
    #simulator = simulator(timesteps=timesteps, dataset_name='DRIVE', path='.', logs_path='./logs',device=device)
    with torch.no_grad():
        for i, data in enumerate(test_dataloader):
            print("{:d} / {:d}".format(i, len(test_dataloader)))

            u_200, sensor_200  = data  # sensor在前
            u_200 = u_200.to(device)
            sensor_200 = sensor_200.to(device)

            output = forward_pass(snn_model, sensor_200, timesteps, device) # forward-pass
            print(output)
            print(output[0].shape)
            #output = outputs.mean(dim=0)  # 将时间步长的脉冲输出取平均作为最终输出(并到前向传播函数里去了)
            #output = simulator.simulate_for_sample_test(model=snn_model, data=sensor_200, timesteps=timesteps,device=device)
            #output = snn_model(sensor_200)

        # path1 = r'/home/haoranli/workspace/test/neuron_IF_static_coding_T3_vth099999_test_no_cat/code/'
        # check_exist_makedirs(path1)
        # torch.save(snn_model.state_dict(), "/home/haoranli/workspace/test/neuron_IF_static_coding_T3_vth099999_test_no_cat/code/snn_model_code.pth")

    return output


def code_one_mat(fpath,spath, device, timesteps):
    #pytorch_model.load_state_dict(state_dict, strict=False)
    #print(pytorch_model)
    #for key in state_dict.keys():
    #   print(key)
    for filepath,dirnames,filenames in os.walk(fpath):
        for filename in filenames:
            mat_path = filepath + filename
            test_dataset = DRIVE_dataset(
                    #r'/data_sata/XCIM_Group/haodongfan/workspace_haoran/1_data/dataset/data2/test/test/',
                    #r'/home/haoranli/workspace/conversion/Normal_dataset/test_data/Example0.mat',
                    mat_path,
                    train=False,
                    transform=x_transforms,
                    label_transform=y_transforms)

            snn_model = SNN_SegNet(1,1)
            snn_model_code = snn_model.code
            #recursive_initialize_weights(snn_model)
            #print(snn_model)
            #snn_model.apply(weights_init_xavier)
            # 微调后的Unet
            #snn_state_dict = torch.load('/data_sata/XCIM_Group/haodongfan/workspace_haoran/test/SNN_train/logs/DRIVE/robust/reset_by_zero/middle_D2/snn_model_with_vth_099_MSE_138.688524_16_.pth')
            # 训练的SNN
            snn_state_dict_code = torch.load("D:/Research/Project/SNN_jss/top_pc_code/code_all/snn_segnet_model_code.pth", map_location=device)
            #load_model_ignore_state(snn_model, model_dict)
            load_model_ignore_state(snn_model_code, snn_state_dict_code)

            #snn_model.load_state_dict(snn_state_dict, strict=False)
            #for key in snn_model.state_dict().keys():
                #print(key)
            #snn_model.load_state_dict(model_dict, strict=False)
            #normalize_conv_weights(snn_model) # 改权重最大值
            snn_model_code = adjust_conv_and_deconv_weights(snn_model_code, 16) # 量化
            test_dataloader = DataLoader(test_dataset, batch_size=1)
            #save_with_vth(snn_model, device)
            print(snn_model_code)
            #summary(snn_model, (1, 200, 200).to(device))
            #evaluate(snn_model, test_dataloader, timesteps, test=True)
            code = evaluate(snn_model_code, test_dataloader, timesteps, device, test=True)
            for i in range(len(code)):
                append_tensor_to_file(code[i],spath+'incode_segnet_'+filename.split('.')[0]+'.txt')
            print(code[0].shape)

    return code

device = torch.device('cuda:3' if torch.cuda.is_available() else 'cpu')
timesteps = 3
fpath = "D:\\Research\\Project\\SNN_jss\\top_pc_code\\test_file\\raw_data\\"
spath = "D:\\Research\\Project\\SNN_jss\\top_pc_code\\test_file\\incode_data\\segnet\\"
code = code_one_mat(fpath,spath, device, timesteps) # code是个张量列表，共timestep个张量，每个均为200*200，若要变回原数据类型，需要加298
print(code[0].shape)