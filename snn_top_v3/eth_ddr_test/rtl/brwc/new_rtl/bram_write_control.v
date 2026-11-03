`include "proj_snn.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/23/2024 08:14:58 PM
// Design Name: 
// Module Name: bram_write_control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bram_write_control_new(
input   wire                               clk                     ,
input   wire                               rst_n                   ,
input   wire                               ilc_enable              ,
input   wire   [`PE_NUM-1:0]               pec_spike_din           ,
input   wire                               pec_spike_vld           ,
input   wire   [`ACC_WIDTH-1:0]            pec_acc_dout            ,
input   wire                               itlc_vld                ,
input   wire   [`OUTCH_NUM_WIDTH-1:0]      itlc_out_ch_num         ,
input   wire                               itlc_avgpool_or_not     ,
input   wire                               itlc_last_layer_or_not  ,
input   wire                               itlc_sp_padding         ,
input   wire   [`MAX_WIDTH_INDEX-1:0]      ilc_fms_length          ,//new
input   wire   [`TS_INDEX-1:0]             brc_ts_cs               ,
input   wire                               brc_ts_end_vld          ,
input   wire                               brc_slide_over          ,
input   wire                               brc_row_end_vld         ,
output  reg                                ilc_stop_req            ,
output  wire                               fms_write_en            ,
output  reg  [`FMS_RAM_INDEX-1:0]          fms_write_addr          ,
output  wire  [`TS_INDEX-1:0]              fms_ts_cs               ,
wire   [`PE_NUM-1:0]               fms_spike_dout          ,

output  wire                               sp_pad_slide_over        //new
    );

reg   [`OUTCH_NUM_WIDTH-1:0]      itlc_out_ch_num_r       ; 
reg                               itlc_avgpool_or_not_r   ; 
reg                               itlc_last_layer_or_not_r;
wire                               itlc_sp_padding_r       ;
reg   [`OUTCH_NUM_WIDTH-1:0]      write_base_addr       ;
//reg   [4:0]                       sp_padding_cnt        ;
//wire  [`OUTCH_NUM_WIDTH:0]        write_skip_addr         ;
wire                              ts_end_vld_d          ;
wire                              slide_over_d          ;
wire  [`TS_INDEX-1:0]             ts_cs                 ;
wire  [`TS_INDEX-1:0]             ts_cs_d                 ;
wire                              row_end_vld           ;
reg    [`TS_INDEX-1:0]           ts_cnt                ;
reg   [`MAX_WIDTH_INDEX-1:0]         col_cnt              ;
reg                               last_row_padding     ; 
//assign ts_cs = (itlc_last_layer_or_not_r) ? {`TS_INDEX{1'b0}} : brc_ts_cs;
assign fms_ts_cs = (ilc_stop_req) ? ts_cnt:((itlc_last_layer_or_not_r) ? {`TS_INDEX{1'b0}} : brc_ts_cs);
assign ts_end_vld_d = brc_ts_end_vld;
assign slide_over_d = brc_slide_over;
assign row_end_vld = brc_row_end_vld;
assign itlc_sp_padding_r = itlc_sp_padding;
assign sp_pad_slide_over = (itlc_sp_padding_r) ? (col_cnt==((ilc_fms_length<<1)+1'b1)&&(ts_cnt==`TIMESTEP - 1'b1)):1'b0;
//register control signal of this layer
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
       itlc_out_ch_num_r       <= {`OUTCH_NUM_WIDTH{1'b0}};
       itlc_avgpool_or_not_r   <= 1'b0;
       itlc_last_layer_or_not_r<= 1'b0;
      // itlc_sp_padding_r       <= 1'b0;
    end
    else if(itlc_vld)begin
       itlc_out_ch_num_r       <= itlc_out_ch_num;
       itlc_avgpool_or_not_r   <= itlc_avgpool_or_not;
       itlc_last_layer_or_not_r<= itlc_last_layer_or_not;
       //itlc_sp_padding_r       <= itlc_sp_padding;
    end
    else begin
       itlc_out_ch_num_r       <= itlc_out_ch_num_r;
       itlc_avgpool_or_not_r   <= itlc_avgpool_or_not_r;
       itlc_last_layer_or_not_r<= itlc_last_layer_or_not_r;
       //itlc_sp_padding_r       <= itlc_sp_padding_r;
    end
end
//c_shift_ram_0 delay_ts_cs(
//  .D(ts_cs),      // input wire [0 : 0] D
//  .CLK(clk),  // input wire CLK
//  .Q(ts_cs_d)      // output wire [0 : 0] Q
//);

//c_shift_ram_0 delay_ts_end_vld(
//  .D(brc_ts_end_vld),      // input wire [0 : 0] D
//  .CLK(clk),  // input wire CLK
//  .Q(ts_end_vld_d)      // output wire [0 : 0] Q
//);
//c_shift_ram_0 delay_slide_over(
//  .D(brc_slide_over),      // input wire [0 : 0] D
//  .CLK(clk),  // input wire CLK
//  .Q(slide_over_d)      // output wire [0 : 0] Q
//);
//c_shift_ram_0 delay_row_end_vld(
//  .D(brc_row_end_vld),      // input wire [0 : 0] D
//  .CLK(clk),  // input wire CLK
//  .Q(row_end_vld)      // output wire [0 : 0] Q
//);
always @(posedge clk or negedge rst_n)begin
    if(!rst_n||itlc_vld)begin
        ilc_stop_req <= 1'b0;
    end
    else if(ilc_enable)begin
        if(itlc_sp_padding_r) begin
            if(row_end_vld||slide_over_d)
                ilc_stop_req <= 1'b1;
            else if((ts_cnt==`TIMESTEP - 1'b1)&&(!last_row_padding||col_cnt==((ilc_fms_length<<1)+1'b1)))
                ilc_stop_req <= 1'b0;
            else
                ilc_stop_req <= ilc_stop_req;
        end
        else
            ilc_stop_req <= 1'b0;
    end
    else begin
        ilc_stop_req <= ilc_stop_req;
    end
