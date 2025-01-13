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

// `define SIMUL
//////////////////////////////////////////////////////////////////////////////////
// Company: Neurocoms Inc.
// Engineer: Byungik Ahn (jerryahn@neurocoms.com)
// 
// Create Date: 2020/11/14 22:21:17
// Design Name: 
// Module Name: ddr_if
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: Handles DDR3 requests from various part of the circuit and
//          interfaces to DDR3 logic. 
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


module ddr_if(
        // command distribution
        input i_dispatch,       // there is a new command
        input [5:0] i_modes,    // the content of the command
        
        // header interface
        output reg o_header_en,
        output reg [127:0] o_header128,
        input [25:0] i_model_baseaddr,
        // --> NU flow queue interface
        input i_r_rd_en,
        output o_r_valid,
        output [127:0] o_r_dout,
        // <-- NU flow queue interface
        input i_w_wr_en,
        output o_w_full,
        input [127:0] i_w_din,
        // --> SNU (parameter)
        input i_para_full,
        output reg o_para_en,
        output reg [127:0] o_para128,
        //
        input i_out_wr_en,
        output o_out_full,
        input [127:0] i_out_din,
        input [25:0] i_out_addr,
        //
        output reg o_req_en,
        output reg o_req_rw,
        output reg o_req_flush,
        output reg o_req_newaddr,
        output [25:0] o_req_addr,
        output reg [127:0] o_req_din,
        input i_req_avail,
        input reg i_req_error,
        //
        input i_resp_en,
        input [25:0] i_resp_addr,
        input [127:0] i_resp_dout,
        output o_resp_wait,
        input i_resp_rdone,
        
        // supplimentary information
        input [13:0] i_ddr_addr,    // 64k-byte resolution
        input [19:0] i_ddr_len_m1,  // 128-bit resolution
        input [17:0] i_ddr_step,
        input i_topmost,
        input [12:0] i_ncm1,
        // supplimentary information for parameter
        input [29:0] i_para_baseaddr,
        // synchronization
        output reg o_ddr_done,
        output reg o_if_idle,
        input i_interlg_reset,
        input [25:0] i_runtime,
        input [8:0] i_job_id,
        output reg [31:0] o_chksum = 0,
        output reg [31:0] o_err_code = 0,
        input i_reset_chksum,
        input clk
    );
    
    enum bit [3:0] {S_DDR_IDLE, S_DDR_READING, S_DDR_READFLUSH, S_DDR_READFLUSH1, S_DDR_READFLUSH2, S_DDR_READFLUSH3,
        S_DDR_WRITING, S_DDR_BBOX_WRITING, S_DDR_BBOX_COUNT, S_DDR_WRITEFLUSH, S_DDR_WRITEFLUSH2,
        S_DDR_PARA} ddrif_state = S_DDR_IDLE;
    
    logic [29:0] curr_addr, prev_addr_down, prev_addr_up, prev_addr_down_res;
    logic iq_srst, iq_full, iq_empty;
    logic [127:0] iq_dout;
    logic oq_srst, oq_wr_en, oq_full, oq_empty;
    logic [127:0] oq_din;
    logic [23:0] curr_count;
    logic [4:0] iq_dcount, oq_dcount;
    logic [25:0] reg_baseaddr, reg_para_baseaddr;
    logic [17:0] reg_imsize_down_m1, reg_imsize_up_m1;
    logic [12:0] curr_ch;
    
    logic [4:0] delay_counter;
    logic [15:0] error_counter = 16'd0;
    logic reg_dispatch;
    
    logic header_mode, bbox_mode, r_mode, w_mode, conv_mode, res_mode;
    logic r_req_en, w_req_en, conv_req_en, bbox_count_en;
    logic bbox_done;
    logic [9:0] det_count;
    logic ddr_error = 'b0;
    logic reg_req_en = 'b0;
    logic [19:0] reg_ddr_len_m1, reg_ddr_len_m2;
    logic single_length, curr_count_last;
    
    logic [25:0] reg_para_base;
    
    logic [15:0] chkcount;
    logic [31:0] chksum = 32'd0;
    logic [25:0] reg_req_addr;
    logic header_mode_d2 = 0;
    
    // buffer for DDR upload
    
    video_fifo inQ (    // DDR upload
      .clk(clk),      // input wire clk
      .srst(iq_srst),    // input wire srst
      .din(bbox_mode?i_out_din:i_w_din),      // input wire [145 : 0] din
      .wr_en(bbox_mode?i_out_wr_en:i_w_wr_en),  // input wire wr_en
      .rd_en(w_req_en),  // input wire rd_en
      .dout(iq_dout),    // output wire [145 : 0] dout
      .data_count(iq_dcount),
      .full(),    // output wire full
      .almost_full(iq_full),  // output wire almost_full
      .almost_empty(),  // output wire almost_full
      .empty(iq_empty)  // output wire empty
    );

    // buffer for DDR download
    
    video_fifo outQ (   
      .clk(clk),      // input wire clk
      .srst(oq_srst),    // input wire srst
      .din(oq_din),      // input wire [127 : 0] din
      .wr_en(oq_wr_en),  // input wire wr_en
      .rd_en(i_r_rd_en),  // input wire rd_en
      .dout(o_r_dout),    // output wire [127 : 0] dout
      .data_count(oq_dcount),
      .full(),    // output wire full
      .almost_full(),  // output wire almost_full
      .almost_empty(),  // output wire almost_full
      .empty(oq_empty)  // output wire empty
    );
    
    assign oq_srst = 'b0;//i_interlg_reset; // without reset would be safer way
    assign iq_srst = 'b0;//i_interlg_reset;
    assign {res_mode, header_mode, bbox_mode, r_mode, w_mode, conv_mode} = i_modes;
    
    assign r_req_en = i_req_avail && ((r_mode || res_mode) && ddrif_state==S_DDR_READING);
    assign w_req_en = i_req_avail && (((w_mode && ddrif_state==S_DDR_WRITING) || (bbox_mode && ddrif_state==S_DDR_BBOX_WRITING)) && ~iq_empty);
    assign bbox_done = (bbox_mode && iq_dout[127]);
    assign conv_req_en = i_req_avail && ((header_mode || conv_mode) && ddrif_state==S_DDR_PARA);
    assign o_resp_wait = (r_mode || res_mode)  ? oq_full : conv_mode ? i_para_full : 'b0;
    assign bbox_count_en = (ddrif_state==S_DDR_BBOX_COUNT);
