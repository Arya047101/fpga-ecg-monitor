module derivative_filter #(parameter DATA_WIDTH = 16) (
    input clk,
    input rst,
    input signed [DATA_WIDTH-1:0] data_in,
    input data_valid,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg valid_out
)

//delay line 
reg [DATA_WIDTH-1:0] input_delay_line [0:4];

integer i;

always @(posedge clk or negedge rst) begin 
    if(!rst) begin
        for (i = 0; i < 5 ; i = i + 1) begin 
            input_delay_line <= 0;
        end
    end
    