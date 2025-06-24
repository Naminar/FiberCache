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

wire [WAYS:0] [DATA_WIDTH*BIT_SIZE-1:0] dirty_data_or;
assign dirty_data_or[0] = {DATA_WIDTH*BIT_SIZE{1'b0}};

generate
for (genvar i = 0; i < WAYS; i++) begin : gen_dirty_data
    assign dirty_data_or[i+1] = dirty_data_or[i] | (data_set[i] & {DATA_WIDTH*BIT_SIZE{victim_indicator_i[i]}});
end
endgenerate

wire [DATA_WIDTH*BIT_SIZE-1:0] dirty_data_comb = dirty_data_or[WAYS];

reg [DATA_WIDTH*BIT_SIZE-1:0] dirty_data;

always @(posedge i_clk) begin
    if (miss & is_victim_dirty & (is_state_fetch | is_state_write)) begin
        dirty_data <= dirty_data_comb;
    end
end

assign o_dram_data_o = dirty_data;

endmodule
