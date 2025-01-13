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
// Create Date: 2020/11/26 12:57:42
// Design Name: 
// Module Name: pixel2half
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: Convert input pixel data into half-precision floating point numbers
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//      For explanations of the source code, please subscribe to YouTube @fpgalover. 
//      For efficient custom AI hardware design, please contact the author.
//	Don't waste your time and ask us for help.

//				sign			
//100000000	0	00000000	-128	1	128	-1	15
//11111111	1	00000001	-127	1	127	-0.9921875	14
//11111110	2	00000010	-126	1	126	-0.984375	14
//11111101	3	00000011	-125	1	125	-0.9765625	14
//11111100	4	00000100	-124	1	124	-0.96875	14
//11111011	5	00000101	-123	1	123	-0.9609375	14
//11111010	6	00000110	-122	1	122	-0.953125	14
//11111001	7	00000111	-121	1	121	-0.9453125	14
//11111000	8	00001000	-120	1	120	-0.9375	14
//11110111	9	00001001	-119	1	119	-0.9296875	14
//11110110	10	00001010	-118	1	118	-0.921875	14

//10000111	121	01111001	-7	1	7	-0.0546875	10
//10000110	122	01111010	-6	1	6	-0.046875	10
//10000101	123	01111011	-5	1	5	-0.0390625	10
//10000100	124	01111100	-4	1	4	-0.03125	10
//10000011	125	01111101	-3	1	3	-0.0234375	9
//10000010	126	01111110	-2	1	2	-0.015625	9
//10000001	127	01111111	-1	1	1	-0.0078125	8

//	128	10000000	0	0	0	0	0
//	129	10000001	1	0	1	0.0078125	8
//	130	10000010	2	0	2	0.015625	9
//	131	10000011	3	0	3	0.0234375	9
//	132	10000100	4	0	4	0.03125	10
//	133	10000101	5	0	5	0.0390625	10
//	134	10000110	6	0	6	0.046875	10
//	135	10000111	7	0	7	0.0546875	10
//	136	10001000	8	0	8	0.0625	11

//	244	11110100	116	0	116	0.90625	14
//	245	11110101	117	0	117	0.9140625	14
//	246	11110110	118	0	118	0.921875	14
//	247	11110111	119	0	119	0.9296875	14
//	248	11111000	120	0	120	0.9375	14
//	249	11111001	121	0	121	0.9453125	14
//	250	11111010	122	0	122	0.953125	14
//	251	11111011	123	0	123	0.9609375	14
//	252	11111100	124	0	124	0.96875	14
//	253	11111101	125	0	125	0.9765625	14
//	254	11111110	126	0	126	0.984375	14
//	255	11111111	127	0	127	0.9921875	14

//////////////////////////////////////////////////////////////////////////////////


module pixel2half(
    input clk,
    input [7:0] i_pixel,
    output reg [15:0] o_half
    );
    
    logic [7:0] comptwo;
    
    assign comptwo = (i_pixel ^ 8'hff) + 1'b1;
    
    always @ (*) begin
        if (i_pixel[7]) begin
            if (i_pixel[6])         o_half <= {1'b0, 5'd14, i_pixel[5:0], 4'h0};
            else if (i_pixel[5])    o_half <= {1'b0, 5'd13, i_pixel[4:0], 5'h0};
            else if (i_pixel[4])    o_half <= {1'b0, 5'd12, i_pixel[3:0], 6'h0};
            else if (i_pixel[3])    o_half <= {1'b0, 5'd11, i_pixel[2:0], 7'h0};
            else if (i_pixel[2])    o_half <= {1'b0, 5'd10, i_pixel[1:0], 8'h0};
            else if (i_pixel[1])    o_half <= {1'b0, 5'd9,  i_pixel[0],   9'h0};
            else if (i_pixel[0])    o_half <= {1'b0, 5'd8,               10'h0};
            else                    o_half <= 16'h0;
        end else begin
            if (comptwo[6])         o_half <= {1'b1, 5'd14, comptwo[5:0], 4'h0};
            else if (comptwo[5])    o_half <= {1'b1, 5'd13, comptwo[4:0], 5'h0};
            else if (comptwo[4])    o_half <= {1'b1, 5'd12, comptwo[3:0], 6'h0};
            else if (comptwo[3])    o_half <= {1'b1, 5'd11, comptwo[2:0], 7'h0};
            else if (comptwo[2])    o_half <= {1'b1, 5'd10, comptwo[1:0], 8'h0};
            else if (comptwo[1])    o_half <= {1'b1, 5'd9,  comptwo[0]  , 9'h0};
            else if (comptwo[0])    o_half <= {1'b1, 5'd8,               10'h0};
            else                    o_half <= {1'b1, 5'd15,              10'h0};
        end
    end
    
endmodule
