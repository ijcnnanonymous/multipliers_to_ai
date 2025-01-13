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

//////////////////////////////////////////////////////////////////////////////////
// Company: Neurocoms Inc.
// Engineer: Byungik Ahn (jerryahn@neurocoms.com)
// 
// Create Date: 2020/11/04 16:39:26
// Design Name: 
// Module Name: networkunit
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: Network Unit storing (partial) feature maps. 
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


module networkunit # (
        parameter DATA_WIDTH = 16,
        parameter N_MX = 32,
        parameter N_ADDR = 15,
        parameter C_MXNUM = 32,
        parameter IMSIZE_W = 18,
`ifdef SMALL_SYS 
        parameter MX_ADDR_WIDTH = 12,
        parameter MAX_MX_ADDR = 3072,
        parameter N_RECEPTOR = 4
`else
        parameter MX_ADDR_WIDTH = 13,
        parameter MAX_MX_ADDR = 6144,
        parameter N_RECEPTOR = 8
`endif
    )(
        //== command from control unit via NU
        input i_rc_readstart = 1'b0, // command for starting to read
        input i_rc_writestart = 1'b0, // command for starting to write
        input [5:0] i_i_rc_mode = 6'h0, // indicates the type of read
        input [5:0] i_o_rc_mode = 6'h0, // indicates the type of read
        input [9:0] i_rc_sx_m1 = 10'h0, // W - 1
        input [9:0] i_rc_sy_m1 = 10'h0, // H - 1 (full map)
        input [9:0] i_rc_o_sxm1 = 10'h0,    // W - 1 for s1, [(W+1)/2] - 1 for s2
        input [9:0] i_rc_o_sym1 = 10'h0,    // H - 1 for s1, [(H+1)/2] - 1 for s2
        input [IMSIZE_W-1:0] i_rc_imsize,
        input [9:0] i_ckflush,
        input [12:0] i_n_c_m1,  // number of (repeating) channels
        input [12:0] i_n_f_m1,  // number of (repeating) feature maps
        input [15:0] i_n_map_m1,    // number of maps = n_c * n_f - 1
        input [IMSIZE_W-1:0] i_ickpim_m1,    // partial image size
        input [IMSIZE_W-1:0] i_ockpim_m1,    // partial image size
        output [IMSIZE_W-1:0] o_ockpim_m1,
        input [IMSIZE_W-1:0] i_istep,    // input address increment
        input [IMSIZE_W-1:0] i_ostep,    // output address increment
        input [3:0] i_rstate_addr,  // state index
        input [12:0] i_shuttle_addr,  // shuttle memory base address
        input i_topmost = 1'b0, // flag indicating the first fragmentation
        input i_wait_save = 1'b0, // flag indicating the first fragmentation
        input [17:0] i_i_baseaddr = 18'd0,
        input [17:0] i_o_baseaddr = 18'd0,
        // SU input
        // 한 계층에서 SU출력이 몇번째인지를 식별
        input i_su_we,
        input [15:0] i_su_addr,
        input [15:0][15:0] i_su_din,
        input i_su_row_odd,
        input [9:0] i_su_col,
        input i_su_lastchan,
        input i_su_lastf,
        input [5:0] i_o_rc_mode_su,
        // DDR interface
        output ddr_r_rd_en, // new data is accepted
        input ddr_r_valid,  // new data is available
        input [127:0] ddr_r_din,   // the new data
        output reg ddr_w_wr_en, // new data is accepted
        input ddr_w_full,  // new data is available
        output reg [127:0] ddr_w_dout,   // the new data
        //== NU controls 
        // the input command and parameters are sent back to NU to make it in action
        //== the output of the receptor
        output o_rc_out_valid,  // output validity
        output [15:0] o_rc_out_seq, // output data sequence (in full map)
        output [15:0] o_rc_out_seq_partial, // output data sequence (in partial map)
        output [9:0] o_row_i,
        output [9:0] o_col_i,
        output o_first_chan,
        output o_last_chan,
        output o_o_firstf,
        output o_o_lastf,
        output [N_RECEPTOR*9-1:0][DATA_WIDTH-1:0] o_rc_data,   // output data
        output o_pop_para,
        output o_done,
        output o_all_done,
        output o_bottommost,
        // detection
        output reg o_det_done = 1'b0,
        output reg o_det_en = 1'b0,
        output reg [17:0] o_det_data = 18'd0,
        input i_det_q_full,
        // common
        input i_paraqempty,
        input interlg_reset,
        input reset_n = 1'b1,
        input clk
    );
    
    function [MX_ADDR_WIDTH-1:0] add_addr (input [MX_ADDR_WIDTH-1:0] a, b);              
        reg [MX_ADDR_WIDTH:0] c;
    begin
        c = {1'b0,a} + b;
        add_addr[MX_ADDR_WIDTH-1:MX_ADDR_WIDTH-2] = (c[MX_ADDR_WIDTH:MX_ADDR_WIDTH-2]<3'b011) ? c[MX_ADDR_WIDTH-1:MX_ADDR_WIDTH-2] : 2'(c[MX_ADDR_WIDTH:MX_ADDR_WIDTH-2] - 3'b011);
		add_addr[MX_ADDR_WIDTH-3:0] = c[MX_ADDR_WIDTH-3:0];
    end                                                           
    endfunction                                                     

    // states for reading
    enum bit [3:0] {S_INU_IDLE, S_INU_WAIT_RECEPTOR, S_INU_TRANSIT, S_INU_HOLD_ON, S_INU_READING, S_INU_DETECTION} in_nu_state = S_INU_IDLE;
    // states for writing
    enum bit [3:0] {S_DET_IDLE, S_DET_HEADER, S_DET_BOX, S_DET_GUARD, S_DET_CLASS, S_DET_GUARD2, S_DET_FLUSH, S_DET_FLUSH2} det_substate = S_DET_IDLE;

    // Receptor IOs

    //== command from control unit via NU
    reg [IMSIZE_W-1:0] oseq = 0, w_addr, evenrow_base, w_rowbase, o_ch; // variables for writing
    reg [2:0] o_subch;
    reg [13:0] o_currbase; // variables for writing
    reg [IMSIZE_W-1:0] r_addr; // variables for reading
    reg [17:0] i_currbase; // variables for reading
    reg [IMSIZE_W-1:0] i_ch, i_fm; // variables for reading
    logic [3:0][IMSIZE_W-1:0] i_ch_d; 
    //== NU controls 
    // the input command and parameters are sent back to NU to make it in action
    wire [5:0] o_rc_mode;
    logic reg_o_ckpim_onef, oseq_last_m1 = 0;
    logic [IMSIZE_W-1:0] reg_i_ckpim_m1, reg_o_ckpim_m1, reg_o_ckpim_m2, reg_ow_ckpim_m1;    // partial image size
    logic [IMSIZE_W-1:0] reg_i_ckpim_m2, reg_ow_ckpim_m2;
    //== inputs from NU
    // data read from MX memories in the NU
    logic i_rc_valid;
    logic [4:0] i_rc_valid_d;
    logic ddr_wr;
    logic ddr_wr_d[4:0];
    logic i_rc_firstf_a2;
    logic i_rc_lastf_a2;
    logic o_rc_bottommost;
    logic o_is_shuttle_idle;
    logic [IMSIZE_W-1:0] o_rc_im_left, o_rc_oim_left;
    reg [15:0] i_rc_seq = 0;
    logic [4:0][15:0] i_rc_seq_d;
    reg [N_RECEPTOR*4-1:0][DATA_WIDTH-1:0] i_rc_dout = 0;
    wire o_rc_readstart;  // start command for NU
    logic [3:0][7:0] v48;
    logic [3:0][15:0] v416;
    logic [N_RECEPTOR-1:0][15:0] v_per_receptor;
    logic [15:0][15:0] v1616;
    reg [N_RECEPTOR*4-1:0][DATA_WIDTH-1:0] reg_dout = 0;
    logic reg_hold_on = 1'b0;
    logic [9:0] two_sx;
    logic [11:0] reg_col, reg_row;
    logic [5:0] reg_i_mode;
    // shortcuts
    logic rmode_conv1x1s1, rmode_conv3x3s2i, rmode_conv3x3s2, rmode_dws1, rmode_dws2, rmode_dws2_2, rmode_ddrupload, rmode_detection, rmode_resnet, wmode_resnet;
    logic [17:0] det_box_addr, det_cls_addr;
    logic [2:0] det_n_ar_m1;
    logic [9:0] det_n_class_m1;
    logic [2:0] det_scale;
    //
    logic [17:0] det_b_ad, det_c_ad;
    logic [1:0] det_coori;
    logic [3:0] det_cls16_i;
    logic [2:0] det_ari;
    logic [4:0] det_xi, det_yi;
    logic [9:0] det_pxi, det_pxi_p1, det_clsi;
    logic [3:0][15:0] det_data_pipe;
    logic [3:0][2:0] det_en_pipe;

    integer i;

    // Original NU IOs
    
    logic [N_MX-1:0] mx_wen = 0;
    logic [N_MX-1:0][MX_ADDR_WIDTH-1:0] mx_waddr, mx_raddr;
    logic [N_MX-1:0][DATA_WIDTH-1:0] mx_din, mx_dout, mx_dinout, mx_doutin;
    logic [2:0] det_delay_cnt;
    
    logic i_seq_cond1, i_seq_cond2;
    
    logic [2:0][127:0] res_dataq;
    logic [11:0][MX_ADDR_WIDTH-1:0] res_addrq;
    logic [11:0] res_enq;
    logic [11:0][4:0] res_chq;
    logic [15:0] resadder_a, resadder_b, resadder_c;
    
    logic [9:0] reg_rc_o_sxm1, reg_rc_o_sxm2;
    logic reg_col_last_m1 = 0, reg_rc_o_sx_onef, r_addr_last_m1 = 0;
    
    logic check = 1'b0;
    
    // alias of signals for detection
    assign det_box_addr = i_i_baseaddr;
    assign det_cls_addr = i_o_baseaddr;
    assign det_n_ar_m1 = i_n_c_m1[2:0];
    assign det_n_class_m1 = i_n_f_m1[9:0];
    assign det_scale = reg_rc_o_sxm1[2:0];
    
    // input modes
    localparam [5:0] CONV1x1S1 = 6'b001000;
    localparam [5:0] CONV3x3S2I = 6'b010101;
    localparam [5:0] CONV3x3S2 = 6'b000101;
    localparam [5:0] DW3x3S1 = 6'b000110;
    localparam [5:0] DW3x3S2 = 6'b000111;
    localparam [5:0] DDRUPLOAD = 6'd34;
    localparam [5:0] DETECTION = 6'd36;
    localparam [5:0] RESNET = 6'd37;
    localparam [5:0] DW3x3S2_2 = 6'b010111;	// simple DWS2 read mode
    // writing operations
`ifndef SMALL_SYS
    localparam [5:0] W_16_2x16 = 6'd1;
    localparam [5:0] W_8_2x16 = 6'd2;
    localparam [5:0] W_16_DWS2 = 6'd3;
