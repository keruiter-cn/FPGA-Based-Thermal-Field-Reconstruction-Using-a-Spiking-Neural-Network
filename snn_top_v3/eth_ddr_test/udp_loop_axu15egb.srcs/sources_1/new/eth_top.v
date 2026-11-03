`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/07/24 15:01:44
// Design Name:
// Module Name: eth_top
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


module eth_top(
    input rst_n,
    // connect to other modules
    // TX
    input                          itlc_eth_clk,
    input                          itlc_fms_read_req,
    output                         itlc_eth_rdy,
    output                         itlc_eth_read_fms_done,
    output                         fms_read_en,
    output [`ETH_TX_RAM_INDEX-1:0] fms_read_addr,
    input  [`ETH_TX_APP_WIDTH-1:0] fms_read_data,
    input                          fms_read_data_vld,
    // RX
    input                          ddr_weight_rd_clk,
    input                          ddr_weight_rd_en,
    output [`DDR_WIDTH-1:0]        ddr_weight_data,
    output                         ddr_weight_empty,
    output                         itlc_eth_write_ddr_done,

    output                         fms_write_clk,
    output [`ETH_RX_RAM_INDEX-1:0] fms_write_addr,
    output [`ETH_RX_APP_WIDTH-1:0] fms_write_data,
    output                         fms_write_data_vld,
    output                         itlc_eth_write_fms_done,
    // connect to phy
    output                         phy_rst_n,
    input  [3:0]                   phy_rgmii_rxd,
    input                          phy_rgmii_rx_ctl,
    input                          phy_rgmii_rxc,
    output [3:0]                   phy_rgmii_txd,
    output                         phy_rgmii_tx_ctl,
    output                         phy_rgmii_txc,
    // eth_ip
    input                          clk_15_625,
    input                          clk_333_33,
    input                          clk_125,
    input                          locked
);


/*************** master_wrapper ***************/
wire            core_reset;

wire            udp_tx_ready;
wire            app_tx_ack;
wire            app_tx_data_request;
wire            app_tx_data_valid;
wire [63:0]     app_tx_data;
wire [7:0]      app_tx_data_keep;
wire            app_tx_data_last;
wire [15:0]     app_tx_data_length;

wire            dst_ip_unreachable;

wire            app_rx_data_valid;
wire [63:0]     app_rx_data;
wire [7:0]      app_rx_data_keep;
wire            app_rx_data_last;
wire [15:0]     app_rx_data_length;
wire [15:0]     app_rx_port_num;

master_wrapper master_wrapper_inst(
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

    .rgmii_rxd           (phy_rgmii_rxd),
    .rgmii_rx_ctl        (phy_rgmii_rx_ctl),
    .rgmii_rxc           (phy_rgmii_rxc),

    .rgmii_txd           (phy_rgmii_txd),
    .rgmii_tx_ctl        (phy_rgmii_tx_ctl),
    .rgmii_txc           (phy_rgmii_txc)
);
/******************************/

/*************** eth_transmit ***************/
eth_transmit eth_transmit_inst(
    .rst_n(rst_n),
    // connect to other modules
    .req_clk(itlc_eth_clk),
    .eth_transmit_req(itlc_fms_read_req),
    .eth_transmit_rdy(itlc_eth_rdy),
    .eth_transmit_done(itlc_eth_read_fms_done),
    .buf_read_en(fms_read_en),
    .buf_read_addr(fms_read_addr),
    .buf_read_data(fms_read_data),
    .buf_read_data_vld(fms_read_data_vld),
    // connect to master_wrapper
    .app_clk(clk_15_625),
    .udp_tx_ready(udp_tx_ready),
    .app_tx_ack(app_tx_ack),
    .app_tx_data_request(app_tx_data_request),
    .app_tx_data_valid(app_tx_data_valid),
    .app_tx_data(app_tx_data),
    .app_tx_data_keep(app_tx_data_keep),
    .app_tx_data_last(app_tx_data_last),
    .app_tx_data_length(app_tx_data_length)
);
/******************************/

/*************** eth_receive ***************/
// itlc_eth_write_ddr_done
wire fifo_read_done;
slow_to_fast fifo_read_done_sync(
    .rst_n(rst_n),

    .slow_signal(fifo_read_done),

    .fast_clk(itlc_eth_clk),
    .fast_signal(itlc_eth_write_ddr_done),
    .fast_signal_posedge()
);
// itlc_eth_write_ddr_done
wire bram_write_done;
slow_to_fast bram_write_done_sync(
    .rst_n(rst_n),

    .slow_signal(bram_write_done),

    .fast_clk(itlc_eth_clk),
    .fast_signal(),
    .fast_signal_posedge(itlc_eth_write_ddr_done)
);
eth_receive eth_receive_inst(
    .rst_n(rst_n),
    // connect to other modules
    .fifo_read_clk(ddr_weight_rd_clk),
    .fifo_read_en(ddr_weight_rd_en),
    .fifo_read_data(ddr_weight_data),
    .fifo_empty(ddr_weight_empty),
    .fifo_read_done_nosync(fifo_read_done),

    .bram_write_clk(fms_write_clk),
    .bram_write_addr(fms_write_addr),
    .bram_write_data(fms_write_data),
    .bram_write_data_vld(fms_write_data_vld),
    .bram_write_done(bram_write_done),
    // connect to master_wrapper
    .app_clk(clk_15_625),
    .app_rx_data_valid(app_rx_data_valid),
    .app_rx_data(app_rx_data),
    .app_rx_data_keep(app_rx_data_keep),
    .app_rx_data_last(app_rx_data_last),
    .app_rx_data_length(app_rx_data_length)
);
/******************************/
endmodule
