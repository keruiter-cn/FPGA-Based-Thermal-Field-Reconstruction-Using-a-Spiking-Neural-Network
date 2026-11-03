`timescale 1ns / 1ps
`include "proj_snn.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: iot-x
// Engineer: Haodong Fan
// 
// Create Date: 07/22/2024 07:01:23 PM
// Design Name: fms
// Module Name: fms
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
module fms(
input                                   clk,
input                                   clk_eth,
input                                   rst_n,
input                                   itlc_eth_ping_pong,
output                                  itlc_eth_ping_pong_ack,
input       [`ETH_TX_RAM_INDEX-1:0]     eth_rx_addr,//eth clk
input       [`ETH_TX_APP_WIDTH-1:0]     eth_rx_dt,
input                                   eth_rx_dt_vld,
input       [`ETH_TX_RAM_INDEX-1:0]     eth_tx_rd_addr,
input                                   eth_tx_rd_en,
output  reg                             eth_tx_rd_vld,
output      [`ETH_TX_APP_WIDTH-1:0]     eth_tx_rd_data,
output      [`SPIKE_INCH_WIDTH-1:0]     brc_spike_out,
output                                  brc_spike_vld,
input       [`FMS_RAM_INDEX-1:0]        brc_rd_addr,
input                                   brc_rd_en,
input       [`TS_INDEX-1:0]             brc_ts_cs,
input                                   itlc_rd_ping_or_pong,
input                                   itlc_brc_u_or_b,//1 b 0 u
input                                   itlc_bwc_u_or_b,
input       [`URAM_INDEX-1:0]           itlc_uram_base_addr,
input                                   bwc_wr_en,
input       [`FMS_RAM_INDEX-1:0]        bwc_wr_addr,
input       [`TS_INDEX-1:0]             bwc_ts_cs,
input       [`SPIKE_INCH_WIDTH-1:0]     bwc_spike_din          
    );

//fms bram array
/****eth clk domain control*****/
//cross clk domain
reg     [2:0]       r_itlc_eth_ping_pong;
reg     [1:0]       r_itlc_eth_ping_pong_ack;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_itlc_eth_ping_pong[0]     <=  1'b0;
    end else begin
        r_itlc_eth_ping_pong[0]     <=  itlc_eth_ping_pong;
    end
end
always@(posedge clk_eth or negedge rst_n)begin
    if(!rst_n)begin
        r_itlc_eth_ping_pong[2:1]   <=  1'b0;
    end else begin
        r_itlc_eth_ping_pong[2:1]   <=  r_itlc_eth_ping_pong[1:0];
    end
end
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_itlc_eth_ping_pong_ack    <=  2'b0;
    end begin
        r_itlc_eth_ping_pong_ack    <=  {r_itlc_eth_ping_pong_ack[0],r_itlc_eth_ping_pong[2]};
    end
end
assign  itlc_eth_ping_pong_ack      =   r_itlc_eth_ping_pong_ack[1];
integer i;
//stage 1 , generate wea , ena and addr
reg     [`TIMESTEP-1:0]                     w_eth_ping_ena;
reg     [`TIMESTEP-1:0]                     w_eth_pong_ena;
reg     [`TIMESTEP-1:0]                     w_eth_ping_wea;
reg     [`TIMESTEP-1:0]                     w_eth_pong_wea;
wire    [`ETH_TX_RAM_ADDR_INDEX-1:0]        w_eth_addr;
always@(*)begin
    for(i=0;i<`TIMESTEP;i=i+1)begin
        w_eth_ping_ena[i]   =   r_itlc_eth_ping_pong[2]&(eth_rx_dt_vld|eth_tx_rd_en)&(eth_rx_addr[`ETH_TX_RAM_INDEX-1-:3]==i);
        w_eth_pong_ena[i]   =   (!r_itlc_eth_ping_pong[2])&(eth_rx_dt_vld|eth_tx_rd_en)&(eth_rx_addr[`ETH_TX_RAM_INDEX-1-:3]==i);
        w_eth_ping_wea[i]   =   r_itlc_eth_ping_pong[2]&eth_rx_dt_vld&eth_rx_addr[`ETH_TX_RAM_INDEX-1-:3]==i;
        w_eth_pong_wea[i]   =   (!r_itlc_eth_ping_pong[2])&eth_rx_dt_vld&eth_rx_addr[`ETH_TX_RAM_INDEX-1-:3]==i;
    end
end
assign  w_eth_addr  =   eth_rx_dt_vld? eth_rx_addr[`ETH_TX_RAM_ADDR_INDEX-1:0]: eth_tx_rd_en? eth_tx_rd_addr[`ETH_TX_RAM_ADDR_INDEX-1:0] : 'd0;
//transfer data between stage
reg     [`TS_INDEX-1:0]             r_eth_ts_cs;
reg                                 r_eth_ping_or_pong;
always@(posedge clk_eth)begin
    r_eth_ts_cs         <=  eth_rx_addr[`ETH_TX_RAM_INDEX-1-:3];
    r_eth_ping_or_pong  <=  r_itlc_eth_ping_pong[2];
end
//stage 2,  dout and dout data
wire    [`ETH_TX_RAM_WIDTH-1:0]     w_eth_dout_ping     [`TIMESTEP-1:0];
wire    [`ETH_TX_RAM_WIDTH-1:0]     w_eth_dout_pong     [`TIMESTEP-1:0];
always@(posedge clk_eth )begin
    eth_tx_rd_vld <= eth_tx_rd_en;
end
assign  eth_tx_rd_data  = r_eth_ping_or_pong? w_eth_dout_ping[r_eth_ts_cs] : w_eth_dout_pong[r_eth_ts_cs];


/**brc and bwc control for bram**/
//stage 1, generate brm ena , wea and addr
reg     [`TIMESTEP-1:0]             w_brm_ping_ena;
reg     [`TIMESTEP-1:0]             w_brm_pong_ena;
reg     [`TIMESTEP-1:0]             w_brm_ping_wea;
reg     [`TIMESTEP-1:0]             w_brm_pong_wea;
wire    [`FMS_RAM_INDEX-1:0]        w_bram_addr [1:0];
always@(*)begin
    for(i=0;i<`TIMESTEP;i=i+1)begin
        w_brm_ping_ena[i]   =   (itlc_rd_ping_or_pong? (brc_ts_cs==i)&brc_rd_en&itlc_brc_u_or_b : (bwc_ts_cs==i)&bwc_wr_en&itlc_bwc_u_or_b);
        w_brm_pong_ena[i]   =   ((!itlc_rd_ping_or_pong)? (brc_ts_cs==i)&brc_rd_en&itlc_brc_u_or_b : (bwc_ts_cs==i)&bwc_wr_en&itlc_bwc_u_or_b);
        w_brm_ping_wea[i]   =   (itlc_rd_ping_or_pong? 1'b0 : (bwc_ts_cs==i)&bwc_wr_en&itlc_bwc_u_or_b);
        w_brm_pong_wea[i]   =   ((!itlc_rd_ping_or_pong)? 1'b0 : (bwc_ts_cs==i)&bwc_wr_en&itlc_bwc_u_or_b);
    end
end
assign  w_bram_addr[0]      =   itlc_rd_ping_or_pong? brc_rd_addr: bwc_wr_addr;
assign  w_bram_addr[1]      =   itlc_rd_ping_or_pong? bwc_wr_addr: brc_rd_addr;
//transfer data between stage 1&2
reg     [`TS_INDEX-1:0]             r_brm_ts_cs;
reg                                 r_brm_rd_ping_or_pong;
always@(posedge clk)begin
    r_brm_ts_cs             <=      brc_ts_cs;
    r_brm_rd_ping_or_pong   <=      itlc_rd_ping_or_pong;
end
//stage 2, dout and dout vld
wire    [`SPIKE_INCH_WIDTH-1:0]     w_brm_ping_dout     [`TIMESTEP-1:0];
wire    [`SPIKE_INCH_WIDTH-1:0]     w_brm_pong_dout     [`TIMESTEP-1:0];
wire    [`SPIKE_INCH_WIDTH-1:0]     w_brm_dout;
assign  w_brm_dout  =   r_brm_rd_ping_or_pong ? w_brm_ping_dout[r_brm_ts_cs] : w_brm_pong_dout[r_brm_ts_cs];
reg                                 r_brm_rd_vld;
always@(posedge clk )begin
    r_brm_rd_vld   <=  itlc_brc_u_or_b&brc_rd_en;
end
genvar j;
generate
    for(j=0;j<`TIMESTEP;j=j+1)begin:bram_array_ping
        fms_mem main_mem_ping (
            .clka(clk),    // input wire clka
            .ena(w_brm_ping_ena[j]),      // input wire ena
            .wea(w_brm_ping_wea[j]),      // input wire [0 : 0] wea
            .addra(w_bram_addr[0]),  // input wire [15 : 0] addra
            .dina(bwc_spike_din),    // input wire [31 : 0] dina
            .douta(w_brm_ping_dout[j]),  // output wire [31 : 0] douta

            .clkb(clk_eth),    // input wire clkb
            .enb(w_eth_ping_ena[j]),      // input wire enb
            .web(w_eth_ping_wea[j]),      // input wire [0 : 0] web
            .addrb(w_eth_addr),  // input wire [14 : 0] addrb
            .dinb(eth_rx_dt),    // input wire [63 : 0] dinb
            .doutb(w_eth_dout_ping[j])  // output wire [63 : 0] doutb
        );
    end
endgenerate
generate
    for(j=0;j<`TIMESTEP;j=j+1)begin:bram_array_pong
        fms_mem main_mem_pong(
            .clka(clk),    // input wire clka
            .ena(w_brm_pong_ena[j]),      // input wire ena
            .wea(w_brm_pong_wea[j]),      // input wire [0 : 0] wea
            .addra(w_bram_addr[1]),  // input wire [15 : 0] addra
            .dina(bwc_spike_din),    // input wire [31 : 0] dina
            .douta(w_brm_pong_dout[j]),  // output wire [31 : 0] douta

            .clkb(clk_eth),    // input wire clkb
            .enb(w_eth_pong_ena[j]),      // input wire enb
            .web(w_eth_pong_wea[j]),      // input wire [0 : 0] web
            .addrb(w_eth_addr),  // input wire [14 : 0] addrb
            .dinb(eth_rx_dt),    // input wire [63 : 0] dinb
            .doutb(w_eth_dout_pong[j])  // output wire [63 : 0] doutb
        );
    end
endgenerate
// uram control
//stage 1,
wire        [`URAM_INDEX-1:0]       urm_addr;
reg         [`TIMESTEP-1:0]         urm_ena;
reg         [`TIMESTEP-1:0]         urm_wea;
wire        [`SPIKE_INCH_WIDTH-1:0] urm_dout    [`TIMESTEP-1:0];
always@(*)begin
    for(i=0;i<`TIMESTEP;i=i+1)begin
        urm_ena[i]      =   (brc_ts_cs==i&!itlc_brc_u_or_b&brc_rd_en)|(bwc_ts_cs==i&!itlc_bwc_u_or_b&bwc_wr_en);
        urm_wea[i]      =   bwc_ts_cs==i&!itlc_bwc_u_or_b&bwc_wr_en;
    end
end
assign      urm_addr    =   itlc_uram_base_addr+ (!itlc_brc_u_or_b? brc_rd_addr : !itlc_bwc_u_or_b? bwc_wr_addr : 'd0);
//stage 2, 2 clk latency
wire            uram_rd_en_dly;
wire    [`TS_INDEX-1:0]   uram_ts_cs_dly;
c_shift_ram_uram  c_shift_ram_uram(
  .D({!itlc_brc_u_or_b&brc_rd_en,brc_ts_cs}),      // input wire [4 : 0] D
  .CLK(clk),  // input wire CLK
  .Q({uram_rd_en_dly,uram_ts_cs_dly})      // output wire [4 : 0] Q
);
generate
    for(j=0;j<`TIMESTEP;j=j+1)begin:uram_array
        xpm_memory_sdpram #(
              .ADDR_WIDTH_A(`URAM_INDEX),               // DECIMAL
              .ADDR_WIDTH_B(`URAM_INDEX),               // DECIMAL
              .AUTO_SLEEP_TIME(0),            // DECIMAL
              .BYTE_WRITE_WIDTH_A(`SPIKE_INCH_WIDTH),        // DECIMAL
              .CASCADE_HEIGHT(0),             // DECIMAL
              .CLOCKING_MODE("common_clock"), // String
              .ECC_MODE("no_ecc"),            // String
              .MEMORY_INIT_FILE("none"),      // String
              .MEMORY_INIT_PARAM("0"),        // String
              .MEMORY_OPTIMIZATION("true"),   // String
              .MEMORY_PRIMITIVE("ultra"),      // String
              .MEMORY_SIZE(`URAM_DEPTH*`SPIKE_INCH_WIDTH),             // DECIMAL
              .MESSAGE_CONTROL(0),            // DECIMAL
              .READ_DATA_WIDTH_B(`SPIKE_INCH_WIDTH),         // DECIMAL
              .READ_LATENCY_B(2),             // DECIMAL
              .READ_RESET_VALUE_B("0"),       // String
              .RST_MODE_A("SYNC"),            // String
              .RST_MODE_B("SYNC"),            // String
              .SIM_ASSERT_CHK(0),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
              .USE_EMBEDDED_CONSTRAINT(0),    // DECIMAL
              .USE_MEM_INIT(1),               // DECIMAL
              .WAKEUP_TIME("disable_sleep"),  // String
              .WRITE_DATA_WIDTH_A(`SPIKE_INCH_WIDTH),        // DECIMAL
              .WRITE_MODE_B("read_first")      // String
           )// A write B read
           xpm_memory_sdpram_inst_0 (
              .dbiterrb( ),                     // 1-bit output: Status signal to indicate double bit error occurrence
                                                // on the data output of port B.
              .doutb(urm_dout[j]),              // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
              .sbiterrb( ),                     // 1-bit output: Status signal to indicate single bit error occurrence
                                                // on the data output of port B.
              .addra(urm_addr),                 // ADDR_WIDTH_A-bit input: Address for port A write operations.
              .addrb(urm_addr),                 // ADDR_WIDTH_B-bit input: Address for port B read operations.
              .clka(clk),                       // 1-bit input: Clock signal for port A. Also clocks port B when
                                                // parameter CLOCKING_MODE is "common_clock".
              .clkb(clk),                       // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                                                // "independent_clock". Unused when parameter CLOCKING_MODE is
                                                // "common_clock".
              .dina(bwc_spike_din),             // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
              .ena(1'b1),                       // 1-bit input: Memory enable signal for port A. Must be high on clock
                                                // cycles when write operations are initiated. Pipelined internally.
              .wea(urm_wea[j]),                  // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
              .enb(1'b1),                       // 1-bit input: Memory enable signal for port B. Must be high on clock
                                                // cycles when read operations are initiated. Pipelined internally.
              .injectdbiterra(1'b0), // 1-bit input: Controls double bit error injection on input data when
                                               // ECC enabled (Error injection capability is not available in
                                               // "decode_only" mode).
              .injectsbiterra(1'b0), // 1-bit input: Controls single bit error injection on input data when
                                               // ECC enabled (Error injection capability is not available in
                                               // "decode_only" mode).
              .regceb(1'b1),                 // 1-bit input: Clock Enable for the last register stage on the output
                                               // data path.
              .rstb(1'b0),                     // 1-bit input: Reset signal for the final port B output register stage.
                                               // Synchronously resets output port doutb to the value specified by
                                               // parameter READ_RESET_VALUE_B.
              .sleep(1'b0)                   // 1-bit input: sleep signal to enable the dynamic power saving feature.
                                               // for port A input data port dina. 1 bit wide when word-wide writes are
                                               // used. In byte-wide write configurations, each bit controls the
                                               // writing one byte of dina to address addra. For example, to
                                               // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                                               // is 32, wea would be 4'b0010.
           );
       end
endgenerate
//output control

assign      brc_spike_vld   =   uram_rd_en_dly|r_brm_rd_vld;
assign      brc_spike_out   =   uram_rd_en_dly?urm_dout[uram_ts_cs_dly] : r_brm_rd_vld ? w_brm_dout : 'd0;
endmodule
