`timescale 1ns / 1ps
/***************************************************************
# Filename       :  pec.v
# Designer       :  Zhicheng Hu
#
# File Created   :  2024-07-23 10:51
# Last modified  :  2024-07-23 10:51
#
# Description    :  
# Info           :  v0.0 primary version 2024-07
# Submodules     :  
***************************************************************/
`include "proj_snn.vh"
module pec (
    input wire clk,                   // Clock signal, operating at 200MHz
    input wire clk_ddr,                 //  clokc signal for ddr write
    input wire rst_n,                 // Reset signal (active low)
    input wire ilc_enable,            // Module enable signal (active high)
    input wire brc_din_vld,           // Valid signal for BRC input FMS data
    input wire [`SPIKE_INCH_WIDTH-1:0] brc_fms_spike, // BRC input spike data
    input wire brc_one_spike,         // Indicates single spike input in first layer
    input wire brc_row_end_vld,       // Valid signal for end of row in sliding window
    input wire brc_fire_enable,       // Enables firing operation based on threshold comparison
    input wire brc_ts_end_vld,        // Valid signal indicating end of all time steps
    input wire [`WEIGHT_RAM_INDEX:0] ddr_weight_waddr, // Address for writing weights to DDR
    input wire [5-1:0] wgt_buf_cs,
    input wire ddr_write_vld,         // Valid signal to write to BRAM (ping when reading, pong when writing)
    input wire [`DDR_WIDTH-1:0] ddr_weight_din, // Data input for writing weights to DDR
    input wire itlc_vld,              // Inter-layer transition control signal valid
    input wire itlc_first_layer_or_not, // Pulse indicating if it is the first layer
    input wire itlc_last_layer_or_not,  // Pulse indicating if it is the last layer
    input wire itlc_bias_or_not,        // Pulse indicating presence of bias
    input wire itlc_conv_or_not,        // Pulse enabling convolution mode
    input wire itlc_convt_or_not,       // Pulse enabling deconvolution mode
    input wire itlc_avgpool_or_not,     // Pulse enabling average pooling mode
    input wire [`THRESHOLD_WIDTH-1:0] itlc_threshold, // Threshold value for comparison (not used in avgpool mode)
    input wire ilc_ping_or_pong,        // Indicates current read operation from BRAM (ping or pong)
    input  wire [4-1:0] ilc_in_ch_num,
    input  wire [`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH-1:0] bias,
    output wire bwc_spike_vld,           // Output valid signal
    output wire [`PE_NUM-1:0] bwc_spike, // Combined 32 PE spikes as a 32-bit signal
    output wire [`ACC_WIDTH-1:0] bwc_acc_dout // Accumulated output for last layeR
);

genvar g;
wire irst_n;
assign irst_n = rst_n;

reg reg_first_layer_or_not;
reg reg_last_layer_or_not;
reg reg_bias_or_not;
reg reg_conv_or_not;
reg reg_convt_or_not;
reg reg_avgpool_or_not;


reg brc_din_vld_dly;           // Valid signal for BRC input FMS data
reg [`SPIKE_INCH_WIDTH-1:0] brc_fms_spike_dly; // BRC input spike data
reg brc_one_spike_dly;         // Indicates single spike input in first layer
reg brc_row_end_vld_dly;       // Valid signal for end of row in sliding window
reg brc_fire_enable_dly;       // Enables firing operation based on threshold comparison
reg brc_ts_end_vld_dly;       // Valid signal indicating end of all time steps
always@(posedge clk) begin
    begin
        brc_din_vld_dly <= brc_din_vld;
        brc_one_spike_dly  <= brc_one_spike;
        brc_fms_spike_dly <= brc_fms_spike;
        brc_row_end_vld_dly<= brc_row_end_vld;
        brc_fire_enable_dly<= brc_fire_enable;
        brc_ts_end_vld_dly <= brc_ts_end_vld;
    end
end


always@(posedge clk or negedge irst_n) begin
    if (!irst_n) begin
        reg_first_layer_or_not <= 1'b0;
        reg_last_layer_or_not <= 1'b0;
        reg_bias_or_not <= 1'b0;
        reg_conv_or_not <= 1'b0;
        reg_convt_or_not <= 1'b0;
        reg_avgpool_or_not <= 1'b0;
    end
    else if (itlc_vld) begin
        reg_first_layer_or_not <= itlc_first_layer_or_not;
        reg_last_layer_or_not <= itlc_last_layer_or_not;
        reg_bias_or_not <= itlc_bias_or_not;
        reg_conv_or_not <= itlc_conv_or_not;
        reg_convt_or_not <= itlc_convt_or_not;
        reg_avgpool_or_not <= itlc_avgpool_or_not;
    end
end

wire bypass;
assign bypass = reg_first_layer_or_not | reg_avgpool_or_not;

wire [`PE_NUM*`WEIGHT_WIDTH*`SPIKE_INCH_WIDTH-1:0] wbc_weight_din;

wire [`WEIGHT_WIDTH-1:0] wvfms_spike_bypass [`PE_NUM-1:0];
generate
    for(g=0 ; g<`PE_NUM; g=g+1) begin:bypass_assign
       assign wvfms_spike_bypass[g] = reg_avgpool_or_not? {15'b0, brc_fms_spike_dly[g]} : {`WEIGHT_WIDTH{brc_fms_spike_dly[0]}}&wbc_weight_din[g*`WEIGHT_WIDTH*`SPIKE_INCH_WIDTH +:`WEIGHT_WIDTH];
    end
endgenerate

wire [`THRESHOLD_WIDTH-1:0] wvthre;
assign wvthre = reg_avgpool_or_not? `AVGPOOL_THRESHOLD: itlc_threshold;

wire [`SPIKE_INCH_WIDTH-1:0] wvpe_spike;
assign wvpe_spike = reg_first_layer_or_not? {31'b0, brc_one_spike_dly}: brc_fms_spike_dly;

wire [`PE_NUM-1:0] wvbrc_din_vld;
assign wvbrc_din_vld = brc_din_vld_dly ? (reg_last_layer_or_not? 32'b1: 32'hffffffff): 32'b0;

wire [`PE_NUM-1:0] pec_spike_vld;
wire [`ACC_WIDTH-1:0] pe_acc_dout [`PE_NUM-1:0];

generate
    for(g=0 ; g<`PE_NUM; g=g+1) begin :gen_pe
        pe u_pe_inst (
            .clk(clk),
            .irst_n(irst_n),
            .ilc_enable(ilc_enable),
            .brc_din_vld(wvbrc_din_vld[g]),
            .brc_fms_spike(wvpe_spike),
            .wbc_weight_din(wbc_weight_din[g*`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH+:`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH]),
            .ivbias(bias[g*`BIAS_WIDTH+:`BIAS_WIDTH]),
            .brc_fire_enable(brc_fire_enable_dly),
            .brc_ts_end_vld(brc_ts_end_vld_dly),
            .itlc_avgpool_or_not(reg_avgpool_or_not),
            .rbypass(bypass),
            .itlc_first_layer_or_not(reg_first_layer_or_not),
            .itlc_last_layer_or_not(reg_last_layer_or_not),
            .itlc_threshold(wvthre),
            .fms_spike_bypass(wvfms_spike_bypass[g]),
            .itlc_vld(itlc_vld),
            .pec_spike_vld(pec_spike_vld[g]),
            .pe_acc_dout(pe_acc_dout[g])
        );
    end
endgenerate


wire [`WEIGHT_RAM_INDEX-1:0] wvraddr;

reg [`PE_NUM-1:0] cs_en;
wire [`PE_NUM-1:0] cs_wen;
always @(*) begin
    cs_en = 32'b0;
    cs_en[wgt_buf_cs] = 1'b1;
end

generate
    for(g=0; g<`PE_NUM; g=g+1) begin: gen_wgt_buf
        assign cs_wen[g] = ddr_write_vld & cs_en[g];
        pp_wgt_buf upp_wgt_buf(
            .wclk(clk_ddr),
            .iwen(cs_wen[g]),
            .ilc_ping_or_pong(ilc_ping_or_pong),
            .iwvwaddr(ddr_weight_waddr),
            .iwvwdata(ddr_weight_din),
            .rclk(clk),
            .iwvraddr(wvraddr),
            .owvdata(wbc_weight_din[g*`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH+:`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH])
        );
    end
endgenerate

wgt_buf_ctrl u_wgt_buf_ctrl (
    .clk(clk),
    .irst_n(irst_n),
    .itlc_vld(itlc_vld),
    .imode_avg(reg_avgpool_or_not),
    .imode_convt(reg_convt_or_not),
    .imode_conv(reg_conv_or_not),
    .brc_din_vld(brc_din_vld),
    .ilc_in_ch_num(ilc_in_ch_num),
    .ifire_enable(brc_fire_enable),
    .its_end(brc_ts_end_vld),
    .irow_end(brc_row_end_vld),
    .orvraddr(wvraddr)
);

generate
for(g=0; g<`PE_NUM; g=g+1) begin:bwc_acc_dout_assign
    assign bwc_acc_dout[0+:`ACC_WIDTH] = pe_acc_dout[0];
    assign bwc_spike[g] = pe_acc_dout[g][0];
end
endgenerate
assign bwc_spike_vld = |pec_spike_vld;

endmodule


