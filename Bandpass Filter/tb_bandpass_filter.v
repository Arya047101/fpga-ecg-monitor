`timescale 1ns / 1ps   // Time unit = 1ns, precision = 1ps

module tb_bandpass_filter;

parameter CLK_PERIOD = 2_777_778;  // ns (≈ 2.778 ms)
parameter N_SAMPLES   = 3600;    // 10 seconds of ECG at 360 Hz
parameter HEX_IN      = "ecg_record100.hex";    // Input hex file
parameter HEX_OUT     = "out_bpf.hex";          // Output hex file
parameter VCD_FILE    = "bpf_wave.vcd";         // VCD dump file

reg        clk;         // Master clock
reg        rst_n;       // Active-low reset
reg        valid_in;    // Input valid strobe
reg  signed [15:0] x_in;    // 16-bit ECG input sample
wire signed [15:0] y_out;   // 16-bit BPF output sample
wire       valid_out;   // Output valid strobe

bandpass_filter dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .valid_in  (valid_in),
    .x_in      (x_in),
    .y_out     (y_out),
    .valid_out (valid_out)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;   // Toggle every half-period

reg [15:0] mem_in [0:N_SAMPLES-1];   // Hex input storage

integer fout;       // File descriptor for output hex file
integer sample_count; // Counter of output samples written

initial begin
    $dumpfile(VCD_FILE);             // Set VCD output filename
    $dumpvars(0, tb_bandpass_filter.clk);        // Clock only
    $dumpvars(0, tb_bandpass_filter.rst_n);
    $dumpvars(0, tb_bandpass_filter.valid_in);
    $dumpvars(0, tb_bandpass_filter.x_in);
    $dumpvars(0, tb_bandpass_filter.y_out);
    $dumpvars(0, tb_bandpass_filter.valid_out);
    // DO NOT dump dut internal signals (delay lines = 44 regs * 16b = huge)
end

initial begin
    // ----- Load input hex file -----
    $readmemh(HEX_IN, mem_in);     // Read all hex samples into array
    $display("Loaded input: %s", HEX_IN);

    // ----- Open output file -----
    fout = $fopen(HEX_OUT, "w");   // Open output file for writing
    if (fout == 0) begin
        $display("ERROR: Cannot open %s for writing", HEX_OUT);
        $finish;
    end

    sample_count = 0;

    // ----- Reset sequence -----
    rst_n    = 0;         // Assert reset (active low)
    valid_in = 0;         // No valid input during reset
    x_in     = 16'sd0;
    repeat (4) @(posedge clk);  // Hold reset for 4 clock cycles
    rst_n    = 1;         // Release reset
    @(posedge clk);       // One idle cycle after reset

    // ----- Feed samples one per clock cycle -----
    begin : feed_loop
        integer i;
        for (i = 0; i < N_SAMPLES; i = i + 1) begin
            x_in     = $signed(mem_in[i]);
            valid_in = 1'b1;
            @(posedge clk);                // Mark sample as valid
        end
    end

    // Deassert valid after last sample
    @(posedge clk);
    valid_in <= 1'b0;

    // Wait for pipeline to flush (BPF has ~48 sample latency)
    repeat (60) @(posedge clk);

    // ----- Close output file -----
    $fclose(fout);
    $display("Written %0d samples to %s", sample_count, HEX_OUT);
    $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        // Write 4-char hex (two's complement for negative values)
        $fwrite(fout, "%04X\n", y_out & 16'hFFFF);
        sample_count = sample_count + 1;
    end
end

always @(posedge clk) begin
    if (valid_out && (sample_count % 360 == 0) && sample_count > 0)
        $display("BPF: %0d samples processed (%0d seconds)",
                 sample_count, sample_count/360);
end

endmodule
