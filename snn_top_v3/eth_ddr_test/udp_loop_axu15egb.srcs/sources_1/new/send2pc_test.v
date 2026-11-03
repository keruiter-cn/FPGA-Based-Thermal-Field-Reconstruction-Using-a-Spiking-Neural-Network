`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/13 18:59:34
// Design Name: 
// Module Name: send2pc_test
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

module send2pc_test(
	input									clk,
	input									rst_n,
    input                         			fms_read_clk,
    input                         			fms_read_en,
    input [`ETH_TX_RAM_INDEX-1:0] 			fms_read_addr,
	input									itlc_eth_read_fms_done,
	output  wire [`ETH_TX_APP_WIDTH-1:0] 		fms_read_data,
    output	reg								fms_read_data_vld,
	output	wire								itlc_fms_read_req
    );
	
reg [4:0] init_cnt;
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        init_cnt <= 'd0;
    end
    else begin
        if(init_cnt == 'd20)
            init_cnt <= init_cnt;
        else 
            init_cnt <= init_cnt + 1'b1;
    end
end
assign itlc_fms_read_req = (init_cnt == 'd20-1'b1) ? 1'b1 : 1'b0;	

send_test_bram u_send_test_bram(
   .clka	(fms_read_clk) ,
   .ena     (fms_read_en)  ,
   .wea     (1'b0)         ,
   .addra   (fms_read_addr),
   .dina    ('d0)          ,
   .douta   (fms_read_data)
  );
  
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin
       fms_read_data_vld <= 1'b1;
   end
   else begin
		fms_read_data_vld <= fms_read_en;
   end
end


endmodule
