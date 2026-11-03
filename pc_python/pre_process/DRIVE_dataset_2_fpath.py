from torch.utils.data import Dataset
import torch
from torch import autograd, optim
from torchvision.transforms import transforms
import torch.nn as nn
import os
import sys
sys.path.append('../')
import numpy as np
# import random
import scipy.io
import scipy.io as scio
from torchvision.transforms import transforms

x_transforms = transforms.Compose([
    transforms.ToTensor(), transforms.Normalize([0], [1])])

y_transforms = transforms.Compose([
    transforms.ToTensor(), transforms.Normalize([0], [1])])


def load_matfile(infile):
    data = scipy.io.loadmat(infile)  # 加载 MAT 文件
    return data["u"]  # 返回键为 "u" 的数据



class DRIVE_dataset(Dataset):
    def __init__(self,
                 root_dir,
                 train=True,
                 transform=x_transforms,
                 label_transform=y_transforms):
        self.f_root_dir = root_dir
        self.transform = transform
        self.label_transform = label_transform

        F200 = np.zeros((1, 200, 200), dtype=np.float32)
        u200 = np.zeros((1, 200, 200), dtype=np.float32)
        sensor200 = np.zeros((1, 200, 200), dtype=np.float32)

        fpath = self.f_root_dir
            # print(fpath)
        j = scio.loadmat(fpath)
        relu = nn.ReLU()
            # print(j)
            #  数据集合共有temp-dist,ux_,uy_,sigma_xx,sigma_yy,sigma_xy分别代表温度场、x方向变形，y方向变形，x方向热应力，y方向热应力，切方向热应力
            #  predicted指向需要训练的部分
            #  由于数据量级比较小，放大进行训练
            # print('T_normal.size', T_normal.shape, j['T_normal'].shape)
            # F200[i] = j['F']
        u200[0] = j['u']-298
        sensor200_tensor = (j['u_obs']-298) / 100  # 归一化0-1
        sensor200_tensor = relu(torch.tensor(sensor200_tensor))
        sensor200[0] = sensor200_tensor.numpy()
            # print(u200[i].max(), u200[i].min())
            # print(sensor200[i].max(), sensor200[i].min())
            # print(i)
        # self.F200 = np.expand_dims(F200, 3)
        self.u200 = np.expand_dims(u200, 3)
        self.sensor200 = np.expand_dims(sensor200, 3)

        # print(self.F200.shape)
        # print(self.u200.shape)

    def __len__(self):
        # print(self.temp_dist.shape[0])
        return self.u200.shape[0]  # 这里用return len(self.imgs)?

    def __getitem__(self, idx):
        u_200, sensor_200 = self.u200[idx], self.sensor200[idx]
        # f_200, u_200, sensor_200 = self.F200[idx], self.u200[idx], self.sensor200[idx]
        # print(tn.shape)
        # print(t_short_1.shape)
        if self.transform:
            # u_200 = self.transform(u_200)
            sensor_200 = self.transform(sensor_200)
        if self.label_transform:
            u_200 = self.label_transform(u_200)
        # print('tf',tf)
        # print('Predicted',Predicted)
        # f是布局，u是温度，sensor是传感器
        return u_200, sensor_200
