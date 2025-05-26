module tag_logic #(
    DATA_WIDTH=16, // double + 2 * i32
    SETS=256,
    WAYS=16,
    ADDR_WIDTH = 64 // 64 bit address
    // SRRIP_BITS=2,
    // PRIORITY_BITS=5
) (
    input wire i_clk,
    input wire is_state_fetch,
    // input wire is_state_read,
    input wire is_state_write,
    // input wire is_state_consume,
    input wire is_new_request_fetch,
    input wire is_new_request_read, 
    input wire is_new_request_write,
    input wire is_new_request_consume,
    
    input wire miss,
    input wire [$clog2(SETS)-1:0] cur_set,
    input wire [WAYS-1:0] victim_indicator_i,
    input wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] cur_tag,
    output wire [WAYS-1:0] [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_set 
);

wire [WAYS-1:0] tag_bank_sel;
wire tag_read_en                 = is_new_request_fetch | is_new_request_read | is_new_request_consume | is_new_request_write;
wire tag_write_en = (miss & is_state_fetch) | (miss & is_state_write);
wire [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_write_data = cur_tag;

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign tag_bank_sel[gen_i]      = is_new_request_fetch | (miss & is_state_fetch & victim_indicator_i[gen_i])
                                          | is_new_request_read
                                          | is_new_request_consume
                                          | is_new_request_write | (miss & is_state_write & victim_indicator_i[gen_i]);
    end
endgenerate

genvar gen_i;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        srambank
                #(
                    .ADDRESS($clog2(SETS)),
                    .DATA(ADDR_WIDTH-$clog2(SETS)-$clog2(DATA_WIDTH))
                ) tag_array
                (
                    .i_clk(i_clk),
                    .i_address(cur_set),
                    .i_write_data(tag_write_data),
                    .i_bank_sel(tag_bank_sel[gen_i]),
                    .i_read_en(tag_read_en),
                    .i_write_en(tag_write_en),
                    .o_data_out(tag_set[gen_i])
                );
    end
endgenerate

endmodule
