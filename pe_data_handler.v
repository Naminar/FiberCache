module pe_data_handler #(
    BIT_SIZE=8,
    DATA_WIDTH=16,
    WAYS=16
) (
    input wire i_clk,
    input wire is_state_read,
    input wire is_state_consume,
    input wire [WAYS-1:0] hit_i,
    input wire [WAYS-1:0] [DATA_WIDTH*BIT_SIZE-1:0] data_set,
    output reg [DATA_WIDTH*BIT_SIZE-1:0] o_pe_data_o
);

wire [WAYS-1:0] [DATA_WIDTH*BIT_SIZE-1:0] masked_data;
generate
for (genvar i = 0; i < WAYS; i++) begin : gen_pe_data
    assign masked_data[i] = data_set[i] & {DATA_WIDTH*BIT_SIZE{hit_i[i]}};
end
endgenerate

wire [DATA_WIDTH*BIT_SIZE-1:0] pe_data_comb = 
    masked_data[0] |
    masked_data[1] |
    masked_data[2] |
    masked_data[3] |
    masked_data[4] |
    masked_data[5] |
    masked_data[6] |
    masked_data[7] |
    masked_data[8] |
    masked_data[9] |
    masked_data[10] |
    masked_data[11] |
    masked_data[12] |
    masked_data[13] |
    masked_data[14] |
    masked_data[15];

always @(posedge i_clk) begin
    if (is_state_read | is_state_consume) begin
        o_pe_data_o <= pe_data_comb;
    end
end

endmodule
