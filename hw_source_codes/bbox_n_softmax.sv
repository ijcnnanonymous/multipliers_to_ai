`timescale 1ns / 1ps
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
// Create Date: 2021/07/05 14:05:24
// Design Name: 
// Module Name: bbox_n_softmax
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: This code computes Softmax.
//              Bound box computation parts have been removed for a copyright issue.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//      For studying how it works, please subscribe to YouTube @fpgalover. 
//      For efficient custom AI hardware design, please contact the author.
//	Don't waste your time and ask us for help.
//////////////////////////////////////////////////////////////////////////////////

module bbox_n_softmax (
//		// Object detection bbox
//        input i_en,
//        input [17:0] i_din,
//        input [10:0] i_th,          // 11.10
//        output o_en,
//        output [95:0] o_bbox,
//        output reg o_bbox_done = 1'b0,
//        input i_det_reset,
		// Softmax
        input i_sm_en,
        input [15:0] i_sm_half,
        output o_sm_en,
        output [10:0] o_sm_top1_class,	
        output [10:0] o_sm_top1_score,	// 11.10
        input i_sm_restart,
        //
        input [10:0] i_n_classm1,
		input [1:0] i_relu,
		// multi-scale function
		input multiscale,
		input [31:0] scale_offset,
        input clk
    );

	// SSD BBox
	// ========
    
    enum bit [5:0] {S_BOX_IDLE, S_BOX_Z0, S_BOX_Z1, S_BOX_Z2, S_BOX_Z3, S_BOX_P1, S_BOX_P2, S_BOX_P3, S_BOX_P4, S_BOX_P5, S_BOX_P6, S_BOX_P7,
                    S_WAIT_CLASS, S_CLASS_1, S_BOX_DONE} ssd_box_state = S_BOX_IDLE;

    logic [24:0] int_s2414i, int_s2414o, half_test_s2414;
    logic [15:0] coeff, sig_header_out;
    logic [40:0] int_s4028;
    logic [28:0] int_s2816;
    logic [27:0] int_s2716;
    logic [18:0] sig_flag_header, reg_flag_header, reg_din;
    logic [2:0] sig_tab, sig_tab_delayed, sig_tab_delayed2;
    logic [15:0] reg_mul_out, sig_z0z1_out, reg_z2z3_score_out;
    logic [2:0] det_scale, det_ai;
    logic [4:0] det_yi, det_xi;
    logic [2:0] delay_cnt;
    logic [23:0] sig_w_h;
    logic [31:0] sig_gridinfo;
    logic [11:0] sig_w, sig_h;
    logic [15:0] sig_cx, sig_cy, sig_dx, sig_dy;
    logic [15:0] box_mul_a, box_mul_b, box_mul_a2, box_mul_b2;
    logic [16:0] box_cx, box_cy;
    logic [31:0] box_mul_c, box_mul_c_adj, box_mul_c2, box_mul_c_adj2;
    logic [15:0] sig_exp_in, sig_exp_out, delayed_exp, sig_add_out, sig_recip_out, reg_float;
    logic [15:0] sig_Z0, sig_Z1;
    logic signed [15:0] sig_z1mz3, sig_z1pz3;
    logic [10:0] sig_classi;
    logic [15:0] sig_P0, sig_P1, sig_P2, sig_P3;
    logic [15:0] sig_sx, sig_sy, sig_ex, sig_ey;
    logic reg_o_en = 0;
    logic [15:0] reg_prob = 0;
    logic [15:0] reg_class = 0;
    logic [15:0] reg_sx = 0, reg_sy = 0, reg_ex = 0, reg_ey = 0;
    logic reg_last;

    // you also need to change the contents of the tables
    localparam SCR_W = 16'h03E7; // 999
    localparam SCR_H = 16'h03E7; // 999

	// Softmax
	// =======
    
    enum bit [3:0] {S_SM_IDLE, S_SM_MAX_IN, S_DELAY, S_SM_EXP, S_SM_EXP_FLUSH, S_SM_SOFTMAX_DONE} sm_state = S_SM_IDLE;
    
    logic [27:0] sm_int_in, sm_maxq_dout, sm_max_in = 0, sm_reg_x, sm_sig_exp_int, sm_top1_exp_int, sm_sig_top1_score_int;
    logic [17:0] sm_top1_exp_int_18;
    logic signed [27:0] sm_sig_expsum_int;
    logic signed [27:0] sm_reg_x_m_max_int, sm_1over_expsum_int;
    logic [17:0] sm_1over_expsum_int_18;
    logic [15:0] sm_sig_exp_half, sm_top1_exp_half, sm_sig_expsum_half, sm_1over_expsum_half, sm_sig_top1_score_half;
    logic [2:0] sm_en_train_in;
    logic [29:0] sm_en_train_exp;
    logic [6:0] sm_flush_count;
    logic sm_maxq_empty, sm_exp_en = 0;
    logic [10:0] sm_class_count_in = 0, sm_class_count_exp = 0, sm_class_count_expsum = 0, sm_top1_class;
    logic [3:0] sm_delay_count;
    logic sm_reg_sm_o_en = 1'b0;
    logic [10:0] sm_reg_top1_score, sm_reg_top1_class;
    logic [35:0] sm_top1_score_36_24;
    
    logic [10:0] reg_scale;
    logic [9:0] reg_offx, reg_offy;
    
    conv_s2716real_half int2half (  // delay = 3
        .clk(clk),
        .i_int((i_relu==2'b11)?sm_reg_x_m_max_int:int_s2716),  // t7
        .o_half(sig_exp_in) // t10
    );

    half_exp fp_exp (     // delay = 13
      .aclk(clk),                       // input wire aclk
      .s_axis_a_tvalid(1'b1),           // input wire s_axis_a_tvalid
      .s_axis_a_tdata(sig_exp_in),      // input wire [15 : 0] s_axis_a_tdata,          t10
      .m_axis_result_tvalid(),          // output wire m_axis_result_tvalid
      .m_axis_result_tdata(sig_exp_out)     // output wire [15 : 0] m_axis_result_tdata,    t23
    );
    assign sm_sig_exp_half = sig_exp_out;
    
    D_SSD_3 delay3 (        // w = 16, delay = 15
        .CLK(clk),
        .D(sig_exp_out),    // t23
        .Q(delayed_exp)     // t38
    );

    half_add fp_add (   // delay = 11
      .aclk(clk),                       // input wire aclk
      .s_axis_a_tvalid(1'b1),           // input wire s_axis_a_tvalid
      .s_axis_a_tdata(sig_exp_out),     // input wire [15 : 0] s_axis_a_tdata           t23
      .s_axis_b_tvalid(1'b1),           // input wire s_axis_b_tvalid
      .s_axis_b_tdata(16'h3c00),        // input wire [15 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(),          // output wire m_axis_result_tvalid
      .m_axis_result_tdata(sig_add_out) // output wire [15 : 0] m_axis_result_tdata     t34
    );
    
    half_recip fp_recip (   // delay = 4
      .aclk(clk),                       // input wire aclk
      .s_axis_a_tvalid(1'b1),           // input wire s_axis_a_tvalid
      .s_axis_a_tdata((i_relu==2'b11)?sm_sig_expsum_half:sig_add_out),     // input wire [15 : 0] s_axis_a_tdata           t34, t_expsum(24)
      .m_axis_result_tvalid(),          // output wire m_axis_result_tvalid
      .m_axis_result_tdata(sig_recip_out) // output wire [15 : 0] m_axis_result_tdata   t38, t_expsum(28)
    );
    assign sm_1over_expsum_half = sig_recip_out;    // t_expsum(28)


	// Softmax
	// =======
    
    assign o_sm_en = sm_reg_sm_o_en;
    assign o_sm_top1_class = sm_reg_top1_class;
    assign o_sm_top1_score = sm_reg_top1_score;

    
    // convert input in half format to integer
    
    conv_half_s2716 h2i_in (
        .clk(clk),
        .i_half(i_sm_half),    // t0
        .o_int(sm_int_in)      // t3
    );
    
    // collect data for max computation

    sm_maxq softmax_maxq (
      .clk(clk),      // input wire clk
      .din(sm_int_in),      // input wire [27 : 0] din
      .wr_en(sm_en_train_in[2]),  // input wire wr_en
      .rd_en(sm_exp_en),  // input wire rd_en
      .dout(sm_maxq_dout),    // output wire [27 : 0] dout
      .srst(i_sm_restart),
      .full(),    // output wire full
      .empty(sm_maxq_empty)  // output wire empty
    );

    // convert exponential in half format to an integer
    
    conv_half_s2716 h2i_exp (
        .clk(clk),
        .i_half(sm_sig_exp_half),                                          // t_exp(17)
        .o_int(sm_sig_exp_int)                                             // t_exp(20)
    );
    
    conv_s2716real_half i2h_exp_expsum (
        .clk(clk),
        .i_int(sm_sig_expsum_int),                                          // t_expsum(21)
        .o_half(sm_sig_expsum_half)                                         // t_expsum(24)
    );
    
    conv_half_s2716 h2i_1over (
        .clk(clk),
        .i_half(sm_1over_expsum_half),      // t_expsum(28)
        .o_int(sm_1over_expsum_int)         // t_expsum(31)
    );

    mul_18x18 mul_18x18 (
      .CLK(clk),  // input wire CLK
      .A(sm_top1_exp_int_18),      // input wire [17 : 0] A  18.12
      .B(sm_1over_expsum_int_18),      // input wire [17 : 0] B  18.12
      .P(sm_top1_score_36_24)      // output wire [35 : 0] P  36.24
    );
    assign sm_top1_exp_int_18 = (sm_top1_exp_int[27:22]!=6'd0) ? 18'h3ffff : sm_top1_exp_int[21:4];
    assign sm_1over_expsum_int_18 = (sm_1over_expsum_int[27:22]!=6'd0) ? 18'h3ffff : sm_1over_expsum_int[21:4];


    
    always @ (posedge clk) begin
        // timing of sm_en_train_in[0] is t1
        sm_en_train_in[2:1] <= sm_en_train_in[1:0];
        sm_en_train_in[0] <= i_sm_en; // t0
        // timing of sm_en_train_exp[0] is t_exp(1)
        sm_en_train_exp[29:1] <= sm_en_train_exp[28:0];
        sm_en_train_exp[0] <= sm_exp_en;                                          // t_exp(0)
        
        sm_reg_x <= sm_maxq_dout;                                                 // t_exp(0)
        sm_reg_x_m_max_int <= $signed($signed(sm_reg_x) - $signed(sm_max_in));   // t_exp(1)
        
        if (sm_en_train_exp[20]) begin                                              // t_exp(21)
            sm_sig_expsum_int <= sm_sig_expsum_int + sm_sig_exp_int;
            if (sm_class_count_expsum==11'd0) begin                                 // initial condition
                sm_top1_exp_int <= sm_sig_exp_int;
                sm_top1_class <= 11'd0;
            end else if (sm_sig_exp_int>sm_top1_exp_int) begin                      // determin top1 class
                sm_top1_exp_int <= sm_sig_exp_int;
                sm_top1_class <= sm_class_count_expsum;
            end
            sm_class_count_expsum <= sm_class_count_expsum + 1'b1;
        end

        if (i_sm_restart) begin
            sm_exp_en <= 1'b0;
            sm_class_count_in <= 11'd0;
            sm_state <= S_SM_MAX_IN;
        end
        
        case (sm_state)
        S_SM_IDLE, S_SM_MAX_IN: begin
                if (sm_en_train_in[2]) begin
                    if (sm_class_count_in==11'd0 || ($signed(sm_int_in)>$signed(sm_max_in)))
                        sm_max_in <= sm_int_in;
                        
                    if (sm_class_count_in==i_n_classm1) begin
                        sm_delay_count <= 4'd0;
                        sm_state <= S_DELAY;
                    end else
                        sm_class_count_in <= sm_class_count_in + 1'b1;
                end
                sm_reg_sm_o_en <= 1'b0;
            end
        S_DELAY: begin
                if (sm_delay_count==4'd4) begin
                    sm_exp_en <= 1'b1;                         // t_exp(-1)
                    sm_class_count_exp <= 11'd0;
                    sm_sig_expsum_int <= 28'd0;
                    sm_class_count_expsum <= 11'd0;
                    sm_state <= S_SM_EXP;
                end else
                    sm_delay_count <= sm_delay_count + 1'b1;
            end
        S_SM_EXP: begin                                         // t_exp(0)
                if (sm_class_count_exp==i_n_classm1) begin
                    sm_exp_en <= 1'b0; 
                    sm_flush_count <= 7'd65;
                    sm_state <= S_SM_EXP_FLUSH;
                end else
                    sm_class_count_exp <= sm_class_count_exp + 1'b1;
            end
        S_SM_EXP_FLUSH:
            if (sm_flush_count==7'd0) begin    // at this point, top1 results are available
                sm_state <= S_SM_SOFTMAX_DONE;
            end else
                sm_flush_count <= sm_flush_count - 1'b1;
        S_SM_SOFTMAX_DONE: begin
                sm_reg_sm_o_en <= 1'b1;
                sm_reg_top1_class <= sm_top1_class;
                sm_reg_top1_score <= sm_top1_score_36_24[24:14];
                sm_state <= S_SM_IDLE;
            end
        endcase
    end
    
endmodule
