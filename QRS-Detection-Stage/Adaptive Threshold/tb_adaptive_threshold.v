`timescale 1ns / 1ps

// NOTE: This testbench drives the adaptive_threshold in isolation.
// In the full system, is_qrs comes from peak_detector. Here we simulate
// by flagging a sample as QRS whenever envelope > 60% of max (naive estimate).

module tb_adaptive_threshold;

parameter CLK_PERIOD = 2_777_778;
parameter N_SAMPLES  = 3600;
parameter HEX_IN     = "out_lps.hex";
parameter HEX_OUT    = "out_threshold.hex";

reg        clk, rst_n, valid_in, is_qrs;
reg [15:0] x_in;
wire [15:0] threshold_out;
wire        valid_out;

adaptive_threshold dut (
    .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
    .x_in(x_in), .is_qrs(is_qrs),
    .threshold_out(threshold_out), .valid_out(valid_out)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

reg [15:0] mem_in [0:N_SAMPLES-1];
integer fout, sample_count, i;
reg [15:0] running_max;

initial begin
    $dumpfile("threshold_wave.vcd");
    $dumpvars(0, tb_adaptive_threshold);
    $readmemh(HEX_IN, mem_in);

    // Find max for naive QRS estimation
    running_max = 16'd0;
    for (i = 0; i < N_SAMPLES; i = i + 1)
        if (mem_in[i] > running_max) running_max = mem_in[i];
    $display("LPS max = %0d (0x%04X)", running_max, running_max);

    fout = $fopen(HEX_OUT, "w");
    if (fout == 0) begin $display("ERROR: cannot open %s", HEX_OUT); $finish; end
    sample_count = 0;

    rst_n = 0; valid_in = 0; x_in = 0; is_qrs = 0;
    repeat(4) @(posedge clk);
    rst_n = 1; @(posedge clk);

    for (i = 0; i < N_SAMPLES; i = i + 1) begin
        x_in  = mem_in[i];
        // Naive is_qrs: flag if > 40% of max
        is_qrs   = (mem_in[i] > (running_max >> 1)) ? 1'b1 : 1'b0;
        valid_in = 1'b1;
        @(posedge clk);
    end
    @(posedge clk); valid_in = 0;
    repeat(10) @(posedge clk);

    $fclose(fout);
    $display("Written %0d threshold samples to %s", sample_count, HEX_OUT);
    $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        $fwrite(fout, "%04X\n", threshold_out);
        sample_count = sample_count + 1;
    end
end

endmodule
