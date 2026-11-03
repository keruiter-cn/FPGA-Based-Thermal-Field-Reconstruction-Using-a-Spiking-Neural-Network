`define UNET
`ifndef _proj_snn_vh_
`define _proj_snn_vh_


/*************Weight Last Layer******************/
`ifdef UNET
//`define     WEIGHT_LAST_LAYER  'h4FB64CF20000512A5ABE4B5F2C524F8E4ED21C2550875C1951E850581C8056614D625AC800005D924DF6FAD50000141907174F0A4A644EA406544B1D47E95313
`define     WEIGHT_LAST_LAYER  'hF8E03E781C90329AF456EE84384C58AC43ECEE231B1841670000000000000000DAB6F8E81951E56E276F00003BC5289700004A89E3BA23EF30FCF887205946BD
`else
`define     WEIGHT_LAST_LAYER  'h54A851F107A355D15DF450D4334E54E6546822EE4E875F1E537953BC23C3597250A55F0C070B61D04F8DFD45072E1AF00D48534F4DDC53140D6650404C1A587C
`endif 

`define     TIMESTEP 3
`define     TS_INDEX $clog2(`TIMESTEP)  //timestep index
`define     SPIKE_INCH_WIDTH 32 //Ò»´Î¸øPEµÄÊäÈëÍ¨µÀ¸öÊý
`define     PE_NUM 32
`define     SHIFT_WIDTH 4 //
`define     SLIDE_NUM 40000 //Ã¿Ò»²ã×î´óµÄ»¬´°´ÎÊý
`define     SLIDE_NUM_INDEX $clog2(`SLIDE_NUM)
`define     MAIN_MEM_DEPTH 40000
`define     MAIN_MEM_INDEX $clog2(`MAIN_MEM_DEPTH)
`define     IN_CH_INDEX 4
`define     MAX_WIDTH 200
`define     MAX_WIDTH_INDEX $clog2(`MAX_WIDTH)
`define     AVGPOOL_WEIGHT 1
`define     AVGPOOL_THRESHOLD 4
`define     WEIGHT_WIDTH 16
`define     THRESHOLD_WIDTH  `WEIGHT_WIDTH 
`define     BIAS_WIDTH 16
`define     ACC_WIDTH 32
`define     OUTCH_NUM_WIDTH 4

`ifdef UNET
`define     LAYER_NUM 27 //²ãÊýÍ³¼Æ£¬°üÀ¨pooling
`define     LAYER_INDEX $clog2(`LAYER_NUM)
`else
`define     LAYER_NUM 19 //²ãÊýÍ³¼Æ£¬°üÀ¨pooling
`define     LAYER_INDEX $clog2(`LAYER_NUM)
`endif

/************RAM define*************/
`define     WEIGHT_RAM_DEPTH 144
`define     WEIGHT_RAM_INDEX $clog2(`WEIGHT_RAM_DEPTH)
`define     WEIGHT_RAM_WIDTH 512
`define     DDR_WIDTH 256
`define     DDR_ADDR_WIDTH 29
`define     RAM_ADDR_WIDTH  29
`define     FMS_RAM_DEPTH 40000 //fms bufferÖÐÃ¿¸öbramµÄÉî¶È
`define     FMS_RAM_INDEX $clog2(`FMS_RAM_DEPTH) //fms bufferÃ¿¸öBRAMµÄµØÖ·Î»¿í
`define     ETH_TRANSMIT_RAM_INDEX FMS_RAM_INDEX+2 //eth·¢ËÍÊ±¶ÁbramµÄµØÖ·Î»¿í
`define     MAX_KERNEL_NUM 144 //16*9
`define     MAX_KERNEL_INDEX  $clog2(`MAX_KERNEL_NUM )
`define     URAM_DEPTH 77304
`define     URAM_INDEX $clog2(`URAM_DEPTH)
`define     DDR_INDEX 32


/************ ETH defines ***********/
`define ETH_TX_APP_WIDTH 64 // eth用户接口发�?�数据位�???
`define ETH_TX_RAM_WIDTH 64
`define ETH_TX_RAM_DEPTH `FMS_RAM_DEPTH/(`ETH_TX_RAM_WIDTH/32) // eth发�?�时每个bram的深�???
`define ETH_TX_RAM_NUM 1 // eth认为的bram的数�???
`define ETH_TX_RAM_SEL_INDEX $clog2(`ETH_TX_RAM_NUM) // 用于bram片�?�的地址位宽
`define ETH_TX_RAM_ADDR_INDEX $clog2(`ETH_TX_RAM_DEPTH) // 用于bram地址的地�???位宽
`define ETH_TX_RAM_INDEX `ETH_TX_RAM_SEL_INDEX+`ETH_TX_RAM_ADDR_INDEX // eth发�?�时读bram的地�???位宽
`define ETH_TX_READ_NUM `ETH_TX_RAM_DEPTH*`ETH_TX_RAM_NUM // eth读取的�?�地�?�? /20000
`define ETH_TX_READ_NUM_SINGLE 1280/(`ETH_TX_RAM_WIDTH/8) // eth发�?�一次读的地�?�? 1280/64/8 = 1
`define ETH_TX_FRAME_NUM `ETH_TX_READ_NUM*(`ETH_TX_RAM_WIDTH/8)/(`ETH_TX_READ_NUM_SINGLE*(`ETH_TX_RAM_WIDTH/8)) // eth要发送的帧数
//20000 * (64/8) / (180 * (64/8)) = 总byte�?/每一次读取的地址�?*每一个地�?的byte�? 20000*64/8/180*8 
`define ETH_RX_APP_WIDTH 64 // eth用户接口接收数据位宽
`define ETH_RX_RAM_WIDTH 64
`define ETH_RX_RAM_DEPTH `FMS_RAM_DEPTH/(`ETH_RX_RAM_WIDTH/32) // eth接收时，每个fms bram的深�???
`define ETH_RX_RAM_NUM `TIMESTEP // eth认为的fms bram的数�???
`define ETH_RX_RAM_SEL_INDEX $clog2(`ETH_RX_RAM_NUM) // 用于fms bram片�?�的地址位宽
`define ETH_RX_RAM_ADDR_INDEX $clog2(`ETH_RX_RAM_DEPTH) // 用于fms bram地址的地�???位宽
`define ETH_RX_RAM_INDEX `ETH_RX_RAM_SEL_INDEX+`ETH_RX_RAM_ADDR_INDEX // eth接收时写fms bram的地�???位宽

`ifdef UNET
`define ETH_RX_WEIGHT_NUM 13963328 // eth接收时，weight数据的�?�字节数
//`define ETH_RX_WEIGHT_NUM 15530048 // eth接收时，weight数据的�?�字节数
`define ETH_RX_FMS_NUM 480000 // eth接收时，fms数据的�?�字节数
`else
`define ETH_RX_WEIGHT_NUM 2887744 // eth接收时，weight数据的�?�字节数
`define ETH_RX_FMS_NUM 480000 // eth接收时，fms数据的�?�字节数
`endif

`endif
