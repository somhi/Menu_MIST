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
   input         SPI_SS2,
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

`define LINE_MAX 312
//`define LINE_MAX 262

wire clk_x2, clk_pix, clk_ram, pll_locked;
pll pll
(
	.inclk0(CLOCK_27),
	.c0(clk_ram),
	.c2(clk_x2),
	.c3(clk_pix),
	.locked(pll_locked)
);

assign SDRAM_CLK = clk_ram;
assign SDRAM_CKE = 1;
//______________________________________________________________________________
//
// MIST ARM I/O
//
wire		   scandoubler_disable;
wire		   ypbpr;
wire           no_csync;

user_io #(.STRLEN(6), .FEATURES(32'd1)) user_io
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

assign LED = ~ioctl_downl;

wire        ioctl_downl;
wire        ioctl_upl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_dout;

data_io data_io(
	.clk_sys       ( clk_ram      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_upload  ( ioctl_upl    ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_din     ( ioctl_din    ),
	.ioctl_dout    ( ioctl_dout   )
);

reg  [23:0] bmp_data_start;
wire [23:0] downl_addr = ioctl_addr - bmp_data_start;
reg         bmp_loaded = 0;
reg         port1_req;

always @(posedge clk_ram) begin
	reg        ioctl_wr_last = 0;
	reg        ioctl_downl_last = 0;

	ioctl_wr_last <= ioctl_wr;
	ioctl_downl_last <= ioctl_downl;

	if (ioctl_downl) begin
		if (~ioctl_wr_last & ioctl_wr) begin
			if (ioctl_addr == 10) bmp_data_start[7:0] <= ioctl_dout;
			else if (ioctl_addr == 11) bmp_data_start[15:8] <= ioctl_dout;
			else if (ioctl_addr == 12) bmp_data_start[23:16] <= ioctl_dout;
			port1_req <= ~port1_req;
		end
	end
	if (ioctl_downl_last & ~ioctl_downl) bmp_loaded <= 1;
end

wire [31:0] cpu_q;
wire [23:0] cpu1_addr;

always @(posedge clk_ram) begin
	cpu1_addr <= (((`LINE_MAX-1-vc)<<9)+hc)<<2;
end

sdram #(.MHZ(80)) sdram(
	.*,
	.init_n        ( pll_locked   ),
	.clk           ( clk_ram      ),
	.clkref        ( ),

	// ROM upload
	.port1_req     ( port1_req    ),
	.port1_ack     ( ),
	.port1_a       ( downl_addr[23:1] ),
	.port1_ds      ( {downl_addr[0], ~downl_addr[0]} ),
	.port1_we      ( ioctl_downl ),
	.port1_d       ( {ioctl_dout, ioctl_dout} ),
	.port1_q       (  ),

	// CPU/video access
	.cpu1_addr     ( cpu1_addr[23:2] ),
	.cpu1_q        ( cpu_q ),
	.cpu1_oe       ( ~ioctl_downl )
);

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
		if(vc == `LINE_MAX-1) begin 
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
	if (hc == 511) HBlank <= 1;
		else if (hc == 639) HBlank <= 0;

	if (hc == 545) HSync <= 1;
		else if (hc == 577) HSync <= 0;

	if(vc == `LINE_MAX-3) VSync <= 1;
		else if (vc == 0) VSync <= 0;

	if(vc == `LINE_MAX-5) VBlank <= 1;
		else if (vc == 2) VBlank <= 0;
end

///// Noise
reg  [7:0] cos_out;
wire [5:0] cos_g = cos_out[7:3]+6'd32;
cos cos(vvc + {vc, 2'b00}, cos_out);

wire [5:0] comp_v = (cos_g >= rnd_c) ? cos_g - rnd_c : 6'd0;

///// Bitmap
wire [5:0] bmp_r = cpu_q[23:18];
wire [5:0] bmp_g = cpu_q[15:10];
wire [5:0] bmp_b = cpu_q[7:2];

///// Final pixel value
wire [5:0] R_in = !viden ? 6'd0 : bmp_loaded ? bmp_r : comp_v;
wire [5:0] G_in = !viden ? 6'd0 : bmp_loaded ? bmp_g : comp_v;
wire [5:0] B_in = !viden ? 6'd0 : bmp_loaded ? bmp_b : comp_v;

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
	.ce_divider     ( 1'b1             ),
	.rotate         ( 2'b00            ),
	.blend          ( 1'b0             ),
	.scandoubler_disable( scandoubler_disable ),
	.scanlines      ( 2'b00            ),
	.ypbpr          ( ypbpr            ),
	.no_csync       ( no_csync         )
	);

endmodule
