/* verilator lint_off UNUSEDSIGNAL */
module tag_logic_fix #(
    DATA_WIDTH=16,
    SETS=256,
    WAYS=16,
    ADDR_WIDTH = 64,
    SRRIP_BITS=2,
    PRIORITY_BITS=5
) (
    input wire i_clk,
    input wire i_nreset,
    // input wire is_it_new_request,
    input wire is_state_fetch,
    input wire is_state_write,
    input wire is_state_read,
    input wire is_state_consume,
    input wire is_new_request_fetch,
    input wire is_new_request_read,
    input wire is_new_request_write,
    input wire is_new_request_consume,

    // input wire miss,
    input wire [$clog2(SETS)-1:0]   cur_set,
    input wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] cur_tag,
    output wire [WAYS-1:0] where_to_write_while_write_stage,
    output wire [WAYS-1:0] hit_i,
    output wire [WAYS-1:0] victim_indicator_i,
    output wire miss
    // input wire [WAYS-1:0]   victim_indicator_i,
    // input wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] partial_address,
);

localparam TAG_WIDTH = 1+7+ADDR_WIDTH-$clog2(SETS)-$clog2(DATA_WIDTH);

//=================================================================//
// valid 1 bit | dirty 1 bit | emi 2 bits | partial address 52 bits//
//=================================================================//
wire [WAYS-1:0] [60:0] tag_rd;
wire [WAYS-1:0] [TAG_WIDTH:0] tag_wd;


wire [WAYS-1:0] new_valid_bit;
wire [WAYS-1:0] new_dirty_bit;
wire [WAYS-1:0] [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] new_addr_bits;

wire is_it_new_request    =   is_new_request_fetch
                            | is_new_request_read
                            | is_new_request_consume
                            | is_new_request_write;

wire is_it_state          = is_state_fetch
                            | is_state_write
                            | is_state_read
                            | is_state_consume;

wire tag_we    = is_it_state;
wire tag_ce    = is_it_new_request | tag_we;
wire hit = |hit_i;
assign miss = ~hit;

wire [WAYS-1:0] [PRIORITY_BITS-1:0]     priority_set;
wire [WAYS-1:0] [SRRIP_BITS-1:0]        srrip_set;
wire [WAYS-1:0] [PRIORITY_BITS-1:0]     new_priority_set;
wire [WAYS-1:0] [SRRIP_BITS-1:0]        new_srrip_set;


// wire [WAYS-1:0] victim_indicator_i;
wire is_victim_dirty;


genvar gen_i;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign tag_wd[gen_i] = {    new_valid_bit[gen_i], 
                                    new_dirty_bit[gen_i],
                                    // new_emi
                                    {new_priority_set[gen_i], new_srrip_set[gen_i]}, 
                                    new_addr_bits[gen_i]
                                };//, cur_tag}
    end
endgenerate

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        fakeram7_61x256_tag_logic tag_array (
            .rd_out(tag_rd[gen_i]),
            .addr_in(cur_set),
            .we_in(tag_we),
            // CAUTION: sram cell do not properly work
            .wd_in(tag_wd[gen_i]),
            .clk(i_clk),
            .ce_in(tag_ce)
        );
    end
endgenerate


wire [WAYS-1:0] valid_bits_rd;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign valid_bits_rd[gen_i] = tag_rd[gen_i][TAG_WIDTH-1];
    end
endgenerate


wire [WAYS-1:0] dirty_bits_rd;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign dirty_bits_rd[gen_i] = tag_rd[gen_i][TAG_WIDTH-2];
    end
endgenerate

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign {priority_set[gen_i], srrip_set[gen_i]} = tag_rd[gen_i][TAG_WIDTH-3 -: 7];
    end
endgenerate



wire [WAYS-1:0] [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] addr_bits_rd;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign addr_bits_rd[gen_i] = tag_rd[gen_i][ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0];
    end
endgenerate


generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign hit_i[gen_i] = (cur_tag == addr_bits_rd[gen_i]) & valid_bits_rd[gen_i];
    end
endgenerate


priority_update_logic #(
    .WAYS(WAYS),
    .PRIORITY_BITS(PRIORITY_BITS)
) priority_update_logic_u (
    .is_state_fetch(is_state_fetch),
    .is_state_read(is_state_read),
    .miss(miss),
    .hit_i(hit_i),
    .victim_indicator_i(victim_indicator_i),
    .new_priority_set(new_priority_set),
    .priority_set(priority_set)
);

srrip_update_logic #(
    .WAYS(WAYS),
    .SRRIP_BITS(SRRIP_BITS)
) srrip_update_logic_u (
    .hit(hit),
    .hit_i(hit_i),
    .srrip_set(srrip_set),
    .victim_indicator_i(victim_indicator_i),
    .new_srrip_set(new_srrip_set)
);


generate
    for (gen_i = 0; gen_i < WAYS; gen_i++)
        assign where_to_write_while_write_stage[gen_i] = (hit)? 
                                                            hit_i[gen_i]
                                                          : 
                                                            victim_indicator_i[gen_i];
endgenerate


generate
for (gen_i = 0; gen_i < WAYS; gen_i++) begin
    assign new_valid_bit[gen_i] = i_nreset & (miss & is_state_fetch & victim_indicator_i[gen_i])? 1'b1
                                    : (is_state_consume & hit_i[gen_i])? 1'b0
                                    : (is_state_write & where_to_write_while_write_stage[gen_i])? 1'b1
                                    : valid_bits_rd[gen_i];
end
endgenerate

generate
for (gen_i = 0; gen_i < WAYS; gen_i++) begin
    assign new_dirty_bit[gen_i] = (is_state_write & where_to_write_while_write_stage[gen_i])? 1'b1
                                    : dirty_bits_rd[gen_i];
end
endgenerate


generate
for (gen_i = 0; gen_i < WAYS; gen_i++) begin
    assign new_addr_bits[gen_i] = ((miss & is_state_fetch & victim_indicator_i[gen_i]) 
                                    | (miss & is_state_write & victim_indicator_i[gen_i])
                                  )? cur_tag
                                        : addr_bits_rd[gen_i];
end
endgenerate

emi_update #(
    .WAYS(WAYS),
    .SRRIP_BITS(SRRIP_BITS),
    .PRIORITY_BITS(PRIORITY_BITS)
) emi_update_u (
    .cur_valid_bits_line(valid_bits_rd),
    .dirty_bits_set(dirty_bits_rd),
    .priority_set(priority_set),
    .srrip_set(srrip_set),

    .is_victim_dirty(is_victim_dirty),
    .victim_indicator_i(victim_indicator_i)
);

endmodule
