# 这个直接由Unet转SNN效果不错，每一层权重除以输出
from torch.nn import Module
from torch import nn
import torch
import sys
import torch.nn.functional as F
import snntorch as snn
import os
import numpy as np
from snntorch import surrogate

sys.path.append("/home/lihb/Github/bita_new_version")
#import snn.spiking_neuron as neuron
#import spiking_neuron_099_timestep1_inputs as neuron # 若内存泄露，可用T..._Train2和上一行应急

spike_grad = surrogate.atan(alpha=2) # fast sigmoid surrogate gradient

device = torch.device("cuda:3" if torch.cuda.is_available() else "cpu")

mem_min = -100

alpha = 2

def percentile_99(tensor, percentile=0.97):
    # 将张量展平为一维
    flattened_tensor = tensor.view(-1)
    
    # 对张量进行排序
    sorted_tensor = torch.sort(flattened_tensor).values
    
    # 计算百分位索引
    index = int(percentile * (sorted_tensor.numel() - 1))
    
    # 返回百分位数值
    return sorted_tensor[index]

class SNNUNet_haodong(nn.Module): # 在其他模型基础上前面加了个code层用于编码
    def __init__(self, n_channels, n_classes, bilinear=False):
        super(SNNUNet_haodong, self).__init__()
        self.n_channels = n_channels
        self.n_classes = n_classes
        self.bilinear = bilinear
        f_maps = 32

        self.code = nn.Sequential(nn.Conv2d(n_channels, n_channels, kernel_size=3, padding=1, bias = False),
                                  snn.Leaky(beta=1, threshold=0.999999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'))
        #nn.init.constant_(self.code[0].weight, 1) # 初始化为1

        self.inc = DoubleConv(n_channels, f_maps) #200
        self.down1 = Down(f_maps, f_maps * 2) #100
        self.down2 = Down(f_maps * 2, f_maps * 4) #50
        self.down3 = Down(f_maps * 4, f_maps * 8) #25
        factor = 2 if bilinear else 1
        self.down4 = Down(f_maps * 8, (f_maps * 16) // factor) # 12
        self.up1 = Up(f_maps * 16, (f_maps * 8) // factor, bilinear)
        self.up2 = Up(f_maps * 8, (f_maps * 4) // factor, bilinear)
        self.up3 = Up(f_maps * 4, (f_maps * 2) // factor, bilinear)
        self.up4 = Up(f_maps * 2, f_maps, bilinear)
        self.outc = OutConv(f_maps, n_classes)

        self.first_timestep = True  # 跟踪是否是第一个时间步

    def forward(self, x, timesteps):
        x = self.code(x)

        x1 = self.inc(x, timesteps)
        #print(x1.max())
        x2 = self.down1(x1, timesteps)
        #print(x2.max())
        x3 = self.down2(x2, timesteps)
        #print(x3.max())
        x4 = self.down3(x3, timesteps)
        #print(x4.max())
        x5 = self.down4(x4, timesteps)
        #print(x5.max())
        # x = self.up1(x5, x4, timesteps)
        # #print(x.max())
        # x = self.up2(x, x3, timesteps)
        # #print(x.max())
        # x = self.up3(x, x2, timesteps)
        # #print(x.max())
        # x = self.up4(x, x1, timesteps)
        #print(x.max())
        x = self.up1(x5, x4, timesteps)
        #print(x.max())
        x = self.up2(x, x3, timesteps)
        #print(x.max())
        x = self.up3(x, x2, timesteps)
        #print(x.max())
        x = self.up4(x, x1, timesteps)

        # positions = torch.nonzero(x == 1, as_tuple=True)
        # #torch.set_printoptions(threshold=torch.inf)
        # result = torch.stack((positions[1], positions[2], positions[3]))
        # resultT = result.t()
        # #print(resultT)
        # # 找出以 0 和 1 结尾的行
        # rows_with_01_ending = resultT[(resultT[:, -2] == 2) & (resultT[:, -1] == 2)]
        # # 打印这些行
        # print(rows_with_01_ending) # 这一坨用来看某个位置的神经元有没有激活

        logits = self.outc(x)
        #print(logits.max())

        self.first_timestep = False

        return logits


class DoubleConv(nn.Module):
    """(convolution => [BN] => ReLU) * 2"""

    def __init__(self, in_channels, out_channels, mid_channels=None):
        super().__init__()
        if not mid_channels:
            mid_channels = out_channels
        self.conv1 = nn.Conv2d(in_channels, mid_channels, kernel_size=3, padding=1, bias = False)
        self.relu1 = snn.Leaky(beta=1, threshold=0.999999, spike_grad=spike_grad, init_hidden=False ,reset_mechanism='zero')
        self.conv2 = nn.Conv2d(mid_channels, out_channels, kernel_size=3, padding=1, bias = False)
        self.relu2 = snn.Leaky(beta=1, threshold=0.999999, spike_grad=spike_grad, init_hidden=False,reset_mechanism='zero')

        self.mem1 = self.relu1.init_leaky().to(device)
        self.mem2 = self.relu2.init_leaky().to(device)

        self.row = []
        # self.double_conv = nn.Sequential(
        #    nn.Conv2d(in_channels, mid_channels, kernel_size=3, padding=1, bias=False),
        #    nn.BatchNorm2d(mid_channels),
        #    nn.ReLU(),
        #    nn.Conv2d(mid_channels, out_channels, kernel_size=3, padding=1, bias=False),
        #    nn.BatchNorm2d(out_channels),
        #    nn.ReLU()
        # )

    def forward(self, x, timesteps):
        #mem1 = self.relu1.init_leaky() # reset/init hidden states at t=0
        #mem2 = self.relu2.init_leaky() # reset/init hidden states at t=0
        if timesteps ==0 :
            self.mem1 = self.relu1.init_leaky().to(device)
            self.mem2 = self.relu2.init_leaky().to(device)
        
        self.mem1 = torch.clamp(self.mem1, min=mem_min) # 小于-1的赋值为-1
        self.mem2 = torch.clamp(self.mem2, min=mem_min) # 小于-1的赋值为-1

        x1 = self.conv1(x)
        #print(x1.max())
        x2, self.mem1 = self.relu1(x1, self.mem1)

        # mem1 = self.mem1.clone()
        # mem1 = percentile_99(mem1)
        # self.conv1.weight.data = self.conv1.weight.data/mem1 * alpha
        # print(self.conv1.weight.data.max())
        # count_ones = (x2 == 1).sum().item()
        # print(f"Total number of 1s in spk_rec: {count_ones}")


        #print(self.mem1[0,0:32,0,0])

        #dv = self.mem1.clone()
        #dv = dv * 2**14
        #print(dv[0,18,:,:])

        positions = torch.nonzero(x2 == 1, as_tuple=True)
        #torch.set_printoptions(threshold=torch.inf)
        result = torch.stack((positions[1], positions[2], positions[3]))
        resultT = result.t()
        #print(resultT)
        # 找出以 0 和 1 结尾的行
        rows_with_01_ending = resultT[(resultT[:, -2] == 0) & (resultT[:, -1] == 0)]
        # 打印这些行
        print(rows_with_01_ending) # 这一坨用来看某个位置的神经元有没有激活


        x3 = self.conv2(x2)
        #print(x3.max())
        x4, self.mem2 = self.relu2(x3, self.mem2)

        #self.conv2.weight.data = self.conv2.weight.data/self.mem2.max() * alpha
        # mem2 = self.mem2.clone()
        # mem2 = percentile_99(mem2)
        # self.conv2.weight.data = self.conv2.weight.data/mem2 * alpha
        print(self.conv2.weight.data.max())
        count_ones = (x4 == 1).sum().item()
        print(f"Total number of 1s in spk_rec: {count_ones}")



        # positions = torch.nonzero(x4 == 1, as_tuple=True)
        # #torch.set_printoptions(threshold=torch.inf)
        # result = torch.stack((positions[1], positions[2], positions[3]))
        # resultT = result.t()
        # #print(resultT)
        # # 找出以 0 和 1 结尾的行
        # rows_with_01_ending = resultT[(resultT[:, -2] == 2) & (resultT[:, -1] == 2)]
        # # 打印这些行
        # print(rows_with_01_ending) # 这一坨用来看某个位置的神经元有没有激活


        #print(x4)

        #self.mem2 = torch.clamp(self.mem2, min=mem_min) # 小于-1的赋值为-1
        #print(x4.max())
        # self.double_conv(x)
        return x4


class Down(nn.Module):
    """Downscaling with maxpool then double conv"""

    def __init__(self, in_channels, out_channels):
        super().__init__()
        self.avgpool = nn.AvgPool2d(2)
        #self.maxpool = nn.MaxPool2d(2)
        self.relu = snn.Leaky(beta=1, threshold=0.999999,spike_grad=spike_grad, init_hidden=False,reset_mechanism='zero')
        self.conv = DoubleConv(in_channels, out_channels)

        self.mem1 = self.relu.init_leaky().to(device)
        # self.avgpool_conv = nn.Sequential(
        #    nn.AvgPool2d(2),
        #    DoubleConv(in_channels, out_channels)
        # )

    def forward(self, x, timesteps):
        #mem1 = self.relu.init_leaky() # reset/init hidden states at t=0
        if timesteps ==0 :
            self.mem1 = self.relu.init_leaky().to(device)

        self.mem1 = torch.clamp(self.mem1, min=mem_min) # 小于-1的赋值为-1
        x1 = self.avgpool(x)
        x2, self.mem1 = self.relu(x1, self.mem1)


        #print(self.mem1[0,31:,0,0])


        # positions = torch.nonzero(x2 == 1, as_tuple=True)
        # #torch.set_printoptions(threshold=torch.inf)
        # result = torch.stack((positions[1], positions[2], positions[3]))
        # resultT = result.t()
        # #print(resultT)
        # # 找出以 0 和 1 结尾的行
        # rows_with_01_ending = resultT[(resultT[:, -2] == 2) & (resultT[:, -1] == 2)]
        # # 打印这些行
        # print(rows_with_01_ending) # 这一坨用来看某个位置的神经元有没有激活


        #self.mem1 = torch.clamp(self.mem1, min=mem_min) # 小于-1的赋值为-1
        x3 = self.conv(x2, timesteps)
        return x3


class Up(nn.Module):
    """Upscaling then double conv"""

    def __init__(self, in_channels, out_channels, bilinear=False):
        super().__init__()

        # if bilinear, use the normal convolutions to reduce the number of channels
        if bilinear:
            self.up = nn.Upsample(scale_factor=2, mode='bilinear', align_corners=True)
            self.relu1 = snn.Leaky(beta=1, threshold=1, spike_grad=spike_grad, init_hidden=False,reset_mechanism='zero')
            self.DoubleConv = DoubleConv(in_channels, out_channels, in_channels // 2)
        else:
            self.up = nn.ConvTranspose2d(in_channels, out_channels, kernel_size=2, stride=2)
            self.relu1 = snn.Leaky(beta=1, threshold=0.999999, spike_grad=spike_grad, init_hidden=False,reset_mechanism='zero')
            self.conv = DoubleConv(out_channels, out_channels)

        self.mem1 = self.relu1.init_leaky().to(device)

    def forward(self, x1, x2, timesteps):
        #mem1 = self.relu1.init_leaky() # reset/init hidden states at t=0
        if timesteps ==0 :
            self.mem1 = self.relu1.init_leaky().to(device)

        self.mem1 = torch.clamp(self.mem1, min=mem_min) # 小于-1的赋值为-1
        x = self.up(x1)
        weight = self.up.weight.data
        print(weight.shape)
        print(self.up.weight.data)
        print(self.up.bias.data)

        
        #print(x1)
        # input is CHW
        diffY = x2.size()[2] - x.size()[2]
        diffX = x2.size()[3] - x.size()[3]

        x = F.pad(x, [diffX // 2, diffX - diffX // 2,
                        diffY // 2, diffY - diffY // 2])
        # if you have padding issues, see
        # https://github.com/HaiyongJiang/U-Net-Pytorch-Unstructured-Buggy/commit/0e854509c2cea854e247a9c615f175f76fbb2e3a
        # https://github.com/xiaopeng-liao/Pytorch-UNet/commit/8ebac70e633bac59fc22bb5195e513d5832fb3bd
        #x = torch.cat([x2, x1], dim=1)
        x, self.mem1 = self.relu1(x, self.mem1)
        print(type(x))
        # self.up.weight.data = self.up.weight.data/self.mem1.max() * alpha
        # mem1 = self.mem1.clone()
        # mem1 = percentile_99(mem1)
        # self.up.weight.data = self.up.weight.data/mem1 * alpha
        #self.mem1 = torch.clamp(self.mem1, min=mem_min) # 小于-1的赋值为-1
        print(self.up.weight.data.max())
        count_ones = (x == 1).sum().item()
        print(f"Total number of 1s in spk_rec: {count_ones}")
        x2 = self.conv(x, timesteps)
        return x2


class OutConv(nn.Module):
    def __init__(self, in_channels, out_channels):
        super(OutConv, self).__init__()
        self.conv = nn.Conv2d(in_channels, out_channels, kernel_size=1)

    def forward(self, x):
        
        print(self.conv.weight.data.shape)
        x1 = self.conv(x)
        return x1


def save_output_mem(mem, layer_name, timesteps): # 存为浮点数
    # 指定保存文件的目录
    directory = "/home/haoranli/workspace/conversion/parameter_save_FPGA/parameter_T3_20240820_no_cat/layer_out_for_Unet_example0/Neuron_mem/"
    # 确保目录存在，如果不存在则创建
    if not os.path.exists(directory):
        os.makedirs(directory)

    # 生成文件的完整路径
    filename = f"{directory}/{layer_name}_mem.txt"

    # 将张量转换为 NumPy 数组，并转换为整数类型
    mem_numpy = mem.cpu().numpy()
        
    # 保存时保留原始张量形状
    with open(filename, "a") as f:
        f.write(f"Timestep {timesteps}:\n")
        for channel_idx in range(mem_numpy.shape[1]):
            f.write(f"Output Channel {channel_idx}:\n")
            np.savetxt(f, mem_numpy[0, channel_idx], fmt="%6f")
            f.write("\n")
        f.write("\n\n")

    
def save_output_01(mem, layer_name, timesteps):
    directory = "/home/haoranli/workspace/conversion/parameter_save_FPGA/parameter_T3_20240820_no_cat/layer_out_for_Unet_example0/Neuron_out/"
    if not os.path.exists(directory):
        os.makedirs(directory)

    filename = f"{directory}/{layer_name}_output.txt"
        
    # 将张量转换为 NumPy 数组，并转换为整数类型
    mem_numpy = mem.cpu().numpy()
        
    # 保存时保留原始张量形状
    with open(filename, "a") as f:
        f.write(f"Timestep {timesteps}:\n")
        for channel_idx in range(mem_numpy.shape[1]):
            f.write(f"Output Channel {channel_idx}:\n")
            np.savetxt(f, mem_numpy[0, channel_idx], fmt="%6f")
            f.write("\n")
        f.write("\n\n")


def save_output_positions(mem, layer_name, timesteps):
    directory = "/home/haoranli/workspace/conversion/parameter_save_FPGA/parameter_T3_20240820_no_cat/layer_out_for_Unet_example0/Spike_positions/"
    if not os.path.exists(directory):
        os.makedirs(directory)

    filename = f"{directory}/{layer_name}_spikes.txt"
        
    # 将张量转换为 NumPy 数组，并转换为整数类型
    mem_numpy = mem.cpu().numpy().astype(int)
        
    # 查找哪些位置存在脉冲（即值为1）
    (batch, channel, h, w) = mem.shape

    positions = torch.nonzero(mem == 1, as_tuple=True)
    result = torch.stack((positions[1], positions[2], positions[3]))  # (channels, height, width)
    resultT = result.t()  # 转置以方便遍历

    with open(filename, "a") as f:
        f.write(f"Timestep {timesteps}:\n")
        for i in range(h):
            for j in range(w):
                print(i)
                print(j)
                rows_with_01_ending = resultT[(resultT[:, -2] == i) & (resultT[:, -1] == j)]
                f.write(f"Position (H={i}, W={j}): Active in Channels {rows_with_01_ending}\n")
              