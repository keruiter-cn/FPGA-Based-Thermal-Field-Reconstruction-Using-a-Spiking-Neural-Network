// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
// Date        : Wed Aug 14 10:02:25 2024
// Host        : Fanhaodong running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub d:/System/Desktop/eth_ddr_test/ip/bias_bram/bias_bram_stub.v
// Design      : bias_bram
// Purpose     : Stub declaration of top-level module interface
// Device      : xczu15eg-ffvb1156-2-i
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_5,Vivado 2022.2" *)
module bias_bram(clka, ena, wea, addra, dina, douta)
/* synthesis syn_black_box black_box_pad_pin="clka,ena,wea[0:0],addra[4:0],dina[511:0],douta[511:0]" */;
  input clka;
  input ena;
  input [0:0]wea;
  input [4:0]addra;
  input [511:0]dina;
  output [511:0]douta;
endmodule
