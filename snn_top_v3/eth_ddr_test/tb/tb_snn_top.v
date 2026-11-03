`timescale 1ps/1ps
// `define FSDB
module tb_snn_top();
//dumpfsdb
`ifdef FSDB
initial begin
    $fsdbDumpfile("../verdi/tb_snn_top.fsdb");
    $fsdbDumpvars(0,tb_snn_top);
    $fsdbDumpMDA(0,tb_snn_top);
end
`endif
//clk generate
localparam PERIOD_CLK   = 5000;
localparam PERIOD       = 4*5000;
reg     sys_clk_i=   1;
reg     sys_rst =   1;
wire    sys_clk_p   =   !sys_clk_i;
initial begin
    forever #(PERIOD_CLK/2) sys_clk_i = !sys_clk_i;
end


//ddr model replament
initial begin
    force u_snn_top.u_ddr_rwc.init_calib_complete   =   1;
    force u_snn_top.u_ddr_rwc.ddr_rdy               =   1;
    force u_snn_top.u_ddr_rwc.ddr_wdf_rdy           =   1;
end
always@(posedge u_snn_top.u_ddr_rwc.clk_ddr_in)begin
    if(u_snn_top.u_ddr_rwc.ddr_cmd==1&u_snn_top.u_ddr_rwc.ddr_en)begin
        force u_snn_top.u_ddr_rwc.ddr_rd_data_valid   =   1;
    end else begin
        release u_snn_top.u_ddr_rwc.ddr_rd_data_valid   ;
    end
end
//memory control
localparam          INPUT_SIZE  =   200;
reg     [511:0]     weight_txt  [0:242657-1];
reg     [31:0]      input_data  [0:INPUT_SIZE*INPUT_SIZE*3-1];
integer n;
initial begin
    $readmemh("D:/System/Desktop/workspace_snn/socket/data_to_fpga/weights_ts3.txt",weight_txt);
    $readmemh("D:/System/Desktop/snn_top_v3/eth_ddr_test/coe/incode_Example0_ts3.txt",input_data);
end
//init fms
initial begin
    wait(u_snn_top.u_ilc.eth_write_fms_done)
    #PERIOD;
    for(n=0;n<INPUT_SIZE*INPUT_SIZE;n=n+1)begin
        $display(input_data[0*INPUT_SIZE*INPUT_SIZE+n]);
         u_snn_top.u_fms.bram_array_pong[0].main_mem_pong.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[n][31:0] = 'h11111111;
         u_snn_top.u_fms.bram_array_pong[1].main_mem_pong.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[n][31:0] = 'h22222222;
         u_snn_top.u_fms.bram_array_pong[2].main_mem_pong.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[n][31:0] = 'h33333333;
        //  u_snn_top.u_fms.bram_array_ping[3].main_mem_ping.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[n][31:0] = input_data[3*INPUT_SIZE*INPUT_SIZE+n][31:0];
        //  u_snn_top.u_fms.bram_array_ping[4].main_mem_ping.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[n][31:0] = input_data[4*INPUT_SIZE*INPUT_SIZE+n][31:0];
        //  u_snn_top.u_fms.bram_array_ping[5].main_mem_ping.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[n][31:0] = input_data[5*INPUT_SIZE*INPUT_SIZE+n][31:0];
        //  u_snn_top.u_fms.bram_array_ping[6].main_mem_ping.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[n][31:0] = input_data[6*INPUT_SIZE*INPUT_SIZE+n][31:0];
        //  u_snn_top.u_fms.bram_array_ping[7].main_mem_ping.inst.native_mem_module.blk_mem_gen_v8_4_5_inst.memory[n][31:0] = input_data[7*INPUT_SIZE*INPUT_SIZE+n][31:0];
    end
end
//weight bram update
reg     [31:0]                  weight_txt_addr =   0;
reg                             high_end_flg    =   0;

always@(posedge u_snn_top.mem_clk)begin
    if(u_snn_top.u_pec.ddr_write_vld)begin
        high_end_flg    <=  !high_end_flg;
        if(high_end_flg)
            weight_txt_addr <=  weight_txt_addr +1;
    end
end

always@(*)begin
    if(u_snn_top.u_pec.ddr_write_vld)begin
        if(high_end_flg)
            force u_snn_top.u_pec.ddr_weight_din = weight_txt[weight_txt_addr][511:256];
        else
            force u_snn_top.u_pec.ddr_weight_din = weight_txt[weight_txt_addr][255:0];
    end else
        release u_snn_top.u_pec.ddr_weight_din ;
end
//force up conv 
integer p;
initial begin//force control
    wait(u_snn_top.u_ilc.layer_cnt == 0&u_snn_top.u_ilc.itlc_vld|u_snn_top.u_ilc.layer_cnt == 1)
    // force u_snn_top.u_ilc.first_layer_or_not    =   0;
    // force u_snn_top.u_ilc.last_layer_or_not     =   0;
    // force u_snn_top.u_ilc.bias_or_not           =   1;
    // force u_snn_top.u_ilc.conv_or_not           =   0;
    // force u_snn_top.u_ilc.convt_or_not          =   1;
    // force u_snn_top.u_ilc.itlc_sp_padding       =   1;
    // force u_snn_top.u_ilc.in_ch_num             =   16;
    // force u_snn_top.u_ilc.out_ch_num            =   8;
    // force u_snn_top.u_ilc.ilc_padding_or_not    =   0;
    // force u_snn_top.u_ilc.ilc_fms_len           =   12;
    // force u_snn_top.u_ilc.shift_value           =   4;
    // //foece weight and input spike to a fixed value

    force u_snn_top.u_pec.wbc_weight_din[63:0]      = 'h0001000100010001;
    //force to last layer
    force u_snn_top.u_ilc.first_layer_or_not    =   0;
    force u_snn_top.u_ilc.last_layer_or_not     =   1;
    force u_snn_top.u_ilc.bias_or_not           =   1;
    force u_snn_top.u_ilc.conv_or_not           =   0;
    force u_snn_top.u_ilc.convt_or_not          =   0;
    force u_snn_top.u_ilc.avg_pool_or_not       =   0;
    force u_snn_top.u_ilc.itlc_sp_padding       =   0;
    force u_snn_top.u_ilc.in_ch_num             =   1;
    force u_snn_top.u_ilc.out_ch_num            =   1;
    force u_snn_top.u_ilc.ilc_padding_or_not    =   0;
    force u_snn_top.u_ilc.ilc_fms_len           =   200;
    force u_snn_top.u_ilc.shift_value           =   0;  

    // //force bias to a fixed value
    force u_snn_top.u_pec.bias[15:0]                =   16'h1;
    // force u_snn_top.u_pec.brc_fms_spike         =   32'h8f8f8f8f8;