`else    
    localparam [5:0] W_8_2x16 = 6'd1;
    localparam [5:0] W_4_2x16 = 6'd2;
    localparam [5:0] W_8_DWS2 = 6'd3;
`endif
    localparam [5:0] W_DDR_IMAGE = 6'd4;
    localparam [5:0] W_DDR_NONIMAGE = 6'd6;
    localparam [5:0] W_DDR_S2 = 6'd7;
    localparam [5:0] W_RESNET = 6'd8;

    receptor # (.DATA_WIDTH(DATA_WIDTH)) uut_receptor 
    (
        .i_rc_readstart(i_rc_readstart),
        .i_rc_mode(i_i_rc_mode),
        .i_rc_sx_m1(i_rc_sx_m1),
        .i_rc_sy_m1(i_rc_sy_m1),
        .i_rc_o_sxm1(i_rc_o_sxm1),
        .i_rc_o_sym1(i_rc_o_sym1),
        .i_rc_imsize(i_rc_imsize),
        .i_ickpim_m1(i_ickpim_m1),
        .i_ockpim_m1(i_ockpim_m1),
        .i_topmost(i_topmost),
        .i_wait_save(i_wait_save),
        .i_n_c_m1(i_n_c_m1),
        .i_n_f_m1(i_n_f_m1),
        .i_n_map_m1(i_n_map_m1),
        .i_rstate_addr(i_rstate_addr),
        .i_shuttle_addr(i_shuttle_addr),
        //== NU controls 
        // the input command and parameters are sent back to NU to make it in action
        .o_rc_readstart(o_rc_readstart),
        .o_rc_bottommost(o_rc_bottommost),
        .o_rc_im_left(o_rc_im_left),
        .o_rc_oim_left(o_rc_oim_left),
        //== inputs from NU
        // data read from MX memories in the NU
        .i_rc_valid(i_rc_valid_d[4]),
        .i_rc_firstf_a2(i_rc_firstf_a2),
        .i_rc_lastf_a2(i_rc_lastf_a2),
        .i_rc_dout(i_rc_dout),
        //== the output of the receptor
        .o_rc_out_valid(o_rc_out_valid),
        .o_rc_out_seq(o_rc_out_seq),
        .o_rc_out_seq_partial(o_rc_out_seq_partial),
        .o_rc_data(o_rc_data),
        .o_row_i(o_row_i),
        .o_col_i(o_col_i),
        .o_first_chan(o_first_chan),
        .o_last_chan(o_last_chan),
        .o_o_firstf(o_o_firstf),
        .o_o_lastf(o_o_lastf),
        .o_done(o_done),
        .o_all_done(o_all_done),
        .o_is_shuttle_idle(o_is_shuttle_idle),
        // common
        .interlg_reset(interlg_reset),
        .reset_n(reset_n),
        .clk(clk)
    );
    
    genvar idx;

    generate
        for(idx = 0; idx < N_MX; idx = idx + 1) begin : gen_inst
            mx_mem mx_mem (
              .clka(clk),    // input wire clka
              .wea(mx_wen[idx]),      // input wire [0 : 0] wea
              .addra(mx_waddr[idx][MX_ADDR_WIDTH-1:0]),  // input wire [11 : 0] addra
              .dina(mx_din[idx]),    // input wire [15 : 0] dina
              .clkb(clk),    // input wire clkb
              .addrb(mx_raddr[idx][MX_ADDR_WIDTH-1:0]),  // input wire [11 : 0] addrb
              .doutb(mx_dout[idx])  // output wire [15 : 0] doutb
            );
        end
    endgenerate
    
    generate
        for (idx = 0; idx < 4; idx = idx + 1) begin : gen_conv
            pixel2half pixel2half (
                .clk(clk),
                .i_pixel(v48[idx]),
                .o_half(v416[idx])
            );
        end 
    endgenerate
    
