`timescale 1ns / 1ps
`define SMALL_SYS
// Copyright (c) 2021 Neurocoms Inc.
  
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
  
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
  
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

//`define SIMUL
//////////////////////////////////////////////////////////////////////////////////
// Company: Neurocoms Inc.
// Engineer: Byungik Ahn (jerryahn@neurocoms.com)
// 
// Create Date: 2020/10/03 14:16:52
// Design Name: 
// Module Name: top
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: Top Unit for the AI circuit.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//      For explanations of the source code, please subscribe to YouTube @fpgalover. 
//      For efficient custom AI hardware design, please contact the author.
//	Don't waste your time and ask us for help.
//////////////////////////////////////////////////////////////////////////////////

`ifdef SIMUL
module top # (
`else
module neuron_machine # (
`endif
        parameter DATA_WIDTH = 16,
        parameter N_MX = 32,
        parameter N_ADDR = 15,
        parameter N_CTRAIN = 30,
        parameter W_CTRAIN = 40,
`ifdef SIMUL
        parameter TEMPMAP_SPACE = 14'h1ec0,
        parameter STARTING_LAYER = 10'd0,
`else
        parameter TEMPMAP_SPACE = 14'h1ec0,
        parameter STARTING_LAYER = 10'd0,
`endif
`ifdef SMALL_SYS 
        parameter N_MUL = 128,
        parameter N_RECEPTOR = 4,
        parameter N_SUOUT = 8
`else
        parameter N_MUL = 256,
        parameter N_RECEPTOR = 8,
        parameter N_SUOUT = 16
`endif
    ) (
`ifdef SIMUL
        input i_nm_runf,
`else
        output o_runf,
`endif
        output o_nm_done,
        output [5:0] o_mode,
        // NU Output check
        output o_out_valid,
        output [15:0] o_out_seq,
        output [N_RECEPTOR*9-1:0][DATA_WIDTH-1:0] o_out_data,
        output [7:0] o_layerid,
        output o_out_lastchan,
        // SU output check
        output o_su_valid,
        output [7:0] o_su_layerid,
        output [15:0][15:0] o_su_data,
        
        // to DDR AXI        
        output o_req_en,
        output o_req_rw,
        output o_req_flush,
        output o_req_newaddr,
        output [25:0] o_req_addr,
        output [127:0] o_req_din,
        input i_req_avail,
        input i_req_error,
        //
        input i_resp_en,
        input [25:0] i_resp_addr,
        input [127:0] i_resp_dout,
        output o_resp_wait,
        input i_resp_rdone,
        //
`ifdef SIMUL
        output o_det_en,
        output [17:0] o_det_data,
        //
`else
        input [31:0] cmd_control,
        input [31:0] cmd_addr,
        output reg [31:0] cmd_din,
        input [31:0] cmd_dout,
