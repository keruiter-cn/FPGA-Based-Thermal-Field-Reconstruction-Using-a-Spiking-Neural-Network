`timescale 1ns/1ps
`include "proj_snn.vh"
module tb_pec;

    // Signal definitions
    reg  clk;
    reg  rst_n;
    reg  ilc_enable;
    reg  brc_din_vld;
    reg [`SPIKE_INCH_WIDTH-1:0] brc_fms_spike;
    reg  brc_one_spike;
    reg  brc_row_end_vld;
    reg  brc_fire_enable;
    reg  brc_ts_end_vld;
    reg [`WEIGHT_RAM_INDEX-1:0] ddr_weight_waddr;
    reg [5-1:0] wgt_buf_cs;
    reg  ddr_write_vld;
    reg [`DDR_WIDTH*2-1:0] ddr_weight_din;
    reg  itlc_vld;
    reg  itlc_first_layer_or_not;
    reg  itlc_last_layer_or_not;
    reg  itlc_bias_or_not;
    reg  itlc_conv_or_not;
    reg  itlc_convt_or_not;
    reg  itlc_avgpool_or_not;
    reg [`THRESHOLD_WIDTH-1:0] itlc_threshold;
    reg  ilc_ping_or_pong;
    reg [4-1:0] ilc_in_ch_num;
    reg [`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH-1:0] bias;
    wire  bwc_spike_vld;
    wire [`PE_NUM-1:0] bwc_spike;
    wire [`ACC_WIDTH-1:0] bwc_acc_dout;

initial begin
    $fsdbDumpfile("tb.fsdb");
    $fsdbDumpvars(0,tb_pec);
    $fsdbDumpMDA(0,tb_pec);
end

    // Clock signal generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end
    
    // Reset signal generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end
    
    // Instantiate the Unit Under Test (UUT)
    pec uut (
        .clk(clk),
        .rst_n(rst_n),
        .ilc_enable(ilc_enable),
        .brc_din_vld(brc_din_vld),
        .brc_fms_spike(brc_fms_spike),
        .brc_one_spike(brc_one_spike),
        .brc_row_end_vld(brc_row_end_vld),
        .brc_fire_enable(brc_fire_enable),
        .brc_ts_end_vld(brc_ts_end_vld),
        .ddr_weight_waddr(ddr_weight_waddr),
        .wgt_buf_cs(wgt_buf_cs),
        .ddr_write_vld(ddr_write_vld),
        .ddr_weight_din(ddr_weight_din),
        .itlc_vld(itlc_vld),
        .itlc_first_layer_or_not(itlc_first_layer_or_not),
        .itlc_last_layer_or_not(itlc_last_layer_or_not),
        .itlc_bias_or_not(itlc_bias_or_not),
        .itlc_conv_or_not(itlc_conv_or_not),
        .itlc_convt_or_not(itlc_convt_or_not),
        .itlc_avgpool_or_not(itlc_avgpool_or_not),
        .itlc_threshold(itlc_threshold),
        .ilc_ping_or_pong(ilc_ping_or_pong),
        .ilc_in_ch_num(ilc_in_ch_num),
        .bias(bias),
        .bwc_spike_vld(bwc_spike_vld),
        .bwc_spike(bwc_spike),
        .bwc_acc_dout(bwc_acc_dout)
    );

    wire ddr_finish;
    assign ddr_finish = wgt_buf_cs == 'd31 & ddr_weight_waddr == 'd143;
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            ddr_weight_waddr <= 'b0;
            wgt_buf_cs <= 'b0;
            ddr_write_vld <= 1'b1;
        end
        else if (ddr_finish) begin
            ddr_weight_waddr <= ddr_weight_waddr;
            wgt_buf_cs <= wgt_buf_cs;
            ddr_write_vld <= 1'b0;
        end
        else if (ddr_weight_waddr == 'd143) begin
            wgt_buf_cs <= wgt_buf_cs + 1'b1;
            ddr_weight_waddr <= 'b0;
            ddr_write_vld <= 1'b1;
        end
        else begin
            ddr_weight_waddr <= ddr_weight_waddr + 1'b1;
            wgt_buf_cs <= wgt_buf_cs;
            ddr_write_vld <= 1'b1;
        end
    end

    // Simulation test
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        ilc_enable = 0;
        brc_din_vld = 0;
        brc_fms_spike = 32'hffffffff;
        brc_one_spike = 0;
        brc_row_end_vld = 0;
        brc_fire_enable = 0;
        brc_ts_end_vld = 0;
        ddr_weight_waddr = 0;
        wgt_buf_cs = 32'h0000;
        ddr_weight_din = {32{16'h0001}};
        itlc_vld = 0;
        itlc_first_layer_or_not = 0;
        itlc_last_layer_or_not = 0;
        itlc_bias_or_not = 0;
        itlc_conv_or_not = 0;
        itlc_convt_or_not = 0;
        itlc_avgpool_or_not = 0;
        itlc_threshold = 0;
        ilc_ping_or_pong = 0;
        ilc_in_ch_num = 'd3;
        bias = 0;
        wait(ddr_finish == 1'b1);
        // Add more test cases here
        #100;
        brc_one_spike = 1'b1;
        itlc_first_layer_or_not = 1'b1;
        itlc_conv_or_not = 1'b1;
        itlc_vld = 1'b1;
        ilc_ping_or_pong = ~ilc_ping_or_pong;
        #5;
        itlc_vld = 1'b0;
        itlc_first_layer_or_not = 1'b0;
        itlc_conv_or_not = 1'b0;
        @(negedge clk);
        fire_enable('d3,4,1'b0,1'b0);
        fire_enable('d33,4,1'b0,1'b0);
        @(negedge clk);
        itlc_first_layer_or_not = 0;
        itlc_conv_or_not = 1'b1;
        itlc_vld = 1'b1;
        @(negedge clk);
        itlc_first_layer_or_not = 1'b0;
        itlc_conv_or_not = 1'b0;
        itlc_vld = 1'b0;
        @(negedge clk);
        fire_enable('d33*5,4,0,0);
        fire_enable('d33*7,4,0,0);
        itlc_last_layer_or_not = 1'b1;
        itlc_conv_or_not = 1'b1;
        itlc_vld = 1'b1;
        @(negedge clk);
        itlc_last_layer_or_not = 1'b0;
        itlc_conv_or_not = 1'b0;
        itlc_vld = 1'b0;
        @(negedge clk);
        fire_enable('d33*5,4,1'b0,1'b0);
        fire_enable('d33*3,4,1'b1,1'b0);
        @(negedge clk);
        itlc_last_layer_or_not = 1'b0;
        itlc_convt_or_not = 1'b1;
        itlc_vld = 1'b1;
        @(negedge clk);
        itlc_convt_or_not = 1'b0;
        itlc_vld = 1'b0;
        @(negedge clk);
        fire_enable('d33*3,4,1'b1,1'b0);
        fire_enable('d33*3,4,1'b1,1'b0);
        fire_enable('d33*2,4,1'b1,1'b0);
        fire_enable('d33*5,4,1'b1,1'b1);
        fire_enable('d33*3,4,1'b1,1'b0);
        fire_enable('d33*2,4,1'b1,1'b1);
        fire_enable('d33*5,4,1'b1,1'b0);
        itlc_avgpool_or_not = 1'b1;
        itlc_vld = 1'b1;
        @(negedge clk); 
        itlc_avgpool_or_not = 1'b0;
        itlc_vld = 1'b0;
        @(negedge clk);
        fire_enable('d33*5,4,1'b0,1'b0);
        fire_enable('d33*3,3,1'b0,1'b0);
        fire_enable('d33*3,5,1'b0,1'b0);
        fire_enable('d33*3,2,1'b0,1'b0);
        fire_enable('d33*5,4,1'b0,1'b0);
        repeat(4)@(posedge clk);
        $finish;
    end

task fire_enable(input [`THRESHOLD_WIDTH-1:0] threshold, input [8-1:0] cycle, input ts_end,input row_end);
begin

    @(negedge clk);
    brc_din_vld = 1'b1;
    itlc_threshold = threshold;
    repeat(cycle-1)@(negedge clk);
    brc_fire_enable = 1'b1;
    brc_ts_end_vld = ts_end;
    brc_row_end_vld = row_end;
    @(negedge clk);
    brc_ts_end_vld = 1'b0;
    brc_fire_enable = 1'b0;
    brc_din_vld = 1'b0;
    brc_row_end_vld = 1'b0;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    $display("thre =%d, cycle =%d, ", threshold, cycle);
end
endtask


endmodule
