from torch.nn import Module
from torch import nn
import torch
import sys
import torch.nn.functional as F
import snntorch as snn
from snntorch import surrogate

sys.path.append("/home/lihb/Github/bita_new_version")
#import snn.spiking_neuron as neuron
#import spiking_neuron_099_timestep1_inputs as neuron # 若内存泄露，可用T..._Train2和上一行应急

spike_grad = surrogate.atan(alpha=2) # fast sigmoid surrogate gradient
#spike_grad = surrogate.triangular()
#spike_grad = surrogate.superspike()
class SNN_SegNet(nn.Module):
    def __init__(self, input_channels, output_channels):
        super(SNN_SegNet, self).__init__()

        #self.IF_neuron = snn.Leaky(beta=1, threshold=0.999999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        # 编码器部分
        self.code = nn.Sequential(nn.Conv2d(input_channels, input_channels, kernel_size=3, padding=1, bias = False),
                                  snn.Leaky(beta=1, threshold=0.999999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'))
        
        
        self.enc1 = nn.Sequential(
            nn.Conv2d(input_channels, 32, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'),
            nn.Conv2d(32, 32, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        )
        self.pool1 = nn.AvgPool2d(2, stride=2)
        self.IF_neuron_1 = snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        
        

        self.enc2 = nn.Sequential(
            nn.Conv2d(32, 64, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'),
            nn.Conv2d(64, 64, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        )
        self.pool2 = nn.AvgPool2d(2, stride=2)
        self.IF_neuron_2 = snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        
        
        self.enc3 = nn.Sequential(
            nn.Conv2d(64, 128, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'),
            nn.Conv2d(128, 128, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'),
            nn.Conv2d(128, 256, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        )
        self.pool3 = nn.AvgPool2d(2, stride=2)
        self.IF_neuron_3 = snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        

        # 解码器部分，使用 MaxUnpool2d
        self.unpool3 = nn.ConvTranspose2d(256, 256, kernel_size=2, stride=2, bias=False)
        self.IF_neuron_u3 = snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        self.dec3 = nn.Sequential(
            nn.Conv2d(256, 128, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'),
            nn.Conv2d(128, 128, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'),
            nn.Conv2d(128, 64, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        )

        self.unpool2 = nn.ConvTranspose2d(64, 64, kernel_size=2, stride=2, bias=False)
        self.IF_neuron_u2 = snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        self.dec2 = nn.Sequential(
            nn.Conv2d(64, 64, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero'),
            nn.Conv2d(64, 32, kernel_size=3, padding=1, bias=False),
            snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        )

        self.unpool1 = nn.ConvTranspose2d(32, 32, kernel_size=2, stride=2, bias=False)
        self.IF_neuron_u1 = snn.Leaky(beta=1, threshold=0.9999, spike_grad=spike_grad, init_hidden=True ,reset_mechanism='zero')
        self.outc = nn.Conv2d(32, output_channels, kernel_size=1)


    def forward(self, x):
        # 编码
        x = self.code(x)
        
        #print(x.shape)
        x = self.enc1[0](x)
        #print(x.max())
        x = self.enc1[1](x)
        x = self.enc1[2](x)
        #print(x.max())
        x = self.enc1[3](x)
        #print(self.enc1[1].mem)
        x = self.pool1(x)
        x = self.IF_neuron_1(x)
        #print(self.IF_neuron_1.mem)

        # print(self.unpool1.weight.data)
        # k = self.unpool1.weight.data

        
        x = self.enc2[0](x)
        # print(x.max())
        x = self.enc2[1](x)
        x = self.enc2[2](x)
        # print(x.max())
        x = self.enc2[3](x)
        x = self.pool2(x)
        x = self.IF_neuron_2(x)

        
        x = self.enc3[0](x)
        # print(x.max())
        x = self.enc3[1](x)
        x = self.enc3[2](x)
        # print(x.max())
        x = self.enc3[3](x)
        x = self.enc3[4](x)
        # print(x.max())
        x = self.enc3[5](x)
        x = self.pool3(x)
        x = self.IF_neuron_3(x)

        # 解码
        x = self.unpool3(x)  # 注意这里不再传递 idx3
        # print(x.max())
        x = self.IF_neuron_u3(x)
        x = self.dec3[0](x)
        # print(x.max())
        x = self.dec3[1](x)
        x = self.dec3[2](x)
        # print(x.max())
        x = self.dec3[3](x)
        x = self.dec3[4](x)
        # print(x.max())
        x = self.dec3[5](x)

        x = self.unpool2(x)  # 不再传递 idx2
        x = self.IF_neuron_u2(x)
        x = self.dec2[0](x)
        x = self.dec2[1](x)
        x = self.dec2[2](x)
        x = self.dec2[3](x)

        x = self.unpool1(x)  # 不再传递 idx1
        x = self.IF_neuron_u1(x)
        x = self.outc(x)

        return x