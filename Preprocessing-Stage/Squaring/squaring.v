module squaring (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire signed [15:0] x_in,  // 16-bit signed derivative input
    output reg         [15:0] y_out, // 16-bit unsigned squared output
    output reg         valid_out
);

reg signed [31:0] sq;       
reg        [31:0] sq_shifted; 

always @(posedge clk) begin
    if (!rst_n) begin
        sq        <= 32'sd0;
        sq_shifted <= 32'd0;
        y_out     <= 16'd0;
        valid_out <= 1'b0;
    end
    else if (valid_in) begin
        sq <= x_in * x_in;         
        if (sq_shifted > 32'd65535)
            y_out <= 16'hFFFF;     
        else
            y_out <= sq_shifted[15:0]; 

        valid_out <= valid_in;
    end
    else begin
        valid_out <= 1'b0;
    end
end

endmodule
