`include "proj_snn.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/29/2024 09:13:52 PM
// Design Name: 
// Module Name: snn_top
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


module snn_top(
input   wire                       rst_n           ,
input                              sys_clk_p,
input                              sys_clk_n,
input                              sys_rst,             //high level reset
output                             c0_ddr4_act_n   ,
output [16:0]                      c0_ddr4_adr     ,
output [1:0]                       c0_ddr4_ba      ,
output [0:0]                       c0_ddr4_bg      ,
output [0:0]                       c0_ddr4_cke     ,
output [0:0]                       c0_ddr4_odt     ,
output [0:0]                       c0_ddr4_cs_n    ,
output [0:0]                       c0_ddr4_ck_t    ,
output [0:0]                       c0_ddr4_ck_c    ,
output                             c0_ddr4_reset_n ,
output                             init_calib_complete,
inout [3:0]                        c0_ddr4_dm_dbi_n,
inout [31:0]                       c0_ddr4_dq      ,
inout [3:0]                        c0_ddr4_dqs_c   ,
inout [3:0]                        c0_ddr4_dqs_t   ,
// connect to phy
output                             phy_rst_n,
input  [3:0]                       phy_rgmii_rxd,
input                              phy_rgmii_rx_ctl,
input                              phy_rgmii_rxc,
output [3:0]                       phy_rgmii_txd,
output                             phy_rgmii_tx_ctl,
output                             phy_rgmii_txc    );

wire   [`TS_INDEX-1:0]             top_ts_cs              ;
wire                               top_ts_end_vld         ;
wire                               top_slide_over         ;
wire                               top_row_end_vld        ;
wire   [`TS_INDEX-1:0]             top_ts_cs_2            ;
wire                               top_ts_end_vld_2       ;
wire                               top_slide_over_2       ;
wire                               top_row_end_vld_2      ;
wire   [`TS_INDEX-1:0]             top_ts_cs_4            ;
wire                               top_ts_end_vld_4       ;
wire                               top_slide_over_4       ;
wire                               top_row_end_vld_4      ;
wire                               clk                    ;
//output from ilc or itlc
wire                               ilc_enable             ;
wire                               itlc_vld               ;
wire   [`OUTCH_NUM_WIDTH-1:0]      itlc_out_ch_num        ;
wire                               itlc_avgpool_or_not    ;
wire                               itlc_last_layer_or_not ;
wire                               itlc_sp_padding        ;
wire                               itlc_concat_or_not     ;  
wire                               itlc_first_layer_or_not;  
wire                               itlc_conv_or_not       ; 
wire                               itlc_convt_or_not      ;
wire                               itlc_bias_or_not       ;
wire    [`THRESHOLD_WIDTH-1:0]     itlc_threshold         ;
wire   [`SHIFT_WIDTH-1:0]          ilc_shift_value        ;  
wire                               ilc_padding_or_not     ;  
wire    [8-1:0]                    ilc_fms_length           ; 
wire    [3:0]                      ilc_in_ch_num          ;  
wire                               ilc_read_start         ;
wire                               ilc_pec_ping_or_pong   ;
wire [`SPIKE_INCH_WIDTH*`WEIGHT_WIDTH-1:0]  ilc_pec_bias  ;
wire    [5-1:0]                     ilc_pec_wgt_buf_cs      ;
wire                                itlc_ddr_weight_init     ;
wire                                itlc_ddr_weight_init_done;
wire                                ilc_ddr_weight_rd_req    ;
wire   [`RAM_ADDR_WIDTH-1: 0]        ilc_ddr_weight_rd_len    ;
wire   [`RAM_ADDR_WIDTH-1: 0]        ilc_ddr_weight_rd_addr   ;
wire   [`RAM_ADDR_WIDTH-1: 0]        ilc_ddr_bram_wr_addr     ;
wire                                itlc_eth_fms_read_req    ;
wire    [`URAM_INDEX-1:0]           ilc_uram_base_addr     ;

//output from pec
wire   [`PE_NUM-1:0]               pec_bwc_spike_din        ;   
wire                               pec_bwc_spike_vld        ;   
wire   [`ACC_WIDTH-1:0]            pec_bwc_acc_dout         ;    
//output from bwc
wire                               bwc_ilc_stop_req         ;
wire                               bwc_fms_write_en         ;   
wire  [`FMS_RAM_INDEX-1:0]         bwc_fms_write_addr       ;   
wire  [`TS_INDEX-1:0]              bwc_fms_ts_cs            ;   
wire   [`PE_NUM-1:0]               bwc_fms_spike_dout       ;   
wire   [`ACC_WIDTH-1:0]            bwc_fms_acc_dout         ;   
//output from brc
wire                               brc_slide_over         ;
wire                               brc_ilc_cat_half_finish;
wire     [`SLIDE_NUM_INDEX-1:0]    brc_ilc_slide_position ;
wire    [`SPIKE_INCH_WIDTH-1:0]     brc_fms_spike_din        ; 
wire                               brc_fms_data_valid       ; 
wire    [`FMS_RAM_INDEX-1:0]       brc_fms_read_addr        ; 
wire                               brc_fms_read_en          ; 
wire   [`TS_INDEX-1:0]             brc_ts_cs                ;    
wire                               brc_pec_dout_vld         ; 
wire    [`SPIKE_INCH_WIDTH-1:0]    brc_pec_spike_dout       ; 
wire                               brc_pec_one_spike        ; 
wire                               brc_pec_row_end_vld      ; 
wire                               brc_pec_fire_enable      ; 
wire                               brc_pec_ts_end_vld       ;    

