`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/07/22 21:05:30
// Design Name:
// Module Name: transmit
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

`define TX_LENGTH 64

module transmit(
    input          sysclk_p,
    input          sysclk_n,
    input          rst_n,
    output         phy_rst_o,
    //PHYA
    input [3:0]    PHYA_rgmii_rxd,
    input          PHYA_rgmii_rx_ctl,
    input          PHYA_rgmii_rxc,
    output[3:0]    PHYA_rgmii_txd,
    output         PHYA_rgmii_tx_ctl,
    output         PHYA_rgmii_txc
);

// clk
wire     clk_15_625;
wire     clk_333_33;
wire     clk_125;
wire     clk_25;
wire     clk_200m;
wire     locked;

clk_wiz_0 clk_wiz_0(
.clk_in1_p  (sysclk_p),
.clk_in1_n  (sysclk_n),
.clk_out1   (clk_15_625),
.clk_out2   (clk_333_33),
.clk_out3   (clk_125),
.clk_out4   (clk_25),
.clk_out5   (clk_200m),
.locked     (locked));

// phy rst
wire rstn;
assign rstn=rst_n&locked;
assign phy_rst_o=rstn;

// eth
wire core_reset;

wire            udp_tx_ready;
wire            app_tx_ack;
reg             app_tx_data_request;
reg             app_tx_data_valid;
reg  [63:0]     app_tx_data;
reg  [7:0]      app_tx_data_keep;
reg             app_tx_data_last;
reg  [15:0]     app_tx_data_length;

wire            dst_ip_unreachable;

wire            app_rx_data_valid;
wire [63:0]     app_rx_data;
wire [7:0]      app_rx_data_keep;
wire            app_rx_data_last;
wire [15:0]     app_rx_data_length;
wire [15:0]     app_rx_port_num;



master_wrapper master_wrapper_inst
(
.LOCAL_PORT_NUM      (16'd6002),
.LOCAL_IP_ADDRESS    (32'hc0a88902),
.LOCAL_MAC_ADDRESS   (48'h000a35000102),
.DST_PORT_NUM        (16'd6001),
.DST_IP_ADDRESS      (32'hc0a88901),
.ICMP_EN             (1'b1),
.ARP_REPLY_EN        (1'b1),
.ARP_REQUEST_EN      (1'b1),
.ARP_TIMEOUT_VALUE   (30'd20_000_000),
.ARP_RETRY_NUM       (4'd2),

.reset               (~rst_n),
.dcm_locked          (locked),
.refclk              (clk_333_33),
.udp_core_clk        (clk_15_625),
.gtx_clk             (clk_125),
.core_reset          (core_reset),

.udp_tx_ready        (udp_tx_ready),
.app_tx_ack          (app_tx_ack),

.app_tx_request      (app_tx_data_request),
.app_tx_data_valid   (app_tx_data_valid),
.app_tx_data         (app_tx_data),
.app_tx_data_keep    (app_tx_data_keep),
.app_tx_data_last    (app_tx_data_last),
.app_tx_data_length  (app_tx_data_length),
.dst_ip_unreachable  (dst_ip_unreachable),
.app_rx_data_valid   (app_rx_data_valid),
.app_rx_data         (app_rx_data),
.app_rx_data_keep    (app_rx_data_keep),
.app_rx_data_last    (app_rx_data_last),
.app_rx_data_length  (app_rx_data_length),
.app_rx_port_num     (app_rx_port_num),
.udp_rx_error        (),

.rgmii_rxd           (PHYA_rgmii_rxd),
.rgmii_rx_ctl        (PHYA_rgmii_rx_ctl),
.rgmii_rxc           (PHYA_rgmii_rxc),

.rgmii_txd           (PHYA_rgmii_txd),
.rgmii_tx_ctl        (PHYA_rgmii_tx_ctl),
.rgmii_txc           (PHYA_rgmii_txc)

);

localparam  WAIT_UDP_DATA   = 2'd0;
localparam  WAIT_ACK        = 2'd1;
localparam  SEND_UDP_DATA   = 2'd2;
localparam  DELAY           = 2'd3;

reg [1:0]       STATE;

reg [31:0]      send_data_cnt;

reg [63:0]      send_data;

always@(posedge clk_15_625 or negedge rstn) begin
    if(!rstn) begin
        app_tx_data_request<=1'b0;
        app_tx_data_length<=16'b0;

        app_tx_data_valid<=1'b0;
        app_tx_data<=64'd0;
        app_tx_data_last<=1'b0;
        app_tx_data_keep<=8'b0;

        STATE<=WAIT_ACK;

        send_data_cnt<=32'b0;

        send_data<=64'b0;
    end
    else begin
        case(STATE)
            SEND_UDP_DATA:
                begin
                    app_tx_data_valid<=1'b1;
                    app_tx_data<=send_data;
                    send_data_cnt<=send_data_cnt+1'b1;
                    if((send_data_cnt+8'd8)>=`TX_LENGTH) begin
                        app_tx_data_last<=1'b1;
                        STATE<=WAIT_UDP_DATA;
                    end
                    else begin
                        STATE<=SEND_UDP_DATA;
                    end
                end
            WAIT_UDP_DATA:
                begin
                    app_tx_data_valid<=1'b0;
                    app_tx_data_last<=1'b0;
                    send_data_cnt<=32'b0;
                    STATE<=WAIT_ACK;
                end

            WAIT_ACK:
                begin
                    if(app_tx_ack) begin
                        app_tx_data_request<=1'b0;
                        app_tx_data_valid<=1'b1;
                        app_tx_data<=send_data;
                        send_data_cnt<=send_data_cnt+8'd8;
                        send_data<=send_data+1'b1;

                        STATE<=SEND_UDP_DATA;
                    end
                    else begin
                        if(udp_tx_ready) begin
                            app_tx_data_request<=1'b1;
                            app_tx_data_length<=`TX_LENGTH;
                        end
                        STATE<=WAIT_ACK;
                        app_tx_data_valid<=1'b0;
                    end
                end
        endcase
    end
end


endmodule
