`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/07/23 17:00:14
// Design Name:
// Module Name: eth_receive
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

`include "proj_snn.vh"
`define ETH_RX_WEIGHT_COUNT_WIDTH $clog2(`ETH_RX_WEIGHT_NUM)
`define ETH_RX_FMS_COUNT_WIDTH $clog2(`ETH_RX_FMS_NUM)
module eth_receive(
    input rst_n,
    // connect to other models
    input                              fifo_read_clk,
    input                              fifo_read_en,
    output     [`DDR_WIDTH-1:0]        fifo_read_data,
    output                             fifo_empty,
    output                             fifo_read_done_nosync,

    output                             bram_write_clk,
    output reg [`ETH_RX_RAM_INDEX-1:0] bram_write_addr,
    output     [`ETH_RX_APP_WIDTH-1:0] bram_write_data,
    output                             bram_write_data_vld,
    output reg                         bram_write_done,
    // connect to master_wrapper
    input                              app_clk,
    input                              app_rx_data_valid,
    input     [`ETH_RX_APP_WIDTH-1:0]  app_rx_data,
    input     [7:0]                    app_rx_data_keep,
    input                              app_rx_data_last,
    input     [15:0]                   app_rx_data_length
);

/**************** data num counter & data storage select **************/
reg [`ETH_RX_WEIGHT_COUNT_WIDTH-1:0] eth_rx_weight_count;
reg data_storage_sel;
always@(posedge app_clk or negedge rst_n) begin
    if(!rst_n) begin
        eth_rx_weight_count<={`ETH_RX_WEIGHT_COUNT_WIDTH{1'b0}};
        data_storage_sel<=1'b0;
    end
    else if(app_rx_data_last) begin
        if(eth_rx_weight_count<`ETH_RX_WEIGHT_NUM) begin
            eth_rx_weight_count<=eth_rx_weight_count+app_rx_data_length;
        end
        if(eth_rx_weight_count+app_rx_data_length>`ETH_RX_WEIGHT_NUM) begin
            data_storage_sel<=1'b1;
        end
    end
end
/******************************/

/**************** fifo **************/
wire fifo_full;
// fifo_read_done
assign fifo_read_done_nosync=data_storage_sel&fifo_empty;
// fifo instance
// 1472bytes/8bytes=184<256
fifo_64b256bx256 weight_fifo(
  .wr_clk(app_clk),  // input wire wr_clk
  .rd_clk(fifo_read_clk),  // input wire rd_clk
  .din(app_rx_data),        // input wire [63 : 0] din
  .wr_en(app_rx_data_valid&~data_storage_sel),    // input wire wr_en
  .rd_en(fifo_read_en),    // input wire rd_en
  .dout(fifo_read_data),      // output wire [255 : 0] dout
  .full(fifo_full),      // output wire full
  .empty(fifo_empty)    // output wire empty
);
/******************************/

/**************** bram **************/
// bram_write_clk
assign bram_write_clk=app_clk;
// bram_write_addr
always@(posedge app_clk or negedge rst_n) begin
    if(!rst_n) begin
        bram_write_addr<={`ETH_RX_RAM_INDEX{1'b0}};
    end
    else if(bram_write_data_vld) begin
        if(bram_write_addr[`ETH_RX_RAM_ADDR_INDEX-1:0]==`ETH_RX_RAM_DEPTH-1) begin
            bram_write_addr[`ETH_RX_RAM_ADDR_INDEX-1:0]<={`ETH_RX_RAM_ADDR_INDEX{1'b0}};
            bram_write_addr[`ETH_RX_RAM_ADDR_INDEX+:`ETH_RX_RAM_SEL_INDEX]<=bram_write_addr[`ETH_RX_RAM_ADDR_INDEX+:`ETH_RX_RAM_SEL_INDEX]+1;
        end
        else begin
            bram_write_addr[`ETH_RX_RAM_ADDR_INDEX-1:0]<=bram_write_addr[`ETH_RX_RAM_ADDR_INDEX-1:0]+1'b1;
        end
    end
end

// bram_write_data & bram_write_vld
assign bram_write_data=app_rx_data;
assign bram_write_data_vld=app_rx_data_valid&data_storage_sel;

// bram_write_done
reg [`ETH_RX_FMS_COUNT_WIDTH:0] eth_rx_fms_count;
always@(posedge app_clk or negedge rst_n) begin
    if(!rst_n) begin
        eth_rx_fms_count<={`ETH_RX_FMS_COUNT_WIDTH{1'b0}};
        bram_write_done<=1'b0;
    end
    else if(app_rx_data_last&data_storage_sel) begin
        if(eth_rx_fms_count+app_rx_data_length<`ETH_RX_FMS_NUM) begin
            eth_rx_fms_count<=eth_rx_fms_count+app_rx_data_length;
        end
        else begin
            bram_write_done<=1'b1;
            eth_rx_fms_count<={`ETH_RX_FMS_COUNT_WIDTH{1'b0}};
        end
    end
    else begin
        bram_write_done<=1'b0;
    end
end
/******************************/

endmodule
