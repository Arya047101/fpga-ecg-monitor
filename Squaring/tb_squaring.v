// =============================================================
//  Testbench: tb_squaring.v
//  Tests squaring.v — reads derivative output, writes squared output.
//  Output is unsigned (all non-negative).
//  Outputs: out_sq.hex, sq_wave.vcd
// =============================================================

`timescale 1ns / 1ps

module tb_squaring;

parameter CLK_PERIOD = 2_778;
parameter N_SAMPLES  = 3600;
parameter HEX_IN     = "out_deriv.hex";   // Derivative filter output
parameter HEX_OUT    = "out_sq.hex";      // Squaring output
parameter VCD_FILE   = "sq_wave.vcd";

reg        clk;
reg        rst_n;
reg        valid_in;
reg  signed [15:0] x_in;     // Signed derivative input
wire       [15:0]  y_out;    // Unsigned squared output
wire       valid_out;

squaring dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .valid_in (valid_in),
    .x_in     (x_in),
    .y_out    (y_out),
    .valid_out(valid_out)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

reg [15:0] mem_in [0:N_SAMPLES-1];

// VCD: port-only dump
initial begin
    $dumpfile(VCD_FILE);
    $dumpvars(0, tb_squaring.clk);
    $dumpvars(0, tb_squaring.valid_in);
    $dumpvars(0, tb_squaring.x_in);
    $dumpvars(0, tb_squaring.y_out);
    $dumpvars(0, tb_squaring.valid_out);
end

integer fout;
integer sample_count;

initial begin
    $readmemh(HEX_IN, mem_in);
    fout = $fopen(HEX_OUT, "w");
    sample_count = 0;

    rst_n = 0; valid_in = 0; x_in = 16'sd0;
    repeat (4) @(posedge clk);
    rst_n = 1; @(posedge clk);

    begin : feed
        integer i;
        for (i = 0; i < N_SAMPLES; i = i + 1) begin
            @(posedge clk);
            x_in     <= $signed(mem_in[i]);   // Interpret hex as signed
            valid_in <= 1'b1;
        end
    end

    @(posedge clk); valid_in <= 1'b0;
    repeat (4) @(posedge clk);   // Squaring has 1-cycle latency

    $fclose(fout);
    $display("Squaring: Written %0d samples to %s", sample_count, HEX_OUT);
    $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        $fwrite(fout, "%04X\n", y_out);   // Unsigned — no sign extension needed
        sample_count = sample_count + 1;
    end
end

endmodule
