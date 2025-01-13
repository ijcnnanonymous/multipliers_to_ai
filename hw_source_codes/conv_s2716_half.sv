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
// Create Date: 2021/03/13 21:16:24
// Design Name: 
// Module Name: conv_s2716_half
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: This code converts high-precision integer numbers into half-precision floating numbers. 
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

// total pipeline delay: 3

module conv_s2716_half (
    input clk,
    input [28:0] i_int,
    output reg [15:0] o_half
    );
    
    reg [1:0] reg_sign;
    reg [27:0] reg_data;
    reg [5:0] reg_exp;
    reg [9:0] reg_frac;
    
    always @ (posedge clk) begin
    
        // t0
        reg_sign[0] <= i_int[28];
        reg_data <= (i_int[28]) ? -(i_int[27:0]) : i_int[27:0];
    
        // at t1
        reg_sign[1] <= reg_sign[0];
        if (reg_data[27]) begin             reg_exp <= 6'd26; reg_frac <= reg_data[26:17];
        end else if (reg_data[26]) begin    reg_exp <= 6'd25; reg_frac <= reg_data[25:16];
        end else if (reg_data[25]) begin    reg_exp <= 6'd24; reg_frac <= reg_data[24:15];
        end else if (reg_data[24]) begin    reg_exp <= 6'd23; reg_frac <= reg_data[23:14];
        end else if (reg_data[23]) begin    reg_exp <= 6'd22; reg_frac <= reg_data[22:13];
        end else if (reg_data[22]) begin    reg_exp <= 6'd21; reg_frac <= reg_data[21:12];
        end else if (reg_data[21]) begin    reg_exp <= 6'd20; reg_frac <= reg_data[20:11];
        end else if (reg_data[20]) begin    reg_exp <= 6'd19; reg_frac <= reg_data[19:10];
        end else if (reg_data[19]) begin    reg_exp <= 6'd18; reg_frac <= reg_data[18: 9];
        end else if (reg_data[18]) begin    reg_exp <= 6'd17; reg_frac <= reg_data[17: 8];
        end else if (reg_data[17]) begin    reg_exp <= 6'd16; reg_frac <= reg_data[16: 7];
        end else if (reg_data[16]) begin    reg_exp <= 6'd15; reg_frac <= reg_data[15: 6];
        end else if (reg_data[15]) begin    reg_exp <= 6'd14; reg_frac <= reg_data[14: 5];
        end else if (reg_data[14]) begin    reg_exp <= 6'd13; reg_frac <= reg_data[13: 4];
        end else if (reg_data[13]) begin    reg_exp <= 6'd12; reg_frac <= reg_data[12: 3];
        end else if (reg_data[12]) begin    reg_exp <= 6'd11; reg_frac <= reg_data[11: 2];
        end else if (reg_data[11]) begin    reg_exp <= 6'd10; reg_frac <= reg_data[10: 1];
        end else if (reg_data[10]) begin    reg_exp <= 6'd9 ; reg_frac <= reg_data[ 9: 0];
        end else if (reg_data[ 9]) begin    reg_exp <= 6'd8 ; reg_frac <= {reg_data[ 8: 0], 1'h0};
        end else if (reg_data[ 8]) begin    reg_exp <= 6'd7 ; reg_frac <= {reg_data[ 7: 0], 2'h0};
        end else if (reg_data[ 7]) begin    reg_exp <= 6'd6 ; reg_frac <= {reg_data[ 6: 0], 3'h0};
        end else if (reg_data[ 6]) begin    reg_exp <= 6'd5 ; reg_frac <= {reg_data[ 5: 0], 4'h0};
        end else if (reg_data[ 5]) begin    reg_exp <= 6'd4 ; reg_frac <= {reg_data[ 4: 0], 5'h0};
        end else if (reg_data[ 4]) begin    reg_exp <= 6'd3 ; reg_frac <= {reg_data[ 3: 0], 6'h0};
        end else if (reg_data[ 3]) begin    reg_exp <= 6'd2 ; reg_frac <= {reg_data[ 2: 0], 7'h0};
        end else if (reg_data[ 2]) begin    reg_exp <= 6'd1 ; reg_frac <= {reg_data[ 1: 0], 8'h0};
        end else begin                      reg_exp <= 6'd32 ; reg_frac <= {reg_data[ 0: 0], 9'h0};
        end
        
        o_half[15] <= (reg_exp[5] && ~reg_frac[9]) ? 1'b0 : reg_sign[1];
        o_half[14:10] <= reg_exp[4:0];
        o_half[9:0] <= reg_frac;
    end
    
endmodule