end
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        last_row_padding <= 1'b0;
    else if(ilc_enable&&itlc_sp_padding_r)begin
        if(slide_over_d)
            last_row_padding <= 1'b1;
        else if(sp_pad_slide_over)
            last_row_padding <= 1'b0;
        else
            last_row_padding <= last_row_padding;
    end
    else
        last_row_padding <= last_row_padding;
end
always @(posedge clk or negedge rst_n)begin
    if(!rst_n||itlc_vld)begin
        ts_cnt <= {`TS_INDEX{1'b0}};
    end
    else if(ilc_enable)begin
        if(ilc_stop_req)begin
            if(ts_cnt==`TIMESTEP - 1'b1)
                ts_cnt  <= {`TS_INDEX{1'b0}};
            else
                ts_cnt <= ts_cnt + 1'b1;
        end
        else begin
            ts_cnt <= {`TS_INDEX{1'b0}};
        end
    end
    else 
        ts_cnt <= ts_cnt;
end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        col_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
    else if(ilc_enable)begin
        if(ilc_stop_req&&last_row_padding)begin
            if(sp_pad_slide_over)
                col_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
            else if(ts_cnt==`TIMESTEP - 1'b1)
                col_cnt <= col_cnt + 1'b1;
            else
                col_cnt <= col_cnt;
        end
        else
            col_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
    end
    else
        col_cnt <= col_cnt;
end


always @(posedge clk or negedge rst_n)begin
    if(!rst_n||itlc_vld)begin
        fms_write_addr <= {`FMS_RAM_INDEX{1'b0}};
        write_base_addr <= {`OUTCH_NUM_WIDTH{1'b0}};
    end
    else if(ilc_enable)begin
        if(itlc_last_layer_or_not_r)begin
            if(ts_end_vld_d)begin
                fms_write_addr  <=  fms_write_addr + 1'b1;
            end
            else begin
                fms_write_addr <= fms_write_addr;
            end
        end
        else if(itlc_sp_padding_r)begin //padding 24-->25 convt result
             if(sp_pad_slide_over)begin
                write_base_addr <= write_base_addr + 1'b1;
                fms_write_addr  <=  write_base_addr+ 1'b1;
            end
            else if(ilc_stop_req&&(ts_cnt==`TIMESTEP - 1'b1))begin
                fms_write_addr  <=  fms_write_addr+itlc_out_ch_num_r + 1'b1;
                write_base_addr <= write_base_addr;
            end
            else if(ts_end_vld_d)begin //when time step end addr+1. The write addr of every Time Step BRAM is same
                fms_write_addr  <=  fms_write_addr + itlc_out_ch_num_r + 1'b1;
                write_base_addr <= write_base_addr;
            end
            else begin
                write_base_addr <= write_base_addr;
                fms_write_addr <= fms_write_addr;
            end           
            
        end
        else begin
            if(slide_over_d)begin
                write_base_addr <= write_base_addr + 1'b1;
                fms_write_addr  <=  write_base_addr+ 1'b1;
            end
            else if(ts_end_vld_d)begin //when time step end addr+1. The write addr of every Time Step BRAM is same
                fms_write_addr  <=  fms_write_addr + itlc_out_ch_num_r + 1'b1;
                write_base_addr <= write_base_addr;
            end
            else begin
                write_base_addr <= write_base_addr;
                fms_write_addr <= fms_write_addr;
            end
        end
    end
    else begin
        fms_write_addr <= fms_write_addr;
        write_base_addr <= write_base_addr;
    end
end
//  wire   [`ACC_WIDTH-1:0]            fms_acc_dout            ;
assign fms_write_en = (ilc_stop_req) ? 1'b1: pec_spike_vld;
//assign write_skip_addr = itlc_out_ch_num_r;
assign fms_spike_dout = (ilc_stop_req) ? {`PE_NUM{1'b0}}:(itlc_last_layer_or_not_r ? ((pec_spike_vld) ? $signed(pec_acc_dout):{`PE_NUM{1'b0}}): ((pec_spike_vld) ? pec_spike_din:{`PE_NUM{1'b0}}));
// assign fms_acc_dout =  (pec_spike_vld&&itlc_last_layer_or_not_r) ? pec_acc_dout:{`ACC_WIDTH{1'b0}};

endmodule
