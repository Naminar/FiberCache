module dirty_logic #(
    SETS=256,
    WAYS=16
) (
    input wire i_clk,
    input wire is_state_fetch,
    input wire is_state_write,
    input wire is_new_request_fetch,
    input wire is_new_request_write,
    
    input wire hit,
    input wire miss,
    input wire [$clog2(SETS)-1:0] cur_set,
    input wire [WAYS-1:0] hit_i,
    input wire [WAYS-1:0] victim_indicator_i,
    output wire [WAYS-1:0] dirty_bits_set,
    output wire [WAYS-1:0] where_to_write_while_write_stage
);

wire [WAYS-1:0] dirty_bits_bank_sel;
wire dirty_bits_read_en;
wire dirty_bits_write_en;
wire dirty_bits_write_data;

assign dirty_bits_read_en          = is_new_request_fetch | is_new_request_write;
assign  dirty_bits_write_en = (miss & is_state_fetch) | (is_state_write);
assign dirty_bits_write_data = is_state_write;

genvar gen_i;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
            srambank
                    #(
                        .ADDRESS($clog2(SETS)),
                        .DATA(1)
                    ) dirty_bits_array
                    (
                        .i_clk(i_clk),
                        .i_address(cur_set),
                        .i_write_data(dirty_bits_write_data),
                        .i_bank_sel(dirty_bits_bank_sel[gen_i]),
                        .i_read_en(dirty_bits_read_en),
                        .i_write_en(dirty_bits_write_en),
                        .o_data_out(dirty_bits_set[gen_i])
                    );
    end
endgenerate



generate
    for (gen_i = 0; gen_i < WAYS; gen_i++)
        assign where_to_write_while_write_stage[gen_i] = (hit)? hit_i[gen_i]: victim_indicator_i[gen_i];
endgenerate

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign dirty_bits_bank_sel[gen_i]   = is_new_request_fetch | (miss & is_state_fetch & victim_indicator_i[gen_i])
                                          | is_new_request_write | (is_state_write & where_to_write_while_write_stage[gen_i]);
    end
endgenerate

endmodule
