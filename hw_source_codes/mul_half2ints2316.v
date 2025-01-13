
//`timescale 1ns / 1ps
////`define ROUNDUP
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 2020/09/13 15:25:14
//// Design Name: 
//// Module Name: mul_half2ints3116
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////


//module mul_half2int(
//    input clk,
//    input [15:0] i_half1,
//    input [15:0] i_half2,
//    output [23:0] o_int
//    );
    
//    wire msb_a, msb_b;
//    reg reg_sign_t1, reg_sign_t2, reg_sign_t3, reg_sign_t4;
//    reg [5:0] reg_exp_t1, reg_exp_t2, reg_exp_t3;
//    reg [22:0] reg_out_t4;
//    reg [13:0] mul_a, mul_b;
//    wire [27:0] mul_c;
    
//    // t1 --> t3
//    mul14x14 my_mul11 (
//      .CLK(clk),  // input wire CLK
//      .A(mul_a),  // input wire [13 : 0] A     // t1
//      .B(mul_b),  // input wire [13 : 0] B     // t1
//      .P(mul_c)   // output wire [27 : 0] P    // t3
//    );
    
//    assign msb_a = (i_half1[14:10]!=5'h0);
//    assign msb_b = (i_half2[14:10]!=5'h0);
    
//    always @ (posedge clk) begin
    
//        // at t0 --> t3
//        reg_sign_t1 <= i_half1[15] ^ i_half2[15];
//        reg_sign_t2 <= reg_sign_t1;
//        reg_sign_t3 <= reg_sign_t2;
//        reg_sign_t4 <= reg_sign_t3;
//        reg_exp_t1 <= {1'b0,i_half1[14:12], 2'd0} + {i_half2[14:12], 2'd0};
//        reg_exp_t2 <= reg_exp_t1; 
//        reg_exp_t3 <= reg_exp_t2; 
        
//        // t0 --> t1
//        case (i_half1[11:10])
//        2'd0: mul_a <= {3'd0, msb_a, i_half1[9:0]};
//        2'd1: mul_a <= {2'd0, msb_a, i_half1[9:0], 1'b1};
//        2'd2: mul_a <= {1'd0, msb_a, i_half1[9:0], 2'b10};
//        2'd3: mul_a <= {msb_a, i_half1[9:0], 3'b100};
//        endcase
        
//        case (i_half2[11:10])
//        2'd0: mul_b <= {3'd0, msb_b, i_half2[9:0]};
//        2'd1: mul_b <= {2'd0, msb_b, i_half2[9:0], 1'b1};
//        2'd2: mul_b <= {1'd0, msb_b, i_half2[9:0], 2'b10};
//        2'd3: mul_b <= {msb_b, i_half2[9:0], 3'b100};
//        endcase
        
//        // at t3
//        if (reg_exp_t3>6'd36 || 
//            (reg_exp_t3==6'd36 && mul_c[27:21]!=7'd0) || 
//            (reg_exp_t3==6'd32 && mul_c[27:25]!=3'd0)) begin
//            reg_out_t4 <= {{22{1'b1}}, 1'h0};
//        end else if (reg_exp_t3<6'd8) begin
//            reg_out_t4 <= 23'h0;
//        end else begin
//            case (reg_exp_t3)
//`ifdef ROUNDUP
//            // note that the roundup affects only 1/65536
//            6'd8 : begin reg_out_t4 <= {21'h0, mul_c[27:26]} + mul_c[25]; end
//            6'd12: begin reg_out_t4 <= {17'h0, mul_c[27:22]} + mul_c[21]; end
//            6'd16: begin reg_out_t4 <= {13'h0, mul_c[27:18]} + mul_c[17]; end
//            6'd20: begin reg_out_t4 <= { 9'h0, mul_c[27:14]} + mul_c[13]; end
//            6'd24: begin reg_out_t4 <= { 5'h0, mul_c[27:10]} + mul_c[9]; end
//            6'd28: begin reg_out_t4 <= { 1'h0, mul_c[27: 6]} + mul_c[5]; end
//`else
//            6'd8 : begin reg_out_t4 <= {21'h0, mul_c[27:26]}; end
//            6'd12: begin reg_out_t4 <= {17'h0, mul_c[27:22]}; end
//            6'd16: begin reg_out_t4 <= {13'h0, mul_c[27:18]}; end
//            6'd20: begin reg_out_t4 <= { 9'h0, mul_c[27:14]}; end
//            6'd24: begin reg_out_t4 <= { 5'h0, mul_c[27:10]}; end
//            6'd28: begin reg_out_t4 <= { 1'h0, mul_c[27: 6]}; end
//`endif
//            6'd32: begin reg_out_t4 <= {mul_c[24: 2]}; end  // no roundup here to avoid overflow
//            6'd36: begin reg_out_t4 <= {mul_c[20:0], 2'b10}; end
//            endcase
//        end
//    end
    
