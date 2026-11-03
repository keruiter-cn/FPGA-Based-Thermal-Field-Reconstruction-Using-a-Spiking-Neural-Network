`ifndef _proj_snn_vh_
`define _proj_snn_vh_

`define     TIMESTEP 8
`define     TS_INDEX $clog2(`TIMESTEP)  //timestep index
`define     SPIKE_INCH_WIDTH 32 //Ò»´Î¸øPEµÄÊäÈëÍ¨µÀ¸öÊý
`define     PE_NUM 32
`define     SHIFT_WIDTH 4 //
`define     SLIDE_NUM 40000 //Ã¿Ò»²ã×î´óµÄ»¬´°´ÎÊý
`define     SLIDE_NUM_INDEX $clog2(`SLIDE_NUM)
`define     LAYER_INDEX 5 //Ö¸Ê¾ddrÐ´Èë¶ÁÈ¡µÄÊÇÄÄÒ»²ã
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
`define     ACC_WIDTH 26
`define     OUTCH_NUM_WIDTH 4
`define LAYER_NUM 27 //²ãÊýÍ³¼Æ£¬°üÀ¨pooling
`define LAYER_INDEX $clog2(`LAYER_NUM)
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
`define ETH_TX_APP_WIDTH 64 // eth用户接口发送数据位宽
`define ETH_TX_RAM_WIDTH 64
`define ETH_TX_RAM_DEPTH `FMS_RAM_DEPTH/(`ETH_TX_RAM_WIDTH/32) // eth发送时每个bram的深度
`define ETH_TX_RAM_NUM 1 // eth认为的bram的数量
`define ETH_TX_RAM_SEL_INDEX $clog2(`ETH_TX_RAM_NUM) // 用于bram片选的地址位宽
`define ETH_TX_RAM_ADDR_INDEX $clog2(`ETH_TX_RAM_DEPTH) // 用于bram地址的地址位宽
`define ETH_TX_RAM_INDEX `ETH_TX_RAM_SEL_INDEX+`ETH_TX_RAM_ADDR_INDEX // eth发送时读bram的地址位宽
`define ETH_TX_READ_NUM `ETH_TX_RAM_DEPTH*`ETH_TX_RAM_NUM // eth发送时总读取地址数
`define ETH_TX_READ_NUM_SINGLE 1280/(`ETH_TX_RAM_WIDTH/8) // eth发送时一次读取地址数
`define ETH_TX_FRAME_NUM `ETH_TX_READ_NUM*(`ETH_TX_RAM_WIDTH/8)/(`ETH_TX_READ_NUM_SINGLE*(`ETH_TX_RAM_WIDTH/8)) // eth需要发送的帧数

`define ETH_RX_APP_WIDTH 64 // eth用户接口接收数据位宽
`define ETH_RX_RAM_WIDTH 64
`define ETH_RX_RAM_DEPTH `FMS_RAM_DEPTH/(`ETH_RX_RAM_WIDTH/32) // eth接收时，每个fms bram的深度
`define ETH_RX_RAM_NUM 8 // eth认为的fms bram的数量
`define ETH_RX_RAM_SEL_INDEX $clog2(`ETH_RX_RAM_NUM) // 用于fms bram片选的地址位宽
`define ETH_RX_RAM_ADDR_INDEX $clog2(`ETH_RX_RAM_DEPTH) // 用于fms bram地址的地址位宽
`define ETH_RX_RAM_INDEX `ETH_RX_RAM_SEL_INDEX+`ETH_RX_RAM_ADDR_INDEX // eth接收时写fms bram的地址位宽
`define ETH_RX_WEIGHT_NUM 40000 // eth接收时，weight数据的总字节数
`define ETH_RX_FMS_NUM 20000*8 // eth接收时，fms数据的总字节数


`endif
