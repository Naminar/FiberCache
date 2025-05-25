module emi_logic #(
    SETS=256,
    WAYS=16,
    SRRIP_BITS=2,
    PRIORITY_BITS=5
) (
    input wire i_clk,
    input wire is_state_fetch,
    input wire is_state_read,
    input wire is_state_write,
    input wire is_state_consume,
    input wire is_new_request_fetch,
    input wire is_new_request_read, 
    input wire is_new_request_write,
    input wire is_new_request_consume,
    
    input wire [$clog2(SETS)-1:0] cur_set,
    input wire [SRRIP_BITS-1:0]    new_srrip_set       [WAYS-1:0],
    input wire [PRIORITY_BITS-1:0] new_priority_set    [WAYS-1:0],
    output wire [PRIORITY_BITS-1:0]             priority_set                [WAYS-1:0],
    output wire [SRRIP_BITS-1:0]                srrip_set                   [WAYS-1:0]
);

wire [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_write_data [WAYS-1:0];
wire [WAYS-1:0] eviction_meta_info_bank_sel;
wire eviction_meta_info_write_en;
wire eviction_meta_info_read_en;
assign eviction_meta_info_read_en  = is_new_request_fetch | is_new_request_read | is_new_request_consume | is_new_request_write;
assign  eviction_meta_info_write_en = (is_state_fetch) | (is_state_read) | (is_state_write);

genvar gen_i, gen_k;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin:valid_ways_blk
        for (gen_k = 0; gen_k < SETS; gen_k++) begin:valid_sets_blk
        srambank
                #(
                    .ADDRESS($clog2(SETS)),
                    .DATA(SRRIP_BITS+PRIORITY_BITS)
                ) eviction_meta_info_array
                (
                    .i_clk(i_clk),
                    .i_address(cur_set),
                    .i_write_data(eviction_meta_info_write_data[gen_i]),
                    .i_bank_sel(eviction_meta_info_bank_sel[gen_i]),
                    .i_read_en(eviction_meta_info_read_en),
                    .i_write_en(eviction_meta_info_write_en),
                    .o_data_out({priority_set[gen_i], srrip_set[gen_i]})
                );
        end
    end
endgenerate



generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign eviction_meta_info_bank_sel[gen_i]  = is_new_request_fetch      | (is_state_fetch)
                                          | is_new_request_read     | (is_state_read)
                                          | is_new_request_consume  | (is_state_consume)
                                          | is_new_request_write    | (is_state_write);
    end
endgenerate

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign eviction_meta_info_write_data[gen_i] = {new_priority_set[gen_i], new_srrip_set[gen_i]};
    end
endgenerate

endmodule
