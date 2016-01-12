////////////////////////////////////////////////////////////////////////////////
//
//
//
//  MENU for MIST board
//  (C) 2016 Sorgelig
//
//
//
////////////////////////////////////////////////////////////////////////////////

module MENU(
   input  wire [1:0]  CLOCK_27,            // Input clock 27 MHz

   output wire [5:0]  VGA_R,
   output wire [5:0]  VGA_G,
   output wire [5:0]  VGA_B,
   output wire        VGA_HS,
   output wire        VGA_VS,
	 
   output wire        LED,

   output wire        AUDIO_L,
   output wire        AUDIO_R,

   input  wire        SPI_SCK,
   output wire        SPI_DO,
   input  wire        SPI_DI,
   input  wire        SPI_SS2,
   input  wire        SPI_SS3,
   input  wire        SPI_SS4,
   input  wire        CONF_DATA0,

   output wire [12:0] SDRAM_A,
   inout  wire [15:0] SDRAM_DQ,
   output wire        SDRAM_DQML,
   output wire        SDRAM_DQMH,
   output wire        SDRAM_nWE,
   output wire        SDRAM_nCAS,
   output wire        SDRAM_nRAS,
   output wire        SDRAM_nCS,
   output wire [1:0]  SDRAM_BA,
   output wire        SDRAM_CLK,
   output wire        SDRAM_CKE
);

//______________________________________________________________________________
//
// Clocks
//

wire clk_120mhz, clk_120mhzS, clk_24mhz, plock;

pll pll(
	.inclk0(CLOCK_27[0]),
	.c0(clk_120mhz),  		//120MHz, 0 deg
	.c1(clk_120mhzS),  		//120MHz, 60 deg
	.c2(clk_24mhz),    		//24MHz
	.locked(plock)
);

assign SDRAM_CLK = clk_120mhzS;
wire   clk_ram   = clk_120mhz;
wire   clk_pix   = clk_24mhz;

//______________________________________________________________________________
//
// MIST ARM I/O
//
wire		   scandoubler_disable;

user_io #(.STRLEN(6)) user_io (
	.conf_str("MENU;;"),
	
	.SPI_SCK(SPI_SCK),
	.CONF_DATA0(CONF_DATA0),
	.SPI_DO(SPI_DO),
	.SPI_DI(SPI_DI),
	.scandoubler_disable(scandoubler_disable)
);

assign LED = 1'b1;

//______________________________________________________________________________
//
// Video 
//

video video(.*);
endmodule
