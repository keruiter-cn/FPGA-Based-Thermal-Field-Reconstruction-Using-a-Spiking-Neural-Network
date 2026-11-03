`timescale 1ns / 1ps
/***************************************************************
# Filename       :  pp_wgt_buf.v
# Designer       :  Zhicheng Hu
#
# File Created   :  2024-07-23 17:43
# Last modified  :  2024-07-23 17:43
#
# Description    :  
# Info           :  v0.0 primary version 2024-07
# Submodules     :  
***************************************************************/
module pp_wgt_buf(
    input           wclk,
    input           rst_n,
    input           iwen,
    input           ilc_ping_or_pong,
    input   [$clog2(`WEIGHT_RAM_DEPTH):0]      iwvwaddr,
    input   [`DDR_WIDTH-1:0] iwvwdata,
    input           rclk,
    input   [$clog2(`WEIGHT_RAM_DEPTH)-1:0]      iwvraddr,
    output  [`DDR_WIDTH*2-1:0] owvdata
);
reg   [$clog2(`WEIGHT_RAM_DEPTH):0]      rvwaddr;
reg   [`DDR_WIDTH-1:0]                    rvwdata;
reg                                      rwen;
always@(posedge wclk or negedge rst_n)begin
  if(!rst_n)begin
    rvwaddr  <= 'd0;
    rvwdata  <= 'd0;
    rwen     <= 'd0;
  end else begin
    rvwaddr  <= iwvwaddr;
    rvwdata  <= iwvwdata;
    rwen     <= iwen;
  end
end
wire iwen_ping;
wire iwen_pong;
assign iwen_ping = ilc_ping_or_pong? rwen: 1'b0;//1 write ping, 0 write pong
assign iwen_pong = ilc_ping_or_pong? 1'b0: rwen;

wire [`DDR_WIDTH*2-1:0] wvdata_ping, wvdata_pong;
assign owvdata = ilc_ping_or_pong? wvdata_pong: wvdata_ping;

wgt_buf512x144 ping_buf (
  .clka(wclk),    // input wire clka
  .wea(iwen_ping),      // input wire [0 : 0] wea
  .ena(1'b1),
  .addra(rvwaddr),  // input wire [7 : 0] addra
  .dina(rvwdata),    // input wire [255 : 0] dina
  .clkb(rclk),    // input wire clkb
  .enb(~ilc_ping_or_pong),
  .addrb(iwvraddr),  // input wire [7 : 0] addrb
  .doutb(wvdata_ping)  // output wire [511 : 0] doutb
);

wgt_buf512x144 pong_buf (
  .clka(wclk),    // input wire clka
  .wea(iwen_pong),      // input wire [0 : 0] wea
  .ena(1'b1),
  .addra(rvwaddr),  // input wire [7 : 0] addra
  .dina(rvwdata),    // input wire [255 : 0] dina
  .clkb(rclk),    // input wire clkb
  .enb(ilc_ping_or_pong),
  .addrb(iwvraddr),  // input wire [7 : 0] addrb
  .doutb(wvdata_pong)  // output wire [511 : 0] doutb
);


endmodule
