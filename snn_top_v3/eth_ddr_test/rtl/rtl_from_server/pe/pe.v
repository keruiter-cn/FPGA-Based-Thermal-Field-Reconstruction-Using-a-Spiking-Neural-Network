`timescale 1ns / 1ps
/***************************************************************
# Filename       :  pe.v
# Designer       :  Zhicheng Hu
#
# File Created   :  2024-07-23 10:54
# Last modified  :  2024-07-23 10:54
#
# Description    :  
# Info           :  v0.0 primary version 2024-07
# Submodules     :  
***************************************************************/
`include "proj_snn.vh"
module pe (
    // Input Ports
    input wire clk,                  // Clock, operating at 200MHz
    input wire irst_n,                // Reset signal, active low
    input wire ilc_enable,           // Module enable signal; low pauses module operation
    input wire brc_din_vld,          // Valid signal for BRC input FMS data, synchronized with clk
    input wire [`SPIKE_INCH_WIDTH-1:0] brc_fms_spike, // Spike data input for convolution or avgpool mode
    input wire [`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH-1:0] wbc_weight_din, // Weight input for convolution mode
    input wire brc_fire_enable,      // Enable firing based on threshold comparison
    input wire brc_ts_end_vld,       // Valid signal indicating end of time step calculations
    input wire itlc_vld,             // Control signal for inter-layer transition
    input wire itlc_first_layer_or_not, // Pulse indicating if it's the first layer
    input wire itlc_last_layer_or_not,  // Pulse indicating if it's the last layer
    input wire itlc_avgpool_or_not,  // Pulse indicating average pooling mode
    input wire [`THRESHOLD_WIDTH-1:0] itlc_threshold, // Threshold value for firing (not used in avgpool mode)
    input wire [`WEIGHT_WIDTH-1:0] fms_spike_bypass,
    input wire [`WEIGHT_WIDTH-1:0] ivbias,
    input wire rbypass,
    // Output Ports
    output reg pec_spike_vld,        // Output valid signal
    output reg [`ACC_WIDTH-1:0] pe_acc_dout // Accumulated output spike or accumulation result
);

//stage0
wire signed [`WEIGHT_WIDTH-1:0] wvwgt_stage0 [`SPIKE_INCH_WIDTH-1:0];
generate
    genvar g;
    for(g=0; g<`SPIKE_INCH_WIDTH; g=g+1) begin:brc_fms_spike_assign 
        assign wvwgt_stage0[g] = brc_fms_spike[g]? wbc_weight_din[g*`WEIGHT_WIDTH+:`WEIGHT_WIDTH]: 'b0;
    end
endgenerate

//stage1 
reg signed [`WEIGHT_WIDTH+3-1:0] rvadd_stage1 [`SPIKE_INCH_WIDTH/8-1:0];
wire signed [`WEIGHT_WIDTH+3-1:0] wvadd_stage1 [`SPIKE_INCH_WIDTH/8-1:0];
generate
    for(g=0; g<`SPIKE_INCH_WIDTH/8; g=g+1) begin:wvadd_stage1_assign
        assign wvadd_stage1[g] = wvwgt_stage0[g*8+0] +
                                 wvwgt_stage0[g*8+1] +
                                 wvwgt_stage0[g*8+2] +
                                 wvwgt_stage0[g*8+3] +
                                 wvwgt_stage0[g*8+4] +
                                 wvwgt_stage0[g*8+5] +
                                 wvwgt_stage0[g*8+6] +
                                 wvwgt_stage0[g*8+7];
        always@(posedge clk or negedge irst_n) begin
            if(!irst_n) begin
                rvadd_stage1[g] <= 'b0;
            end
            else if(brc_din_vld) begin
                rvadd_stage1[g] <= wvadd_stage1[g];
            end
        end
    end
endgenerate

reg rstage1_vld;
reg rstage1_tsend_vld;
reg rstage1_fire_vld;

always@(posedge clk or negedge irst_n) begin
    if(!irst_n) begin
        rstage1_vld <= 1'b0;
        rstage1_fire_vld <= 1'b0;
        rstage1_tsend_vld <= 1'b0;
    end
    else begin
        rstage1_vld <= brc_din_vld;
        rstage1_fire_vld <= brc_fire_enable;
        rstage1_tsend_vld <= brc_ts_end_vld;
    end