//    assign o_int[23] = reg_sign_t4;    // t4
//    assign o_int[22:0] = (~reg_sign_t4) ? reg_out_t4 : ~reg_out_t4;    // t4
    
//endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/09/13 15:25:14
// Design Name: 
// Module Name: mul_half2ints3116
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mul_half2int(
    input clk,
    input [15:0] i_half1,
    input [15:0] i_half2,
    output [23:0] o_int
    );
    
    wire msb_a, msb_b, lead_zero1, lead_zero2;
    reg reg_sign_t1, reg_sign_t2, reg_sign_t3, reg_sign_t4, reg_exp_t3_2_1_eq_0;
    reg [3:0] reg_exp_t1, reg_exp_t2, reg_exp_t3, reg_exp_t3_2;
    reg [22:0] reg_out_t4;
    wire [29:0] mul_c_sh0, mul_c_sh1;
    reg [22:0] mul_c_sh2;
    wire [12:0] mul_a_sh, mul_b_sh;
    reg [13:0] mul_a, mul_b;
    wire [27:0] mul_c;
    
    // t1 --> t3
    mul14x14 my_mul11 (
      .CLK(clk),  // input wire CLK
      .A(mul_a),  // input wire [13 : 0] A     // t1
      .B(mul_b),  // input wire [13 : 0] B     // t1
      .P(mul_c)   // output wire [27 : 0] P    // t3
    );
    
    assign msb_a = (i_half1[14:10]!=5'h0);
    assign msb_b = (i_half2[14:10]!=5'h0);
    assign mul_a_sh = i_half1[10] ? {msb_a, i_half1[9:0], 2'b10} : {1'd0, msb_a, i_half1[9:0], 1'b1};
    assign mul_b_sh = i_half2[10] ? {msb_b, i_half2[9:0], 2'b10} : {1'd0, msb_b, i_half2[9:0], 1'b1};
    assign mul_c_sh0 = reg_exp_t3_2[0] ? {4'd0, mul_c[27: 2]} : {mul_c[27:0], 2'b10};
    assign mul_c_sh1 = reg_exp_t3_2[1] ? {8'd0, mul_c_sh0[29: 8]} : mul_c_sh0;
    assign lead_zero1 = (mul_c[27:25]==3'd0);
    assign lead_zero2 = (mul_c[24:21]==4'd0);
    
    always @ (posedge clk) begin
    
        // at t0 --> t3
        reg_sign_t1 <= i_half1[15] ^ i_half2[15];
        reg_sign_t2 <= reg_sign_t1;
        reg_sign_t3 <= reg_sign_t2;
        reg_sign_t4 <= reg_sign_t3;
        reg_exp_t1 <= i_half1[14:12] + i_half2[14:12];
        reg_exp_t2 <= reg_exp_t1; 
        reg_exp_t3 <= reg_exp_t2; 
        reg_exp_t3_2 <= 4'd9 - reg_exp_t2;
        reg_exp_t3_2_1_eq_0 <= (reg_exp_t2[2:1]==2'b00);
        
        // t0 --> t1
        mul_a <= i_half1[11] ? {mul_a_sh[12:0], 1'b0} : {2'd0, mul_a_sh[12:1]};
        mul_b <= i_half2[11] ? {mul_b_sh[12:0], 1'b0} : {2'd0, mul_b_sh[12:1]};

        // at t3
        if (reg_exp_t3[3] && (~reg_exp_t3_2_1_eq_0 ||                                       // reg_exp_t3 > 9
            ((reg_exp_t3_2_1_eq_0 && reg_exp_t3[0])  && (~lead_zero1 || ~lead_zero2)) ||    // reg_exp_t3 == 9
            ((reg_exp_t3_2_1_eq_0 && ~reg_exp_t3[0]) && ~lead_zero1))) begin                // reg_exp_t3 == 8
            reg_out_t4 <= {{22{1'b1}}, 1'h0};
        end else if (~reg_exp_t3[3] && reg_exp_t3_2_1_eq_0) begin                           // reg_exp_t3 < 2
            reg_out_t4 <= 23'h0;
        end else
            reg_out_t4 <= reg_exp_t3_2[2] ? {9'd0, mul_c_sh1[29:16]} : mul_c_sh1[22:0];
    end
    
    assign o_int[23] = reg_sign_t4;    // t4
    assign o_int[22:0] = (~reg_sign_t4) ? reg_out_t4 : ~reg_out_t4;    // t4
    
endmodule
