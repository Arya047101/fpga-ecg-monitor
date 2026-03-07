module lowpass_filter (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [15:0] x_in,    // 16-bit unsigned (from MWI)
    output reg  [15:0] y_out,   // 16-bit unsigned smoothed output
    output reg         valid_out
);

localparam signed [31:0] B0 =  32'sd59;
localparam signed [31:0] B1 =  32'sd119;
localparam signed [31:0] B2 =  32'sd59;
localparam signed [31:0] A1 = -32'sd29867;
localparam signed [31:0] A2 =  32'sd13726;
localparam integer        SH = 14;         

reg signed [31:0] s1;   
reg signed [31:0] s2;   
reg signed [31:0] x_s;      
reg signed [31:0] y_wide;   
reg signed [31:0] y_curr;   
reg signed [31:0] s1_next;  
reg signed [31:0] s2_next;  

always @(posedge clk) begin
    if (!rst_n) begin
        s1        <= 32'sd0;
        s2        <= 32'sd0;
        y_out     <= 16'd0;
        valid_out <= 1'b0;
    end
    else if (valid_in) begin
        x_s    = $signed({16'd0, x_in});  
        y_wide = B0 * x_s + s1;            
        y_curr = y_wide >>> SH;            

        s1_next = B1 * x_s - A1 * y_curr + s2;  
        s2_next = B2 * x_s - A2 * y_curr;        
        s1 <= s1_next;
        s2 <= s2_next;
        if      (y_curr < 32'sd0)      y_out <= 16'd0;
        else if (y_curr > 32'sd65535)  y_out <= 16'hFFFF;
        else                           y_out <= y_curr[15:0];

        valid_out <= valid_in;
    end
    else begin
        valid_out <= 1'b0;
    end
end

endmodule