//output from ddr
wire                            ddr_pec_write_vld   ;
wire [`DDR_WIDTH-1:0]         ddr_pec_weight_din  ;
wire    [`WEIGHT_RAM_INDEX:0] ddr_pec_weight_waddr    ;
wire                           mem_clk           ;
//wire                           clk_ddr           ;   
wire                           rst               ;  
wire                           ddr_rdy           ;   
wire                           ddr_wdf_rdy       ;   
wire                           ddr_rd_data_valid ;   
wire   [`DDR_WIDTH-1 : 0]       ddr_rd_data       ;   
wire   [2 : 0]                 ddr_cmd           ;   
wire   [`DDR_ADDR_WIDTH-1 : 0]  ddr_addr          ;   
wire                           ddr_en            ;   
wire   [(`DDR_WIDTH/8)-1 : 0]   ddr_wdf_mask      ;   
wire   [`DDR_WIDTH-1: 0]        ddr_wdf_data      ;   
wire                           ddr_wdf_end       ;   
wire                           ddr_wdf_wren      ;   
wire                           ddr_eth_weight_fifo_en;   
  
//output from eth_top
wire   [`DDR_WIDTH-1: 0]     eth_ddr_weight_data   ;   
wire                         eth_ddr_weight_empty  ;  
wire                         eth_itlc_eth_rdy           ;
wire                         eth_itlc_eth_read_fms_done ;
wire                         eth_fms_read_clk           ;
wire                         eth_fms_read_en            ;
wire [`ETH_TX_RAM_INDEX-1:0] eth_fms_read_addr          ;
wire                         eth_itlc_eth_write_ddr_done; 
wire                         eth_fms_write_clk          ;
wire [`ETH_RX_RAM_INDEX-1:0] eth_fms_write_addr         ;
wire [`ETH_RX_APP_WIDTH-1:0] eth_fms_write_data         ;
wire                         eth_fms_write_data_vld     ;
wire                         eth_itlc_eth_write_fms_done;  
wire  [`ETH_TX_APP_WIDTH-1:0]eth_fms_read_data          ;
wire                         eth_fms_read_data_vld      ;
wire                         clk_15_625                 ;
wire                         clk_333_33                 ;
wire                         clk_125                    ;
wire                         locked                     ;

IBUFDS IBUFDS_inst (
      .O(clk),   // 1-bit output: Buffer output
      .I(sys_clk_p),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
      .IB(sys_clk_n)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
   );
ilc u_ilc(
.clk                    (   clk                 ),
.rst_n                  (   rst_n               ),
.ilc_ena                (   ilc_enable          ),
//eth control
.eth_write_ddr_done     (   eth_itlc_eth_write_ddr_done ),
.eth_write_fms_done     (   eth_itlc_eth_write_fms_done ),
.eth_read_fms_done      (   eth_itlc_eth_read_fms_done  ),
.eth_fms_read_req       (   itlc_eth_fms_read_req       ),
//weight init and move ddr to pec req
.ddr_weight_init        (   itlc_ddr_weight_init        ),
.ddr_weight_rd_req      (   ilc_ddr_weight_rd_req       ),
.ddr_weight_rd_addr     (   ilc_ddr_weight_rd_addr      ),
.ddr_weight_rd_len      (   ilc_ddr_weight_rd_len       ),
.ddr_brm_wr_addr        (   ilc_ddr_bram_wr_addr        ),
.ddr_brm_wr_done        (   ilc_weight_rd_done          ),

//pec control
.pec_weight_buffer_cs   (   ilc_pec_wgt_buf_cs          ),
//.pec_enable             (   ilc_enable          ),
.pec_ping_pong          (   ilc_pec_ping_or_pong        ),
.pec_threshold          (   itlc_threshold              ),
.pec_in_ch_num          (   ilc_in_ch_num               ),
.pec_bias               (   ilc_pec_bias                ),

.brc_slide_over_dly     (   top_slide_over              ),
.brc_uram_half_finish   (   brc_ilc_cat_half_finish     ),
.brc_ts_end_dly         (   top_ts_end_vld              ),
.ilc_shift_value        (   ilc_shift_value             ),
.ilc_padding_or_not     (   ilc_padding_or_not          ),
.ilc_fms_len            (   ilc_fms_length              ),
.brc_read_start         (   ilc_read_start              ),

.itlc_vld               (   itlc_vld                    ),
.itlc_first_layer_or_not(   itlc_first_layer_or_not     ),
.itlc_last_layer_or_not (   itlc_last_layer_or_not      ),
.itlc_out_ch_num        (   itlc_out_ch_num             ),
.itlc_sp_padding        (   itlc_sp_padding             ),
.itlc_bias_or_not       (   itlc_bias_or_not            ),
.itlc_conv_or_not       (   itlc_conv_or_not            ),
.itlc_convt_or_not      (   itlc_convt_or_not           ),
.itlc_concat_or_not     (   itlc_concat_or_not          ),
.itlc_avgpool_or_not    (   itlc_avgpool_or_not         ),
.itlc_sp_pool           (   itlc_sp_pool                ),

.fms_eth_ping_pong      (   ilc_fms_eth_ping_pong       ),
.fms_ping_pong          (   ilc_fms_ping_pong           ),
.fms_brc_u_or_b         (   ilc_fms_brc_u_or_b          ),
.fms_bwc_u_or_b         (   ilc_fms_bwc_u_or_b          ),
.fms_uram_base_addr     (   ilc_uram_base_addr          )
);

fms u_fms(
.clk                    (   clk                         ),
.clk_eth                (   eth_fms_write_clk           ),
.rst_n                  (   rst_n                       ),
.itlc_eth_ping_pong     (   ilc_fms_eth_ping_pong       ),
.itlc_eth_ping_pong_ack (   ilc_fms_eth_ping_pong_ack   ),
.eth_rx_addr            (   eth_fms_write_addr          ),//eth clk
.eth_rx_dt              (   eth_fms_write_data          ),
.eth_rx_dt_vld          (   eth_fms_write_data_vld      ),

.eth_tx_rd_addr         (   eth_fms_read_addr           ),
.eth_tx_rd_en           (   eth_fms_read_en             ),
.eth_tx_rd_vld          (   eth_fms_read_data_vld       ),
.eth_tx_rd_data         (   eth_fms_read_data           ),

.brc_spike_out          (   brc_fms_spike_din           ),
.brc_spike_vld          (   brc_fms_data_valid          ),
.brc_rd_addr            (   brc_fms_read_addr           ),
.brc_rd_en              (   brc_fms_read_en             ),
.brc_ts_cs              (   brc_ts_cs                   ),
.itlc_rd_ping_or_pong   (   ilc_fms_ping_pong           ),
.itlc_brc_u_or_b        (   ilc_fms_brc_u_or_b          ),//1 b 0 u
.itlc_bwc_u_or_b        (   ilc_fms_bwc_u_or_b          ),
.itlc_uram_base_addr    (   ilc_uram_base_addr          ),
.bwc_wr_en              (   bwc_fms_write_en            ),
.bwc_wr_addr            (   bwc_fms_write_addr          ),
.bwc_ts_cs              (   top_ts_cs                   ),
.bwc_spike_din          (   bwc_fms_spike_dout          )
    );

bram_write_control_new u_bram_write_control(
.clk                     ( clk                    ),
.rst_n                   ( rst_n                  ),
.ilc_enable              ( ilc_enable             ),
.pec_spike_din           ( pec_bwc_spike_din      ),
.pec_spike_vld           ( pec_bwc_spike_vld      ),
.pec_acc_dout            ( pec_bwc_acc_dout       ),
.itlc_vld                ( itlc_vld               ),
.itlc_out_ch_num         ( itlc_out_ch_num        ),
.itlc_avgpool_or_not     ( itlc_avgpool_or_not    ),
.itlc_last_layer_or_not  ( itlc_last_layer_or_not ),
.itlc_sp_padding         ( itlc_sp_padding        ),
.ilc_fms_length         (   ilc_fms_length          ),
.brc_ts_cs               ( top_ts_cs              ),
.brc_ts_end_vld          ( top_ts_end_vld         ),
.brc_slide_over          ( top_slide_over         ),
.brc_row_end_vld         ( top_row_end_vld        ),
.ilc_stop_req            ( bwc_ilc_stop_req       ),
.fms_write_en            ( bwc_fms_write_en       ),
.fms_write_addr          ( bwc_fms_write_addr     ),
.fms_ts_cs               ( bwc_fms_ts_cs          ),
.fms_spike_dout          ( bwc_fms_spike_dout     ),
.fms_acc_dout            ( bwc_fms_acc_dout       ),
.sp_pad_slide_over      (   bwc_ilc_sp_pad_slide_over)
);

bram_read_control u_bram_read_control(
.clk                    ( clk                    ),
.rst_n                  ( rst_n                  ),
.ilc_enable             ( ilc_enable             ),
.ilc_shift_value        ( ilc_shift_value        ),
//.ilc_out_ch_num         ( itlc_out_ch_num        ),
.ilc_padding_or_not     ( ilc_padding_or_not     ),
.ilc_fms_length         ( ilc_fms_length         ),
.ilc_in_ch_num          ( ilc_in_ch_num          ),
.ilc_read_start         ( ilc_read_start         ),
.itlc_vld               ( itlc_vld               ),
.itlc_concat_or_not     ( itlc_concat_or_not     ),
.itlc_first_layer_or_not( itlc_first_layer_or_not),
.itlc_last_layer_or_not ( itlc_last_layer_or_not ),
.itlc_conv_or_not       ( itlc_conv_or_not       ),
.itlc_convt_or_not      ( itlc_convt_or_not      ),
.itlc_avgpool_or_not    ( itlc_avgpool_or_not    ),
.itlc_sp_pool           ( itlc_sp_pool           ),
.fms_spike_din          ( brc_fms_spike_din      ),
.fms_data_valid         ( brc_fms_data_valid     ),
.ilc_bwc_slide_over_req ( brc_slide_over         ),
.ilc_cat_half_finish    ( brc_ilc_cat_half_finish),
.ilc_slide_position     ( brc_ilc_slide_position ),
.fms_read_addr          ( brc_fms_read_addr      ),
.fms_read_en            ( brc_fms_read_en        ),
.fms_bwc_ts_cs          ( brc_ts_cs          ),
.pec_dout_vld           ( brc_pec_dout_vld       ),
.pec_spike_dout         ( brc_pec_spike_dout     ),
.pec_one_spike          ( brc_pec_one_spike      ),
.pec_row_end_vld        ( brc_pec_row_end_vld    ),
.pec_fire_enable        ( brc_pec_fire_enable    ),
.pec_ts_end_vld         ( brc_pec_ts_end_vld     )
);

pec u_pec (
        .clk(clk),
        .clk_ddr(mem_clk),
        .rst_n(rst_n),
        .ilc_enable(ilc_enable),
        .brc_din_vld(brc_pec_dout_vld),
        .brc_fms_spike(brc_pec_spike_dout),
        .brc_one_spike(brc_pec_one_spike),
        .brc_row_end_vld(brc_pec_row_end_vld),
        .brc_fire_enable(brc_pec_fire_enable),
        .brc_ts_end_vld(brc_pec_ts_end_vld),
        .ddr_weight_waddr(ddr_pec_weight_waddr),
        .wgt_buf_cs(ilc_pec_wgt_buf_cs),
        .ddr_write_vld(ddr_pec_write_vld),
        .ddr_weight_din(ddr_pec_weight_din),
        .itlc_vld(itlc_vld),
        .itlc_first_layer_or_not(itlc_first_layer_or_not),
        .itlc_last_layer_or_not(itlc_last_layer_or_not),
        .itlc_bias_or_not(itlc_bias_or_not),
        .itlc_conv_or_not(itlc_conv_or_not),
        .itlc_convt_or_not(itlc_convt_or_not),
        .itlc_avgpool_or_not(itlc_avgpool_or_not),
        .itlc_threshold(itlc_threshold),
        .ilc_ping_or_pong(ilc_pec_ping_or_pong),
        .ilc_in_ch_num(ilc_in_ch_num),
        .bias(ilc_pec_bias),
        .bwc_spike_vld(pec_bwc_spike_vld),
        .bwc_spike(pec_bwc_spike_din),
        .bwc_acc_dout(pec_bwc_acc_dout)
    );
ddr_rwc   #(
.DDR_WIDTH         (256)   ,
.DDR_ADDR_WIDTH    (32 )   ,
.RAM_ADDR_WIDTH    (29 )
)
u_ddr_rwc(
  // ********* ALL SIGNALS AT THIS INTERFACE ARE ACTIVE HIGH SIGNALS ********/
.clk_ddr_in             (mem_clk                ) ,    // MC UI clock.
//.clk_ddr                (clk_ddr                ) ,    // clock  output.
.rst                    (~rst_n                  ) ,    // MC UI reset signal.
.init_calib_complete    (init_calib_complete  ) ,    // MC calibration done signal coming from MC UI.
.ddr_rdy                (ddr_rdy              ) ,    // cmd fifo ready signal coming from MC UI.
.ddr_wdf_rdy            (ddr_wdf_rdy          ) ,    // write data fifo ready signal coming from MC UI. 
.ddr_rd_data_valid      (ddr_rd_data_valid    ) ,    // read data valid signal coming from MC UI
.ddr_rd_data            (ddr_rd_data          ) ,    // read data bus coming from MC UI
.ddr_cmd                (ddr_cmd              ) ,    // command bus to the MC UI 
.ddr_addr               (ddr_addr             ) ,    // address bus to the MC UI
.ddr_en                 (ddr_en               ) ,    // command enable signal to MC UI.
.ddr_wdf_mask           (ddr_wdf_mask         ) ,    // write data mask signal which,is tied to 0 in this example
.ddr_wdf_data           (ddr_wdf_data         ) ,    // write data bus to MC UI.
.ddr_wdf_end            (ddr_wdf_end          ) ,    // write burst end signal to MC UI
.ddr_wdf_wren           (ddr_wdf_wren         ) ,    // write enable signal to MC UI

.clk                    (clk                  ) ,//200M
.itlc_weight_init       (itlc_ddr_weight_init     ) ,
.itlc_weight_init_done  (itlc_ddr_weight_init_done) ,
.eth_weight_data        (eth_ddr_weight_data      ) ,
.eth_weight_empty       (eth_ddr_weight_empty     ) ,
.eth_weight_fifo_en     (ddr_eth_weight_fifo_en   ) ,
.ilc_weight_rd_req      (ilc_ddr_weight_rd_req    ) ,
.ilc_weight_rd_len      (ilc_ddr_weight_rd_len    ) ,
.ilc_weight_rd_addr     (ilc_ddr_weight_rd_addr   ) ,
.ilc_bram_wr_addr       (ilc_ddr_bram_wr_addr     ) ,
.ilc_weight_rd_done     (ilc_weight_rd_done     ) ,
.pec_weight_wr_en       (ddr_pec_write_vld     ) ,
.pec_weight_data        (ddr_pec_weight_din      ) ,
.pec_weight_wr_addr     (ddr_pec_weight_waddr   )
);

ddr4_0 u_ddr4_0
   (
   .sys_rst                    (sys_rst                  ),
   .c0_sys_clk_p               (clk                 ),
   .c0_sys_clk_n               (~clk                 ),
   .c0_ddr4_act_n              (c0_ddr4_act_n             ),
   .c0_ddr4_adr                (c0_ddr4_adr               ),
   .c0_ddr4_ba                 (c0_ddr4_ba                ),
   .c0_ddr4_bg                 (c0_ddr4_bg                ),
   .c0_ddr4_cke                (c0_ddr4_cke               ),
   .c0_ddr4_odt                (c0_ddr4_odt               ),
   .c0_ddr4_cs_n               (c0_ddr4_cs_n              ),
   .c0_ddr4_ck_t               (c0_ddr4_ck_t              ),
   .c0_ddr4_ck_c               (c0_ddr4_ck_c              ),
   .c0_ddr4_reset_n            (c0_ddr4_reset_n           ),
   .c0_ddr4_dm_dbi_n           (c0_ddr4_dm_dbi_n          ),
   .c0_ddr4_dq                 (c0_ddr4_dq                ),
   .c0_ddr4_dqs_c              (c0_ddr4_dqs_c             ),
   .c0_ddr4_dqs_t              (c0_ddr4_dqs_t             ),
   .c0_init_calib_complete     (init_calib_complete       ),
   .c0_ddr4_ui_clk             (mem_clk                   ),
   .c0_ddr4_ui_clk_sync_rst    (rst                       ),
   .dbg_clk                    (                          ),
   .c0_ddr4_app_addr           (ddr_addr                  ),
   .c0_ddr4_app_cmd            (ddr_cmd                   ),
   .c0_ddr4_app_en             (ddr_en                    ),
   .c0_ddr4_app_hi_pri         (1'b0                      ),
   .c0_ddr4_app_wdf_data       (ddr_wdf_data              ),
   .c0_ddr4_app_wdf_end        (ddr_wdf_end               ),
   .c0_ddr4_app_wdf_mask       (ddr_wdf_mask              ),
   .c0_ddr4_app_wdf_wren       (ddr_wdf_wren              ),
   .c0_ddr4_app_rd_data        (ddr_rd_data               ),
   .c0_ddr4_app_rd_data_end    (                          ),
   .c0_ddr4_app_rd_data_valid  (ddr_rd_data_valid         ),
   .c0_ddr4_app_rdy            (ddr_rdy                   ),
   .c0_ddr4_app_wdf_rdy        (ddr_wdf_rdy               ),
   .dbg_bus                    (                          )
   );

eth_top u_eth_top(
.rst_n                              (rst_n),
    // connect to other modules
    // TX
.itlc_eth_clk                       (clk),
.itlc_fms_read_req                  (itlc_eth_fms_read_req),
.itlc_eth_rdy                       (eth_itlc_eth_rdy),
.itlc_eth_read_fms_done             (eth_itlc_eth_read_fms_done),
.fms_read_clk                       (eth_fms_read_clk ),
.fms_read_en                        (eth_fms_read_en  ),
.fms_read_addr                      (eth_fms_read_addr),
.fms_read_data                      (eth_fms_read_data    ),
.fms_read_data_vld                  (eth_fms_read_data_vld),
    // RX
.ddr_weight_rd_clk                  (mem_clk),
.ddr_weight_rd_en                   (ddr_eth_weight_fifo_en),
.ddr_weight_data                    (eth_ddr_weight_data         ),
.ddr_weight_empty                   (eth_ddr_weight_empty        ),
.itlc_eth_write_ddr_done            (eth_itlc_eth_write_ddr_done ),

.fms_write_clk                      (eth_fms_write_clk          ),
.fms_write_addr                     (eth_fms_write_addr         ),
.fms_write_data                     (eth_fms_write_data         ),
.fms_write_data_vld                 (eth_fms_write_data_vld     ),
.itlc_eth_write_fms_done            (eth_itlc_eth_write_fms_done),
.phy_rst_n                          (phy_rst_n       ),
.phy_rgmii_rxd                      (phy_rgmii_rxd   ),
.phy_rgmii_rx_ctl                   (phy_rgmii_rx_ctl),
.phy_rgmii_rxc                      (phy_rgmii_rxc   ),
.phy_rgmii_txd                      (phy_rgmii_txd   ),
.phy_rgmii_tx_ctl                   (phy_rgmii_tx_ctl),
.phy_rgmii_txc                      (phy_rgmii_txc   ),
    // eth_ip
.clk_15_625                         (clk_15_625),
.clk_333_33                         (clk_333_33),
.clk_125                            (clk_125   ),
.locked                             (locked    )
);


clk_wiz_0 clk_wiz_0
(
    .clk_in1_p   (clk),
    .clk_in1_n   (~clk),
    .clk_out_15  (clk_15_625),
    .clk_out_333 (clk_333_33),
    .clk_out_125 (clk_125),
    .clk_out_25  (clk_25),
    .clk_out_200 (clk_200),
    .locked      (locked)
);

wire        shift_2 =   itlc_first_layer_or_not|itlc_avgpool_or_not;
wire        shift_4 =   !shift_2;
c_shift_ram_4 delay_ts_cs_4(
  .D({4{shift_4}}&brc_ts_cs),      // input wire [0 : 0] d
  .CLK(clk),  // input wire clk
  .Q(top_ts_cs_4)      // output wire [0 : 0] q
);

c_shift_ram_4 delay_ts_end_vld_4(
  .D(shift_4&brc_pec_ts_end_vld),      // input wire [0 : 0] d
  .CLK(clk),  // input wire clk
  .Q(top_ts_end_vld_4)      // output wire [0 : 0] q
);
c_shift_ram_4 delay_slide_over_4(
  .D(shift_4&brc_slide_over),      // input wire [0 : 0] d
  .CLK(clk),  // input wire clk
  .Q(top_slide_over_4)      // output wire [0 : 0] q
);
c_shift_ram_4 delay_row_end_vld_4(
  .D(shift_4&brc_pec_row_end_vld),      // input wire [0 : 0] d
  .CLK(clk),  // input wire clk
  .Q(top_row_end_vld_4)      // output wire [0 : 0] q
);


c_shift_ram_0 delay_ts_cs(
  .D({4{shift_2}}&brc_ts_cs),      // input wire [0 : 0] d
  .CLK(clk),  // input wire clk
  .Q(top_ts_cs_2)      // output wire [0 : 0] q
);

c_shift_ram_0 delay_ts_end_vld(
  .D(shift_2&brc_pec_ts_end_vld),      // input wire [0 : 0] d
  .CLK(clk),  // input wire clk
  .Q(top_ts_end_vld_2)      // output wire [0 : 0] q
);
c_shift_ram_0 delay_slide_over(
  .D(shift_2&brc_slide_over),      // input wire [0 : 0] d
  .CLK(clk),  // input wire clk
  .Q(top_slide_over_2)      // output wire [0 : 0] q
);
c_shift_ram_0 delay_row_end_vld(
  .D(shift_2&brc_pec_row_end_vld),      // input wire [0 : 0] d
  .CLK(clk),  // input wire clk
  .Q(top_row_end_vld_2)      // output wire [0 : 0] q
);
assign  {top_ts_cs,top_ts_end_vld,top_slide_over,top_row_end_vld}   =   (itlc_first_layer_or_not|itlc_avgpool_or_not)?{top_ts_cs_2,top_ts_end_vld_2,top_slide_over_2,top_row_end_vld_2}:{top_ts_cs_4,top_ts_end_vld_4,top_slide_over_4,top_row_end_vld_4};
assign itlc_ddr_weight_init_done = eth_itlc_eth_write_ddr_done;
endmodule
