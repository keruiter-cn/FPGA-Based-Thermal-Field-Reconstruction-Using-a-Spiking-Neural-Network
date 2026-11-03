`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/04/2024 07:42:28 PM
// Design Name: 
// Module Name: top_eth_ddr
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
module top_eth_ddr(
//input   wire                       rst_n           ,     
input                              sys_clk_p,
input                              sys_clk_n,
input                              sys_rst,            
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
//output                             init_calib_complete,
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
output                             phy_rgmii_txc,   
output                            current_led

);

wire                               rst_n                   ;
wire                               init_calib_complete     ; 

//wire   [`TS_INDEX-1:0]             top_ts_cs              ; 
//wire                               top_ts_end_vld         ; 
//wire                               top_slide_over         ; 
//wire                               top_row_end_vld        ;   
wire                               clk                    ;
////output from ilc or itlc
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
wire                               ilc_slide_over_ack     ;  
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
wire    [`SLIDE_NUM_INDEX-1:0]     brc_fms_spike_din        ; 
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
wire    [`WEIGHT_RAM_INDEX-1:0] ddr_pec_weight_waddr    ;
wire                           mem_clk           ;
wire                           clk_ddr           ;   
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
wire                           ddr_ilc_weight_rd_done;   
  
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
wire  [`ETH_TX_APP_WIDTH-1:0]fms_eth_read_data          ;
wire                         fms_eth_read_data_vld      ;
wire                         clk_15_625                 ;
wire                         clk_333_33                 ;
wire                         clk_125                    ;
wire                         locked                     ;
wire                         clk_200                    ;
wire                        itlc_fms_read_req           ;
IBUFDS IBUFDS_inst (
      .O(clk),   // 1-bit output: Buffer output
      .I(sys_clk_p),   // 1-bit input: Diff_p buffer input (connect directly to top-level port)
      .IB(sys_clk_n)  // 1-bit input: Diff_n buffer input (connect directly to top-level port)
   );


ddr_rwc   #(
.DDR_WIDTH         (256)   ,
.DDR_ADDR_WIDTH    (32 )   ,
.RAM_ADDR_WIDTH    (29 )
)
u_ddr_rwc(
  // ********* ALL SIGNALS AT THIS INTERFACE ARE ACTIVE HIGH SIGNALS ********/
.clk_ddr_in             (mem_clk           ) ,    // MC UI clock. 
//.clk_ddr                (clk_ddr              ) ,    // clock  output.  
.rst                    (~rst_n               ) ,    // MC UI reset signal.                                                            
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
.itlc_weight_init_done  (eth_itlc_eth_write_ddr_done) ,
.eth_weight_data        (eth_ddr_weight_data      ) ,
.eth_weight_empty       (eth_ddr_weight_empty     ) ,
.eth_weight_fifo_en     (ddr_eth_weight_fifo_en   ) ,
.ilc_weight_rd_req      (1'b0    ) ,
.ilc_weight_rd_len      ('d0    ) ,
.ilc_weight_rd_addr     ('d0   ) ,
.ilc_bram_wr_addr       ('d0     ) ,
.ilc_weight_rd_done     (ddr_ilc_weight_rd_done   ) ,
.pec_weight_wr_en       (ddr_pec_write_vld     ) ,
.pec_weight_data        (ddr_pec_weight_din      ) ,
.pec_weight_wr_addr     (ddr_pec_weight_waddr   )            
);

ddr4_0 u_ddr4_0
   (
   .sys_rst                    (~sys_rst                  ),
   .c0_sys_clk_i               (clk                       ),
  // .c0_sys_clk_n               (~clk_200                      ),
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
.itlc_fms_read_req                  (itlc_fms_read_req),
.itlc_eth_rdy                       (eth_itlc_eth_rdy),
.itlc_eth_read_fms_done             (eth_itlc_eth_read_fms_done),
.fms_read_clk                       (eth_fms_read_clk ),
.fms_read_en                        (eth_fms_read_en  ),
.fms_read_addr                      (eth_fms_read_addr),
.fms_read_data                      (fms_eth_read_data    ),
.fms_read_data_vld                  (fms_eth_read_data_vld),
    // RX
.ddr_weight_rd_clk                  (mem_clk),
.ddr_weight_rd_en                   (ddr_eth_weight_fifo_en),
.ddr_weight_data                    (eth_ddr_weight_data         ),
.ddr_weight_empty                   (eth_ddr_weight_empty        ),
.itlc_eth_write_ddr_done            (eth_itlc_eth_write_ddr_done ),

.fms_write_clk                      (eth_fms_write_clk          ),
.fms_write_addr                     (eth_fms_write_addr         ),
.fms_write_data                     (eth_fms_write_data     ),
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

send2pc_test u_send2pc_test(
		.clk(clk),
		.rst_n(rst_n),
    	.fms_read_clk(eth_fms_read_clk),
    	.fms_read_en(eth_fms_read_en),
    	.fms_read_addr(eth_fms_read_addr),
		.itlc_eth_read_fms_done(eth_itlc_eth_read_fms_done),
		.fms_read_data(fms_eth_read_data),
    	.fms_read_data_vld(fms_eth_read_data_vld),
		.itlc_fms_read_req(itlc_fms_read_req)
    );


//clk_wiz_0 clk_wiz_0
//(
//    .clk_in1_p   (sys_clk_p),
//    .clk_in1_n   (sys_clk_n),
//    .clk_out_15  (clk_15_625),
//    .clk_out_333 (clk_333_33),
//    .clk_out_125 (clk_125),
//    .clk_out_25  (clk_25),
//    .clk_out_200 (clk_200),
//    .locked      (locked)
//);
clk_wiz_0 clk_wiz_0(
//.clk_in1_p  (sys_clk_p),
//.clk_in1_n  (sys_clk_n),
.clk_in1  (clk),
.clk_out1   (clk_15_625),
.clk_out2   (clk_333_33),
.clk_out3   (clk_125),
.clk_out4   (clk_25),
.clk_out5   (clk_200),
.locked     (locked));
reg current_flag;
reg [255:0] data_cnt;
wire current_led;
always @(posedge mem_clk or negedge rst_n)begin
    if(!rst_n)begin
        current_flag <= 1'b0; 
        data_cnt    <= 'd0;
    end
    else if(ddr_eth_weight_fifo_en)begin //300MHz
            data_cnt <= data_cnt +1'b1;
        if(eth_ddr_weight_data==data_cnt)begin //300MHz
            current_flag <= 1'b1;
        end
        else begin
            current_flag <= 1'b0;
        end
    end
    else begin
        current_flag <= current_flag;
        data_cnt <= data_cnt;
    end
end
assign current_led = ~current_flag;

reg [4:0] init_cnt;
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        init_cnt <= 'd0;
    end
    else if(init_calib_complete)begin
        if(init_cnt == 'd20)
            init_cnt <= init_cnt;
        else 
            init_cnt <= init_cnt + 1'b1;
    end
end
assign itlc_ddr_weight_init = (init_cnt == 'd20-1'b1) ? 1'b1 : 1'b0;
assign rst_n = sys_rst;
endmodule
