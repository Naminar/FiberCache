module inout_handler #(
    DATA_WIDTH=16,
    SETS=256,
    WAYS=16,
    ADDR_WIDTH = 64
) (
    input wire i_clk,
    input wire is_state_fetch,
    input wire is_state_read,
    input wire is_state_write,
    input wire is_state_consume,
    input wire is_internal_state_receive_data,

    input wire miss,
    input wire is_victim_dirty,

    input wire [WAYS-1:0]                   hit_i,
    input wire [$clog2(SETS)-1:0]           cur_set,
    input wire [WAYS-1:0]                   victim_indicator_i,
    input wire [ADDR_WIDTH-1:0]             internal_addr,
    input wire [WAYS-1:0] [DATA_WIDTH-1:0]  data_set,
    
    input wire [WAYS-1:0] [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_set,

    output  reg     [DATA_WIDTH-1:0]    o_pe_data_o,
    output  wire    [DATA_WIDTH-1:0]    o_dram_data_o,
    output  wire    [ADDR_WIDTH-1:0]    o_dram_addr
);
reg [DATA_WIDTH-1:0] dirty_data;
reg [ADDR_WIDTH-1:0] dirty_addr;
reg [DATA_WIDTH-1:0] dirty_data_comb;
reg [ADDR_WIDTH-1:0] dirty_addr_comb;
reg [DATA_WIDTH-1:0] pe_data_comb;

always @(*) begin
    dirty_data_comb = {DATA_WIDTH{1'b0}};
    dirty_addr_comb = {ADDR_WIDTH{1'b0}};

    for (int i = 0; i < WAYS; i++) begin
        dirty_data_comb = dirty_data_comb | (data_set[i] & {DATA_WIDTH{victim_indicator_i[i]}});
        dirty_addr_comb = dirty_addr_comb | {tag_set[i] & {ADDR_WIDTH-$clog2(SETS)-$clog2(DATA_WIDTH){victim_indicator_i[i]}}, cur_set, {$clog2(DATA_WIDTH){1'b0}}};
    end
end

always @(posedge i_clk) begin
    if (miss & is_victim_dirty & (is_state_fetch | is_state_write)) begin
        dirty_data <= dirty_data_comb;
        dirty_addr <= dirty_addr_comb;
    end
end

always @(*) begin
    pe_data_comb = 0;
    for (int i = 0; i < WAYS; i++)
        pe_data_comb = pe_data_comb | (data_set[i] & {DATA_WIDTH{hit_i[i]}});
end

always @(posedge i_clk) begin
    if (is_state_read | is_state_consume) begin
        o_pe_data_o <= pe_data_comb;
    end
end

assign o_dram_data_o = dirty_data;
assign o_dram_addr = (is_internal_state_receive_data)?
                            internal_addr
                        :
                            dirty_addr;

endmodule
