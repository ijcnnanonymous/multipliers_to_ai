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
// Create Date: 2021/06/25 17:21:12
// Design Name: 
// Module Name: halfadder
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description:It adds two half-pprecision floating-point numbers resulting in a half-pprecision floating-point number.   
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

module halfadder(
        input [15:0] i_half1, // t0
        input [15:0] i_half2, // t0
        output [15:0] o_half_added,  // t8
        input clk
    );
    
    logic [27:0] sig_i_in1_28, sig_i_in2_28;
    logic [31:0] sig_i_in1, sig_i_in2;
    logic signed [32:0] reg_i_added;
    logic [28:0] reg_i_added2;
    
    assign sig_i_in1 = {{4{sig_i_in1_28[27]}}, sig_i_in1_28};
    assign sig_i_in2 = {{4{sig_i_in2_28[27]}}, sig_i_in2_28};
    
    // t0 -> t3
    conv_half_s2716 conv_half2int1 (
        .clk(clk),
        .i_half(i_half1),   // t0
        .o_int(sig_i_in1_28)   // t3
    );
    
    // t0 -> t3
    conv_half_s2716 conv_half2int2 (
        .clk(clk),
        .i_half(i_half2),   // t0
        .o_int(sig_i_in2_28)   // t3
    );
    
    always @ (posedge clk) begin
        // t3 -> t4
        reg_i_added <= $signed($signed({sig_i_in1[31],sig_i_in1}) + $signed(sig_i_in2));
        // check overflow, t4 -> t5
        if (~reg_i_added[32]     && reg_i_added[31:28]!=4'b0000) reg_i_added2 <= 29'h0fffffff;
        else if (reg_i_added[32] && reg_i_added[31:28]!=4'b1111) reg_i_added2 <= 29'h10000000;
        else reg_i_added2 <= reg_i_added[28:0];
    end
    
    // t5 -> t8
    conv_s2716_half conv_int2half (
        .clk(clk),
        .i_int(reg_i_added2),   // t5
        .o_half(o_half_added)   // t8
    );
    
endmodule
