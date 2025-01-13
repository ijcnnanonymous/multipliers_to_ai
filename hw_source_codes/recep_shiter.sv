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
// Create Date: 2020/10/03 15:34:29
// Design Name: 
// Module Name: recep_shiter
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description:Receptor Shifter  
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


module recep_shiter # (
        parameter DATA_WIDTH = 16,
`ifdef SMALL_SYS 
        parameter N_RECEPTOR = 4,
`else
        parameter N_RECEPTOR = 8,
`endif
        parameter REC_WIDTH = (N_RECEPTOR * DATA_WIDTH * 2)
    ) 
    (
        input [1:0][REC_WIDTH-1:0] i_din = 0,   // FIFO input for each row
        input [(4*3)-1:0][REC_WIDTH-1:0] i_rnetstate,   // additional info for receptornet data (4x3 array)
        output [1:0][REC_WIDTH-1:0] o_dout, // FIFO output for each row
        output [(4*3)-1:0][REC_WIDTH-1:0] o_rnetstate,  // additional info for receptornet data (4x3 array)
        input i_topmost,
        // input commands
        input [4:0] i_switch_req = 5'h0,    // reset_loading, switch_receptor, start_saving, start_loading, reserved
        // output flags
        output o_save_done, o_load_done,
        // additional control signals
        input [8:0] i_len = 9'h0,   // length of the FIFOs
        input [1:0] i_mode_bits = 2'h0, // DW, S2
        // 
        input init, // timing to set memory base address
        input [12:0] i_shuttle_addr,    // base address for shuttle memory
        input i_hold,   // hold shifting
        output o_is_idle,
        input interlg_reset,
        //
        input clk
    );
    
    enum {S_MS_INIT, S_MS_RESET, S_MS_FILLING, S_MS_SHIFTING} myshifter_state = S_MS_INIT;
    enum {S_ST_IDLE, S_ST_S1, S_ST_S2, S_ST_S3, S_ST_S4, S_ST_S5, S_ST_SAVE, S_ST_LOAD} shuttle_state = S_ST_IDLE;
    logic reg_error = 1'b0;
    logic reg_wr_en1, reg_rd_en1, sig_valid1;
    logic reg_wr_en2, reg_rd_en2, sig_valid2;
    logic reg_wr_en3, reg_rd_en3, sig_valid3;
    logic reg_wr_en4, reg_rd_en4, sig_valid4;
    logic reg_reset13, reg_reset24, reg_reset_fifo, reg_reset_extra;
    logic [9:0] sig_data_count1, sig_data_count2, sig_data_count3, sig_data_count4;
    logic reg_wr_en_low, reg_rd_en_low, sig_valid_low, reg_wr_en_extra1, reg_rd_en_extra1, sig_valid_extra1;
    logic reg_wr_en_high, reg_rd_en_high, sig_valid_high, reg_wr_en_extra2, reg_rd_en_extra2, sig_valid_extra2;
    logic [9:0] sig_data_count_low, sig_data_count_extra1;
    logic [9:0] sig_data_count_high, sig_data_count_extra2;
    logic [2:0] rst_delay = 3'h0;
    logic [8:0] reg_len, reg_i_len = 9'h0;
    logic [REC_WIDTH-1:0] din1, din2, dout1, dout2, din_low, din_extra1, dout_low, dout_extra1;
    logic [REC_WIDTH-1:0] din3, din4, dout3, dout4, din_high, din_extra2, dout_high, dout_extra2;
    logic [REC_WIDTH-1:0] dout1_bypass1, dout2_bypass1, dout3_bypass1, dout4_bypass1;
    logic [REC_WIDTH-1:0] dout1_bypass2, dout2_bypass2, dout3_bypass2, dout4_bypass2;
    logic [REC_WIDTH-1:0] dout1_fifo, dout2_fifo, dout3_fifo, dout4_fifo;
    logic reg_save_done = 1'b0, save_en = 1'b0, rnet_save_en;
    logic reg_load_done = 1'b0, load_addr_en = 1'b0, load_en = 1'b0;
    logic [2:0] load_data_en;
    logic [4:0] reg_switch_req = 5'h0;
    logic [(4*3)-1:0][REC_WIDTH-1:0] reg_rnetstate;
    logic [1:0] reg_mode_bits = 2'h0;
    logic [31:0] bottom_32;
    logic [63:0] bottom_64;
`ifndef SMALL_SYS 
    logic [255:0] bottom_256;
    logic [3:0] sh_waddr_cycle = 4'h0, sh_raddr_cycle = 4'h0;
    logic [1:0][3:0] sh_raddr_cycle_d;
