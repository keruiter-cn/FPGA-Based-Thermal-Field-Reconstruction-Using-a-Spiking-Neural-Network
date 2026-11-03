`timescale 1ns / 1ps
/***************************************************************
# Filename       :  wgt_buf_ctrl.v
# Designer       :  Zhicheng Hu
#
# File Created   :  2024-07-24 08:34
# Last modified  :  2024-07-24 08:34
#
# Description    :  
# Info           :  v0.0 primary version 2024-07
# Submodules     :  
***************************************************************/
module wgt_buf_ctrl(
    input   clk,
    input   irst_n,
    input   itlc_vld,
    input   imode_avg,
    input   imode_convt,
    input   imode_conv,
    input   brc_din_vld,
    input   [4-1:0] ilc_in_ch_num,
    input   ifire_enable,
    input   its_end,
    input   irow_end,
    output reg [`WEIGHT_RAM_INDEX-1:0] orvraddr
);

localparam W1 = 2'b00;
localparam W2 = 2'b01;
localparam W3 = 2'b10;
localparam W4 = 2'b11;

wire [3-1:0] wvmode;
assign wvmode = {imode_avg, imode_convt, imode_conv};

wire [`WEIGHT_RAM_INDEX-1:0] wvbaseaddr = 'b0;
wire [`WEIGHT_RAM_INDEX-1:0] wvaddr21;
wire [`WEIGHT_RAM_INDEX-1:0] wvaddr31;
wire [`WEIGHT_RAM_INDEX-1:0] wvaddr41;

wire [5-1:0] wvaddr_inc;
assign wvaddr_inc = ilc_in_ch_num + 1'b1;

assign wvaddr21 = wvbaseaddr + wvaddr_inc * 1;
assign wvaddr31 = wvbaseaddr + wvaddr_inc * 2;
assign wvaddr41 = wvbaseaddr + wvaddr_inc * 3;

reg [`WEIGHT_RAM_INDEX-1:0] nxt_ptr;
reg [`WEIGHT_RAM_INDEX-1:0] cur_ptr;

reg [2-1:0] nxt_state;
reg [2-1:0] cur_state;

always@(*) begin
    case(wvmode)
        3'b100:
            nxt_ptr = 'b0;
        3'b001:
            if(ifire_enable)begin
                nxt_ptr = 'd0;
            end
            else if(brc_din_vld) begin
                nxt_ptr = cur_ptr + 1'b1;
            end
            else begin
                nxt_ptr = cur_ptr;
            end
        3'b010:
            case(cur_state)
                W1:
                    if(irow_end) begin
                        nxt_state = W3;
                        nxt_ptr = wvaddr31;
                    end
                    else if(its_end) begin
                        nxt_state = W2;
                        nxt_ptr = wvaddr21;
                    end
                    else if(ifire_enable) begin
                        nxt_state = W1;
                        nxt_ptr = wvbaseaddr;
                    end
                    else if(brc_din_vld) begin
                        nxt_state = W1;
                        nxt_ptr = cur_ptr + 1'b1;
                    end
                    else begin
                        nxt_state = W1;
                        nxt_ptr = cur_ptr;
                    end

                    W2: if(irow_end) begin
                        nxt_state = W3;
                        nxt_ptr = wvaddr31;
                    end
                    else if(its_end) begin
                        nxt_state = W1;
                        nxt_ptr = wvbaseaddr;
                    end
                    else if(ifire_enable) begin
                        nxt_state = W2;
                        nxt_ptr = wvaddr21;
                    end
                    else if(brc_din_vld) begin
                        nxt_state = W2;
                        nxt_ptr = cur_ptr + 1'b1;
                    end
                    else begin
                        nxt_state = W2;
                        nxt_ptr = cur_ptr;
                    end

                    W3: if(irow_end) begin
                        nxt_state = W1;
                        nxt_ptr = wvbaseaddr;
                    end
                    else if(its_end) begin
                        nxt_state = W4;
                        nxt_ptr = wvaddr41;
                    end
                    else if(ifire_enable) begin
                        nxt_state = W3;
                        nxt_ptr = wvaddr31;
                    end
                    else if(brc_din_vld) begin
                        nxt_state = W3;
                        nxt_ptr = cur_ptr + 1'b1;
                    end
                    else begin
                        nxt_state = W3;
                        nxt_ptr = cur_ptr;
                    end
                    W4: if(irow_end) begin
                        nxt_state = W1;
                        nxt_ptr = wvbaseaddr;
                    end
                    else if(its_end) begin
                        nxt_state = W3;
                        nxt_ptr = wvaddr31;
                    end
                    else if(ifire_enable) begin
                        nxt_state = W4;
                        nxt_ptr = wvaddr41;
                    end
                    else if(brc_din_vld) begin
                        nxt_state = W4;
                        nxt_ptr = cur_ptr + 1'b1;
                    end
                    else begin
                        nxt_state = W4;
                        nxt_ptr = cur_ptr;
                    end
                    default:  begin
                        nxt_state = W1;
                        nxt_ptr = 'b0;
                    end
                    endcase
        default: begin
                nxt_state = W1;
                nxt_ptr = 'b0;
                end
    endcase
end

always@(posedge clk or negedge irst_n) begin
    if(!irst_n) begin
        cur_state <= 'b0;
        cur_ptr <= 'b0;
    end
    else if(itlc_vld) begin
        cur_state <= nxt_state;
        cur_ptr <= 'b0;
    end
    else begin
        cur_state <= nxt_state;
        cur_ptr <= nxt_ptr;
    end
end

always@(*) begin
    orvraddr = cur_ptr;
end
endmodule
