module dram_data_handler #(
    BIT_SIZE=8,
    DATA_WIDTH=16,
    WAYS=16
) (
    input wire i_clk,
    input wire miss,
    input wire is_victim_dirty,
    input wire is_state_fetch,
    input wire is_state_write,
    input wire [WAYS-1:0] victim_indicator_i,
    input wire [WAYS-1:0] [DATA_WIDTH*BIT_SIZE-1:0] data_set,
    output wire [DATA_WIDTH*BIT_SIZE-1:0] o_dram_data_o
);


wire [WAYS-1:0] [DATA_WIDTH*BIT_SIZE-1:0] masked_data;
generate
    for (genvar i = 0; i < WAYS; i++) begin : gen_masked_data
        assign masked_data[i] = data_set[i] & {DATA_WIDTH*BIT_SIZE{victim_indicator_i[i]}};
    end
endgenerate

wire [DATA_WIDTH*BIT_SIZE-1:0] dirty_data_comb = 
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

reg [DATA_WIDTH*BIT_SIZE-1:0] dirty_data;

always @(posedge i_clk) begin
    if (miss & is_victim_dirty & (is_state_fetch | is_state_write)) begin
        dirty_data <= dirty_data_comb;
    end
end

assign o_dram_data_o = dirty_data;

endmodule
