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

wire [WAYS:0] [DATA_WIDTH*BIT_SIZE-1:0] pe_data_or;
assign pe_data_or[0] = {DATA_WIDTH*BIT_SIZE{1'b0}};

generate
for (genvar i = 0; i < WAYS; i++) begin : gen_pe_data
    assign pe_data_or[i+1] = pe_data_or[i] | (data_set[i] & {DATA_WIDTH*BIT_SIZE{hit_i[i]}});
end
endgenerate

wire [DATA_WIDTH*BIT_SIZE-1:0] pe_data_comb = pe_data_or[WAYS];

always @(posedge i_clk) begin
    if (is_state_read | is_state_consume) begin
        o_pe_data_o <= pe_data_comb;
    end
end

endmodule
