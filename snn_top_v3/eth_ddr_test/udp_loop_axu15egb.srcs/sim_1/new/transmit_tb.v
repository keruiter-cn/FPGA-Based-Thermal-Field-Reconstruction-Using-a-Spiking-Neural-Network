`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/07/22 22:05:39
// Design Name:
// Module Name: transmit_tb
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


module transmit_tb();

reg clk_200m_p;
wire clk_200m_n;
assign clk_200m_n=~clk_200m_p;

initial begin
    clk_200m_p=0;
    forever begin
        #(2.5)
        clk_200m_p=~clk_200m_p;
    end
end

reg rst_n;

initial begin
    rst_n=0;
    #(200)
    rst_n=1;
end

wire     clk_15_625;
wire     clk_333_33;
wire     clk_125;
wire     clk_25;
wire     clk_200m;
wire     locked;

clk_wiz_0 clk_wiz_0(
.clk_in1_p  (clk_200m_p),
.clk_in1_n  (clk_200m_n),
.clk_out1   (clk_15_625),
.clk_out2   (clk_333_33),
.clk_out3   (clk_125),
.clk_out4   (clk_25),
.clk_out5   (clk_200m),
.locked     (locked));

wire phy_rst_o;
wire [3:0] PHYA_rgmii_rxd;
wire PHYA_rgmii_rx_ctl;
wire PHYA_rgmii_rxc;
wire [3:0] PHYA_rgmii_txd;
wire PHYA_rgmii_tx_ctl;
wire PHYA_rgmii_txc;

transmit transmit_inst(
    .sysclk_p(clk_200m_p),
    .sysclk_n(clk_200m_n),
    .rst_n(rst_n),
    .phy_rst_o(phy_rst_o),

    .PHYA_rgmii_rxd(PHYA_rgmii_rxd),
    .PHYA_rgmii_rx_ctl(PHYA_rgmii_rx_ctl),
    .PHYA_rgmii_rxc(PHYA_rgmii_rxc),
    .PHYA_rgmii_txd(PHYA_rgmii_txd),
    .PHYA_rgmii_tx_ctl(PHYA_rgmii_tx_ctl),
    .PHYA_rgmii_txc(PHYA_rgmii_txc)
);

wire            dst_ip_unreachable;
wire udp_rx_error;
master_wrapper master_wrapper_inst
(
.LOCAL_PORT_NUM      (16'd6001),
.LOCAL_IP_ADDRESS    (32'hc0a88901),
.LOCAL_MAC_ADDRESS   (48'h000a35000101),
.DST_PORT_NUM        (16'd6002),
.DST_IP_ADDRESS      (32'hc0a88902),
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

.app_tx_request      (0),
.app_tx_data_valid   (0),
.app_tx_data         (0),
.app_tx_data_keep    (0),
.app_tx_data_last    (0),
.app_tx_data_length  (0),

.dst_ip_unreachable  (dst_ip_unreachable),
.udp_rx_error        (),

.rgmii_rxd           (PHYA_rgmii_txd),
.rgmii_rx_ctl        (PHYA_rgmii_tx_ctl),
.rgmii_rxc           (PHYA_rgmii_txc),

.rgmii_txd           (PHYA_rgmii_rxd),
.rgmii_tx_ctl        (PHYA_rgmii_rx_ctl),
.rgmii_txc           (PHYA_rgmii_rxc)

);

endmodule
