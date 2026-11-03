import re

# Read the Verilog file
with open('pec.v', 'r') as file:
    verilog_code = file.read()

# Remove comments (both single-line and multi-line)
verilog_code = re.sub(r'//.*', '', verilog_code)  # Remove single-line comments
verilog_code = re.sub(r'/\*.*?\*/', '', verilog_code, flags=re.DOTALL)  # Remove multi-line comments

# Extract module name and port information
module_name = re.search(r'\bmodule\s+(\w+)', verilog_code).group(1)
ports = re.findall(r'\b(input|output|inout)\s+(wire|reg)?\s*(\[.*?\])?\s*(\w+)', verilog_code)

# Create the testbench code
tb_code = f"""`timescale 1ns/1ps

module tb_{module_name};

    // Signal definitions
"""

# Generate signal definitions based on port types
for port in ports:
    direction, _, width, name = port
    if not width:
        width = ''
    if direction == 'input':
        tb_code += f"    reg {width} {name};\n"
    elif direction == 'output':
        tb_code += f"    wire {width} {name};\n"

# Generate clock signal if clk exists
if 'clk' in [p[3] for p in ports]:
    tb_code += """
    // Clock signal generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end
    """

# Generate reset signal if rst_n exists
if 'rst_n' in [p[3] for p in ports]:
    tb_code += """
    // Reset signal generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end
    """

# Generate instantiation code
tb_code += f"""
    // Instantiate the Unit Under Test (UUT)
    {module_name} uut (
"""
for port in ports:
    name = port[3]
    tb_code += f"        .{name}({name}),\n"
tb_code = tb_code.rstrip(',\n') + '\n    );\n'

tb_code += """
    // Simulation test
    initial begin
        // Initialize signals
"""

# Initialize input signals
for port in ports:
    direction, name = port[0], port[3]
    if direction == 'input':
        tb_code += f"        {name} = 0;\n"

tb_code += """
        // Add more test cases here
        #100;
        $finish;
    end

endmodule
"""

# Save the generated testbench to a file
with open(f'tb_{module_name}.v', 'w') as file:
    file.write(tb_code)

print(f'tb_{module_name}.v has been generated.')

