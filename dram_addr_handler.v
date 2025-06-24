module dram_addr_handler #(
    SETS=256,
    WAYS=16,
    ADDR_WIDTH=64,
    DATA_WIDTH=16
) (
    input wire i_clk,
    input wire miss,
    input wire is_victim_dirty,
    input wire is_state_fetch,
    input wire is_state_write,
    input wire is_internal_state_receive_data,
    input wire [WAYS-1:0] victim_indicator_i,
    input wire [$clog2(SETS)-1:0] cur_set,
    input wire [WAYS-1:0] [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_set,
    input wire [ADDR_WIDTH-1:0] internal_addr,
    output wire [ADDR_WIDTH-1:0] o_dram_addr
);

localparam TAG_WIDTH = ADDR_WIDTH - $clog2(SETS) - $clog2(DATA_WIDTH);

wire [WAYS-1:0] [TAG_WIDTH-1:0] masked_tag;
generate
for (genvar i = 0; i < WAYS; i++) begin : gen_tag
    assign masked_tag[i] = tag_set[i] & {TAG_WIDTH{victim_indicator_i[i]}};
end
endgenerate

wire [TAG_WIDTH-1:0] selected_tag = 
    masked_tag[0] |
    masked_tag[1] |
    masked_tag[2] |
    masked_tag[3] |
    masked_tag[4] |
    masked_tag[5] |
    masked_tag[6] |
    masked_tag[7] |
    masked_tag[8] |
    masked_tag[9] |
    masked_tag[10] |
    masked_tag[11] |
    masked_tag[12] |
    masked_tag[13] |
    masked_tag[14] |
    masked_tag[15];

wire [ADDR_WIDTH-1:0] dirty_addr_comb = {selected_tag, cur_set, {$clog2(DATA_WIDTH){1'b0}}};

reg [ADDR_WIDTH-1:0] dirty_addr;

always @(posedge i_clk) begin
    if (miss & is_victim_dirty & (is_state_fetch | is_state_write)) begin
        dirty_addr <= dirty_addr_comb;
    end
end

assign o_dram_addr = (is_internal_state_receive_data) ? internal_addr : dirty_addr;

endmodule
