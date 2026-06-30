// =============================================================================
// vga_controller.v
// Standard VGA 640x480 @ 60 Hz timing controller
//
// Requires a 25.175 MHz pixel clock.
// On Nexys 4 DDR (100 MHz system clock), generate pixel clock with:
//   a simple clock divider (÷4 = 25 MHz, close enough) OR
//   a Vivado MMCM/PLL primitive for exact 25.175 MHz.
//
// Timing (from VGA standard):
//   Horizontal: 640 active + 16 fp + 96 sync + 48 bp = 800 total pixels
//   Vertical  : 480 active + 10 fp + 2 sync + 33 bp  = 525 total lines
//   hsync and vsync are active LOW
//
// Outputs:
//   h_pos  — current pixel column (0..639 when active)
//   v_pos  — current pixel row    (0..479 when active)
//   active — 1 when inside the visible display area
//   hsync  — horizontal sync pulse (active low)
//   vsync  — vertical   sync pulse (active low)
// =============================================================================
`timescale 1ns / 1ps

module vga_controller (
    input  wire        pclk,     // 25 MHz pixel clock
    input  wire        rst_n,
    output reg  [9:0]  h_pos,   // 0..799
    output reg  [9:0]  v_pos,   // 0..524
    output wire        active,  // 1 inside visible area
    output wire        hsync,
    output wire        vsync
);

// Horizontal timing constants
localparam H_ACTIVE = 640;
localparam H_FP     = 16;
localparam H_SYNC   = 96;
localparam H_BP     = 48;
localparam H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;  // 800

// Vertical timing constants
localparam V_ACTIVE = 480;
localparam V_FP     = 10;
localparam V_SYNC   = 2;
localparam V_BP     = 33;
localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;  // 525

// Sync pulse regions (active low)
// Hsync pulse: pixels 656..751  (640+16 to 640+16+96-1)
// Vsync pulse: lines  490..491  (480+10 to 480+10+2-1)
assign hsync  = ~((h_pos >= H_ACTIVE + H_FP) && (h_pos < H_ACTIVE + H_FP + H_SYNC));
assign vsync  = ~((v_pos >= V_ACTIVE + V_FP) && (v_pos < V_ACTIVE + V_FP + V_SYNC));
assign active = (h_pos < H_ACTIVE) && (v_pos < V_ACTIVE);

// Pixel counter
always @(posedge pclk) begin
    if (!rst_n) begin
        h_pos <= 10'd0;
        v_pos <= 10'd0;
    end else begin
        if (h_pos == H_TOTAL - 1) begin
            h_pos <= 10'd0;
            if (v_pos == V_TOTAL - 1)
                v_pos <= 10'd0;
            else
                v_pos <= v_pos + 1;
        end else begin
            h_pos <= h_pos + 1;
        end
    end
end

endmodule