end
    // initial begin
    //     wait(u_snn_top.u_ilc.layer_cnt == 0&u_snn_top.u_ilc.itlc_vld|u_snn_top.u_ilc.layer_cnt == 1)
    //     force u_snn_top.u_ilc.first_layer_or_not = 0;
    //     force u_snn_top.u_ilc.bias_or_not   =   1;
    //     force u_snn_top.u_ilc.conv_or_not   =   0;
    //     force u_snn_top.u_ilc.convt_or_not  =   1;
    //     force u_snn_top.u_ilc.itlc_sp_padding=   1;
    //     force u_snn_top.u_ilc.in_ch_num     =   16;
    // end

//main simulation
initial begin
    sys_rst = 1'b0;
    #(2*PERIOD);
    sys_rst = 1'b1;
    #200;
    force u_snn_top.u_ddr_rwc.itlc_weight_init = 1'b0;
    #(200*PERIOD);
    @(posedge u_snn_top.mem_clk)
    u_snn_top.u_ddr_rwc.current_state = 'd5;
    #(20*PERIOD);
    @(posedge u_snn_top.clk)
    #(PERIOD/2);
    force  u_snn_top.u_ilc.next_state =   'h2;
    #PERIOD
    release u_snn_top.u_ilc.next_state;
    force u_snn_top.u_ilc.eth_write_fms_done =  1'b1;
    #PERIOD;
    release u_snn_top.u_ilc.eth_write_fms_done ;
end



//integer i;
//always@(posedge u_snn_top.clk) begin
//    if(u_snn_top.ilc_weight_rd_done)begin
//        for(i=0;i<u_snn_top.u_ilc.weight_rd_distance/2;i=i+1)begin
//            if(u_snn_top.ilc_pec_ping_or_pong)begin
//                u_snn_top/u_pec/\gen_wgt_buf[u_snn_top.u_pec.wgt_buf_cs].upp_wgt_buf/pong_buf/inst/\native_mem_module.blk_mem_gen_v8_4_4_inst/memory[2*i]=weight_txt[u_snn_top.u_ilc.weight_base_addr+i][255:0];
//                u_snn_top/u_pec/\gen_wgt_buf[u_snn_top.u_pec.wgt_buf_cs].upp_wgt_buf/pong_buf/inst/\native_mem_module.blk_mem_gen_v8_4_4_inst/memory[2*i+1]=weight_txt[u_snn_top.u_ilc.weight_base_addr+i][511:256];
//            end else begin
//                u_snn_top/u_pec/\gen_wgt_buf[u_snn_top.u_pec.wgt_buf_cs].upp_wgt_buf/ping_buf.inst/\native_mem_module.blk_mem_gen_v8_4_4_inst/memory[2*i]=weight_txt[u_snn_top.u_ilc.weight_base_addr+i][255:0];
//                u_snn_top/u_pec/\gen_wgt_buf[u_snn_top.u_pec.wgt_buf_cs].upp_wgt_buf/ping_buf.inst/\native_mem_module.blk_mem_gen_v8_4_4_inst/memory[2*i+1]=weight_txt[u_snn_top.u_ilc.weight_base_addr+i][511:256];
//            end
//        end
//    end
//end

snn_top u_snn_top(
.sys_rst            ( sys_rst           )   ,
.sys_clk_p          ( sys_clk_i         )   ,
.sys_clk_n          ( sys_clk_p         )   ,            //high level reset
.c0_ddr4_act_n      (                   )   ,
.c0_ddr4_adr        (                   )   ,
.c0_ddr4_ba         (                   )   ,
.c0_ddr4_bg         (                   )   ,
.c0_ddr4_cke        (                   )   ,
.c0_ddr4_odt        (                   )   ,
.c0_ddr4_cs_n       (                   )   ,
.c0_ddr4_ck_t       (                   )   ,
.c0_ddr4_ck_c       (                   )   ,
.c0_ddr4_reset_n    (                   )   ,
.init_calib_complete(                   )   ,
.c0_ddr4_dm_dbi_n   (                   )   ,
.c0_ddr4_dq         (                   )   ,
.c0_ddr4_dqs_c      (                   )   ,
.c0_ddr4_dqs_t      (                   )   ,

.phy_rst_n          (                   )   ,
.phy_rgmii_rxd      (                   )   ,
.phy_rgmii_rx_ctl   (                   )   ,
.phy_rgmii_rxc      (                   )   ,
.phy_rgmii_txd      (                   )   ,
.phy_rgmii_tx_ctl   (                   )   ,
.phy_rgmii_txc      (                   )
);

endmodule
