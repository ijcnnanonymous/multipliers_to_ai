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
// Create Date: 2020/10/03 14:17:34
// Design Name: Receptor Unit for 128 half precision multiplication system
// Module Name: receptor
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description:Receptor Unit converting input data stream to k x k receptor data stream 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//      For explanations of the source code, please subscribe to YouTube @fpgalover. 
//      For efficient custom AI hardware design, please contact the author.
//	Don't waste your time and ask us for help.
//////////////////////////////////////////////////////////////////////////////////
                                                                      
// i_rc_mode specification; 5:reserved 4:reserved 3:1x1 2:3x3 1:dw 0:stride2

module receptor # (
        parameter C_MXNUM = 32,
        parameter DATA_WIDTH = 16,
`ifndef SMALL_SYS
        parameter N_RECEPTOR = 8
`else
        parameter N_RECEPTOR = 4
`endif
    ) 
    (
        //== command from control unit via NU
        input i_rc_readstart = 1'b0, // command for starting to read
        input [5:0] i_rc_mode = 6'h0, // indicates the type of read
        input [9:0] i_rc_sx_m1 = 10'h0, // W - 1
        input [9:0] i_rc_sy_m1 = 10'h0, // H - 1 (full map)
        input [9:0] i_rc_o_sxm1 = 10'h0,    // W - 1 for s1, [(W+1)/2] - 1 for s2
        input [9:0] i_rc_o_sym1 = 10'h0,    // H - 1 for s1, [(H+1)/2] - 1 for s2
        input [17:0] i_rc_imsize,
        input [17:0] i_ickpim_m1,
        input [17:0] i_ockpim_m1,
        input [12:0] i_n_c_m1,  // number of (repeating) channels
        input [12:0] i_n_f_m1,  // number of (repeating) feature maps
        input [15:0] i_n_map_m1,    // number of maps = n_c * n_f - 1
        input [3:0] i_rstate_addr,  // state index
        input [12:0] i_shuttle_addr,  // shuttle memory base address
        input i_topmost = 1'b0, // flag indicating the first fragmentation
        input i_wait_save = 1'b0, // flag indicating the first fragmentation
        //== NU controls 
        // the input command and parameters are sent back to NU to make it in action
        output o_rc_readstart,  // start command for NU
        output o_rc_bottommost,
        output [17:0] o_rc_im_left,
        output [17:0] o_rc_oim_left,
        //== input from NU
        // data read from MX memories in the NU
        input i_rc_valid = 1'b0,    // data validity
        input i_rc_firstf_a2 = 1'b0,   // the first of data
        input i_rc_lastf_a2 = 1'b0,    // the last of data
//        input [15:0] i_rc_seq = 1'b0,   // data sequence
        input [N_RECEPTOR*4-1:0][DATA_WIDTH-1:0] i_rc_dout = 0, // [16][16]
        //== the output of the receptor
        output o_rc_out_valid,  // output validity
        output [15:0] o_rc_out_seq, // output data sequence (in full map)
        output [15:0] o_rc_out_seq_partial, // output data sequence (in partial map)
        output [9:0] o_row_i,
        output [9:0] o_col_i,
        output o_first_chan,
        output o_last_chan,
        output o_o_firstf,
        output o_o_lastf,
        output [N_RECEPTOR*9-1:0][DATA_WIDTH-1:0] o_rc_data,   // output data
        output o_done,
        output o_all_done,
        output o_is_shuttle_idle,
        // common
        input interlg_reset,
        input reset_n = 1'b1,
        input clk
    );
    
    localparam DUAL_WIDTH = DATA_WIDTH * 2; // 16 * 2 = 32
    localparam REC_WIDTH = N_RECEPTOR * DUAL_WIDTH;
    
    enum bit [3:0]  {S_RC_IDLE, S_RC_PRELOAD, S_RC_LOADING1, S_RC_LOADING2, S_RC_READING, S_RC_PAUSE, S_RC_FLUSHING, S_RC_CLEAR_STATE} rc_state = S_RC_IDLE;
    
    logic [3:0][2:0][REC_WIDTH-1:0] receptornet = 0;    // receptor net
    logic [2:0][REC_WIDTH-1:0] sr_din;  // wires between receptornet and FIFO input
    logic [2:0][REC_WIDTH-1:0] sr_dout; // wires for FIFO output and receptornet 
    logic [9:0] fifo_len = 10'h0;   // the length of FIFO (W - 1)
    logic [1:0] reg_fast_trackf;   // flag if W<3 in which case FIFO is not used
    logic [10:0] reg_loading_delay, reg_loading_count = 11'h0;  // delay in S_RC_LOADING2 state (from the first 
    logic [9:0] reg_col_i;  // internal state for column
    logic [9:0] reg_row_i;  // internal state for row
    logic [2:0][9:0] reg_col_i_1, reg_row_i_1;
    logic reg_col_last = 0, reg_o_sx_one = 0;
    logic [9:0] reg_o_sxm1, reg_o_sxm2, reg_o_sym1; // repeater register for i_o_sxm1 and i_o_sym1 
    logic [17:0] reg_im_left, reg_ickpim, reg_ockpim, reg_oim_left;
    logic is_last_block = 1'b0, is_single_block = 1'b0;
    logic [5:0] xmask, ymask = 6'h0;    // mask bits
    logic [9:0] xmaskbit_left = 0, ymaskbit_left = 0;   // the numbers of remaining 1 bits in the x and y masks
    logic reg_rc_out_valid_0;// = 1'b0;    // output valid signals
    logic [3:0] reg_rc_out_valid_1 = 0;    // output valid signals
    logic [15:0] reg_rc_out_seq_0, reg_out_seq; // output sequence
    logic [2:0][15:0] reg_rc_out_seq_1; // output sequence
    logic [N_RECEPTOR*24-1:0][DATA_WIDTH-1:0] reg_rc_data_1 = 0;
    logic [N_RECEPTOR*9-1:0][DATA_WIDTH-1:0] reg_rc_data_2 = 0;
    logic [N_RECEPTOR*9-1:0][DATA_WIDTH-1:0] reg_rc_data_3 = 0;
    // shortcuts
    logic [1:0] sig_even_stride2;   // {sy_even, sx_even}
    logic [15:0] reg_n_map_m2;  // i_n_map_m1 - 1
    // counters
    logic [12:0] load_chseq = 13'h0;    // channel sequence (loading time based)
    logic [12:0] lastf_chseq = 13'h0;   // channel sequence (i_rc_lastf based)
    logic [12:0] fmap_seq = 13'h0;     // feature map sequence (i_rc_lastf based)
    logic [15:0] ch_count = 16'h0;  // overall channel count (i_rc_lastf based)
    // repeaters
    logic [14:0] reg_rc_baseaddr = 15'h0;   // bypass register
    logic [5:0] reg_rc_mode = 6'h0; // mode of the block
    logic reg_rc_readstart = 1'b0;  // temp signal for NU start flag
    logic start_saving = 1'b0, start_loading = 1'b0, switch_receptor = 1'b0, reset_loading = 1'b0;  // shifter flags
    logic sig_save_done, sig_load_done; // shfter return signals
    logic save_states = 1'b0, load_states = 1'b0;   // save and load state commands
    logic [3:0][2:0][REC_WIDTH-1:0] sig_rnetstate;  // shifter's receptornet output 
    logic [103:0] rstate_din, rstate_dout;   // receptor state memory interface
    logic rstate_we;    // state memory write enable
    logic reg_hold_fifo = 1'b0; // signal temporally holding shifter
    logic reg_all_done = 1'b0, reg_done = 1'b0, reg_firstchan = 1'b0, reg_lastchan = 1'b0;
    logic [2:0] reg_firstchan_1, reg_lastchan_1;
    logic reg_o_lastf;
    logic [2:0] reg_o_lastf_1;
    logic [2:0] reg_firstf, reg_lastf;
    logic [4:0] switch_req;
    logic pause_receptor = 1'b0, set_delayed_switch;
    logic [3:0] reg_rstate_addr;  // state index
    logic switch_sent;
    logic [12:0] reg_n_c_m1;    // repeater for i_n_c_m1
    logic [12:0] reg_n_f_m1;    // repeater for i_n_f_m1
    logic [15:0] reg_n_map_m1;  // repeater for i_n_map_m1
    logic [9:0] reg_rc_sx_m1, reg_rc_sy_m1;

    logic switch_receptor_d, start_saving_d, start_loading_d, reset_loading_d, save_states_d, load_states_d, last_ch_d;
    //
    integer i, j, k;    // loop valiables
    
    // Shifter provides FIFO function for two rows each with up to (N_RECEPTORS * 2 * 16) bits
    
    recep_shiter # (
        .DATA_WIDTH(DATA_WIDTH),
        .N_RECEPTOR(N_RECEPTOR)
    ) shifter (
        .i_din({sr_din[1], sr_din[0]}), // FIFO input for each row
        .i_rnetstate(receptornet),  // additional info for receptornet data (4x3 array)
        .o_dout({sr_dout[1], sr_dout[0]}),  // FIFO output for each row
        .o_rnetstate(sig_rnetstate),    // additional info for receptornet data (4x3 array)
        // input commands
        .i_topmost(i_topmost),
        .i_switch_req(switch_req),
        // output flags
        .o_save_done(sig_save_done),    // save operation has done
        .o_load_done(sig_load_done),    // load operation has done
        // additional control signals
        .i_len(fifo_len[8:0]),  // length of the FIFOs
        .i_mode_bits({reg_rc_mode[1:0]}),    // {DW, S2}
        // 
        .init(i_rc_readstart==1'b1 && i_rc_mode[2]),  // timing to set memory base address
        .i_shuttle_addr(i_shuttle_addr),    // base address for shuttle memory
        .i_hold((reg_hold_fifo && ~reg_firstf[1]) || pause_receptor), // hold shifting
        .o_is_idle(o_is_shuttle_idle),
        .interlg_reset(interlg_reset),
        .clk(clk)
    );
    
    // State memory (up to 16 states each with 80 bits)
    // need to check as there can be a read-write conflict
    
    receptor_state_mem rstate_mem (
      .a(reg_rstate_addr),        // input wire [3 : 0] a
      .d(rstate_din),        // input wire [149 : 0] d
      .dpra(i_rstate_addr),  // input wire [3 : 0] dpra
      .clk(clk),    // input wire clk
      .we(rstate_we),      // input wire we
      .dpo(rstate_dout)    // output wire [149 : 0] dpo
    );
    
    assign reg_rc_out_valid_0 = (rc_state==S_RC_READING);
    
    always @ (posedge clk) begin
        
        if (reset_n==1'b0) begin
        
            reg_rc_readstart <= 1'b0;
            rc_state <= S_RC_IDLE;
            
        end else begin

            reg_n_c_m1 <= i_n_c_m1;
            reg_n_f_m1 <= i_n_f_m1;
            reg_n_map_m1 <= i_n_map_m1;
            reg_rc_sx_m1 <= i_rc_sx_m1;
            reg_rc_sy_m1 <= i_rc_sy_m1;
            
            // in the case of topmost block, issue readstart immediately after i_rc_readstart
            // in the following blocks, issue readstart only after the first loading is complete
            reg_rc_readstart <= (
                (rc_state==S_RC_IDLE && (i_rc_mode[3] || i_topmost) && i_rc_readstart) || 
                (rc_state==S_RC_PRELOAD && sig_load_done)
            );
            
            // set repeator
            reg_n_map_m2 <= reg_n_map_m1 - 1'b1;
            reg_firstchan <= (rc_state==S_RC_READING && (i_rc_mode[1] || lastf_chseq==13'd0));
            reg_lastchan <= (rc_state==S_RC_READING && (i_rc_mode[1] || lastf_chseq==i_n_c_m1));
            reg_o_lastf <= (rc_state==S_RC_READING && reg_lastf[2]);

            // implement automata
            
            case (rc_state)
            S_RC_IDLE:
                begin
                    if (i_rc_readstart==1'b1 && ~i_rc_mode[5]) begin
                    // on i_rc_readstart, 
                    //      issue readstart command if is is a topmost block
                    //      otherwise, defer issuing the readstart until first loading is finished
                    // freezes variables at this time
                        reg_rc_mode <= i_rc_mode;
                        reg_o_sxm1 <= i_rc_o_sxm1;
                        reg_o_sxm2 <= i_rc_o_sxm1 - 1'b1;
                        reg_o_sx_one <= (i_rc_o_sxm1==10'd0);
                        reg_o_sym1 <= i_rc_o_sym1;
                        reg_ickpim <= i_ickpim_m1 + 1'b1;
                        reg_ockpim <= i_ockpim_m1 + 1'b1;
                        // define reg_fast_trackf and fifo_len
                        case (i_rc_o_sxm1)
                        10'd0: reg_fast_trackf <= 2'b00;
                        10'd1: reg_fast_trackf <= 2'b01;
                        10'd2: reg_fast_trackf <= 2'b10;
                        default: reg_fast_trackf <= 2'b11;
                        endcase
                        fifo_len <= i_rc_o_sxm1[9:0]; // sx - 1
                        // preset delay count in S_RC_LOADING2 state:
                        //      time between the first data in the receptornet and the first data extraction
                        reg_loading_delay <= (i_rc_mode[0] && !reg_rc_sy_m1[0]) ? 11'h0 : {1'b0, i_rc_o_sxm1 + 1'b1};
                        // clear counters
                        ch_count <= 16'h0;  // overall channel count (i_rc_lastf based)
                        load_chseq <= 13'h0;    // channel sequence (loading time based)
                        lastf_chseq <= 13'h0;   // channel sequence (i_rc_lastf based)
                        fmap_seq <= 13'h0;     // feature map sequence (i_rc_lastf based)
                        reg_all_done <= 1'b0;
                        // state transits only in 3x3 convolution
                        if (i_rc_mode[2]) begin
                            if (i_topmost) begin    // if topmost, fill receptornet first
                                rc_state <= S_RC_LOADING1;
                            end else begin          // if not topmost, load FIFO first
                                rc_state <= S_RC_PRELOAD;
                            end
                        end else
                            rc_state <= S_RC_LOADING1;
                        if (i_topmost) begin
                            reg_im_left <= i_rc_imsize;
                            reg_oim_left <= i_rc_imsize;
                        end
                    end
                    reg_done <= 1'b0;
                end
            S_RC_PRELOAD:   // 로딩이 완료되기를 기다리는 타이밍
                if (sig_load_done) begin    // if loading is done, proceed
                    rc_state <= S_RC_LOADING1;
                end
            S_RC_LOADING1:  // NU에서 유효한 데이터를 기다리는 타이밍
                begin
                    // S_RC_LOADING1 상태에서는 NU로부터 첫 번째 valid 한 입력이 들어오면
                    //      3x3 Conv단계이면 topmost 일 때 S_RC_LOADING2 상태로 천이하고 ~topmost  이면 S_RC_READING으로 천이
                    //      1x1 conv 단계이면 S_RC_READING 상태로 천이
                    // S_RC_READING로 천이할 때 reg_rc_out_valid_0 = 1
                    if (reg_firstf[1]) begin
                        if (reg_rc_mode[2]) begin    // 3x3
                            // mask가 끝부분 padding을 위해 0로 채워지기 시작하는 타이밍
                            
                            // 지정된 지연값 만큼 카운트 시작 
                            if (i_topmost) begin
                                reg_loading_count <= reg_loading_delay;
                                rc_state <= S_RC_LOADING2;
                            end else
                                // timing for load states
                                rc_state <= S_RC_READING;
                        end else if (reg_rc_mode[3]) begin   // 1x1
                            if (i_topmost) begin
                                reg_rc_out_seq_0 <= 16'h0;
                                reg_row_i <= 10'h0;
                                reg_col_i <= 10'h0;
                                reg_col_last <= 1'b0;
                            end
                            rc_state <= S_RC_READING;
                        end
                    end
                    pause_receptor <= 1'b0;
                end
            // 첫 데이터가 receptornet에 들어간 후 첫 출력데이터를 뽑을 수 있을 때까지 대기하는 상태
            // 대기하는 길이는 reg_loading_delay에 의해 정해진다.
            // Topmost block 일때만 이 상태를 거친다.
            S_RC_LOADING2:
                begin
                    // S_RC_LOADING2 상태에서 지연 타이머가 끝나면 S_RC_READING 상태로 천이하면서
                    // 행과 열 마스크를 시작하고 행과 열 변수를 초기화 하며
                    // 데이터를 추출하면서 필요한 변수를 설정함. 이 시점부터 데이터가 추출 됨.
                    if (reg_loading_count==11'h0) begin   
//                      ISSUE Init XMASK
//                      ISSUE Init YMASK
                        reg_row_i <= 10'h0;
                        reg_col_i <= 10'h0;
                        reg_col_last <= 1'b0;
                        reg_rc_out_seq_0 <= 16'h0;
                        rc_state <= S_RC_READING;
                    end else
                        reg_loading_count <= reg_loading_count - 1'b1;
                end
            S_RC_READING:
                begin
                    // the order of following code blocks matter
                    // (1)

                    if (reg_o_sx_one || reg_col_last) begin //reg_col_i==reg_o_sxm1) begin 
                        reg_col_i <= 10'h0;
                        reg_col_last <= 1'b0;
                        reg_row_i <= reg_row_i + 1'b1;
                    end else begin
                        reg_col_i <= reg_col_i + 1'b1;
                        reg_col_last <= (reg_col_i==reg_o_sxm2);
                    end
                        
                        
                    // (2-0) - seq의 마지막에서 두 번째 포인트
                    
                    // 다음 데이터가 연속해서 오거나 마지막 seq에 셔틀이 비어있으면 shifter 신호를 생성
                    if (reg_lastf[1] && ~is_single_block) begin
                        if (reg_rc_mode[3] || i_rc_firstf_a2 || (~(ch_count<reg_n_map_m1) && o_is_shuttle_idle)) begin
                            switch_receptor <= reg_rc_mode[2];
                            start_saving <= (reg_rc_mode[2] && ~is_last_block && fmap_seq==reg_n_f_m1);
                            start_loading <= (reg_rc_mode[2] && ~i_topmost && ch_count<reg_n_map_m2);
                            reset_loading <= (reg_rc_mode[2] && ~i_topmost && load_chseq==i_n_c_m1);
                            save_states <= (ch_count==reg_n_map_m1);
                            load_states <= (~i_topmost && ch_count<reg_n_map_m1);
                            switch_sent <= 1'b1;
                            pause_receptor <= 1'b0;
                        // 아니면 신호를 변수에 저장하고 나중을 기약하기...
                        end else begin
                            switch_receptor_d <= reg_rc_mode[2];
                            start_saving_d <= (reg_rc_mode[2] && ~is_last_block && fmap_seq==reg_n_f_m1);
                            start_loading_d <= (reg_rc_mode[2] && ~i_topmost && ch_count<reg_n_map_m2);
                            reset_loading_d <= (reg_rc_mode[2] && ~i_topmost && load_chseq==i_n_c_m1);
                            save_states_d <= (ch_count==reg_n_map_m1);
                            load_states_d <= (~i_topmost && ch_count<reg_n_map_m1);
                            pause_receptor <= 1'b1;
                            switch_sent <= 1'b0;
                        end
                    end
                        

                    // (2) - seq의 마지막 포인트
                    
                    if (reg_lastf[2]) begin
                    
                        ch_count <= ch_count + 1'b1;
                        last_ch_d <= ~(ch_count<reg_n_map_m1);    // 나중에 분기를 위해 필요함
        
                        // transit to S_RC_LOADING1 and wait for the next map when ch_count<reg_n_map_m1                      
                        // Otherwise, stay in READING state until all data are extracted
                        if (reg_rc_mode[3]) begin
                            if (i_topmost) reg_rc_out_seq_0 <= 16'h0;
                        end
                        if (reg_rc_mode[3] || switch_sent || is_single_block || (i_rc_firstf_a2 && ~switch_sent))
                            rc_state <= (ch_count==reg_n_map_m1) ? S_RC_FLUSHING : S_RC_LOADING1;
                        else
                            rc_state <= S_RC_PAUSE;

                        if (i_rc_firstf_a2 && ~switch_sent) begin
                            switch_receptor <= switch_receptor_d;
                            start_saving <= start_saving_d;
                            start_loading <= start_loading_d;
                            reset_loading <= reset_loading_d;
                            save_states <= save_states_d;
                            load_states <= load_states_d;
                            switch_sent <= 1'b1;
                        end

                        if (lastf_chseq==reg_n_c_m1) begin
                             lastf_chseq <= 13'h0;
                             fmap_seq <= fmap_seq + 1'b1;
                        end else
                            lastf_chseq <= lastf_chseq + 1'b1;
                        
                        if (reg_rc_mode[2] && i_topmost) begin
                            xmask <= 6'h0;
                            xmaskbit_left <= 10'h0;
                            ymask <= 6'h0;
                            ymaskbit_left <= 10'h0;
                        end
                        
                    end else begin
                    
                        reg_rc_out_seq_0 <= reg_rc_out_seq_0 + 1'b1;
                    
                        // manage mask and reg_col_i, reg_row_i
                        
                        // 행카운트, 열카운트를 관리하는 부분
                        // 열 카운트가 마지막에 이르면,
                        if (reg_o_sx_one || reg_col_last) begin //reg_col_i==reg_o_sxm1) begin
//                              ISSUE Init XMASK
                            // 행카운트가 마지막에 이르면,
                            if (reg_row_i!=reg_o_sym1) begin                        
//                                  ISSUE Init YMASK
                                if (reg_rc_mode[2]) begin 
                                    if (reg_rc_mode[0]==1'b0) begin // stride 1
                                        ymask[5:1] <= ymask[4:0];
                                        ymask[0] <= (ymaskbit_left>10'd0) ? 1'b1 : 1'b0;
                                        if (ymaskbit_left>10'd0) ymaskbit_left <= ymaskbit_left - 1'b1;
                                    end else begin
                                        ymask[5:2] <= ymask[3:0];
                                        if (ymaskbit_left==10'd0) ymask[1:0] <= 2'b00;
                                        else if (ymaskbit_left==10'd1) ymask[1:0] <= 2'b10;
                                        else ymask[1:0] <= 2'b11;
                                        ymaskbit_left <= (ymaskbit_left<10'd2) ? 10'h0 : ymaskbit_left - 2'h2;
                                    end
                                end
                            end 
                        end else begin
                            if (reg_rc_mode[2]) begin 
                                // 두 칸씩 이동
                                xmask[5:2] <= xmask[3:0];
                                if (reg_rc_mode[0]==1'b0) begin // stride 1
                                    xmask[1:0] <= (xmaskbit_left>10'd0) ? 2'b11 : 2'b00;
                                    if (xmaskbit_left>10'd0) xmaskbit_left <= xmaskbit_left - 1'b1;
                                end else begin
                                    if (xmaskbit_left==10'd0) xmask[1:0] <= 2'b00;
                                    else if (xmaskbit_left==10'd1) xmask[1:0] <= 2'b10;
                                    else xmask[1:0] <= 2'b11;
                                    xmaskbit_left <= (xmaskbit_left<10'd2) ? 10'h0 : xmaskbit_left - 2'h2;
                                end
                            end
                        end
                    end
                end
            S_RC_PAUSE:
                begin
                    if (~switch_sent && o_is_shuttle_idle) begin
                        switch_receptor <= switch_receptor_d;
                        start_saving <= start_saving_d;
                        start_loading <= start_loading_d;
                        reset_loading <= reset_loading_d;
                        save_states <= save_states_d;
                        load_states <= load_states_d;
                        switch_sent <= 1'b1;
                    end
                    if (switch_sent || o_is_shuttle_idle) begin
                        if (last_ch_d) 
                            rc_state <= S_RC_FLUSHING;
                        else if (reg_firstf[0]) 
                            rc_state <= S_RC_LOADING1;
                        if (last_ch_d || reg_firstf[0]) pause_receptor <= 1'b0;
                    end
                end
            S_RC_FLUSHING:
                begin
                    // 출력데이터가 완전히 빠져 나간 후에 IDLE로 복귀한다.
                    if (!reg_rc_out_valid_0 && !reg_rc_out_valid_1[0] && (reg_rc_mode[3] || !i_wait_save || (is_last_block || sig_save_done))) begin
                        if (reg_row_i>=reg_o_sym1) reg_all_done <= 1'b1;
                        reg_done <= 1'b1;
                        rc_state <= S_RC_IDLE;
                    end
                end
            endcase

            
            // Command signal generation

            // shifter init and pre-loading
            if ((rc_state==S_RC_IDLE && i_rc_readstart==1'b1) || (rc_state==S_RC_PRELOAD && sig_load_done)) begin
                if (i_rc_mode[2] && ~is_single_block) switch_receptor <= 1'b1;
                if (!i_topmost) begin
                    if (i_rc_mode[2] && ~is_single_block) start_loading <= 1'b1;
                    load_states <= 1'b1;
                end
            end

            if (switch_receptor) switch_receptor <= 1'b0;
            if (start_saving)  start_saving <= 1'b0;
            if (start_loading) start_loading <= 1'b0;
            if (reset_loading) reset_loading <= 1'b0;
            if (save_states) save_states <= 1'b0;
            if (load_states) load_states <= 1'b0;
                
            // generate reg_hold_fifo signal
            // 적재 완료 후 유효한 데이터가 들어올 때까지 시프터를 정지시킨다.
            if (i_rc_mode[2] && rc_state==S_RC_PRELOAD && sig_load_done) reg_hold_fifo <= 1'b1;
            if (reg_hold_fifo && reg_firstf[1]) reg_hold_fifo <= 1'b0;

            // 적재를 시작할 때 시점의 채널 sequence를 관리
            if (start_loading) begin
                if (load_chseq==reg_n_c_m1) load_chseq <= 13'h0;
                else                      load_chseq <= load_chseq + 1'b1;
            end

            // init x mask
            // 두 군데서 동일한 xmask 초기화가 필요해서 state automata에서 분리하였음

            if (
                (rc_state==S_RC_LOADING2 && reg_loading_count==11'h0) ||            // Init when block starts
                (reg_rc_mode[2] && rc_state==S_RC_READING && (reg_o_sx_one || reg_col_last)) // reg_col_i==reg_o_sxm1) // Init at the end of row
            ) begin
                // 열 마스크를 초기화
                // 마스크는 입력 W, H를 기준으로 처리되며 stride에 관계 없이 2씩 증가.
                if (reg_rc_mode[0]==1'b0) begin // stride 1
                    // xask 가 두개 비트씩 묶여지므로 두 개의 마스크  비트를 하나로 침
                    // 따라서 두 칸씩 이동한다.
                    // W==1이면 하나의 마스크 비트, 기타 두 개의 마스크비트로 시작
                    xmask <= (reg_rc_sx_m1==10'h0) ? 6'b001100 : 6'b001111;
                    // W>0이면 두 개의 마스크로 시작하므로 남은 비트 수는 W - 2
                    xmaskbit_left <= (reg_rc_sx_m1==10'h0) ? 10'h0 : reg_rc_sx_m1 - 1'b1;
                end else begin // stride 2
                    // x, y가 한비트씩 단위로 두 칸씩 이동한다.
                    case (reg_rc_sx_m1)
                    10'd0: xmask <= 6'b001000;  // 1은 홀수이므로 x010xx 로 시작
                    10'd1: xmask <= 6'b001100;  // 2는 짝수이므로 xx110x 로 시작
                    10'd2: xmask <= 6'b001110;  // 3은 홀수이므로 x0111x 로 시작
                    default: xmask <= 6'b001111;// 4는 짝수이므로 xx1111로 시작, 5는 홀수이므로 1111로 시작 (두 케이스 다 4개 비트 사용)
                    endcase
                    // W<4이면 남은 비트는 0, 기타 남은 비트는 W - 4
                    xmaskbit_left <= (reg_rc_sx_m1<10'd3) ? 10'h0 : reg_rc_sx_m1 - 2'd3;
                end
            end
            
            // init y mask
            // 두 군데서 동일한 ymask 초기화가 필요해서 state automata에서 분리하였음
            
            if (
                (rc_state==S_RC_LOADING2 && reg_loading_count==11'h0) ||        // Init when block starts
                (reg_rc_mode[2] && rc_state==S_RC_READING&& reg_row_i==reg_o_sym1 && (reg_o_sx_one || reg_col_last)) //reg_col_i==reg_o_sxm1 )    // Init ai the end of image
            ) begin
                // 행 마스크를 초기화
                if (reg_rc_mode[0]==1'b0) begin // stride 1
                    // x, ymask 가 두개 비트씩 묶여지며 01,01위치에서만 유효
                    // 따라서 두 칸씩 이동한다.
                    // H==1이면 010으로 시작, 기타 011로 시작
                    ymask <= (reg_rc_sy_m1==10'h0) ? 6'b000010: 6'b000011;
                    // H==1이거나 H==2이면 남은 비트 수는 0, 기타 H - 2
                    ymaskbit_left <= (reg_rc_sy_m1<=10'h1) ? 10'h0 : reg_rc_sy_m1 - 1'b1;
                end else begin // stride 2
                    // x, y가 한비트씩 유효하지만 두 칸씩 이동한다.
                    // H가 홀수개이면 아래 두 줄에서 마스크가 시작하고
                    // 짝수이면 아래 네 줄에서 시작한다.
                    case (reg_rc_sy_m1)
                    10'd0: ymask <= 6'b000010;  // H = 1, 1이 홀수이므로 xxx010가 유효
                    10'd1: ymask <= 6'b001100;  // H = 2, 2가 짝수이므로 xx110x가 유효
                    // H==홀수이면 xxx111에서 패딩한 xxx011로 시작, 짝수이면 패딩이 없는xx111x로 시작
                    default: ymask <= (!reg_rc_sy_m1[0]) ? 6'b000011 : 6'b001111;
                    endcase
                    if (reg_rc_sy_m1[0]) begin
                        // H==짝수이면 처음 4비트로 시작했으므로 남은 비트는 H - 4
                        ymaskbit_left <= (reg_rc_sy_m1<10'd3) ? 10'h0 : reg_rc_sy_m1 - 3'd3;
                    end else begin
                        // H==홀수이면 처음 2비트로 시작했으므로 남은 비트는 H - 2
                        ymaskbit_left <= (reg_rc_sy_m1==10'd0) ? 10'h0 : reg_rc_sy_m1 - 2'd1;
                    end
                end
            end
                
            // Note: 데이터 출력이 valid 및 seq 출력보다 2클록 늦게 출력됨
                // 이는 NM 안에서 데이터의 시작점을 늦춰서 버퍼가 필요하지 않게 하기 위함 
                // 이것 때문에 Validatation 시 에러가 발생할 수 있음 (테스트벤치에서 valid와 seq를 지연시켜 출력할 필요)
            
            if (reg_rc_mode[2]) begin  // 3x3
            
                // 각각이 3개의 열로 구성된 4개 열의 receptor 구현
                // 각 데이터는 각각이 2개의 데이터가 합쳐지므로 6개의 열, 4개 행으로 receptor를 구성 (총 데이터 수 384개)
                // 시프터는 아래 두 개의 행에만 구현하면 됨 (PPT자료 참고할것)
                
                // implement receptor network

                if (load_states)
                    receptornet <= sig_rnetstate;
                
                else if (i_rc_valid && ~pause_receptor) begin
                    for (j=0; j<4; j = j + 1) begin // for each of 6 rows
                        // 각 행의 세 개의 레지스터를 연결
                        for (k=0; k<2; k = k + 1) begin // for each of 6 columns
                            receptornet[j][k+1] <= receptornet[j][k]; 
                        end
                    end
                    if (reg_rc_mode[0]==1'b0) begin  // stride 1
                        // in case W<=3, shifters are not used and feedback connection in the receptornet
                        for (j=0; j<3; j = j + 1) begin
                            // connect receptornet rows
                            // when sx<9 then use only registers (no ram shifters used)
                            case (reg_fast_trackf)
                            2'b00: receptornet[j+1][0] <= receptornet[j][0];    // W==1
                            2'b01: receptornet[j+1][0] <= receptornet[j][1];    // W==2
                            2'b10: receptornet[j+1][0] <= receptornet[j][2];    // W==3
                            default: receptornet[j+1][0] <= sr_dout[j];
                            endcase
                        end
                    end else begin  // stride 2
                        for (j=0; j<2; j = j + 1) begin
                            // connect receptornet rows
                            // when sx<9 then use only registers (no ram shifters used)
                            case (reg_fast_trackf)
                            2'b00: receptornet[j+2][0] <= receptornet[j][0];    // W==1
                            2'b01: receptornet[j+2][0] <= receptornet[j][1];    // W==2
                            2'b10: receptornet[j+2][0] <= receptornet[j][2];    // W==3
                            default: receptornet[j+2][0] <= sr_dout[j];
                            endcase
                        end
                    end
                    if (reg_rc_mode[0]==1'b0) begin // stride 1
                        for (i=0; i<N_RECEPTOR; i = i + 1) begin
                            // receptornet의 맨 위가 가장 낮은 y값을 가지므로 위층에 0, 1을 아래층에 3, 4를 넣는다.
                            receptornet[0][0][DUAL_WIDTH*i+:DUAL_WIDTH] <= {i_rc_dout[i*4+0], i_rc_dout[i*4+0]};
                        end
                    end else begin
                        for (i=0; i<N_RECEPTOR; i = i + 1) begin
                            // receptornet의 맨 위가 가장 낮은 y값을 가지므로 위층에 0, 1을 아래층에 3, 4를 넣는다.
                            receptornet[1][0][DUAL_WIDTH*i+:DUAL_WIDTH] <= {i_rc_dout[i*4+1], i_rc_dout[i*4+0]};
                            receptornet[0][0][DUAL_WIDTH*i+:DUAL_WIDTH] <= {i_rc_dout[i*4+3], i_rc_dout[i*4+2]};
                        end
                    end
                end

                // extract 36-point data from receptor nets
                // receptornet에서 4 x 6 = 24 개의 데이터를 추출하고 첫번째 reg_rc_data 버퍼에 저장
                
                for (i=0; i<4; i = i + 1) begin // for each row
                    for (j=0; j<6; j = j + 1) begin // for each column
                        for (k=0; k<N_RECEPTOR; k = k + 1) begin
                            if (xmask[j] && ymask[i]) begin
                                if ((j % 2)==1)
                                     reg_rc_data_1[k * 24 + i * 6 + j] <= receptornet[i][j/2][k*DUAL_WIDTH+:DATA_WIDTH];
                                else reg_rc_data_1[k * 24 + i * 6 + j] <= receptornet[i][j/2][k*DUAL_WIDTH+DATA_WIDTH+:DATA_WIDTH];
                            end else
                                reg_rc_data_1[k * 24 + i * 6 + j] <= 0; //11'h0;    // padding
                        end
                    end
                end
                
                // process striding (reg_rc_data_1 --> reg_rc_data_2)
                
                for (i=0; i<N_RECEPTOR; i = i + 1) begin // for each receptor
                    if (reg_rc_mode[0]==1'b0) begin    // if stride one
                        for (j=0; j<3; j = j + 1) begin // for each row
                            for (k=0; k<3; k = k + 1) begin // for each column
                                reg_rc_data_2[i * 9 + j * 3 + k] <= reg_rc_data_1[i * 24 + j * 6 + (k * 2)];
                            end
                        end
                    end else begin   // stride two
                        // W 또는 H가 짝수인 경우 시작점에 패딩을 하지 않으므로 3x3영역을 좌로 또는 위로 시프트
                        for (j=0; j<3; j = j + 1) begin
                            for (k=0; k<3; k = k + 1) begin
                                case (sig_even_stride2)
                                2'b00: reg_rc_data_2[i * 9 + j * 3 + k] <= reg_rc_data_1[i * 24 + (j + 0) * 6 + k + 2];   // base
                                2'b01: reg_rc_data_2[i * 9 + j * 3 + k] <= reg_rc_data_1[i * 24 + (j + 0) * 6 + k + 1];
                                2'b10: reg_rc_data_2[i * 9 + j * 3 + k] <= reg_rc_data_1[i * 24 + (j + 1) * 6 + k + 2];
                                2'b11: reg_rc_data_2[i * 9 + j * 3 + k] <= reg_rc_data_1[i * 24 + (j + 1) * 6 + k + 1];
                                endcase
                            end
                        end
                    end
                end
                
                // replicate data (reg_rc_data_2 --> reg_rc_data_3)
            
                if (reg_rc_mode[1]==1'b0) begin   // if not DW Conv, replicate first 9 data for all 8 feature maps
                     reg_rc_data_3[N_RECEPTOR*9-1:9] <= 0; 
                     reg_rc_data_3[8:0] <= reg_rc_data_2[8:0]; 
                end
                    else reg_rc_data_3[N_RECEPTOR * 9 - 1 : 0] <= reg_rc_data_2[N_RECEPTOR * 9 - 1 : 0];  // if dw conv, use all 4 x 9 data

                
                reg_rc_out_valid_1[0] <= reg_rc_out_valid_0;
                reg_rc_out_valid_1[3:1] <= reg_rc_out_valid_1[2:0]; 
                reg_rc_out_seq_1[0] <= reg_rc_out_seq_0;
                reg_rc_out_seq_1[2:1] <= reg_rc_out_seq_1[1:0];
                reg_row_i_1[0] <= reg_row_i;
                reg_row_i_1[2:1] <= reg_row_i_1[1:0];
                reg_col_i_1[0] <= reg_col_i;
                reg_col_i_1[2:1] <= reg_col_i_1[1:0];

                reg_firstchan_1[0] <= reg_firstchan;
                reg_firstchan_1[2:1] <= reg_firstchan_1[1:0]; 
                reg_lastchan_1[0] <= reg_lastchan;
                reg_lastchan_1[2:1] <= reg_lastchan_1[1:0]; 
                reg_o_lastf_1[0] <= reg_o_lastf;
                reg_o_lastf_1[2:1] <= reg_o_lastf_1[1:0]; 
            
            // 1x1 이면 NU의 출력이 바로 연결됨
            // 100T 디자인도 16개의 데이터를 처리함 (8 feature maps)
            
            end else if (reg_rc_mode[3]) begin
            
                reg_rc_out_valid_1[2:0] <= {3{reg_rc_out_valid_0}};
                reg_rc_out_valid_1[3] <= reg_rc_out_valid_1[2];
                reg_rc_out_seq_1[2] <= reg_rc_out_seq_0;
                reg_row_i_1[2] <= reg_row_i;
                reg_col_i_1[2] <= reg_col_i;
                reg_rc_data_2[15:0] <= i_rc_dout[15:0];
                reg_rc_data_3[N_RECEPTOR*9-1:16] <= 0;
                reg_rc_data_3[15:0] <= reg_rc_data_2[15:0];
                
            end


            if (load_states) begin
                reg_row_i <= rstate_dout[9:0];
                reg_col_i <= rstate_dout[19:10];
                reg_col_last <= (rstate_dout[19:10]==reg_o_sxm1);
                ymask <= rstate_dout[25:20];
                xmask <= rstate_dout[31:26];
                ymaskbit_left <= rstate_dout[41:32];
                xmaskbit_left <= rstate_dout[51:42];
                reg_rc_out_seq_0 <= rstate_dout[67:52];
                reg_im_left <= rstate_dout[85:68];
                reg_oim_left <= rstate_dout[103:86];
            end
            
            if (save_states) begin
                rstate_din[9:0] <= (~reg_o_sx_one && ~reg_col_last) ? reg_row_i : ((reg_row_i==reg_o_sym1) ? 10'h0 : reg_row_i + 1'b1);
//                rstate_din[9:0] <= (reg_col_i<reg_o_sxm1) ? reg_row_i : ((reg_row_i==reg_o_sym1) ? 10'h0 : reg_row_i + 1'b1);
                rstate_din[19:10] <= (reg_o_sx_one || reg_col_last) ? 10'h0 : reg_col_i + 1'b1;
//                rstate_din[19:10] <= (reg_col_i==reg_o_sxm1) ? 10'h0 : reg_col_i + 1'b1;
                rstate_din[25:20] <= ymask;
                rstate_din[31:26] <= xmask;
                rstate_din[41:32] <= ymaskbit_left;
                rstate_din[51:42] <= xmaskbit_left;
                rstate_din[67:52] <= reg_rc_out_seq_0 + 1'b1;
                rstate_din[85:68] <= (reg_ickpim>reg_im_left) ? 0 : reg_im_left - reg_ickpim;
                rstate_din[103:86] <= (reg_ockpim>reg_oim_left) ? 0 : reg_oim_left - reg_ockpim;

                // 행카운트, 열카운트를 관리하는 부분
                // 열 카운트가 마지막에 이르면,
                if (reg_o_sx_one || reg_col_last) begin //reg_col_i==reg_o_sxm1) begin
                    // 행카운트가 마지막에 이르면,
                    if (reg_row_i!=reg_o_sym1) begin   
                        // 아니면, 두 줄씩 이동
                        if (reg_rc_mode[0]==1'b0) begin // stride 1
                            rstate_din[25:21] <= ymask[4:0];
                            rstate_din[20] <= (ymaskbit_left>10'd0) ? 1'b1 : 1'b0;
                            if (ymaskbit_left>10'd0) rstate_din[41:32] <= ymaskbit_left - 1'b1;
                            rstate_din[31:26] <= (reg_rc_sx_m1==10'h0) ? 6'b001100 : 6'b001111;
                            rstate_din[51:42] <= (reg_rc_sx_m1==10'h0) ? 10'h0 : reg_rc_sx_m1 - 1'b1;
                        end else begin
                            rstate_din[25:22] <= ymask[3:0];
                            if (ymaskbit_left==10'd0) rstate_din[21:20] <= 2'b00;
                            else if (ymaskbit_left==10'd1) rstate_din[21:20] <= 2'b10;
                            else rstate_din[21:20] <= 2'b11;
                            rstate_din[41:32] <= (ymaskbit_left<10'd2) ? 10'h0 : ymaskbit_left - 2'h2;
                            // x, y가 한비트씩 유효하지만 두 칸씩 이동한다.
                            case (reg_rc_sx_m1)
                            10'd0: rstate_din[31:26] <= 6'b001000;
                            10'd1: rstate_din[31:26] <= 6'b001100;
                            10'd2: rstate_din[31:26] <= 6'b001110;
                            default: rstate_din[31:26] <= 6'b001111;
                            endcase
                            rstate_din[51:42] <= (reg_rc_sx_m1<10'd3) ? 10'h0 : reg_rc_sx_m1 - 2'd3;
                        end
                    end
                end else begin
                    // 두 칸씩 이동
                    rstate_din[31:28] <= xmask[3:0];
                    if (reg_rc_mode[0]==1'b0) begin // stride 1
                        rstate_din[27:26] <= (xmaskbit_left>10'd0) ? 2'b01 : 2'b00;
                        if (xmaskbit_left>10'd0) rstate_din[51:42] <= xmaskbit_left - 1'b1;
                    end else begin
                        if (xmaskbit_left==10'd0) rstate_din[27:26] <= 2'b00;
                        else if (xmaskbit_left==10'd1) rstate_din[27:26] <= 2'b10;
                        else rstate_din[27:26] <= 2'b11;
                        rstate_din[51:42] <= (xmaskbit_left<10'd2) ? 10'h0 : xmaskbit_left - 2'h2;
                    end
                end
            end
            
            is_last_block <= (rc_state!=S_RC_IDLE && reg_im_left<=reg_ickpim);
            is_single_block <= (i_topmost && is_last_block);
            reg_firstf[0] <= i_rc_firstf_a2;
            reg_firstf[2:1] <= reg_firstf[1:0];
            reg_lastf[0] <= i_rc_lastf_a2;
            reg_lastf[2:1] <= reg_lastf[1:0];

            reg_rstate_addr <= i_rstate_addr;
            rstate_we <= save_states;
            
            if (!reg_rc_out_valid_1[2]) reg_out_seq <= 16'd0;
            else reg_out_seq <= reg_out_seq + 1'b1;

        end // if (reset_n==1'b0) begin

    end // always

    // send layer configurations to NU
    assign o_rc_readstart = reg_rc_readstart;
    assign o_rc_out_valid = reg_rc_out_valid_1[2];
    assign o_rc_out_seq = reg_rc_out_seq_1[2];
    assign o_rc_out_seq_partial = reg_out_seq;
    assign o_row_i = reg_row_i_1[2];
    assign o_col_i = reg_col_i_1[2];
    assign o_rc_data = reg_rc_data_3;
    assign o_done = reg_done;
    assign o_all_done = reg_all_done;
    
    assign sig_even_stride2 = {reg_rc_sy_m1[0], reg_rc_sx_m1[0] };
    assign switch_req = {reset_loading, switch_receptor, start_saving, start_loading, 1'b0};//load_states};
    assign set_delayed_switch = (rc_state==S_RC_PAUSE && i_rc_firstf_a2);

    // receptornet to fifo
    assign sr_din[0] = receptornet[0][2];
    assign sr_din[1] = receptornet[1][2];
    assign o_first_chan = (reg_rc_mode[2]) ? reg_firstchan_1[1] : reg_firstchan;
    assign o_last_chan = (reg_rc_mode[2]) ? reg_lastchan_1[1] : reg_lastchan;
    assign o_o_firstf = (reg_rc_out_valid_1[3:2]==2'b01);
    assign o_o_lastf = (reg_rc_mode[2]) ? reg_o_lastf_1[1] : reg_o_lastf;
    assign o_rc_bottommost = is_last_block;
    assign o_rc_im_left = reg_im_left;
    assign o_rc_oim_left = reg_oim_left;

endmodule
