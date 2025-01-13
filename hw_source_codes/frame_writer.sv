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
// Create Date: 2023/08/13 14:58:57
// Design Name: 
// Module Name: frame_writer
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description:It interfaces DDR memory for storing frame input images from HDMI input source. 
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


module frame_writer #
(
    parameter BUFF_TH = 11'd700,
    parameter AXI_SIZE = 11'd4
)(
    input [23:0] data_in,
    input de,
    input eol,
    output reg ready,
    input [31:0] data_in_32,
    input de_32,
    input hcount32_0,
    input sof,
    input [15:0] hr_base,
    input [15:0] lr_base,
    input [3:0] window_type,
    //
    output [31:0] S_AXI_araddr,
    output [1:0] S_AXI_arburst,
    output [3:0] S_AXI_arlen,
    input S_AXI_arready,
    output [2:0] S_AXI_arsize,
    output S_AXI_arvalid,
    output [31:0] S_AXI_awaddr,
    output [1:0] S_AXI_awburst,
    output [3:0] S_AXI_awlen,
    input S_AXI_awready,
    output [2:0] S_AXI_awsize,
    output reg S_AXI_awvalid = 1'b0,
    output S_AXI_bready,
    input [1:0] S_AXI_bresp,
    input S_AXI_bvalid,
    input [63:0] S_AXI_rdata,
    input S_AXI_rlast,
    output S_AXI_rready,
    input [1:0] S_AXI_rresp,
    input S_AXI_rvalid,
    output [63:0] S_AXI_wdata,
    output S_AXI_wlast,
    input S_AXI_wready,
    output [7:0] S_AXI_wstrb,
    output reg S_AXI_wvalid = 1'b0,
    //
    output reg [1:0] is_busy,
    output reg [11:0] debug_state = 8'd0,
    //
    input rst,
    input clk
    );
    
    logic [11:0] hr_count, lr_count;
    logic hr_empty, hr_full, lr_empty, lr_full, hr_wr_en, hr_rd_en, lr_rd_en;
    logic lr_wr_en;
    logic [64:0] reg_hr_din, sig_hr_dout, sig_lr_dout;
    logic [64:0] reg_lr_din;
    logic [31:0] reg_hr_awaddr = 32'h1b600000, reg_lr_awaddr = 32'h1fb00000;
    logic [1:0] traffic_mode = 2'd0;
    logic [3:0] packet_left;
    
    logic [41:0] scan_din, scan_dout;
    logic scan_wr, snan_rd, scan_full, scan_empty;
    logic [3:0] vseq = 4'd0, hseq = 4'd0;
    
    logic [11:0] r_hsum12, g_hsum12, b_hsum12, b_vsum12, r_vsum12_ini, g_vsum12_ini, b_vsum12_ini;
    logic [13:0] r_vsum14_add, g_vsum14_add, b_vsum14_add;
    logic [13:0] r_vsum14, g_vsum14, b_vsum14;
    
    logic [3:0] hseq_d1, hseq_d2;
    logic de_d1, de_d2, h_oddcycle = 0, v_oddcycle = 0;
    logic [2:0] out_en = 3'd0;
    logic [4:0] h_oddcycle_d = 4'd0;
    logic [7:0] vseq_d2 = 8'd0;
    logic [2:0] begin_type = 3'd1;
    logic [3:0] h_cycle_end, v_cycle_end;
    logic [3:0] curr_wtype = 0;
    logic [23:0] rgb_adj;
    
    logic [17:0] color_divider;
    logic [31:0] r_div_out, g_div_out, b_div_out;


    scan_mem scan_mem (
      .clk(clk),      // input wire clk
      .srst(sof),    // input wire srst
      .din({r_vsum14, g_vsum14, b_vsum14}),      // input wire [35 : 0] din
      .wr_en(scan_wr),  // input wire wr_en
      .rd_en(snan_rd),  // input wire rd_en
      .dout(scan_dout),    // output wire [35 : 0] dout
      .full(scan_full),    // output wire full
      .empty(scan_empty)  // output wire empty
    );

    logic [63:0] oe_din, even_dout;
    logic even_wr, even_rd, even_full, even_empty;
    logic [1:0] oe_seq = 2'd0;
    
    even_queue even_queue (
      .clk(clk),      // input wire clk
      .srst(sof),    // input wire srst
      .din(oe_din),      // input wire [63 : 0] din
      .wr_en(even_wr),  // input wire wr_en
      .rd_en(even_rd),  // input wire rd_en
      .dout(even_dout),    // output wire [63 : 0] dout
      .full(even_full),    // output wire full
      .empty(even_empty)  // output wire empty
    );
        
    mipi_fifo lr_buff (
      .srst(rst),
      .clk(clk),                // input clock
      .din(reg_lr_din),                      // input wire [64 : 0] din
      .wr_en(lr_wr_en),                  // input wire wr_en
      .rd_en(lr_rd_en),                  // input wire rd_en
      .dout(sig_lr_dout),                    // output wire [64 : 0] dout
      .full(lr_full),                    // output wire full
      .empty(lr_empty),                  // output wire empty
      .data_count(lr_count)  // output wire [5 : 0] rd_data_count
    );

    color_div_mul rdiv ( .CLK(clk), .A(r_vsum14_add), .B(color_divider), .P(r_div_out) );
    color_div_mul gdiv ( .CLK(clk), .A(g_vsum14_add), .B(color_divider), .P(g_div_out) );
    color_div_mul bdiv ( .CLK(clk), .A(b_vsum14_add), .B(color_divider), .P(b_div_out) );

    always @ (posedge clk) begin
        if (lr_full) debug_state[0] <= 1'b1;
        if (hr_full) debug_state[1] <= 1'b1;
        debug_state[11:2] <= {hr_empty, hr_full, lr_empty, lr_full, packet_left, traffic_mode};
        is_busy[0] <= ~(hr_empty && lr_empty);
        is_busy[1] <= ~(hr_count<AXI_SIZE && lr_count<AXI_SIZE);
        
        if (rst) begin
            case (window_type)  // color_divider = 1024 * 256 / (x * y)
            4'd0: {color_divider, h_cycle_end, v_cycle_end} <= {18'd21845, 4'd3, 4'd2}; // 4 : 3    1200x900 (Det), 896x672 (CLs)
