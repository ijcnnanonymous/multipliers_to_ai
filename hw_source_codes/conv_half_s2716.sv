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
// Create Date: 2021/06/25 10:07:40
// Design Name: 
// Module Name: conv_half_s2716
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: This code converts half-precision floating-point numbers into high-resolution integer numbers.
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


module conv_half_s2716(
    input clk,
    input [15:0] i_half,    // t0
    output [27:0] o_int     // t3
    );

    logic [1:0] reg_sign;
    logic [4:0] reg_exponent;
    logic [9:0] reg_fraction;
    logic [27:0] reg_ival, reg_ival2;
    logic zero_fraction;
    
    assign o_int = reg_ival2;   // t3

    always @ (posedge clk) begin
    
        // t0
        reg_sign[0] <= i_half[15];
        reg_exponent <= i_half[14:10];
        reg_fraction <= i_half[9:0];
    
        // t1
        reg_sign[1] <= reg_sign[0];
        zero_fraction <= (reg_exponent==5'd0 && reg_fraction[9:8]==2'd0);
        case (reg_exponent)
        5'd0 : reg_ival <= {25'd0, 1'b0, reg_fraction[9:8]};
        5'd1 : reg_ival <= {25'd0, 1'b1, reg_fraction[9:8]};
        5'd2 : reg_ival <= {24'd0, 1'b1, reg_fraction[9:7]};
        5'd3 : reg_ival <= {23'd0, 1'b1, reg_fraction[9:6]};
        5'd4 : reg_ival <= {22'd0, 1'b1, reg_fraction[9:5]};
        5'd5 : reg_ival <= {21'd0, 1'b1, reg_fraction[9:4]};
        5'd6 : reg_ival <= {20'd0, 1'b1, reg_fraction[9:3]};
        5'd7 : reg_ival <= {19'd0, 1'b1, reg_fraction[9:2]};
        5'd8 : reg_ival <= {18'd0, 1'b1, reg_fraction[9:1]};
        5'd9 : reg_ival <= {17'd0, 1'b1, reg_fraction[9:0]};
        5'd10: reg_ival <= {16'd0, 1'b1, reg_fraction[9:0], 1'd0};
        5'd11: reg_ival <= {15'd0, 1'b1, reg_fraction[9:0], 2'd0};
        5'd12: reg_ival <= {14'd0, 1'b1, reg_fraction[9:0], 3'd0};
        5'd13: reg_ival <= {13'd0, 1'b1, reg_fraction[9:0], 4'd0};
        5'd14: reg_ival <= {12'd0, 1'b1, reg_fraction[9:0], 5'd0};
        5'd15: reg_ival <= {11'd0, 1'b1, reg_fraction[9:0], 6'd0};
        5'd16: reg_ival <= {10'd0, 1'b1, reg_fraction[9:0], 7'd0};
        5'd17: reg_ival <= { 9'd0, 1'b1, reg_fraction[9:0], 8'd0};
        5'd18: reg_ival <= { 8'd0, 1'b1, reg_fraction[9:0], 9'd0};
        5'd19: reg_ival <= { 7'd0, 1'b1, reg_fraction[9:0],10'd0};
        5'd20: reg_ival <= { 6'd0, 1'b1, reg_fraction[9:0],11'd0};
        5'd21: reg_ival <= { 5'd0, 1'b1, reg_fraction[9:0],12'd0};
        5'd22: reg_ival <= { 4'd0, 1'b1, reg_fraction[9:0],13'd0};
        5'd23: reg_ival <= { 3'd0, 1'b1, reg_fraction[9:0],14'd0};
        5'd24: reg_ival <= { 2'd0, 1'b1, reg_fraction[9:0],15'd0};
        5'd25: reg_ival <= { 1'd0, 1'b1, reg_fraction[9:0],16'd0};
        default: reg_ival <= 28'h7ffffff;
        endcase
        
        // t2
        if (zero_fraction) reg_ival2 <= 28'd0;
        else
            reg_ival2 <= (reg_sign[1]) ? -reg_ival : reg_ival;
    end
    
endmodule
