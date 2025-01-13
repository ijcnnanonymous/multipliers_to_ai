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
// Create Date: 2021/03/07 16:04:57
// Design Name: 
// Module Name: design_1_wrapper
// Project Name:Deep Runner Z1 
// Target Devices:Zynq-7020 
// Tool Versions: Vivado 2019.1
// Description: Top module containing PS, DDR, HDMI and AI Core (Neuron machine)
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
`timescale 1 ps / 1 ps

module design_1_wrapper # (
        parameter SYSTEM_VERSION = 32'h2412180D,
        parameter CLOCK_SPEED = 32'd170769,
        parameter N_RECEPTOR = 4
    )
   (DDR_addr,
    DDR_ba,
    DDR_cas_n,
    DDR_ck_n,
    DDR_ck_p,
    DDR_cke,
    DDR_cs_n,
    DDR_dm,
    DDR_dq,
    DDR_dqs_n,
    DDR_dqs_p,
    DDR_odt,
    DDR_ras_n,
    DDR_reset_n,
    DDR_we_n,
    btn,
    sw,
    led,
    led_r,
    led_g,
    led_b,
    gpio_out,
    FIXED_IO_ddr_vrn,
    FIXED_IO_ddr_vrp,
    FIXED_IO_mio,
    FIXED_IO_ps_clk,
    FIXED_IO_ps_porb,
    FIXED_IO_ps_srstb,
	// HDMI signals
	// display data channel
	DDC_scl_io,
    DDC_sda_io,	
	// HDMI Input
    TMDS_clk_n,
    TMDS_clk_p,
    TMDS_data_n,
    TMDS_data_p,
    hdmi_hpd_tri_o,
	// HDMI Output
    TMDS_1_clk_n,
    TMDS_1_clk_p,
    TMDS_1_data_n,
    TMDS_1_data_p
);

    inout [14:0]DDR_addr;
    inout [2:0]DDR_ba;
    inout DDR_cas_n;
    inout DDR_ck_n;
    inout DDR_ck_p;
    inout DDR_cke;
    inout DDR_cs_n;
    inout [3:0]DDR_dm;
    inout [31:0]DDR_dq;
    inout [3:0]DDR_dqs_n;
    inout [3:0]DDR_dqs_p;
    inout DDR_odt;
    inout DDR_ras_n;
    inout DDR_reset_n;
    inout DDR_we_n;
    inout FIXED_IO_ddr_vrn;
    inout FIXED_IO_ddr_vrp;
    inout [53:0]FIXED_IO_mio;
    inout FIXED_IO_ps_clk;
    inout FIXED_IO_ps_porb;
    inout FIXED_IO_ps_srstb;

    input [3:0] btn;
    input [1:0] sw;
    output [3:0] led;
    output led_r, led_g, led_b;
    output [4:0] gpio_out;

	// display data channel    
	inout DDC_scl_io;
	inout DDC_sda_io;
	// HDMI Input
	input TMDS_clk_n;
	input TMDS_clk_p;
	input [2:0]TMDS_data_n;
	input [2:0]TMDS_data_p;
	output [0:0] hdmi_hpd_tri_o;
	// HDMI Output
	output TMDS_1_clk_n;
	output TMDS_1_clk_p;
	output [2:0]TMDS_1_data_n;
	output [2:0]TMDS_1_data_p;

	wire TMDS_1_clk_n;
	wire TMDS_1_clk_p;
	wire [2:0]TMDS_1_data_n;
	wire [2:0]TMDS_1_data_p;

    wire [14:0]DDR_addr;
    wire [2:0]DDR_ba;
    wire DDR_cas_n;
    wire DDR_ck_n;
    wire DDR_ck_p;
    wire DDR_cke;
    wire DDR_cs_n;
    wire [3:0]DDR_dm;
    wire [31:0]DDR_dq;
    wire [3:0]DDR_dqs_n;
    wire [3:0]DDR_dqs_p;
    wire DDR_odt;
    wire DDR_ras_n;
    wire DDR_reset_n;
    wire DDR_we_n;
    wire FIXED_IO_ddr_vrn;
    wire FIXED_IO_ddr_vrp;
    wire [53:0]FIXED_IO_mio;
    wire FIXED_IO_ps_clk;
    wire FIXED_IO_ps_porb;
    wire FIXED_IO_ps_srstb;

    wire axi_clk, axi_resetn;
    wire app_clk, app_resetn;

    wire [31:0] S_AXI_HP0_0_araddr;
    wire [1:0] S_AXI_HP0_0_arburst;
    wire [3:0] S_AXI_HP0_0_arlen;
    wire S_AXI_HP0_0_arready;
    wire [2:0] S_AXI_HP0_0_arsize;
    wire S_AXI_HP0_0_arvalid;
    wire [31:0] S_AXI_HP0_0_awaddr;
    wire [1:0] S_AXI_HP0_0_awburst;
    wire [3:0] S_AXI_HP0_0_awlen;
    wire S_AXI_HP0_0_awready;
    wire [2:0] S_AXI_HP0_0_awsize;
    wire S_AXI_HP0_0_awvalid;
    wire S_AXI_HP0_0_bready;
    wire [1:0] S_AXI_HP0_0_bresp;
    wire S_AXI_HP0_0_bvalid;
    wire [63:0] S_AXI_HP0_0_rdata;
    wire S_AXI_HP0_0_rlast;
    wire S_AXI_HP0_0_rready;
    wire [1:0] S_AXI_HP0_0_rresp;
    wire S_AXI_HP0_0_rvalid;
    wire [63:0] S_AXI_HP0_0_wdata;
    wire S_AXI_HP0_0_wlast;
    wire S_AXI_HP0_0_wready;
    wire [7:0] S_AXI_HP0_0_wstrb;
    wire S_AXI_HP0_0_wvalid;

    wire [31:0] S_AXI_HP1_0_araddr;
    wire [1:0] S_AXI_HP1_0_arburst;
    wire [3:0] S_AXI_HP1_0_arlen;
    wire S_AXI_HP1_0_arready;
    wire [2:0] S_AXI_HP1_0_arsize;
    wire S_AXI_HP1_0_arvalid;
    wire [31:0] S_AXI_HP1_0_awaddr;
    wire [1:0] S_AXI_HP1_0_awburst;
    wire [3:0] S_AXI_HP1_0_awlen;
    wire S_AXI_HP1_0_awready;
    wire [2:0] S_AXI_HP1_0_awsize;
    wire S_AXI_HP1_0_awvalid;
    wire S_AXI_HP1_0_bready;
    wire [1:0] S_AXI_HP1_0_bresp;
    wire S_AXI_HP1_0_bvalid;
    wire [63:0] S_AXI_HP1_0_rdata;
    wire S_AXI_HP1_0_rlast;
    wire S_AXI_HP1_0_rready;
    wire [1:0] S_AXI_HP1_0_rresp;
    wire S_AXI_HP1_0_rvalid;
    wire [63:0] S_AXI_HP1_0_wdata;
    wire S_AXI_HP1_0_wlast;
    wire S_AXI_HP1_0_wready;
    wire [7:0] S_AXI_HP1_0_wstrb;
    wire S_AXI_HP1_0_wvalid;

    wire [31:0] S_AXI_HP2_0_araddr;
    wire [1:0] S_AXI_HP2_0_arburst;
    wire [3:0] S_AXI_HP2_0_arlen;
    wire S_AXI_HP2_0_arready;
    wire [2:0] S_AXI_HP2_0_arsize;
    wire S_AXI_HP2_0_arvalid;
    wire [31:0] S_AXI_HP2_0_awaddr;
    wire [1:0] S_AXI_HP2_0_awburst;
    wire [3:0] S_AXI_HP2_0_awlen;
    wire S_AXI_HP2_0_awready;
    wire [2:0] S_AXI_HP2_0_awsize;
    wire S_AXI_HP2_0_awvalid;
    wire S_AXI_HP2_0_bready;
    wire [1:0] S_AXI_HP2_0_bresp;
    wire S_AXI_HP2_0_bvalid;
    wire [63:0] S_AXI_HP2_0_rdata;
    wire S_AXI_HP2_0_rlast;
    wire S_AXI_HP2_0_rready;
    wire [1:0] S_AXI_HP2_0_rresp;
    wire S_AXI_HP2_0_rvalid;
    wire [63:0] S_AXI_HP2_0_wdata;
    wire S_AXI_HP2_0_wlast;
    wire S_AXI_HP2_0_wready;
    wire [7:0] S_AXI_HP2_0_wstrb;
    wire S_AXI_HP2_0_wvalid;
    
	wire [31:0]S_AXI_HP3_0_araddr;
	wire [1:0]S_AXI_HP3_0_arburst;
	wire [3:0]S_AXI_HP3_0_arlen;
	wire S_AXI_HP3_0_arready;
	wire [2:0]S_AXI_HP3_0_arsize;
	wire S_AXI_HP3_0_arvalid;
	wire [31:0]S_AXI_HP3_0_awaddr;
	wire [1:0]S_AXI_HP3_0_awburst;
	wire [3:0]S_AXI_HP3_0_awlen;
	wire S_AXI_HP3_0_awready;
	wire [2:0]S_AXI_HP3_0_awsize;
	wire S_AXI_HP3_0_awvalid;
	wire S_AXI_HP3_0_bready;
	wire [1:0]S_AXI_HP3_0_bresp;
	wire S_AXI_HP3_0_bvalid;
	wire [63:0]S_AXI_HP3_0_rdata;
	wire S_AXI_HP3_0_rlast;
	wire S_AXI_HP3_0_rready;
	wire [1:0]S_AXI_HP3_0_rresp;
	wire S_AXI_HP3_0_rvalid;
	wire [63:0]S_AXI_HP3_0_wdata;
	wire S_AXI_HP3_0_wlast;
	wire S_AXI_HP3_0_wready;
	wire [7:0]S_AXI_HP3_0_wstrb;
	wire S_AXI_HP3_0_wvalid;
	
	wire [0:0]hdmi_hpd_tri_o;
	
	logic clk200, clk200_locked, r_clk200_locked;
	
	wire DDC_scl_i;
	wire DDC_scl_o;
	wire DDC_scl_t;
	wire DDC_sda_i;
	wire DDC_sda_o;
	wire DDC_sda_t;
	
	reg pRst, pRst_n;
	wire PixelClk, SerialClk;
	wire [3:0] led;
	
	wire pLocked;
	logic [23:0] vid_pData, bg_vid_pData, bg_vid_pData2, wbg_vid_pData;
	logic vid_pVDE, vid_pHSync, vid_pVSync;  
	wire [3:0] vid_pCTL;
	reg [3:0] r_btn, nm_btn;
	logic [23:0] r_vid_pData, r_vid_pData2;
	logic r_vid_pVDE, r_vid_pVSync, r_vid_pHSync;

    logic [25:0] hdmii_din;
    logic hdmii_wr_en; 
    reg [31:0] sys_counter = 32'd0;
    logic [25:0] hdmii_dout;
    logic hdmii_valid, de_active = 1'b0; 
    logic [3:0] hdmii_q_count; 
    (* mark_debug="true" *) logic [11:0] hcount, vcount;

    // DDR application interface
    reg ddr_req_en, ddr_req_rw, ddr_req_flush, ddr_req_newaddr;
    reg [25:0] ddr_req_addr;
    reg [127:0] ddr_req_din;
    wire ddr_req_avail;
    wire ddr_req_error;
    wire ddr_resp_en;
    wire [25:0] ddr_resp_addr;
    wire [127:0] ddr_resp_dout;
    reg ddr_resp_wait;
    wire ddr_resp_rdone;
    reg [3:0] button;
    reg [1:0] r_sw;
    logic [31:0] cmd_control, cmd_addr, cmd_din, cmd_dout, cmd_monitor;
    logic [31:0] vcmd_control, vcmd_addr, vcmd_din, vcmd_dout, vcmd_vout_extra;

    logic [16:0] label_waddr = 17'd0;
    logic [7:0] label_wdata = 8'd0;
    (* keep = "true" *) logic [31:0] vcmd_monitor, nm_monitor;
    (* keep = "true" *) logic [31:0] hdmi_nm_monitor;
    
    logic [31:0] hdmi_nm_monitor_d1;
    logic cmd_en_d, vcmd_en_d;
    logic [31:0] sys_status, nm_status;
    
    logic vout_clk, vout_rst;
    logic mipi_sof;
    logic vout_tvalid, vout_tlast, vout_tready_bayer, vout_tready;
    logic [5:0] mipi_sof_d = 6'd0;
    (* mark_debug="true" *) logic [11:0] vRes, hRes;
    logic [11:0] vRes_m1, hRes_m1;
    logic [39:0] vout_tdata;
    logic [9:0] vout_tdest;
    logic [95:0] vout_tuser;
    logic [29:0] vid_tdata;
    logic [23:0] vid_tdata_isp, vid_tdata_d1, vid_tdata_d2;
    logic vid_tvalid, vid_tuser_isp_d1, vid_tlast_d2, vid_tvalid_isp;
    logic vid_tvalid_d1, vid_tready, vid_tready_writer, vid_tuser, vid_tuser_d1, vid_tuser_d2, vid_tuser_isp, vid_tlast_isp;
    logic vid_tlast_d1;
    logic tick_b22_app, tick_b22_mipi, tick_b22_mipi_d1;
    logic [15:0] led_counter = 16'h0000;
    logic [15:0] vid_counter = 16'h0000;
    logic [15:0] nm_counter = 16'h0000;

    logic [5:0] attributes0;
    logic nm_tvalid, scr_tvalid, scr_tvalid_t2, vid_h_area = 1'b0, vid_v_area, scr_h_area = 1'b0, scr_v_area;
    logic [3:0] scr_hseq = 4'd0, scr_vseq = 4'd0, scr_hstride_m1 = 4'd0, scr_vstride_m1 = 4'd0;
    logic scr_v_area_d1;
    logic [3:0] res_type = 4'd1;
    logic [1:0] last_view_m1 = 2'd0;
    
    logic [3:0] window_type = 4'd8;
    localparam SCR_VRANGE = {12'd988, 12'd92};
    localparam SCR_HRANGE = {12'd1520, 12'd400};
    
    (* mark_debug="true" *) logic [23:0] vrange = SCR_VRANGE, hrange = SCR_HRANGE;
    (* mark_debug="true" *) logic [23:0] vrange_scr = SCR_VRANGE, hrange_scr = SCR_HRANGE;
    logic [7:0] last_buff = 8'd0;
    logic [15:0] curr_hr_base = 16'h1b60, curr_lr_base = 16'h1fb0;
    logic [3:0] curr_hr_seq = 4'd0, curr_lr_seq = 4'd0;
    logic [11:0] buff_seq = 12'd0;
    
    logic [1:0] four_seq = 2'd0;
    logic [31:0] vid_tdata32, vid_tdata32_rgb;
    logic [23:0] vid_keep24;
    logic valid32, valid32_rgb;
    logic fw_reset = 1'b0;
    logic hcount32_0, hcount32_0_rgb = 0, fw_tobe_reset = 1'b0;
    logic [2:0] trail_count;
    
    logic [3:0] hr_last = 4'd9;
    logic [15:0] hr_stepsize = 16'h4b; 
    logic reg_on_req = 1'b0;
    logic reg_on = 0, hdmi_on, hdmi_on_d1;
    logic [4:0] gpio_output;
    logic [2:0] color_led = 3'd0;
    
    assign {led_r, led_g, led_b} = color_led;
    
    integer i;


    IOBUF DDC_scl_iobuf
       (.I(DDC_scl_o),
        .IO(DDC_scl_io),
        .O(DDC_scl_i),
        .T(DDC_scl_t));

    IOBUF DDC_sda_iobuf
       (.I(DDC_sda_o),
        .IO(DDC_sda_io),
        .O(DDC_sda_i),
        .T(DDC_sda_t));

    design_1 design_1_i
       (.DDR_addr(DDR_addr),
        .DDR_ba(DDR_ba),
        .DDR_cas_n(DDR_cas_n),
        .DDR_ck_n(DDR_ck_n),
        .DDR_ck_p(DDR_ck_p),
        .DDR_cke(DDR_cke),
        .DDR_cs_n(DDR_cs_n),
        .DDR_dm(DDR_dm),
        .DDR_dq(DDR_dq),
        .DDR_dqs_n(DDR_dqs_n),
        .DDR_dqs_p(DDR_dqs_p),
        .DDR_odt(DDR_odt),
        .DDR_ras_n(DDR_ras_n),
        .DDR_reset_n(DDR_reset_n),
        .DDR_we_n(DDR_we_n),
        .FIXED_IO_ddr_vrn(FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp(FIXED_IO_ddr_vrp),
        .FIXED_IO_mio(FIXED_IO_mio),
        .FIXED_IO_ps_clk(FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb(FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb(FIXED_IO_ps_srstb),
        .GPIO_0_tri_o(cmd_control),
        .GPIO2_0_tri_o(cmd_addr),
        .GPIO_1_tri_i(cmd_din),
        .GPIO2_1_tri_o(cmd_dout),
        .GPIO_2_tri_i(cmd_monitor),
        .GPIO_3_tri_o(vcmd_control),
        .GPIO2_3_tri_o(vcmd_addr),
        .GPIO_4_tri_o(vcmd_dout),
        .GPIO2_4_tri_i(vcmd_din),
        .GPIO_5_tri_i(vcmd_monitor),
        .GPIO2_5_tri_o(vcmd_vout_extra),
        .S_AXI_HP0_0_araddr(S_AXI_HP0_0_araddr),
        .S_AXI_HP0_0_arburst(S_AXI_HP0_0_arburst),
        .S_AXI_HP0_0_arcache(4'b0010),
        .S_AXI_HP0_0_arid(6'h0),
        .S_AXI_HP0_0_arlen(S_AXI_HP0_0_arlen),
        .S_AXI_HP0_0_arlock(2'h0),
        .S_AXI_HP0_0_arprot(3'h0),
        .S_AXI_HP0_0_arqos(4'h0),
        .S_AXI_HP0_0_arready(S_AXI_HP0_0_arready),
        .S_AXI_HP0_0_arsize(S_AXI_HP0_0_arsize),
        .S_AXI_HP0_0_arvalid(S_AXI_HP0_0_arvalid),
        .S_AXI_HP0_0_awaddr(S_AXI_HP0_0_awaddr),
        .S_AXI_HP0_0_awburst(S_AXI_HP0_0_awburst),
        .S_AXI_HP0_0_awcache(4'b0010),
        .S_AXI_HP0_0_awid(6'h0),
        .S_AXI_HP0_0_awlen(S_AXI_HP0_0_awlen),
        .S_AXI_HP0_0_awlock(2'h0),
        .S_AXI_HP0_0_awprot(3'h0),
        .S_AXI_HP0_0_awqos(4'h0),
        .S_AXI_HP0_0_awready(S_AXI_HP0_0_awready),
        .S_AXI_HP0_0_awsize(S_AXI_HP0_0_awsize),
        .S_AXI_HP0_0_awvalid(S_AXI_HP0_0_awvalid),
        .S_AXI_HP0_0_bid(),
        .S_AXI_HP0_0_bready(S_AXI_HP0_0_bready),
        .S_AXI_HP0_0_bresp(S_AXI_HP0_0_bresp),
        .S_AXI_HP0_0_bvalid(S_AXI_HP0_0_bvalid),
        .S_AXI_HP0_0_rdata(S_AXI_HP0_0_rdata),
        .S_AXI_HP0_0_rid(),
        .S_AXI_HP0_0_rlast(S_AXI_HP0_0_rlast),
        .S_AXI_HP0_0_rready(S_AXI_HP0_0_rready),
        .S_AXI_HP0_0_rresp(S_AXI_HP0_0_rresp),
        .S_AXI_HP0_0_rvalid(S_AXI_HP0_0_rvalid),
        .S_AXI_HP0_0_wdata(S_AXI_HP0_0_wdata),
        .S_AXI_HP0_0_wid(6'h0),
        .S_AXI_HP0_0_wlast(S_AXI_HP0_0_wlast),
        .S_AXI_HP0_0_wready(S_AXI_HP0_0_wready),
        .S_AXI_HP0_0_wstrb(S_AXI_HP0_0_wstrb),
        .S_AXI_HP0_0_wvalid(S_AXI_HP0_0_wvalid),
        .S_AXI_HP1_0_araddr(S_AXI_HP1_0_araddr),
        .S_AXI_HP1_0_arburst(S_AXI_HP1_0_arburst),
        .S_AXI_HP1_0_arcache(4'b0010),
        .S_AXI_HP1_0_arid(6'h0),
        .S_AXI_HP1_0_arlen(S_AXI_HP1_0_arlen),
        .S_AXI_HP1_0_arlock(2'h0),
        .S_AXI_HP1_0_arprot(3'h0),
        .S_AXI_HP1_0_arqos(4'h0),
        .S_AXI_HP1_0_arready(S_AXI_HP1_0_arready),
        .S_AXI_HP1_0_arsize(S_AXI_HP1_0_arsize),
        .S_AXI_HP1_0_arvalid(S_AXI_HP1_0_arvalid),
        .S_AXI_HP1_0_awaddr(S_AXI_HP1_0_awaddr),
        .S_AXI_HP1_0_awburst(S_AXI_HP1_0_awburst),
        .S_AXI_HP1_0_awcache(4'b0010),
        .S_AXI_HP1_0_awid(6'h0),
        .S_AXI_HP1_0_awlen(S_AXI_HP1_0_awlen),
        .S_AXI_HP1_0_awlock(2'h0),
        .S_AXI_HP1_0_awprot(3'h0),
        .S_AXI_HP1_0_awqos(4'h0),
        .S_AXI_HP1_0_awready(S_AXI_HP1_0_awready),
        .S_AXI_HP1_0_awsize(S_AXI_HP1_0_awsize),
        .S_AXI_HP1_0_awvalid(S_AXI_HP1_0_awvalid),
        .S_AXI_HP1_0_bid(),
        .S_AXI_HP1_0_bready(S_AXI_HP1_0_bready),
        .S_AXI_HP1_0_bresp(S_AXI_HP1_0_bresp),
        .S_AXI_HP1_0_bvalid(S_AXI_HP1_0_bvalid),
        .S_AXI_HP1_0_rdata(S_AXI_HP1_0_rdata),
        .S_AXI_HP1_0_rid(),
        .S_AXI_HP1_0_rlast(S_AXI_HP1_0_rlast),
        .S_AXI_HP1_0_rready(S_AXI_HP1_0_rready),
        .S_AXI_HP1_0_rresp(S_AXI_HP1_0_rresp),
        .S_AXI_HP1_0_rvalid(S_AXI_HP1_0_rvalid),
        .S_AXI_HP1_0_wdata(S_AXI_HP1_0_wdata),
        .S_AXI_HP1_0_wid(6'h0),
        .S_AXI_HP1_0_wlast(S_AXI_HP1_0_wlast),
        .S_AXI_HP1_0_wready(S_AXI_HP1_0_wready),
        .S_AXI_HP1_0_wstrb(S_AXI_HP1_0_wstrb),
        .S_AXI_HP1_0_wvalid(S_AXI_HP1_0_wvalid),
        .S_AXI_HP2_0_araddr(S_AXI_HP2_0_araddr),
        .S_AXI_HP2_0_arburst(S_AXI_HP2_0_arburst),
        .S_AXI_HP2_0_arcache(4'b0010),
        .S_AXI_HP2_0_arid(6'h0),
        .S_AXI_HP2_0_arlen(S_AXI_HP2_0_arlen),
        .S_AXI_HP2_0_arlock(2'h0),
        .S_AXI_HP2_0_arprot(3'h0),
        .S_AXI_HP2_0_arqos(4'h0),
        .S_AXI_HP2_0_arready(S_AXI_HP2_0_arready),
        .S_AXI_HP2_0_arsize(S_AXI_HP2_0_arsize),
        .S_AXI_HP2_0_arvalid(S_AXI_HP2_0_arvalid),
        .S_AXI_HP2_0_awaddr(S_AXI_HP2_0_awaddr),
        .S_AXI_HP2_0_awburst(S_AXI_HP2_0_awburst),
        .S_AXI_HP2_0_awcache(4'b0010),
        .S_AXI_HP2_0_awid(6'h0),
        .S_AXI_HP2_0_awlen(S_AXI_HP2_0_awlen),
        .S_AXI_HP2_0_awlock(2'h0),
        .S_AXI_HP2_0_awprot(3'h0),
        .S_AXI_HP2_0_awqos(4'h0),
        .S_AXI_HP2_0_awready(S_AXI_HP2_0_awready),
        .S_AXI_HP2_0_awsize(S_AXI_HP2_0_awsize),
        .S_AXI_HP2_0_awvalid(S_AXI_HP2_0_awvalid),
        .S_AXI_HP2_0_bid(),
        .S_AXI_HP2_0_bready(S_AXI_HP2_0_bready),
        .S_AXI_HP2_0_bresp(S_AXI_HP2_0_bresp),
        .S_AXI_HP2_0_bvalid(S_AXI_HP2_0_bvalid),
        .S_AXI_HP2_0_rdata(S_AXI_HP2_0_rdata),
        .S_AXI_HP2_0_rid(),
        .S_AXI_HP2_0_rlast(S_AXI_HP2_0_rlast),
        .S_AXI_HP2_0_rready(S_AXI_HP2_0_rready),
        .S_AXI_HP2_0_rresp(S_AXI_HP2_0_rresp),
        .S_AXI_HP2_0_rvalid(S_AXI_HP2_0_rvalid),
        .S_AXI_HP2_0_wdata(S_AXI_HP2_0_wdata),
        .S_AXI_HP2_0_wid(6'h0),
        .S_AXI_HP2_0_wlast(S_AXI_HP2_0_wlast),
        .S_AXI_HP2_0_wready(S_AXI_HP2_0_wready),
        .S_AXI_HP2_0_wstrb(S_AXI_HP2_0_wstrb),
        .S_AXI_HP2_0_wvalid(S_AXI_HP2_0_wvalid),
        .S_AXI_HP3_0_araddr(S_AXI_HP3_0_araddr),
        .S_AXI_HP3_0_arburst(S_AXI_HP3_0_arburst),
        .S_AXI_HP3_0_arcache(4'b0010),
        .S_AXI_HP3_0_arid(6'h0),
        .S_AXI_HP3_0_arlen(S_AXI_HP3_0_arlen),
        .S_AXI_HP3_0_arlock(2'h0),
        .S_AXI_HP3_0_arprot(3'h0),
        .S_AXI_HP3_0_arqos(4'h0),
        .S_AXI_HP3_0_arready(S_AXI_HP3_0_arready),
        .S_AXI_HP3_0_arsize(S_AXI_HP3_0_arsize),
        .S_AXI_HP3_0_arvalid(S_AXI_HP3_0_arvalid),
        .S_AXI_HP3_0_awaddr(S_AXI_HP3_0_awaddr),
        .S_AXI_HP3_0_awburst(S_AXI_HP3_0_awburst),
        .S_AXI_HP3_0_awcache(4'b0010),
        .S_AXI_HP3_0_awid(6'h0),
        .S_AXI_HP3_0_awlen(S_AXI_HP3_0_awlen),
        .S_AXI_HP3_0_awlock(2'h0),
        .S_AXI_HP3_0_awprot(3'h0),
        .S_AXI_HP3_0_awqos(4'h0),
        .S_AXI_HP3_0_awready(S_AXI_HP3_0_awready),
        .S_AXI_HP3_0_awsize(S_AXI_HP3_0_awsize),
        .S_AXI_HP3_0_awvalid(S_AXI_HP3_0_awvalid),
        .S_AXI_HP3_0_bid(),
        .S_AXI_HP3_0_bready(S_AXI_HP3_0_bready),
        .S_AXI_HP3_0_bresp(S_AXI_HP3_0_bresp),
        .S_AXI_HP3_0_bvalid(S_AXI_HP3_0_bvalid),
        .S_AXI_HP3_0_rdata(S_AXI_HP3_0_rdata),
        .S_AXI_HP3_0_rid(),
        .S_AXI_HP3_0_rlast(S_AXI_HP3_0_rlast),
        .S_AXI_HP3_0_rready(S_AXI_HP3_0_rready),
        .S_AXI_HP3_0_rresp(S_AXI_HP3_0_rresp),
        .S_AXI_HP3_0_rvalid(S_AXI_HP3_0_rvalid),
        .S_AXI_HP3_0_wdata(S_AXI_HP3_0_wdata),
        .S_AXI_HP3_0_wid(6'h0),
        .S_AXI_HP3_0_wlast(S_AXI_HP3_0_wlast),
        .S_AXI_HP3_0_wready(S_AXI_HP3_0_wready),
        .S_AXI_HP3_0_wstrb(S_AXI_HP3_0_wstrb),
        .S_AXI_HP3_0_wvalid(S_AXI_HP3_0_wvalid),
        .axi_clk(axi_clk),
        .axi_resetn(axi_resetn),
        .app_clk(app_clk),
        .app_resetn(app_resetn),
        .clk_out1(clk200),
        .clk_locked(clk200_locked)
    );

   assign gpio_out = gpio_output;

    ddr_manager ddr_man (
        .i_req_en(ddr_req_en),
        .i_req_rw(ddr_req_rw),
        .i_req_flush(ddr_req_flush),
        .i_req_addr(ddr_req_addr),
        .i_req_din(ddr_req_din),
        .i_req_newaddr(ddr_req_newaddr),
        .o_req_avail(ddr_req_avail),
        .o_req_error(ddr_req_error),
        .o_resp_en(ddr_resp_en),
        .i_resp_wait(ddr_resp_wait),
        .o_resp_rdone(ddr_resp_rdone),
        .o_resp_dout(ddr_resp_dout),
        .o_resp_addr(ddr_resp_addr),
        //
        .S_AXI_HP0_0_araddr(S_AXI_HP0_0_araddr),
        .S_AXI_HP0_0_arburst(S_AXI_HP0_0_arburst),
        .S_AXI_HP0_0_arlen(S_AXI_HP0_0_arlen),
        .S_AXI_HP0_0_arready(S_AXI_HP0_0_arready),
        .S_AXI_HP0_0_arsize(S_AXI_HP0_0_arsize),
        .S_AXI_HP0_0_arvalid(S_AXI_HP0_0_arvalid),
        .S_AXI_HP0_0_awaddr(S_AXI_HP0_0_awaddr),
        .S_AXI_HP0_0_awburst(S_AXI_HP0_0_awburst),
        .S_AXI_HP0_0_awlen(S_AXI_HP0_0_awlen),
        .S_AXI_HP0_0_awready(S_AXI_HP0_0_awready),
        .S_AXI_HP0_0_awsize(S_AXI_HP0_0_awsize),
        .S_AXI_HP0_0_awvalid(S_AXI_HP0_0_awvalid),
        .S_AXI_HP0_0_bready(S_AXI_HP0_0_bready),
        .S_AXI_HP0_0_bresp(S_AXI_HP0_0_bresp),
        .S_AXI_HP0_0_bvalid(S_AXI_HP0_0_bvalid),
        .S_AXI_HP0_0_rdata(S_AXI_HP0_0_rdata),
        .S_AXI_HP0_0_rlast(S_AXI_HP0_0_rlast),
        .S_AXI_HP0_0_rready(S_AXI_HP0_0_rready),
        .S_AXI_HP0_0_rresp(S_AXI_HP0_0_rresp),
        .S_AXI_HP0_0_rvalid(S_AXI_HP0_0_rvalid),
        .S_AXI_HP0_0_wdata(S_AXI_HP0_0_wdata),
        .S_AXI_HP0_0_wlast(S_AXI_HP0_0_wlast),
        .S_AXI_HP0_0_wready(S_AXI_HP0_0_wready),
        .S_AXI_HP0_0_wstrb(S_AXI_HP0_0_wstrb),
        .S_AXI_HP0_0_wvalid(S_AXI_HP0_0_wvalid),
        .S_AXI_HP1_0_araddr(S_AXI_HP1_0_araddr),
        .S_AXI_HP1_0_arburst(S_AXI_HP1_0_arburst),
        .S_AXI_HP1_0_arlen(S_AXI_HP1_0_arlen),
        .S_AXI_HP1_0_arready(S_AXI_HP1_0_arready),
        .S_AXI_HP1_0_arsize(S_AXI_HP1_0_arsize),
        .S_AXI_HP1_0_arvalid(S_AXI_HP1_0_arvalid),
        .S_AXI_HP1_0_awaddr(S_AXI_HP1_0_awaddr),
        .S_AXI_HP1_0_awburst(S_AXI_HP1_0_awburst),
        .S_AXI_HP1_0_awlen(S_AXI_HP1_0_awlen),
        .S_AXI_HP1_0_awready(S_AXI_HP1_0_awready),
        .S_AXI_HP1_0_awsize(S_AXI_HP1_0_awsize),
        .S_AXI_HP1_0_awvalid(S_AXI_HP1_0_awvalid),
        .S_AXI_HP1_0_bready(S_AXI_HP1_0_bready),
        .S_AXI_HP1_0_bresp(S_AXI_HP1_0_bresp),
        .S_AXI_HP1_0_bvalid(S_AXI_HP1_0_bvalid),
        .S_AXI_HP1_0_rdata(S_AXI_HP1_0_rdata),
        .S_AXI_HP1_0_rlast(S_AXI_HP1_0_rlast),
        .S_AXI_HP1_0_rready(S_AXI_HP1_0_rready),
        .S_AXI_HP1_0_rresp(S_AXI_HP1_0_rresp),
        .S_AXI_HP1_0_rvalid(S_AXI_HP1_0_rvalid),
        .S_AXI_HP1_0_wdata(S_AXI_HP1_0_wdata),
        .S_AXI_HP1_0_wlast(S_AXI_HP1_0_wlast),
        .S_AXI_HP1_0_wready(S_AXI_HP1_0_wready),
        .S_AXI_HP1_0_wstrb(S_AXI_HP1_0_wstrb),
        .S_AXI_HP1_0_wvalid(S_AXI_HP1_0_wvalid),
        .S_AXI_HP2_0_araddr(S_AXI_HP2_0_araddr),
        .S_AXI_HP2_0_arburst(S_AXI_HP2_0_arburst),
        .S_AXI_HP2_0_arlen(S_AXI_HP2_0_arlen),
        .S_AXI_HP2_0_arready(S_AXI_HP2_0_arready),
        .S_AXI_HP2_0_arsize(S_AXI_HP2_0_arsize),
        .S_AXI_HP2_0_arvalid(S_AXI_HP2_0_arvalid),
        .S_AXI_HP2_0_awaddr(S_AXI_HP2_0_awaddr),
        .S_AXI_HP2_0_awburst(S_AXI_HP2_0_awburst),
        .S_AXI_HP2_0_awlen(S_AXI_HP2_0_awlen),
        .S_AXI_HP2_0_awready(S_AXI_HP2_0_awready),
        .S_AXI_HP2_0_awsize(S_AXI_HP2_0_awsize),
        .S_AXI_HP2_0_awvalid(S_AXI_HP2_0_awvalid),
        .S_AXI_HP2_0_bready(S_AXI_HP2_0_bready),
        .S_AXI_HP2_0_bresp(S_AXI_HP2_0_bresp),
        .S_AXI_HP2_0_bvalid(S_AXI_HP2_0_bvalid),
        .S_AXI_HP2_0_rdata(S_AXI_HP2_0_rdata),
        .S_AXI_HP2_0_rlast(S_AXI_HP2_0_rlast),
        .S_AXI_HP2_0_rready(S_AXI_HP2_0_rready),
        .S_AXI_HP2_0_rresp(S_AXI_HP2_0_rresp),
        .S_AXI_HP2_0_rvalid(S_AXI_HP2_0_rvalid),
        .S_AXI_HP2_0_wdata(S_AXI_HP2_0_wdata),
        .S_AXI_HP2_0_wlast(S_AXI_HP2_0_wlast),
        .S_AXI_HP2_0_wready(S_AXI_HP2_0_wready),
        .S_AXI_HP2_0_wstrb(S_AXI_HP2_0_wstrb),
        .S_AXI_HP2_0_wvalid(S_AXI_HP2_0_wvalid),
        .axi_clk(axi_clk),
        .axi_resetn(axi_resetn),
        .app_clk(app_clk),
        .app_resetn(app_resetn)
);

    logic reg_nm_runf, sig_runf;
    logic sig_nm_done;
    logic [5:0] sig_mode;
    logic o_out_valid, o_out_lastchan;
    logic [15:0] o_out_seq;
    logic [N_RECEPTOR*9-1:0][16-1:0] o_out_data;
    logic [7:0] o_layerid;
    logic o_su_valid;
    logic [15:0][15:0] o_su_data;
    logic [7:0] o_su_layerid;
    logic overlay = 1'b0;

    reg [31:0] app_counter = 0;
    reg [31:0] axi_counter = 0;
    reg led_pulse, led_pulse2;

    neuron_machine nm (
        .o_runf(sig_runf),
        .o_nm_done(sig_nm_done),
        .o_mode(sig_mode),
        //
        .o_out_valid(o_out_valid),
        .o_out_lastchan(o_out_lastchan),
        .o_out_seq(o_out_seq),
        .o_out_data(o_out_data),
        .o_layerid(o_layerid),
        //
        .o_su_valid(o_su_valid),
        .o_su_data(o_su_data),
        .o_su_layerid(o_su_layerid),
        //
        .o_req_en(ddr_req_en),
        .o_req_rw(ddr_req_rw),
        .o_req_flush(ddr_req_flush),
        .o_req_addr(ddr_req_addr),
        .o_req_din(ddr_req_din),
        .o_req_newaddr(ddr_req_newaddr),
        .i_req_avail(ddr_req_avail),
        .i_req_error(ddr_req_error),
        //
        .i_resp_en(ddr_resp_en),
        .i_resp_addr(ddr_resp_addr),
        .i_resp_dout(ddr_resp_dout),
        .i_resp_rdone(ddr_resp_rdone),
        .o_resp_wait(ddr_resp_wait),
        //
        .cmd_control(cmd_control),
        .cmd_addr(cmd_addr),
        .cmd_din(nm_status),
        .cmd_dout(cmd_dout),
        .cmd_monitor(cmd_monitor),
        .reset_n(app_resetn),
        .clk(app_clk)
    );

    hdmii_fifo hdmii_fifo (
        .wr_clk(PixelClk),          // input wire wr_clk
        .rd_clk(axi_clk),           // input wire rd_clk
        .din(hdmii_din),            // input wire [25 : 0] din
        .wr_en(hdmii_wr_en),        // input wire wr_en
        .rd_en(1'b1),               // input wire rd_en
        .dout(hdmii_dout),          // output wire [25 : 0] dout
        .full(),                    // output wire full
        .empty(),                   // output wire empty
        .valid(hdmii_valid),        // output wire valid
        .rd_data_count(hdmii_q_count) // output wire [3 : 0] rd_data_count
	);

    assign hdmi_hpd_tri_o[0] = ~r_btn[3];
        
    dvi2rgb hdmi2rgb
    (
        .TMDS_Clk_p(TMDS_clk_p),
        .TMDS_Clk_n(TMDS_clk_n),
        .TMDS_Data_p(TMDS_data_p),
        .TMDS_Data_n(TMDS_data_n),
        .RefClk(clk200),
        .aRst(~r_clk200_locked),
        .aRst_n(r_clk200_locked),
        .vid_pData(vid_pData),
        .vid_pVDE(vid_pVDE),
        .vid_pHSync(vid_pHSync),
        .vid_pVSync(vid_pVSync),
        .vid_pCTL(vid_pCTL),
        .PixelClk(PixelClk),
        .SerialClk(SerialClk),
        .aPixelClkLckd(),
        .pLocked(pLocked),
        .SDA_I(DDC_sda_i),
        .SDA_O(DDC_sda_o),
        .SDA_T(DDC_sda_t),
        .SCL_I(DDC_scl_i),
        .SCL_O(DDC_scl_o),
        .SCL_T(DDC_scl_t),
        .pRst(0),
        .pRst_n(1)
    );
        
    rgb2dvi rgb2hdmi
    (
        .TMDS_Clk_p(TMDS_1_clk_p),
        .TMDS_Clk_n(TMDS_1_clk_n),
        .TMDS_Data_p(TMDS_1_data_p),
        .TMDS_Data_n(TMDS_1_data_n),
        .aRst(~pLocked),
        .aRst_n(pLocked),
        .vid_pData(r_vid_pData2),
        .vid_pVDE(r_vid_pVDE),
        .vid_pHSync(r_vid_pHSync),
        .vid_pVSync(r_vid_pVSync),
//        .vid_pData(overlay?r_vid_pData:vid_pData),
//        .vid_pVDE(vid_pVDE),
//        .vid_pHSync(vid_pHSync),
//        .vid_pVSync(vid_pVSync),
        .PixelClk(PixelClk),
        .SerialClk(SerialClk)
    );
    
    assign r_vid_pData2 = {
        r_vid_pData[23:16]>8'hf0 ? 8'hf0 : r_vid_pData[23:16],
        r_vid_pData[15: 8]>8'hf0 ? 8'hf0 : r_vid_pData[15: 8],
        r_vid_pData[ 7: 0]>8'hf0 ? 8'hf0 : r_vid_pData[ 7: 0]
    };
    
    (* mark_debug="true" *) logic vsync_axi, hsync_axi, de_axi, vid_tlast;
    logic [23:0] vdata_axi;
    logic [4:0] r_vsync_axi, r_hsync_axi, r_de_axi;
    logic [4:0][23:0] r_vdata_axi;

    assign mipi_sof = vsync_axi;
    assign nm_tvalid = (r_de_axi[0] && vid_v_area && vid_h_area);
    assign scr_tvalid = (r_de_axi[0] && scr_v_area && scr_h_area);

    assign vsync_axi = (hdmii_valid && hdmii_dout[25]);
    assign hsync_axi = (hdmii_valid && hdmii_dout[24]);
    assign de_axi = (hdmii_valid && ~hdmii_dout[25] && ~hdmii_dout[24]);
    assign vdata_axi = hdmii_dout[23:0];

    assign led[0] = led_pulse;          // bit file is running
    assign led[1] = sig_runf;           // AI logic is running
    assign led[2] = ~led_counter[15];   // HDMI input is valid
    assign led[3] = ~vid_counter[15];   // uploading image data

frame_writer frame_writer (
    // lr specific
    // t1
    .data_in(r_vdata_axi[0]),           // input [23:0] data_in,
    .de(nm_tvalid && reg_on),           // input de,
    .eol(vid_tlast_d1 && vid_v_area),   // input eol,
    .ready(vid_tready_writer),          // output reg ready,
    // hr specific    
    .data_in_32(vid_tdata32),
    .de_32(valid32 && reg_on),
    .hcount32_0(hcount32_0),
    // common
    .sof(r_vsync_axi[2]), // 2 clocks delay for valid base addresses
    .hr_base(curr_hr_base),
    .lr_base(curr_lr_base),
    .window_type(window_type),
    //
    .S_AXI_araddr(S_AXI_HP3_0_araddr),  // output [31:0] S_AXI_araddr,
    .S_AXI_arburst(S_AXI_HP3_0_arburst),// output [1:0] S_AXI_arburst,
    .S_AXI_arlen(S_AXI_HP3_0_arlen),    // output [3:0] S_AXI_arlen,
    .S_AXI_arready(S_AXI_HP3_0_arready),// input S_AXI_arready,
    .S_AXI_arsize(S_AXI_HP3_0_arsize),  // output [2:0] S_AXI_arsize,
    .S_AXI_arvalid(S_AXI_HP3_0_arvalid),// output S_AXI_arvalid,
    .S_AXI_awaddr(S_AXI_HP3_0_awaddr),  // output [31:0] S_AXI_awaddr,
    .S_AXI_awburst(S_AXI_HP3_0_awburst),// output [1:0] S_AXI_awburst,
    .S_AXI_awlen(S_AXI_HP3_0_awlen),    // output [3:0] S_AXI_awlen,
    .S_AXI_awready(S_AXI_HP3_0_awready),// input S_AXI_awready,
    .S_AXI_awsize(S_AXI_HP3_0_awsize),  // output [2:0] S_AXI_awsize,
    .S_AXI_awvalid(S_AXI_HP3_0_awvalid),// output reg S_AXI_awvalid,
    .S_AXI_bready(S_AXI_HP3_0_bready),  // output S_AXI_bready,
    .S_AXI_bresp(S_AXI_HP3_0_bresp),    // input [1:0] S_AXI_bresp,
    .S_AXI_bvalid(S_AXI_HP3_0_bvalid),  // input S_AXI_bvalid,
    .S_AXI_rdata(S_AXI_HP3_0_rdata),    // input [63:0] S_AXI_rdata,
    .S_AXI_rlast(S_AXI_HP3_0_rlast),    // input S_AXI_rlast,
    .S_AXI_rready(S_AXI_HP3_0_rready),  // output S_AXI_rready,
    .S_AXI_rresp(S_AXI_HP3_0_rresp),    // input [1:0] S_AXI_rresp,
    .S_AXI_rvalid(S_AXI_HP3_0_rvalid),  // input S_AXI_rvalid,
    .S_AXI_wdata(S_AXI_HP3_0_wdata),    // output [63:0] S_AXI_wdata,
    .S_AXI_wlast(S_AXI_HP3_0_wlast),    // output S_AXI_wlast,
    .S_AXI_wready(S_AXI_HP3_0_wready),  // input S_AXI_wready,
    .S_AXI_wstrb(S_AXI_HP3_0_wstrb),    // output [7:0] S_AXI_wstrb,
    .S_AXI_wvalid(S_AXI_HP3_0_wvalid),  // output S_AXI_wvalid,
    //
    .rst(fw_reset),
    .clk(axi_clk)              // input clk
);
    
    always @ (posedge axi_clk) begin

        axi_counter <= axi_counter + 1'b1;

        if (S_AXI_HP3_0_awvalid && S_AXI_HP3_0_awready && S_AXI_HP3_0_awaddr[27:24]<4'hf)
            vid_counter <= 16'd0;
        else if (~vid_counter[15])
            vid_counter <= vid_counter + 1'b1;
            
        if (S_AXI_HP3_0_awvalid && S_AXI_HP3_0_awready && S_AXI_HP3_0_awaddr[27:24]==4'hf)
            nm_counter <= 16'd0;
        else if (~nm_counter[15])
            nm_counter <= nm_counter + 1'b1;
        
        // output: vsync_axi, hsync_axi, de_axi, vcount, hcount;
        if (hdmii_valid) begin
            if (hdmii_dout[25]) begin
                if (vcount!=12'd0) vRes <= vcount;
                vcount <= 12'd0;
                de_active <= 1'b0;
            end else if (hdmii_dout[24]) begin
                if (de_active) begin
                    vcount <= vcount + 1'b1;
                    hRes <= hcount;
                    hcount <= 12'd0;
                    de_active <= 1'b0;
                end
            end else begin
                hcount <= hcount + 1'b1;
                de_active <= 1'b1;
            end
        end
        if (vRes>12'd0) vRes_m1 <= vRes - 1'b1;
        if (hRes>12'd0) hRes_m1 <= hRes - 1'b1;

        // t0
        r_vsync_axi[0] <= vsync_axi;
        r_hsync_axi[0] <= hsync_axi;
        r_de_axi[0] <= de_axi;
        r_vdata_axi[0] <= vdata_axi;
        r_vsync_axi[4:1] <= r_vsync_axi[3:0];
        r_hsync_axi[4:1] <= r_hsync_axi[3:0];
        r_de_axi[4:1] <= r_de_axi[3:0];
        r_vdata_axi[4:1] <= r_vdata_axi[3:0];
        vid_v_area <= (vcount>=vrange[11:0] && vcount<vrange[23:12]);
        vid_h_area <= (hcount>=hrange[11:0] && hcount<hrange[23:12]);
        scr_v_area <= (vcount>=vrange_scr[11:0] && vcount<vrange_scr[23:12]);
        scr_h_area <= (hcount>=hrange_scr[11:0] && hcount<hrange_scr[23:12]);
        if (hcount==hrange[11:0]) vid_h_area <= 1'b1;
        if (hcount==hrange[23:12]) vid_h_area <= 1'b0;
        if (hcount==hrange_scr[11:0]) scr_h_area <= 1'b1;
        if (hcount==hrange_scr[23:12]) scr_h_area <= 1'b0;
        if (de_axi)
            led_counter <= 16'd0;
        else if (~led_counter[15])
            led_counter <= led_counter + 1'b1;
        vid_tlast <= (de_axi && hcount==hRes_m1);

        // t1
        if (r_vsync_axi[0]) 
            scr_vseq = 4'd0;
        else if (r_hsync_axi[0] && scr_v_area) begin
            scr_hseq <= 4'd0;
            scr_vseq <= (scr_vseq==scr_vstride_m1) ? 4'd0 : scr_vseq + 1'b1;
        end else if (r_de_axi[0] && scr_v_area && scr_h_area) 
            scr_hseq <= (scr_hseq==scr_hstride_m1) ? 4'd0 : scr_hseq + 1'b1;
        scr_tvalid_t2 <= (r_de_axi[0] && scr_vseq==4'd0 && scr_hseq==4'd0 && scr_v_area && scr_h_area);
        vid_tlast_d1 <= vid_tlast;


        // advance hr sequence by one
        // if the next seq is skip sequence, advance one more seq        
        if (vsync_axi) begin
            if (curr_hr_seq>=hr_last) begin
                curr_hr_seq <= 4'd0;
                curr_hr_base <= 16'h1b60;
            end else begin
                curr_hr_seq <= curr_hr_seq + 1'b1;
                curr_hr_base <= curr_hr_base  + hr_stepsize;
            end
        end

        // t0
        
        // advance lr sequence by one
        if (vsync_axi && reg_on) begin
            if (curr_lr_seq==4'd9) begin
                curr_lr_seq <= 4'd0;
                curr_lr_base <= 16'h1fb0;
            end else begin
                curr_lr_seq <= curr_lr_seq + 1'b1;
                curr_lr_base <= curr_lr_base  + 16'h6;
            end
            last_buff <= {curr_hr_seq, curr_lr_seq};
            buff_seq <= (buff_seq>=12'd3999) ? 12'd0 : buff_seq + 1'b1;
        end
        
        // t1
        scr_v_area_d1 <= scr_v_area;
        if (~scr_v_area && scr_v_area_d1) 
            trail_count <= 3'b111;
        else if (trail_count[2])
            trail_count <= trail_count - 1'b1;
        // in the rgb mode, convert 3-byte word to 4-byte word
        if (r_vsync_axi[0] || r_hsync_axi[0]) begin
            four_seq <= 2'd0;
            hcount32_0_rgb <= 1'b0;
        end
        // t2
        if (scr_tvalid_t2) begin
            if (four_seq==2'd0)
                vid_keep24 <= r_vdata_axi[1];
            else if (four_seq==2'd1) begin
                vid_tdata32_rgb <= {r_vdata_axi[1][23:16], vid_keep24[7:0], vid_keep24[15:8], vid_keep24[23:16]};
                vid_keep24 <= {8'd0, r_vdata_axi[1][15:0]};
            end else if (four_seq==2'd2) begin
                vid_tdata32_rgb <= {r_vdata_axi[1][15:8], r_vdata_axi[1][23:16], vid_keep24[7:0], vid_keep24[15:8]};
                vid_keep24 <= {16'd0, r_vdata_axi[1][7:0]};
            end else
                vid_tdata32_rgb <= {r_vdata_axi[1][7:0], r_vdata_axi[1][15:8], r_vdata_axi[1][23:16], vid_keep24[7:0]};
            four_seq <= four_seq + 1'b1;
        end

        valid32_rgb <= ((scr_tvalid_t2 && four_seq!=2'd0) || trail_count[2]);
        if (scr_tvalid_t2) four_seq <= four_seq + 1'b1;
        if (valid32_rgb) hcount32_0_rgb <= ~hcount32_0_rgb;

        // t3
        valid32 <= valid32_rgb;// && ~transiting_m1;
        vid_tdata32 <= vid_tdata32_rgb;
        hcount32_0 <= hcount32_0_rgb;

        // reset and vblank generation
        fw_reset <= (vcount==(vRes - 4'd5) && vid_tlast);


        vcmd_monitor <= {2'd0, res_type, window_type, last_view_m1, buff_seq, last_buff}; // 4, 4, 2, 12, 8
        
        vcmd_en_d <= vcmd_control[0];
        if (vcmd_addr[31:28]==4'd0) begin
            if (vcmd_control[1]) begin   // on write
                if (vcmd_control[0] && ~vcmd_en_d) begin
                    case (vcmd_addr[7:0])
                    8'd1: reg_on_req <= vcmd_dout[0];
                    8'd60: label_waddr <= vcmd_dout[20:0];
                    8'd61: label_wdata <= vcmd_dout[7:0];
                    endcase
                end
            end else begin  // on read
                case (vcmd_addr[7:0])
                8'd10: vcmd_din <= {8'd0, vRes_m1, hRes_m1};
                endcase
            end
        end
        
        if (fw_reset) reg_on <= reg_on_req;
        
        if (vsync_axi && ~r_vsync_axi[0]) begin
            
            if (hRes==12'd1920 && vRes==12'd1080) begin
                res_type <= 4'd1;
                window_type <= 4'd8;
                hrange_scr <= {12'd1520, 12'd400};
                vrange_scr <= {12'd988, 12'd92};
            end else if (hRes==12'd1440 && vRes==12'd900 ) begin
                res_type <= 4'd2;
                window_type <= 4'd8;
                hrange_scr <= {12'd1520, 12'd400};
                vrange_scr <= {12'd988, 12'd92};
            end else begin  // 720p and others
                res_type <= 4'd3;
                window_type <= 4'd0;
                hrange_scr <= {12'd1088, 12'd192};
                vrange_scr <= {12'd696, 12'd24};
            end
            
        end
        hrange <= hrange_scr;
        vrange <= vrange_scr;
        
    end

    // 200 MHz clock
    always @ (posedge clk200) begin
		r_clk200_locked <= clk200_locked;
    end

    logic fontout;
    logic [14:0] char_sel = 15'd0;  // 1024 x 32
    logic [7:0] char_code;
    
    logic [23:0] hdmi_vrange, hdmi_hrange, hdmi_vrange_m1, hdmi_hrange_m1, hdmi_vrange_ext, hdmi_hrange_ext, font_vrange, font_hrange, font_hrange_d2;
    logic [23:0] score_vrange, score_hrange, font_vrange_ext, font_hrange_ext;
    logic [11:0] hvcount = 12'd0, hhcount = 12'd0, vrising, hrising, devalid, score_pos;
    logic [8:0] prev_job;
    logic [9:0] hdmi_class, reg_class, label_id;
    logic [5:0] ci = 6'd0, ci_d;
    logic [5:0] cseq = 6'd0, cseq_d, yi;
    logic [14:0] font_addr;
    logic lower_page = 1'b0;

    font_map font_map (
      .clka(PixelClk),  // input wire clka
      .addra(font_addr),// input wire [14 : 0] addra
      .douta(fontout)   // output wire [0 : 0] douta
    );
    assign font_addr = {char_code[6:0], yi[4:1], cseq_d[4:1]};
    
    label_db label_db (
      .clka(axi_clk),           // input wire clka
      .wea(label_waddr[16]),    // input wire [0 : 0] wea
      .addra(label_waddr[14:0]),// input wire [14 : 0] addra
      .dina(label_wdata),       // input wire [7 : 0] dina
      .clkb(PixelClk),          // input wire clkb
      .addrb(char_sel),         // input wire [14 : 0] addrb
      .doutb(char_code)         // output wire [7 : 0] doutb
    );
    assign vrising = (vid_pVSync && ~r_vid_pVSync);
    assign hrising = (vid_pHSync && ~r_vid_pHSync);
    assign devalid = (vid_pVDE);

        
    assign bg_vid_pData[23:16] = (vid_pData[23:22]==2'b00) ? 8'h00 : {vid_pData[23:22] - 2'b01, vid_pData[21:16]};
    assign bg_vid_pData[15:8 ] = (vid_pData[15:14]==2'b00) ? 8'h00 : {vid_pData[15:14] - 2'b01, vid_pData[13:8]};
    assign bg_vid_pData[ 7:0 ] = (vid_pData[ 7:6 ]==2'b00) ? 8'h00 : {vid_pData[ 7:6 ] - 2'b01, vid_pData[ 5:0]};
    assign wbg_vid_pData[23:16] = (vid_pData[23:22]==2'b11) ? 8'hff : {vid_pData[23:22] + 2'b01, vid_pData[21:16]};
    assign wbg_vid_pData[15:8 ] = (vid_pData[15:14]==2'b11) ? 8'hff : {vid_pData[15:14] + 2'b01, vid_pData[13:8]};
    assign wbg_vid_pData[ 7:0 ] = (vid_pData[ 7:6 ]==2'b11) ? 8'hff : {vid_pData[ 7:6 ] + 2'b01, vid_pData[ 5:0]};
    assign bg_vid_pData2 = lower_page ? bg_vid_pData : wbg_vid_pData;
    
    logic [3:0] box1, box2, box3, box4, box5;
    
    // pixel clock (valiable)
    always @ (posedge PixelClk) begin
    
        hdmi_on <= reg_on;
        hdmi_on_d1 <= hdmi_on;
    
        r_vid_pVDE <= vid_pVDE;
        r_vid_pHSync <= vid_pHSync;
        r_vid_pVSync <= vid_pVSync;
        
        hdmii_din[23:0] <= {vid_pData[23:16], vid_pData[7:0], vid_pData[15:8]};
        hdmii_wr_en <= vrising || hrising || devalid;
        if (vrising) begin
            hdmii_din[25:24] <= 2'b10;
            hvcount <= 12'd0;
            yi <= 5'd0;
            lower_page <= 1'b1;
        end else if (hrising) begin
            hdmii_din[25:24] <= 2'b01;
            if (hhcount>12'd0) begin
                hvcount <= hvcount + 1'b1;
                if (box2[1:0]==2'b11) yi <= yi + 1'b1;
            end
            hhcount <= 12'd0;
            ci <= 6'd0;
            cseq <= 6'd0;
        end else begin
            hdmii_din[25:24] <= 2'b00;
            if (vid_pVDE) hhcount <= hhcount + 1'b1;
        end

        if (~hdmi_nm_monitor_d1[9] && hdmi_nm_monitor_d1[8:0]!=prev_job) begin
            prev_job <= hdmi_nm_monitor_d1[8:0];
            hdmi_class <= hdmi_nm_monitor_d1[19:10];
            score_pos <= {1'b0, hdmi_nm_monitor_d1[31:21]};
        end

        hdmi_nm_monitor <= nm_monitor;
        hdmi_nm_monitor_d1 <= hdmi_nm_monitor;
        hdmi_vrange_m1 <= vrange_scr;       
        hdmi_hrange_m1 <= hrange_scr;       
        if (vrising) begin
            hdmi_vrange <= hdmi_vrange_m1;
            hdmi_hrange <= hdmi_hrange_m1;
            reg_class <= hdmi_class;
        end
        if (hvcount==12'd1) begin
            hdmi_vrange_ext <= {hdmi_vrange[23:12] + 12'd2, hdmi_vrange[11:0] - 12'd2};
            hdmi_hrange_ext <= {hdmi_hrange[23:12] + 12'd2, hdmi_hrange[11:0] - 12'd2};
            font_vrange <= {hdmi_vrange[11:0] + 12'd47, hdmi_vrange[11:0] + 12'd15};
            font_hrange <= {hdmi_hrange[11:0] + 12'd847, hdmi_hrange[11:0] + 12'd15};
            font_hrange_d2 <= {hdmi_hrange[11:0] + 12'd849, hdmi_hrange[11:0] + 12'd17};
            font_vrange_ext <= {hdmi_vrange[11:0] + 12'd52, hdmi_vrange[11:0] + 12'd10};
            font_hrange_ext <= {hdmi_hrange[11:0] + 12'd1034, hdmi_hrange[11:0] + 12'd10};
            score_vrange <= {hdmi_vrange[11:0] + 12'd59, hdmi_vrange[11:0] + 12'd57};
            score_hrange <= {font_hrange_ext[11:0] + score_pos, font_hrange_ext[11:0]};
        end else if (hvcount==12'd360) begin
            lower_page <= 1'b0;
            yi <= 5'd0;
            font_vrange <= {hdmi_vrange[23:12] - 12'd5, hdmi_vrange[23:12] - 12'd37};
            font_hrange <= {hdmi_hrange[23:12] - 12'd15, hdmi_hrange[23:12] - 12'd847};
            font_hrange_d2 <= {hdmi_hrange[23:12] - 12'd13, hdmi_hrange[23:12] - 12'd845};
        end
        
        box1[0] <= (hvcount>=hdmi_vrange[11:0]);
        box1[1] <= (hvcount<hdmi_vrange[23:12]);
        box1[2] <= (hhcount>=hdmi_hrange[11:0]);
        box1[3] <= (hhcount<hdmi_hrange[23:12]);
        box2[0] <= (hvcount>=font_vrange[11:0]);
        box2[1] <= (hvcount<font_vrange[23:12]);
        box2[2] <= (hhcount>=font_hrange_d2[11:0]);
        box2[3] <= (hhcount<font_hrange_d2[23:12]);
        box3[0] <= (hvcount>=font_vrange_ext[11:0]);
        box3[1] <= (hvcount<font_vrange_ext[23:12]);
        box3[2] <= (hhcount>=font_hrange_ext[11:0]);
        box3[3] <= (hhcount<font_hrange_ext[23:12]);
        box4[0] <= (hvcount>=hdmi_vrange_ext[11:0]);
        box4[1] <= (hvcount<hdmi_vrange_ext[23:12]);
        box4[2] <= (hhcount>=hdmi_hrange_ext[11:0]);
        box4[3] <= (hhcount<hdmi_hrange_ext[23:12]);
        box5[0] <= (hvcount>=score_vrange[11:0]);
        box5[1] <= (hvcount<score_vrange[23:12]);
        box5[2] <= (hhcount>=score_hrange[11:0]);
        box5[3] <= (hhcount<score_hrange[23:12]);
        
        // red blue green
        if (box2==4'b1111) begin
            r_vid_pData <= (fontout) ? (lower_page?24'hf0f0f0:24'h808080) : bg_vid_pData2;    // font area
            overlay <= 1'b1;
        end else if (lower_page && box3==4'b1111) begin             // font margin
            r_vid_pData <= bg_vid_pData2;
            overlay <= 1'b1;
        end else if (box5==4'b1111) begin
            r_vid_pData <= 24'hff80ff;      // score bar
            overlay <= 1'b1;
        end else if (box1==4'b1111) begin             // active area
            r_vid_pData <= vid_pData;
            overlay <= 1'b0;
        end else if (box4==4'b1111) begin             // frame of active area
            r_vid_pData <= 24'h8080ff;      // green frame
            overlay <= 1'b1;
        end else begin
            r_vid_pData <= vid_pData;
            overlay <= 1'b0;
        end

        if (box2[1:0]==2'b11 && hhcount>=font_hrange[11:0] && hhcount<font_hrange[23:12]) begin
            if (cseq==6'd25) begin
                cseq <= 6'd0;
                ci <= ci + 1'b1;
            end else
                cseq <= cseq + 1'b1;
            char_sel <= {label_id, ci[4:0]};
        end
        cseq_d <= cseq;
        ci_d <= ci;
        label_id <= lower_page ? (hdmi_on_d1 ? reg_class : 10'd1006) : 10'd1004;

    end
    
    
    always @ (posedge app_clk) begin

        app_counter <= app_counter + 'b1;
        button <= btn;
        r_sw <= sw;
        tick_b22_app <= app_counter[22];
        led_pulse <= (app_counter[26:23]==4'b0000);
        led_pulse2 <= (app_counter[26:23]==4'b0001);
       
        cmd_en_d <= cmd_control[0];
        if (cmd_addr[31:28]==4'd0) begin   // the control(top level) unit is enabled
            if (cmd_control[1]) begin      // on write
                if (cmd_control[0] && ~cmd_en_d) begin
                    case (cmd_addr[7:0])
                    8'd3: gpio_output <= cmd_dout[4:0];
                    8'd4: color_led <= cmd_dout[2:0];
//                    8'd5: nm_monitor <= cmd_dout;
                    endcase
                end
            end else begin  // on read
                case (cmd_addr[7:0])
                8'd0: sys_status <= {26'd0, r_sw, button};
                8'd1: sys_status <= SYSTEM_VERSION;
                8'd2: sys_status <= CLOCK_SPEED;
                8'd3: sys_status <= app_counter;
                endcase
            end
        end
        
        // distribute commands over units
        
        case (cmd_addr[31:28])
        4'd0: cmd_din <= sys_status;
        4'd1: cmd_din <= nm_status;
        endcase
        
        nm_monitor <= cmd_monitor;
        
    end

endmodule