//            4'd1: {color_divider, h_cycle_end, v_cycle_end} <= {18'd14563, 4'd5, 4'd2}; // 6 : 3    1800x900 (Det fhd), 1344x672 (Cls fhd)
//            4'd2: {color_divider, h_cycle_end, v_cycle_end} <= {18'd17476, 4'd4, 4'd2}; // 5 : 3    1500x900 (Det fhd), 1120x672 (Cls)
//            4'd3: {color_divider, h_cycle_end, v_cycle_end} <= {18'd43690, 4'd2, 4'd1}; // 3 : 2    1200x600 (Det), 672x448 (Cls)
//            4'd4: {color_divider, h_cycle_end, v_cycle_end} <= {18'd65536, 4'd1, 4'd1}; // 2 : 2     600x600 (Det), 448x448 (Cls)
//            4'd5: {color_divider, h_cycle_end, v_cycle_end} <={18'd131072, 4'd1, 4'd0}; // 2 : 1     600x300 (Det), 448x224 (Cls)
//            4'd6: {color_divider, h_cycle_end, v_cycle_end} <= { 18'd9362, 4'd6, 4'd3}; // 7:  4    1568x896 (Cls fhd)
//            4'd7: {color_divider, h_cycle_end, v_cycle_end} <= {18'd10922, 4'd5, 4'd3}; // 6 : 4    1344x896 (Cls fhd)
            4'd8: {color_divider, h_cycle_end, v_cycle_end} <= {18'd13107, 4'd4, 4'd3}; // 5 : 4    1120x896 (Cls fhd)
            endcase
            curr_wtype <= window_type;
        end
    
        de_d1 <= (de && ready); de_d2 <= de_d1;
        
        h_oddcycle_d[0] <= h_oddcycle;
        h_oddcycle_d[4:1] <= h_oddcycle_d[3:0];
        if (sof || eol) begin
            hseq <= 4'd0;
            h_oddcycle <= 1'b0;
        end else if (de && ready) begin
            hseq <= (hseq>=h_cycle_end) ? 4'd0 : hseq + 1'b1;
            h_oddcycle <= (hseq>=h_cycle_end) ? ~h_oddcycle : h_oddcycle;
        end
        hseq_d1 <= hseq;  
        hseq_d2 <= hseq_d1;

        if (sof) begin
            vseq <= 4'd0;
            v_oddcycle <= 1'b0;
        end else if (eol && ready) begin
            vseq <= (vseq==v_cycle_end) ? 4'd0 : vseq + 1'b1;
            if (vseq==v_cycle_end) v_oddcycle <= ~v_oddcycle;
        end
        vseq_d2[0] <= (vseq==v_cycle_end && v_oddcycle);
        vseq_d2[7:1] <= vseq_d2[6:0];
            
        if (de && ready) begin   // t0
            r_hsum12 <= (hseq==4'd0) ? {4'd0, data_in[23:16]} : r_hsum12 + data_in[23:16]; // max 255*4 = 1020
            g_hsum12 <= (hseq==4'd0) ? {4'd0, data_in[15: 8]} : g_hsum12 + data_in[15: 8];
            b_hsum12 <= (hseq==4'd0) ? {4'd0, data_in[ 7: 0]} : b_hsum12 + data_in[ 7: 0];
        end
        
        // t1
        r_vsum14_add <= scan_dout[41:28] + r_hsum12;
        g_vsum14_add <= scan_dout[27:14] + g_hsum12;
        b_vsum14_add <= scan_dout[13: 0] + b_hsum12;
        r_vsum12_ini <= r_hsum12;
        g_vsum12_ini <= g_hsum12;
        b_vsum12_ini <= b_hsum12;

        if (de_d2 && hseq_d2==h_cycle_end) begin   // t2
            r_vsum14 <= (vseq[3:0]==4'd0) ? {2'd0, r_vsum12_ini} : r_vsum14_add;
            g_vsum14 <= (vseq[3:0]==4'd0) ? {2'd0, g_vsum12_ini} : g_vsum14_add;
            b_vsum14 <= (vseq[3:0]==4'd0) ? {2'd0, b_vsum12_ini} : b_vsum14_add;
        end
        out_en[0] <= (de_d2 && hseq_d2==h_cycle_end && vseq==v_cycle_end); // t2
        out_en[2:1] <= out_en[1:0];
        rgb_adj <= {r_div_out[25:18], g_div_out[25:18], b_div_out[25:18]}; 
        if (out_en[2]) begin    // t5
            if (~h_oddcycle_d[4]) begin
                oe_din <= {33'd0, rgb_adj};
            end else
                oe_din[63:32] <= rgb_adj;
        end
        if (out_en[2] && h_oddcycle_d[4] && vseq_d2[7]) oe_seq <= 2'd2;    // t5
        if (oe_seq>2'd0) oe_seq <= oe_seq - 1'b1;
        if (sof)
            reg_lr_din <= {1'b1, hr_base, 16'd0, lr_base, 16'd0};
        else if (oe_seq==2'd2)   // {green, red}
            reg_lr_din <= {oe_din[47:40],oe_din[15:8],even_dout[47:40],even_dout[15:8], oe_din[55:48],oe_din[23:16],even_dout[55:48],even_dout[23:16]};
        else if (oe_seq==2'd1)   // {0, blue}
            reg_lr_din <= {32'd0, oe_din[39:32],oe_din[7:0],even_dout[39:32],even_dout[7:0]};
        
        even_wr <= (out_en[2] && h_oddcycle_d[4] && ~vseq_d2[7]);
        even_rd <= (oe_seq==2'd1);
        lr_wr_en <= (sof || oe_seq>2'd0);
        scan_wr <= (de_d2 && hseq_d2==h_cycle_end && vseq!=v_cycle_end);
        snan_rd <= (de_d1 && hseq_d1==h_cycle_end && vseq!=4'd0);
    end
        
    mipi_fifo hr_buff (
      .srst(rst),
      .clk(clk),                // input wire wr_clk
      .din(reg_hr_din),                      // input wire [64 : 0] din
      .wr_en(hr_wr_en),                  // input wire wr_en
      .rd_en(hr_rd_en),                  // input wire rd_en
      .dout(sig_hr_dout),                    // output wire [64 : 0] dout
      .full(hr_full),                    // output wire full
      .empty(hr_empty),                  // output wire empty
      .data_count(hr_count)  // output wire [5 : 0] rd_data_count
    );
    
    always @ (posedge clk) begin
		if (de_32) begin
            if (hcount32_0==1'b0)
                reg_hr_din[31:0] <= data_in_32; // {8'd0, data_in};
            else begin  // wr = 1
                reg_hr_din[64:32] <= {1'b0, data_in_32};
            end
        end
        hr_wr_en <= (de_32 && hcount32_0);
        ready <= (hr_count<=BUFF_TH && lr_count<=BUFF_TH);
    end
    // limit address to 1c000000 ~ 1fffffff
    assign S_AXI_awaddr = {
        5'd3,
        ( traffic_mode[1] ? 
            {(reg_hr_awaddr[26:21]<6'd27 || reg_hr_awaddr[26:21]>6'd53) ? 6'd53 : reg_hr_awaddr[26:0]} : 
            {4'hf, reg_lr_awaddr[22:0]}
        )
      };    
    assign S_AXI_awsize = 3'b011;   // 8 bytes (64-bit) packet
    assign S_AXI_awlen = 4'd3;
    assign S_AXI_awburst = 2'd1;
    assign S_AXI_wstrb = 8'hff;
    assign S_AXI_wlast = (packet_left==4'd1);
    assign S_AXI_bready = 1'b1;
    assign S_AXI_arvalid = 1'b0;
    
    assign S_AXI_wdata = traffic_mode[1] ? sig_hr_dout[63:0] : sig_lr_dout[63:0];
    assign hr_rd_en = (traffic_mode[1] && S_AXI_wvalid && S_AXI_wready);
    assign lr_rd_en = (traffic_mode[0] && S_AXI_wvalid && S_AXI_wready) || sig_lr_dout[64];

    logic [31:0] awaddr_dbg;
    logic awvalid_dbg, awready_dbg, wvalid_dbg, wready_dbg, hr_newaddr, sof_d1;
    logic [31:0] aw_hr_count = 32'd0, aw_lr_count = 32'd0;

    always @ (posedge clk) begin
        sof_d1 <= sof;
        awaddr_dbg <= S_AXI_awaddr;
        awvalid_dbg <= S_AXI_awvalid;
        awready_dbg <= S_AXI_awready;
        wvalid_dbg <= S_AXI_wvalid;
        wready_dbg <= S_AXI_wready;
        hr_newaddr <= (sig_lr_dout[64] && lr_rd_en && ~lr_empty);
        
        // aw channel
        // branch to low resolution communication
        if (traffic_mode==2'b00 && lr_count>=AXI_SIZE && lr_count>=hr_count && sig_lr_dout[64]==1'b0) begin
            traffic_mode <= 2'b01;
            S_AXI_awvalid <= 1'b1;
        end else
        // branch to high resolution communication
        if (traffic_mode==2'b00 && hr_count>=AXI_SIZE) begin
            traffic_mode <= 2'b10;
            S_AXI_awvalid <= 1'b1;
        end
        // set base address
        if (~lr_empty && sig_lr_dout[64] && lr_rd_en) begin
			reg_hr_awaddr <= sig_lr_dout[63:32];
			reg_lr_awaddr <= sig_lr_dout[31:0];
			aw_hr_count <= 32'd0;
			aw_lr_count <= 32'd0;
		end else if (S_AXI_awready && S_AXI_awvalid) begin
            if (traffic_mode[1]) begin
                reg_hr_awaddr <= reg_hr_awaddr + 7'd32;
    			aw_hr_count <= aw_hr_count + 1'b1;
            end else begin
                reg_lr_awaddr <= reg_lr_awaddr + 7'd32;
    			aw_lr_count <= aw_lr_count + 1'b1;
            end
        end
        if (S_AXI_awready && S_AXI_awvalid) begin
            S_AXI_awvalid <= 1'b0;
            S_AXI_wvalid <= 1'b1;
            packet_left <= 4'd4;
        end        
        // write channel
        if (S_AXI_wvalid && S_AXI_wready) packet_left <= packet_left - 1'b1;
        if (S_AXI_wvalid && S_AXI_wready && packet_left==4'd1) S_AXI_wvalid <= 1'b0;
        if (S_AXI_wvalid && S_AXI_wready && packet_left==4'd1) traffic_mode <= 2'b00;
    end

endmodule
