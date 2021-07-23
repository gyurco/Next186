//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the Next186 Soc PC project
// http://opencores.org/project,next186
//
// Filename: PIC_8259.v
// Description: Part of the Next186 SoC PC project, PIC controller
// 	8259 simplified interrupt controller (only interrupt mask can be read, not IRR or ISR, no EOI required)
// Version 1.0
// Creation date: May2012
//
// Author: Nicolae Dumitrache 
// e-mail: ndumitrache@opencores.org
//
// ISR added, switched to non-automatic end: July2021 Gyorgy Szombathelyi
//
/////////////////////////////////////////////////////////////////////////////////
// 
// Copyright (C) 2012 Nicolae Dumitrache
// 
// This source file may be used and distributed without 
// restriction provided that this copyright statement is not 
// removed from the file and that any derivative work contains 
// the original copyright notice and the associated disclaimer.
// 
// This source file is free software; you can redistribute it 
// and/or modify it under the terms of the GNU Lesser General 
// Public License as published by the Free Software Foundation;
// either version 2.1 of the License, or (at your option) any 
// later version. 
// 
// This source is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied 
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
// PURPOSE. See the GNU Lesser General Public License for more 
// details. 
// 
// You should have received a copy of the GNU Lesser General 
// Public License along with this source; if not, download it 
// from http://www.opencores.org/lgpl.shtml 
// 
///////////////////////////////////////////////////////////////////////////////////
// Additional Comments: 
// http://wiki.osdev.org/8259_PIC
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module PIC_8259(
	input RST,
	input CS,
	input A,
	input WR,
	input [7:0]din,
	input slave,
	output wire [7:0]dout,
	output reg [7:0]ivect,
	input clk,		// cpu CLK
	output reg INT = 0,
	input IACK,
	input [4:0]I	// 0:timer, 1:keyboard, 2:RTC, 3:mouse, 4:COM1
);

reg [4:0]ss_I = 0;
reg [4:0]s_I = 0;
reg [4:0]IMR = 5'b11111;
reg [4:0]IRR = 0;
reg [4:0]ISR = 0;
reg      RIS; // Read ISR

assign dout = A ? (slave ? {3'b000, IMR[3], 3'b000, IMR[2]} : {3'b000, IMR[4], 2'b00, IMR[1:0]}) :
            RIS ? (slave ? {3'b000, ISR[3], 3'b000, ISR[2]} : {3'b000, ISR[4], 2'b00, ISR[1:0]}) :
			      (slave ? {3'b000, IRR[3], 3'b000, IRR[2]} : {3'b000, IRR[4], 2'b00, IRR[1:0]});

always @ (posedge clk) begin
	if (RST) begin
		ss_I <= 0;
		s_I <= 0;
		IMR <= 5'b11111;
		IRR <= 0;
		ISR <= 0;
		INT <= 0;
		RIS <= 0;
	end else begin
		ss_I <= I;
		s_I <= ss_I;
		IRR <= (IRR | (~s_I & ss_I)) & ~IMR;	// front edge detection
		if(~INT) begin
			if(IRR[0] && !ISR[0]) begin //timer
				INT <= 1'b1; 
				ivect <= 8'h08;
				IRR[0] <= 1'b0;
				ISR[0] <= 1'b1;
			end	else if(IRR[1] && ISR[1:0] == 0) begin  // keyboard
				INT <= 1'b1; 
				ivect <= 8'h09; 
				IRR[1] <= 1'b0;
				ISR[1] <= 1'b1;
			end else if(IRR[2] && ISR[2:0] == 0) begin  // RTC
				INT <= 1'b1; 
				ivect <= 8'h70; 
				IRR[2] <= 1'b0;
				ISR[2] <= 1'b1;
			end else if(IRR[3] && ISR[3:0] == 0) begin // mouse
				INT <= 1'b1; 
				ivect <= 8'h74; 
				IRR[3] <= 1'b0;
				ISR[3] <= 1'b1;
			end else if(IRR[4] && ISR[4:0] == 0) begin // COM1
				INT <= 1'b1;
				ivect <= 8'h0c;
				IRR[4] <= 1'b0;
				ISR[4] <= 1'b1;
			end
		end else if(IACK) begin
			INT <= 1'b0;
			if (IRR[0]) begin
				IRR[0] <= 0;
				ISR[0] <= 1;
			end else if (IRR[1]) begin
				IRR[1] <= 0;
				ISR[1] <= 1;
			end else if (IRR[2]) begin
				IRR[2] <= 0;
				ISR[2] <= 1;
			end else if (IRR[3]) begin
				IRR[3] <= 0;
				ISR[3] <= 1;
			end else if (IRR[4]) begin
				IRR[4] <= 0;
				ISR[4] <= 1;
			end
		end

		if(CS & WR)
			if (!A) begin
				if (!din[3]) begin
					// OCW2
					if (din[5]) begin
						// End-of-interrupt
						if      (!slave && ISR[0]) ISR[0] <= 0;
						else if (!slave && ISR[1]) ISR[1] <= 0;
						else if ( slave && ISR[2]) ISR[2] <= 0;
						else if ( slave && ISR[3]) ISR[3] <= 0;
						else if (!slave && ISR[4]) ISR[4] <= 0;
					end
				end else begin
					// OCW3
					if (din[1]) RIS <= din[0];
				end
			end else begin
				// OCW1
				if(slave) IMR[3:2] <= {din[4], din[0]};
				else {IMR[4], IMR[1:0]} <= {din[4], din[1:0]};
			end
	end
end

endmodule


