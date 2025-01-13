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
// Create Date: 2021/03/20 11:18:31
// Design Name: 
// Module Name: soma_unit
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description:Soma Unit computing bias and activation functions 
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

// overall delay: 8

module soma_unit # (
`ifdef SMALL_SYS 
        parameter N_SUOUT = 8
`else
        parameter N_SUOUT = 16
`endif
    )(
        input [N_SUOUT-1:0][31:0] i_netsum, // t13
        output [N_SUOUT-1:0][15:0] o_suout, // t21 ot t27
        //
        input i_bias_en,
        input [N_SUOUT*32-1:0] i_bias,
        input i_load_bias,                  // t12
        output o_biasqfull,
        //
        input [1:0] i_relu,                 // t16
        input i_firstf,                     // t17
        input i_o_en,                       // t17
        input i_reset,
        input clk
    );
    
    logic [N_SUOUT-1:0][31:0] bias_dout_32;
    logic [N_SUOUT-1:0][15:0] sig_biased, reg_biased, reg_relued = 0, sig_gaped;
    logic biasq_error = 0;
    logic [N_SUOUT*32-1:0] bias_dout;
    logic biasq_full, biasq_empty;
    genvar idx;
    integer i;

    biasq biasq (
        .clk(clk),      // input wire clk
        .srst(i_reset),    // input wire srst
        .din(i_bias),      // input wire [255 : 0] din
        .wr_en(i_bias_en),  // input wire wr_en
        .rd_en(i_load_bias),  // input wire rd_en
        .dout(bias_dout),    // output wire [255 : 0] dout
        .full(biasq_full),    // output wire full
        .empty(biasq_empty),  // output wire empty
        .data_count()  // output wire [4 : 0] data_count
    );
    
    generate
        for (idx = 0; idx < N_SUOUT; idx = idx + 1) begin : gen_biasadder
            // t13 -> t19
            my_half_adder biasadder (
                .i_in1(i_netsum[idx]),      // t13
                .i_in2(bias_dout_32[idx]),  // t13
                .o_added(sig_biased[idx]),  // t19, t25
                //
                .i_en(i_o_en),          // t17
                .i_firstf(i_firstf),    // t17
                .i_relu(i_relu),        // t16
                //
                .clk(clk)
            );
        end
    endgenerate
    
    assign o_biasqfull = biasq_full;
    assign o_suout = reg_relued;    // t21 ot t27 (GAP)

    always @ (posedge clk) begin
    
        // for bias queue
        if (i_bias_en) begin
            if (biasq_full) biasq_error <= 1'b1;
        end
        
        // t12 -> t13
        if (i_load_bias) begin
            bias_dout_32 <= bias_dout;
            if (biasq_empty) biasq_error <= 1'b1;
        end
        
        // for soma computation
        
        // t19 -> t20, or t25 -> t26 (GAP)
        reg_biased <= sig_biased;
        
        // t20 -> t21, or t26 -> t27 (GAP)
        for (i=0; i<N_SUOUT; i++) begin
            case (i_relu)
            2'b00, 2'b10, 2'b11:   // no relu or softmax(no relu)
                reg_relued[i] <= reg_biased[i];
            2'b01: begin
                    if (reg_biased[i][15])
                        reg_relued[i] <= 16'h0;
                    else if (reg_biased[i]>16'h4600)
                        reg_relued[i] <= 16'h4600;
                    else
                        reg_relued[i] <= reg_biased[i];
                end
            endcase
        end
    end
    
    
endmodule
