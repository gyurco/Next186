
module mpu
(
	input            clk,
	input            reset,

	input            address,
	input            write,
	input      [7:0] writedata,
	input            read,
	output reg [7:0] readdata,
	input            cs,

	input            double_rate,
	input            br_clk,

	input            rx,
	output           tx,
	output           br_out,

	output           irq
);

assign irq  = read_ack | ~rx_empty;

wire rx_empty, tx_full;
wire [7:0] data;

gh_uart_16550 #(1'b1) uart_16550
(
	.clk(clk),
	.BR_clk(br_clk),
	.rst(reset),
	.CS(cs & ~address & ((read & ~read_ack) | write)),
	.WR(write),
	.ADD(0),
	.D(writedata),
	.RD(data),

	.B_CLK(br_out),

	.sRX(rx),
	.sTX(tx),
	.RIn(1),
	.CTSn(0),
	.DSRn(0),
	.DCDn(0),

	.DIV2(double_rate),
	.TX_Full(tx_full),
	.RX_Empty(rx_empty)
);

reg read_ack;
reg mpu_dumb;
always @(posedge clk) begin
	if(reset) begin
		read_ack <= 0;
		mpu_dumb <= 0;
	end
	else if(cs) begin
		if(address) begin
			if(read) readdata <= {~(read_ack | ~rx_empty), tx_full, 6'd0};
			if(write) begin
				read_ack <= ~mpu_dumb;
				if(writedata == 8'hFF) mpu_dumb <= 0;
				if(writedata == 8'h3F) mpu_dumb <= 1;
			end
		end
		else if(read) begin
			readdata <= read_ack ? 8'hFE : data;
			read_ack <= 0;
		end
	end
end

endmodule
