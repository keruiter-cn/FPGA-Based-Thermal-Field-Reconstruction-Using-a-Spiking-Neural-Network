`timescale  1ps/1ps
`include    "proj_snn.vh"
module tb_fms();
reg                                 clk                     =   1;
reg                                 clk_eth                 =   1;
reg                                 rst_n                   =   1;
reg                                 itlc_eth_ping_pong      =   0;
wire                                itlc_eth_ping_pong_ack  ;
reg     [`ETH_TX_RAM_INDEX-1:0]     eth_rx_addr             =   0;//eth clk
reg     [`ETH_TX_APP_WIDTH-1:0]     eth_rx_dt               =   0;
reg                                 eth_rx_dt_vld           =   0;
reg     [`ETH_TX_RAM_INDEX-1:0]     eth_tx_rd_addr          =   0;
reg                                 eth_tx_rd_en            =   0;
wire                                eth_tx_rd_vld           ;
wire     [`ETH_TX_APP_WIDTH-1:0]    eth_tx_rd_data          ;
wire     [`SPIKE_INCH_WIDTH-1:0]    brc_spike_out           ;
wire                                brc_spike_vld           ;
reg     [`FMS_RAM_INDEX-1:0]        brc_rd_addr             =   0;
reg                                 brc_rd_en               =   0;
reg     [`TS_INDEX-1:0]             brc_ts_cs               =   0;
reg                                 itlc_rd_ping_or_pong    =   0;//0 ping 1 pong
reg                                 itlc_brc_u_or_b         =   1;//1 b 0 u
reg                                 itlc_bwc_u_or_b         =   1;
reg     [`URAM_INDEX-1:0]           itlc_uram_base_addr     =   0;
reg                                 bwc_wr_en               =   0;
reg     [`FMS_RAM_INDEX-1:0]        bwc_wr_addr             =   0;
reg     [`TS_INDEX-1:0]             bwc_ts_cs               =   0;
reg     [`SPIKE_INCH_WIDTH-1:0]     bwc_spike_din           =   0;


fms u_fms(
.clk                    ( clk                             ),
.clk_eth                ( clk_eth                         ),
.rst_n                  ( rst_n                           ),
.itlc_eth_ping_pong     ( itlc_eth_ping_pong              ),
.itlc_eth_ping_pong_ack ( itlc_eth_ping_pong_ack          ),
.eth_rx_addr            ( eth_rx_addr                     ),
.eth_rx_dt              ( eth_rx_dt                       ),
.eth_rx_dt_vld          ( eth_rx_dt_vld                   ),
.eth_tx_rd_addr         ( eth_tx_rd_addr                  ),
.eth_tx_rd_en           ( eth_tx_rd_en                    ),
.eth_tx_rd_vld          ( eth_tx_rd_vld                   ),
.eth_tx_rd_data         ( eth_tx_rd_data                  ),
.brc_spike_out          ( brc_spike_out                   ),
.brc_spike_vld          ( brc_spike_vld                   ),
.brc_rd_addr            ( brc_rd_addr                     ),
.brc_rd_en              ( brc_rd_en                       ),
.brc_ts_cs              ( brc_ts_cs                       ),
.itlc_rd_ping_or_pong   ( itlc_rd_ping_or_pong            ),
.itlc_brc_u_or_b        ( itlc_brc_u_or_b                 ),
.itlc_bwc_u_or_b        ( itlc_bwc_u_or_b                 ),
.itlc_uram_base_addr    ( itlc_uram_base_addr             ),
.bwc_wr_en              ( bwc_wr_en                       ),
.bwc_wr_addr            ( bwc_wr_addr                     ),
.bwc_ts_cs              ( bwc_ts_cs                       ),
.bwc_spike_din          ( bwc_spike_din                   )

);

localparam  PERIOD      =   5000;
localparam  PERIOD_ETH  =   100000/15.625;

initial begin
    forever #(PERIOD/2) clk <=  !clk;
end
initial begin
    forever #(PERIOD_ETH/2) clk_eth <=  !clk_eth;
end

task    read_and_write;
input                           ping_pong;
input   [`FMS_RAM_INDEX-1:0]    addr;
input   [`SPIKE_INCH_WIDTH-1:0] data_in;
input   [`TS_INDEX-1:0]         ts_cs;
    begin
        @(posedge clk)
        #(PERIOD/2);
        itlc_rd_ping_or_pong    =   ping_pong;
        brc_ts_cs               =   ts_cs;
        brc_rd_addr             =   addr;
        brc_rd_en               =   1;

        bwc_wr_en               =   1;
        bwc_ts_cs               =   ts_cs;
        bwc_spike_din           =   data_in;

        #1
        @(posedge clk)
        #(PERIOD/2);
        itlc_rd_ping_or_pong    =   0;
        brc_ts_cs               =   0;
        brc_rd_addr             =   0;
        brc_rd_en               =   0;

        bwc_wr_en               =   0;
        bwc_ts_cs               =   0;
        bwc_spike_din           =   0;

    end
endtask
task    eth_write;
input                           ping_pong;
input   [`ETH_RX_RAM_INDEX-1:0]    addr;
input   [`ETH_RX_RAM_WIDTH-1:0] data_in;
    begin
        @(posedge clk)
        #(PERIOD/2);
        eth_rx_addr         = addr;
        eth_rx_dt           = data_in;
        eth_rx_dt_vld       = 1'b1;
        @(posedge clk)
        #(PERIOD/2);
        eth_rx_addr         = 'b0;
        eth_rx_dt           = 'b0;
        eth_rx_dt_vld       = 'b0;
    end
endtask
task    eth_read;
input                           ping_pong;
input   [`ETH_TX_RAM_INDEX-1:0]    addr;
    begin


        eth_tx_rd_vld      =
        @(posedge clk)
        #(PERIOD/2);
        eth_tx_rd_addr     =   addr;
        eth_tx_rd_en       =   1;
        @(posedge clk)
        #(PERIOD/2);
        eth_tx_rd_addr     =  'd0;
        eth_tx_rd_en       =   'd0;
    end
endtask
initial begin
    rst_n   =   0;
    #(300)
    rst_n   =   1;
    #(300)
    read_and_write(0,1,2,3);
    read_and_write(1,1,2,3);
end
endmodule
