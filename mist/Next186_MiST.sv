// SiDi / MiST TOP module for NEXT186.

module Next186_MiST
(
    input         CLOCK_27,   // Input clock 27 MHz

    output  [5:0] VGA_R,
    output  [5:0] VGA_G,
    output  [5:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,

    output        LED,

    output        AUDIO_L,
    output        AUDIO_R,

	input         UART_RX,
	output        UART_TX,

    input         SPI_SCK,
    output        SPI_DO,
    input         SPI_DI,
    input         SPI_SS2,
    input         SPI_SS3,
    input         CONF_DATA0,

	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,
	output        SDRAM_CKE,
	output        SDRAM_nCS,
	output        SDRAM_CLK
);

`include "build_id.v"

parameter CONF_STR = {
	"NEXT186;;",
	"O12,CPU Speed,Maximum,/2,/3,/4;",
	"T0,Reset;",
	"V,",`BUILD_DATE
};

wire  [1:0] cpu_speed = status[2:1];

// core's raw video 
wire  [5:0] core_r, core_g, core_b;
wire        core_hs, core_vs;

wire        clk_25, clk_sdr, clk_50, CLK44100x256, CLK14745600;
wire        clk_sys = clk_25;

assign SDRAM_CKE = 1'b1;

dcm dcm_system (
	.inclk0(CLOCK_27), 
	.c0(clk_25), 
	.c1(clk_sdr),
	.c2(SDRAM_CLK),
	.c3(clk_50)
);

dcm_misc dcm_misc (
	.inclk0(CLOCK_27),
	.c0(CLK44100x256),
	.c1(CLK14745600)
);

wire        clk_cpu, clk_dsp;
dcm_cpu dcm_cpu_inst (
	.inclk0(CLOCK_27), 
	.c0(clk_cpu),
	.c1(clk_dsp)
);

reg  reset;
    
always @(posedge clk_cpu) reset <= status[0] | buttons[1];
	