end

reg [`WEIGHT_WIDTH-1:0] rvbias_stage1;
always@(posedge clk or negedge irst_n) begin
    if(!irst_n) begin
        rvbias_stage1 <= 'b0;
    end
    else begin
        rvbias_stage1 <= ivbias;
    end
end

//stage2
reg signed [`WEIGHT_WIDTH+5-1:0] rvadd_stage2;
wire signed [`WEIGHT_WIDTH+5-1:0] wvadd_stage2;

assign wvadd_stage2 = rvadd_stage1[0] + rvadd_stage1[1] + rvadd_stage1[2] + rvadd_stage1[3];

always@(posedge clk or negedge irst_n) begin
    if(!irst_n) begin
        rvadd_stage2 <= 'b0;
    end
    else if(rstage1_vld) begin
        rvadd_stage2 <= wvadd_stage2;
    end
end

reg rstage2_vld;
reg rstage2_tsend_vld;
reg rstage2_fire_vld;

always@(posedge clk or negedge irst_n) begin
    if(!irst_n) begin
        rstage2_vld <= 1'b0;
        rstage2_fire_vld <= 1'b0;
        rstage2_tsend_vld <= 1'b0;
    end
    else begin
        rstage2_vld <= rstage1_vld;
        rstage2_fire_vld <= rstage1_fire_vld;
        rstage2_tsend_vld <= rstage1_tsend_vld;
    end
end

reg [`WEIGHT_WIDTH-1:0] rvbias_stage2;
always@(posedge clk or negedge irst_n) begin
    if(!irst_n) begin
        rvbias_stage2 <= 'b0;
    end
    else begin
        rvbias_stage2 <= rvbias_stage1;
    end
end
//stage 3

wire signed [`WEIGHT_WIDTH-1:0] wvbias_acc;
assign wvbias_acc = rvbias_stage2 & rstage2_fire_vld;

wire signed [`ACC_WIDTH-1:0] wvacc_result;
reg signed [`ACC_WIDTH-1:0] rvacc_result;
assign wvacc_result  = (rbypass)? rvacc_result + ($signed(fms_spike_bypass)) : rvacc_result + rvadd_stage2 + wvbias_acc;

reg rfire_compare;

always@(posedge clk or negedge irst_n) begin
    if(!irst_n) begin
        rvacc_result <= 'b0;
    end
    else begin
        rvacc_result <= itlc_vld ? 'b0:
                itlc_avgpool_or_not? ( (brc_ts_end_vld)? 'b0:
                ((brc_fire_enable) & (wvacc_result >= `AVGPOOL_THRESHOLD))? 'b0:
                brc_din_vld? wvacc_result:
                rvacc_result):
                rbypass? ( (brc_ts_end_vld)? 'b0:
                ((brc_fire_enable) & ($signed(wvacc_result) >= $signed(itlc_threshold)))? 'b0:
                brc_din_vld? wvacc_result:
                rvacc_result):
                itlc_last_layer_or_not? (rstage2_vld? wvacc_result: rvacc_result):
                rstage2_tsend_vld ? 'b0:
                rstage2_fire_vld ? ($signed(wvacc_result) >= $signed(itlc_threshold))? 'b0: wvacc_result:
                rstage2_vld? wvacc_result:
                rvacc_result;

                rfire_compare <= rbypass?
                brc_fire_enable&(itlc_avgpool_or_not? wvacc_result >= `AVGPOOL_THRESHOLD : ($signed(wvacc_result) >= $signed(itlc_threshold)))
                : rstage2_fire_vld ? ($signed(wvacc_result) >= $signed(itlc_threshold)) : 'b0;
    end
end

always@(*) begin
    pe_acc_dout = itlc_last_layer_or_not? rvacc_result: rfire_compare;
end

always@(posedge clk or negedge irst_n) begin
    if(!irst_n) begin
        pec_spike_vld <= 1'b0;
    end
    else begin
        pec_spike_vld <= itlc_last_layer_or_not? rstage2_tsend_vld: rbypass? brc_fire_enable : rstage2_fire_vld;
    end
end

//stage 4


endmodule

