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
// Create Date: 2021/03/19 06:20:13
// Design Name: 
// Module Name: du_tip
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: DU Tip accumulates partial sums for computing netsum inputs.
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

// base timing: t7

module du_tip # (
`ifdef SMALL_SYS 
            parameter N_MNET_WIDTH = 11
`else
            parameter N_MNET_WIDTH = 11
`endif
		) (
        input [27:0] i_partsum,     // t7
        output [31:0] o_netsum,     // t11
        //
        input [15:0] i_nsum_raddr,  // t4
        input i_firstchan,          // t6
        input i_nsum_en,            // t9
        input i_lastchan,           // t9
        input [15:0] i_nsum_waddr,  // t9
        input clk
    );

    logic [31:0] sig_adder_i2, reg_adder_i2;
    logic signed [32:0] reg_added;
    logic [31:0] reg_added2;
    logic [31:0] reg_out;
    logic mnet_we;
    logic [N_MNET_WIDTH-1:0] mnet_waddr, mnet_raddr;
    
    assign mnet_waddr = i_nsum_waddr[N_MNET_WIDTH-1:0]; // t9
    assign mnet_raddr = i_nsum_raddr[N_MNET_WIDTH-1:0]; // t4
    assign mnet_we = i_nsum_en & ~i_lastchan;   // t9
    assign o_netsum = reg_out;  // t10
    
    mem_net mnet (
      .clka(clk),    // input wire clka
      .wea(mnet_we),      // input wire [0 : 0] wea
      .addra(mnet_waddr),  // input wire [10 : 0] addra
      .dina(reg_added2),    // input wire [31 : 0] dina
      .clkb(clk),    // input wire clkb
      .addrb(mnet_raddr),  // input wire [10 : 0] addrb
      .doutb(sig_adder_i2)  // output wire [31 : 0] doutb
    );
    
    always @ (posedge clk) begin
        // initialize the summation 
        reg_adder_i2 <= (i_firstchan) ? 32'd0 : sig_adder_i2;   // t6
        // summation, t7
        reg_added <= $signed($signed({reg_adder_i2[31],reg_adder_i2}) + $signed(i_partsum));
        // handle overflow, t8
        if (reg_added[32:31]==2'b01) reg_added2 <= 32'h7fffffff;
        else if (reg_added[32:31]==2'b10) reg_added2 <= 32'h80000000;
        else reg_added2 <= reg_added[31:0];
        // output the net sum
        reg_out <= (i_lastchan) ? reg_added2 : 32'd0;  // t9
    end
    
endmodule
