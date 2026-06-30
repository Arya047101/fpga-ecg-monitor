`timescale 1ns / 1ps

module tb_centered_derivative;

parameter CLK_PERIOD = 2_777_778;   // ~360 Hz (ns)
parameter N_SAMPLES  = 3600;
parameter HEX_IN     = "out_lps.hex";
parameter HEX_OUT    = "out_cderiv.hex";

reg        clk, rst_n, valid_in;
reg [15:0] x_in;
wire signed [16:0] y_out;
wire       valid_out;

centered_derivative dut (
    .clk(clk), .rst_n(rst_n), .valid_in(valid_in),
    .x_in(x_in), .y_out(y_out), .valid_out(valid_out)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

reg [15:0] mem_in [0:N_SAMPLES-1];
integer fout, sample_count, i;

initial begin
    $dumpfile("cderiv_wave.vcd");
    $dumpvars(0, tb_centered_derivative);
    $readmemh(HEX_IN, mem_in);
    $display("Loaded: %s", HEX_IN);

    fout = $fopen(HEX_OUT, "w");
    if (fout == 0) begin $display("ERROR: cannot open %s", HEX_OUT); $finish; end
    sample_count = 0;

    rst_n = 0; valid_in = 0; x_in = 16'd0;
    repeat(4) @(posedge clk);
    rst_n = 1; @(posedge clk);

    for (i = 0; i < N_SAMPLES; i = i + 1) begin
        x_in = mem_in[i]; valid_in = 1'b1;
        @(posedge clk);
    end
    @(posedge clk); valid_in = 1'b0;
    repeat(10) @(posedge clk);

    $fclose(fout);
    $display("Written %0d samples to %s", sample_count, HEX_OUT);
    $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        // Store as signed 17-bit: mask to 17 bits, sign-extend to 32
        $fwrite(fout, "%04X\n", y_out[15:0] & 16'hFFFF);
        sample_count = sample_count + 1;
    end
end

endmodule
