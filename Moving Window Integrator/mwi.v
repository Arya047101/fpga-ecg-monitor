module moving_window_integrator #(
    parameter N = 30   // Window length 
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [15:0] x_in,   // 16-bit unsigned input (from squaring)
    output reg  [15:0] y_out,  // 16-bit unsigned output
    output reg         valid_out
);

reg [15:0] buf_mem [0:N-1];          
reg [$clog2(N)-1:0] wr_ptr;          
reg [31:0] acc;
integer i;

always @(posedge clk) begin
    if (!rst_n) begin
        acc       <= 32'd0;
        wr_ptr    <= 0;
        y_out     <= 16'd0;
        valid_out <= 1'b0;
        for (i = 0; i < N; i = i + 1)
            buf_mem[i] <= 16'd0;  
    end
    else if (valid_in) begin
        acc <= acc + x_in - buf_mem[wr_ptr];
        buf_mem[wr_ptr] <= x_in;
        if (wr_ptr == N - 1)
            wr_ptr <= 0;
        else
            wr_ptr <= wr_ptr + 1;
        y_out <= (acc + x_in - buf_mem[wr_ptr]) / N; 

        valid_out <= valid_in;
    end
    else begin
        valid_out <= 1'b0;
    end
end

endmodule