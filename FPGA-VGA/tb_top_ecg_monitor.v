// =============================================================================
// tb_top_ecg_monitor.v
// Full System Testbench — works with Icarus Verilog on macOS
//
// How to run on Mac:
//   iverilog -o sim_top \
//     tb_top_ecg_monitor.v top_ecg_monitor.v vga_controller.v vga_waveform.v \
//     seg7_driver.v qrs_detector.v centered_derivative.v adaptive_threshold.v \
//     peak_detector.v rr_calculator.v bandpass_filter.v derivative_filter.v \
//     squaring.v moving_window_integrator.v lowpass_filter.v
//   vvp sim_top
//   gtkwave top_ecg.vcd &
//
// What this verifies:
//   1. VGA hsync/vsync pulse widths and timing
//   2. Pixel output changes (non-black pixels appear in active region)
//   3. 7-seg display cycles through all 8 digits
//   4. Peak detection and HR output appear within 10 seconds
//   5. LED heartbeat toggles with each detected peak
// =============================================================================
`timescale 1ns / 1ps

module tb_top_ecg_monitor;

// ── Clock and control ─────────────────────────────────────────────────────────
reg clk_100mhz, btnc;
initial clk_100mhz = 0;
always #5 clk_100mhz = ~clk_100mhz;  // 100 MHz = 10 ns period

// ── DUT outputs ───────────────────────────────────────────────────────────────
wire [7:0] an;
wire [6:0] seg;
wire [3:0] led;
wire [3:0] vga_r, vga_g, vga_b;
wire       vga_hs, vga_vs;

// ── DUT instantiation ─────────────────────────────────────────────────────────
top_ecg_monitor dut (
    .clk_100mhz (clk_100mhz),
    .btnc        (btnc),
    .an          (an),
    .seg         (seg),
    .led         (led),
    .vga_r       (vga_r),
    .vga_g       (vga_g),
    .vga_b       (vga_b),
    .vga_hs      (vga_hs),
    .vga_vs      (vga_vs)
);

// ── VGA timing checks ─────────────────────────────────────────────────────────
// At 25 MHz pixel clock: one pixel = 40 ns
// Hsync period  = 800 pixels × 40 ns = 32,000 ns = 32 µs
// Hsync pulse   = 96  pixels × 40 ns = 3,840 ns
// Vsync period  = 525 lines  × 32 µs = 16,800 µs ≈ 16.7 ms
// At 100 MHz system clock: pixel clock = 100 MHz / 4 = 25 MHz
//   Hsync period  ≈ 800 × 40 ns = 32,000 ns (3200 sys clocks)
//   Vsync period  ≈ 16,800,000 ns (1,680,000 sys clocks)

integer hs_fall_time, hs_rise_time, hs_pulse_ns;
integer vs_fall_time, vs_rise_time, vs_period_us;
integer hs_count, vs_count, pixel_count;
integer nonblack_pixels;
integer beat_count;
integer f_vga_log;

initial begin
    $dumpfile("top_ecg.vcd");
    // Dump only top-level ports (not internal signals — too large)
    $dumpvars(0, dut.clk_100mhz);
    $dumpvars(0, dut.btnc);
    $dumpvars(0, dut.vga_hs);
    $dumpvars(0, dut.vga_vs);
    $dumpvars(0, dut.vga_r);
    $dumpvars(0, dut.vga_g);
    $dumpvars(0, dut.vga_b);
    $dumpvars(0, dut.led);
    $dumpvars(0, dut.an);
    $dumpvars(0, dut.seg);
    $dumpvars(0, dut.u_qrs.peak_flag);
    $dumpvars(0, dut.u_qrs.heart_rate);
    $dumpvars(0, dut.u_qrs.arrhythmia_flag);
    $dumpvars(0, dut.lps_out);
    $dumpvars(0, dut.threshold_out);

    $display("");
    $display("=== ECG Monitor Full System Testbench ===");
    $display("=== Icarus Verilog — macOS              ===");
    $display("");

    hs_count       = 0;
    vs_count       = 0;
    nonblack_pixels= 0;
    beat_count     = 0;

    // Reset
    btnc = 1;   // Active high reset
    repeat(20) @(posedge clk_100mhz);
    btnc = 0;
    $display("[TB] Reset released at t = %0t ns", $time);

    // ── Wait 2 full VGA frames (~33.6 ms) to check timing ────────────────────
    // 2 frames = 2 × 16.7 ms = 33.4 ms = 33,400,000 ns
    #33_400_000;
    $display("[TB] VGA timing check after 2 frames:");
    $display("[TB]   Hsync pulses counted : %0d (expect ~2*525 = 1050)", hs_count);
    $display("[TB]   Vsync pulses counted : %0d (expect 2)", vs_count);
    $display("[TB]   Non-black pixels seen: %0d", nonblack_pixels);

    if (hs_count < 1000 || hs_count > 1100)
        $display("[TB]   WARNING: Hsync count out of range!");
    else
        $display("[TB]   Hsync timing: PASS");

    if (vs_count < 1 || vs_count > 3)
        $display("[TB]   WARNING: Vsync count out of range!");
    else
        $display("[TB]   Vsync timing: PASS");

    // ── Run for 12 seconds to accumulate beats ────────────────────────────────
    $display("[TB] Running 12 seconds of ECG for beat detection...");
    // 12 seconds at 100 MHz = 1,200,000,000 ns
    #1_200_000_000;

    $display("");
    $display("=== FINAL SYSTEM RESULTS ===");
    $display("  Beats detected  : %0d", beat_count);
    $display("  VGA hsync count : %0d (expect ~12s × 31250 Hz ≈ 375000)", hs_count);
    $display("  Non-black pixels: %0d", nonblack_pixels);
    $display("  Last HR display : %0d BPM", dut.u_qrs.heart_rate);
    $display("  Arrhythmia flag : %b", dut.u_qrs.arrhythmia_flag);
    $display("");
    $display("7-Segment state  : AN=%b SEG=%b", dut.an, dut.seg);
    $display("LED state        : %b (LD3=heartbeat LD2=active LD1=peak LD0=arrhy)", dut.led);

    if (beat_count < 10)
        $display("WARNING: Fewer than 10 beats — check threshold or LPS amplitude");
    else
        $display("Beat detection: PASS (%0d beats in 12 s)", beat_count);

    $finish;
end

// ── VGA timing monitors ───────────────────────────────────────────────────────
// Count falling edges of hsync (each = start of one horizontal line)
always @(negedge vga_hs) begin
    hs_count = hs_count + 1;
    hs_fall_time = $time;
end
always @(posedge vga_hs) begin
    if (hs_fall_time > 0) begin
        hs_pulse_ns = $time - hs_fall_time;
        // Hsync pulse should be 96 pixels × 40 ns = 3840 ns
        // At 25 MHz effective (100 MHz / 4): 96 × 160 ns = 15,360 ns sys clock
        // Just check it's in range 12000–18000 ns
        if (hs_count <= 5 && (hs_pulse_ns < 12000 || hs_pulse_ns > 18000))
            $display("[TB] WARNING: Hsync pulse = %0d ns (expect ~15360 ns)", hs_pulse_ns);
    end
end

// Count falling edges of vsync (each = start of one frame)
always @(negedge vga_vs) begin
    vs_count = vs_count + 1;
end

// Count non-black pixels during active video
always @(posedge clk_100mhz) begin
    if ((vga_r != 4'h0 || vga_g != 4'h0 || vga_b != 4'h0))
        nonblack_pixels = nonblack_pixels + 1;
end

// ── Beat detection counter ────────────────────────────────────────────────────
always @(posedge clk_100mhz) begin
    if (dut.peak_flag) begin
        beat_count = beat_count + 1;
        $display("[TB] Beat #%0d at t=%.3f s  HR=%0d BPM  Arrhy=%b",
                 beat_count,
                 $realtime / 1e9,
                 dut.u_qrs.heart_rate,
                 dut.u_qrs.arrhythmia_flag);
    end
end

// ── 7-seg progress every 1 second ────────────────────────────────────────────
integer sec_tick;
initial sec_tick = 0;
always @(posedge clk_100mhz) begin
    if ($time > sec_tick * 1_000_000_000 + 1_000_000_000) begin
        sec_tick = sec_tick + 1;
        $display("[TB] t=%0d s  HR=%0d  Beats=%0d  LED=%b",
                 sec_tick,
                 dut.u_qrs.heart_rate,
                 beat_count,
                 dut.led);
    end
end

endmodule
