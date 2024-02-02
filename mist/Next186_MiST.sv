// SiDi / MiST TOP module for NEXT186.

module Next186_MiST(
	input         CLOCK_27,
`ifdef USE_CLOCK_50
	input         CLOCK_50,
`endif

	output        LED,
	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

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
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
	input         UART_RX,
	output        UART_TX

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

`ifdef USE_AUDIO_IN
localparam bit USE_AUDIO_IN = 1;
`else
localparam bit USE_AUDIO_IN = 0;
`endif

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 0;
assign SDRAM2_DQMH = 0;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

`include "build_id.v"

parameter CONF_STR = {
	"NEXT186;;",
	"S1C,CUEISO,Mount CD;",
	`SEP
	"O24,CPU Speed,Maximum,/2,/3,/4,/8,/16,/32;",
	"O56,ISA Bus Wait,1us,2us,3us,4us;",
	"O7,Fake 286,Off,On;",
	"O8,Swap Joysticks,Off,On;",
	"O9,MIDI,MPU401,COM1;",
	"OA,Adlib,On,Invisible;",
	`SEP
	"T1,NMI;",
	"T0,Reset;",
	"V,",`BUILD_DATE
};

wire        btn_nmi = status[1];
wire  [2:0] speed = status[4:2];
wire  [1:0] isawait = status[6:5];
wire        fake286 = status[7];
wire        joyswap = status[8];
wire        midi = ~status[9];
wire        adlibhide = status[10];

reg   [4:0] cpu_speed;

always @(*) begin
	case (speed)
		1: cpu_speed = 1; // /2
		2: cpu_speed = 2; // /3
		3: cpu_speed = 3; // /4
		4: cpu_speed = 7; // /8
		5: cpu_speed = 15;// /16
		6: cpu_speed = 31;// /32
		default: cpu_speed = 0;
	endcase
end

// core's raw video 
wire  [5:0] core_r, core_g, core_b;
wire        core_hs, core_vs;
wire        core_blank, core_vb;

localparam  CPU_MHZ = 50;

wire        clk_25, clk_sdr, CLK14745600;
wire        clk_mpu; //3MHz MIDI, (31250Hz * 32)*3
wire        clk_cpu, clk_dsp;
wire        clk_sys = clk_25;

assign SDRAM_CKE = 1'b1;

dcm dcm_system (
	.inclk0(CLOCK_27),
	.c0(SDRAM_CLK),
	.c1(clk_sdr),
	.c2(clk_cpu),
	.c3(clk_dsp)
);

dcm_misc dcm_misc (
	.inclk0(CLOCK_27),
	.c0(),
	.c1(CLK14745600),
	.c2(clk_mpu)
);

dcm_cpu dcm_cpu_inst (
	.inclk0(CLOCK_27),
	.c0(clk_25)
);

reg  reset;
    
always @(posedge clk_cpu) reset <= status[0] | buttons[1] | !bios_loaded;
	
// user io
wire [63:0] status;
wire  [1:0] buttons;
wire  [1:0] switches;

wire        ps2_kbd_clk, ps2_kbd_clk_i;
wire        ps2_kbd_dat, ps2_kbd_dat_i;
wire        ps2_mouse_clk, ps2_mouse_clk_i;
wire        ps2_mouse_dat, ps2_mouse_dat_i;

// conections between user_io (implementing the SPI communication 
// to the io controller) and the legacy SD Card wrapper
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

assign LED = ~led_out[0]; // CPU HALT

`ifdef USE_HDMI
wire        i2c_start;
wire        i2c_read;
wire  [6:0] i2c_addr;
wire  [7:0] i2c_subaddr;
wire  [7:0] i2c_dout;
wire  [7:0] i2c_din;
wire        i2c_ack;
wire        i2c_end;
`endif

user_io #(.STRLEN($size(CONF_STR)>>3), .PS2DIV(2000), .PS2BIDIR(1'b1), .FEATURES(32'h580 | (BIG_OSD << 13) | (HDMI << 14)) /* Secondary IDE - ATA, Primary Slave - CDROM*/) user_io(
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

`ifdef USE_HDMI
	.i2c_start       ( i2c_start     ),
	.i2c_read        ( i2c_read      ),
	.i2c_addr        ( i2c_addr      ),
	.i2c_subaddr     ( i2c_subaddr   ),
	.i2c_dout        ( i2c_dout      ),
	.i2c_din         ( i2c_din       ),
	.i2c_ack         ( i2c_ack       ),
	.i2c_end         ( i2c_end       ),
`endif
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

///// VIDEO OUT /////

mist_video #(.COLOR_DEPTH(6), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video (
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
	.no_csync    ( 1'b1       ),
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

	.HSync       ( ~core_hs   ),
	.VSync       ( ~core_vs   ),

	// MiST video output signals
	.VGA_R       ( VGA_R      ),
	.VGA_G       ( VGA_G      ),
	.VGA_B       ( VGA_B      ),
	.VGA_VS      ( VGA_VS     ),
	.VGA_HS      ( VGA_HS     )
);

`ifdef USE_HDMI
i2c_master #(50_000_000) i2c_master (
	.CLK         (clk_cpu),
	.I2C_START   (i2c_start),
	.I2C_READ    (i2c_read),
	.I2C_ADDR    (i2c_addr),
	.I2C_SUBADDR (i2c_subaddr),
	.I2C_WDATA   (i2c_dout),
	.I2C_RDATA   (i2c_din),
	.I2C_END     (i2c_end),
	.I2C_ACK     (i2c_ack),

	//I2C bus
	.I2C_SCL     (HDMI_SCL),
	.I2C_SDA     (HDMI_SDA)
);

mist_video #(.COLOR_DEPTH(6), .OUT_COLOR_DEPTH(8), .USE_BLANKS(1'b1), .BIG_OSD(BIG_OSD)) hdmi_video (
	.clk_sys     ( clk_25     ),

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
	.no_csync    ( 1'b1       ),
	// YPbPr always uses composite sync
	.ypbpr       ( 1'b0       ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( core_r     ),
	.G           ( core_g     ),
	.B           ( core_b     ),

	.HSync       ( ~core_hs   ),
	.VSync       ( ~core_vs   ),
	.HBlank      ( core_blank ),
	.VBlank      ( core_vb    ),

	// MiST video output signals
	.VGA_R       ( HDMI_R     ),
	.VGA_G       ( HDMI_G     ),
	.VGA_B       ( HDMI_B     ),
	.VGA_VS      ( HDMI_VS    ),
	.VGA_HS      ( HDMI_HS    ),
	.VGA_DE      ( HDMI_DE    )
);

assign HDMI_PCLK = clk_25;

`endif

////// BIOS DOWNLOAD /////

wire        ioctl_downl;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire        hdd_cmd_req;
wire        hdd_dat_req;
wire        hdd_cdda_req;
wire        hdd_cdda_wr;
wire        hdd_status_wr;

wire  [2:0] hdd_addr;
wire        hdd_wr;

wire [15:0] hdd_data_out;
wire [15:0] hdd_data_in;
wire        hdd_data_rd;
wire        hdd_data_wr;

wire [15:0] cdda_l;
wire [15:0] cdda_r;

data_io #(.ENABLE_IDE(1'b1)) data_io(
	.clk_sys       ( clk_sdr      ),
	.SPI_SCK       ( SPI_SCK      ),
	.SPI_SS2       ( SPI_SS2      ),
	.SPI_SS4       ( SPI_SS4      ),
	.SPI_DI        ( SPI_DI       ),
	.SPI_DO        ( SPI_DO       ),
	.ioctl_download( ioctl_downl  ),
	.ioctl_index   ( ioctl_index  ),
	.ioctl_wr      ( ioctl_wr     ),
	.ioctl_addr    ( ioctl_addr   ),
	.ioctl_dout    ( ioctl_dout   ),

	.hdd_clk       ( clk_cpu      ),
	.hdd_cmd_req   ( hdd_cmd_req  ),
	.hdd_dat_req   ( hdd_dat_req  ),
	.hdd_cdda_req  ( hdd_cdda_req ),
	.hdd_cdda_wr   ( hdd_cdda_wr  ),
	.hdd_status_wr ( hdd_status_wr),
	.hdd_addr      ( hdd_addr     ),
	.hdd_wr        ( hdd_wr       ),
	.hdd_data_out  ( hdd_data_out ),
	.hdd_data_in   ( hdd_data_in  ),
	.hdd_data_rd   ( hdd_data_rd  ),
	.hdd_data_wr   ( hdd_data_wr  )
);

reg [15:0] bios_tmp[64];
reg [13:0] bios_addr = 0;
reg [15:0] bios_din;
reg        bios_wr = 0;
wire       bios_req;
reg        bios_loaded = 0;

always @(posedge clk_sdr) begin
	reg [7:0] dat;
	reg       bios_reqD;
	reg       ioctl_downlD;

	ioctl_downlD <= ioctl_downl;
	if (ioctl_downl & ~ioctl_downlD) begin
		bios_addr <= 0;
		bios_wr <= 0;
	end

	if (ioctl_downlD & ~ioctl_downl) bios_loaded <= 1;

	if (ioctl_downl & ioctl_wr) begin
		if (ioctl_addr[0]) begin
			bios_tmp[ioctl_addr[6:1]] <= {ioctl_dout, dat};
			if (&ioctl_addr[5:1]) bios_wr <= 1;
		end else begin
			dat <= ioctl_dout;
		end
	end

	bios_reqD <= bios_req;
	if (bios_reqD & ~bios_req) bios_wr <= 0;

	if (ioctl_downl & bios_req) begin
		bios_addr <= bios_addr + 1'd1;
		bios_din <= bios_tmp[bios_addr[5:0]];
	end
end

////////////// IDE INTERFACES ///////
wire [15:0] IDE_DAT_O;
wire [15:0] IDE_DAT_I;
wire  [3:0] IDE_A;
wire        IDE_WE;
wire  [1:0] IDE_CS;
reg   [1:0] IDE_INT;

wire  [1:0] ide_irq_ack;

assign ide_irq_ack[1] = IDE_CS[1] && IDE_A == 4'd7;
assign ide_irq_ack[0] = IDE_CS[0] && IDE_A == 4'd7;

//reg [3:0] dbg_ide_addr /* synthesis noprune */;
//always @(posedge clk_cpu) if (|IDE_CS) dbg_ide_addr <= IDE_A;

ide ide (
	.clk(clk_cpu), // system clock
	.clk_en(1'b1),
	.reset(reset),

	// cpu interface
	.address_in((~IDE_WE && IDE_A == 4'hE) ? 3'd7 : IDE_A[2:0]),
	.sel_secondary(IDE_CS[1]),
	.data_in({IDE_DAT_O[7:0], IDE_DAT_O[15:8]}),
	.data_out({IDE_DAT_I[7:0], IDE_DAT_I[15:8]}),
	.rd(~IDE_WE),
	.hwr(IDE_WE),
	.lwr(IDE_WE),
	.sel_ide(|IDE_CS),
	.intreq(IDE_INT),
	.intreq_ack(ide_irq_ack),  // interrupt clear
	.nrdy(),				// fifo is not ready for reading 
	.hdd0_ena(2'b10),		// enables Master & Slave drives on primary channel
	.hdd1_ena(2'b11),		// enables Master & Slave drives on secondary channel
	.fifo_rd(),
	.fifo_wr(),

	// io controller interface
	.hdd_cmd_req   ( hdd_cmd_req  ),
	.hdd_dat_req   ( hdd_dat_req  ),
	.hdd_status_wr ( hdd_status_wr),
	.hdd_addr      ( hdd_addr     ),
	.hdd_wr        ( hdd_wr       ),
	.hdd_data_in   ( hdd_data_in  ),
	.hdd_data_out  ( hdd_data_out ),
	.hdd_data_rd   ( hdd_data_rd  ),
	.hdd_data_wr   ( hdd_data_wr  )
);

cdda_fifo cdda_fifo (
	.clk_sys       ( clk_cpu      ),
	.clk_en        ( 1'b1         ),
	.cen_44100     ( cen_44100    ),
	.reset         ( reset        ),

	.hdd_cdda_req  ( hdd_cdda_req ),
	.hdd_cdda_wr   ( hdd_cdda_wr  ),
	.hdd_data_out  ( hdd_data_out ),

	.cdda_l        ( cdda_l       ),
	.cdda_r        ( cdda_r       )
);

////////////// JOYSTICKS /////////////

reg   [7:0] joy = 8'hFF;
wire        joy_wr;
reg   [7:0] joy_cnt = 8'hFF;
reg   [8:0] joy_cnt_ce_cnt;
reg         joy_cnt_ce;
wire [15:0] joy0 = joyswap ? joystick_analog_1: joystick_analog_0;
wire [15:0] joy1 = joyswap ? joystick_analog_0: joystick_analog_1;

always @(posedge clk_cpu) begin
	joy[7:4] <= joyswap ? ~{joystick_1[5:4], joystick_0[5:4]} : ~{joystick_0[5:4], joystick_1[5:4]};
	joy_cnt_ce_cnt <= joy_cnt_ce_cnt + 1'd1;
	if (joy_cnt_ce_cnt == {cpu_speed, {4{1'b1}}}) joy_cnt_ce_cnt <= 0;
	joy_cnt_ce <= joy_cnt_ce_cnt == 0;
	if (joy_wr) begin
		joy[3:0] <= 4'b1111;
		joy_cnt <= 0;
		joy_cnt_ce_cnt <= 1;
		joy_cnt_ce <= 0;
	end else if (joy_cnt != 8'hFF) begin
		if (joy_cnt == {~joy1[15], joy1[14:8]}) joy[0] <= 0;
		if (joy_cnt == {~joy1[ 7], joy1[ 6:0]}) joy[1] <= 0;
		if (joy_cnt == {~joy0[15], joy0[14:8]}) joy[2] <= 0;
		if (joy_cnt == {~joy0[ 7], joy0[ 6:0]}) joy[3] <= 0;
		if (joy_cnt_ce) joy_cnt <= joy_cnt + 1'd1;
	end else joy[3:0] <= 0;
end

////// NEXT186 ///////////////

wire [3:0] IO;
wire [7:0] led_out;
reg        NMI;

always @(posedge clk_25) begin
	integer nmi_cnt = 0;
	reg btn_nmi_d;
	btn_nmi_d <= btn_nmi;
	if (nmi_cnt == 0) begin
		if (~btn_nmi_d & btn_nmi) nmi_cnt <= 24'hFFFFFF;
		NMI <= 0;
	end else begin
		NMI <= 1;
		nmi_cnt <= nmi_cnt - 1'd1;
	end

end

wire com1_Rx, com1_Tx;
wire mpu_Rx, mpu_Tx;

assign UART_TX = midi ? mpu_Tx : com1_Tx;
assign com1_Rx = midi ? 1'b1 : UART_RX;
assign mpu_Rx = midi ? UART_RX : 1'b1;

reg         cen_opl2; // 3.58MHz
reg  [15:0] cen_opl2_cnt;
wire [15:0] cen_opl2_cnt_next = cen_opl2_cnt + 16'd358;
always @(posedge clk_cpu) begin
	cen_opl2 <= 0;
	cen_opl2_cnt <= cen_opl2_cnt_next;
	if (cen_opl2_cnt_next >= (CPU_MHZ * 100)) begin
		cen_opl2 <= 1;
		cen_opl2_cnt <= cen_opl2_cnt_next - (CPU_MHZ * 100);
	end
end

reg         cen_44100;
reg  [31:0] cen_44100_cnt;
wire [31:0] cen_44100_cnt_next = cen_44100_cnt + 16'd44100;
always @(posedge clk_cpu) begin
	cen_44100 <= 0;
	cen_44100_cnt <= cen_44100_cnt_next;
	if (cen_44100_cnt_next >= (CPU_MHZ*1000000)) begin
		cen_44100 <= 1;
		cen_44100_cnt <= cen_44100_cnt_next - (CPU_MHZ*1000000);
	end
end

reg fake286_r, fake286_r2;
always @(posedge clk_cpu) { fake286_r, fake286_r2 } <= { fake286, fake286_r };
wire [15:0] laudio, raudio;

system sys_inst (
	.clk_25(clk_25),
	.clk_sdr(clk_sdr),
	.CLK14745600(CLK14745600),
	.clk_mpu(clk_mpu),

	.clk_cpu(clk_cpu),
	.clk_en_opl2(cen_opl2),
	.clk_en_44100(cen_44100),
	.clk_dsp(clk_dsp),

	.fake286(fake286_r2),
	.adlibhide(adlibhide),
	.cpu_speed(cpu_speed),
	.waitstates(isawait == 0 ? 8'd50 :
	            isawait == 1 ? 8'd100 :
	            isawait == 2 ? 8'd166 : 8'd200),

	.VGA_R(core_r),
	.VGA_G(core_g),
	.VGA_B(core_b),
	.VGA_HSYNC(core_hs),
	.VGA_VSYNC(core_vs),
	.VGA_BLANK(core_blank),
	.VGA_VBLANK(core_vb),
	.frame_on(),

	.sdr_n_CS_WE_RAS_CAS({SDRAM_nCS, SDRAM_nWE, SDRAM_nRAS, SDRAM_nCAS}),
	.sdr_BA(SDRAM_BA),
	.sdr_ADDR(SDRAM_A),
	.sdr_DATA(SDRAM_DQ),
	.sdr_DQM({SDRAM_DQMH, SDRAM_DQML}),

	.LED(led_out),

	.BTN_RESET(reset),
	.BTN_NMI(NMI),

	.RS232_DCE_RXD(),
	.RS232_DCE_TXD(),
	.RS232_EXT_RXD(com1_Rx),
	.RS232_EXT_TXD(com1_Tx),
	.MPU_RX(mpu_Rx),
	.MPU_TX(mpu_Tx),

	.SD_n_CS(sd_cs),
	.SD_DI(sd_sdi),
	.SD_CK(sd_sck),
	.SD_DO(sd_sdo),

	.CDDA_L(cdda_l),
	.CDDA_R(cdda_r),

	.AUD_L(AUDIO_L),
	.AUD_R(AUDIO_R),
	.LAUDIO(laudio),
	.RAUDIO(raudio),

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

	.GPIO_WR(joy_wr),
	.GPIO_IN(joy),

	.IDE_DAT_O(IDE_DAT_O),
	.IDE_DAT_I(IDE_DAT_I),
	.IDE_A(IDE_A),
	.IDE_WE(IDE_WE),
	.IDE_CS(IDE_CS),
	.IDE_INT(IDE_INT),

	.I2C_SCL(),//I2C_SCLK),
	.I2C_SDA(), //I2C_SDAT)

	.BIOS_ADDR(bios_addr),
	.BIOS_DIN(bios_din),
	.BIOS_WR(bios_wr),
	.BIOS_REQ(bios_req)
);

`ifdef I2S_AUDIO
i2s i2s (
	.reset(1'b0),
	.clk(clk_cpu),
	.clk_rate(32'd50_000_000),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan(laudio),
	.right_chan(raudio)
);
`endif

`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_cpu) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif

`ifdef SPDIF_AUDIO
spdif spdif
(
	.clk_i(clk_cpu),
	.rst_i(1'b0),
	.clk_rate_i(32'd50_000_000),
	.spdif_o(SPDIF),
	.sample_i({raudio, laudio})
);
`endif

endmodule
