`include "proj_snn.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/24/2024 03:15:04 PM
// Design Name: 
// Module Name: bram_read_control
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


module bram_read_control(
input   wire                               clk                     ,
input   wire                               rst_n                   ,
input   wire                               ilc_enable              ,
input   wire   [`SHIFT_WIDTH-1:0]          ilc_shift_value           ,
input   wire                               ilc_padding_or_not       ,
//input   wire                               ilc_slide_over_ack          ,
input   wire    [`MAX_WIDTH_INDEX-1:0]     ilc_fms_length           ,
input   wire    [3:0]                      ilc_in_ch_num            ,
input   wire                               ilc_read_start           ,
input   wire                               itlc_vld                ,
input   wire                               itlc_concat_or_not       ,
input   wire                               itlc_first_layer_or_not  ,
input   wire                               itlc_last_layer_or_not  ,
input   wire                               itlc_conv_or_not        ,
input   wire                               itlc_convt_or_not       ,
input   wire                               itlc_avgpool_or_not     ,
input   wire                               itlc_sp_pool            ,
input   wire    [`SPIKE_INCH_WIDTH-1:0]     fms_spike_din           ,
input   wire                               fms_data_valid          ,
output  wire                               ilc_bwc_slide_over_req  ,
output  wire                               ilc_cat_half_finish     ,
output  reg     [`SLIDE_NUM_INDEX-1:0]     ilc_slide_position      ,
output  wire    [`FMS_RAM_INDEX-1:0]       fms_read_addr           ,
output  reg                                fms_read_en             ,
output  reg    [`TS_INDEX-1:0]             fms_bwc_ts_cs           ,
output  wire                               pec_dout_vld            ,
output  wire    [`SPIKE_INCH_WIDTH-1:0]    pec_spike_dout          ,
output  wire                               pec_one_spike           ,
output  wire                               pec_row_end_vld         ,
output  wire                               pec_fire_enable         ,
output  wire                               pec_ts_end_vld
    );


reg                              first_layer_or_not  ;
reg                              last_layer_or_not   ; 

reg                              conv_or_not         ;
reg                              convt_or_not        ;
reg                              avgpool_or_not      ;
reg                              concat_or_not       ;
wire                             sp_pool             ;
reg     [`MAX_KERNEL_INDEX-1:0]  kernel_row_incr     ;

reg     [1:0]                    kernel_row_num        ; //switch row1_base_addr or row2/row3_base_addr
wire                             kernel_rc_over   ; //read control over
reg    [3:0]                     padding_method      ;
reg    [`MAIN_MEM_INDEX-1:0]     row1_base_addr           ;
reg    [`MAIN_MEM_INDEX-1:0]     row2_base_addr           ;
reg    [`MAIN_MEM_INDEX-1:0]     row3_base_addr           ;
reg    [`MAIN_MEM_INDEX-1:0]     base_addr           ;
wire    [`MAIN_MEM_INDEX-1:0]     convt_addr         ;
reg    [`MAX_WIDTH_INDEX-1:0]    col_slide_cnt;
reg    [`MAX_WIDTH_INDEX-1:0]    row_slide_cnt;
wire                             kernel_switch_row;
reg    [3:0]                     inch_inr_cnt;
reg    [3:0]                     kernel_pos;
reg    [3:0]                     inch_inr_cnt2;
reg    [3:0]                     kernel_pos2;
reg                              zero_dout_vld;
reg                              kernel_flag; //it is 1'b1 when kernel compute
reg                              ts_kernel_flag;
reg    [3:0]                     slide_over_cnt;

