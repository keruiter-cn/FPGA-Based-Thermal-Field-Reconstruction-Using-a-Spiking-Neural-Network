import pandas as pd

# 读取Excel文件
excel_file = 'D:/BaiduSyncdisk/项目资料/计算所SNN/control/unet/控制文件/SNN控制文件.xlsx'  # 替换为你的Excel文件路径
sheet_name = 'Sheet1'  # 替换为你的Sheet名称
df = pd.read_excel(excel_file, sheet_name=sheet_name)

# 假设第一行是bit行，获取每一列的bit数，并删除bit行
bit_row = df.iloc[0, 1:]  # 忽略第一列的 'bit' 字符串
df = df.drop(0)

# 打开COE文件准备写入
coe_file = 'D:/BaiduSyncdisk/项目资料/计算所SNN/control/unet/控制文件/SNNUnet_control_200-200_no_cat.coe'  # 替换为你的输出文件名

with open(coe_file, 'w') as file:
    file.write("memory_initialization_radix=2;\n")
    file.write("memory_initialization_vector=\n")

    for index, row in df.iterrows():
        # 过滤掉空行
        if row.isnull().all():
            continue

        binary_values = []
        for i, value in enumerate(row[1:]):  # 忽略第一列
            bit_count = int(bit_row.iloc[i])  # 获取该列对应的bit数
            if isinstance(value, (int, float)):
                int_value = int(value)
                binary_value = f"{int_value:0{bit_count}b}"
                binary_values.append(binary_value)
            elif isinstance(value, str) and value.replace('.', '', 1).isdigit():
                int_value = int(float(value))
                binary_value = f"{int_value:0{bit_count}b}"
                binary_values.append(binary_value)

        if binary_values:
            # 将所有二进制值连接成一个长字符串，并写入COE文件
            row_str = ''.join(binary_values)
            if index < len(df) - 1:
                file.write(row_str + ',\n')
            else:
                file.write(row_str + ';\n')