`else
    logic [127:0] bottom_128;
    logic [2:0] sh_waddr_cycle = 3'h0, sh_raddr_cycle = 3'h0;
    logic [1:0][2:0] sh_raddr_cycle_d;
`endif
    logic [12:0] sh_waddr_seq = 13'h0, sh_raddr_seq = 13'h0;
    logic [12:0] load_count, load_len, base_addr;
    logic [2:0][12:0] load_count_d;
    logic [2:0] load_count_d_2;

    logic [N_RECEPTOR*2-1:0] shmem_we;
    logic [12:0] sh_waddr;
    logic [1:0][REC_WIDTH-1:0] shmem_front, shmem_front2;
    logic [REC_WIDTH*2-1:0] shmem_load;
    logic [N_RECEPTOR*2-1:0][31:0] shmem_din, shmem_dout;
    logic [1:0] reg_bypass_ind = 2'h0;
    
    logic reg_switch = 1'b0;
    
    genvar idx;
    integer i;

    fifo_252_512 shifter1 (
      .clk(clk),                // input wire clk
      .srst(reg_reset13),              // input wire srst
      .din(din1),                // input wire [703 : 0] din
      .wr_en(reg_wr_en1),            // input wire wr_en
      .rd_en(reg_rd_en1),            // input wire rd_en
      .dout(dout1_fifo),              // output wire [703 : 0] dout
      .full(),              // output wire full
      .empty(),            // output wire empty
      .valid(sig_valid1),            // output wire valid
      .data_count(sig_data_count1)  // output wire [9 : 0] data_count
    );

    fifo_252_512 shifter2 (
      .clk(clk),                // input wire clk
      .srst(reg_reset24),              // input wire srst
      .din(din2),                // input wire [703 : 0] din
      .wr_en(reg_wr_en2),            // input wire wr_en
      .rd_en(reg_rd_en2),            // input wire rd_en
      .dout(dout2_fifo),              // output wire [703 : 0] dout
      .full(),              // output wire full
      .empty(),            // output wire empty
      .valid(sig_valid2),            // output wire valid
      .data_count(sig_data_count2)  // output wire [9 : 0] data_count
    );

    fifo_252_512 shifter3 (
      .clk(clk),                // input wire clk
      .srst(reg_reset13),              // input wire srst
      .din(din3),                // input wire [703 : 0] din
      .wr_en(reg_wr_en3),            // input wire wr_en
      .rd_en(reg_rd_en3),            // input wire rd_en
      .dout(dout3_fifo),              // output wire [703 : 0] dout
      .full(),              // output wire full
      .empty(),            // output wire empty
      .valid(sig_valid3),            // output wire valid
      .data_count(sig_data_count3)  // output wire [9 : 0] data_count
    );

    fifo_252_512 shifter4 (
      .clk(clk),                // input wire clk
      .srst(reg_reset24),              // input wire srst
      .din(din4),                // input wire [703 : 0] din
      .wr_en(reg_wr_en4),            // input wire wr_en
      .rd_en(reg_rd_en4),            // input wire rd_en
      .dout(dout4_fifo),              // output wire [703 : 0] dout
      .full(),              // output wire full
      .empty(),            // output wire empty
      .valid(sig_valid4),            // output wire valid
      .data_count(sig_data_count4)  // output wire [9 : 0] data_count
    );

    generate
        for(idx = 0; idx < N_RECEPTOR*2; idx = idx + 1) begin : gen_inst
            shuttle_mem shuttle_mem (
              .clka(clk),    // input wire clka
              .wea(shmem_we[idx]),      // input wire [0 : 0] wea
              .addra(sh_waddr[11:0]),  // input wire [11 : 0] addra
              .dina(shmem_din[idx]),    // input wire [31 : 0] dina
              .clkb(clk),    // input wire clkb
              .addrb(sh_raddr_seq[11:0]),  // input wire [11 : 0] addrb
              .doutb(shmem_dout[idx])  // output wire [31 : 0] doutb
            );
        end
    endgenerate
    
    assign o_save_done = reg_save_done ;
    assign o_load_done = reg_load_done;
    
    assign dout_low = (reg_switch) ? dout2 : dout1; 
    assign sig_valid_low = (reg_switch) ? sig_valid2 : sig_valid1; 
    assign sig_data_count_low = (reg_switch) ? sig_data_count2 : sig_data_count1; 
    assign dout_extra1 = (reg_switch) ? dout1 : dout2; 
    assign sig_valid_extra1 = (reg_switch) ? sig_valid1 : sig_valid2; 
    assign sig_data_count_extra1 = (reg_switch) ? sig_data_count1 : sig_data_count2; 

    assign reg_wr_en1 = (!reg_switch) ? (reg_wr_en_low && ~i_switch_req[3] && ~i_hold) : reg_wr_en_extra1; 
    assign reg_rd_en1 = (!reg_switch) ? (reg_rd_en_low && ~i_switch_req[3] && ~i_hold) : reg_rd_en_extra1; 
    assign din1 = (!reg_switch) ? din_low : din_extra1; 
    assign reg_wr_en2 = (reg_switch) ? (reg_wr_en_low && ~i_switch_req[3] && ~i_hold) : reg_wr_en_extra1; 
    assign reg_rd_en2 = (reg_switch) ? (reg_rd_en_low && ~i_switch_req[3] && ~i_hold) : reg_rd_en_extra1; 
    assign din2 = (reg_switch) ? din_low : din_extra1; 
    
    assign dout_high = (reg_switch) ? dout4 : dout3; 
    assign sig_valid_high = (reg_switch) ? sig_valid4 : sig_valid3; 
    assign sig_data_count_high = (reg_switch) ? sig_data_count4 : sig_data_count3; 
    assign dout_extra2 = (reg_switch) ? dout3 : dout4; 
    assign sig_valid_extra2 = (reg_switch) ? sig_valid3 : sig_valid4; 
    assign sig_data_count_extra2 = (reg_switch) ? sig_data_count3 : sig_data_count4; 
    
    assign reg_wr_en3 = (!reg_switch) ? (reg_wr_en_high && ~i_switch_req[3] && ~i_hold) : reg_wr_en_extra2; 
    assign reg_rd_en3 = (!reg_switch) ? (reg_rd_en_high && ~i_switch_req[3] && ~i_hold) : reg_rd_en_extra2; 
    assign din3 = (!reg_switch) ? din_high : din_extra2; 
    assign reg_wr_en4 = (reg_switch) ? (reg_wr_en_high && ~i_switch_req[3] && ~i_hold) : reg_wr_en_extra2; 
    assign reg_rd_en4 = (reg_switch) ? (reg_rd_en_high && ~i_switch_req[3] && ~i_hold) : reg_rd_en_extra2; 
    assign din4 = (reg_switch) ? din_high : din_extra2; 
    
    assign reg_reset13 = interlg_reset || ((!reg_switch) ? reg_reset_fifo : reg_reset_extra); 
    assign reg_reset24 = interlg_reset || (( reg_switch) ? reg_reset_fifo : reg_reset_extra); 
    
    assign din_low = i_din[0];
    assign o_dout[0] = dout_low;
    assign din_high = i_din[1];
    assign o_dout[1] = dout_high;
    
    assign reg_rd_en_extra1 = (shuttle_state==S_ST_SAVE && sig_valid_extra1);
    assign reg_rd_en_extra2 = (shuttle_state==S_ST_SAVE && sig_valid_extra2);
    assign rnet_save_en = (shuttle_state==S_ST_IDLE && i_switch_req[3:2]==2'b11) || (shuttle_state>=S_ST_S1 && shuttle_state<=S_ST_S5);
    assign bottom_32 = {shmem_front[1][15:0],shmem_front[0][15:0]}; 
    assign bottom_64 = {shmem_front[1][31:0],shmem_front[0][31:0]}; 
`ifndef SMALL_SYS 
    assign bottom_256 = {
                         shmem_front[1][128+111:128+96],
                         shmem_front[1][128+79:128+64],
                         shmem_front[1][128+47:128+32],
                         shmem_front[1][128+15:128],
`else
    assign bottom_128 = {
`endif
                         shmem_front[1][111:96],
                         shmem_front[1][79:64],
                         shmem_front[1][47:32],
                         shmem_front[1][15:0],
`ifndef SMALL_SYS 
                         shmem_front[0][128+111:128+96],
                         shmem_front[0][128+79:128+64],
                         shmem_front[0][128+47:128+32],
                         shmem_front[0][128+15:128],
`endif
                         shmem_front[0][111:96],
                         shmem_front[0][79:64],
                         shmem_front[0][47:32],
                         shmem_front[0][15:0]};
    assign shmem_din = shmem_front2;
    
    assign o_rnetstate = reg_rnetstate;
    assign o_is_idle = (shuttle_state == S_ST_IDLE);
    
    assign dout1 = (reg_bypass_ind[0]) ? dout1_bypass2 : (reg_bypass_ind[1]) ? dout1_bypass1 : dout1_fifo;
    assign dout2 = (reg_bypass_ind[0]) ? dout2_bypass2 : (reg_bypass_ind[1]) ? dout2_bypass1 : dout2_fifo;
    assign dout3 = (reg_bypass_ind[0]) ? dout3_bypass2 : (reg_bypass_ind[1]) ? dout3_bypass1 : dout3_fifo;
    assign dout4 = (reg_bypass_ind[0]) ? dout4_bypass2 : (reg_bypass_ind[1]) ? dout4_bypass1 : dout4_fifo;

    always @ (posedge clk) begin

        reg_i_len <= i_len;
        load_data_en[0] <= load_addr_en;
        load_data_en[2:1] <= load_data_en[1:0];
        sh_raddr_cycle_d[0] <= sh_raddr_cycle;
        sh_raddr_cycle_d[1] <= sh_raddr_cycle_d[0];
        load_count_d[0] <= load_count;
        load_count_d[2:1] <= load_count_d[1:0];
        if (init) begin
            base_addr <= i_shuttle_addr;
            sh_waddr_seq <= i_shuttle_addr;
            sh_raddr_seq <= i_shuttle_addr;
        end
        dout1_bypass1 <= din1; dout1_bypass2 <= dout1_bypass1;
        dout2_bypass1 <= din2; dout2_bypass2 <= dout2_bypass1;
        dout3_bypass1 <= din3; dout3_bypass2 <= dout3_bypass1;
        dout4_bypass1 <= din4; dout4_bypass2 <= dout4_bypass1;
        
        // FIFO 관리 state
    
        case (myshifter_state)
        S_MS_INIT:
            // FIFO길이가 변경되거나 계층의 처음에는 무조건 FIFO 초기화 하고 감
            if (i_len!=reg_i_len || (i_switch_req[3] && i_topmost)) begin
                if (i_len>9'd4) begin
                    reg_wr_en_low <= 1'b0;
                    reg_rd_en_low <= 1'b0;
                    reg_wr_en_high <= 1'b0;
                    reg_rd_en_high <= 1'b0;
                    reg_len <= i_len - 2'd3;
                    rst_delay <= 3'h1;
                    reg_reset_fifo <= 1'b1;
                    reg_bypass_ind <= 2'b00;
                    myshifter_state <= S_MS_RESET;
                end else begin
                    if (i_len==9'd4)        reg_bypass_ind <= 2'b01;
                    else if (i_len==9'd3)   reg_bypass_ind <= 2'b10;
                    else                    reg_error <= 1'b1;
                end
            end else
                reg_reset_fifo <= 1'b0;
        S_MS_RESET:
            if (rst_delay==3'h0) begin
                if (sig_data_count_low==10'h0 && sig_data_count_high==10'h0) begin
                    reg_wr_en_low <= 1'b1;
                    reg_wr_en_high <= 1'b1;
                    reg_reset_fifo <= 1'b0;
                    myshifter_state <= S_MS_FILLING;
                end
            end else
                rst_delay <= rst_delay - 1'b1;
        S_MS_FILLING:
            if (sig_data_count_low[8:0]>=reg_len) begin
                if (sig_valid_low==1'b0) reg_error <= 1'b1;
                reg_rd_en_low <= 1'b1;
                reg_rd_en_high <= 1'b1;
                myshifter_state <= S_MS_INIT;
            end
        endcase
        
        reg_save_done <= (shuttle_state==S_ST_SAVE && !sig_valid_extra1);
        reg_load_done <= (shuttle_state==S_ST_LOAD && load_data_en[2:1]==2'b10);
        save_en <= (reg_rd_en_extra1 || rnet_save_en);
        
        // read/write state
        
        case (shuttle_state)
        S_ST_IDLE:
            if (i_switch_req[3] || i_switch_req[1]) begin
                reg_switch <= ~reg_switch;
                reg_switch_req <= i_switch_req;
                // fifo has to stop at this moment
                reg_rnetstate <= i_rnetstate;
                reg_mode_bits <= i_mode_bits;
                if (i_switch_req[2]) begin  // save
                    shmem_front[1] <= i_rnetstate[3];
                    shmem_front[0] <= i_rnetstate[0];
                    shuttle_state <= S_ST_S1;
                end else if (i_switch_req[1]) begin // load
                    load_addr_en <= 1'b1;
                    sh_raddr_cycle <= 3'h0;
                    load_count <= 16'h0;
                    // (W-1) = (len + 4)
                    load_len <= 13'd3 + i_len;
                    shuttle_state <= S_ST_LOAD;
                end
            end
        S_ST_S1: begin
                shmem_front[1] <= reg_rnetstate[4];
                shmem_front[0] <= reg_rnetstate[1];
                shuttle_state <= S_ST_S2;
            end
        S_ST_S2: begin
                shmem_front[1] <= reg_rnetstate[5];
                shmem_front[0] <= reg_rnetstate[2];
                shuttle_state <= S_ST_S3;
            end
        S_ST_S3: begin
                shmem_front[1] <= reg_rnetstate[9];
                shmem_front[0] <= reg_rnetstate[6];
                shuttle_state <= S_ST_S4;
            end
        S_ST_S4: begin
                shmem_front[1] <= reg_rnetstate[10];
                shmem_front[0] <= reg_rnetstate[7];
                shuttle_state <= S_ST_S5;
            end
        S_ST_S5: begin
                shmem_front[1] <= reg_rnetstate[11];
                shmem_front[0] <= reg_rnetstate[8];
                shuttle_state <= S_ST_SAVE;
            end
        S_ST_SAVE: begin
                if (!sig_valid_extra1) begin    // loop until the FIFO is empty
                    if (reg_switch_req[1]) begin    // if loading was also requested
                        load_addr_en <= 1'b1;
                        sh_raddr_cycle <= 3'h0;
                        load_count <= 16'h0;
                        // (W - 1) = (len + 4)
                        load_len <= 13'd3 + i_len;
                        shuttle_state <= S_ST_LOAD;
                    end else
                        shuttle_state <= S_ST_IDLE;
                end else begin
                    shmem_front[1] <= dout_extra2;  // the output of FIFO
                    shmem_front[0] <= dout_extra1;
                end
            end
        S_ST_LOAD:
            if (load_data_en[2:1]==2'b10) begin
                if (reg_switch_req[4]) begin
                    sh_raddr_seq <= base_addr;  // reset loading address
                end else begin
                    if (sh_raddr_cycle!=3'h0) begin
                        sh_raddr_seq <= sh_raddr_seq + 1'b1;
                    end
                end
                sh_raddr_cycle <= 3'h0;
                shuttle_state <= S_ST_IDLE;
            end
        endcase
        
        case (reg_mode_bits)
`ifndef SMALL_SYS 
        2'b00: shmem_front2 <= {16{bottom_32}};     // 3x3 s1
        2'b01: shmem_front2 <= {8{bottom_64}};      // 3x3 s2
        2'b10: shmem_front2 <= {2{bottom_256}};     // DW 3x3 s1 (N_RECEPTOR * 32 bits)
        2'b11: shmem_front2 <= shmem_front;         // DW 3x3 s2
`else
        2'b00: shmem_front2 <= {8{bottom_32}};   // 3x3 s1
        2'b01: shmem_front2 <= {4{bottom_64}};   // 3x3 s2
        2'b10: shmem_front2 <= {2{bottom_128}};  // DW 3x3 s1
        2'b11: shmem_front2 <= shmem_front;      // DW 3x3 s2
`endif
        endcase

        if (save_en) begin
            case (reg_mode_bits)
            2'b00: begin    // 3x3 s1
`ifndef SMALL_SYS 
                    for (i=0; i<16; i=i+1) shmem_we[i] <= (i==integer'(sh_waddr_cycle));
                    if (sh_waddr_cycle==4'd15) begin
                        sh_waddr_seq <= sh_waddr_seq + 1'b1;
                        sh_waddr_cycle <= 4'd0;
                    end else
                        sh_waddr_cycle <= sh_waddr_cycle + 1'b1;
`else
                    case (sh_waddr_cycle)
                    3'b000: shmem_we <= 8'b00000001;
                    3'b001: shmem_we <= 8'b00000010;
                    3'b010: shmem_we <= 8'b00000100;
                    3'b011: shmem_we <= 8'b00001000;
                    3'b100: shmem_we <= 8'b00010000;
                    3'b101: shmem_we <= 8'b00100000;
                    3'b110: shmem_we <= 8'b01000000;
                    3'b111: begin
                            shmem_we <= 8'b10000000;
                            sh_waddr_seq <= sh_waddr_seq + 1'b1;
                        end
                    endcase
                    sh_waddr_cycle <= (sh_waddr_cycle==3'b111) ? 3'h0 : sh_waddr_cycle + 1'b1;
`endif
                end
            2'b01: begin    // 3x3 s2
`ifndef SMALL_SYS 
                    for (i=0; i<16; i=i+1) shmem_we[i] <= ((i/2)==integer'(sh_waddr_cycle[2:0]));
                    if (sh_waddr_cycle[2:0]==3'd7) begin
                        sh_waddr_seq <= sh_waddr_seq + 1'b1;
                        sh_waddr_cycle <= 4'd0;
                    end else
                        sh_waddr_cycle <= sh_waddr_cycle + 1'b1;
`else
                    sh_waddr_cycle[2] <= 1'b0;
                    case (sh_waddr_cycle[1:0])
                    2'b00: shmem_we <= 8'b00000011;
                    2'b01: shmem_we <= 8'b00001100;
                    2'b10: shmem_we <= 8'b00110000;
                    2'b11: begin
                            shmem_we <= 8'b11000000;
                            sh_waddr_seq <= sh_waddr_seq + 1'b1;
                        end
                    endcase
                    sh_waddr_cycle <= (sh_waddr_cycle==3'b011) ? 3'h0 : sh_waddr_cycle + 1'b1;
`endif
                end
            2'b10: begin // DW 3x3 s1
`ifndef SMALL_SYS 
                    sh_waddr_cycle[3:1] <= 3'b000;
                    case (sh_waddr_cycle[0])
                    1'b0: shmem_we <= 16'b0000000011111111;
                    1'b1: begin
                            shmem_we <= 16'b1111111100000000;
`else
                    sh_waddr_cycle[2:1] <= 2'b00;
                    case (sh_waddr_cycle[0])
                    1'b0: shmem_we <= 8'b00001111;
                    1'b1: begin
                            shmem_we <= 8'b11110000;
`endif
                            sh_waddr_seq <= sh_waddr_seq + 1'b1;
                        end
                    endcase
                    sh_waddr_cycle[0] <= ~sh_waddr_cycle[0];
                end
            2'b11: begin // DW 3x3 s2
`ifndef SMALL_SYS 
                    sh_waddr_cycle <= 4'b0000;
                    shmem_we <= 16'hffff;
`else
                    sh_waddr_cycle <= 3'b000;
                    shmem_we <= 8'hff;
`endif
                    sh_waddr_seq <= sh_waddr_seq + 1'b1;
                end
            endcase
            sh_waddr <= sh_waddr_seq;
        end else
            shmem_we <= 8'h0;
            
`ifndef SMALL_SYS 
        if (reg_save_done && sh_waddr_cycle!=4'h0) begin
            sh_waddr_cycle <= 4'h0;
`else
        if (reg_save_done && sh_waddr_cycle!=3'h0) begin
            sh_waddr_cycle <= 3'h0;
`endif
            sh_waddr_seq <= sh_waddr_seq + 1'b1;
        end

            
        if (load_addr_en) begin
            case (reg_mode_bits)
            2'b00: begin    // 3x3 s1
`ifndef SMALL_SYS 
                    if (sh_raddr_cycle==4'b1111) begin
                        sh_raddr_cycle <= 4'h0;
`else
                    if (sh_raddr_cycle==3'b111) begin
                        sh_raddr_cycle <= 3'h0;
`endif
                        sh_raddr_seq <= sh_raddr_seq + 1'b1;
                    end else
                        sh_raddr_cycle <= sh_raddr_cycle + 1'b1;
                end
            2'b01: begin    // 3x3 s2
                    sh_raddr_cycle[2] <= 1'b0;
`ifndef SMALL_SYS 
                    if (sh_raddr_cycle[2:0]==3'b111) begin
`else
                    if (sh_raddr_cycle[1:0]==2'b11) begin
`endif
                        sh_raddr_cycle <= 3'h0;
                        sh_raddr_seq <= sh_raddr_seq + 1'b1;
                    end else
                        sh_raddr_cycle <= sh_raddr_cycle + 1'b1;
                end
            2'b10: begin // DW 3x3 s1
`ifndef SMALL_SYS 
                    sh_raddr_cycle[3:1] <= 3'b000;
`else
                    sh_raddr_cycle[2:1] <= 2'b00;
`endif
                    sh_raddr_cycle[0] <= ~sh_raddr_cycle[0];
                    if (sh_raddr_cycle[0]) sh_raddr_seq <= sh_raddr_seq + 1'b1;
                end
            2'b11: begin // DW 3x3 s2
`ifndef SMALL_SYS 
                    sh_raddr_cycle <= 4'b0000;
`else
                    sh_raddr_cycle <= 3'b000;
`endif
                    sh_raddr_seq <= sh_raddr_seq + 1'b1;
                end
            endcase
            if (load_count>=load_len)
                 load_addr_en <= 1'b0;
            else load_count <= load_count + 1'b1;
        end

        if (load_data_en[1]) begin
            case (reg_mode_bits)
            2'b00:  // 3x3 s1
`ifndef SMALL_SYS 
                shmem_load = {240'h0, shmem_dout[unsigned'(sh_raddr_cycle_d[1])][31:16],
                              240'h0, shmem_dout[unsigned'(sh_raddr_cycle_d[1])][15:0]};
`else
                shmem_load = {112'h0, shmem_dout[unsigned'(sh_raddr_cycle_d[1])][31:16],
                              112'h0, shmem_dout[unsigned'(sh_raddr_cycle_d[1])][15:0]};
`endif
            2'b01:  // 3x3 s2
`ifndef SMALL_SYS 
                shmem_load <= {224'h0,shmem_dout[unsigned'(sh_raddr_cycle_d[1])*2+1],
                               224'h0, shmem_dout[unsigned'(sh_raddr_cycle_d[1])*2]};
`else
                shmem_load <= {96'h0,shmem_dout[unsigned'(sh_raddr_cycle_d[1])*2+1],
                               96'h0, shmem_dout[unsigned'(sh_raddr_cycle_d[1])*2]};
`endif
            2'b10:  // DW 3x3 s1
                case (sh_raddr_cycle_d[1][0])
`ifndef SMALL_SYS 
                1'b0: shmem_load <= { shmem_dout[7][31:16],shmem_dout[7][31:16],
                                      shmem_dout[7][15:0],shmem_dout[7][15:0],
                                      shmem_dout[6][31:16],shmem_dout[6][31:16],
                                      shmem_dout[6][15:0],shmem_dout[6][15:0],
                                      shmem_dout[5][31:16],shmem_dout[5][31:16],
                                      shmem_dout[5][15:0],shmem_dout[5][15:0],
                                      shmem_dout[4][31:16],shmem_dout[4][31:16],
                                      shmem_dout[4][15:0],shmem_dout[4][15:0],
                                      shmem_dout[3][31:16],shmem_dout[3][31:16],
`else
                1'b0: shmem_load <= { shmem_dout[3][31:16],shmem_dout[3][31:16],
`endif
                                      shmem_dout[3][15:0],shmem_dout[3][15:0],
                                      shmem_dout[2][31:16],shmem_dout[2][31:16],
                                      shmem_dout[2][15:0],shmem_dout[2][15:0],
                                      shmem_dout[1][31:16],shmem_dout[1][31:16],
                                      shmem_dout[1][15:0],shmem_dout[1][15:0],
                                      shmem_dout[0][31:16],shmem_dout[0][31:16],
                                      shmem_dout[0][15:0],shmem_dout[0][15:0]};
`ifndef SMALL_SYS 
                1'b1: shmem_load <= { shmem_dout[15][31:16],shmem_dout[7][31:16],
                                      shmem_dout[15][15:0],shmem_dout[7][15:0],
                                      shmem_dout[14][31:16],shmem_dout[6][31:16],
                                      shmem_dout[14][15:0],shmem_dout[6][15:0],
                                      shmem_dout[13][31:16],shmem_dout[5][31:16],
                                      shmem_dout[13][15:0],shmem_dout[5][15:0],
                                      shmem_dout[12][31:16],shmem_dout[4][31:16],
                                      shmem_dout[12][15:0],shmem_dout[4][15:0],
                                      shmem_dout[11][31:16],shmem_dout[3][31:16],
                                      shmem_dout[11][15:0],shmem_dout[3][15:0],
                                      shmem_dout[10][31:16],shmem_dout[2][31:16],
                                      shmem_dout[10][15:0],shmem_dout[2][15:0],
                                      shmem_dout[9][31:16],shmem_dout[1][31:16],
                                      shmem_dout[9][15:0],shmem_dout[1][15:0],
                                      shmem_dout[8][31:16],shmem_dout[0][31:16],
                                      shmem_dout[8][15:0],shmem_dout[0][15:0]};
`else
                1'b1: shmem_load <= { shmem_dout[7][31:16],shmem_dout[7][31:16],
                                      shmem_dout[7][15:0],shmem_dout[7][15:0],
                                      shmem_dout[6][31:16],shmem_dout[6][31:16],
                                      shmem_dout[6][15:0],shmem_dout[6][15:0],
                                      shmem_dout[5][31:16],shmem_dout[5][31:16],
                                      shmem_dout[5][15:0],shmem_dout[5][15:0],
                                      shmem_dout[4][31:16],shmem_dout[4][31:16],
                                      shmem_dout[4][15:0],shmem_dout[4][15:0]};
`endif
                endcase
            2'b11:   // DW 3x3 s2
`ifndef SMALL_SYS 
                shmem_load[511:0] <= {
                    shmem_dout[15],shmem_dout[14],shmem_dout[13],shmem_dout[12],
                    shmem_dout[11],shmem_dout[10],shmem_dout[9],shmem_dout[8],
`else
                shmem_load[255:0] <= {
`endif
                    shmem_dout[7],shmem_dout[6],shmem_dout[5],shmem_dout[4],
                    shmem_dout[3],shmem_dout[2],shmem_dout[1],shmem_dout[0]};
            endcase
        end
        
        // shortcut to improve time closure
        case (load_count_d[1])
        13'd0:   load_count_d_2 <= 3'd0;
        13'd1:   load_count_d_2 <= 3'd1;
        13'd2:   load_count_d_2 <= 3'd2;
        13'd3:   load_count_d_2 <= 3'd3;
        13'd4:   load_count_d_2 <= 3'd4;
        13'd5:   load_count_d_2 <= 3'd5;
        default: load_count_d_2 <= 3'd6;
        endcase 

        if (load_data_en[2]) begin
            case (load_count_d_2)
            3'd0: 
                begin
                    reg_reset_extra <= 1'b1;
`ifndef SMALL_SYS 
                    reg_rnetstate[3] <= shmem_load[511:256];
                    reg_rnetstate[0] <= shmem_load[255:0];
`else
                    reg_rnetstate[3] <= shmem_load[255:128];
                    reg_rnetstate[0] <= shmem_load[127:0];
`endif
                end
            3'd1:
                begin
`ifndef SMALL_SYS 
                    reg_rnetstate[4] <= shmem_load[511:256];
                    reg_rnetstate[1] <= shmem_load[255:0];
`else
                    reg_rnetstate[4] <= shmem_load[255:128];
                    reg_rnetstate[1] <= shmem_load[127:0];
`endif
                end
            3'd2:
                begin
`ifndef SMALL_SYS 
                    reg_rnetstate[5] <= shmem_load[511:256];
                    reg_rnetstate[2] <= shmem_load[255:0];
`else
                    reg_rnetstate[5] <= shmem_load[255:128];
                    reg_rnetstate[2] <= shmem_load[127:0];
`endif
                end
            3'd3:
                begin
`ifndef SMALL_SYS 
                    reg_rnetstate[9] <= shmem_load[511:256];
                    reg_rnetstate[6] <= shmem_load[255:0];
`else
                    reg_rnetstate[9] <= shmem_load[255:128];
                    reg_rnetstate[6] <= shmem_load[127:0];
`endif
                end
            3'd4:
                begin
`ifndef SMALL_SYS 
                    reg_rnetstate[10] <= shmem_load[511:256];
                    reg_rnetstate[7] <= shmem_load[255:0];
`else
                    reg_rnetstate[10] <= shmem_load[255:128];
                    reg_rnetstate[7] <= shmem_load[127:0];
`endif
                end
            3'd5:
                begin
`ifndef SMALL_SYS 
                    reg_rnetstate[11] <= shmem_load[511:256];
                    reg_rnetstate[8] <= shmem_load[255:0];
`else
                    reg_rnetstate[11] <= shmem_load[255:128];
                    reg_rnetstate[8] <= shmem_load[127:0];
`endif
                end
            default:
                begin
                    reg_reset_extra <= 1'b0;
`ifndef SMALL_SYS 
                    din_extra2 <= shmem_load[511:256];
                    din_extra1 <= shmem_load[255:0];
`else
                    din_extra2 <= shmem_load[255:128];
                    din_extra1 <= shmem_load[127:0];
`endif
                    reg_wr_en_extra2 <= 1'b1;
                    reg_wr_en_extra1 <= 1'b1;
                end
            endcase
            
        end else begin
            reg_reset_extra <= 1'b0;
            reg_wr_en_extra1 <= 1'b0;
            reg_wr_en_extra2 <= 1'b0;
        end 
        
        if (interlg_reset) begin
            myshifter_state <= S_MS_INIT;
            shuttle_state <= S_ST_IDLE;
            base_addr <= 13'h0;
            sh_waddr_seq <= 13'h0;
            sh_raddr_seq <= 13'h0;
        end
        
    end
    
endmodule
