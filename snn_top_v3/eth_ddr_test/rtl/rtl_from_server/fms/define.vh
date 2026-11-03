`define TIMESTEP 8 
`define TS_INDEX $clog2(`TIMESTEP)  //timestep index
`define SPIKE_INCH_WIDTH 32 //Ò»´Î¸øPEµÄÊäÈëÍ¨µÀ¸öÊý
`define PE_NUM 32
`define SHIFT_WIDTH 4 //
`define SLIDE_NUM 40000 //Ã¿Ò»²ã×î´óµÄ»¬´°´ÎÊý
`define SLIDE_NUM_INDEX $clog2(`SLIDE_NUM)
`define LAYER_INDEX 5 //Ö¸Ê¾ddrÐ´Èë¶ÁÈ¡µÄÊÇÄÄÒ»²ã
`define MAIN_MEM_DEPTH 40000
`define MAIN_MEM_INDEX $clog2(`MAIN_MEM_DEPTH)
`define IN_CH_INDEX 4
`define MAX_WIDTH 200
`define MAX_WIDTH_INDEX $2clog(`MAX_WIDTH)
`define AVGPOOL_WEIGHT 1
`define AVGPOOL_THRESHOLD 4
`define WEIGHT_WIDTH 16
`define THRESHOLD_WIDTH  `WEIGHT_WIDTH 
`define BIAS_WIDTH 16
`define LAYER_NUM 27//²ãÊýÍ³¼Æ£¬°üÀ¨pooling
`define LAYER_INDEX $clog2(`LAYER_NUM)
/************RAM define*************/
`define WEIGHT_RAM_DEPTH 144
`define WEIGHT_RAM_INDEX $clog2(`WEIGHT_RAM_DEPTH)
`define WEIGHT_RAM_WIDTH 512
`define DDR_WIDTH 256
`define DDR_INDEX 29
`define FMS_RAM_DEPTH 40000 //fms bufferÖÐÃ¿¸öbramµÄÉî¶È
`define FMS_RAM_INDEX $clog2(`FMS_RAM_DEPTH) //fms bufferÃ¿¸öBRAMµÄµØÖ·Î»¿í
`define URAM_DEPTH 77304
`define URAM_INDEX $clog2(`URAM_DEPTH)
/************ ETH defines ***********/
`define ETH_TX_APP_WIDTH 64 // ethÓÃ»§½Ó¿Ú·¢ËÍÊý¾ÝÎ»¿í
`define ETH_TX_RAM_WIDTH 64
`define ETH_TX_RAM_DEPTH `FMS_RAM_DEPTH/(`ETH_TX_RAM_WIDTH/32) // eth·¢ËÍÊ±Ã¿¸öbramµÄÉî¶È
`define ETH_TX_RAM_NUM 8 // ethÈÏÎªµÄbramµÄÊýÁ¿
`define ETH_TX_RAM_SEL_INDEX $clog2(`ETH_TX_RAM_NUM) // ÓÃÓÚbramÆ¬Ñ¡µÄµØÖ·Î»¿í
`define ETH_TX_RAM_ADDR_INDEX $clog2(`ETH_TX_RAM_DEPTH) // ÓÃÓÚbramµØÖ·µÄµØÖ·Î»¿í
`define ETH_TX_RAM_INDEX `ETH_TX_RAM_SEL_INDEX+`ETH_TX_RAM_ADDR_INDEX // eth·¢ËÍÊ±¶ÁbramµÄµØÖ·Î»¿í
`define ETH_TX_READ_NUM `FMS_RAM_DEPTH // eth·¢ËÍÊ±×Ü¶ÁÈ¡µØÖ·Êý
`define ETH_TX_READ_NUM_SINGLE 1280 // eth·¢ËÍÊ±Ò»´Î¶ÁÈ¡µØÖ·Êý
`define ETH_TX_FRAME_NUM `ETH_TX_RAM_DEPTH*`ETH_TX_RAM_NUM*(`ETH_TX_RAM_WIDTH/8)/`ETH_TX_READ_NUM_SINGLE // ethÐèÒª·¢ËÍµÄÖ¡Êý

`define ETH_RX_APP_WIDTH 64 // ethÓÃ»§½Ó¿Ú½ÓÊÕÊý¾ÝÎ»¿í
`define ETH_RX_RAM_WIDTH 64
`define ETH_RX_RAM_DEPTH `FMS_RAM_DEPTH/(`ETH_RX_RAM_WIDTH/32) // eth½ÓÊÕÊ±£¬Ã¿¸öfms bramµÄÉî¶È
`define ETH_RX_RAM_NUM 8 // ethÈÏÎªµÄfms bramµÄÊýÁ¿
`define ETH_RX_RAM_SEL_INDEX $clog2(`ETH_RX_RAM_NUM) // ÓÃÓÚfms bramÆ¬Ñ¡µÄµØÖ·Î»¿í
`define ETH_RX_RAM_ADDR_INDEX $clog2(`ETH_RX_RAM_DEPTH) // ÓÃÓÚfms bramµØÖ·µÄµØÖ·Î»¿í
`define ETH_RX_RAM_INDEX `ETH_RX_RAM_SEL_INDEX+`ETH_RX_RAM_ADDR_INDEX // eth½ÓÊÕÊ±Ð´fms bramµÄµØÖ·Î»¿í
`define ETH_RECEIVE_WEIGHT_NUM // eth½ÓÊÕÊ±£¬weightÊý¾ÝµÄ×Ö½ÚÊý
/************ pe define***/
`define ACC_WIDTH 26 //ÀÛ¼Ó¼Ä´æÆ÷µÄÎ»¿í
`define OUTCH_NUM_WIDTH 4
