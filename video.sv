`timescale 1ns / 1ps

module video(
	input         clk_pix, // Video clock (24 MHz)

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

reg clk_12;
always @(posedge clk_pix) clk_12 <= !clk_12;

reg  [9:0] hc;
reg  [8:0] vc;
reg  [9:0] vvc;

reg [22:0] rnd_reg;
wire [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};

wire [22:0] rnd;
lfsr random(rnd);

always @(posedge clk_12) begin
	if(hc == 767) begin 
		hc <=0;
		if (vc == 311) begin 
			vc <= 9'd0;
			vvc <= vvc + 9'd6;
		end else vc <= vc + 1'd1;
	end else hc <= hc + 1'd1;

	rnd_reg <= rnd;
end

reg  [7:0] cos_out;
wire [5:0] cos_g = cos_out[7:3]+6'd32;
cos cos(vvc + {vc, 2'b00}, cos_out);

wire HBlank = (hc < 10'd020) || (hc > 10'd680);
wire HSync  = (hc >= 10'd707);
wire VBlank = ((vc < 9'd010) || (vc > 9'd306));
wire VSync  = (vc >= 9'd308);
wire viden  = !HBlank && !VBlank;

wire [5:0] comp_v = (cos_g >= rnd_c) ? cos_g - rnd_c : 6'd0;
wire [5:0] R = !viden ? 6'd0 : comp_v;
wire [5:0] G = !viden ? 6'd0 : comp_v;
wire [5:0] B = !viden ? 6'd0 : comp_v;

assign VGA_HS = scandoubler_disable ? ~(HSync ^ VSync) : ~sd_hs;
assign VGA_VS = scandoubler_disable ? 1'b1 : ~sd_vs;
wire [5:0] VGA_Rx  = scandoubler_disable ? R : sd_r;
wire [5:0] VGA_Gx  = scandoubler_disable ? G : sd_g;
wire [5:0] VGA_Bx  = scandoubler_disable ? B : sd_b;

wire sd_hs, sd_vs;
wire [5:0] sd_r;
wire [5:0] sd_g;
wire [5:0] sd_b;

scandoubler scandoubler(
	.clk_x2(clk_pix),

	.scanlines(2'b00),

	.hs_in(HSync),
	.vs_in(VSync),
	.r_in(R),
	.g_in(G),
	.b_in(B),

	.hs_out(sd_hs),
	.vs_out(sd_vs),
	.r_out(sd_r),
	.g_out(sd_g),
	.b_out(sd_b)
);

osd #(10'd0, 10'd0, 3'd4) osd(
	.*,
	.clk_pix(scandoubler_disable ? clk_12 : clk_pix),
	.OSD_VS(scandoubler_disable ? ~VSync : ~sd_vs),
	.OSD_HS(scandoubler_disable ? ~HSync : ~sd_hs)
);

endmodule
