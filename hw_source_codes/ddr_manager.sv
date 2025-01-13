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
// Create Date: 2021/04/12 06:38:12
// Design Name: 
// Module Name: ddr_manager
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: AXI interface for DDR3 memory (512MB)
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
`timescale 1 ps / 1 ps

module ddr_manager
   (
    input i_req_en,
    input i_req_rw,
    input i_req_flush,
    input i_req_newaddr,
    input [25:0] i_req_addr,
    input [127:0] i_req_din,
    output o_req_avail,
    output o_req_error,
    //
    output o_resp_en,
    input i_resp_wait,
    output o_resp_rdone,
    output [127:0] o_resp_dout,
    output [25:0] o_resp_addr,
    //
    output [31:0] S_AXI_HP0_0_araddr,
    output [1:0] S_AXI_HP0_0_arburst,
    output [3:0] S_AXI_HP0_0_arlen,
    input S_AXI_HP0_0_arready,
    output [2:0] S_AXI_HP0_0_arsize,
    output S_AXI_HP0_0_arvalid,
    output [31:0] S_AXI_HP0_0_awaddr,
    output [1:0] S_AXI_HP0_0_awburst,
    output [3:0] S_AXI_HP0_0_awlen,
    input S_AXI_HP0_0_awready,
    output [2:0] S_AXI_HP0_0_awsize,
    output S_AXI_HP0_0_awvalid,
    output S_AXI_HP0_0_bready,
    input [1:0] S_AXI_HP0_0_bresp,
    input S_AXI_HP0_0_bvalid,
    input [63:0] S_AXI_HP0_0_rdata,
    input S_AXI_HP0_0_rlast,
    output S_AXI_HP0_0_rready,
    input [1:0] S_AXI_HP0_0_rresp,
    input S_AXI_HP0_0_rvalid,
    output [63:0] S_AXI_HP0_0_wdata,
    output S_AXI_HP0_0_wlast,
    input S_AXI_HP0_0_wready,
    output [7:0] S_AXI_HP0_0_wstrb,
    output S_AXI_HP0_0_wvalid,

    output [31:0] S_AXI_HP1_0_araddr,
    output [1:0] S_AXI_HP1_0_arburst,
    output [3:0] S_AXI_HP1_0_arlen,
    input S_AXI_HP1_0_arready,
    output [2:0] S_AXI_HP1_0_arsize,
    output S_AXI_HP1_0_arvalid,
    output [31:0] S_AXI_HP1_0_awaddr,
    output [1:0] S_AXI_HP1_0_awburst,
    output [3:0] S_AXI_HP1_0_awlen,
    input S_AXI_HP1_0_awready,
    output [2:0] S_AXI_HP1_0_awsize,
    output S_AXI_HP1_0_awvalid,
    output S_AXI_HP1_0_bready,
    input [1:0] S_AXI_HP1_0_bresp,
    input S_AXI_HP1_0_bvalid,
    input [63:0] S_AXI_HP1_0_rdata,
    input S_AXI_HP1_0_rlast,
    output S_AXI_HP1_0_rready,
    input [1:0] S_AXI_HP1_0_rresp,
    input S_AXI_HP1_0_rvalid,
    output [63:0] S_AXI_HP1_0_wdata,
    output S_AXI_HP1_0_wlast,
    input S_AXI_HP1_0_wready,
    output [7:0] S_AXI_HP1_0_wstrb,
    output S_AXI_HP1_0_wvalid,

    output [31:0] S_AXI_HP2_0_araddr,
    output [1:0] S_AXI_HP2_0_arburst,
    output [3:0] S_AXI_HP2_0_arlen,
    input S_AXI_HP2_0_arready,
    output [2:0] S_AXI_HP2_0_arsize,
    output S_AXI_HP2_0_arvalid,
    output [31:0] S_AXI_HP2_0_awaddr,
    output [1:0] S_AXI_HP2_0_awburst,
    output [3:0] S_AXI_HP2_0_awlen,
    input S_AXI_HP2_0_awready,
    output [2:0] S_AXI_HP2_0_awsize,
    output S_AXI_HP2_0_awvalid,
    output S_AXI_HP2_0_bready,
    input [1:0] S_AXI_HP2_0_bresp,
    input S_AXI_HP2_0_bvalid,
    input [63:0] S_AXI_HP2_0_rdata,
    input S_AXI_HP2_0_rlast,
    output S_AXI_HP2_0_rready,
    input [1:0] S_AXI_HP2_0_rresp,
    input S_AXI_HP2_0_rvalid,
    output [63:0] S_AXI_HP2_0_wdata,
    output S_AXI_HP2_0_wlast,
    input S_AXI_HP2_0_wready,
    output [7:0] S_AXI_HP2_0_wstrb,
    output S_AXI_HP2_0_wvalid,
   
    input axi_clk,
    input app_clk,
    input axi_resetn,
    input app_resetn
    );
		
    localparam integer AXI_LEN = 4;
    localparam integer PACKET_LEN = (AXI_LEN * 8);

    wire [287:0] ddrrq_din;
    wire [287:0] ddrrq_dout;
    wire ddrrq_rd_en;
    wire ddrrq_wr_en;
    wire ddrrq_full, ddrrq_empty;
    reg [7:0] dcount = 0;
    wire w_is_last;

    wire [287:0] ddrrq_din_2;
    wire [287:0] ddrrq_dout_2;
    wire ddrrq_rd_en_2;
    wire ddrrq_wr_en_2;
    wire ddrrq_full_2, ddrrq_empty_2;
    reg [7:0] dcount_2 = 0;
    wire w_is_last_2;

    wire [287:0] ddrrq_din_3;
    wire [287:0] ddrrq_dout_3;
    wire ddrrq_rd_en_3;
    wire ddrrq_wr_en_3;
    wire ddrrq_full_3, ddrrq_empty_3;
    reg [7:0] dcount_3 = 0;
    wire w_is_last_3;
        
        
    ddr_addr_q ddr_addr_q (
      .clk(axi_clk),      // input wire clk
      .din(ddrrq_din),      // input wire [287 : 0] din
      .wr_en(ddrrq_wr_en),  // input wire wr_en
      .rd_en(ddrrq_rd_en),  // input wire rd_en
      .dout(ddrrq_dout),    // output wire [287 : 0] dout
      .full(ddrrq_full),    // output wire full
      .empty(ddrrq_empty)  // output wire empty
    );
        
    ddr_addr_q ddr_addr_rq_2 (
      .clk(axi_clk),      // input wire clk
      .din(ddrrq_din_2),      // input wire [287 : 0] din
      .wr_en(ddrrq_wr_en_2),  // input wire wr_en
      .rd_en(ddrrq_rd_en_2),  // input wire rd_en
      .dout(ddrrq_dout_2),    // output wire [287 : 0] dout
      .full(ddrrq_full_2),    // output wire full
      .empty(ddrrq_empty_2)  // output wire empty
    );
        
    ddr_addr_q ddr_addr_rq_3 (
      .clk(axi_clk),      // input wire clk
      .din(ddrrq_din_3),      // input wire [287 : 0] din
      .wr_en(ddrrq_wr_en_3),  // input wire wr_en
      .rd_en(ddrrq_rd_en_3),  // input wire rd_en
      .dout(ddrrq_dout_3),    // output wire [287 : 0] dout
      .full(ddrrq_full_3),    // output wire full
      .empty(ddrrq_empty_3)  // output wire empty
    );

    // application signals
    
    //
    reg [1:0] f_p = 0, b_p = 0;
    wire ddri_rd_en;
    reg ddro_wr_en;
    wire [31:0] ddr_ra_addr;
    wire [2:0] ddr_ra_size;
    wire [3:0] ddr_ra_len;
    reg [287:0] ddro_din;
    reg [255:0] ro256a, ro256a_2, ro256a_3, ro256b, ro256b_2, ro256b_3;
    reg [31:0] ro_addra, ro_addra_2, ro_addra_3, ro_addrb, ro_addrb_2, ro_addrb_3;
    
    reg [287:0] ddri_din;
    reg ddri_wr_en;
    wire ddro_rd_en;
    wire [287:0] ddri_dout;
    wire [287:0] ddro_dout;
    wire ddri_full, ddro_full;
    wire ddri_empty;
    reg ddri_read_done;
    wire  ddro_empty;
    reg ro256a_en = 0, ro256a_en_2 = 0, ro256a_en_3 = 0, ro256b_en = 0, ro256b_en_2 = 0, ro256b_en_3 = 0;
    
    (* keep = "true" *) reg all_queue_empty = 1;
    (* keep = "true" *) reg all_queue_empty_app;
    (* keep = "true" *) reg read_mode, read_mode_axi_d;
    (* keep = "true" *) reg read_mode_axi = 0;
    wire axi_read_on, axi_read_on_2, axi_read_on_3;
    wire axi_write_on, axi_write_on_2, axi_write_on_3;
    wire axi_read_last, axi_read_last_2, axi_read_last_3;
    (* keep = "true" *) logic flush_req_app = 1'b0; 
    (* keep = "true" *) logic flush_req_axi; 

    ddr_if_queue ddr_input_q (
      .wr_clk(app_clk),      // input wire wr_clk
      .rd_clk(axi_clk),      // input wire rd_clk
      .din(ddri_din),        // input wire [287 : 0] din
      .wr_en(ddri_wr_en),    // input wire wr_en
      .rd_en(ddri_rd_en),    // input wire rd_en
      .dout(ddri_dout),      // output wire [287 : 0] dout
      .full(),      // output wire full
      .almost_full(ddri_full),      // output wire full
      .empty(ddri_empty)     // output wire empty
    );

    ddr_if_queue ddr_output_q (
      .wr_clk(axi_clk),      // input wire wr_clk
      .rd_clk(app_clk),      // input wire rd_clk
      .din(ddro_din),        // input wire [287 : 0] din
      .wr_en(ddro_wr_en),    // input wire wr_en
      .rd_en(ddro_rd_en),    // input wire rd_en
      .dout(ddro_dout),      // output wire [287 : 0] dout
      .full(),      // output wire full
      .almost_full(ddro_full),  // output wire almost_full
      .empty(ddro_empty)     // output wire empty
    );

    // for debug
//    assign ddrrq_dout32 = ddrrq_dout[31:0];
//    assign ddrrq_dout32_2 = ddrrq_dout_2[31:0];
//    assign ddrrq_dout32_3 = ddrrq_dout_3[31:0];
//    assign ddri_dout32 = ddri_dout[31:0];
//    assign ddri_din32 = ddri_din[31:0];
//    assign ddro_dout32 = ddro_dout[31:0];
//    assign ddro_din32 = ddro_din[31:0];
//    assign ro256a64 = ro256a_2[63:0];
//    assign ro256b64 = ro256b_2[63:0];
//    assign ddro_din64 = ddro_din[95:32];
    
    // distribute read requests over multiple AXI ports
    
    assign S_AXI_HP0_0_arvalid = (f_p==2'd0 && ~ddri_empty && ~ddri_dout[28] && ~ddrrq_full);
    assign S_AXI_HP1_0_arvalid = (f_p==2'd1 && ~ddri_empty && ~ddri_dout[28] && ~ddrrq_full_2);
    assign S_AXI_HP2_0_arvalid = (f_p==2'd2 && ~ddri_empty && ~ddri_dout[28] && ~ddrrq_full_3);
    assign ddr_ra_addr = {ddri_dout[27:0], 4'h0};
    assign ddr_ra_size = 3'b011;
    assign ddr_ra_len = ddri_dout[29] ? AXI_LEN/2 - 1 : AXI_LEN - 1;
    assign ddrrq_din = ddri_dout;
    assign ddrrq_din_2 = ddri_dout;
    assign ddrrq_din_3 = ddri_dout;
    
    // AXI signals for read adress (common for all channels)
    
    assign S_AXI_HP0_0_araddr = {5'd3, ddr_ra_addr[26:0]};  // 0x18xxxxxx
    assign S_AXI_HP0_0_arsize = ddr_ra_size;
    assign S_AXI_HP0_0_arlen = ddr_ra_len;
    assign S_AXI_HP0_0_arburst = 2'd1;
    
    assign S_AXI_HP1_0_araddr = {5'd3, ddr_ra_addr[26:0]};
    assign S_AXI_HP1_0_arsize = ddr_ra_size;
    assign S_AXI_HP1_0_arlen = ddr_ra_len;
    assign S_AXI_HP1_0_arburst = 2'd1;
    
    assign S_AXI_HP2_0_araddr = {5'd3, ddr_ra_addr[26:0]};
    assign S_AXI_HP2_0_arsize = ddr_ra_size;
    assign S_AXI_HP2_0_arlen = ddr_ra_len;
    assign S_AXI_HP2_0_arburst = 2'd1;

    // implement AXI read data
    
    // proceed only when there is a request and output buffer is available
    assign S_AXI_HP0_0_rready = (~ddrrq_empty   && ~ro256a_en);     // ~ro256a_en: ro256a is empty
    assign S_AXI_HP1_0_rready = (~ddrrq_empty_2 && ~ro256a_en_2);
    assign S_AXI_HP2_0_rready = (~ddrrq_empty_3 && ~ro256a_en_3);
    // pop request
    assign ddrrq_rd_en   = (~ddrrq_empty   && ((axi_read_on   && S_AXI_HP0_0_rlast) || w_is_last));
    assign ddrrq_rd_en_2 = (~ddrrq_empty_2 && ((axi_read_on_2 && S_AXI_HP1_0_rlast) || w_is_last_2));
    assign ddrrq_rd_en_3 = (~ddrrq_empty_3 && ((axi_read_on_3 && S_AXI_HP2_0_rlast) || w_is_last_3));

    
    // distribute write requests over multiple AXI ports
    
    assign S_AXI_HP0_0_awvalid = (f_p==2'd0 && ~ddri_empty && ddri_dout[28] && ~ddrrq_full);    // ddri_dout[28]: write mode
    assign S_AXI_HP1_0_awvalid = (f_p==2'd1 && ~ddri_empty && ddri_dout[28] && ~ddrrq_full_2);
    assign S_AXI_HP2_0_awvalid = (f_p==2'd2 && ~ddri_empty && ddri_dout[28] && ~ddrrq_full_3);
    assign ddrrq_wr_en   = (S_AXI_HP0_0_arready && S_AXI_HP0_0_arvalid) || (S_AXI_HP0_0_awready && S_AXI_HP0_0_awvalid);
    assign ddrrq_wr_en_2 = (S_AXI_HP1_0_arready && S_AXI_HP1_0_arvalid) || (S_AXI_HP1_0_awready && S_AXI_HP1_0_awvalid);
    assign ddrrq_wr_en_3 = (S_AXI_HP2_0_arready && S_AXI_HP2_0_arvalid) || (S_AXI_HP2_0_awready && S_AXI_HP2_0_awvalid);
    assign ddri_rd_en = ddrrq_wr_en || ddrrq_wr_en_2 || ddrrq_wr_en_3;
    
    // AXI signals for write adress (common for all channels)
    
    assign S_AXI_HP0_0_awaddr = {5'd3, ddr_ra_addr[26:0]};
    assign S_AXI_HP0_0_awsize = ddr_ra_size;
    assign S_AXI_HP0_0_awlen = ddr_ra_len;
    assign S_AXI_HP0_0_awburst = 2'd1;
    assign S_AXI_HP0_0_wstrb = 8'hff;
    assign S_AXI_HP0_0_wlast = w_is_last;
    assign S_AXI_HP0_0_bready = 1'b1;

    assign S_AXI_HP1_0_awaddr = {5'd3, ddr_ra_addr[26:0]};
    assign S_AXI_HP1_0_awsize = ddr_ra_size;
    assign S_AXI_HP1_0_awlen = ddr_ra_len;
    assign S_AXI_HP1_0_awburst = 2'd1;
    assign S_AXI_HP1_0_wstrb = 8'hff;
    assign S_AXI_HP1_0_wlast = w_is_last_2;
    assign S_AXI_HP1_0_bready = 1'b1;
    
    assign S_AXI_HP2_0_awaddr = {5'd3, ddr_ra_addr[26:0]};
    assign S_AXI_HP2_0_awsize = ddr_ra_size;
    assign S_AXI_HP2_0_awlen = ddr_ra_len;
    assign S_AXI_HP2_0_awburst = 2'd1;
    assign S_AXI_HP2_0_wstrb = 8'hff;
    assign S_AXI_HP2_0_wlast = w_is_last_3;
    assign S_AXI_HP2_0_bready = 1'b1;

    // implement AXI write data
    
    // proceed only when there is a request and output buffer is available
    assign S_AXI_HP0_0_wvalid = (~ddrrq_empty && ddrrq_dout[28]);
    assign S_AXI_HP1_0_wvalid = (~ddrrq_empty_2 && ddrrq_dout_2[28]);
    assign S_AXI_HP2_0_wvalid = (~ddrrq_empty_3 && ddrrq_dout_3[28]);
    assign w_is_last   = ddrrq_dout[28]   && (ddrrq_dout[29]   ? (dcount>=(AXI_LEN/2 - 1))   : (dcount>=(AXI_LEN - 1)));
    assign w_is_last_2 = ddrrq_dout_2[28] && (ddrrq_dout_2[29] ? (dcount_2>=(AXI_LEN/2 - 1)) : (dcount_2>=(AXI_LEN - 1)));
    assign w_is_last_3 = ddrrq_dout_3[28] && (ddrrq_dout_3[29] ? (dcount_3>=(AXI_LEN/2 - 1)) : (dcount_3>=(AXI_LEN - 1)));
    
    assign S_AXI_HP0_0_wdata = (dcount[1:0]==2'h0) ? ddrrq_dout[95:32] :
                               (dcount[1:0]==2'h1) ? ddrrq_dout[159:96] :
                               (dcount[1:0]==2'h2) ? ddrrq_dout[223:160] :
                               ddrrq_dout[287:224];
    
    assign S_AXI_HP1_0_wdata = (dcount_2[1:0]==2'h0) ? ddrrq_dout_2[95:32] :
                               (dcount_2[1:0]==2'h1) ? ddrrq_dout_2[159:96] :
                               (dcount_2[1:0]==2'h2) ? ddrrq_dout_2[223:160] :
                               ddrrq_dout_2[287:224];
    
    assign S_AXI_HP2_0_wdata = (dcount_3[1:0]==2'h0) ? ddrrq_dout_3[95:32] :
                               (dcount_3[1:0]==2'h1) ? ddrrq_dout_3[159:96] :
                               (dcount_3[1:0]==2'h2) ? ddrrq_dout_3[223:160] :
                               ddrrq_dout_3[287:224];

    // for debug
    assign axi_read_on   = (S_AXI_HP0_0_rready && S_AXI_HP0_0_rvalid);
    assign axi_read_on_2 = (S_AXI_HP1_0_rready && S_AXI_HP1_0_rvalid);
    assign axi_read_on_3 = (S_AXI_HP2_0_rready && S_AXI_HP2_0_rvalid);
    assign axi_read_last = S_AXI_HP0_0_rlast;
    assign axi_read_last_2 = S_AXI_HP1_0_rlast;
    assign axi_read_last_3 = S_AXI_HP2_0_rlast;
    assign axi_write_on   = (S_AXI_HP0_0_wready && S_AXI_HP0_0_wvalid);
    assign axi_write_on_2 = (S_AXI_HP1_0_wready && S_AXI_HP1_0_wvalid);
    assign axi_write_on_3 = (S_AXI_HP2_0_wready && S_AXI_HP2_0_wvalid);    
    
    always @ (posedge axi_clk) begin

        read_mode_axi <= read_mode;
        read_mode_axi_d <= read_mode_axi;
        flush_req_axi <= flush_req_app;
        all_queue_empty <= (flush_req_axi && (ddri_empty && ddrrq_empty && ddrrq_empty_2 && ddrrq_empty_3 && dcount==8'd0 && dcount_2==8'd0 && dcount_3==8'd0));

        if (~axi_resetn || (read_mode_axi!=read_mode_axi_d)) begin
        
            f_p <= 2'd0;
            b_p <= 2'd0;
            
        end else begin
        
            // advance forward pointer
            case (f_p)
            2'd0: if (ddrrq_wr_en)   f_p <= 2'd1;
            2'd1: if (ddrrq_wr_en_2) f_p <= 2'd2;
            2'd2: if (ddrrq_wr_en_3) f_p <= 2'd0;
            endcase
            
            // on reading new data, put in ro256a buffer shifting 64-bit groups
            if (axi_read_on) begin
                ro256a[255:192] <= S_AXI_HP0_0_rdata;
                ro256a[191:0] <= ro256a[255:64];
                // on last data, move data to ro256b if it is empty
                // if not, keep ro256a until ro256b becomes empty
                if (S_AXI_HP0_0_rlast) begin
                    ro_addra <= ddrrq_dout[31:0];
                    ro256a_en <= 'b1;
                end
            end
            // do the same for the second AXI port
            if (axi_read_on_2) begin
                ro256a_2[255:192] <= S_AXI_HP1_0_rdata;
                ro256a_2[191:0] <= ro256a_2[255:64];
                if (S_AXI_HP1_0_rlast) begin
                    ro_addra_2 <= ddrrq_dout_2[31:0];
                    ro256a_en_2 <= 'b1;
                end
            end
            // do the same for the third AXI port
            if (axi_read_on_3) begin
                ro256a_3[255:192] <= S_AXI_HP2_0_rdata;
                ro256a_3[191:0] <= ro256a_3[255:64];
                if (S_AXI_HP2_0_rlast) begin
                    ro_addra_3 <= ddrrq_dout_3[31:0];
                    ro256a_en_3 <= 'b1;
                end
            end
            // if ro256b available(empty), move ro256a to it
            if (~ro256b_en && ro256a_en) begin
                ro_addrb <= ro_addra;
                ro256b <= ro256a;
                ro256b_en <= 'b1;
                ro256a_en <= 'b0;
            end
            if (~ro256b_en_2 && ro256a_en_2) begin
                ro_addrb_2 <= ro_addra_2;
                ro256b_2 <= ro256a_2;
                ro256b_en_2 <= 'b1;
                ro256a_en_2 <= 'b0;
            end
            if (~ro256b_en_3 && ro256a_en_3) begin
                ro_addrb_3 <= ro_addra_3;
                ro256b_3 <= ro256a_3;
                ro256b_en_3 <= 'b1;
                ro256a_en_3 <= 'b0;
            end
            
            // push read data to output queue and advance b_p
            
            if (~ddro_full) begin   // ~ddro_full is expected in the case of writing
                case (b_p)
                2'd0: begin
                        if (ro256b_en || (w_is_last && axi_write_on)) b_p <= 2'd1;
                        if (ro256b_en) begin
                            ddro_din[31:0] <= ro_addrb;
                            ddro_din[287:32] <= ro_addrb[29] ? {128'd0, ro256b[255:128]} : ro256b;
                            ro256b_en <= 'b0; 
                        end
                    end
                2'd1: begin
                        if (ro256b_en_2 || (w_is_last_2 && axi_write_on_2)) b_p <= 2'd2;
                        if (ro256b_en_2) begin
                            ddro_din[31:0] <= ro_addrb_2;
                            ddro_din[287:32] <= ro_addrb_2[29] ? {128'd0, ro256b_2[255:128]} : ro256b_2;
                            ro256b_en_2 <= 'b0; 
                        end
                    end
                2'd2: begin
                        if (ro256b_en_3 || (w_is_last_3 && axi_write_on_3)) b_p <= 2'd0;
                        if (ro256b_en_3) begin
                            ddro_din[31:0] <= ro_addrb_3;
                            ddro_din[287:32] <= ro_addrb_3[29] ? {128'd0, ro256b_3[255:128]} : ro256b_3;
                            ro256b_en_3 <= 'b0; 
                        end
                    end
                endcase
            end
            ddro_wr_en <=  ~ddro_full && ((b_p==2'd0 && ro256b_en) || (b_p==2'd1 && ro256b_en_2) || (b_p==2'd2 && ro256b_en_3));

            if (axi_write_on)   dcount <= w_is_last ? 8'h0 :     dcount + 1'b1;
            if (axi_write_on_2) dcount_2 <= w_is_last_2 ? 8'h0 : dcount_2 + 1'b1;
            if (axi_write_on_3) dcount_3 <= w_is_last_3 ? 8'h0 : dcount_3 + 1'b1;
            
        end
    end
    

    // application side
    // ================
    
    localparam [3:0] S_REQ_IDLE = 4'd0,
            S_REQ_R_ODD = 4'd1,
            S_REQ_R_EVEN = 4'd2,
            S_REQ_W_ODD = 4'd3,
            S_REQ_W_EVEN = 4'd4,
            S_REQ_FLUSH = 4'd5;

    localparam [1:0] S_RESP_IDLE = 2'd0,
            S_RESP_ODD = 2'd1;
            
    reg [3:0] req_state = S_REQ_IDLE;
    reg [1:0] resp_state = S_RESP_IDLE;
    
    logic req_flush_d, reg_req_error = 0;
    logic [25:0] pendaddr, keep_outaddr;
    logic [25:0] recent_req_addr, recent_resp_addr;
    logic [127:0] pend128, keep_out128;

    assign ddro_rd_en = (~ddro_empty && resp_state==S_RESP_IDLE && ~i_resp_wait);
    assign o_resp_en = ddro_rd_en || (resp_state==S_RESP_ODD && ~i_resp_wait);
    assign o_resp_rdone = (ddri_read_done);
    assign o_resp_dout = (resp_state==S_RESP_IDLE) ? ddro_dout[159:32] : keep_out128;
    assign o_resp_addr = (resp_state==S_RESP_IDLE) ? ddro_dout[25:0] : keep_outaddr;
    assign o_req_avail = (~ddri_full && req_state!=S_REQ_FLUSH);
    assign o_req_error = reg_req_error;

    always @ (posedge app_clk) begin
        if (~app_resetn) begin
            req_state <= S_REQ_IDLE;
            resp_state <= S_RESP_IDLE;
            
        end else begin
            req_flush_d <= i_req_flush;
            all_queue_empty_app <= all_queue_empty;
            if (i_req_en) read_mode <= i_req_rw;
            if (i_req_en) recent_req_addr <= i_req_addr;
            if (o_resp_en) recent_resp_addr <= o_resp_addr;
            ddri_read_done <= (recent_req_addr==recent_resp_addr);
            
            // attribute bits: {0 0 half/full write/read}
        
            case (req_state)
            S_REQ_IDLE: begin
                    // on new request
                    ddri_wr_en <= (i_req_en && i_req_newaddr);
                    // i_req_en is ignored
                    if (i_req_flush && ~req_flush_d) begin
                        flush_req_app <= 1'b1;
                        req_state <= S_REQ_FLUSH;
                    end else if (i_req_en) begin
                        if (i_req_newaddr) begin
                            if (i_req_rw)
                                // half read
                                ddri_din <= {256'd0, 4'b0010, 2'h0, i_req_addr};
                            else
                                // half write
                                ddri_din <= {128'd0, i_req_din,  4'b0011, 2'h0, i_req_addr};
                        end else begin
                            pendaddr <= i_req_addr;
                            // dispatch base on read or write
                            if (i_req_rw) begin // on read request
                                req_state <= S_REQ_R_ODD;
                            end else begin  // on write request
                                pend128 <= i_req_din;
                                req_state <= S_REQ_W_ODD;
                            end
                        end
                    end
                end
            S_REQ_R_ODD: begin  // read request pending
                    ddri_wr_en <= i_req_en || (i_req_flush && ~req_flush_d);
                    // fulll read
                    if (i_req_en && i_req_rw)
                        ddri_din <= {256'd0, 4'b0000, 2'h0, pendaddr};
                    // half read
                    else if ((i_req_en && ~i_req_rw) ||                             // on write request
                        (i_req_flush && ~req_flush_d)) begin           // on flush request
                        ddri_din <= {256'd0, 4'b0010, 2'h0, pendaddr};
                    end 
                    // state transition
                    if (i_req_flush && ~req_flush_d) begin   // on flush request
                        flush_req_app <= 1'b1;
                        req_state <= S_REQ_FLUSH;
                    end else if (i_req_en)
                        req_state <= i_req_rw ? S_REQ_IDLE : S_REQ_W_ODD;
                end
            S_REQ_W_ODD: begin
                    ddri_wr_en <= i_req_en || (i_req_flush && ~req_flush_d);
                    // full write
                    if (i_req_en && ~i_req_rw) // on new read request with consecutive address
                        ddri_din <= {i_req_din, pend128, 4'b0001, 2'h0, pendaddr};
                    // half write
                    else if ((i_req_en && i_req_rw) ||                              // on write request
                        (i_req_flush && ~req_flush_d)) begin           // on flush request
                        ddri_din <= {128'd0, pend128, 4'b0011, 2'h0, pendaddr};
                    end 
                    // state transition
                    if (i_req_flush && ~req_flush_d) begin   // on flush request
                        flush_req_app <= 1'b1;
                        req_state <= S_REQ_FLUSH;
                    end else if (i_req_en)
                        req_state <= ~i_req_rw ? S_REQ_IDLE : S_REQ_R_ODD;
                end
            S_REQ_FLUSH: begin
                    ddri_wr_en <= 'b0;
                    if (~i_req_flush && all_queue_empty_app && ddro_empty) begin
                        flush_req_app <= 1'b0;
                        req_state <= S_REQ_IDLE;
                    end
                end
            endcase
            
            case (resp_state)
            S_RESP_IDLE: begin
                    if (ddro_rd_en && ~ddro_dout[29]) begin
                        keep_out128 <= ddro_dout[287:160];
                        keep_outaddr <= ddro_dout[25:0] + 'b1;
                        resp_state <= S_RESP_ODD;
                    end
                end
            S_RESP_ODD: begin
                    if (~i_resp_wait) resp_state <= S_RESP_IDLE;
                end
            endcase
        
        end
    end
        
        
endmodule