`endif
        output [31:0] cmd_monitor,
        input reset_n,
        input clk
    );

	  // function called clogb2 that returns an integer which has the 
	  // value of the ceiling of the log base 2.                      
	  function integer clogb2 (input integer bit_depth);              
	  begin                                                           
	    for(clogb2=0; bit_depth>0; clogb2=clogb2+1)                   
	      bit_depth = bit_depth >> 1;                                 
	    end                                                           
	  endfunction                                                     


    // main states
    
    /* debug1 */ enum bit [3:0] {S_SOT_STOPPED, S_SOT_LOAD, S_SOT_NEXT, S_SOT_HOLD, S_SOT_FLUSH, S_SOT_FLUSH2,
        S_SOT_DISPATCH, S_SOT_DDR_MONITOR, S_SOT_CONV_MONITOR, S_SOT_DET_MONITOR, S_SOT_BBOX_MONITOR} 
        sot_state = S_SOT_STOPPED, prev_sot_state = S_SOT_STOPPED, stall_state = S_SOT_STOPPED;
    enum bit [1:0] {S_SM_IDLE, S_SM_SHIFT} sm_state = S_SM_IDLE;

    // sot related
    
    logic reg_runf, reg_runf_d1;
    logic [9:0] sot_i = 0;
    logic [511:0] sot_record, reg_sot = 0;
    logic [127:0] sot_record128;
    logic [1:0] hold_delay; // for sot redirection for GOTO
    logic [7:0] last_delay; // for sot redirection for GOTO
    // sot fields    
    logic [5:0] sot_r_mode; // reading mode (of the block)
    logic [5:0] sot_w_mode; // writing mode
    logic sot_tmost;        // topmost block indicator
    logic sot_wsave;        // wait before shuttle data is saved
    logic [9:0] sot_sxm1;   // W - 1 of the input map
    logic [9:0] sot_osxm1;  // H - 1 of the input map
    logic [12:0] sot_ncm1;  // number of channel cycles for each feature map
    logic [12:0] sot_nfm1;  // number of feature map cycles
    logic [15:0] sot_nmapm1;// c x f - 1
    logic [3:0] sot_staddr; // state memory address
    logic [12:0] sot_shaddr;// starting memoriy address of shuttle memory
    logic [17:0] sot_ickpim, sot_ickpim_m1; // the size of input (partial) image
    logic [17:0] sot_ockpim, sot_ockpim_m1, sig_ockpim_m1; // the size of output (partial) image
    logic [17:0] sot_istep; // address difference between adjacent images (reading)
    logic [17:0] sot_ostep; // address difference between adjacent images (writinging) 
    logic [17:0] sot_ickfull;   // full image size in clocks
    logic [9:0] sot_ckflush;    // flush size for 3x3 convolution
    logic [17:0] sot_raddr; // MX base address when reading
    logic [17:0] sot_waddr; // MX base address when writing
    logic [9:0] sot_goto;   // conditional goto index (0: no goto)
    logic [29:0] sot_paraaddr;  // starting parameter address (DDR)
    logic [19:0] sot_paralen;  // parameter length (DDR)
    logic [7:0] sot_layer;  // layer id (starting from 1)
    logic [1:0] sot_relu;

    // DDR IF related
    
    logic dispatch_ddr;
    logic [13:0] ddr_addr; // starting read DDR address
    logic [19:0] ddr_len_m1;  // size of read (in 128-bit unit)
    logic ddr_done;       // finish indicator
    // --> NU flow
    logic ddr_r_rd_en;      // read from NU
    logic ddr_r_valid;      // when valid
    logic [127:0] ddr_r_dout;
    // <-- NU flow
    logic ddr_w_wr_en;      // write from NU
    logic ddr_w_full;       // when queue is not full
    logic [127:0] ddr_w_din;
    // <-- NMS
    logic bbox_w_wr_en;      // write from NMS to DDR
    logic bbox_w_full;       // when queue is not full
    logic [127:0] bbox_w_din;

    // Network unit related
    
    //== command from control unit via NU
    logic i_rc_readstart = 1'b0; // command for starting to read
    logic i_rc_writestart = 1'b0; // command for starting to write
    // input from SU interface
    logic i_su_we;
    logic [17:0] i_su_addr;
    logic [9:0] i_su_row;
    logic [9:0] i_su_col;
    //== the output of the receptor
    logic o_rc_out_valid, reg_nu_out_valid;  // output validity
    logic [15:0] o_rc_out_seq, reg_nu_out_seq, o_rc_out_seq_partial; // output data sequence
    logic [9:0] o_row_i;//, reg_row_i;
    logic [9:0] o_col_i;//, reg_col_i;
    logic o_first_chan, o_last_chan, o_firstf, o_lastf, o_pop_para;
    logic reg_first_chan, reg_last_chan, reg_firstf, reg_lastf;
    logic [N_RECEPTOR*9-1:0][DATA_WIDTH-1:0] o_rc_data;   // output data
    logic [N_MUL-1:0][DATA_WIDTH-1:0] reg_nu_data;
    //
    logic o_done, o_det_done, is_bottommost;
    logic o_all_done;  // indication that all parts of an image are processed
    logic just_started, interlg_reset, reg_interlg_reset;
    
    logic [N_CTRAIN-1:0] entrain = 0;
    logic [N_CTRAIN-1:0][15:0] seqtrain = 0;
    logic [N_CTRAIN-1:0][W_CTRAIN-1:0] auxtrain = 0;

    logic [9:0] reg_su_row;
    logic [9:0] reg_su_col;
    
    logic sig_paraqfull, sig_paraqempty, sig_biasqfull;
    logic sig_para_en;
    logic [127:0] sig_para128;
    logic conv_start;
    logic [N_MUL-1:0][23:0] sig_products;
    logic [N_MUL/16-1:0][31:0] sig_netsum;
    logic [15:0][15:0] sig_suout, reg_suout, sm_suout;
    logic [clogb2(N_SUOUT-1)-1:0] smax_counter;
    
    logic sig_bias_en;
    logic [N_MUL*2-1:0] sig_bias;
    logic reg_circuit_idle, ddrif_idle;
    logic ddr_donef, comp_donef;
    
    logic header_mode, bbox_mode, r_mode, w_mode, conv_mode, res_mode;
    logic sot_load_start;
    logic [15:0] i_blocks = 16'd0;
    logic [25:0] runtime_count, reg_runtime_count, multime_count, convtime_count, reg_multime_count, reg_convtime_count;
    logic null_goto, non_conv_read;

    logic det_q_full = 1'b0, det_en_d;
    logic [17:0] det_chksum = 18'd0;
`ifndef SIMUL
    logic o_det_en;
    logic [17:0] o_det_data;
