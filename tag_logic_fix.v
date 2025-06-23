/* verilator lint_off UNUSEDSIGNAL */
module tag_logic_fix #(
    DATA_WIDTH=16,
    SETS=256,
    WAYS=16,
    ADDR_WIDTH = 64
) (
    input wire i_clk,
    input wire is_it_new_request,
    input wire is_state_fetch,
    input wire is_state_write,
    // input wire is_new_request_fetch,
    // input wire is_new_request_read,
    // input wire is_new_request_write,
    // input wire is_new_request_consume,

    // input wire miss,
    input wire [$clog2(SETS)-1:0]   cur_set,
    input wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] cur_tag,
    // input wire [WAYS-1:0]   victim_indicator_i,
    // input wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] partial_address,

    output wire [WAYS-1:0] [60:0] tag_rd
);

localparam TAG_WIDTH = 1+7+ADDR_WIDTH-$clog2(SETS)-$clog2(DATA_WIDTH);
// valid bit | dirty bit | emi | partial address
// wire [WAYS-1:0] [TAG_WIDTH:0] tag_rd
// wire [TAG_WIDTH:0] tag_wd = {new_valid_bit, new_dirty_bit, new_emi, cur_tag}


wire tag_read_en    = is_it_new_request;
wire tag_we   = (miss & is_state_fetch) | (miss & is_state_write);

// wire [WAYS-1:0] tag_bank_sel;
genvar gen_i;
// generate
//     for (gen_i = 0; gen_i < WAYS; gen_i++) begin
//         assign tag_bank_sel[gen_i]      = is_new_request_fetch 
//                                           | is_new_request_read
//                                           | is_new_request_consume
//                                           | is_new_request_write 
//                                           | (miss & is_state_fetch & victim_indicator_i[gen_i])
//                                           | (miss & is_state_write & victim_indicator_i[gen_i]);
//     end
// endgenerate

wire tag_ce = tag_read_en; //((tag_we | tag_read_en) & tag_bank_sel[gen_i]);
// wire tag_we = 1;
wire [TAG_WIDTH:0] tag_wd = 1;

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        fakeram7_61x256_tag_logic tag_array (
            .rd_out(tag_rd[gen_i]),
            .addr_in(cur_set),
            .we_in(tag_we),
            // CAUTION: sram cell do not properly work
            .wd_in(tag_wd),
            .clk(i_clk),
            .ce_in(tag_ce)
        );
    end
endgenerate

wire [WAYS-1:0] valid_bits_rd;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign valid_bits_rd[gen_i] = tag_rd[gen_i][TAG_WIDTH];
    end
endgenerate

wire [WAYS-1:0] dirty_bits_rd;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign dirty_bits_rd[gen_i] = tag_rd[gen_i][TAG_WIDTH-1];
    end
endgenerate

wire [WAYS-1:0] [6:0] emi_bits_rd;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign emi_bits_rd[gen_i] = tag_rd[gen_i][TAG_WIDTH-2 -: 7];
    end
endgenerate


wire [WAYS-1:0] [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] addr_bits_rd;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign addr_bits_rd[gen_i] = tag_rd[gen_i][ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0];
    end
endgenerate



wire [WAYS-1:0] hit_i;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign hit_i[gen_i] = (cur_tag == addr_bits_rd[gen_i]) & valid_bits_rd[gen_i];
    end
endgenerate



// priority_update_logic #(
//     .WAYS(WAYS),
//     .PRIORITY_BITS(PRIORITY_BITS)
// ) priority_update_logic_u (
//     .is_state_fetch(is_state_fetch),
//     .is_state_read(is_state_read),
//     .miss(miss),
//     .hit_i(hit_i),
//     .victim_indicator_i(victim_indicator_i),
//     .new_priority_set(new_priority_set),
//     .priority_set(priority_set)
// );

// srrip_update_logic #(
//     .WAYS(WAYS),
//     .SRRIP_BITS(SRRIP_BITS)
// ) srrip_update_logic_u (
//     .hit(hit),
//     .hit_i(hit_i),
//     .srrip_set(srrip_set),
//     .victim_indicator_i(victim_indicator_i),
//     .new_srrip_set(new_srrip_set)
// );

// emi_update #(
//     .WAYS(WAYS),
//     .SRRIP_BITS(SRRIP_BITS),
//     .PRIORITY_BITS(PRIORITY_BITS)
// ) emi_update_u (
//     .cur_valid_bits_line(cur_valid_bits_line),
//     .dirty_bits_set(dirty_bits_set),
//     .priority_set(priority_set),
//     .srrip_set(srrip_set),

//     .is_victim_dirty(is_victim_dirty),
//     .victim_indicator_i(victim_indicator_i)
// );

endmodule
