// =============================================================
//  Testbench: tb_mwi.v
//  Tests moving_window_integrator.v
//  Inputs: out_sq.hex  Outputs: out_mwi.hex, mwi_wave.vcd
// =============================================================

`timescale 1ns / 1ps

module tb_mwi;

parameter CLK_PERIOD = 2_778;
parameter N_SAMPLES  = 3600;
parameter HEX_IN     = "out_sq.hex";     // Squaring output
parameter HEX_OUT    = "out_mwi.hex";    // MWI output
parameter VCD_FILE   = "mwi_wave.vcd";
parameter N_WIN      = 30;               // MWI window length

reg        clk;
reg        rst_n;
reg        valid_in;
reg  [15:0] x_in;     // Unsigned squaring output
wire [15:0] y_out;    // Unsigned MWI output
wire        valid_out;

moving_window_integrator #(.N(N_WIN)) dut (
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
    $dumpvars(0, tb_mwi.clk);
    $dumpvars(0, tb_mwi.valid_in);
    $dumpvars(0, tb_mwi.x_in);
    $dumpvars(0, tb_mwi.y_out);
    $dumpvars(0, tb_mwi.valid_out);
    // NOTE: buf_mem circular buffer NOT dumped (30 * 16b = 480b saved per transition)
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
            x_in     <= mem_in[i];     // Unsigned
            valid_in <= 1'b1;
        end
    end

    @(posedge clk); valid_in <= 1'b0;
    repeat (35) @(posedge clk);   // Flush MWI (N_WIN cycles)

    $fclose(fout);
    $display("MWI: Written %0d samples to %s", sample_count, HEX_OUT);
    $finish;
end

always @(posedge clk) begin
    if (valid_out) begin
        $fwrite(fout, "%04X\n", y_out);
        sample_count = sample_count + 1;
    end
end

endmodule


