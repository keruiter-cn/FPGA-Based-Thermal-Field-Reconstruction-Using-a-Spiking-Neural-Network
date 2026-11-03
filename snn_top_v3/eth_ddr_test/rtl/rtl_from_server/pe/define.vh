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
`define WEIGHT_RAM_DEPTH 144
`define WEIGHT_RAM_INDEX $clog2(`WEIGHT_RAM_DEPTH)
`define WEIGHT_RAM_WIDTH 512
`define DDR_WIDTH 256
`define FMS_RAM_DEPTH 40000 //fms bufferÖÐÃ¿¸öbramµÄÉî¶È
`define FMS_RAM_INDEX $clog2(`FMS_RAM_DEPTH) //fms bufferÃ¿¸öBRAMµÄµØÖ·Î»¿í
`define ACC_WIDTH 26