`endif
    logic det_reset = 1'b0, nms_reset = 1'b0;
    logic det_o_en, det_bbox_done, sig_det_bbox_done;
    logic [95:0] det_bbox;
    logic [10:0] reg_n_class_m1;
    
    logic sot_we;
    logic [10:0] sot_addr;
    logic [127:0] sot_din;
    logic [11:0] sot_wseq;
    logic sys_header_en, sotw_state = 1'b0;
    logic [127:0] sys_header128;
    logic [15:0] format_ver, sys_n_class_m1;
    logic [10:0] det_th = 11'd512, nms_th = 11'd512;

    logic [97:0] job_temp;
    logic [8:0] job_id = 0, last_job = 0;
    logic [97:0] next_input;
    logic [25:0] sig_model_addr, sig_output_addr, last_output_addr;
    logic [13:0] sig_input_addr;
    /* debug1 */ logic reg_en_nm;
    logic reg_softmax_clear = 1'b0;
    logic [31:0] reg_monitor;
    
    logic smax_in_en = 1'b0, smax_out_en;
    logic [15:0] smax_in_half;
    logic [10:0] smax_top1_class, smax_top1_score;
    /* debug1 */ logic fresh_input = 0;
    /* debug1 */ logic was_detection;
    logic [31:0] chksum_din, chksum_dout, sig_err_code, sig_err_code2;
    
    logic multiscale = 1'b0, multiscale_last = 1'b0, multiscale_reset = 1'b0;
    logic [31:0] scale_offset, stall_count = 32'd0;
    
    logic stall_detected = 0;
    
    // debugging
    logic [31:0] ddr_dbg_start;
    logic [9:0] chksum_waddr = 10'h0, chksum_raddr = 10'h0;
    
`ifdef SIMUL
    assign sig_model_addr = 26'h1800000;
    assign sig_input_addr = 14'h1fc0;
    assign sig_output_addr = 26'h1fbf800;// - 'd2048;
