// =============================================================================
// seg7_driver.v
// 8-digit 7-segment multiplexed display driver for Nexys 4 DDR
//
// Shows heart rate in BPM on digits AN2..AN0 (hundreds, tens, units)
// AN3 shows a dash separator
// AN7..AN4 are blanked
//
// Nexys 4 DDR: common anode — segments are ACTIVE LOW
// Multiplex rate: ~1 kHz per digit (100 MHz / 100000 = 1 kHz)
// =============================================================================
`timescale 1ns / 1ps

module seg7_driver (
    input  wire        clk,       // 100 MHz system clock
    input  wire        rst_n,
    input  wire [9:0]  heart_rate,   // 0..999 BPM
    input  wire        arrhythmia,   // Blinks DP on AN0 when high
    output reg  [7:0]  an,           // Anode select (active low)
    output reg  [6:0]  seg           // Segment cathodes a..g (active low)
);

// ── Clock divider for ~1 kHz multiplex ───────────────────────────────────────
reg [16:0] div_cnt;
reg  [2:0] digit_sel;   // Which of 8 digits is active (0..7)
reg        blink_tick;  // 1 Hz blink for arrhythmia DP

reg [9:0] blink_cnt;

always @(posedge clk) begin
    if (!rst_n) begin
        div_cnt   <= 0;
        digit_sel <= 0;
        blink_cnt <= 0;
        blink_tick<= 0;
    end else begin
        if (div_cnt == 17'd99999) begin   // 100 MHz / 100000 = 1 kHz
            div_cnt   <= 0;
            digit_sel <= digit_sel + 1;
        end else begin
            div_cnt <= div_cnt + 1;
        end

        if (div_cnt == 17'd99999 && digit_sel == 3'd7) begin
            blink_cnt <= blink_cnt + 1;
            if (blink_cnt == 10'd999)    // ~1 Hz blink
                blink_tick <= ~blink_tick;
        end
    end
end

// ── BCD extraction ────────────────────────────────────────────────────────────
wire [3:0] d0 = heart_rate % 10;          // Units
wire [3:0] d1 = (heart_rate / 10) % 10;  // Tens
wire [3:0] d2 = heart_rate / 100;        // Hundreds

// ── BCD → 7-segment (common anode: active low) ───────────────────────────────
// Segment order: gfedcba
function [6:0] bcd_to_seg7;
    input [3:0] d;
    case (d)
        4'd0: bcd_to_seg7 = 7'b1000000;  // 0
        4'd1: bcd_to_seg7 = 7'b1111001;  // 1
        4'd2: bcd_to_seg7 = 7'b0100100;  // 2
        4'd3: bcd_to_seg7 = 7'b0110000;  // 3
        4'd4: bcd_to_seg7 = 7'b0011001;  // 4
        4'd5: bcd_to_seg7 = 7'b0010010;  // 5
        4'd6: bcd_to_seg7 = 7'b0000010;  // 6
        4'd7: bcd_to_seg7 = 7'b1111000;  // 7
        4'd8: bcd_to_seg7 = 7'b0000000;  // 8
        4'd9: bcd_to_seg7 = 7'b0010000;  // 9
        default: bcd_to_seg7 = 7'b1111111; // Blank
    endcase
endfunction

localparam SEG_DASH  = 7'b0111111;  // '-' (only segment g)
localparam SEG_BLANK = 7'b1111111;  // All off

// ── Multiplexer ───────────────────────────────────────────────────────────────
always @(posedge clk) begin
    case (digit_sel)
        3'd0: begin  // Units of BPM
            an  <= 8'b11111110;
            seg <= bcd_to_seg7(d0);
        end
        3'd1: begin  // Tens of BPM
            an  <= 8'b11111101;
            seg <= bcd_to_seg7(d1);
        end
        3'd2: begin  // Hundreds of BPM
            an  <= 8'b11111011;
            seg <= (d2 == 4'd0) ? SEG_BLANK : bcd_to_seg7(d2);  // Suppress leading zero
        end
        3'd3: begin  // Dash separator
            an  <= 8'b11110111;
            seg <= SEG_DASH;
        end
        default: begin  // Blank AN4..AN7
            an  <= 8'b11101111 >> (digit_sel - 4);
            seg <= SEG_BLANK;
        end
    endcase
end

endmodule
