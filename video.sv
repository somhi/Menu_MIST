`timescale 1ns / 1ps

module video(
	input         clk_pix, // Video clock (24 MHz)
	input			  clk_ram, // Video ram clock (>50 MHz)

	input         SPI_SCK,
	input         SPI_SS3,
	input         SPI_DI,

	// Video outputs
	output  [5:0] VGA_R,
	output  [5:0] VGA_G,
	output  [5:0] VGA_B,
	output        VGA_VS,
	output        VGA_HS,
	
	input         scandoubler_disable
);

`define HPOS 9'd18
`define VPOS 9'd36

reg clk_12;
always @(posedge clk_pix) clk_12 <= !clk_12;

ram ram(
	.clock(clk_ram),

	.address(addr),
	.wren(1'b0),
	.rden(1'b1),
	.q(data)
);

reg  [9:0] hc;
wire [8:0] hcpic = hc[9:1] - `HPOS;
reg  [8:0] vc;
wire [8:0] vcpic = vc - `VPOS;

always @(posedge clk_12) begin
	if(hc == 767) begin 
		hc <=0;
		if (vc == 311) begin 
			vc <= 9'd0;
		end else vc <= vc + 1'd1;
	end else hc <= hc + 1'd1;
end

wire HBlank = !((hc[9:1] >= `HPOS) && (hc[9:1] < (`HPOS+9'd256)));
wire HSync  = (hc[9:1] >= 9'd312);

wire VBlank = !((vc >= `VPOS) && (vc < (`VPOS + 9'd256)));
wire VSync  = (vc >= 9'd308);

wire [15:0] data;
wire [12:0] addr = (!HBlank && !VBlank) ? {vcpic[7:0],hcpic[7:3]} : 13'b0;

wire  [1:0] dotc = dots[1:0];
reg  [15:0] dots;
reg  viden;
reg  dotm = 1'b0;

always @(negedge clk_12) begin
	dotm  <= !dotm;
	dots  <= (data >> {hcpic[2:0], 1'b0});
	viden <= !HBlank && !VBlank;
end

//Colors: White, Red, Blue, Black
reg  [31:0] palette = 32'b00111111_00110000_00000011_00000000;
wire [31:0] comp = palette >> {dotc[0],dotc[1], 2'b000};

wire Rh = viden && comp[5];
wire Rl = viden && comp[4];
wire Gh = viden && comp[3];
wire Gl = viden && comp[2];
wire Bh = viden && comp[1];
wire Bl = viden && comp[0];

assign VGA_HS     = scandoubler_disable ? ~(HSync ^ VSync) : ~sd_hs;
assign VGA_VS     = scandoubler_disable ? 1'b1 : ~sd_vs;
wire [5:0] VGA_Rx = scandoubler_disable ? {Rh, Rh, Rl, Rl, Rl, Rl} : {sd_r, sd_r[1:0]};
wire [5:0] VGA_Gx = scandoubler_disable ? {Gh, Gh, Gl, Gl, Gl, Gl} : {sd_g, sd_g[1:0]};
wire [5:0] VGA_Bx = scandoubler_disable ? {Bh, Bh, Bl, Bl, Bl, Bl} : {sd_b, sd_b[1:0]};

wire sd_hs, sd_vs;
wire [3:0] sd_r;
wire [3:0] sd_g;
wire [3:0] sd_b;

scandoubler scandoubler(
	.clk_x2(clk_pix),
	.clk(clk_12),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines(2'b00),
		    
	.hs_in(HSync),
	.vs_in(VSync),
	.r_in({Rh,Rh,Rl,Rl}),
	.g_in({Gh,Gh,Gl,Gl}),
	.b_in({Bh,Bh,Bl,Bl}),

	.hs_out(sd_hs),
	.vs_out(sd_vs),
	.r_out(sd_r),
	.g_out(sd_g),
	.b_out(sd_b)
);

osd #(-10'd36, 10'd0, 3'd4) osd(
	.*,
	.clk_pix(scandoubler_disable ? clk_12 : clk_pix),
	.OSD_VS(scandoubler_disable ? ~VSync : ~sd_vs),
	.OSD_HS(scandoubler_disable ? ~HSync : ~sd_hs)
);

endmodule
