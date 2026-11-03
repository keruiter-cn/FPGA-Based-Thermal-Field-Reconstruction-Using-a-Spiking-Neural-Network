`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/07/24 16:34:08
// Design Name:
// Module Name: slow_to_fast
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


module slow_to_fast(
    input rst_n,

    input slow_signal,

    input fast_clk,
    output fast_signal,
    output fast_signal_posedge
);

reg slow_signal_dly1,slow_signal_dly2;
always@(posedge fast_clk or negedge rst_n) begin
    if(!rst_n) begin
        slow_signal_dly1<=1'b0;
        slow_signal_dly2<=1'b0;
    end
    else begin
        slow_signal_dly1<=slow_signal;
        slow_signal_dly2<=slow_signal_dly1;
    end
end

assign fast_signal=slow_signal_dly2;

reg fast_signal_dly;
always@(posedge fast_clk or negedge rst_n) begin
    if(!rst_n) begin
        fast_signal_dly<=1'b0;
    end
    else begin
        fast_signal_dly<=fast_signal;
    end
end
assign fast_signal_posedge=fast_signal&~fast_signal_dly;

endmodule
