// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
// Date        : Thu Aug 15 21:16:00 2024
// Host        : Fanhaodong running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               d:/System/Desktop/snn_top_v3/eth_ddr_test/rtl/ddr/ddr4_0/ddr4_0_stub.v
// Design      : ddr4_0
// Purpose     : Stub declaration of top-level module interface
// Device      : xczu15eg-ffvb1156-2-i
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "ddr4_v2_2_17,Vivado 2022.2" *)
module ddr4_0(sys_rst, c0_sys_clk_i, c0_ddr4_act_n, 
  c0_ddr4_adr, c0_ddr4_ba, c0_ddr4_bg, c0_ddr4_cke, c0_ddr4_odt, c0_ddr4_cs_n, c0_ddr4_ck_t, 
  c0_ddr4_ck_c, c0_ddr4_reset_n, c0_ddr4_dm_dbi_n, c0_ddr4_dq, c0_ddr4_dqs_c, c0_ddr4_dqs_t, 
  c0_init_calib_complete, c0_ddr4_ui_clk, c0_ddr4_ui_clk_sync_rst, dbg_clk, 
  c0_ddr4_app_addr, c0_ddr4_app_cmd, c0_ddr4_app_en, c0_ddr4_app_hi_pri, 
  c0_ddr4_app_wdf_data, c0_ddr4_app_wdf_end, c0_ddr4_app_wdf_mask, c0_ddr4_app_wdf_wren, 
  c0_ddr4_app_rd_data, c0_ddr4_app_rd_data_end, c0_ddr4_app_rd_data_valid, 
  c0_ddr4_app_rdy, c0_ddr4_app_wdf_rdy, dbg_bus)
/* synthesis syn_black_box black_box_pad_pin="sys_rst,c0_sys_clk_i,c0_ddr4_act_n,c0_ddr4_adr[16:0],c0_ddr4_ba[1:0],c0_ddr4_bg[0:0],c0_ddr4_cke[0:0],c0_ddr4_odt[0:0],c0_ddr4_cs_n[0:0],c0_ddr4_ck_t[0:0],c0_ddr4_ck_c[0:0],c0_ddr4_reset_n,c0_ddr4_dm_dbi_n[3:0],c0_ddr4_dq[31:0],c0_ddr4_dqs_c[3:0],c0_ddr4_dqs_t[3:0],c0_init_calib_complete,c0_ddr4_ui_clk,c0_ddr4_ui_clk_sync_rst,dbg_clk,c0_ddr4_app_addr[28:0],c0_ddr4_app_cmd[2:0],c0_ddr4_app_en,c0_ddr4_app_hi_pri,c0_ddr4_app_wdf_data[255:0],c0_ddr4_app_wdf_end,c0_ddr4_app_wdf_mask[31:0],c0_ddr4_app_wdf_wren,c0_ddr4_app_rd_data[255:0],c0_ddr4_app_rd_data_end,c0_ddr4_app_rd_data_valid,c0_ddr4_app_rdy,c0_ddr4_app_wdf_rdy,dbg_bus[511:0]" */;
  input sys_rst;
  input c0_sys_clk_i;
  output c0_ddr4_act_n;
  output [16:0]c0_ddr4_adr;
  output [1:0]c0_ddr4_ba;
  output [0:0]c0_ddr4_bg;
  output [0:0]c0_ddr4_cke;
  output [0:0]c0_ddr4_odt;
  output [0:0]c0_ddr4_cs_n;
  output [0:0]c0_ddr4_ck_t;
  output [0:0]c0_ddr4_ck_c;
  output c0_ddr4_reset_n;
  inout [3:0]c0_ddr4_dm_dbi_n;
  inout [31:0]c0_ddr4_dq;
  inout [3:0]c0_ddr4_dqs_c;
  inout [3:0]c0_ddr4_dqs_t;
  output c0_init_calib_complete;
  output c0_ddr4_ui_clk;
  output c0_ddr4_ui_clk_sync_rst;
  output dbg_clk;
  input [28:0]c0_ddr4_app_addr;
  input [2:0]c0_ddr4_app_cmd;
  input c0_ddr4_app_en;
  input c0_ddr4_app_hi_pri;
  input [255:0]c0_ddr4_app_wdf_data;
  input c0_ddr4_app_wdf_end;
  input [31:0]c0_ddr4_app_wdf_mask;
  input c0_ddr4_app_wdf_wren;
  output [255:0]c0_ddr4_app_rd_data;
  output c0_ddr4_app_rd_data_end;
  output c0_ddr4_app_rd_data_valid;
  output c0_ddr4_app_rdy;
  output c0_ddr4_app_wdf_rdy;
  output [511:0]dbg_bus;
endmodule
