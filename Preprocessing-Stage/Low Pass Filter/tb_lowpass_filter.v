// =============================================================
//  Testbench: tb_lowpass_filter.v
//  Tests lowpass_filter.v (post-MWI LP smoothing)
//  Inputs: out_mwi.hex  Outputs: out_lps.hex, lps_wave.vcd
// =============================================================

`timescale 1ns / 1ps

module tb_lowpass_filter;

parameter CLK_PERIOD = 2_778;
parameter N_SAMPLES  = 3600;
parameter HEX_IN     = "out_mwi.hex";
parameter HEX_OUT    = "out_lps.hex";
parameter VCD_FILE   = "lps_wave.vcd";

reg        clk;
reg        rst_n;
reg        valid_in;
reg  [15:0] x_in;
wire [15:0] y_out;
wire        valid_out;

lowpass_filter dut (
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

initial begin
    $dumpfile(VCD_FILE);
    $dumpvars(0, tb_lowpass_filter.clk);
    $dumpvars(0, tb_lowpass_filter.valid_in);
    $dumpvars(0, tb_lowpass_filter.x_in);
    $dumpvars(0, tb_lowpass_filter.y_out);
    $dumpvars(0, tb_lowpass_filter.valid_out);
    // s1, s2 state regs NOT dumped — saves VCD space
end

integer fout;
integer sample_count;

initial begin
    $readmemh(HEX_IN, mem_in);
    fout = $fopen(HEX_OUT, "w");
    sample_count = 0;

    rst_n = 0; valid_in = 0; x_in = 16'd0;
    repeat (4) @(posedge clk);
    rst_n = 1; @(posedge clk);

    begin : feed
        integer i;
        for (i = 0; i < N_SAMPLES; i = i + 1) begin
            @(posedge clk);
            x_in     <= mem_in[i];
            valid_in <= 1'b1;
        end
    end

    @(posedge clk); valid_in <= 1'b0;
    repeat (10) @(posedge clk);

    $fclose(fout);
    $display("LPS: Written %0d samples to %s", sample_count, HEX_OUT);
    $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        $fwrite(fout, "%04X\n", y_out);
        sample_count = sample_count + 1;
    end
end

endmodule
