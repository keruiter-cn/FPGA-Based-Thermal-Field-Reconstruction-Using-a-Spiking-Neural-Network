`timescale 1ns / 1ps
`include "proj_snn.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2024 04:53:13 PM
// Design Name:
// Module Name: ilc
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


module ilc(
input                                       clk,
input                                       rst_n,
/***************global signal***/
output                                      ilc_ena,
/***************eth ************/
input   wire                                eth_write_ddr_done,
input   wire                                eth_write_fms_done,
input   wire                                eth_read_fms_done,
output  reg                                 eth_fms_read_req,
/**************ddr*************/
output  reg                                 ddr_weight_init,
output                                      ddr_weight_rd_req,
output          [`DDR_INDEX-1:0]            ddr_weight_rd_addr,
output          [`DDR_INDEX-1:0]            ddr_weight_rd_len,
output          [`DDR_INDEX-1:0]            ddr_brm_wr_addr,
input                                       ddr_brm_wr_done,
/*************pec**************/
output          [5-1:0]                     pec_brm_cs,
output                                      pec_enable,
output   reg                                pec_ping_pong,
output          [`THRESHOLD_WIDTH-1:0]      pec_threshold,
output          [4:0]                       pec_in_ch_num,
output          [4:0]                       pec_weight_buffer_cs,
output          [`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH-1:0]   pec_bias,
/*************brc**************/
output  reg                                 brc_read_start,
input                                       brc_slide_over_dly,
input                                       brc_uram_half_finish,
input                                       brc_ts_end_dly,
//input                                       ilc_cat_half_finish,
output           [`SHIFT_WIDTH-1:0]         ilc_shift_value,
output                                      ilc_padding_or_not,
output          [8-1:0]                     ilc_fms_len,
/************bwc***************/
output          [`OUTCH_NUM_WIDTH-1:0]      itlc_out_ch_num,
output                                      itlc_sp_padding,
input                                       bwc_sp_pad_slide_over,
/***********fms****************/
output                                      fms_eth_ping_pong,
output                                      fms_ping_pong,
output                                      fms_brc_u_or_b,
output                                      fms_bwc_u_or_b,
output          [`URAM_INDEX-1:0]           fms_uram_base_addr,
/***********itlc***************/
output                                      itlc_vld,
output                                      itlc_first_layer_or_not,
output                                      itlc_last_layer_or_not,
output                                      itlc_bias_or_not,
output                                      itlc_conv_or_not,
output                                      itlc_convt_or_not,
output                                      itlc_concat_or_not,
output                                      itlc_avgpool_or_not,
output                                      itlc_sp_pool,
output                                      itlc_reset,
/**********************for test ****************************/
output reg [`LAYER_INDEX-1:0]      layer_cnt
    );
/************brm to store interlayer information******/
localparam      LAYER_BRM_WIDTH     =   95;

//reg     [`LAYER_INDEX-1:0]      layer_cnt;

wire            [`LAYER_INDEX-1:0]          layer_brm_rd_index;
wire                                        layer_brm_rd_en;

wire    [LAYER_BRM_WIDTH-1:0]               brm_rd_data;

wire            [15:0]                      weight_rd_distance  ;
wire                                        conv_or_not         ;
wire                                        convt_or_not        ;
wire                                        first_layer_or_not  ;
wire                                        last_layer_or_not   ;
wire                                        bias_or_not         ;
wire                                        avg_pool_or_not     ;
wire                                        cat_or_not          ;
wire            [7:0]                       out_ch_num          ;
wire            [8-1:0]                     in_ch_num           ;
wire            [32-1:0]                    uram_start_addr     ;
wire                                        write_uram          ;
wire                                        read_uram           ;
wire            [3:0]                       shift_value         ;
wire            [7:0]                       fms_len             ;
wire            [7:0]                       fms_len_next        ;

`ifdef UNET
unet_control u_unet_control(
  .clka(clk),    // input wire clka
  .ena(layer_brm_rd_en),      // input wire ena
  .wea('d0),      // input wire [0 : 0] wea
  .addra(layer_brm_rd_index),  // input wire [4 : 0] addra
  .dina('d0),    // input wire [76 : 0] dina
  .douta(brm_rd_data)  // outputstart wire [76 : 0] douta
);
`else
segnet_control u_segnet_control(
  .clka(clk),    // input wire clka
  .ena(layer_brm_rd_en),      // input wire ena
  .wea('d0),      // input wire [0 : 0] wea
  .addra(layer_brm_rd_index),  // input wire [4 : 0] addra
  .dina('d0),    // input wire [76 : 0] dina
  .douta(brm_rd_data)  // outputstart wire [76 : 0] douta
);
`endif
//dram_unet_control u_unet_control (
//  .a(layer_brm_rd_index),        // input wire [4 : 0] a
//  .d('d0),        // input wire [94 : 0] d
//  .clk(clk),    // input wire clk
//  .we(1'd0),      // input wire we
//  .qspo(brm_rd_data)  // output wire [94 : 0] qspo
////);
//reg             [LAYER_BRM_WIDTH-1:0]                    r0_brm_rd_data;
//always@(posedge clk or negedge rst_n)begin
//    if(!rst_n)begin
//        r0_brm_rd_data<='d0;
//    end else begin
//        if(layer_brm_rd_en)
//            r0_brm_rd_data <= brm_rd_data;
//         else
//            r0_brm_rd_data <= r0_brm_rd_data;
//    end
//end
reg                                         layer_brm_rd_en_dly;
reg             [LAYER_BRM_WIDTH-1:0]                    r_brm_rd_data;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_brm_rd_data   <=  'd0;
    end else begin
        if(layer_brm_rd_en)
            r_brm_rd_data   <=  brm_rd_data;
    end
end

assign  {first_layer_or_not,last_layer_or_not,bias_or_not,conv_or_not,convt_or_not,cat_or_not,avg_pool_or_not,out_ch_num,shift_value,write_uram,read_uram,uram_start_addr,in_ch_num,fms_len,fms_len_next}    =   r_brm_rd_data[LAYER_BRM_WIDTH-9*2-1:0];
//brm for threshold
`ifdef UNET
wire            [`WEIGHT_WIDTH-1:0]         threshold           =   'b0001000000000000;
`else
wire            [`WEIGHT_WIDTH-1:0]         threshold           =   'b0001000000000000;
`endif

//brm for bias
wire            [`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH-1:0]   bias    ;
wire                                        bias_read_en;
reg            [4:0]                        bias_read_addr;

//bias_bram u_bias_bram(
//  .clka(clk),    // input wire clka
//  .ena(1'b1),      // input wire ena
//  .wea(1'd0),      // input wire [0 : 0] wea
//  .addra(bias_read_addr),  // input wire [4 : 0] addra
//  .dina('d0),    // input wire [511 : 0] dina
//  .douta(bias)  // output wire [511 : 0] douta
//);
`ifdef UNET
dram_bias_ram u_bias_bram (
  .a(bias_read_addr),        // input wire [4 : 0] a
  .d('d0),        // input wire [511 : 0] d
  .clk(clk),    // input wire clk
  .we(1'd0),      // input wire we
  .qspo(bias)  // output wire [511 : 0] qspo
);
`else
dram_segnet_bias_ram u_bias_bram (
  .a(bias_read_addr),        // input wire [4 : 0] a
  .d('d0),        // input wire [511 : 0] d
  .clk(clk),    // input wire clk
  .we(1'd0),      // input wire we
  .qspo(bias)  // output wire [511 : 0] qspo
);
`endif

//fsm
localparam          S_IDLE              =   'h0     ;
localparam          S_INIT_WEIGHT       =   'h1     ;
localparam          S_INIT_FMS          =   'h2     ;
localparam          S_INIT_MOVE_WEIGHT  =   'h3     ;
localparam          S_ITLC              =   'h4     ;
localparam          S_MOVE_WEIGHT       =   'h5     ;
localparam          S_WAIT_WEIGHT       =   'h6     ;
localparam          S_WAIT_INFER        =   'h7     ;
localparam          S_OUT_FMS           =   'h8     ;
reg     [3:0]                   cur_state;
assign              itlc_reset          =   cur_state==S_OUT_FMS&next_state==S_INIT_FMS;
reg     [3:0]                   next_state;
//other reg for jump
reg     [4:0]                   weight_write_brm_cnt;
reg     [`OUTCH_NUM_WIDTH-1:0]  out_ch_cnt;
wire                            slide_over;
assign                          slide_over  =   itlc_sp_padding ? bwc_sp_pad_slide_over : brc_slide_over_dly;
assign  weight_rd_distance = {{7{1'b0}},cur_state==S_INIT_MOVE_WEIGHT ? brm_rd_data[LAYER_BRM_WIDTH-1-:9]: out_ch_cnt==out_ch_num-1'b1 ? r_brm_rd_data[LAYER_BRM_WIDTH-1-9-:9] : r_brm_rd_data[LAYER_BRM_WIDTH-1-:9]};//if we read next layer, we use r_brm_[next_layer_distacnce],or we use
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
       cur_state   <=  S_IDLE;
    end
    else begin
        cur_state   <=  next_state;
    end
end
always@(*)begin
    case(cur_state)
        S_IDLE:begin
            next_state  =   S_INIT_WEIGHT;
        end
        S_INIT_WEIGHT:begin
            if(eth_write_ddr_done)
                next_state  =   S_INIT_FMS;
            else
                next_state  =   cur_state;
        end
        S_INIT_FMS:begin
            if(eth_write_fms_done)
                next_state  =   S_INIT_MOVE_WEIGHT;
            else
                next_state  =   cur_state;
        end
        S_INIT_MOVE_WEIGHT:begin
            if(ddr_brm_wr_done&weight_write_brm_cnt==32-1)
                next_state  =   S_ITLC;
            else
                next_state  =   cur_state;
        end
        S_ITLC:begin
            if(!itlc_avgpool_or_not)
                next_state      =   S_MOVE_WEIGHT;
            else
                next_state      =   S_WAIT_INFER;
        end
        S_MOVE_WEIGHT:begin
            if(ddr_brm_wr_done&weight_write_brm_cnt==32-1)//write done weight
                next_state  =   S_WAIT_INFER;
            else if(slide_over)//after infer
                next_state  =   S_WAIT_WEIGHT;
            else
                next_state  =   cur_state;
        end
        S_WAIT_WEIGHT:begin
            if(ddr_brm_wr_done&weight_write_brm_cnt==32-1)//write done weight
                if(out_ch_cnt==out_ch_num-1)begin//layer over
                    if(layer_cnt==`LAYER_NUM)begin
                        next_state  =   S_OUT_FMS;
                    end else begin
                        next_state  =   S_ITLC;
                    end
                end else begin
                    next_state  =   S_MOVE_WEIGHT;//layer no over, continue infer
                end
            else next_state = cur_state;
        end
        S_WAIT_INFER:begin
            if(slide_over)
                if(out_ch_cnt==out_ch_num-1)begin
                    if(layer_cnt==`LAYER_NUM)begin
                        next_state  =   S_OUT_FMS;
                    end else begin
                        next_state  =   S_ITLC;
                    end
                end else begin
                    if(!itlc_avgpool_or_not)begin
                        next_state  =   S_MOVE_WEIGHT;
                    end else begin
                        next_state  =   cur_state;
                    end
                end
            else next_state  =   cur_state;
        end
        S_OUT_FMS:begin
            if(eth_read_fms_done)
                next_state  =   S_INIT_FMS;
            else
                next_state  =   cur_state;
        end
        default:
            next_state  =   S_IDLE;
    endcase
end
//init signal
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        ddr_weight_init         <=  1'b0;
    end
    else begin
        if(cur_state==S_IDLE&next_state==S_INIT_WEIGHT)begin
            ddr_weight_init     <=  1'b1;
        end
        else begin
            ddr_weight_init     <=  1'b0;
        end
    end
end
//weight update
reg     [`DDR_INDEX-1:0]        weight_base_addr;
reg                             write_weight_flg,write_weight_vld;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        write_weight_vld        <=  1'b0;
        write_weight_flg        <=  1'b0;
    end else begin
        if(cur_state==S_INIT_MOVE_WEIGHT|cur_state==S_MOVE_WEIGHT|cur_state==S_WAIT_WEIGHT)begin
            //flg
            if(write_weight_vld)
                write_weight_flg    <=  1'b1;
            else if(ddr_brm_wr_done)
                write_weight_flg    <=  1'b0;
            else
                write_weight_flg    <=  write_weight_flg;
            //vld
            if(!write_weight_flg&!write_weight_vld)
                write_weight_vld    <=  1'b1;
            else
                write_weight_vld    <=  1'b0;
        end else
        begin
            write_weight_flg        <=  1'b0;
            write_weight_vld        <=  1'b0;
        end
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        weight_write_brm_cnt     <=  'd0     ;
    end else
    begin
        if(ddr_brm_wr_done&weight_write_brm_cnt!=31)
            weight_write_brm_cnt <=  weight_write_brm_cnt +   1'b1;
        else if(ddr_brm_wr_done&weight_write_brm_cnt==31)
            weight_write_brm_cnt <=  'd0     ;
        else
            weight_write_brm_cnt <=  weight_write_brm_cnt;
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        weight_base_addr        <=  'd0     ;
    end else
    begin
        if(cur_state == S_OUT_FMS)
            weight_base_addr <= 'd0;
        else if(ddr_brm_wr_done)
            weight_base_addr    <=  weight_base_addr    +   (weight_rd_distance<<3);
        else 
            weight_base_addr   <=  weight_base_addr;
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        pec_ping_pong   <=  1'b0;
    end else begin
        if(cur_state == S_OUT_FMS)
            pec_ping_pong   <=  1'b0;
        else if(cur_state!=S_MOVE_WEIGHT&next_state==S_MOVE_WEIGHT)begin
            pec_ping_pong   <=  !pec_ping_pong;
        end
    end
end
//start infer
reg     r_brc_sp_padding_slide_over;
// equa slide over and ts end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_brc_sp_padding_slide_over   <=  1'b0;
    end else begin
        if(brc_slide_over_dly&brc_ts_end_dly&itlc_sp_padding)
            r_brc_sp_padding_slide_over   <=  1'b1;
        else if(bwc_sp_pad_slide_over)
            r_brc_sp_padding_slide_over   <=  1'b0;
        else
            r_brc_sp_padding_slide_over   <=  r_brc_sp_padding_slide_over;  
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        brc_read_start  <=  1'b0;
    end else begin
        brc_read_start  <=  itlc_sp_padding? 
            ((cur_state==S_WAIT_WEIGHT&next_state==S_MOVE_WEIGHT)//finish infer and restart reading 
            |((r_brc_sp_padding_slide_over ? bwc_sp_pad_slide_over : brc_ts_end_dly&!brc_slide_over_dly)&next_state!=S_WAIT_WEIGHT&next_state!=S_OUT_FMS&&next_state!=S_ITLC) //normal situation
            |(cur_state==S_ITLC)&(next_state  !=  S_ITLC))//start infer        
        :   (cur_state==S_WAIT_WEIGHT&next_state==S_MOVE_WEIGHT)//finish infer and restart reading 
            |(brc_ts_end_dly&next_state!=S_WAIT_WEIGHT&next_state!=S_OUT_FMS&&next_state!=S_ITLC) //normal situation
            |(cur_state==S_ITLC)&(next_state  !=  S_ITLC);//start infer
    end
end
//out ch cnt
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        out_ch_cnt  <=  'd0;
    end else begin
        if((slide_over&next_state!=S_WAIT_WEIGHT)|(cur_state==S_WAIT_WEIGHT&next_state!=S_WAIT_WEIGHT))begin
            if(out_ch_cnt==out_ch_num-1'd1)
                out_ch_cnt  <=  'd0;
            else
                out_ch_cnt  <=  out_ch_cnt + 1'b1;
        end
        else
            out_ch_cnt  <= out_ch_cnt;
    end
end
//layer cnt
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        layer_cnt   <=  'd0;
    end else begin
        if(cur_state==S_ITLC)
            layer_cnt   <=  layer_cnt   +1'd1;
        else if(cur_state!=S_OUT_FMS&next_state==S_OUT_FMS)
            layer_cnt   <=  'd0;
        else
            layer_cnt   <=  layer_cnt;
    end
end

assign      layer_brm_rd_index  =   (cur_state!=S_INIT_MOVE_WEIGHT&next_state==S_INIT_MOVE_WEIGHT)?'d0:layer_cnt+1'b1;
assign      layer_brm_rd_en     =   (cur_state!=S_ITLC&next_state==S_ITLC)|(cur_state!=S_INIT_MOVE_WEIGHT&next_state==S_INIT_MOVE_WEIGHT);

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        layer_brm_rd_en_dly     <=  1'd0;
    end else begin
        layer_brm_rd_en_dly     <=  layer_brm_rd_en;
    end
end

assign      bias_read_en        =   slide_over&bias_or_not;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        bias_read_addr  <=  'd0;
    end else begin
        if(next_state==S_INIT_FMS)
            bias_read_addr  <=  'd0;
        else if(bias_read_en)
            bias_read_addr  <=  bias_read_addr  +   1'd1;
        else
            bias_read_addr  <=  bias_read_addr;
    end
end
//fms ping pong and uram or bram
reg         fms_ping_pong_reg;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        fms_ping_pong_reg       <=  1'b0;
    end else begin
        if(cur_state==S_INIT_FMS)
            fms_ping_pong_reg   <=  fms_eth_ping_pong;
        else if(cur_state!=S_INIT_MOVE_WEIGHT&next_state==S_ITLC)
            fms_ping_pong_reg   <=  !fms_ping_pong_reg;
        else
            fms_ping_pong_reg   <=  fms_ping_pong_reg;
    end
end
reg         fms_uram_flg;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        fms_uram_flg    <=  1'd0;
    end else begin
        if(itlc_vld)
            fms_uram_flg    <=  read_uram;
        else if(brc_uram_half_finish)
            fms_uram_flg    <=  1'd0;
    end
end
//read fms to eth
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        eth_fms_read_req    <=  1'b0;
    else
        eth_fms_read_req    <=  cur_state!=S_OUT_FMS & next_state==S_OUT_FMS;
end
assign  ilc_ena                 =   1'b1;
assign  ilc_shift_value         =   shift_value;
assign  ilc_padding_or_not      =   conv_or_not&!itlc_last_layer_or_not;
assign  ilc_fms_len             =   fms_len;


assign  itlc_vld                =   cur_state==S_ITLC;
assign  itlc_first_layer_or_not =   first_layer_or_not;
assign  itlc_last_layer_or_not  =   last_layer_or_not;
assign  itlc_bias_or_not        =   bias_or_not;
assign  itlc_conv_or_not        =   conv_or_not;
assign  itlc_convt_or_not       =   convt_or_not;
assign  itlc_concat_or_not      =   'b0;
assign  itlc_avgpool_or_not     =   avg_pool_or_not;
assign  itlc_out_ch_num         =   out_ch_num -1'b1;
`ifdef UNET 
assign  itlc_sp_padding         =   layer_cnt=='d15;
assign  itlc_sp_pool            =   layer_cnt=='d12;
`else 
assign  itlc_sp_padding         =   1'b0;
assign  itlc_sp_pool            =   1'b0;
`endif
assign  ddr_weight_rd_req       =   write_weight_vld;
assign  ddr_weight_rd_len       =   weight_rd_distance;
assign  ddr_brm_wr_addr         =   'd0;
assign  ddr_weight_rd_addr      =   weight_base_addr;

assign  pec_threshold           =   threshold;
assign  pec_in_ch_num           =   in_ch_num - 1'b1;
assign  pec_brm_cs              =   weight_write_brm_cnt;
assign  pec_enable              =   1'b1;
assign  pec_weight_buffer_cs    =   weight_write_brm_cnt;
assign  pec_bias                =   bias&{`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH{itlc_bias_or_not}};
`ifdef UNET
assign  fms_eth_ping_pong       =   cur_state == S_OUT_FMS ? 1'b1: 1'b0;
`else
assign  fms_eth_ping_pong       =   cur_state == S_OUT_FMS ? 1'b1: 1'b0;
`endif
assign  fms_ping_pong           =   fms_ping_pong_reg;
assign  fms_brc_u_or_b          =   !(read_uram&fms_uram_flg);
assign  fms_bwc_u_or_b          =   !write_uram;
assign  fms_uram_base_addr      =   uram_start_addr;

endmodule
