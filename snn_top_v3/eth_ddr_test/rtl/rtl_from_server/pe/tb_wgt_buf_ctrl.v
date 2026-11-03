`timescale 1ns/1ps

module tb_wgt_buf_ctrl;

    // Signal definitions
    reg  clk;
    reg  irst_n;
    reg  itlc_vld;
    reg  imode_avg;
    reg  imode_convt;
    reg  imode_conv;
    reg  brc_din_vld;
    reg [4-1:0] ilc_in_ch_num;
    reg  ifire_enable;
    reg  its_end;
    reg  irow_end;
    wire [`WEIGHT_RAM_INDEX-1:0] orvraddr;

    // Clock signal generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end
    
    // Instantiate the Unit Under Test (UUT)
    wgt_buf_ctrl uut (
        .clk(clk),
        .irst_n(irst_n),
        .itlc_vld(itlc_vld),
        .imode_avg(imode_avg),
        .imode_convt(imode_convt),
        .imode_conv(imode_conv),
        .brc_din_vld(brc_din_vld),
        .ilc_in_ch_num(ilc_in_ch_num),
        .ifire_enable(ifire_enable),
        .its_end(its_end),
        .irow_end(irow_end),
        .orvraddr(orvraddr)
    );

    // Simulation test
    initial begin
        // Initialize signals
        clk = 0;
        irst_n = 0;
        itlc_vld = 0;
        imode_avg = 0;
        imode_convt = 0;
        imode_conv = 0;
        brc_din_vld = 0;
        ilc_in_ch_num = 0;
        ifire_enable = 0;
        its_end = 0;
        irow_end = 0;

        // Add more test cases here
        #100;
        $finish;
    end

endmodule
