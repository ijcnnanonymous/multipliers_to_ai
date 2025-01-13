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
// Create Date: 2021/03/21 15:22:20
// Design Name: 
// Module Name: my_half_adder
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description:It adds two high-precision integer numbers into a half-precision floating point number. 
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

// total pipeline delay: 6
// t_local (t_global)

module my_half_adder (
        input [31:0] i_in1,     // t0 (t13)
        input [31:0] i_in2,     // t0 (t13)
        output [15:0] o_added,  // t6 (t19), 
        //
        input i_en,             // t17
        input i_firstf,         // t17
        input [1:0] i_relu,     // t16
        //
        input clk
    );
    
    logic [31:0] reg_i_in1, reg_i_in2;
    logic signed [32:0] reg_i_added;
    logic [28:0] reg_i_added2, gaped_29;
    logic [34:0] reg_relued, gap_sum;
    logic [52:0] sig_div49_53;
    
    // t3 -> t6 (t16 -> t19)
    conv_s2716_half conv_int2half (
        .clk(clk),
        .i_int((i_relu==2'b10) ? gaped_29 : reg_i_added2),  // t3 (t16), or t9 (t22)
        .o_half(o_added)                                    // t6 (t19), or t12 (t25)
    );

    // delay: 3
    mul_s34x18 div49 (
      .CLK(clk),  // input wire CLK
      .A(gap_sum),      // input wire [34 : 0] A                    t5 (t18)
      .B(18'd171196),      // input wire [17 : 0] B,  2^23 / 49      
      .P(sig_div49_53)      // output wire [52 : 0] P               t8 (t21)
    );
    
    always @ (posedge clk) begin

        // t0 -> t1 (t13 -> t14)
        reg_i_in1 <= i_in1;
        reg_i_in2 <= i_in2;
        // t1 -> t2 (t14 -> t15)
        reg_i_added <= $signed($signed({reg_i_in1[31],reg_i_in1}) + $signed(reg_i_in2));
        // check overflow, t2 -> t3 (t15 -> t16)
        if (~reg_i_added[32]     && reg_i_added[31:28]!=4'b0000) reg_i_added2 <= 29'h0fffffff;
        else if (reg_i_added[32] && reg_i_added[31:28]!=4'b1111) reg_i_added2 <= 29'h10000000;
        else reg_i_added2 <= reg_i_added[28:0];
        
        // in the case og GAP
        
        //  t3 -> t4 (t16 -> t17)
        if (reg_i_added2[28])
            reg_relued <= 35'd0;
        else if (reg_i_added2[27:16]>=12'd6)
            reg_relued <= 35'h60000;
        else
            reg_relued <= {{6{reg_i_added2[28]}}, reg_i_added2};
        // t4 -> t5 (t17 -> t18)
        if (i_en) begin
            if (i_firstf)
                 gap_sum <= reg_relued;
            else gap_sum <= gap_sum + reg_relued;
        end
        // t8 (t21)
        gaped_29 <= (sig_div49_53[52:51]==2'b01) ? 29'hfffffff : (sig_div49_53[52:51]==2'b10) ? 29'h10000000 : sig_div49_53[51:23];

    end
    
endmodule
