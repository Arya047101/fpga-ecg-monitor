`timescale 1ns / 1ps

module tb_rr_calculator;

parameter CLK_PERIOD = 2_777_778;
parameter N_SAMPLES  = 3600;
parameter HEX_PEAKS  = "out_peaks.hex";
parameter HEX_HR     = "out_heartrate.hex";
parameter HEX_RR     = "out_rr.hex";

reg        clk, rst_n, valid_in, peak_flag;
wire [11:0] rr_interval;
wire [9:0]  heart_rate;
wire        arrhythmia_flag, rr_valid;

rr_calculator #(.FS(360), .RR_MAX(1440), .RR_MIN(72)) dut (
    .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
    .peak_flag(peak_flag),
    .rr_interval(rr_interval), .heart_rate(heart_rate),
    .arrhythmia_flag(arrhythmia_flag), .rr_valid(rr_valid)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

reg [15:0] mem_peaks [0:N_SAMPLES-1];
integer fhr, frr, i, beat_count;
real hr_avg_sum;

initial begin
    $dumpfile("rr_wave.vcd");
    $dumpvars(0, tb_rr_calculator);

    $readmemh(HEX_PEAKS, mem_peaks);
    $display("Loaded peak data from %s", HEX_PEAKS);

    fhr = $fopen(HEX_HR, "w");
    frr = $fopen(HEX_RR, "w");
    if (fhr == 0 || frr == 0) begin $display("ERROR opening output files"); $finish; end

    beat_count = 0;
    hr_avg_sum = 0;

    rst_n = 0; valid_in = 0; peak_flag = 0;
    repeat(4) @(posedge clk);
    rst_n = 1; @(posedge clk);

    for (i = 0; i < N_SAMPLES; i = i + 1) begin
        // A non-zero entry in peaks file = peak
        peak_flag = (mem_peaks[i] != 16'd0) ? 1'b1 : 1'b0;
        valid_in  = 1'b1;
        @(posedge clk);
    end
    @(posedge clk); valid_in = 0;
    repeat(10) @(posedge clk);

    $fclose(fhr);
    $fclose(frr);
    if (beat_count > 0)
        $display("Mean HR over %0d beats = %.1f BPM", beat_count, hr_avg_sum/beat_count);
    $finish;
end

always @(posedge clk) begin
    if (rr_valid) begin
        beat_count   = beat_count + 1;
        hr_avg_sum   = hr_avg_sum + heart_rate;
        $fwrite(fhr, "%04X\n", {6'b0, heart_rate});
        $fwrite(frr, "%04X\n", rr_interval);
        $display("Beat %0d: RR=%0d samples  HR=%0d BPM  Arrhy=%b",
                 beat_count, rr_interval, heart_rate, arrhythmia_flag);
    end
end

endmodule
