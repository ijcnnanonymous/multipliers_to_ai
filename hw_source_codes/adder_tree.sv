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
// Create Date: 2021/03/11 07:48:32
// Design Name: 
// Module Name: adder_tree
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: This is adder tree for Dendrite Unit.
//          It addes 128 inputs in parallel using a tree of adders.
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


module adder_tree(
        input [127:0][23:0] i_products, // t3
        output [7:0][27:0] o_netsum,    // t7
        input clk
    );
    
    logic [127:0][23:0] adders_0;
    logic [ 63:0][24:0] adders_1;
    logic [ 31:0][25:0] adders_2;
    logic [ 15:0][26:0] adders_3;
    logic [  7:0][27:0] adders_4;
    integer i;
    
    assign adders_0 = i_products;   // t3
    assign o_netsum = adders_4;     // t7
    
    always @ (posedge clk) begin
        
        // t3 -> t4
        for (i=0; i<64; i++) begin
            adders_1[i] <= $signed(adders_0[i*2]) + $signed(adders_0[i*2+1]); 
        end
        
        // t4 -> t5
        for (i=0; i<32; i++) begin
            adders_2[i] <= $signed(adders_1[i*2]) + $signed(adders_1[i*2+1]); 
        end
        
        // t5 -> t6
        for (i=0; i<16; i++) begin
            adders_3[i] <= $signed(adders_2[i*2]) + $signed(adders_2[i*2+1]); 
        end
        
        // t6 -> t7
        for (i=0; i<8; i++) begin
            adders_4[i] <= $signed(adders_3[i*2]) + $signed(adders_3[i*2+1]); 
        end
        
    end
    
endmodule
