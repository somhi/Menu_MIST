////////////////////////////////////////////////////////////////////////////////
//
//
//
//  MENU for MIST board
//  (C) 2016 Sorgelig
//  (C) 2022 Slingshot
//
//
////////////////////////////////////////////////////////////////////////////////

module MENU
(
   input         CLOCK_27,   // Input clock 27 MHz

   output  [5:0] VGA_R,
   output  [5:0] VGA_G,
   output  [5:0] VGA_B,
   output        VGA_HS,
   output        VGA_VS,

   output        LED,

   input         SPI_SCK,
   output        SPI_DO,
   input         SPI_DI,
   input         SPI_SS3,
   input         CONF_DATA0,

   output [12:0] SDRAM_A,
   inout  [15:0] SDRAM_DQ,
   output        SDRAM_DQML,
   output        SDRAM_DQMH,
   output        SDRAM_nWE,
   output        SDRAM_nCAS,
   output        SDRAM_nRAS,
   output        SDRAM_nCS,
   output  [1:0] SDRAM_BA,
   output        SDRAM_CLK,
   output        SDRAM_CKE
);

wire clk_x2, clk_pix, clk_ram, locked;
pll pll
(
	.inclk0(CLOCK_27),
	.c0(clk_ram),
	.c2(clk_x2),
	.c3(clk_pix),
	.locked(locked)
);

assign SDRAM_CLK = clk_ram;
//______________________________________________________________________________
//
// MIST ARM I/O
//
wire		   scandoubler_disable;
wire		   ypbpr;
wire           no_csync;

user_io #(.STRLEN(6)) user_io
(
	.clk_sys(clk_x2),
	.conf_str("MENU;;"),
	
	.SPI_CLK(SPI_SCK),
	.SPI_SS_IO(CONF_DATA0),
	.SPI_MISO(SPI_DO),
	.SPI_MOSI(SPI_DI),
	.scandoubler_disable(scandoubler_disable),
	.ypbpr(ypbpr),
	.no_csync(no_csync)
);

assign LED = 1;

sram ram
(
	.*,
	.init(~locked),
	.clk(clk_ram),
	.wtbt(3),
	.dout(),
	.din(0),
	.rd(0),
	.ready()
);

reg        we;
reg [24:0] addr = 0;

always @(posedge clk_ram) begin
	integer   init = 5000000;
	reg [4:0] cnt = 9;
	
	if(init) init <= init - 1;
	else begin
		cnt <= cnt + 1'b1;
		we <= &cnt;
		if(cnt == 8) addr <= addr + 1'd1;
	end
end

//______________________________________________________________________________
//
// Video 
//

reg  [9:0] hc;
reg  [8:0] vc;
reg  [9:0] vvc;

reg [22:0] rnd_reg;
wire [5:0] rnd_c = {rnd_reg[0],rnd_reg[1],rnd_reg[2],rnd_reg[2],rnd_reg[2],rnd_reg[2]};

wire [22:0] rnd;
lfsr random(rnd);

always @(posedge clk_pix) begin
	if(hc == 639) begin
		hc <= 0;
		if(vc == 311) begin 
			vc <= 0;
			vvc <= vvc + 9'd6;
		end else begin
			vc <= vc + 1'd1;
		end
	end else begin
		hc <= hc + 1'd1;
	end
	
	rnd_reg <= rnd;
end

reg  HBlank;
reg  HSync;
reg  VBlank;
reg  VSync;
wire viden  = !HBlank && !VBlank;

always @(posedge clk_pix) begin
	if (hc == 310) HBlank <= 1;
		else if (hc == 420) HBlank <= 0;

	if (hc == 336) HSync <= 1;
		else if (hc == 368) HSync <= 0;

	if(vc == 308) VSync <= 1;
		else if (vc == 0) VSync <= 0;

	if(vc == 306) VBlank <= 1;
		else if (vc == 2) VBlank <= 0;
end

reg  [7:0] cos_out;
wire [5:0] cos_g = cos_out[7:3]+6'd32;
cos cos(vvc + {vc, 2'b00}, cos_out);

wire [5:0] comp_v = (cos_g >= rnd_c) ? cos_g - rnd_c : 6'd0;
wire [5:0] R_in = !viden ? 6'd0 : comp_v;
wire [5:0] G_in = !viden ? 6'd0 : comp_v;
wire [5:0] B_in = !viden ? 6'd0 : comp_v;

mist_video #(
	.COLOR_DEPTH(6),
	.SD_HCNT_WIDTH(10),
	.OSD_X_OFFSET(10),
	.OSD_Y_OFFSET(0),
	.OSD_COLOR(4)
) mist_video (
	.clk_sys        ( clk_x2           ),
	.SPI_SCK        ( SPI_SCK          ),
	.SPI_SS3        ( SPI_SS3          ),
	.SPI_DI         ( SPI_DI           ),
	.R              ( R_in             ),
	.G              ( G_in             ),
	.B              ( B_in             ),
	.HSync          ( ~HSync           ),
	.VSync          ( ~VSync           ),
	.VGA_R          ( VGA_R            ),
	.VGA_G          ( VGA_G            ),
	.VGA_B          ( VGA_B            ),
	.VGA_VS         ( VGA_VS           ),
	.VGA_HS         ( VGA_HS           ),
	.ce_divider     ( 1'b0             ),
	.rotate         ( 2'b00            ),
	.blend          ( 1'b0             ),
	.scandoubler_disable( scandoubler_disable ),
	.scanlines      ( 2'b00            ),
	.ypbpr          ( ypbpr            ),
	.no_csync       ( no_csync         )
	);

endmodule
