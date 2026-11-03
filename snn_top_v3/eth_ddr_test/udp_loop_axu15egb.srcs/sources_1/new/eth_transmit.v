`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/07/23 17:00:14
// Design Name:
// Module Name: eth_transmit
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

`include "eth_defines.vh"

`define BUF_ADDR_COUNTER_WIDTH $clog2(`ETH_TX_READ_NUM_SINGLE)
`define TX_LENGTH `ETH_TX_READ_NUM_SINGLE

module eth_transmit(
    input                              rst_n,
    // connect to other modules
    input                              req_clk,
    input                              eth_transmit_req,
    output                             eth_transmit_rdy,
    output                             eth_transmit_done,
    output                             buf_read_en,
    output reg [`ETH_TX_RAM_INDEX-1:0] buf_read_addr,
    input      [`ETH_TX_APP_WIDTH-1:0] buf_read_data,
    input                              buf_read_data_vld,
    // connect to master_wrapper
    input                              app_clk,
    input                              udp_tx_ready,
    input                              app_tx_ack,
    output reg                         app_tx_data_request,
    output                             app_tx_data_valid,
    output     [`ETH_TX_APP_WIDTH-1:0] app_tx_data,
    output reg [7:0]                   app_tx_data_keep,
    output reg                         app_tx_data_last,
    output reg [15:0]                  app_tx_data_length
);

/******************************/

/*************** FSM variables ***************/
localparam IDLE=2'd0;
localparam WAIT_REQUEST=2'd1;
localparam WAIT_TX_ACK=2'd2;
localparam SEND_UDP_DATA=2'd3;

reg [1:0] STATE;
/******************************/

/*************** other model ***************/

// eth_transmit_req synchronization

// assume req_clk is 200m and app_clk is 15.625m, the difference is 12.8 times.
// fast to slow
reg [14:0] eth_transmit_req_dlys;
wire eth_transmit_req_or;
always@(posedge req_clk or negedge rst_n) begin
    if(!rst_n) begin
        eth_transmit_req_dlys<=15'b0;
    end
    else begin
        eth_transmit_req_dlys<={eth_transmit_req_dlys[13:0],eth_transmit_req};
    end
end
assign eth_transmit_req_or=|eth_transmit_req_dlys;

// delay and sync
reg eth_transmit_req_or_dly1,eth_transmit_req_or_dly2;
wire eth_transmit_req_sync;
always@(posedge app_clk or negedge rst_n) begin
    if(!rst_n) begin
        eth_transmit_req_or_dly1<=1'b0;
        eth_transmit_req_or_dly2<=1'b0;
    end
    else begin
        eth_transmit_req_or_dly1<=eth_transmit_req_or;
        eth_transmit_req_or_dly2<=eth_transmit_req_or_dly1;
    end
end
assign eth_transmit_req_sync=eth_transmit_req_or_dly2;

// posedge detect
reg eth_transmit_req_sync_dly;
wire eth_transmit_req_sync_posedge;
always@(posedge app_clk or negedge rst_n) begin
    if(!rst_n) begin
        eth_transmit_req_sync_dly<=1'b0;
    end
    else begin
        eth_transmit_req_sync_dly<=eth_transmit_req_sync;
    end
end
assign eth_transmit_req_sync_posedge=eth_transmit_req_sync&~eth_transmit_req_sync_dly;

// eth_transmit_ready
// need sync, slow to fast
reg udp_tx_ready_dly1,udp_tx_ready_dly2;
always@(posedge req_clk or negedge rst_n) begin
    if(!rst_n) begin
        udp_tx_ready_dly1<=1'b0;
        udp_tx_ready_dly2<=1'b0;
    end
    else begin
        udp_tx_ready_dly1<=udp_tx_ready;
        udp_tx_ready_dly2<=udp_tx_ready_dly1;
    end
end
assign eth_transmit_rdy=udp_tx_ready_dly2;

// eth_transmit_done
// need sync, slow to fast
reg send_frame_done_dly1,send_frame_done_dly2;
assign eth_transmit_done=send_frame_done_dly2;

// buf_read_en
reg app_tx_ack_lengthen;
reg [`BUF_ADDR_COUNTER_WIDTH-1:0] buf_read_addr_counter;
always@(posedge app_clk or negedge rst_n) begin
    if(!rst_n) begin
        app_tx_ack_lengthen<=1'b0;
    end
    else if(app_tx_ack) begin
        app_tx_ack_lengthen<=1'b1;
    end
    else if(buf_read_addr_counter==`ETH_TX_READ_NUM_SINGLE-1) begin
        app_tx_ack_lengthen<=1'b0;
    end
end
always@(posedge app_clk or negedge rst_n) begin
    if(!rst_n) begin
        buf_read_addr_counter<=`BUF_ADDR_COUNTER_WIDTH'b0;
    end
    else if(buf_read_en) begin
        if(buf_read_addr_counter==`ETH_TX_READ_NUM_SINGLE-1) begin
            buf_read_addr_counter<=`BUF_ADDR_COUNTER_WIDTH'b0;
        end
        else begin
            buf_read_addr_counter<=buf_read_addr_counter+1'b1;
        end
    end
end

assign buf_read_en=app_tx_ack|app_tx_ack_lengthen;

// buf_read_addr
always@(posedge app_clk or rst_n) begin
    if(!rst_n) begin
        buf_read_addr<=`ETH_TX_RAM_INDEX'b0;
    end
    else if(buf_read_en) begin
        if(buf_read_addr[`ETH_TX_RAM_ADDR_INDEX-1:0]==`ETH_TX_RAM_DEPTH-1) begin
            buf_read_addr[`ETH_TX_RAM_ADDR_INDEX-1:0]<=`ETH_TX_RAM_ADDR_INDEX'b0;
            // buf_read_addr[`ETH_TX_RAM_ADDR_INDEX+:`ETH_TX_RAM_SEL_INDEX]<=buf_read_addr[`ETH_TX_RAM_ADDR_INDEX+:`ETH_TX_RAM_SEL_INDEX]+1'b1;
        end
        else begin
            buf_read_addr[`ETH_TX_RAM_ADDR_INDEX-1:0]<=buf_read_addr[`ETH_TX_RAM_ADDR_INDEX-1:0]+1'b1;
        end
    end
end
/******************************/


/*************** eth app ***************/
// app_tx_data_valid
assign app_tx_data_valid=buf_read_data_vld;
// app_tx_data
assign app_tx_data=buf_read_data_vld;
/******************************/




/*************** FSM ***************/
reg [15:0] send_data_cnt;
reg [7:0]  send_frame_cnt;
reg        send_frame_done;
always@(posedge app_clk or negedge rst_n) begin
    if(!rst_n) begin
        app_tx_data_request<=1'b0;
        app_tx_data_length<=16'b0;

        app_tx_data_last<=1'b0;
        app_tx_data_keep<=8'b0;

        STATE<=WAIT_ACK;

        send_data_cnt<=32'b0;
        send_frame_cnt<=8'b0;
        send_frame_done<=1'b0;
    end
    else begin
        case(STATE)
            IDLE: begin
                app_tx_data_last<=1'b0;
                app_tx_data_keep<=8'hFF;
                send_frame_done<=1'b0;
                STATE<=WAIT_REQUEST;
            end
            WAIT_REQUEST: begin
                if(eth_transmit_req_sync_posedge) begin
                    STATE<=WAIT_TX_ACK;
                end
            end
            WAIT_TX_ACK: begin
                if(app_tx_ack) begin
                    app_tx_data_request<=1'b0;
                    send_data_cnt<=send_data_cnt+8'd8;

                    STATE<=SEND_UDP_DATA;
                end
                else begin
                    if(udp_tx_ready) begin
                        app_tx_data_request<=1'b1;
                        app_tx_data_length<=`TX_LENGTH;
                        app_tx_data_keep<=8'hFF;
                    end
                    STATE<=WAIT_TX_ACK;
                end
            end
            SEND_UDP_DATA: begin
                send_data_cnt<=send_data_cnt+1'b1;
                if(send_data_cnt+8'd8>=`TX_LENGTH) begin
                    app_tx_data_last<=1'b1;
                    app_tx_data_keep<=(8'hFF>>(send_data_cnt+4'd8-`TX_LENGTH));
                    if(send_frame_cnt==`ETH_TX_FRAME_NUM-1) begin
                        send_frame_cnt<=8'b0;
                        send_frame_done<=1'b1;
                        STATE<=IDLE;
                    end
                    else begin
                        send_frame_cnt<=send_frame_cnt+1'b1;
                        STATE<=WAIT_TX_ACK;
                    end
                end
            end
        endcase
    end
end

// send_frame_done
always@(posedge req_clk or negedge rst_n) begin
    if(!rst_n) begin
        send_frame_done_dly1<=1'b0;
        send_frame_done_dly2<=1'b0;
    end
    else begin
        send_frame_done_dly1<=send_frame_done;
        send_frame_done_dly2<=send_frame_done_dly1;
    end
end
/******************************/

endmodule
