# 设置数据的范围
start = 0
end = 10240 - 1
hex_num = 64//4 #64bit对应的hex个数
num_256b2hex = 256//4 #256bit对应的hex个数
num_256rx_64 =256//64 #256bit对应的64bit个数
num_32rx_64 = 1 #32bit对应的64bit个数
import numpy as np
# 生成数据
#data_points = list(range(start, end + 1))
# 打印生成的数据点数量
#print(f"Generated {len(data_points)} data points.")

# hex_data_points = [hex(i)[2:].zfill(num_256b2hex).upper() for i in range(start, end + 1)]

read_path = "D:\System\Desktop\workspace_snn/file\weight\segnet_weights.txt"
save_path = "D:\System\Desktop\workspace_snn/file\weight\segnet_weights_reverse.txt"
# read_path = "D:\System\Desktop\workspace_snn/file\input_example\segnet\incode_Example0_Segnet.txt"
# save_path = "D:\System\Desktop\workspace_snn/file\input_example\segnet\incode_Example0_Segnet_reverse.txt"
# read_path = "D:\System\Desktop\socket\data_to_fpga\weights_ts3.txt"
# save_path = "D:\System\Desktop\socket\data_to_fpga\weights_ts3_re.txt"

file_path = "D:\System\Desktop\socket\data_to_fpga\weights_ts3_re.txt"
binfilepath = "D:\System\Desktop\socket\data_to_fpga\weights_ts3_re.bin"

# read_path = "D:\System\Desktop\socket\process_test\incode_Example0.txt"
# save_path = "D:\System\Desktop\socket\process_test\incode_Example0_reverse.txt"

# file_path = "D:\System\Desktop\socket\process_test\incode_Example0_reverse.txt"
# binfilepath = "D:\System\Desktop\socket\process_test\incode_Example0_reverse.bin"

hex_data_points = np.loadtxt(read_path,dtype=str)
def reverse_512weight_in_hex(hex_str):  
    reversed_hex_str = ''
    # print(len(hex_str))
    second_part = hex_str[:num_256b2hex]
    first_part = hex_str[num_256b2hex:]
    for j in range(num_256rx_64):
        reversed_hex_16=''.join(first_part[i:i+2] for i in range(hex_num*(j+1)-2,hex_num*(j+1)-hex_num-2 , -2))
        reversed_hex_str = reversed_hex_str + reversed_hex_16
    for j in range(num_256rx_64):
        reversed_hex_16=''.join(second_part[i:i+2] for i in range(hex_num*(j+1)-2,hex_num*(j+1)-hex_num-2 , -2))
        reversed_hex_str = reversed_hex_str + reversed_hex_16

    return reversed_hex_str
##没验证fms的情况，也没写完
def reverse_256weight_in_hex(hex_str):  
    reversed_hex_str = ''
    for j in range(num_256rx_64):
        reversed_hex_16=''.join(hex_str[i:i+2] for i in range(hex_num*(j+1)-2,hex_num*(j+1)-hex_num-2 , -2))
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

def txt_to_bytes(file_path:str,save_path:str)->list:
    file=open(file_path)
    lines=file.readlines()
    #lines=file.read(32)
    line_num=len(lines)
    bytes32b=[]
    for i in range(line_num):
        line=lines[i]
        line_list = list(line)
        len_num = len(line_list)//2
        #len_num = len(line_list)
        #high,low=int(line[0:2],16).to_bytes(1,'big'),int(line[2:4],16).to_bytes(1,'big')
        #bytes16b=high+low
        for j in range(len_num):
            if(j==0):
                sum = int(line[j*2:j*2+2],16).to_bytes(1,'big')
            else:
                bytes16b = int(line[j*2:j*2+2],16).to_bytes(1,'big')
                sum = sum + bytes16b
            # if(j==0):
            #     sum = int(line[j],16).to_bytes(1,'big')
            # else:
            #     bytes16b = int(line[j],16).to_bytes(1,'big')
            #     sum = sum + bytes16b
        sum_list = list(sum)
        sum_num = len(sum_list)
    file.close()
    with open(save_path, "wb") as f:
        f.write(sum)
    return sum
# 对每行数据执行逆序操作
reversed_hex_lines = reverse_32fms_in_hex(hex_data_points)
# reversed_hex_lines = [reverse_512weight_in_hex(line) for line in hex_data_points]

with open(save_path, 'w') as file:
    for reversed_line in reversed_hex_lines:
        file.write(reversed_line)

#txt to bin file
# test = txt_to_bytes(file_path,binfilepath)