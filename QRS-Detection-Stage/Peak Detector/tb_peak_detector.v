`timescale 1ns / 1ps

module tb_peak_detector;

parameter CLK_PERIOD = 2_777_778;
parameter N_SAMPLES  = 3600;
parameter HEX_LPS    = "out_lps.hex";
parameter HEX_CDERIV = "out_cderiv.hex";
parameter HEX_THRESH = "out_threshold.hex";
parameter HEX_PEAKS  = "out_peaks.hex";    // 1 if peak, 0 otherwise (per sample)

reg        clk, rst_n, valid_in;
reg [15:0] envelope_in;
reg signed [16:0] deriv_in;
reg [15:0] threshold_in;

wire        peak_flag;
wire [15:0] peak_value;
wire        valid_out;

peak_detector #(.REFRACTORY(72)) dut (
    .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
    .envelope_in(envelope_in), .deriv_in(deriv_in),
    .threshold_in(threshold_in),
    .peak_flag(peak_flag), .peak_value(peak_value), .valid_out(valid_out)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

reg [15:0] mem_lps   [0:N_SAMPLES-1];
reg [15:0] mem_cderiv[0:N_SAMPLES-1];
reg [15:0] mem_thresh[0:N_SAMPLES-1];
integer fout, sample_count, peak_count, i;
real    t_s;

initial begin
    $dumpfile("peak_wave.vcd");
    $dumpvars(0, tb_peak_detector);

    $readmemh(HEX_LPS,    mem_lps);
    $readmemh(HEX_CDERIV, mem_cderiv);
    $readmemh(HEX_THRESH, mem_thresh);
    $display("Loaded input files");

    fout = $fopen(HEX_PEAKS, "w");
    if (fout == 0) begin $display("ERROR: cannot open %s", HEX_PEAKS); $finish; end
    sample_count = 0; peak_count = 0;

    rst_n = 0; valid_in = 0;
    envelope_in = 0; deriv_in = 0; threshold_in = 0;
    repeat(4) @(posedge clk);
    rst_n = 1; @(posedge clk);

    for (i = 0; i < N_SAMPLES; i = i + 1) begin
        envelope_in  = mem_lps[i];
        // Restore signed: if MSB set, sign-extend
        deriv_in     = (mem_cderiv[i][15]) ? {2'b11, mem_cderiv[i]} :
                                             {2'b00, mem_cderiv[i]};
        threshold_in = mem_thresh[i];
        valid_in     = 1'b1;
        @(posedge clk);
    end
    @(posedge clk); valid_in = 0;
    repeat(10) @(posedge clk);

    $fclose(fout);
    $display("Detected %0d peaks in %0d samples", peak_count, sample_count);
    $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        $fwrite(fout, "%04X\n", peak_flag ? peak_value : 16'd0);
        sample_count = sample_count + 1;
        if (peak_flag) begin
            peak_count = peak_count + 1;
            t_s = sample_count / 360.0;
            $display("PEAK #%0d at sample %0d (t=%.3f s), amp=%0d",
                     peak_count, sample_count, t_s, peak_value);
        end
    end
end

endmodule
