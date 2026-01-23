module bandpass_filter #(parameter DATA_WIDTH = 16)(
    input clk,
    input rst,
    input signed [DATA_WIDTH-1:0] data_in,
    input data_valid
    output reg signed [DATA_WIDTH-1:0] data_out,
    output reg valid_out
)

//Constants


//Delay Lines
reg [DATA_WIDTH-1:0] input_delay_line [0:4];
reg [DATA_WIDTH-1:0] output_delay_line [0:4];

//
reg [47:0] accumulator;
integer i;


//Loop
always @(posedge clk or negedge rst) begin 
    if(!rst) begin 
        for (i = 0; i < 5 ; i = i + 1) begin 
            input_delay_line[i] <= 0;
            output_delay_line[i] <= 0;
        end
        data_out <= 0;
        valid_out <= 0;
    end
    else if begin
        for (i = 4; i > 0 ; i = i - 1) begin 
            input_delay_line[i] <= input_delay_line[i-1];
            output_delay_line[i] <= output_delay_line[i-1];
        end
        input_delay_line[0] <= data_in;
        accumulator <= //equation 
        
        output_delay_line <= accumulator >>> 12;
        data_out <= accumulator >>> 12;
        valid_out <= 1;
    end
    else begin 
        valid_out <= 0;
    end
end
endmodule
