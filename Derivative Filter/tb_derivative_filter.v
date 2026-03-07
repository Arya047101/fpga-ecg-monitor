`timescale 1ns / 1ps

module tb_derivative_filter;

parameter CLK_PERIOD = 2_778;         // 360 Hz
parameter N_SAMPLES  = 3600;
parameter HEX_IN     = "out_bpf.hex";      // Reads BPF output as input
parameter HEX_OUT    = "out_deriv.hex";    // Derivative output
parameter VCD_FILE   = "deriv_wave.vcd";

reg        clk;
reg        rst_n;
reg        valid_in;
reg  signed [15:0] x_in;
wire signed [15:0] y_out;
wire       valid_out;

// DUT instantiation
derivative_filter dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .valid_in (valid_in),
    .x_in     (x_in),
    .y_out    (y_out),
    .valid_out(valid_out)
);

// Clock generation
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

// Input storage
reg [15:0] mem_in [0:N_SAMPLES-1];

// VCD: dump only top-level ports (5 regs * 16b = tiny VCD)
initial begin
    $dumpfile(VCD_FILE);
    $dumpvars(0, tb_derivative_filter.clk);
    $dumpvars(0, tb_derivative_filter.rst_n);
    $dumpvars(0, tb_derivative_filter.valid_in);
    $dumpvars(0, tb_derivative_filter.x_in);
    $dumpvars(0, tb_derivative_filter.y_out);
    $dumpvars(0, tb_derivative_filter.valid_out);
end

integer fout;
integer sample_count;

initial begin
    $readmemh(HEX_IN, mem_in);      // Load BPF output hex as this stage's input
    $display("Loaded %s", HEX_IN);

    fout = $fopen(HEX_OUT, "w");
    if (fout == 0) begin
        $display("ERROR: Cannot open output file"); $finish;
    end
    sample_count = 0;

    // Reset
    rst_n = 0; valid_in = 0; x_in = 16'sd0;
    repeat (4) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // Feed samples
    begin : feed
        integer i;
        for (i = 0; i < N_SAMPLES; i = i + 1) begin
            @(posedge clk);
            x_in     <= $signed(mem_in[i]);   // Signed BPF output
            valid_in <= 1'b1;
        end
    end

    @(posedge clk); valid_in <= 1'b0;
    repeat (10) @(posedge clk);   // Flush 5-tap FIR pipeline

    $fclose(fout);
    $display("Written %0d samples to %s", sample_count, HEX_OUT);
    $finish;
end

// Capture output
always @(posedge clk) begin
    if (valid_out) begin
        $fwrite(fout, "%04X\n", y_out & 16'hFFFF);  // Two's complement hex
        sample_count = sample_count + 1;
    end
end

endmodule
