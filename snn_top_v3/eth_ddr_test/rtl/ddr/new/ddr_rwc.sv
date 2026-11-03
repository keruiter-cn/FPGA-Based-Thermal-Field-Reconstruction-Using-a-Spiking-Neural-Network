//******************************************************************************/
// Vendor             : 
// Version            : 1.0
// Filename           : ddr_rd_wr.sv
// 
// 
//
//
//*****************************************************************************
`timescale 1ps / 1ps
module ddr_rwc_new  #(
parameter DDR_WIDTH         = 256   ,
parameter DDR_ADDR_WIDTH    = 32    ,
parameter RAM_ADDR_WIDTH    = 29
)
(
  // ********* ALL SIGNALS AT THIS INTERFACE ARE ACTIVE HIGH SIGNALS ********/
  input                             clk_ddr_in              ,    // MC UI clock. 
  output                            clk_ddr                 ,    // clock  output.  
  input                             rst                     ,    // MC UI reset signal.                                                            
  input                             init_calib_complete     ,    // MC calibration done signal coming from MC UI.                            
  input                             ddr_rdy                 ,    // cmd fifo ready signal coming from MC UI.                                                    
  input                             ddr_wdf_rdy             ,    // write data fifo ready signal coming from MC UI.                                                        
  input                             ddr_rd_data_valid       ,    // read data valid signal coming from MC UI                                
  input     [DDR_WIDTH-1 : 0]       ddr_rd_data             ,    // read data bus coming from MC UI                                                        
  output    [2 : 0]                 ddr_cmd                 ,    // command bus to the MC UI                                                          
  output    [DDR_ADDR_WIDTH-1 : 0]  ddr_addr                ,    // address bus to the MC UI                                                           
  output                            ddr_en                  ,    // command enable signal to MC UI.                                                      
  output    [(DDR_WIDTH/8)-1 : 0]   ddr_wdf_mask            ,    // write data mask signal which,is tied to 0 in this example                                                                                                   
  output    [DDR_WIDTH-1: 0]        ddr_wdf_data            ,    // write data bus to MC UI.                                                            
  output                            ddr_wdf_end             ,    // write burst end signal to MC UI                                                          
  output                            ddr_wdf_wren            ,    // write enable signal to MC UI
  
  //*********weight interface*********
  input                             clk                     ,//200M
  input                             itlc_weight_init        ,
  input                             itlc_weight_init_done   ,
  input     [DDR_WIDTH-1: 0]        eth_weight_data         ,
  input                             eth_weight_empty        ,
  output                            eth_weight_fifo_en      ,
  input                             ilc_weight_rd_req       ,
  input     [RAM_ADDR_WIDTH-1: 0]   ilc_weight_rd_len       ,
  input     [RAM_ADDR_WIDTH-1: 0]   ilc_weight_rd_addr      ,
  input     [RAM_ADDR_WIDTH-1: 0]   ilc_bram_wr_addr        ,
  output                            ilc_weight_rd_done      ,
  output                            pec_weight_wr_en        ,
  output    [DDR_WIDTH-1: 0]        pec_weight_data         ,
  output    [RAM_ADDR_WIDTH-1: 0]   pec_weight_wr_addr                 
);

parameter       IDLE                    =   4'd0    ,
                DDR_CALIB_COMPLETE      =   4'd1    ,
                ETH_WEIGHT_WR           =   4'd2    ,
                ETH_WEIGHT_WR_DATA      =   4'd3    ,
                ETH_WEIGHT_WR_DATA_RDY  =   4'd4    ,
                DDR_WEIGHT_RD           =   4'd5    ,
                DDR_WEIGHT_RD_S         =   4'd6    ,
                DDR_WEIGHT_RD_DONE0     =   4'd7    ,
                ETH_WEIGHT_WR_DATA_RDY0 =   4'd8    ;
               

reg             itlc_weight_init_r0         ;
reg             itlc_weight_init_r1         ;
reg             itlc_weight_init_done_r0    ;
reg             itlc_weight_init_done_r1    ;
reg             ilc_weight_rd_req_r0        ;
reg             ilc_weight_rd_req_r1        ;
reg             itlc_weight_init_200M       ;
reg             ilc_weight_rd_req_200M      ;

reg                             ddr_cmd_r   ;//ddr wr addr
reg                             ddr_en_r    ;
reg     [DDR_ADDR_WIDTH-1 : 0]  ddr_addr_r  ;

reg                             ddr_wdf_mask_r; //ddr wr data
reg     [DDR_WIDTH-1: 0]        ddr_wdf_data_r;
reg                             ddr_wdf_end_r ; 
reg                             ddr_wdf_wren_r;

(* MARK_DEBUG ="true" *)reg                             eth_weight_fifo_en_r;

reg     [31:0]                  wr_ddr_data_counter;
reg     [31:0]                  wr_ddr_addr_counter;

reg     [RAM_ADDR_WIDTH-1: 0]   ilc_weight_rd_len_r  ; 
reg     [RAM_ADDR_WIDTH-1: 0]   ilc_weight_rd_addr_r ;
reg     [RAM_ADDR_WIDTH-1: 0]   ilc_bram_wr_addr_r   ;
reg     [RAM_ADDR_WIDTH-1: 0]   ilc_weight_wr_addr_r ;

reg     [RAM_ADDR_WIDTH-1: 0]   read_ddr_addr_len    ; 
reg     [RAM_ADDR_WIDTH-1: 0]   read_ddr_data_len    ; 

reg                             ilc_weight_rd_done_r0;
reg                             ilc_weight_rd_done_r1;
reg                             ilc_weight_rd_done_r2;
reg                             ilc_weight_rd_done_r3;
reg                             ilc_weight_rd_done_r4;
reg                             pec_weight_wr_en_r   ;  
reg     [DDR_WIDTH-1: 0]        pec_weight_data_r    ;
reg     [RAM_ADDR_WIDTH-1: 0]   pec_weight_wr_addr_r ;
reg     [RAM_ADDR_WIDTH-1: 0]   pec_weight_wr_addr_r0;

reg     [DDR_WIDTH-1: 0]        eth_weight_data_r    ;
reg                             send_a_fifo_data     ;

reg     [3:0]   current_state           ;
(* MARK_DEBUG ="true" *) reg     [3:0]   next_state              ;

assign  eth_weight_fifo_en  =   eth_weight_fifo_en_r&(!eth_weight_empty) ;
assign  ilc_weight_rd_done  =   ilc_weight_rd_done_r4 ;
//ddr  controller  signal
assign  ddr_cmd             =   ddr_cmd_r       ;      
assign  ddr_addr            =   ddr_addr_r      ;   
assign  ddr_en              =   ddr_en_r        ;   
assign  ddr_wdf_mask        =   ddr_wdf_mask_r  ;   
assign  ddr_wdf_data        =   ddr_wdf_data_r  ;   
assign  ddr_wdf_end         =   ddr_wdf_end_r   ;   
assign  ddr_wdf_wren        =   ddr_wdf_wren_r  ;   
    
//ddr clk  ouput    
assign      clk_ddr         =   clk_ddr_in      ;     


//ram
assign  pec_weight_wr_en      =   pec_weight_wr_en_r  ;
assign  pec_weight_data       =   pec_weight_data_r   ;
assign  pec_weight_wr_addr    =   pec_weight_wr_addr_r;   

////eth to ddr,signal sync
always @(posedge clk)
begin
  if(rst)
    begin
    itlc_weight_init_200M <=  1'b0    ;       
    end
  else
    begin
        if(itlc_weight_init)
        itlc_weight_init_200M <=  1'b1    ; 
        else  if(itlc_weight_init_done)
        itlc_weight_init_200M <=  1'b0    ; 
        
    end
end

always @(posedge clk_ddr_in)
begin
  if(rst)
    begin
    itlc_weight_init_r0 <=  1'b0    ;    
    itlc_weight_init_r1 <=  1'b0    ;    
    end
  else
    begin
    itlc_weight_init_r0 <=  itlc_weight_init_200M    ;    
    itlc_weight_init_r1 <=  itlc_weight_init_r0 ;      
    end
end


////////////////rd weight///////////
always @(posedge clk)
begin
  if(rst)
    begin
    ilc_weight_rd_req_200M <=  1'b0    ;     
    end
  else
    begin
        if(ilc_weight_rd_req)
            begin
            ilc_weight_rd_req_200M <=  1'b1    ; 
            end
        else if(ilc_weight_rd_done_r2)
            begin
            ilc_weight_rd_req_200M <=  1'b0    ; 
            end
    end
end

always @(posedge clk_ddr_in)
begin
  if(rst)
    begin
    ilc_weight_rd_req_r0 <=  1'b0    ;    
    ilc_weight_rd_req_r1 <=  1'b0    ;    
    end
  else
    begin
    ilc_weight_rd_req_r0 <=  ilc_weight_rd_req_200M      ;    
    ilc_weight_rd_req_r1 <=  ilc_weight_rd_req_r0   ;        
    end
end

///////fsm/////////////////////////////////////////////////
always @(posedge clk_ddr_in)
begin
  if(rst)
    begin
    current_state   <=  IDLE    ;  
    end
  else
    begin
    current_state   <=  next_state  ;
    end
end

always @(*)
begin
    next_state    =  IDLE    ;  
    case(current_state)
    IDLE:
        begin
        if(init_calib_complete)
            next_state  =   DDR_CALIB_COMPLETE  ;  
        else
            next_state  =   IDLE    ;  
        end
    DDR_CALIB_COMPLETE:
        begin
        if(itlc_weight_init_r1)//wr weight
            begin
            next_state  =   ETH_WEIGHT_WR   ;   
            end 
        else if(!itlc_weight_init_r1)//rd weight
            begin
            next_state  =   DDR_WEIGHT_RD  ; 
            end            
        else
            begin
            next_state  =   DDR_CALIB_COMPLETE  ; 
            end
        end        
    ETH_WEIGHT_WR:
        begin
        if(!eth_weight_empty)
            begin
            next_state  =   ETH_WEIGHT_WR_DATA   ;   
            end
        else if((eth_weight_empty)&(!itlc_weight_init_r1)&(wr_ddr_data_counter==wr_ddr_addr_counter))
            begin
            next_state  =   DDR_CALIB_COMPLETE   ;
            end
        else
            begin
            next_state  =   ETH_WEIGHT_WR   ;
            end
        end
    ETH_WEIGHT_WR_DATA:
        begin
        if(!ddr_wdf_rdy)
            begin
            next_state  =   ETH_WEIGHT_WR_DATA   ;   
            end
        /*else if(eth_weight_empty)
            begin
            next_state  =   ETH_WEIGHT_WR   ;
            end*/ 
        else
            begin
            next_state  =   ETH_WEIGHT_WR_DATA_RDY   ;
            end
        end 
    ETH_WEIGHT_WR_DATA_RDY:
        begin
        /* if(!ddr_wdf_rdy)
            begin
            next_state  =   ETH_WEIGHT_WR_DATA_RDY   ;   
            end
        else  if(send_a_fifo_data)
            begin
            next_state  =   ETH_WEIGHT_WR_DATA_RDY0   ;
            end 
        else 
            begin
            next_state  =   ETH_WEIGHT_WR   ;
            end */ 
        next_state  =   ETH_WEIGHT_WR   ;            
        end
    ETH_WEIGHT_WR_DATA_RDY0:
        begin
         if(!ddr_wdf_rdy)
            begin
            next_state  =   ETH_WEIGHT_WR_DATA_RDY0   ;   
            end
        else
            begin
            next_state  =   ETH_WEIGHT_WR   ;
            end       
        end        
    DDR_WEIGHT_RD:  //read weight 
        begin
        if(ilc_weight_rd_req_r1)
            begin
            next_state  =   DDR_WEIGHT_RD_S   ;   
            end
        else
            begin
            next_state  =   DDR_CALIB_COMPLETE   ;
            end          
        end
    DDR_WEIGHT_RD_S:
        begin
        if(read_ddr_data_len==ilc_weight_rd_len_r)
            next_state  =   DDR_WEIGHT_RD_DONE0   ;
        else
            next_state  =   DDR_WEIGHT_RD_S   ;           
        end
    DDR_WEIGHT_RD_DONE0:
        if(!ilc_weight_rd_req_r1)
        next_state  =   DDR_CALIB_COMPLETE   ;
        else
        next_state  =   DDR_WEIGHT_RD_DONE0  ;
    /*DDR_WEIGHT_RD_DONE1:
        next_state  =   DDR_CALIB_COMPLETE   ; */       
           
    default:next_state    =  IDLE    ;  
    endcase
end


always @(posedge clk_ddr_in)//rd eth fifo data
begin
  if(rst)
    begin
    eth_weight_fifo_en_r    <=  1'b0    ;  
    end
  else
    begin
    if((next_state==ETH_WEIGHT_WR)&(!eth_weight_empty))
        begin
        eth_weight_fifo_en_r    <=  1'b1    ;
        end
    /*else if((next_state==ETH_WEIGHT_WR_DATA)&(!eth_weight_empty)&(ddr_wdf_rdy))
        begin
        eth_weight_fifo_en_r    <=  1'b1    ;
        end*/
    else
        begin
        eth_weight_fifo_en_r    <=  1'b0    ;
        end
    end
end


always @(posedge clk_ddr_in)//add send a fifo data
begin
  if(rst)
    begin
    send_a_fifo_data    <=  1'b0    ; 
    eth_weight_data_r   <=   'b0    ;  
    end
  else
    begin
    if((next_state==ETH_WEIGHT_WR_DATA_RDY)&(!ddr_wdf_rdy)&eth_weight_fifo_en_r)
        begin
        send_a_fifo_data    <=  1'b1   ; 
        eth_weight_data_r   <=  eth_weight_data    ;         
        end
    else if(next_state==ETH_WEIGHT_WR_DATA_RDY0)
        begin
        send_a_fifo_data    <=  1'b0   ;  
        end
    end
end


always @(posedge clk_ddr_in)//wr data to ddr
begin
  if(rst)
    begin
    ddr_wdf_mask_r    <=  1'b0    ; 
    ddr_wdf_data_r    <=   'b0    ;
    ddr_wdf_end_r     <=  1'b0    ;
    ddr_wdf_wren_r    <=  1'b0    ;
    end
  else
    begin
    if((next_state==ETH_WEIGHT_WR)&(!eth_weight_empty))
        begin
        ddr_wdf_data_r    <=  eth_weight_data   ;
        ddr_wdf_end_r     <=  1'b1              ;
        ddr_wdf_wren_r    <=  1'b1              ;
        end        
    //else if((next_state==ETH_WEIGHT_WR_DATA)&(!eth_weight_empty)&ddr_wdf_rdy)
   /* else if((next_state==ETH_WEIGHT_WR_DATA)&(eth_weight_fifo_en_r))
        begin
        ddr_wdf_data_r    <=  eth_weight_data   ;
        ddr_wdf_end_r     <=  1'b1              ;
        ddr_wdf_wren_r    <=  1'b1              ;
        end 
    else if((next_state==ETH_WEIGHT_WR_DATA_RDY0)&(send_a_fifo_data))
        begin
        ddr_wdf_data_r    <=  eth_weight_data_r   ;
        ddr_wdf_end_r     <=  1'b1              ;
        ddr_wdf_wren_r    <=  1'b1              ;
        end */
    /*else if((next_state==ETH_WEIGHT_WR_DATA_RDY0)&(!ddr_wdf_rdy))
        begin
        ddr_wdf_data_r    <=  ddr_wdf_data_r    ;
        ddr_wdf_end_r     <=  1'b1              ;
        ddr_wdf_wren_r    <=  1'b1              ;
        end */     
    /*else if((next_state==ETH_WEIGHT_WR_DATA_RDY)&(!ddr_wdf_rdy))
        begin
        ddr_wdf_data_r    <=  ddr_wdf_data_r    ;
        ddr_wdf_end_r     <=  1'b1              ;
        ddr_wdf_wren_r    <=  1'b1              ;
        end */
    /*else if((next_state==ETH_WEIGHT_WR_DATA_RDY)&(ddr_wdf_rdy))
        begin
        ddr_wdf_data_r    <=  ddr_wdf_data_r    ;
        ddr_wdf_end_r     <=  1'b0              ;
        ddr_wdf_wren_r    <=  1'b0              ;
        end*/          
    else 
        begin
        ddr_wdf_data_r    <=   'b0    ;
        ddr_wdf_end_r     <=  1'b0    ;
        ddr_wdf_wren_r    <=  1'b0    ;
        end
    end
end

always @(posedge clk_ddr_in)//wr data counter
begin
  if(rst)
    begin
    wr_ddr_data_counter  <=  'b0  ;
    end
  else
    begin
    if(next_state==DDR_CALIB_COMPLETE)
        wr_ddr_data_counter  <=  'b0  ;
    else if(ddr_wdf_wren_r&ddr_wdf_rdy)
        wr_ddr_data_counter  <=  wr_ddr_data_counter+1  ;
    end
end

always @(posedge clk_ddr_in)//wr addr counter
begin
  if(rst)
    begin
    wr_ddr_addr_counter  <=  'b0  ;
    end
  else
    begin
    if(next_state==DDR_CALIB_COMPLETE)
        wr_ddr_addr_counter  <=  'b0  ;
    else if(ddr_en&ddr_rdy&(ddr_cmd==3'b0))
        wr_ddr_addr_counter  <=  wr_ddr_addr_counter+1  ;
    end
end


always @(posedge clk_ddr_in)//wr ddr addr
begin
  if(rst)
    begin
    ddr_cmd_r  <=  'b0  ;
    ddr_addr_r <=  'b0  ;
    ddr_en_r   <=  'b0  ;
    ilc_weight_wr_addr_r  <=  'b0  ;
    end
  else
    begin
    if(next_state==DDR_CALIB_COMPLETE)
        begin
        ddr_cmd_r  <=  'b0  ;
        ddr_addr_r <=  'b0  ;
        ddr_en_r   <=  'b0  ;
        ilc_weight_wr_addr_r  <=  'b0  ;        
        end
    else if((wr_ddr_addr_counter<wr_ddr_data_counter)&(ddr_en_r==0))
        begin
        ddr_cmd_r  <=  'b0          ;
        ddr_addr_r <=  ilc_weight_wr_addr_r   ;
        ddr_en_r   <=  'b1          ;   
        ilc_weight_wr_addr_r  <=  ilc_weight_wr_addr_r+8  ;        
        end
    else if(((wr_ddr_addr_counter+1)<wr_ddr_data_counter)&(ddr_en_r==1)&(ddr_rdy))
        begin
        ddr_cmd_r  <=  'b0  ;
        ddr_addr_r <=  ilc_weight_wr_addr_r  ;
        ddr_en_r   <=  'b1  ;   
        ilc_weight_wr_addr_r  <=  ilc_weight_wr_addr_r+8  ;        
        end
    /*else if(((wr_ddr_addr_counter+1)=wr_ddr_data_counter)&(ddr_en_r==1)&(ddr_rdy))
        begin
        ddr_cmd_r  <=  'b0  ;
        ddr_addr_r <=  'b0  ;
        ddr_en_r   <=  'b0  ;         
        end*/         
    else if(((wr_ddr_addr_counter+1)<=wr_ddr_data_counter)&(ddr_en_r==1)&(!ddr_rdy))
        begin
        ddr_cmd_r  <=  'b0  ;
        ddr_addr_r <=  ddr_addr_r  ;
        ddr_en_r   <=  'b1  ;         
        end 
    ///////rd weight 
    else if((next_state==DDR_WEIGHT_RD_S)&(ddr_en_r==0)&(ilc_weight_rd_len_r>0)&(ilc_weight_rd_len_r!=read_ddr_addr_len))
        begin
        ddr_cmd_r  <=  'b1          ;
        ddr_addr_r <=  ilc_weight_rd_addr_r   ;
        ddr_en_r   <=  'b1          ;         
        end 
    else if((next_state==DDR_WEIGHT_RD_S)&(ddr_en_r==1)&(ilc_weight_rd_len_r>(read_ddr_addr_len+1))&ddr_rdy)
        begin
        ddr_cmd_r  <=  'b1          ;
        ddr_addr_r <=  ddr_addr_r+8   ;
        ddr_en_r   <=  'b1          ;         
        end  
    else if((next_state==DDR_WEIGHT_RD_S)&(ddr_en_r==1)&(ilc_weight_rd_len_r>=(read_ddr_addr_len+1))&(!ddr_rdy))
        begin
        ddr_cmd_r  <=  'b1          ;
        ddr_addr_r <=  ddr_addr_r   ;
        ddr_en_r   <=  'b1          ;         
        end          
    else
        begin
        ddr_en_r   <=  'b0  ;
        end
    end
end

/////////////read weight///////////
always @(posedge clk)//
begin
  if(rst)
    begin
    ilc_weight_rd_len_r     <=  'b0 ;
    ilc_weight_rd_addr_r    <=  'b0 ;
    ilc_bram_wr_addr_r      <=  'b0 ;  
    end
  else
    begin
    if(ilc_weight_rd_req)
        begin
        ilc_weight_rd_len_r     <=  ilc_weight_rd_len  ;
        ilc_weight_rd_addr_r    <=  ilc_weight_rd_addr ;
        ilc_bram_wr_addr_r      <=  ilc_bram_wr_addr   ;        
        end
    end
end

always @(posedge clk_ddr_in)//
begin
  if(rst)
    begin
    read_ddr_addr_len     <=  'b0 ;
    end
  else
    begin
    if(next_state==DDR_CALIB_COMPLETE)
        begin
        read_ddr_addr_len     <=  'b0 ;
        end
    else if((ddr_cmd_r==3'b1)&ddr_en_r&ddr_rdy)
        begin
        read_ddr_addr_len     <=  read_ddr_addr_len+1 ;       
        end
    end
end

always @(posedge clk_ddr_in)//write ram
begin
  if(rst)
    begin
    pec_weight_wr_en_r  <=  'b0 ;
    pec_weight_data_r   <=  'b0 ;
    pec_weight_wr_addr_r<=  'b0 ;
    pec_weight_wr_addr_r0<=  'b0 ;
    end
  else
    begin
    if(next_state==DDR_WEIGHT_RD)
        begin
        pec_weight_wr_en_r  <=  'b0 ;
        pec_weight_data_r   <=  'b0 ;
        pec_weight_wr_addr_r<=  'b0 ;
        pec_weight_wr_addr_r0<=  ilc_bram_wr_addr_r ;
        end
    else if(ddr_rd_data_valid)
        begin
        pec_weight_wr_en_r   <=  'b1         ;
        pec_weight_data_r    <=  ddr_rd_data ;
        pec_weight_wr_addr_r <=  pec_weight_wr_addr_r0;
        pec_weight_wr_addr_r0<=pec_weight_wr_addr_r0+1;        
        end
    else
        begin
        pec_weight_wr_en_r  <=  'b0         ;
        end
    end
end

always @(posedge clk_ddr_in)//write ram
begin
  if(rst)
    begin
    read_ddr_data_len  <=  'b0 ;
    end
  else
    begin
    if(next_state==DDR_CALIB_COMPLETE)
        begin
        read_ddr_data_len  <=  'b0 ;
        end
    else if(ddr_rd_data_valid)
        begin
        read_ddr_data_len<=  read_ddr_data_len+1 ;      
        end
    end
end


always @(posedge clk_ddr_in)//make done
begin
  if(rst)
    begin
    ilc_weight_rd_done_r0  <=  'b0 ;
    end
  else
    begin
    if(next_state==DDR_CALIB_COMPLETE)
        begin
        ilc_weight_rd_done_r0  <=  'b0 ;
        end
    else if(next_state==DDR_WEIGHT_RD_DONE0)
        begin
        ilc_weight_rd_done_r0  <=  'b1;      
        end
    else
        begin
        ilc_weight_rd_done_r0  <=  'b0 ;
        end        
    end
end

always @(posedge clk)
begin
  if(rst)
    begin
    ilc_weight_rd_done_r1  <=  'b0 ;    
    ilc_weight_rd_done_r2  <=  'b0 ;    
    ilc_weight_rd_done_r3  <=  'b0 ; 
    ilc_weight_rd_done_r4  <=  'b0 ;     
    end
  else
    begin
    ilc_weight_rd_done_r1  <=  ilc_weight_rd_done_r0;    
    ilc_weight_rd_done_r2  <=  ilc_weight_rd_done_r1;    
    ilc_weight_rd_done_r3  <=  ilc_weight_rd_done_r2;  
    
    if(ilc_weight_rd_done_r2&(!ilc_weight_rd_done_r3)) 
        ilc_weight_rd_done_r4  <=  'b1 ;
    else
        ilc_weight_rd_done_r4  <=  'b0 ; 
    end
end
endmodule