`endif
    assign o_runf = reg_runf;

    // stage operation table
    // to be replaced with a memory unit
    
//    sot4test sot_uut (
//    mobsot sot_uut (
//        .index(sot_i),
//        .record(sot_record[399:0]),
//        .clk(clk)
//    );
    sot_mem sot (
      .clka(clk),    // input wire clka
      .wea(sot_we),      // input wire [0 : 0] wea
      .addra(sot_addr),  // input wire [10 : 0] addra
      .dina(sot_din),    // input wire [127 : 0] dina
      .clkb(clk),    // input wire clkb
//      .addrb(),  // input wire [8 : 0] addrb
//      .doutb()  // output wire [511 : 0] doutb
      .addrb(sot_i[8:0]),  // input wire [8 : 0] addrb
      .doutb(sot_record[399:0])  // output wire [511 : 0] doutb
    );
    assign sot_record128 = sot_record;
    assign sot_record[511:400] = 112'd0;
    
    // header and SOT contents loading
    
    always @ (posedge clk) begin
`ifdef SIMUL
        if (sys_header_en) begin
            if (~sotw_state) begin
                if (sot_wseq[2:0]==3'h0) begin
                    format_ver <= sys_header128[15:0];
                    sys_n_class_m1 <= sys_header128[31:16];
                end
`else
        if (sot_state==S_SOT_STOPPED && fresh_input) begin
            sot_wseq <= 12'd0;
            sotw_state <= 1'b0;
        end else if (sys_header_en) begin
            if (~sotw_state) begin
                case (sot_wseq[2:0])
                3'h0: begin
                        format_ver <= sys_header128[15:0];
                        sys_n_class_m1 <= sys_header128[31:16];
                    end
                3'h1: begin
                    end
                endcase
`endif

                if (sot_wseq[2:0]==3'b111) begin
                    sot_wseq <= 12'd0;
                    sotw_state <= 1'b1;
                end else
                    sot_wseq[2:0] <= sot_wseq[2:0] + 1'b1;
            end else begin
                sot_wseq <= sot_wseq + 1'b1;
                sot_addr <= sot_wseq;
                sot_din <= sys_header128;
            end
        end
        sot_we <= (sys_header_en && sotw_state);
    end
    
    // DDR memory interface

    ddr_if ddr_if_uut (
        // command distribution
        .i_dispatch(dispatch_ddr),
        .i_modes({res_mode, header_mode, bbox_mode, r_mode, w_mode, conv_mode}),
        
        // sot interface
        .o_header_en(sys_header_en),
        .o_header128(sys_header128),
        .i_model_baseaddr(sig_model_addr),
        // --> NU flow
        .i_r_rd_en(ddr_r_rd_en),
        .o_r_valid(ddr_r_valid),
        .o_r_dout(ddr_r_dout),
        // <-- NU flow
        .i_w_wr_en(ddr_w_wr_en),
        .o_w_full(ddr_w_full),
        .i_w_din(ddr_w_din),
        // --> SNU/SU (parameter)
        .i_para_full(sig_paraqfull || sig_biasqfull),
        .o_para_en(sig_para_en),
        .o_para128(sig_para128),
        // <-- bbox/NMS
        .i_out_wr_en(bbox_w_wr_en),
        .o_out_full(bbox_w_full),
        .i_out_din(bbox_w_din),
        .i_out_addr(sig_output_addr),
        //
        .o_req_en(o_req_en),
        .o_req_rw(o_req_rw),
        .o_req_flush(o_req_flush),
        .o_req_addr(o_req_addr),
        .o_req_din(o_req_din),
        .o_req_newaddr(o_req_newaddr),
        .i_req_avail(i_req_avail),
        .i_req_error(i_req_error),
        //
        .i_resp_en(i_resp_en),
        .i_resp_addr(i_resp_addr),
        .i_resp_dout(i_resp_dout),
        .o_resp_wait(o_resp_wait),
        .i_resp_rdone(i_resp_rdone),

        // supplimentary information
        .i_ddr_addr(ddr_addr),
        .i_ddr_len_m1(ddr_len_m1),
        .i_ddr_step(sot_ickfull),
        .i_topmost(sot_tmost),
        .i_ncm1(sot_ncm1),
        // supplimentary information for parameter
        .i_para_baseaddr(sot_paraaddr),

        // for synchronization
        .o_ddr_done(ddr_done),
        .o_if_idle(ddrif_idle),
        .i_interlg_reset(reg_interlg_reset),
        .i_runtime(runtime_count),
        .i_job_id(job_id),
        .o_chksum(chksum_din),
        .o_err_code(sig_err_code),
        .i_reset_chksum(i_rc_writestart),
        .clk(clk)
    );
    
    // network unit

    networkunit uut_nu (
        //== command from control unit via NU
        .i_rc_readstart(i_rc_readstart), // command for starting to read
        .i_rc_writestart(i_rc_writestart), // command for starting to write
        .i_i_rc_mode(sot_r_mode), // indicates the type of read
        .i_o_rc_mode(sot_w_mode), // indicates the type of read
        .i_rc_sx_m1(sot_sxm1), // W - 1
        .i_rc_sy_m1(sot_sxm1), // H - 1 (full map)
        .i_rc_o_sxm1(sot_osxm1),    // W - 1 for s1, [(W+1)/2] - 1 for s2
        .i_rc_o_sym1(sot_osxm1),    // H - 1 for s1, [(H+1)/2] - 1 for s2
        .i_rc_imsize(sot_ickfull),
        .i_ckflush(sot_ckflush),
        .i_n_c_m1(sot_ncm1),  // number of (repeating) channels
        .i_n_f_m1(sot_nfm1),  // number of (repeating) feature maps
        .i_n_map_m1(sot_nmapm1),    // number of maps = n_c * n_f - 1
        .i_ickpim_m1(sot_ickpim_m1),    // partial image size
        .i_ockpim_m1(sot_ockpim_m1),    // partial image size
        .o_ockpim_m1(sig_ockpim_m1),
        .i_istep(sot_istep),    // input address increment
        .i_ostep(sot_ostep),    // output address increment
        .i_rstate_addr(sot_staddr),  // state index
        .i_shuttle_addr(sot_shaddr),  // shuttle memory base address
        .i_topmost(sot_tmost), // flag indicating the first fragmentation
        .i_wait_save(sot_wsave), // flag indicating the first fragmentation
        .i_i_baseaddr(sot_raddr),
        .i_o_baseaddr(sot_waddr),

        // SU input
        .i_su_we(auxtrain[20][21:20]==2'b10 ? auxtrain[26][17] & auxtrain[26][7] : auxtrain[20][17]),
        .i_su_addr(seqtrain[20]),
        .i_su_din(reg_suout), // t28 (GAP) or t22
        .i_su_row_odd(auxtrain[20][6]),
        .i_su_col(auxtrain[20][31:22]),
        .i_su_lastchan(auxtrain[20][17]),
        .i_su_lastf(auxtrain[20][21:20]==2'b10 ? auxtrain[26][7] : auxtrain[20][7]),
        .i_o_rc_mode_su(auxtrain[20][37:32]), // indicates the type of read
        
        // DDR interface
        .ddr_r_rd_en(ddr_r_rd_en), // new data is accepted
        .ddr_r_valid(ddr_r_valid),  // new data is available
        .ddr_r_din(ddr_r_dout),   // the new data
        .ddr_w_wr_en(ddr_w_wr_en), // data is stored for uploading
        .ddr_w_full(ddr_w_full),  // queue is full
        .ddr_w_dout(ddr_w_din),   // the data
        //== the output of the receptor
        .o_rc_out_valid(o_rc_out_valid),  // output validity
        .o_rc_out_seq(o_rc_out_seq), // output data sequence
        .o_rc_out_seq_partial(o_rc_out_seq_partial),
        .o_row_i(o_row_i),
        .o_col_i(o_col_i),
        .o_first_chan(o_first_chan),
        .o_last_chan(o_last_chan),
        .o_o_firstf(o_firstf),
        .o_o_lastf(o_lastf),
        .o_rc_data(o_rc_data),   // output data
        .o_pop_para(o_pop_para),
        .o_done(o_done),
        .o_all_done(o_all_done),
        .o_bottommost(is_bottommost),
        // detection
        .o_det_done(o_det_done),
        .o_det_en(o_det_en),
        .o_det_data(o_det_data),
        .i_det_q_full(det_q_full),
        // common
        .interlg_reset(reg_interlg_reset),
        .i_paraqempty(sig_paraqempty),
        .reset_n(reset_n),
        .clk(clk)
    );
    
    synapse_unit SNU (
        // NU interface
        .i_nu_data(reg_nu_data),
        .o_products(sig_products),
        //
        .i_mode(sot_r_mode),
        .i_para_en(sig_para_en),
        .i_para128(sig_para128),
        .o_paraqfull(sig_paraqfull),
        .i_pop_para(o_pop_para),
        .i_next(o_firstf),  // one clock ahead of data
        .o_paraqempty(sig_paraqempty),
        .o_bias_en(sig_bias_en),
        .o_bias(sig_bias),
        //
        .i_reset(conv_start),
        .clk(clk)
    );

    dendrite_unit DU (
        .i_products(sig_products),          // t5
        .o_netsum(sig_netsum),              // t13
        //
        .i_mode(auxtrain[3][5:0]),          // t5
        // for dutip
        .i_nsum_raddr(seqtrain[5]),         // t7
        .i_firstchan(auxtrain[7][16]),      // t9
        .i_nsum_en(entrain[10]),             // t12
        .i_lastchan(auxtrain[10][17]),       // t12
        .i_nsum_waddr(seqtrain[10]),         // t12
        .clk(clk)
    );

`ifdef SMALL_SYS 
    assign sig_suout[15:8] = 0;
`endif
    
    soma_unit SU (
        .i_netsum(sig_netsum),              // t13
        .o_suout(sig_suout[N_SUOUT-1:0]),   // t21, or t27
        //
        .i_bias_en(sig_bias_en),
        .i_bias(sig_bias),
        .i_load_bias(auxtrain[10][17] && auxtrain[10][18]), // last channel and one clock ahead of first data
        .o_biasqfull(sig_biasqfull),
        .i_relu(auxtrain[14][21:20]),
        .i_firstf(auxtrain[15][18]),
        .i_o_en(auxtrain[15][17]),
        .i_reset(conv_start),
        .clk(clk)
    );
    
    bbox_n_softmax bbox_n_softmax (
//		// Object detection bbox
//        .i_en(o_det_en),
//        .i_din(o_det_data),
//        .i_th(det_th), // 11.10 (1024 = 1.0)
//        .o_en(det_o_en),
//        .o_bbox(det_bbox),
//        .o_bbox_done(det_bbox_done),
//        .i_det_reset(det_reset),
		// Softmax
        .i_sm_en(smax_in_en),
        .i_sm_half(smax_in_half),
        .o_sm_en(smax_out_en),
        .o_sm_top1_class(smax_top1_class),	
        .o_sm_top1_score(smax_top1_score),	// 11.10
        .i_sm_restart(reg_softmax_clear),
        // common
        .i_n_classm1(sys_n_class_m1[10:0]),
        .i_relu(sot_relu),
        .multiscale(multiscale),
        .scale_offset(scale_offset),
        .clk(clk)
    );

//    nms NMS (
//        .i_en(det_o_en),
//        .i_bbox(det_bbox),
//        .i_done(sig_det_bbox_done),
//        // ddr if
//        .o_ddr_we(bbox_w_wr_en),
//        .i_ddr_full(bbox_w_full),
//        .o_ddr_data(bbox_w_din),
//        //
//        .i_nms_th(nms_th), // 11.10 (1024 = 1.0)
//        .multiscale(multiscale),
//        .i_reset(nms_reset),
//        .clk(clk)
//    );
//    assign sig_det_bbox_done = det_bbox_done && (~multiscale || multiscale_last);
    
    assign cmd_monitor = reg_monitor;
    logic cmd_en_d;

    mem_chksum m_chksum (
        .clka(clk),    // input wire clka
        .wea(i_rc_writestart),      // input wire [0 : 0] wea
        .addra(chksum_waddr),  // input wire [9 : 0] addra
        .dina(chksum_din),    // input wire [31 : 0] dina
        .clkb(clk),    // input wire clkb
        .addrb(chksum_raddr),  // input wire [9 : 0] addrb
        .doutb(chksum_dout)  // output wire [31 : 0] doutb
    );

    always @ (posedge clk) begin
`ifndef SIMUL
        cmd_en_d <= cmd_control[0];
        reg_en_nm <= (cmd_addr[31:28]==4'd1);
        chksum_waddr <= i_blocks[9:0];
        if (reg_en_nm)    // in case nm unit is enabled
            if (cmd_control[1]) begin   // on write
                if (cmd_control[0] && ~cmd_en_d) begin
                    case (cmd_addr[7:0])
                    8'd11: job_temp[25:0] <= cmd_dout[25:0];    // sig_model_addr
                    8'd12: job_temp[39:26] <= cmd_dout[13:0];   // sig_input_addr(14bits)
                    8'd13: job_temp[65:40] <= cmd_dout[25:0];   // sig_output_addr
                    8'd14: job_temp[76:66] <= cmd_dout[10:0];   // det_th
                    8'd15: job_temp[87:77] <= cmd_dout[10:0];   // nms_th
                    8'd17: begin
                            // job id and set continious run (no push)
                            next_input[87:0] <= job_temp[87:0];
                            next_input[96:88] <= cmd_dout[8:0];
                            fresh_input <= 1'b1;
                        end
                    8'd18: {multiscale_reset, multiscale_last, multiscale} <= cmd_dout[2:0];      // enable/disable multi-scale mode
                    8'd19: scale_offset <= cmd_dout;            // scale and offset
                    
                    // debugging
                    8'd20: chksum_raddr <= cmd_dout[9:0];            // checksum mem read address
                    8'd21: stall_detected <= cmd_dout[0];
                    
                    endcase
                end
            end else begin  // on read
                case (cmd_addr[7:0])
                8'd0: cmd_din <= {2'd0, i_blocks, sot_state, sot_i};
                8'd1: cmd_din <= {6'd0, reg_runtime_count};     // total time spent
                8'd2: cmd_din <= {6'd0, reg_multime_count};     // total multiplier active time
                8'd3: cmd_din <= {6'd0, reg_convtime_count};    // total time for conv layers
                8'd4: cmd_din <= {14'd0, det_chksum};
                8'd5: cmd_din <= {23'd0, last_job};
                8'd6: cmd_din <= {31'd0, fresh_input};
                8'd8: cmd_din <= {10'd0, smax_top1_score, smax_top1_class}; // last classification result {11,11}
                8'd9: cmd_din <= {6'd0, last_output_addr};  // the address of last detection result
                8'd10:cmd_din <= chksum_dout;
                8'd11:cmd_din <= 32'h00000011;              // capability: it supports SSD(bit0) and mobilenet(bit1)
                
                // debugging
                8'd12:cmd_din <= {26'h0, sot_r_mode};
                8'd13:cmd_din <= {6'h0, sig_model_addr};
                8'd14:cmd_din <= {18'h0, sig_input_addr};
                8'd15:cmd_din <= {6'h0, sig_output_addr};

                8'd16:cmd_din <= sig_err_code;
                8'd17:cmd_din <= sig_err_code2;
                
                8'd20: cmd_din <= {27'd0, stall_state, stall_detected};
                
                endcase
            end
        
        reg_runf <= (sot_state!=S_SOT_STOPPED);
        reg_runf_d1 <= reg_runf;
        reg_monitor <= was_detection ? {4'd0, last_output_addr[25:8], was_detection, last_job}
                                     : {smax_top1_score, smax_top1_class, was_detection, last_job};
`endif

        if (reg_runf_d1 && !reg_runf) begin
            reg_multime_count <= multime_count;
            reg_convtime_count <= convtime_count;
        end

        if (sot_state==S_SOT_STOPPED) begin
`ifdef SIMUL
            if (i_nm_runf) begin
`else
            if (fresh_input) begin
`endif
                runtime_count <= 26'd0;
                multime_count <= 26'd0;
                convtime_count <= 26'd0;
            end
        end else begin
            runtime_count <= runtime_count + 1'b1;
            if (o_rc_out_valid) multime_count <= multime_count + 1'b1;
            if (conv_mode) convtime_count <= convtime_count + 1'b1;
        end
        
//    end
    

//    always @ (posedge clk) begin

        reg_su_row <= o_row_i;
        reg_su_col <= o_col_i;
        null_goto <= (sot_goto==10'd0);
        non_conv_read <= (sot_r_mode==6'd34 || sot_r_mode==6'd36);

        r_mode <= ~header_mode && ~bbox_mode && (sot_r_mode==6'd33 || sot_r_mode==6'd35);
        res_mode <= ~header_mode && ~bbox_mode && (sot_r_mode==6'd37);  // ddr read for resnet
        w_mode <= ~header_mode && ~bbox_mode && (sot_r_mode==6'd34);
        conv_mode <= ~header_mode && ~bbox_mode && ~sot_r_mode[5];
        bbox_mode <= ~header_mode && sot_r_mode==6'd48 && (~multiscale || multiscale_last);
		if (r_mode || res_mode)   ddr_len_m1 <= {2'b00,sot_ickpim_m1};
		else if (w_mode)          ddr_len_m1 <= {2'b00,sig_ockpim_m1};
		else			           ddr_len_m1 <= sot_paralen - 'b1;

        conv_start <= (sot_state==S_SOT_DISPATCH && ~sot_r_mode[5]);
        dispatch_ddr <= (sot_state==S_SOT_DISPATCH || sot_load_start || det_bbox_done);
`ifdef SIMUL
        sot_load_start = (sot_state==S_SOT_STOPPED && i_nm_runf);
`else
        sot_load_start = (sot_state==S_SOT_STOPPED && fresh_input);
`endif
        
        i_rc_writestart <= (sot_state==S_SOT_DISPATCH);
        i_rc_readstart <= (
            (sot_state==S_SOT_DISPATCH && (~sot_r_mode[5] || non_conv_read))    // DDR write included
        );
        
        sot_ickpim_m1 <= sot_ickpim - 1'b1;
        sot_ockpim_m1 <= sot_ockpim - 1'b1;
        reg_interlg_reset <= interlg_reset;

        reg_nu_out_valid <= o_rc_out_valid;
        reg_nu_out_seq <= o_rc_out_seq_partial;
        reg_first_chan <= (o_rc_out_valid && o_first_chan);
        reg_last_chan <= (o_rc_out_valid && o_last_chan);
        reg_firstf <= o_firstf;
        reg_lastf <= o_lastf;
        reg_softmax_clear <= (sot_state==S_SOT_DISPATCH && sot_relu==2'b11);
        
        reg_suout <= sig_suout; // t21 or t27
        
        // softmax data shifter
        
        case (sm_state)
        S_SM_IDLE: begin
                smax_in_en <= 1'b0;
                if (auxtrain[19][21:20]==2'b11 && auxtrain[19][17]) begin
                    smax_counter <= 0;
                    sm_suout <= sig_suout;  // t21
                    sm_state <= S_SM_SHIFT;
                end
            end
        S_SM_SHIFT: begin
                if (smax_counter==clogb2(N_SUOUT-1)'(N_SUOUT-1)) begin
                    sm_state <= S_SM_IDLE;
                end else
                    smax_counter <= smax_counter + 1'b1;
                smax_in_half <= sm_suout[0];
                smax_in_en <= 1'b1;
                sm_suout[N_SUOUT-2:0] <= sm_suout[N_SUOUT-1:1];
            end
        endcase
        
        reg_circuit_idle <= (~reg_nu_out_valid && ~o_rc_out_valid && entrain=={N_CTRAIN{1'b0}});
        
`ifdef SMALL_SYS
        case (sot_r_mode)
        6'b001000:                      reg_nu_data <= {8{o_rc_data[15:0]}};
        6'b000101, 6'b010101:           reg_nu_data <= {{56{16'd0}}, {8{o_rc_data[8:0]}}};
        6'b000110,6'b000111,6'b010111:  reg_nu_data <= {{92{16'd0}}, o_rc_data[35:0]};
        endcase
`else
        case (sot_r_mode)
        6'b001000:                      reg_nu_data <= {16{o_rc_data[15:0]}};
        6'b000101, 6'b010101:           reg_nu_data <= {{112{16'd0}}, {16{o_rc_data[8:0]}}};
        6'b000110,6'b000111,6'b010111:  reg_nu_data <= {{184{16'd0}}, o_rc_data[71:0]};
        endcase
`endif

        // control train
        
        entrain[N_CTRAIN-1:1] <= entrain[N_CTRAIN-2:0];
        seqtrain[N_CTRAIN-1:1] <= seqtrain[N_CTRAIN-2:0];
        auxtrain[N_CTRAIN-1:1] <= auxtrain[N_CTRAIN-2:0];

        entrain[0] <= reg_nu_out_valid;
        seqtrain[0] <= reg_nu_out_seq;
        auxtrain[0][5:0] <= sot_r_mode;
        auxtrain[0][6] <= reg_su_row[0];
        auxtrain[0][7] <= reg_lastf;
        auxtrain[0][15:8] <= sot_layer;
        auxtrain[0][16] <= reg_first_chan;
        auxtrain[0][17] <= reg_nu_out_valid && reg_last_chan;
        auxtrain[0][18] <= reg_firstf;
        auxtrain[0][19] <= conv_start;
        auxtrain[0][21:20] <= sot_relu;
        auxtrain[0][31:22] <= reg_su_col;
        auxtrain[0][37:32] <= sot_w_mode;
        auxtrain[0][W_CTRAIN-1:38] <= 0;
        
        if (o_det_en) det_chksum <= det_chksum + o_det_data;
        
        // main state transition diagram
    
        case (sot_state)
        S_SOT_STOPPED: begin
`ifdef SIMUL
                if (i_nm_runf) begin
                    sot_wseq <= 12'd0;
                    sotw_state <= 1'b0;
`else
                if (fresh_input) begin
                    sig_model_addr <= next_input[25:0];
                    sig_input_addr <= next_input[39:26];
                    sig_output_addr <= next_input[65:40];
                    det_th <= next_input[76:66];
                    nms_th <= next_input[87:77];
                    job_id <= next_input[96:88];
                    fresh_input <= 1'b0;
`endif
                    header_mode <= 1'b1;
                    sot_state <= S_SOT_LOAD;
                    
                    just_started <= 1'b1;
                    det_chksum <= 18'd0;
                    i_blocks <= 16'd0;
                end else
                    header_mode <= 1'b0;
            end
        S_SOT_LOAD: begin
                if (ddr_done) begin
                    sot_i <= STARTING_LAYER;
                    hold_delay <= 2'd3;
                    header_mode <= 1'b0;
                    det_reset <= 1'b1;
                    nms_reset <= (~multiscale || multiscale_reset);
                    sot_state <= S_SOT_HOLD;
                end
            end
        S_SOT_HOLD: begin // wait sot memory output ready
                if (hold_delay==2'd0) begin
                    sot_state <= S_SOT_FLUSH;
                end else 
                    hold_delay <= hold_delay - 1'b1;
                det_reset <= 1'b0;
                nms_reset <= 1'b0;
            end
        S_SOT_NEXT: begin
                if (//~just_started && // check previous record if not just started
                    ((~null_goto && ~o_all_done) || // for conditional and
                    sot_r_mode==6'd49) ) begin            // unconditional goto
                    sot_i <= sot_goto;
                    hold_delay <= 2'd3;
                    sot_state <= S_SOT_HOLD;
                // set next record
                end else
                    sot_state <= S_SOT_FLUSH;
                just_started <= 1'b0;
                ddr_donef <= 1'b0;
                comp_donef <= 1'b0;
            end
        S_SOT_FLUSH:
            if (reg_circuit_idle && ddrif_idle) begin
                reg_sot <= sot_record;
                sot_i <= sot_i + 1'b1;
                hold_delay <= 2'd3;
                sot_state <= S_SOT_FLUSH2;
            end
        S_SOT_FLUSH2:   // some more delay for registered shortcuts of SOT elements
            if (hold_delay==2'd0) begin
                last_delay <= 8'd50;

                sot_state <= S_SOT_DISPATCH;
            end else 
                hold_delay <= hold_delay - 1'b1;
        S_SOT_DISPATCH: begin
                case (sot_r_mode)
                6'd33: begin    // video input
                        ddr_addr <= sig_input_addr;
                        sot_state <= S_SOT_DDR_MONITOR;
                    end
                6'd35, 6'd37: begin    // DDR read (6'd37: for resnet)
                        ddr_addr <= sot_raddr[13:0] + TEMPMAP_SPACE;
                        sot_state <= S_SOT_DDR_MONITOR;
                    end
                6'd34: begin    // DDR write
                        ddr_addr <= sot_waddr[13:0] + TEMPMAP_SPACE;
                        sot_state <= S_SOT_DDR_MONITOR;
                    end
                6'd36: begin    // detection
                        reg_n_class_m1 <= sot_nfm1[10:0];
                        sot_state <= S_SOT_DET_MONITOR;
                    end
                // convolution
                6'd21,6'd23,6'd5,6'd6,6'd8,6'd7: begin
                        sot_state <= S_SOT_CONV_MONITOR;
                    end
                6'd49: sot_state <= S_SOT_NEXT; // unconditional goto
                6'd48: sot_state <= S_SOT_BBOX_MONITOR;
                6'd50: begin
                        if (last_delay==8'd0) begin
                            last_job <= job_id;
                            last_output_addr <= sig_output_addr;               
                            multiscale <= 1'b0;
                            reg_runtime_count <= runtime_count;

                            sot_state <= S_SOT_STOPPED;
                        end else
                            last_delay <= last_delay - 1'b1;
                    end
                endcase
                i_blocks <= i_blocks + 1'b1;
            end
        S_SOT_DDR_MONITOR:
            if (ddr_done) sot_state <= S_SOT_NEXT;
        S_SOT_CONV_MONITOR: begin
                if (ddr_done) ddr_donef <= 1'b1;
                if (o_done) comp_donef <= 1'b1;
                if (sot_relu==2'b11) begin
                    if (smax_out_en) begin
                        was_detection <= 1'b0;
                        sot_state <= S_SOT_NEXT; // the next should be terminating operation (mode 50)
                    end
                end else if (ddr_donef && comp_donef)
                    sot_state <= S_SOT_NEXT;
            end
        S_SOT_DET_MONITOR:
            if (o_det_done) sot_state <= S_SOT_NEXT;
        S_SOT_BBOX_MONITOR:
            if (ddr_done || (multiscale && ~multiscale_last && det_bbox_done)) begin
                was_detection <= 1'b1;
                sot_state <= S_SOT_NEXT;    // the next should be terminating operation (mode 50)
            end
        endcase
        
        // if stall is detected, reset states
        
        if (sot_state!=S_SOT_STOPPED) begin
            if (prev_sot_state==sot_state) begin
                if (stall_count[28]) begin
                    sot_state <= S_SOT_STOPPED;
                    sm_state <= S_SM_IDLE;
                    stall_state <= prev_sot_state;
                    fresh_input <= 1'b0;
                    stall_detected = 1'b1;
                end else
                    stall_count <= stall_count + 1'b1;
            end else
                stall_count <= 30'd0;
            prev_sot_state <= sot_state;
        end
         
        
    end
    
    assign interlg_reset = (sot_state==S_SOT_NEXT && ~just_started && ~null_goto && o_all_done);
    assign sot_wsave = reg_sot[8] && sot_record[8];
    assign sot_w_mode = reg_sot[5:0];
    assign sot_r_mode = reg_sot[11:6];
    assign sot_tmost = reg_sot[12];
    assign sot_sxm1 = reg_sot[22:13];
    assign sot_osxm1 = reg_sot[32:23];
    assign sot_ncm1 = reg_sot[45:33];
    assign sot_nfm1 = reg_sot[58:46];
    assign sot_nmapm1 = reg_sot[74:59];
    assign sot_staddr = reg_sot[78:75];
    assign sot_shaddr = reg_sot[91:79];
    assign sot_ickpim = reg_sot[109:92];
    assign sot_ockpim = reg_sot[127:110];
    assign sot_istep = reg_sot[145:128];
    assign sot_ostep = reg_sot[163:146];
    assign sot_ickfull = reg_sot[181:164];
    assign sot_ckflush = reg_sot[191:182];
    assign sot_raddr = reg_sot[209:192];
    assign sot_waddr = reg_sot[227:210];
    assign sot_goto = reg_sot[237:228];
    assign sot_paraaddr = reg_sot[267:238];
    assign sot_paralen = reg_sot[287:268];
    assign sot_layer = reg_sot[295:288];
    assign sot_relu = reg_sot[297:296];

    assign o_nm_done = (sot_state==S_SOT_STOPPED);

    assign o_mode = sot_r_mode;
    assign o_out_valid = o_rc_out_valid;
    assign o_out_lastchan = o_last_chan;
    assign o_out_seq = o_rc_out_seq;
    assign o_out_data = o_rc_data;
    assign o_layerid = sot_layer;
    
    assign o_su_valid = auxtrain[19][21:20]==2'b10 ? auxtrain[25][17] & auxtrain[25][7] : auxtrain[19][17];
    assign o_su_data = sig_suout;   // t21 or t27
    assign o_su_layerid = auxtrain[19][15:8];

endmodule