reg                              convt_cyc_col_cnt;
reg                              convt_cyc_row_cnt;
reg     [`MAX_KERNEL_INDEX-1:0]  send_receive_cnt;
reg     [`MAX_KERNEL_INDEX-1:0]  uram_addr_incr     ;
reg     [`MAX_KERNEL_INDEX-1:0]  bram_addr_incr     ;
wire                             cat_half_flag;
wire                             half_cat_read_start;
wire                             u_bram_switch;
wire                             uram_read_over;

assign sp_pool = itlc_sp_pool;

assign fms_read_addr = (fms_read_en) ? ((convt_or_not)? convt_addr: base_addr+kernel_row_incr):{`FMS_RAM_INDEX{1'b0}};
assign convt_addr = (u_bram_switch) ? base_addr + uram_addr_incr: base_addr+bram_addr_incr;
 
assign pec_ts_end_vld = ((fms_bwc_ts_cs==`TIMESTEP -1'b1)&&pec_fire_enable) ? 1'b1: 1'b0;

assign pec_fire_enable = conv_or_not ? ((kernel_pos2== 4'd9-1'b1&&inch_inr_cnt2==ilc_in_ch_num)? 1'b1: 1'b0 ):((avgpool_or_not)? ((kernel_pos2== 4'd4-1'b1)? 1'b1: 1'b0 ):(convt_or_not)? ((inch_inr_cnt2==ilc_in_ch_num)? 1'b1: 1'b0):1'b0);

assign pec_spike_dout = (pec_dout_vld)?((fms_data_valid)? fms_spike_din :{`SPIKE_INCH_WIDTH{1'b0}}):{`SPIKE_INCH_WIDTH{1'b0}};

assign pec_one_spike =  (first_layer_or_not) ? ((pec_dout_vld)?((fms_data_valid)? fms_spike_din[0]:1'b0):1'b0) : 1'b0;

assign pec_dout_vld = (zero_dout_vld||fms_data_valid) ? 1'b1:1'b0;

assign pec_row_end_vld = ((((col_slide_cnt==ilc_fms_length-1'b1)&&(conv_or_not||(convt_or_not&&convt_cyc_col_cnt)))||((col_slide_cnt==ilc_fms_length-'d2)&&avgpool_or_not)||((col_slide_cnt==ilc_fms_length-'d3)&&sp_pool))&&pec_ts_end_vld) ? 1'b1:1'b0;

assign kernel_switch_row = (conv_or_not) ? (((kernel_pos==4'd2||kernel_pos==4'd5||kernel_pos==4'd8)&&inch_inr_cnt==ilc_in_ch_num) ? 1'b1: 1'b0):
((avgpool_or_not)? ((kernel_pos==4'd1||kernel_pos==4'd3)? 1'b1: 1'b0):1'b0);

assign kernel_rc_over = conv_or_not ? ((kernel_pos== 4'd9-1'b1&&inch_inr_cnt==ilc_in_ch_num)? 1'b1: 1'b0):((avgpool_or_not) ? ((kernel_pos== 4'd4-1'b1)? 1'b1: 1'b0):((convt_or_not)? ((inch_inr_cnt==ilc_in_ch_num) ? 1'b1: 1'b0):1'b0));

assign ilc_bwc_slide_over_req = (conv_or_not) ?(row_slide_cnt == ilc_fms_length-1'b1&&pec_row_end_vld):
((avgpool_or_not) ? (sp_pool ? (row_slide_cnt == ilc_fms_length-'d3&&pec_row_end_vld):
(row_slide_cnt == ilc_fms_length-'d2&&pec_row_end_vld)):
((convt_or_not) ? (row_slide_cnt == ilc_fms_length-1'b1&&pec_row_end_vld&&convt_cyc_row_cnt): 1'b0));

assign cat_half_flag = (convt_or_not) ? (inch_inr_cnt==((({1'b0,ilc_in_ch_num}+1'b1)>>1)) ? 1'b1:1'b0): 1'b0;

assign uram_read_over = (convt_or_not) ? ((inch_inr_cnt==((({1'b0,ilc_in_ch_num}+1'b1)>>1)-1'b1)) ? 1'b1:1'b0): 1'b0;

assign u_bram_switch = (convt_or_not) ? ((inch_inr_cnt<(({1'b0,ilc_in_ch_num}+1'b1)>>1)) ? 1'b1:1'b0): 1'b0;

assign half_cat_read_start = (convt_or_not) ? ((send_receive_cnt=='d0&&cat_half_flag)? 1'b1:1'b0) : 1'b0;

assign ilc_cat_half_finish = (convt_or_not) ? (half_cat_read_start&&~kernel_flag) : 1'b0;
//register control signal of this layer
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        first_layer_or_not<= 1'b0;
        last_layer_or_not <= 1'b0;
        conv_or_not       <= 1'b0;
        convt_or_not      <= 1'b0;
        avgpool_or_not    <= 1'b0;
        concat_or_not     <= 1'b0;
        //sp_pool           <= 1'b0;
    end
    else if(itlc_vld)begin
        first_layer_or_not<= itlc_first_layer_or_not    ;
        last_layer_or_not <= itlc_last_layer_or_not     ;
        concat_or_not     <= itlc_concat_or_not         ;
        conv_or_not       <= itlc_conv_or_not           ;
        convt_or_not      <= itlc_convt_or_not          ;
        avgpool_or_not    <= itlc_avgpool_or_not        ;
        //sp_pool           <= itlc_sp_pool               ;
    end
    else begin
        first_layer_or_not<= first_layer_or_not;
        last_layer_or_not <= last_layer_or_not ;
        concat_or_not     <= concat_or_not     ;
        conv_or_not       <= conv_or_not       ;
        convt_or_not      <= convt_or_not      ;
        avgpool_or_not    <= avgpool_or_not    ;
        //sp_pool           <= sp_pool           ;
    end
end
always @(*)begin
    if(ilc_padding_or_not)begin
        if(col_slide_cnt=='d0&&row_slide_cnt=='d0)begin
            padding_method = 4'b1010;
        end
        else if(col_slide_cnt==(ilc_fms_length-1'b1)&&row_slide_cnt=='d0)begin
            padding_method = 4'b1001;
        end
        else if(row_slide_cnt==(ilc_fms_length-1'b1)&&col_slide_cnt=='d0)begin
             padding_method = 4'b0110;
        end
        else if(row_slide_cnt==(ilc_fms_length-1'b1)&&col_slide_cnt==(ilc_fms_length-1'b1))begin
             padding_method = 4'b0101;
        end
        else if((col_slide_cnt!='d0&&col_slide_cnt!=(ilc_fms_length-1'b1))&&row_slide_cnt=='d0)begin
            padding_method = 4'b1000;
        end
        else if((col_slide_cnt!='d0&&col_slide_cnt!=(ilc_fms_length-1'b1))&&row_slide_cnt==(ilc_fms_length-1'b1))begin
            padding_method = 4'b0100;
        end
        else if((row_slide_cnt>1'b0&&row_slide_cnt<(ilc_fms_length-1'b1))&&col_slide_cnt=='d0)begin
            padding_method = 4'b0010;
        end
        else if((row_slide_cnt>1'b0&&row_slide_cnt<(ilc_fms_length-1'b1))&&col_slide_cnt==(ilc_fms_length-1'b1))begin
            padding_method = 4'b0001;
        end
        else begin
            padding_method = 4'b0000;
        end
    end
    else begin
        padding_method = 4'b0000;
    end
end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        ilc_slide_position <= {`SLIDE_NUM_INDEX{1'b0}};
    end
    else if(ilc_enable)begin
        if(conv_or_not)begin
            if(ilc_bwc_slide_over_req)
                ilc_slide_position <= {`SLIDE_NUM_INDEX{1'b0}};
            else if(pec_ts_end_vld)
                ilc_slide_position <= ilc_slide_position + 1'b1;
            else 
                ilc_slide_position <= ilc_slide_position;
        end
        else if(avgpool_or_not)begin
             if(ilc_bwc_slide_over_req)
                ilc_slide_position <= {`SLIDE_NUM_INDEX{1'b0}};
            else if(pec_row_end_vld&&sp_pool)
                ilc_slide_position <= ilc_slide_position + ilc_fms_length+'d3;
            else if(pec_row_end_vld)
                ilc_slide_position <= ilc_slide_position + ilc_fms_length+'d2;
            else if(pec_ts_end_vld)
                ilc_slide_position <= ilc_slide_position + 'd2;
            else 
                ilc_slide_position <= ilc_slide_position;           
        end
        else if(convt_or_not)begin
            if(ilc_bwc_slide_over_req)
                ilc_slide_position <= {`SLIDE_NUM_INDEX{1'b0}};
            else if(pec_row_end_vld&&(~convt_cyc_row_cnt))
                ilc_slide_position <= ilc_slide_position + 1'b1 - ilc_fms_length;
            else if(pec_ts_end_vld&&convt_cyc_col_cnt)
                ilc_slide_position <= ilc_slide_position + 1'b1;
            else 
                ilc_slide_position <= ilc_slide_position;           
        end
        else begin
            ilc_slide_position <= {`SLIDE_NUM_INDEX{1'b0}};
        end
    end
    else begin
        ilc_slide_position <= ilc_slide_position;
    end
end 

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        ts_kernel_flag <= 1'b0;
    end
    else if(ilc_enable)begin
        if(conv_or_not||avgpool_or_not)begin
            if(ilc_read_start)
                ts_kernel_flag <= 1'b1;
            else if(pec_ts_end_vld)
                ts_kernel_flag <= 1'b0;
            else
                ts_kernel_flag <= ts_kernel_flag;
        end
        else begin
            ts_kernel_flag <= 1'b0;
        end
    end
    else begin
        ts_kernel_flag <= ts_kernel_flag;
    end
end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        bram_addr_incr <= {`MAX_KERNEL_INDEX{1'b0}};
        uram_addr_incr <= {`MAX_KERNEL_INDEX{1'b0}};
    end
    else if(ilc_enable&&convt_or_not)begin
        if(pec_fire_enable)begin
            bram_addr_incr <= {`MAX_KERNEL_INDEX{1'b0}};
            uram_addr_incr <= {`MAX_KERNEL_INDEX{1'b0}};
        end
        else if(fms_read_en)begin
            if(u_bram_switch)begin
                uram_addr_incr <= uram_addr_incr + 1'b1;
                bram_addr_incr <= bram_addr_incr;
            end
            else begin
                uram_addr_incr <= uram_addr_incr;
                bram_addr_incr <= bram_addr_incr + 1'b1;
            end
        end
        else begin
           bram_addr_incr <= bram_addr_incr ;
           uram_addr_incr <= uram_addr_incr ;
        end
    end
    else begin
        bram_addr_incr <= {`MAX_KERNEL_INDEX{1'b0}};
        uram_addr_incr <= {`MAX_KERNEL_INDEX{1'b0}};
    end
end
//control this read addr
//when fms_read_en, kernel_row_incr always increase on one row
always @(posedge clk or negedge rst_n)begin
    if(!rst_n||pec_fire_enable)begin
        kernel_row_incr <= {`MAX_KERNEL_INDEX{1'b0}};
    end
    else if(ilc_enable)begin
        if(conv_or_not)begin
            if(fms_read_en)begin
                if(kernel_switch_row)
                    kernel_row_incr <= {`MAX_KERNEL_INDEX{1'b0}};
                else
                    kernel_row_incr <= kernel_row_incr + 1'b1;
            end
            else begin
                kernel_row_incr <= {`MAX_KERNEL_INDEX{1'b0}};
            end
        end
        else if(avgpool_or_not)begin
            if(fms_read_en)begin
                if(kernel_switch_row)
                    kernel_row_incr <= {`MAX_KERNEL_INDEX{1'b0}};
                else
                    kernel_row_incr <= kernel_row_incr + ilc_in_ch_num + 1'b1;
            end
            else begin
                kernel_row_incr <= {`MAX_KERNEL_INDEX{1'b0}};
            end

        end
    end
    else begin
        kernel_row_incr <= kernel_row_incr;
    end
end
always @(posedge clk or negedge rst_n)begin
    if(!rst_n||pec_fire_enable)begin
        kernel_row_num <= 2'b00;
    end
    else if(ilc_enable)begin
        if(kernel_rc_over)
            kernel_row_num <= 2'b00;
        else begin
            if(kernel_switch_row)
                kernel_row_num <= kernel_row_num + 1'b1;
            else
                kernel_row_num <= kernel_row_num;
        end
    end
    else begin
        kernel_row_num <= kernel_row_num;
    end
end
//base addr
always @(*)begin
        case(kernel_row_num)
        2'b00:begin
            if(conv_or_not)
                base_addr = row1_base_addr;
            else if(avgpool_or_not)
                base_addr = row1_base_addr + slide_over_cnt;
            else if(convt_or_not)
                base_addr = ilc_slide_position<<(ilc_shift_value-1'b1);
            else
                base_addr = row1_base_addr;
        end
        2'b01:begin
            if(conv_or_not)
                base_addr = row2_base_addr;
            else if(avgpool_or_not)
                base_addr = row2_base_addr + slide_over_cnt;
            else if(convt_or_not)
                base_addr = ilc_slide_position<<(ilc_shift_value-1'b1);
            else
                base_addr = row2_base_addr;
        end
        2'b10:begin
            if(conv_or_not)
                base_addr = row3_base_addr;
            else if(avgpool_or_not)
                base_addr = row3_base_addr + slide_over_cnt;
            else if(convt_or_not)
                base_addr = ilc_slide_position<<(ilc_shift_value-1'b1);
            else
                base_addr = row3_base_addr;
        end
        default:begin
            if(conv_or_not)
                base_addr = row1_base_addr;
            else if(avgpool_or_not)
                base_addr = row1_base_addr + slide_over_cnt;
            else if(convt_or_not)
                base_addr = ilc_slide_position<<(ilc_shift_value-1'b1);
            else
                base_addr = row1_base_addr;
        end
        endcase
end
always @(posedge clk or negedge rst_n)begin
    if(!rst_n||itlc_vld)begin
        slide_over_cnt <= 4'd0;
    end
    else if(ilc_enable)begin
        if(ilc_bwc_slide_over_req)begin
            slide_over_cnt <= slide_over_cnt + 1'b1;
        end
        else begin
            slide_over_cnt <= slide_over_cnt;
        end
    end
    else begin
        slide_over_cnt <= slide_over_cnt;
    end
end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        send_receive_cnt <= {`MAX_KERNEL_INDEX{1'b0}};
    else if(ilc_enable&&convt_or_not)begin
        case({fms_read_en,fms_data_valid})
            2'b00: send_receive_cnt <= send_receive_cnt;
            2'b01: send_receive_cnt <= send_receive_cnt - 1'b1;
            2'b10: send_receive_cnt <= send_receive_cnt + 1'b1;
            2'b11: send_receive_cnt <= send_receive_cnt;
            default: send_receive_cnt <= send_receive_cnt;
        endcase
    end
    else begin
        send_receive_cnt <= {`MAX_KERNEL_INDEX{1'b0}};
    end
end

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        convt_cyc_col_cnt <= 1'b0;
    else if(ilc_enable&&convt_or_not)begin
        if(pec_ts_end_vld&(~convt_cyc_col_cnt))
            convt_cyc_col_cnt <= 1'b1;
        else if(pec_ts_end_vld&(convt_cyc_col_cnt))
            convt_cyc_col_cnt <= 1'b0;
        else
            convt_cyc_col_cnt <= convt_cyc_col_cnt;
    end
    else begin
        convt_cyc_col_cnt <= 1'b0;
    end
end
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)
        convt_cyc_row_cnt <= 1'b0;
    else if(ilc_enable&&convt_or_not)begin
        if(pec_row_end_vld&(~convt_cyc_row_cnt))
            convt_cyc_row_cnt <= 1'b1;
        else if(pec_row_end_vld&(convt_cyc_row_cnt))
            convt_cyc_row_cnt <= 1'b0;
        else
            convt_cyc_row_cnt <= convt_cyc_row_cnt;
    end
    else begin
        convt_cyc_row_cnt <= 1'b0;
    end
end

//the position of compute point now in the conv kernel
//this kernel_pos and inch_inr_cnt only relate to this fms read contorl signal,
//not relate to the feedback signal:fms_data_valid
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        inch_inr_cnt <= 4'd0;
        kernel_pos  <= 4'd0;
    end
    else if(ilc_enable)begin
        if(conv_or_not||convt_or_not)begin
            if(kernel_rc_over)begin
                kernel_pos <= 4'd0;
                inch_inr_cnt <= 4'd0;
            end
            else if(kernel_flag)begin
                if(inch_inr_cnt==ilc_in_ch_num)begin
                    inch_inr_cnt <= 4'd0;
                    kernel_pos  <= kernel_pos + 1'b1;
                end
                else begin
                    inch_inr_cnt <= inch_inr_cnt+1'b1;
                    kernel_pos  <= kernel_pos;
                end
            end
            else begin
                inch_inr_cnt <= inch_inr_cnt;
                kernel_pos  <= kernel_pos; 
            end
        end
        else if(avgpool_or_not)begin
            if(kernel_rc_over)begin
                kernel_pos <= 4'd0;
            end
            else if(kernel_flag)begin
                kernel_pos  <= kernel_pos + 1'b1; 

            end
            else begin
                kernel_pos  <= 4'd0; 
            end
        end
        else begin
            inch_inr_cnt <= 4'd0;
            kernel_pos  <= 4'd0;    
        end
    end
    else begin
        inch_inr_cnt <= inch_inr_cnt;
        kernel_pos   <= kernel_pos  ;
    end
end
// this kernel_pos2 and inch_inr_cnt2 is the really kernel position when transfer
// the data to pec
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        inch_inr_cnt2 <= 4'd0;
        kernel_pos2  <= 4'd0;
    end
    else if(ilc_enable)begin
        if(conv_or_not||convt_or_not)begin
            if(pec_fire_enable)begin
                kernel_pos2 <= 4'd0;
                inch_inr_cnt2 <= 4'd0;
            end
            else if(pec_dout_vld)begin
                if(inch_inr_cnt2==ilc_in_ch_num)begin
                    inch_inr_cnt2 <= 4'd0;
                    kernel_pos2  <= kernel_pos2 + 1'b1;
                end
                else begin
                    inch_inr_cnt2 <= inch_inr_cnt2+1'b1;
                    kernel_pos2  <= kernel_pos2;
                end
            end
            else begin
                inch_inr_cnt2 <= inch_inr_cnt2;
                kernel_pos2  <= kernel_pos2;
            end
        end
        else if(avgpool_or_not)begin
            if(pec_fire_enable)
                kernel_pos2 <= 4'd0;
            else if(pec_dout_vld)
                    kernel_pos2  <= kernel_pos2 + 1'b1;
            else 
                kernel_pos2  <= kernel_pos2;
            
        end
        else begin
            inch_inr_cnt2 <= 4'd0;
            kernel_pos2  <= 4'd0;
        end
    end
    else begin
        inch_inr_cnt2 <= 4'd0;
        kernel_pos2  <= 4'd0;
    end
end
//compute slide num in one row

always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        col_slide_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
    end
    else if(ilc_enable)begin
        if(conv_or_not)begin
            if(pec_ts_end_vld)begin
                if(pec_row_end_vld)
                    col_slide_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
                else
                    col_slide_cnt <=col_slide_cnt+1'b1;
            end
            else
                col_slide_cnt <=col_slide_cnt;
        end
        else if(avgpool_or_not)begin
             if(pec_ts_end_vld)begin
                if(pec_row_end_vld)
                    col_slide_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
                else
                    col_slide_cnt <=col_slide_cnt+'d2;
            end
            else
                col_slide_cnt <=col_slide_cnt;           
        end
        else if(convt_or_not)begin
            if(pec_ts_end_vld&&convt_cyc_col_cnt)begin
                if(pec_row_end_vld)
                    col_slide_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
                else
                    col_slide_cnt <=col_slide_cnt+1'b1;
            end
            else
                col_slide_cnt <=col_slide_cnt;
        end
    end
    else
        col_slide_cnt <=col_slide_cnt;
end
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        row_slide_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
    end
    else if(ilc_enable)begin
        if(conv_or_not)begin
            if(ilc_bwc_slide_over_req)
                row_slide_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
            else if(pec_row_end_vld)
                row_slide_cnt <=row_slide_cnt+1'b1;
            else
                row_slide_cnt <=row_slide_cnt;
        end
        else if(avgpool_or_not)begin
            if(ilc_bwc_slide_over_req)
                 row_slide_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
            else if(pec_row_end_vld)
                row_slide_cnt <=row_slide_cnt+ 'd2;
            else
                row_slide_cnt <=row_slide_cnt;           

        end
        else if(convt_or_not)begin
            if(ilc_bwc_slide_over_req)
                row_slide_cnt <= {`MAX_WIDTH_INDEX{1'b0}};
            else if(pec_row_end_vld&&convt_cyc_row_cnt)
                row_slide_cnt <=row_slide_cnt+1'b1;
            else
                row_slide_cnt <=row_slide_cnt;
        end
    end
    else
        row_slide_cnt <=row_slide_cnt;
end

//when compute kernel,kernel flag = 1'b1
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        kernel_flag <= 1'b0;
    end
    else if(ilc_enable)begin
        if(conv_or_not||avgpool_or_not||convt_or_not)begin
            if((ilc_read_start||pec_fire_enable||half_cat_read_start)&&(~pec_ts_end_vld))
                kernel_flag <= 1'b1;
            else if(kernel_rc_over||uram_read_over)
                kernel_flag <= 1'b0;
            else
                kernel_flag <= kernel_flag;
        end
        else 
            kernel_flag <= 1'b0;
    end
    else
         kernel_flag <= kernel_flag;
end
//time step chip select
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        fms_bwc_ts_cs <= {`TS_INDEX{1'b0}};
    end
    else if(ilc_enable)begin
        if(pec_fire_enable)begin
            if(pec_ts_end_vld)
                fms_bwc_ts_cs <= {`TS_INDEX{1'b0}};
            else
                fms_bwc_ts_cs <= fms_bwc_ts_cs + 1'b1;
        end
        else begin
            fms_bwc_ts_cs <= fms_bwc_ts_cs;
        end
    end
    else begin
        fms_bwc_ts_cs <= fms_bwc_ts_cs;
    end
end
always @(*)begin
        if(conv_or_not)begin
            if(kernel_flag)begin
                case(padding_method)
                4'b0000:begin  //when slide the center, no padding
                    if(kernel_pos<'d9)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end
                end
                4'b1010:begin //up padding and left padding
                    if(kernel_pos=='d4||kernel_pos=='d5||kernel_pos=='d7||kernel_pos=='d8)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end
                end
                4'b1000:begin //only up padding
                    if(kernel_pos=='d3||kernel_pos=='d4||kernel_pos=='d5||kernel_pos=='d6||kernel_pos=='d7||kernel_pos=='d8)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end
                end
                4'b1001:begin //up padding and right padding
                    if(kernel_pos=='d3||kernel_pos=='d4||kernel_pos=='d6||kernel_pos=='d7)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end
                end
                4'b0010:begin //only left padding
                    if(kernel_pos=='d1||kernel_pos=='d2||kernel_pos=='d4||kernel_pos=='d5||kernel_pos=='d7||kernel_pos=='d8)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end
                end
                4'b0001:begin //only right padding
                if(kernel_pos=='d0||kernel_pos=='d1||kernel_pos=='d3||kernel_pos=='d4||kernel_pos=='d6||kernel_pos=='d7)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end 
                end
                4'b0110:begin //left padding and down padding
                    if(kernel_pos=='d1||kernel_pos=='d2||kernel_pos=='d4||kernel_pos=='d5)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end
                end
                4'b0100:begin //only down padding
                    if(kernel_pos=='d0||kernel_pos=='d1||kernel_pos=='d2||kernel_pos=='d3||kernel_pos=='d4||kernel_pos=='d5)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end 
                end
                4'b0101:begin //down padding and right padding
                    if(kernel_pos=='d0||kernel_pos=='d1||kernel_pos=='d3||kernel_pos=='d4)begin
                       fms_read_en = 1'b1;
                    end
                    else begin
                       fms_read_en = 1'b0;
                    end
                end
                default:begin
                    fms_read_en = 1'b0;
                end
                endcase
            end
            else begin
                  fms_read_en = 1'b0;
            end
        end
        else if(avgpool_or_not)begin
            if(kernel_flag)begin
               if(kernel_pos<'d4)begin
                  fms_read_en = 1'b1;
               end
               else begin
                  fms_read_en = 1'b0;
               end
            end
            else begin
                fms_read_en = 1'b0;
            end
        end
        else if(convt_or_not)begin
            if(kernel_flag)
                fms_read_en = 1'b1;
            else
                fms_read_en = 1'b0;
        end
        else begin
            fms_read_en = 1'b0;
        end
end

always @(*)begin
        if(conv_or_not)begin
            if(ts_kernel_flag)begin
                case(padding_method)
                4'b0000:begin  //when slide the center, no padding
                    zero_dout_vld = 1'b0;
                end
                4'b1010:begin //up padding and left padding
                if(kernel_pos2=='d4||kernel_pos2=='d5||kernel_pos2=='d7||kernel_pos2=='d8)begin
                       zero_dout_vld = 1'b0; 
                    end
                    else begin
                       zero_dout_vld = 1'b1;
                    end
                end
                4'b1000:begin //only up padding
                    if(kernel_pos2=='d3||kernel_pos2=='d4||kernel_pos2=='d5||kernel_pos2=='d6||kernel_pos2=='d7||kernel_pos2=='d8)begin
                       zero_dout_vld = 1'b0;
                    end
                    else begin
                       zero_dout_vld = 1'b1;
                    end
                end
                4'b1001:begin //up padding and right padding
                    if(kernel_pos2=='d3||kernel_pos2=='d4||kernel_pos2=='d6||kernel_pos2=='d7)begin
                       zero_dout_vld = 1'b0;
                    end
                    else begin
                       zero_dout_vld = 1'b1;
                    end
                end
                4'b0010:begin //only left padding
                    if(kernel_pos2=='d1||kernel_pos2=='d2||kernel_pos2=='d4||kernel_pos2=='d5||kernel_pos2=='d7||kernel_pos2=='d8)begin
                       zero_dout_vld = 1'b0;
                    end
                    else begin
                       zero_dout_vld = 1'b1;
                    end
                end
                4'b0001:begin //only right padding
                if(kernel_pos2=='d0||kernel_pos2=='d1||kernel_pos2=='d3||kernel_pos2=='d4||kernel_pos2=='d6||kernel_pos2=='d7)begin
                       zero_dout_vld = 1'b0;
                    end
                    else begin
                       zero_dout_vld = 1'b1;
                    end 
                end
                4'b0110:begin //left padding and down padding
                    if(kernel_pos2=='d1||kernel_pos2=='d2||kernel_pos2=='d4||kernel_pos2=='d5)begin
                       zero_dout_vld = 1'b0;
                    end
                    else begin
                       zero_dout_vld = 1'b1;
                    end
                end
                4'b0100:begin //only down padding
                    if(kernel_pos2=='d0||kernel_pos2=='d1||kernel_pos2=='d2||kernel_pos2=='d3||kernel_pos2=='d4||kernel_pos2=='d5)begin
                       zero_dout_vld = 1'b0;
                    end
                    else begin
                       zero_dout_vld = 1'b1;
                    end 
                end
                4'b0101:begin //down padding and right padding
                    if(kernel_pos2=='d0||kernel_pos2=='d1||kernel_pos2=='d3||kernel_pos2=='d4)begin
                       zero_dout_vld = 1'b0;
                   end
                    else begin
                       zero_dout_vld = 1'b1;
                    end
                end
                default:begin
                    zero_dout_vld = 1'b0;
                end
                endcase
            end
            else begin
                zero_dout_vld = 1'b0;
            end
        end
        else begin
            zero_dout_vld = 1'b0;
        end
end


//different condition
always @(*)begin
    if(conv_or_not)begin
        case(padding_method)
        4'b0000:begin  //when slide the center, no padding
            row1_base_addr = (ilc_slide_position-ilc_fms_length-1'b1)<<ilc_shift_value;
            row2_base_addr = (ilc_slide_position-1'b1)<<ilc_shift_value;
            row3_base_addr = (ilc_slide_position+ilc_fms_length-1'b1)<<ilc_shift_value;

        end
        4'b1010:begin //up padding and left padding
            row2_base_addr = (ilc_slide_position)<<ilc_shift_value;
            row3_base_addr = (ilc_slide_position+ilc_fms_length)<<ilc_shift_value;
            row1_base_addr = {`MAIN_MEM_INDEX{1'b0}};

        end
        4'b1000:begin //only up padding
            row2_base_addr = (ilc_slide_position-1'b1)<<ilc_shift_value;
            row3_base_addr = (ilc_slide_position+ilc_fms_length-1'b1)<<ilc_shift_value;
            row1_base_addr = {`MAIN_MEM_INDEX{1'b0}};

        end
        4'b1001:begin //up padding and right padding
            row2_base_addr = (ilc_slide_position-1'b1)<<ilc_shift_value;
            row3_base_addr = (ilc_slide_position+ilc_fms_length-1'b1)<<ilc_shift_value;
            row1_base_addr = {`MAIN_MEM_INDEX{1'b0}};

        end
        4'b0010:begin //only left padding
            row1_base_addr = (ilc_slide_position-ilc_fms_length)<<ilc_shift_value;
            row2_base_addr = (ilc_slide_position)<<ilc_shift_value;
            row3_base_addr = (ilc_slide_position+ilc_fms_length)<<ilc_shift_value;

        end
        4'b0001:begin //only right padding
            row1_base_addr = (ilc_slide_position-ilc_fms_length-1'b1)<<ilc_shift_value;
            row2_base_addr = (ilc_slide_position-1'b1)<<ilc_shift_value;
            row3_base_addr = (ilc_slide_position+ilc_fms_length-1'b1)<<ilc_shift_value;

        end
        4'b0110:begin //left padding and down padding
            row1_base_addr = (ilc_slide_position-ilc_fms_length)<<ilc_shift_value;
            row2_base_addr = (ilc_slide_position)<<ilc_shift_value;
            row3_base_addr = {`MAIN_MEM_INDEX{1'b0}};

        end
        4'b0100:begin //only down padding
            row1_base_addr = (ilc_slide_position-ilc_fms_length-1'b1)<<ilc_shift_value;
            row2_base_addr = (ilc_slide_position-1'b1)<<ilc_shift_value;
            row3_base_addr = {`MAIN_MEM_INDEX{1'b0}};

        end
        4'b0101:begin //down padding and right padding
            row1_base_addr = (ilc_slide_position-ilc_fms_length-1'b1)<<ilc_shift_value;
            row2_base_addr = (ilc_slide_position-1'b1)<<ilc_shift_value;
            row3_base_addr = {`MAIN_MEM_INDEX{1'b0}};

        end
        default:begin
            row1_base_addr = {`MAIN_MEM_INDEX{1'b0}};
            row2_base_addr = {`MAIN_MEM_INDEX{1'b0}};
            row3_base_addr = {`MAIN_MEM_INDEX{1'b0}};
        end
        endcase
    end
    else if(avgpool_or_not)begin
            row1_base_addr = (ilc_slide_position)<<ilc_shift_value;
            row2_base_addr = (ilc_slide_position+ilc_fms_length)<<ilc_shift_value;
            row3_base_addr = {`MAIN_MEM_INDEX{1'b0}};
    end
    else begin
       row1_base_addr = {`MAIN_MEM_INDEX{1'b0}};
       row2_base_addr = {`MAIN_MEM_INDEX{1'b0}};
       row3_base_addr = {`MAIN_MEM_INDEX{1'b0}};
    end
end


endmodule