//    generate
//        for (idx = 0; idx < 8; idx = idx + 1) begin : gen_resadder
//            halfadder halfadder (
//                .clk(clk),
//                .i_half1(resadder_a[idx]),
//                .i_half2(resadder_b[idx]),
//                .o_half_added(resadder_c[idx])
//            );
//        end 
//    endgenerate
    halfadder resnet_adder (
        .clk(clk),
        .i_half1(resadder_a),
        .i_half2(resadder_b),
        .o_half_added(resadder_c)
    );


    always @ (posedge clk) begin

        // mode shortcuts
        rmode_conv1x1s1 <= (reg_i_mode==CONV1x1S1);
        rmode_conv3x3s2i <= (reg_i_mode==CONV3x3S2I);
        rmode_conv3x3s2 <= (reg_i_mode==CONV3x3S2);
        rmode_dws2_2 <= (reg_i_mode==DW3x3S2_2);
        rmode_dws1 <= (reg_i_mode==DW3x3S1);
        rmode_dws2 <= (reg_i_mode==DW3x3S2);
        rmode_ddrupload <= (reg_i_mode==DDRUPLOAD);
        rmode_detection <= (reg_i_mode==DETECTION);
        rmode_resnet <= (reg_i_mode==RESNET);
        wmode_resnet <= (i_o_rc_mode_su==W_RESNET);
    
        i_rc_valid_d[0] <= i_rc_valid;
        i_rc_valid_d[4:1] <= i_rc_valid_d[3:0];
        i_rc_seq_d[0] <= i_rc_seq;
        i_rc_seq_d[4:1] <= i_rc_seq_d[3:0];
        i_ch_d[0] <= i_ch;
        i_ch_d[3:1] <= i_ch_d[2:0];
        i_rc_firstf_a2 <= (i_rc_valid_d[1] && i_rc_seq_d[1]==16'd0);
        i_rc_lastf_a2 <= (i_rc_valid_d[1] && i_rc_seq_d[1]==reg_i_ckpim_m1);
        
        reg_i_mode <= i_i_rc_mode;
        
        ddr_wr_d[0] <= ddr_wr; 
        ddr_wr_d[2:1] <= ddr_wr_d[1:0];
        ddr_w_wr_en <= ddr_wr_d[2];

        reg_i_ckpim_m1 <= (o_rc_bottommost) ? o_rc_im_left + i_ckflush - 1'b1 : i_ickpim_m1;
        reg_o_ckpim_m1 <= (o_rc_bottommost) ? o_rc_oim_left - 1'b1 : i_ockpim_m1;
        reg_o_ckpim_m2 <= (o_rc_bottommost) ? o_rc_oim_left - 2'd2 : i_ockpim_m1 - 1'b1;
        reg_o_ckpim_onef <= (o_rc_bottommost) ? (o_rc_oim_left==18'd1) : (i_ockpim_m1==18'd0);//(reg_o_ckpim_m1==0);
        if (o_done) reg_ow_ckpim_m1 <= reg_o_ckpim_m1;
        reg_i_ckpim_m2 <= reg_i_ckpim_m1 - 1'b1;
        reg_ow_ckpim_m2 <= reg_ow_ckpim_m1 - 1'b1;
        
        det_pxi_p1 <= det_pxi + 1'b1;
        det_data_pipe[3:1] <= det_data_pipe[2:0];
        det_en_pipe[3:1] <= det_en_pipe[2:0];
        
        if (in_nu_state!=S_INU_READING) begin
            i_seq_cond1 <= (reg_i_ckpim_m1==18'd0);
            i_seq_cond2 <= (reg_ow_ckpim_m1==18'd0);
        end
        
        reg_rc_o_sxm1 <= i_rc_o_sxm1;
        reg_rc_o_sxm2 <= i_rc_o_sxm1 - 1'b1;
        reg_rc_o_sx_onef <= (i_rc_o_sxm1==10'd0);

        // reading

        case (in_nu_state)
        S_INU_IDLE: begin
                if (rmode_detection) begin
                    if (i_rc_readstart) begin
                        det_substate = S_DET_IDLE;
                        in_nu_state <= S_INU_DETECTION;
                    end
                end else if (i_rc_readstart) begin
                    i_rc_seq <= 16'd0;
                    r_addr <= 18'd0;
                    r_addr_last_m1 <= 1'b0;
                    i_ch <= 18'd0;
                    i_fm <= 18'd0;
                    evenrow_base <= 18'd0;
                    // DW3x3S2에서 두 row의 step 사이즈를 식별한다.
                    // 두 개의 8 채널 그룹이 2 x osx 주소에 포함되므로 두 개의 채널그룹마다 주소는 2 x ceil(osx/2)*2 
                    two_sx <= {reg_rc_o_sxm1 + 1'b1, 1'b0};
                    i_currbase <= i_i_baseaddr;
                    if (~reg_i_mode[5])
                        in_nu_state <= S_INU_WAIT_RECEPTOR;  // read for convolution
                    else if (rmode_ddrupload)
                        in_nu_state <= S_INU_READING;       // read for DDR upload
                end
                o_det_done <= 1'b0;
                det_en_pipe[0] <= 3'd0;
                o_det_en <= 1'b0;
            end
        S_INU_WAIT_RECEPTOR: begin
                // wait until o_rc_readstart is on
                if (o_rc_readstart) in_nu_state <= S_INU_TRANSIT;
            end
        S_INU_TRANSIT: begin
                // availability check here: shuttle processing and parameter read
                if (~reg_hold_on && (reg_i_mode[5] || ~i_paraqempty)) begin
                    in_nu_state <= S_INU_READING;
                end
            end
        S_INU_READING: begin
                if (~rmode_ddrupload || ~ddr_w_full) begin
                    if ((~rmode_ddrupload && i_seq_cond1) || (rmode_ddrupload && i_seq_cond2)) begin
                        i_rc_seq <= 16'd0;
                        i_seq_cond1 <= (reg_i_ckpim_m1==18'd0);
                        i_seq_cond2 <= (reg_ow_ckpim_m1==18'd0);
                        r_addr <= 18'd0;        // valid only when reg_i_mode==DW3x3S2
                        r_addr_last_m1 <= 1'b0;
                        evenrow_base <= 18'd0;  // valid only when reg_i_mode==DW3x3S2

                        if (i_ch==i_n_c_m1) begin
                            i_currbase <= i_i_baseaddr;
                            i_ch <= 18'd0;
                            i_fm <= i_fm + 1'b1;
                        end else begin
                            i_ch <= i_ch + 1'b1;
                            // in CONV3x3S2I, i_currbase does not change because there is only one channel cycle
                            if ( 
                                 rmode_conv1x1s1 ||
                                 (rmode_ddrupload && i_ch[0]==1'b1) ||
`ifndef SMALL_SYS
                                 (rmode_conv3x3s2 && i_ch[3:0]==4'b1111) ||
                                 rmode_dws2_2 ||
                                 (reg_i_mode[1] && i_ch[0]) )
`else
                                 (rmode_conv3x3s2 && i_ch[2:0]==3'b111) ||
                                 (rmode_dws2 && i_ch[0]==1'b1) ||
                                 (rmode_dws1 && i_ch[1:0]==2'b11) )
`endif
                                i_currbase <= add_addr(i_currbase, i_istep);
                        end
                        evenrow_base <= 18'd0;  // valid only when reg_i_mode==DW3x3S2
                        in_nu_state <= (i_ch==i_n_c_m1 && i_fm==i_n_f_m1) ? S_INU_IDLE : S_INU_TRANSIT;
                    end else begin
`ifndef SMALL_SYS
                        // from here, valid only when reg_i_mode==DW3x3S2,CONV3x3S2 begin
                        if (reg_rc_o_sx_onef || r_addr_last_m1) begin //r_addr==reg_rc_o_sxm1) begin
                            r_addr <= 18'd0;
                            r_addr_last_m1 <= 1'b0;
                            evenrow_base <= evenrow_base + two_sx;
                        end else begin
                            r_addr <= r_addr + 1'b1;
                            r_addr_last_m1 <= (r_addr[9:0]==reg_rc_o_sxm2);
                        end
                        // until here, valid only when reg_i_mode==DW3x3S2,CONV3x3S2 end
`endif
                        i_rc_seq <= i_rc_seq + 1'b1;
                        i_seq_cond1 <= (i_rc_seq==reg_i_ckpim_m2);
                        i_seq_cond2 <= (i_rc_seq==reg_ow_ckpim_m2);
                    end
                end
            end
        
        // sot elements
        
        // det_scale(3), i_rc_sx_m1(10) = k, det_box_addr(18), det_cls_addr(18)
        // i_ickpim_m1(18), i_istep(18), det_n_ar_m1(3), det_n_class_m1(10)
        
        // variables
        
        // det_b_ad(18), det_c_ad(18), det_coori(2), det_cls16_i(4), det_ari(3)
        // det_xi(5), det_yi(5), det_pxi(10), det_clsi(10)
        
        S_INU_DETECTION: begin
            if (~i_det_q_full) begin
                case (det_substate)
                S_DET_IDLE: begin
                        det_b_ad <= det_box_addr;
                        det_c_ad <= det_cls_addr;
                        det_pxi <= 10'd0;
                        det_coori <= 2'd0;
                        det_cls16_i <= 4'd0;
                        det_ari <= 3'd0;
                        det_clsi <= 10'd0;
                        if (i_topmost) begin
                            det_xi <= 5'd0;
                            det_yi <= 5'd0;
                        end
                        det_substate <= S_DET_HEADER;
                    end
                S_DET_HEADER: begin
                        det_data_pipe[0][15:13] <= det_scale;
                        det_data_pipe[0][12:8] <= det_yi;
                        det_data_pipe[0][7:3] <= det_xi;
                        det_data_pipe[0][2:0] <= det_ari;
                        det_en_pipe[0] <= 3'd1;
                        det_substate <= S_DET_BOX;
                    end
                S_DET_BOX: begin
                        if (det_coori==2'd3) begin
                            det_coori <= 2'd0;
                            det_delay_cnt <= 3'd6;
                            det_substate <= S_DET_GUARD;
                        end else
                            det_coori <= det_coori + 1'b1;
                            
                        det_en_pipe[0] <= 3'd2;
                        det_data_pipe[0] = {11'd0, det_pxi[0], det_ari[1:0], det_coori[1:0]};
                        mx_raddr <= {32{det_b_ad[MX_ADDR_WIDTH-1:0]}};
                    end
                S_DET_GUARD: begin
                        if (det_delay_cnt==3'd0) begin
                            det_substate <= S_DET_CLASS;
                        end else
                            det_delay_cnt <= det_delay_cnt - 1'b1;
                        det_en_pipe[0] <= 3'd0;
                    end
                S_DET_CLASS: begin
                        if (det_cls16_i==4'b1111) begin
                            det_cls16_i <= 4'd0;
                            det_c_ad <= det_c_ad + i_istep;
                        end else
                            det_cls16_i <= det_cls16_i + 1'b1;
                            
                        if (det_clsi==det_n_class_m1) begin
                            det_clsi <= 10'd0;
                            if (det_ari==det_n_ar_m1) begin
                                det_ari <= 3'd0;
                                det_cls16_i <= 4'd0;
                                if (det_pxi<i_ickpim_m1) begin
                                    det_pxi <= det_pxi_p1;
                                    det_b_ad <= det_box_addr + det_pxi_p1[9:1];
                                    det_c_ad <= det_cls_addr + det_pxi_p1[9:1];
                                end
                                if (det_xi==i_rc_sx_m1) begin
                                    det_xi <= 10'd0;
                                    det_yi <= det_yi + 1'b1;
                                end else
                                    det_xi <= det_xi + 1'b1;
                            end else begin
                                if (det_ari==3'd3) det_b_ad <= det_b_ad + i_istep;
                                det_ari <= det_ari + 1'b1;
                            end
                            if (det_ari==det_n_ar_m1 && (det_xi==i_rc_sx_m1 && det_yi==i_rc_sy_m1))
                                det_substate <= S_DET_FLUSH;
                            else if (det_ari==det_n_ar_m1 && det_pxi==i_ickpim_m1) begin
                                det_delay_cnt <= 3'd3;
                                det_substate <= S_DET_FLUSH2;
                            end else 
                                det_substate <= S_DET_HEADER;
                        end else
                            det_clsi <= det_clsi + 1'b1;
                            
                        det_en_pipe[0] <= 3'd3;
                        det_data_pipe[0] = {11'd0, det_pxi[0], det_cls16_i[3:0]};
                        mx_raddr <= {32{det_c_ad[MX_ADDR_WIDTH-1:0]}};
                    end
                S_DET_FLUSH: begin
                        det_en_pipe[0] <= 3'd4;
                        det_data_pipe[0] = (det_scale==3'd5) ? 16'd1 : 16'd0;
                        det_delay_cnt <= 3'd3;
                        det_substate <= S_DET_FLUSH2;
                    end
                S_DET_FLUSH2: begin
                        if (det_delay_cnt==3'd0) begin
                            o_det_done <= 1'b1;
                            in_nu_state <= S_INU_IDLE;
                        end else
                            det_delay_cnt <= det_delay_cnt - 1'b1;

                        det_en_pipe[0] <= 3'd0;
                    end
                endcase
                
            end

            reg_dout[7:0] <= mx_dout[integer'(det_data_pipe[2][4:3])*8+:8];
                
            o_det_en <= (det_en_pipe[3]!=3'd0);
            case (det_en_pipe[3])
            // header
            3'd1: begin
                    o_det_data[17:16] <= 2'd0;
                    o_det_data[15:0] <= det_data_pipe[3];
                end
            // box info
            3'd2: begin
                    o_det_data[17:16] <= 2'd1;
                    o_det_data[15:0] <= reg_dout[integer'(det_data_pipe[3][2:0])];
                end
            // class info
            3'd3: begin
                    o_det_data[17:16] <= 2'd2;
                    o_det_data[15:0] <= reg_dout[integer'(det_data_pipe[3][2:0])];
                end
            // finish mark
            3'd4: begin
                    o_det_data[17:16] <= 2'd3;
                    o_det_data[15:0] <= det_data_pipe[3];
                end
            endcase
            
        end
        endcase
        
        
        // conditions here to wait for being ready
        reg_hold_on <= (~o_is_shuttle_idle);
        
        // set address
        
        if (rmode_conv3x3s2i)
            mx_raddr <= {32{add_addr(i_currbase, i_rc_seq[15:2])}};    // video input
        else if (rmode_conv1x1s1 || rmode_dws1 || rmode_ddrupload)
            mx_raddr <= {32{add_addr(i_currbase, i_rc_seq[15:1])}};
`ifndef SMALL_SYS
        else if (rmode_dws2 || rmode_conv3x3s2) begin
            if ((rmode_dws2 && ~i_ch[0]) || (rmode_conv3x3s2 && ~i_ch[3])) begin
                mx_raddr[15:0]  <= {16{add_addr(i_currbase, evenrow_base + r_addr)}};
                mx_raddr[31:16] <= {16{add_addr(i_currbase, evenrow_base + r_addr + two_sx[9:1])}};
            end else begin
                mx_raddr[31:16] <= {16{add_addr(i_currbase, evenrow_base + r_addr)}};
                mx_raddr[15:0]  <= {16{add_addr(i_currbase, evenrow_base + r_addr + two_sx[9:1])}};
            end
        end else if (rmode_dws2_2)
            mx_raddr <= {32{add_addr(i_currbase, i_rc_seq[15:0])}};
`else
        else if (rmode_dws2 || rmode_conv3x3s2)
            mx_raddr <= {32{add_addr(i_currbase, i_rc_seq[15:0])}};
`endif

        // read data from MX memory
        
        // process memory output two clock cycles after the addressing
        // the data output then further processed in one more extra cycle before loading to i_rc_dout
        
        if (i_rc_valid_d[2]) begin
        
            if (rmode_conv3x3s2i)
                v48 <= mx_dout[integer'({i_ch_d[2][1:0], i_rc_seq_d[2][1:0]})*2+:2];
            else if (rmode_conv1x1s1)
                v1616 <= mx_dout[integer'({i_rc_seq_d[2][0]})*16+:16];
            else if (rmode_ddrupload)
                ddr_w_dout <= mx_dout[integer'({i_rc_seq_d[2][0],i_ch_d[2][0]})*8+:8];
`ifndef SMALL_SYS
            else if (rmode_dws1) 
                v_per_receptor <= mx_dout[integer'({i_rc_seq_d[2][0],i_ch_d[2][0]})*8+:8];
            else if (rmode_dws2 || rmode_conv3x3s2) begin
                if ((rmode_dws2 && ~i_ch_d[2][0]) || (rmode_conv3x3s2 && ~i_ch_d[2][3])) begin
                    reg_dout <= {mx_dout[31:24],mx_dout[23:16],mx_dout[7:0],mx_dout[15:8]};    // 4, 3, 2, 1 - see p73 ppt
                end else begin
                    reg_dout <= {mx_dout[15:8],mx_dout[7:0],mx_dout[23:16],mx_dout[31:24]};    // 2, 1, 4, 3
                end
            end else if (rmode_dws2_2)
                for (i=0; i<32; i++) reg_dout[i] <= mx_dout[(i/4) + (i%4)*8];
`else
            else if (rmode_dws1)
                v_per_receptor <= mx_dout[integer'({i_rc_seq_d[2][0],i_ch_d[2][1:0]})*4+:4];
            else if (rmode_dws2)
                for (i=0; i<16; i++) reg_dout[i] <= mx_dout[(i/4)+integer'(i_ch_d[2][0])*4 + (i%4)*8];
            else if (rmode_conv3x3s2)
                for (i=0; i<16; i++) reg_dout[i] <= (i<4) ? mx_dout[i*8+integer'(i_ch_d[2][2:0])] : 0;
`endif
        end
        
        // at the final clock cycle, data are loaded in i_rc_dout array
        if (i_rc_valid_d[3]) begin
            if (rmode_conv3x3s2i) begin
                i_rc_dout[N_RECEPTOR*4-1:4] <= 0;
                // here is where int2floats are to be located
                i_rc_dout[3:0] <= v416;
            end else if (rmode_dws1)
                for (i=0; i<N_RECEPTOR; i=i+1) begin
                    i_rc_dout[i*4] <= v_per_receptor[i];
                    i_rc_dout[i*4+1] <= 0;
                    i_rc_dout[i*4+2] <= 0;
                    i_rc_dout[i*4+3] <= 0;
                end
`ifndef SMALL_SYS
            else if (rmode_conv1x1s1) begin
                    i_rc_dout[N_RECEPTOR*4-1:16] <= 0; 
                    i_rc_dout[15:0] <= v1616;
            end else if (rmode_dws2)
                for (i=0; i<N_RECEPTOR*4; i++) begin
                    i_rc_dout[i] <= reg_dout[(i%4)*N_RECEPTOR+i/4];
                end
            else if (rmode_conv3x3s2)
                for (i=0; i<32; i++) i_rc_dout[i] <= (i<4) ? reg_dout[i * 8 + integer'(i_ch_d[3][2:0])] : 16'd0;
            else if (rmode_dws2_2)
                i_rc_dout <= reg_dout;
`else
            else if (rmode_conv1x1s1)
                i_rc_dout[15:0] <= v1616;
            else if (rmode_dws2 || rmode_conv3x3s2)
                i_rc_dout <= reg_dout;
`endif
        end
        
    
        // W R I T I N G
        
        // note: i_rc_writestart must appear before any ddr_r_valid
        // writing has no state

        // initialize for a new writing
        if (i_rc_writestart) begin
            o_currbase <= i_o_baseaddr; // base for image
            w_rowbase <= 18'd0;    // base for each double-row
            oseq <= 18'd0;
            oseq_last_m1 <= 1'b0;
            o_ch <= 18'd0;
            o_subch <= 3'd0;
            w_addr <= 18'd0;    // address over w_rowbase
            reg_col <= 12'd0;
            reg_col_last_m1 <= 1'b0;
            reg_row <= 12'd0;
        end

        // parameter: i_ostep, 
        // input: i_su_we, i_su_lastchan, i_su_lastf, i_data, i_su_row_odd,i_su_col, 
        // states: oseq, o_currbase, o_ch
        // output: mx_wen, mx_waddr, mx_din, 

        if (i_su_we) begin        
            case (i_o_rc_mode_su)
`ifndef SMALL_SYS            
            W_16_2x16: begin // 1x1,3x3(non-DW) 16 output for stride one 
                    mx_din <= {2{i_su_din}};
    
                    case ({oseq[0]})
                    1'b0: mx_wen <=32'b00000000000000001111111111111111;
                    1'b1: mx_wen <=32'b11111111111111110000000000000000;
                    endcase
                    
                    // on the last clock of each output image
                    if (i_su_lastf) begin
                        oseq <= 18'd0;
                        oseq_last_m1 <= 1'b0;
                        o_currbase <= add_addr(o_currbase, i_ostep);
                        o_ch <= o_ch + 1'b1;
                    end else begin
                        oseq <= oseq + 1'b1;
                        oseq_last_m1 <= (oseq==reg_o_ckpim_m2);
                    end
                    
                    mx_waddr <= {32{add_addr(o_currbase[12:0], oseq[13:1])}};
                end
            W_16_DWS2: begin // 1x1, 3x3 non-DW (16 output) to DW s2
                    case ({i_su_row_odd,i_su_col[0]})
                    2'b00: mx_din <= {i_su_din[15:8],{8{16'h0}},i_su_din[ 7:0],{8{16'h0}}};
                    2'b01: mx_din <= {{8{16'h0}},i_su_din[15:8],{8{16'h0}},i_su_din[ 7:0]};
                    2'b10: mx_din <= {{8{16'h0}},i_su_din[ 7:0],{8{16'h0}},i_su_din[15:8]};
                    2'b11: mx_din <= {i_su_din[ 7:0],{8{16'h0}},i_su_din[15:8],{8{16'h0}}};
                    endcase
                    
                    case ({i_su_row_odd,i_su_col[0]})
                    2'b00: mx_wen <=32'b11111111111111111111111111111111;
                    2'b01: mx_wen <=32'b00000000111111110000000011111111;
                    2'b10: mx_wen <=32'b11111111111111111111111111111111;
                    2'b11: mx_wen <=32'b11111111000000001111111100000000;
                    endcase
                    
                    if (i_su_lastf) begin
                        oseq <= 18'd0;
                        oseq_last_m1 <= 1'b0;
                        o_currbase <= add_addr(o_currbase, i_ostep);
                        o_ch <= o_ch + 1'b1;
                    end else begin
                        if (i_su_col==reg_rc_o_sxm1 && ~reg_rc_o_sxm1[0]) begin // W가 홀수이면 주소를 2 증가
                            oseq <= oseq  + 2'd2;
                        end else begin
	                        oseq_last_m1 <= (oseq==reg_o_ckpim_m2);
                            oseq <= oseq  + 1'b1;
                        end
                    end
                        
                    mx_waddr <= {32{add_addr(o_currbase[12:0], oseq[13:1])}};
                end
`else
            // only for SMALL system
            W_4_2x16: begin // DW 4 output to s1
                    mx_din <= {8{i_su_din[3:0]}};
                    
                    case ({oseq[0],o_ch[1:0]})
                    3'b000: mx_wen <=32'b00000000000000000000000000001111;
                    3'b001: mx_wen <=32'b00000000000000000000000011110000;
                    3'b010: mx_wen <=32'b00000000000000000000111100000000;
                    3'b011: mx_wen <=32'b00000000000000001111000000000000;
                    3'b100: mx_wen <=32'b00000000000011110000000000000000;
                    3'b101: mx_wen <=32'b00000000111100000000000000000000;
                    3'b110: mx_wen <=32'b00001111000000000000000000000000;
                    3'b111: mx_wen <=32'b11110000000000000000000000000000;
                    endcase
                    
                    if (i_su_lastf) begin
                        if (o_ch[1:0]==2'b11) begin
                            o_currbase <= add_addr(o_currbase, i_ostep);
                        end
                        oseq <= 18'd0;
                        o_ch <= o_ch + 1'b1;
                    end else
                        oseq <= oseq + 1'b1;
                        
                    mx_waddr <= {32{add_addr(o_currbase[12:0], oseq[13:1])}};
                end
    
            W_8_DWS2: begin // 1x1, 3x3 non-DW (8 output) to DW s2
                    case ({reg_row[0],reg_col[0]})
                    2'b00: mx_din <= {{24{16'h0}},i_su_din[7:0]};
                    2'b01: mx_din <= {{16{16'h0}},i_su_din[7:0],{ 8{16'h0}}};
                    2'b10: mx_din <= {{ 8{16'h0}},i_su_din[7:0],{16{16'h0}}};
                    2'b11: mx_din <= {            i_su_din[7:0],{24{16'h0}}};
                    endcase
    
                    case ({reg_row[0],reg_col[0]})
                    2'b00: mx_wen <=32'b11111111111111111111111111111111;
                    2'b01: mx_wen <=32'b00000000000000001111111100000000;
                    2'b10: mx_wen <=32'b00000000111111110000000000000000;
                    2'b11: mx_wen <=32'b11111111000000000000000000000000;
                    endcase
                    
                    if (i_su_lastf) begin
                        oseq <= 18'd0;
                        oseq_last_m1 <= 1'b0;
                        o_currbase <= add_addr(o_currbase, i_ostep);
                        o_ch <= o_ch + 1'b1;
                        w_rowbase <= 18'd0;
                        w_addr <= 18'd0;
                        reg_col <= 12'd0;
                        reg_col_last_m1 <= 1'b0;
                        reg_row <= 12'd0;
                    end else begin
                        if (reg_rc_o_sx_onef || reg_col_last_m1) begin //reg_col==reg_rc_o_sxm1) begin
                            if (reg_row[0]) begin
                                w_rowbase <= {(w_addr[11:1] + 1'b1),1'b0};
                                w_addr <= {(w_addr[11:1] + 1'b1),1'b0};
                            end else begin
                                w_addr <= w_rowbase;
                            end
                            reg_row <= reg_row + 1'b1;
                            reg_col <= 12'd0;
                            reg_col_last_m1 <= 1'b0;
                        end else begin
                            w_addr <= w_addr  + 1'b1;
                            reg_col <= reg_col + 1'b1;
                            reg_col_last_m1 <= (reg_col[9:0]==reg_rc_o_sxm2);
                        end
                        oseq <= oseq + 1'b1;
                        oseq_last_m1 <= (oseq==reg_o_ckpim_m2);
                    end
                    
                    mx_waddr <= {32{add_addr(o_currbase, w_addr[13:1])}};
                end
`endif            
    
            W_8_2x16: begin // DW 8 output to s1
                    
                    mx_din <= {4{i_su_din[7:0]}};
                    
                    case ({oseq[0],o_ch[0]})
                    2'b00: mx_wen <=32'b00000000000000000000000011111111;
                    2'b01: mx_wen <=32'b00000000000000001111111100000000;
                    2'b10: mx_wen <=32'b00000000111111110000000000000000;
                    2'b11: mx_wen <=32'b11111111000000000000000000000000;
                    endcase
                    
                    if (i_su_lastf) begin
                        if (o_ch[0]) begin
                            o_currbase <= add_addr(o_currbase, i_ostep);
                        end
                        oseq <= 18'd0;
                        oseq_last_m1 <= 1'b0;
                        o_ch <= o_ch + 1'b1;
                    end else begin
                        oseq <= oseq + 1'b1;
                        oseq_last_m1 <= (oseq==reg_o_ckpim_m2);
                    end
                    
                    mx_waddr <= {32{add_addr(o_currbase[12:0], oseq[13:1])}};
                end
    
            default: mx_wen <= 32'h0;
            endcase
            
            
        end else if (ddr_r_valid) begin
    
            case (i_o_rc_mode)
            W_DDR_S2: begin // DDR to DW s2
                    case ({reg_row[0],reg_col[0]})
                    2'b00: mx_din <= {{24{16'h0}},ddr_r_din};
                    2'b01: mx_din <= {{16{16'h0}},ddr_r_din,{ 8{16'h0}}};
                    2'b10: mx_din <= {{ 8{16'h0}},ddr_r_din,{16{16'h0}}};
                    2'b11: mx_din <= {            ddr_r_din,{24{16'h0}}};
                    endcase
    
                    case ({reg_row[0],reg_col[0]})
                    2'b00: mx_wen <=32'b11111111111111111111111111111111;
                    2'b01: mx_wen <=32'b00000000000000001111111100000000;
                    2'b10: mx_wen <=32'b00000000111111110000000000000000;
                    2'b11: mx_wen <=32'b11111111000000000000000000000000;
                    endcase
                    
                    if (reg_o_ckpim_onef || oseq_last_m1) begin  // oseq>=reg_o_ckpim_m1) begin
                        oseq <= 18'd0;
                        oseq_last_m1 <= 1'b0;
                        o_currbase <= add_addr(o_currbase, i_ostep);
                        o_ch <= o_ch + 1'b1;
                        w_rowbase <= 18'd0;
                        w_addr <= 18'd0;
                        reg_col <= 12'd0;
                        reg_col_last_m1 <= 1'b0;
                        reg_row <= 12'd0;
                    end else begin
                        if (reg_rc_o_sx_onef || reg_col_last_m1) begin //reg_col==reg_rc_o_sxm1) begin
                            if (reg_row[0]) begin
                                w_rowbase <= {(w_addr[11:1] + 1'b1),1'b0};
                                w_addr <= {(w_addr[11:1] + 1'b1),1'b0};
                            end else begin
                                w_addr <= w_rowbase;
                            end
                            reg_row <= reg_row + 1'b1;
                            reg_col <= 12'd0;
                            reg_col_last_m1 <= 1'b0;
                        end else begin
                            w_addr <= w_addr  + 1'b1;
                            reg_col <= reg_col + 1'b1;
                            reg_col_last_m1 <= (reg_col[9:0]==reg_rc_o_sxm2);
                        end
                        oseq <= oseq + 1'b1;
                        oseq_last_m1 <= (oseq>=reg_o_ckpim_m2);
                    end
                    
                    mx_waddr <= {32{add_addr(o_currbase, w_addr[13:1])}};
                end
    
            W_DDR_NONIMAGE: begin // DDR non-image download
    
                    if (~oseq[0] && ~o_ch[0])
                         mx_din <= {384'd0, ddr_r_din};
                    else mx_din <= {4{ddr_r_din}};
                    
                    if (res_enq[2]) begin
                    end
                    
                    case ({oseq[0],o_ch[0]})
                    2'b00: mx_wen <=32'b11111111111111111111111111111111;
                    2'b01: mx_wen <=32'b00000000000000001111111100000000;
                    2'b10: mx_wen <=32'b00000000111111110000000000000000;
                    2'b11: mx_wen <=32'b11111111000000000000000000000000;
                    endcase
                    
                    if (reg_o_ckpim_onef || oseq_last_m1) begin //oseq>=reg_o_ckpim_m1) begin
                        if (o_ch[0]) begin
                            o_currbase <= add_addr(o_currbase, i_ostep);
                        end
                        oseq <= 18'd0;
                        oseq_last_m1 <= 1'b0;
                        o_ch <= o_ch + 1'b1;
                    end else begin
                        oseq <= oseq + 1'b1;
                        oseq_last_m1 <= (oseq>=reg_o_ckpim_m2);
                    end
                    
                    mx_waddr <= {32{add_addr(o_currbase[12:0], oseq[13:1])}};
                end
                
            W_DDR_IMAGE: begin // Write from DDR (Image)
                    // mx = {4x0, 4xB, 4xG, 4xR}
                    mx_din <= {128'h0,{4{ddr_r_din[95:64]}},{4{ddr_r_din[63:32]}},{4{ddr_r_din[31:0]}}};
                    
                    case (oseq[1:0])
                    2'h0: mx_wen <= 32'b00000000000000110000001100000011;
                    2'h1: mx_wen <= 32'b00000000000011000000110000001100;
                    2'h2: mx_wen <= 32'b00000000001100000011000000110000;
                    2'h3: mx_wen <= 32'b00000000110000001100000011000000;
                    endcase
                    oseq <= oseq + 1'b1;
                    oseq_last_m1 <= (oseq==reg_o_ckpim_m2);
                        
                    mx_waddr <= {32{add_addr(o_currbase, oseq[14:2])}};
                end
    
            default: mx_wen <= 32'h0;
            endcase
    
        end else
            mx_wen <= 32'h0;

        // Resnet addition with previous layer data stored in DDR
        if (rmode_resnet) begin
            res_dataq[0] <= ddr_r_din;                                  // t(-1)
            res_addrq[0] <= add_addr(o_currbase[12:0], oseq[13:1]);     // t(-1)
            res_chq[0] <= {oseq[0],o_ch[0],o_subch[2:0]};               // t(-1)
            mx_raddr <= {32{add_addr(o_currbase[12:0], oseq[13:1])}};   // t(-1)
            
            resadder_a <= res_dataq[2][integer'(res_chq[2][2:0])*16+:16];      // t2
            for (i=0; i<32; i++) resadder_b <= mx_dout[integer'(res_chq[2])];              
    
            mx_din <= {32{resadder_c}};                                   // t11

            for (i=0; i<32; i++) mx_wen[i] <= (res_enq[11] && i==integer'(res_chq[11]));              
                
            mx_waddr <= {32{res_addrq[11]}};

            if (ddr_r_valid) begin
                if (o_subch==3'd7) begin
                    if (reg_o_ckpim_onef || oseq_last_m1) begin // oseq>=reg_o_ckpim_m1) begin
                        if (o_ch[0]) o_currbase <= add_addr(o_currbase, i_ostep);
                        oseq <= 18'd0;
                        oseq_last_m1 <= 1'b0;
                        o_ch <= o_ch + 1'b1;
                    end else begin
                        oseq <= oseq + 1'b1;
                        oseq_last_m1 <= (oseq>=reg_o_ckpim_m2);
                    end
                    o_subch <= 3'd0;
                end else
                    o_subch <= o_subch + 1'b1;
            end

            // shift res queues
            res_dataq[2:1] <= res_dataq[1:0];
            res_addrq[11:1] <= res_addrq[10:0]; 
            res_chq[11:1] <= res_chq[10:0];
            res_enq[11:1] <= res_enq[10:0]; 
            res_enq[0] <= (ddr_r_valid && rmode_resnet);
        end

    end
    
    assign ddr_r_rd_en = rmode_resnet ? ddr_r_valid && o_subch==3'd7 : ddr_r_valid;
    assign i_rc_valid = (in_nu_state==S_INU_READING);
    assign ddr_wr = (in_nu_state==S_INU_READING && rmode_ddrupload && ~ddr_w_full);
    assign o_bottommost = o_rc_bottommost;
    
    assign o_ockpim_m1 = reg_ow_ckpim_m1;
    assign o_pop_para = (in_nu_state==S_INU_TRANSIT && ~reg_hold_on && (reg_i_mode[5] || ~i_paraqempty));
    
endmodule
