hex_num = 64//4 #64bit对应的hex个数
num_256b2hex = 256//4 #256bit对应的hex个数
num_256rx_64 =256//64 #256bit对应的64bit个数
num_32rx_64 = 1 #32bit对应的64bit个数
import numpy as np
import os

## 根据硬件以太网接收数据的规则，上位机发送数据每16个bytes需要反序，用于以太网传输
unet_weight_read_path = r"D:\Research\Competition\FPGA2024\workspace_snn\file\weight\unet_weights.txt"
unet_weight_save_path = r"D:\Research\Competition\FPGA2024\workspace_snn\file\weight\unet_weights_reverse.txt"
unet_image_read_path = r"D:\Research\Competition\FPGA2024\workspace_snn\file\input_example\incode_data\unet/"
unet_image_save_path = r"D:\Research\Competition\FPGA2024\workspace_snn\file\input_example\reversed_data\unet/"

# segnet_weight_read_path = "D:/Research/Project/SNN_jss/top_pc_code/parameter_file/weights_segnet.txt"
# segnet_weight_save_path = "D:/Research/Project/SNN_jss/top_pc_code/parameter_file/weights_segnet_re.txt"
# segnet_image_read_path = "D:/Research/Project/SNN_jss/top_pc_code/test_file/incode_data/segnet/"
# segnet_image_save_path = "D:/Research/Project/SNN_jss/top_pc_code/test_file/reversed_data/segnet/"

def reverse_512weight_in_hex(hex_str):  
    reversed_hex_str = ''
    second_part = hex_str[:num_256b2hex]
    first_part = hex_str[num_256b2hex:]
    for j in range(num_256rx_64):
        reversed_hex_16=''.join(first_part[i:i+2] for i in range(hex_num*(j+1)-2,hex_num*(j+1)-hex_num-2 , -2))
        reversed_hex_str = reversed_hex_str + reversed_hex_16
    for j in range(num_256rx_64):
        reversed_hex_16=''.join(second_part[i:i+2] for i in range(hex_num*(j+1)-2,hex_num*(j+1)-hex_num-2 , -2))
        reversed_hex_str = reversed_hex_str + reversed_hex_16
    return reversed_hex_str

def reverse_32fms_in_hex(hex_data_points):  
    reversed_hex_str = []
    for i in range(0,len(hex_data_points)-1,2):
        hex_str = hex_data_points[i+1] + hex_data_points[i] 
        for j in range(num_32rx_64):
            reversed_hex_16=''.join(hex_str[i:i+2] for i in range(hex_num*(j+1)-2,hex_num*(j+1)-hex_num-2 , -2))
            reversed_hex_str.append(reversed_hex_16)
    return reversed_hex_str

#对输入数据进行处理
def reverse_image_data(image_read_path,image_save_path):
    for filepath,dirnames,filenames in os.walk(image_read_path):
        for filename in filenames:
            txt_path =  filepath + filename
            print (filename)
            image_data = np.loadtxt(txt_path,dtype=str)
            reversed_hex_lines = reverse_32fms_in_hex(image_data)
            with open(image_save_path + filename.split('.')[0]+'_re'+'.txt', 'w') as file:
                for reversed_line in reversed_hex_lines:
                    file.write(reversed_line)

def reverse_weight_data(weight_read_path,weight_save_path):
    weight_data = np.loadtxt(weight_read_path,dtype=str)
    reversed_hex_lines = [reverse_512weight_in_hex(line) for line in weight_data]# 对每行数据执行逆序操作
    #保存处理好的weight数据
    with open(weight_save_path, 'w') as file:
        for reversed_line in reversed_hex_lines:
            file.write(reversed_line)

##unet数据处理
# reverse_weight_data(unet_weight_read_path,unet_weight_save_path)
reverse_image_data(unet_image_read_path,unet_image_save_path)
##segnet数据处理
# reverse_weight_data(segnet_weight_read_path,segnet_weight_save_path)
# reverse_image_data(segnet_image_read_path,segnet_image_save_path)





