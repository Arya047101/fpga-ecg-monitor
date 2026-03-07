module bandpass_filter (
    input  wire        clk,
    input  wire        rst_n,      
    input  wire        valid_in,    
    input  wire signed [15:0] x_in, 
    output reg  signed [15:0] y_out,
    output reg         valid_out    
);

reg signed [15:0] x_d [0:9];   
reg signed [31:0] y_lp;        

integer i;

always @(posedge clk) begin
    if (!rst_n) begin
        for (i = 0; i < 10; i = i + 1)
            x_d[i] <= 16'sd0;
        y_lp <= 32'sd0;
    end
    else if (valid_in) begin

        for (i = 9; i > 0; i = i - 1)
            x_d[i] <= x_d[i-1];
        x_d[0] <= x_in;

        y_lp <=   {{16{x_in[15]}},    x_in}            // 1 * x[n]
               + ({{16{x_d[0][15]}},  x_d[0]}  <<< 1)  // 2 * x[n-1]
               + ({{16{x_d[1][15]}},  x_d[1]}  + ({{16{x_d[1][15]}}, x_d[1]} <<< 1)) // 3*x[n-2]
               + ({{16{x_d[2][15]}},  x_d[2]}  <<< 2)  // 4 * x[n-3]
               + (({{16{x_d[3][15]}}, x_d[3]}  <<< 2) + {{16{x_d[3][15]}}, x_d[3]})  // 5*x[n-4]
               + (({{16{x_d[4][15]}}, x_d[4]}  <<< 1) + ({{16{x_d[4][15]}}, x_d[4]} <<< 2)) // 6*x[n-5]
               + (({{16{x_d[5][15]}}, x_d[5]}  <<< 2) + {{16{x_d[5][15]}}, x_d[5]})  // 5*x[n-6]
               + ({{16{x_d[6][15]}},  x_d[6]}  <<< 2)  // 4 * x[n-7]
               + ({{16{x_d[7][15]}},  x_d[7]}  + ({{16{x_d[7][15]}}, x_d[7]} <<< 1)) // 3*x[n-8]
               + ({{16{x_d[8][15]}},  x_d[8]}  <<< 1)  // 2 * x[n-9]
               +  {{16{x_d[9][15]}},  x_d[9]};          // 1 * x[n-10]
    end
end

reg signed [31:0] lp_d [0:31];  
reg signed [31:0] y_hp;         
reg signed [31:0] y_hp_d1;      

always @(posedge clk) begin
    if (!rst_n) begin
        for (i = 0; i < 32; i = i + 1)
            lp_d[i] <= 32'sd0;
        y_hp    <= 32'sd0;
        y_hp_d1 <= 32'sd0;
    end
    else if (valid_in) begin

        y_hp <= y_hp_d1
              + ($signed(y_lp)      >>> 5) * (-1)  // -y_lp[n]/32   
              + lp_d[15]                            // +y_lp[n-16]
              - lp_d[16]                            // -y_lp[n-17]
              + ($signed(lp_d[31])  >>> 5);         // +y_lp[n-32]/32 

        y_hp_d1 <= y_hp;

        for (i = 31; i > 0; i = i - 1)
            lp_d[i] <= lp_d[i-1];
        lp_d[0] <= y_lp;
    end
end

reg signed [31:0] y_scaled;

always @(posedge clk) begin
    if (!rst_n) begin
        y_scaled  <= 32'sd0;
        y_out     <= 16'sd0;
        valid_out <= 1'b0;
    end
    else begin
        y_scaled <= $signed(y_hp) >>> 5;   // ÷32 — brings into ~16-bit range

        if      (y_scaled > 32'sh00007FFF)  y_out <= 16'sh7FFF;  // +32767 clamp
        else if (y_scaled < 32'shFFFF8000)  y_out <= 16'sh8000;  // -32768 clamp
        else                                y_out <= y_scaled[15:0];

        valid_out <= valid_in;
    end
end

endmodule
