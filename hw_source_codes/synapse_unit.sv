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
// Create Date: 2021/03/07 16:04:57
// Design Name: 
// Module Name: synapse_unit
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: Synap Unit comtains 128 multipliers and computes weighted input values. 
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


module synapse_unit # (
`ifdef SMALL_SYS 
        parameter N_MUL = 128
`else
        parameter N_MUL = 256
`endif
    )(
        input [N_MUL-1:0][15:0] i_nu_data,
        output [N_MUL-1:0][23:0] o_products,
        //
        input [5:0] i_mode,
        input i_para_en,
        input [127:0] i_para128,
        input i_next,
        input i_pop_para,
        output o_paraqfull,
        output o_paraqempty,
        output o_bias_en,
        output [N_MUL*2-1:0] o_bias,
        //
        input i_reset,
        input clk
    );
    
    logic rst_q;
    logic [N_MUL*16-1:0] para_din = 0;
    logic [N_MUL*16-1:0] para_dout, reg_para_dout;
    logic [N_MUL-1:0][15:0] para_dout_16;
    logic [N_MUL-1:0][23:0] prod; 
    logic paraq_hl_wr_en, paraq_hl_rd_en;
    logic paraq_full;
    logic paraq_empty;
    logic para_out_valid = 0;
    logic [4:0] n_shift_m1, data_count_l;
    logic [4:0] shift_i = 0, data_count_h;
    logic is_bias, reg_new_bias;
    logic [N_MUL*2-1:0] reg_bias; // max 8 or 16 biases
    logic para_error = 1'b0;
    logic reg_para_en;
    logic  [127:0] reg_para128;
    logic [15:0] token16;

    genvar idx;
    integer i;
    
`ifndef SMALL_SYS 
    paraq paraq_3 (
        .clk(clk),      // input wire clk
        .srst(rst_q),    // input wire srst
        .din(para_din[1023+3072:0+3072]),      // input wire [1023 : 0] din
        .wr_en(paraq_hl_wr_en),  // input wire wr_en
        .rd_en(paraq_hl_rd_en),  // input wire rd_en
        .dout(para_dout[1023+3072:0+3072]),    // output wire [1023 : 0] dout
        .full(),    // output wire full
        .empty(),  // output wire empty
        .data_count()  // output wire [4 : 0] data_count
    );
    
    paraq paraq_2 (
        .clk(clk),      // input wire clk
        .srst(rst_q),    // input wire srst
        .din(para_din[1023+2048:0+2048]),      // input wire [1023 : 0] din
        .wr_en(paraq_hl_wr_en),  // input wire wr_en
        .rd_en(paraq_hl_rd_en),  // input wire rd_en
        .dout(para_dout[1023+2048:0+2048]),    // output wire [1023 : 0] dout
        .full(),    // output wire full
        .empty(),  // output wire empty
        .data_count()  // output wire [4 : 0] data_count
    );
`endif
    
    paraq paraq_1 (
        .clk(clk),      // input wire clk
        .srst(rst_q),    // input wire srst
        .din(para_din[1023+1024:0+1024]),      // input wire [1023 : 0] din
        .wr_en(paraq_hl_wr_en),  // input wire wr_en
        .rd_en(paraq_hl_rd_en),  // input wire rd_en
        .dout(para_dout[1023+1024:0+1024]),    // output wire [1023 : 0] dout
        .full(),    // output wire full
        .empty(),  // output wire empty
        .data_count(data_count_h)  // output wire [4 : 0] data_count
    );
    
    paraq paraq_0 (
        .clk(clk),      // input wire clk
        .srst(rst_q),    // input wire srst
        .din(para_din[1023:0]),      // input wire [1023 : 0] din
        .wr_en(paraq_hl_wr_en),  // input wire wr_en
        .rd_en(paraq_hl_rd_en),  // input wire rd_en
        .dout(para_dout[1023:0]),    // output wire [1023 : 0] dout
        .full(paraq_full),    // output wire full
        .empty(paraq_empty),  // output wire empty
        .data_count(data_count_l)  // output wire [4 : 0] data_count
    );
    
    generate
        for (idx = 0; idx < N_MUL; idx = idx + 1) begin : gen_mul
            mul_half2int wx_mul (
                .clk(clk),
                .i_half1(i_nu_data[idx]),
                .i_half2(para_dout_16[idx]),
                .o_int(prod[idx])
            );
        end
    endgenerate
    
    assign token16 = i_para128[15:0];
    assign o_paraqfull = paraq_full;
    assign o_paraqempty = (paraq_empty || para_out_valid);
    assign rst_q = i_reset;
    assign o_products = prod;
    assign o_bias_en = reg_new_bias;
    assign o_bias = reg_bias;
    
    always @ (posedge clk) begin
    
        if (i_reset) begin
        
            if (~paraq_empty || para_out_valid) para_error <= 1'b1;
            shift_i <= 5'd0;
            para_out_valid <= 1'b0;
            paraq_hl_wr_en <= 1'b0;
        
        end else begin
        
            reg_para_en <= i_para_en;
            reg_para128 <= i_para128;
            is_bias <= (token16==16'hf800);
        
            // shift parameter input array in 128-bit unit
            if (reg_para_en) begin
                for (i=0; i<(N_MUL/8-1); i++) begin
                    para_din[(i+1)*128+:128] <= (shift_i==5'd0) ? 128'd0 : para_din[(i)*128+:128];
                end
                para_din[127:0] <= reg_para128;
                
                if (shift_i==n_shift_m1 || is_bias) shift_i <= 5'd0;
                else                                shift_i <= shift_i + 1'b1;
            end


`ifdef SMALL_SYS
            case (i_mode)
            6'b001000:                      n_shift_m1 <= 5'd15;
            6'b000101, 6'b010101:           n_shift_m1 <= 5'd8;
            6'b000110,6'b000111,6'b010111:  n_shift_m1 <= 5'd4;
            endcase
`else
            case (i_mode)
            6'b001000:                      n_shift_m1 <= 5'd31;
            6'b000101, 6'b010101:           n_shift_m1 <= 5'd17;
            6'b000110,6'b000111,6'b010111:  n_shift_m1 <= 5'd8;
            endcase
`endif
            
            paraq_hl_wr_en <= (reg_para_en && shift_i==n_shift_m1 && ~is_bias);
            reg_new_bias <= (reg_para_en && is_bias);
            if (reg_para_en && is_bias) begin
                reg_bias <= para_din[N_MUL*2-1:0];
            end
            
            if (i_next) para_dout_16 <= reg_para_dout;
            if (~paraq_empty && i_pop_para) reg_para_dout <= para_dout;
            
            if (~paraq_empty && i_pop_para) para_out_valid <= 1'b1;
            else if (i_next)                para_out_valid <= 1'b0;

            paraq_hl_rd_en <= i_pop_para;

        end
    end

    
endmodule