// user io
wire [63:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;

wire        ps2_kbd_clk, ps2_kbd_clk_i;
wire        ps2_kbd_dat, ps2_kbd_dat_i;
wire        ps2_mouse_clk, ps2_mouse_clk_i;
wire        ps2_mouse_dat, ps2_mouse_dat_i;

// conections between user_io (implementing the SPI communication 
// to the io controller) and the legacy 
wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire        sd_conf;
wire        sd_sdhc; 
wire  [7:0] sd_dout;
wire        sd_dout_strobe;
wire  [7:0] sd_din;
wire        sd_din_strobe;
wire  [8:0] sd_buff_addr;
wire        sd_ack_conf;
wire        img_mounted;
wire [31:0] img_size;

wire  [7:0] joystick_0;
wire  [7:0] joystick_1;
wire [15:0] joystick_analog_0;
wire [15:0] joystick_analog_1;

wire        scandoubler_disable;
wire        ypbpr;
wire        no_csync;

user_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(2000), .PS2BIDIR(1'b1)) user_io(
	.conf_str        ( CONF_STR      ),
	.clk_sys         ( clk_cpu       ),
	.clk_sd          ( clk_cpu       ),

	// the spi interface
	.SPI_CLK         ( SPI_SCK       ),
	.SPI_SS_IO       ( CONF_DATA0    ),
	.SPI_MISO        ( SPI_DO        ),   // tristate handling inside user_io
	.SPI_MOSI        ( SPI_DI        ),

	.joystick_0        ( joystick_0 ),
	.joystick_1        ( joystick_1 ),
	.joystick_analog_0 ( joystick_analog_0 ),
	.joystick_analog_1 ( joystick_analog_1 ),

	.status          ( status        ),
	.switches        ( switches      ),
	.buttons         ( buttons       ),
	.scandoubler_disable ( scandoubler_disable ),
	.ypbpr           ( ypbpr         ),
	.no_csync        ( no_csync      ),

   // interface to embedded legacy sd card wrapper
	.sd_lba          ( sd_lba        ),
	.sd_rd           ( sd_rd         ),
	.sd_wr           ( sd_wr         ),
	.sd_ack          ( sd_ack        ),
	.sd_conf         ( sd_conf       ),
	.sd_sdhc         ( sd_sdhc       ),
	.sd_dout         ( sd_dout       ),
	.sd_dout_strobe  ( sd_dout_strobe),
	.sd_din          ( sd_din        ),
	.sd_din_strobe   ( sd_din_strobe ),
	.sd_buff_addr    ( sd_buff_addr  ),
	.sd_ack_conf     ( sd_ack_conf   ),

	.img_mounted     ( img_mounted   ),
	.img_size        ( img_size      ),

	.ps2_kbd_clk     ( ps2_kbd_clk   ), 
	.ps2_kbd_data    ( ps2_kbd_dat   ),
	.ps2_kbd_clk_i   ( ps2_kbd_clk_i ),
	.ps2_kbd_data_i  ( ps2_kbd_dat_i ),
	.ps2_mouse_clk   ( ps2_mouse_clk ), 
	.ps2_mouse_clk_i ( ps2_mouse_clk_i ), 
	.ps2_mouse_data  ( ps2_mouse_dat ),
	.ps2_mouse_data_i( ps2_mouse_dat_i )
);

// wire the sd card to the user port
wire sd_sck;
wire sd_cs;
wire sd_sdi;
reg  sd_sdi_r;
wire sd_sdo;

always @(posedge clk_cpu) sd_sdi_r <= sd_sdi;

sd_card sd_card (
	// connection to io controller
	.clk_sys      ( clk_cpu        ),
	.sd_lba       ( sd_lba         ),
	.sd_rd        ( sd_rd          ),
	.sd_wr        ( sd_wr          ),
	.sd_ack       ( sd_ack         ),
	.sd_ack_conf  ( sd_ack_conf    ),
	.sd_conf      ( sd_conf        ),
	.sd_sdhc      ( sd_sdhc        ),
	.sd_buff_dout ( sd_dout        ),
	.sd_buff_wr   ( sd_dout_strobe ),
	.sd_buff_din  ( sd_din         ),
	.sd_buff_addr ( sd_buff_addr   ),
	.img_mounted  ( img_mounted    ),
	.img_size     ( img_size       ),
	.allow_sdhc   ( 1'b1           ),
 
	// connection to local CPU
	.sd_cs   ( sd_cs          ),
	.sd_sck  ( sd_sck         ),
	.sd_sdi  ( sd_sdi_r       ),
	.sd_sdo  ( sd_sdo         )
);

mist_video #(.COLOR_DEPTH(6)) mist_video (
	.clk_sys     ( clk_sys    ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( 2'b00      ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b0       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( 1'b1 ), // already VGA
	// disable csync without scandoubler
	.no_csync    ( no_csync   ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( core_r     ),
	.G           ( core_g     ),
	.B           ( core_b     ),

	.HSync       ( core_hs    ),
	.VSync       ( core_vs    ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

//////NEXT186///////////////

wire [3:0]IO;

system sys_inst (
	.clk_25(clk_25),
	.clk_sdr(clk_sdr),
	.CLK44100x256(CLK44100x256),
	.CLK14745600(CLK14745600),
	.clk_50(clk_50),

	.clk_cpu(clk_cpu),
	.clk_dsp(clk_dsp),

	.cpu_speed(cpu_speed),

	.VGA_R(core_r),
	.VGA_G(core_g),
	.VGA_B(core_b),
	.VGA_HSYNC(core_hs),
	.VGA_VSYNC(core_vs),
	.frame_on(),

	.sdr_n_CS_WE_RAS_CAS({SDRAM_nCS, SDRAM_nWE, SDRAM_nRAS, SDRAM_nCAS}),
	.sdr_BA(SDRAM_BA),
	.sdr_ADDR(SDRAM_A),
	.sdr_DATA(SDRAM_DQ),
	.sdr_DQM({SDRAM_DQMH, SDRAM_DQML}),

	.LED(LED),

	.BTN_RESET(reset),
	.BTN_NMI(1'b0),

	.RS232_DCE_RXD(),
	.RS232_DCE_TXD(),
	.RS232_EXT_RXD(UART_RX),
	.RS232_EXT_TXD(UART_TX),

	.SD_n_CS(sd_cs),
	.SD_DI(sd_sdi),
	.SD_CK(sd_sck),
	.SD_DO(sd_sdo),

	.AUD_L(AUDIO_L),
	.AUD_R(AUDIO_R),

	.PS2_CLK1_I(ps2_kbd_clk),
	.PS2_CLK1_O(ps2_kbd_clk_i),
	.PS2_CLK2_I(ps2_mouse_clk),
	.PS2_CLK2_O(ps2_mouse_clk_i),
	.PS2_DATA1_I(ps2_kbd_dat),
	.PS2_DATA1_O(ps2_kbd_dat_i),
	.PS2_DATA2_I(ps2_mouse_dat),
	.PS2_DATA2_O(ps2_mouse_dat_i),

	.RS232_HOST_RXD(),
	.RS232_HOST_TXD(),
	.RS232_HOST_RST(),

	.GPIO(), //{IO, GPIO}),

	.I2C_SCL(),//I2C_SCLK),
	.I2C_SDA() //I2C_SDAT)
);

endmodule