`ifdef SIMUL
    assign o_req_addr = reg_req_addr[25:0];
`else
    assign o_req_addr = {2'b11,reg_req_addr[23:0]};
`endif
    
    
    always @ (posedge clk) begin
        if (i_interlg_reset) begin
            
        end else begin

            oq_full <= (oq_dcount>5'd12);
            reg_para_base = i_model_baseaddr + 16'd4096;

            o_req_en <= r_req_en || w_req_en || conv_req_en || bbox_count_en;
            o_req_rw <= ~w_mode && ~bbox_mode;
            reg_req_addr <= reg_baseaddr + curr_addr;
            if (w_mode || (bbox_mode && ~bbox_done && ~bbox_count_en))
                o_req_din <= iq_dout;
            else if (bbox_mode && bbox_count_en) begin
                o_req_din <= {6'd0, i_runtime, 23'd0, i_job_id, 54'h0, det_count};
            end else
                o_req_din <= 128'h0;
            o_req_flush <= (ddrif_state==S_DDR_READFLUSH || ddrif_state==S_DDR_WRITEFLUSH);
            o_req_newaddr <= bbox_done || ((r_req_en || w_req_en || conv_req_en) && (~single_length && curr_count[19:0]==reg_ddr_len_m1));

`ifndef SIMUL
            header_mode_d2 <= i_modes[4];
            if (i_reset_chksum || (~header_mode_d2 && i_modes[4])) begin
//                o_err_code <= 32'd0;
//                o_err_code2 <= 32'd0;
                chkcount <= 16'd0;
                chksum <= 32'd0;
            end else if (i_resp_en) begin
                chkcount <= chkcount + 1'b1;
                chksum <= chksum ^ ((i_resp_dout[31:0] ^ i_resp_dout[63:32]) ^ (i_resp_dout[95:64] ^ i_resp_dout[127:96]));
            end
//            if (o_req_en && reg_req_addr[25:24]!=2'b11) begin
//                o_err_code[29] <= 1'b1;
//                o_err_code[3:0] <= ddrif_state;
//                o_err_code[25:4] <= o_err_code[25:4] + 1'b1;
//                o_err_code2[25:0] <= reg_req_addr;
//            end
//            if (o_req_newaddr && ~o_req_en) o_err_code[30] <= 1'b1;
//            if (o_req_flush && o_req_en) o_err_code[31] <= 1'b1;
            o_chksum <= chksum;
`endif            
            
            if (bbox_done) det_count <= iq_dout[9:0];

            // to make proceed to next layer only when ddr_if is idle
            o_if_idle <= (ddrif_state == S_DDR_IDLE);
            reg_dispatch <= i_dispatch;
            reg_ddr_len_m1 <= header_mode ? 20'd2047 : i_ddr_len_m1;
            reg_ddr_len_m2 <= header_mode ? 20'd2046 : i_ddr_len_m1 - 1'b1;
            single_length <= (reg_ddr_len_m1[19:0]==20'd0);
            
            // read response
            o_header_en <= (header_mode && i_resp_en);
            oq_wr_en <= ((r_mode || res_mode)  && i_resp_en);
            o_para_en <= (conv_mode && i_resp_en);
            
            if (header_mode) begin
                o_header128 <= i_resp_dout;
            end else if (r_mode || res_mode) begin
                oq_din <= i_resp_dout;
            // parameter response
            end else if (conv_mode) begin
                o_para128 <= i_resp_dout;
            end
//            if (i_resp_en) begin
//                chkcount <= chkcount + 1'b1;
//                chksum <= chksum ^ ((i_resp_dout[31:0] ^ i_resp_dout[63:32]) ^ (i_resp_dout[95:64] ^ i_resp_dout[127:96]));
//            end
            
            if ((i_interlg_reset || reg_dispatch) && ddrif_state!=S_DDR_IDLE) ddr_error <= 'b1;
        
            case (ddrif_state)
            S_DDR_IDLE:
                begin
                    if (reg_dispatch && header_mode) begin
                        reg_baseaddr <= i_model_baseaddr;//{6'h18, i_model_baseaddr[19:0]};
                        curr_addr <= 30'd0;
                        ddrif_state <= S_DDR_PARA;
    
                    // DDR download: read from DDR using oQ
                    end else if (reg_dispatch && (r_mode || res_mode)) begin           // oq_full==0 is aasumed
                        reg_baseaddr <= {i_ddr_addr, 12'd0};  // ddr base address in 16 byte(128 bit) resolution
                        if (i_topmost) begin
                            // start a new session
                            curr_addr <= 30'h0;
                            if (r_mode)
                                prev_addr_down <= 30'd0;
                            else
                                prev_addr_down_res <= 30'd0;
                        end else 
                            // continue previous session
                            curr_addr <= r_mode ? prev_addr_down : prev_addr_down_res;
                        ddrif_state <= S_DDR_READING;
                        
                    // DDR upload: write to DDR using iQ
                    end else if (reg_dispatch && w_mode) begin
                        reg_baseaddr <= {i_ddr_addr, 12'd0};   // ddr base address in 16 byte(128bit) resolution
                        if (i_topmost) begin
                            curr_addr <= 30'h0;
                            prev_addr_up <= 30'd0;
                        end else 
                            curr_addr <= prev_addr_up;
                        ddrif_state <= S_DDR_WRITING;

                    end else if (reg_dispatch && bbox_mode) begin
                        reg_baseaddr <= i_out_addr;
                        curr_addr <= 30'd1; // address starting from second record
                        ddrif_state <= S_DDR_BBOX_WRITING;
                        
                    // DDR parameter download
                    end else if (reg_dispatch && conv_mode) begin
                        reg_baseaddr <= reg_para_base + i_para_baseaddr[19:0];
                        curr_addr <= 30'd0;
                        ddrif_state <= S_DDR_PARA;
                    end
    
                    curr_count <= 24'h0;
                    curr_count_last <= 1'b0;
                    curr_ch <= 13'd0;
                    o_ddr_done <= 1'b0;
                    
//                    if (i_reset_chksum) begin
////                    if (reg_dispatch && ((r_mode || res_mode) || conv_mode)) begin
//                        chkcount <= 16'd0;
//                        chksum <= 32'd0;
//                    end
                end
                
            // Read from DDR
            
            S_DDR_READING:
                begin
                    if (r_req_en) begin
                        // non-video의 경우 2 (8ch group) x 16 데이터 두 개가 16채널의 한 픽셀을 구성하고 다 끝나면 오프셋만큼 증가해서 반복
                        // DDR read address is reg_baseaddr + curr_addr
                        if (single_length || curr_count_last) begin //curr_count[13:0]==reg_ddr_len_m1[13:0]) begin
                            if (curr_ch==i_ncm1) begin
                                if (r_mode)
                                    prev_addr_down <= curr_addr + 1'b1; // next starting point
                                else
                                    prev_addr_down_res <= curr_addr + 1'b1;
                                ddrif_state <= S_DDR_READFLUSH;
                            end else begin
                                curr_ch <= curr_ch + 1'b1;
                            end
                            curr_addr <= (i_topmost) ? 30'h0 : (r_mode) ? prev_addr_down : prev_addr_down_res;
                            reg_baseaddr <= reg_baseaddr + i_ddr_step;
                            curr_count <= 24'd0;
                            curr_count_last <= 1'b0;
                        end else begin
                            curr_count <= curr_count + 1'b1;
                            curr_count_last <= (curr_count[13:0]==reg_ddr_len_m2[13:0]);
                            curr_addr <= curr_addr + 1'b1;
                        end
                    end
                end
            S_DDR_READFLUSH: begin
                    delay_counter <= 5'd2;
                    ddrif_state <= S_DDR_READFLUSH1;
                end
            S_DDR_READFLUSH1:
                // wait until the last command applied
                if (delay_counter==5'd0) begin
                    error_counter <= 16'd0;
                    ddrif_state <= S_DDR_READFLUSH2;
                end else
                    delay_counter <= delay_counter - 'b1;
            S_DDR_READFLUSH2:
                if (i_resp_rdone && (!res_mode || oq_empty)) begin
                    delay_counter <= res_mode ? 5'd19 : 5'd4;
                    ddrif_state <= S_DDR_READFLUSH3;    // delay some more clock cycles so that write to MX completes
                end else begin
                    error_counter <= error_counter + 1'b1;
                end
            S_DDR_READFLUSH3:
                // wait until last read response finds its target
                if (delay_counter==5'd0) begin
                    o_ddr_done <= 1'b1;
                    ddrif_state <= S_DDR_IDLE;
                end else
                    delay_counter <= delay_counter - 'b1;
                
            // Write to DDR
            
            S_DDR_WRITING:
                begin
                    // DDR write address is up_offset + curr_addr
                    if (w_req_en) begin
                        if (single_length || curr_count_last) begin //curr_count[13:0]==reg_ddr_len_m1[13:0]) begin
                            if (curr_ch==i_ncm1) begin
                                prev_addr_up <= curr_addr + 1'b1;
                                ddrif_state <= S_DDR_WRITEFLUSH;
                            end else
                                curr_ch <= curr_ch + 1'b1;
                            reg_baseaddr <= reg_baseaddr + i_ddr_step;
                            curr_count <= 24'd0;
                            curr_count_last <= 1'b0;
                            curr_addr <= (i_topmost) ? 30'h0 : prev_addr_up;
                        end else begin
                            curr_count <= curr_count + 1'b1;
                            curr_count_last <= (curr_count[13:0]==reg_ddr_len_m2[13:0]);
                            curr_addr <= curr_addr + 1'b1;
                        end
                    end 
                end
            S_DDR_BBOX_WRITING:
                begin
                    // DDR write address is up_offset + curr_addr
                    if (w_req_en) begin
                        if (bbox_done) begin
                            curr_addr <= 30'd0;
                            ddrif_state <= S_DDR_BBOX_COUNT;
                        end else
                            curr_addr <= curr_addr + 1'b1;
                    end 
                end
            S_DDR_BBOX_COUNT:
                ddrif_state <= S_DDR_WRITEFLUSH;
            S_DDR_WRITEFLUSH:
                    ddrif_state <= S_DDR_WRITEFLUSH2;
            S_DDR_WRITEFLUSH2:
                if (i_req_avail) begin
                    o_ddr_done <= 1'b1;
                    ddrif_state <= S_DDR_IDLE;
                end
    
            // Read parameters
            
            S_DDR_PARA:
                begin
                    if (conv_req_en) begin
                            if (single_length || curr_count_last) begin // if (curr_count==reg_ddr_len_m1) begin
                                ddrif_state <= S_DDR_READFLUSH;
                            end else begin
                                curr_count <= curr_count + 1'b1;
                                curr_count_last <= (curr_count[19:0]==reg_ddr_len_m2);
                            end
                        curr_addr <= curr_addr + 1'b1;
                    end
                end
            endcase
            
        end // if (interlg_reset) begin
    end
    
    // for synchronization with MX part
    assign o_r_valid = ~oq_empty;
    assign o_w_full = (iq_dcount>4'd10);
    assign o_out_full = (iq_dcount>4'd10);
    
endmodule
