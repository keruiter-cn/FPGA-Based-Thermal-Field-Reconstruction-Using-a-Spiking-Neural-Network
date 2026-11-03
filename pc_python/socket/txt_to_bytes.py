def txt16b_to_bytes32b(file_path:str)->list:
    file=open(file_path)
    lines=file.readlines()
    line_num=len(lines)
    bytes32b=[]
    for i in range(line_num):
        line=lines[i]
        high,low=int(line[0:2],16).to_bytes(),int(line[2:4],16).to_bytes()
        bytes16b=high+low
        if(i%2==0):
            bytes32b.append(bytes16b)
        else:
            bytes32b[(i-1)//2]=bytes32b[(i-1)//2]+bytes16b
    file.close()
    return bytes32b

def txt16b_to_bytes32b_plus(file_path:str)->list:
    file=open(file_path)
    lines=file.readlines()
    line_num=len(lines)
    bytes32b=[]
    for i in range(line_num):
        line=lines[i]
        high,low=int(line[0:2],16).to_bytes(),int(line[2:4],16).to_bytes()
        bytes16b=high+low
        bytes32b.append(bytes16b+b'\x00\x00')
    file.close()
    return bytes32b

def txt16b_to_bytes32b_full(y_file_path:str,cb_file_path:str,cr_file_path:str)->list:
    y_file=open(y_file_path)
    cb_file=open(cb_file_path)
    cr_file=open(cr_file_path)

    y_lines=y_file.readlines()
    cb_lines=cb_file.readlines()
    cr_lines=cr_file.readlines()
    line_num=len(y_lines)
    bytes32b=[]
    for i in range(line_num):
        y_line,cb_line,cr_line=y_lines[i],cb_lines[i],cr_lines[i]
        high,low=int(y_line[0:2],16).to_bytes(),int(y_line[2:4],16).to_bytes()
        bytes16b_y=high+low
        bytes16b_cbcr=int(cb_line[0:2],16).to_bytes()+int(cr_line[0:2],16).to_bytes()
        bytes32b.append(bytes16b_y+bytes16b_cbcr)
    y_file.close()
    cb_file.close()
    cr_file.close()
    return bytes32b