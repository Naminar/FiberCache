module priority_update_logic #(
    parameter WAYS = 16,
    parameter PRIORITY_BITS = 5
) (
    input wire is_state_fetch,
    input wire is_state_read,

    input wire miss,
    input wire [WAYS-1:0] hit_i,
    input wire [WAYS-1:0] victim_indicator_i,
    input wire [WAYS-1:0] [PRIORITY_BITS-1:0] priority_set,

    output wire [WAYS-1:0] [PRIORITY_BITS-1:0] new_priority_set
);

generate
    genvar i;
    for (i = 0; i < WAYS; i = i + 1) begin : gen_priority_update
        assign new_priority_set[i] = hit_i[i] ?
                                        (is_state_fetch ? (priority_set[i] + PRIORITY_BITS'(1)) :
                                         is_state_read  ? (priority_set[i] - PRIORITY_BITS'(1)) :
                                                          priority_set[i]) :
                                     (miss & victim_indicator_i[i] & is_state_fetch) ?
                                        {{PRIORITY_BITS-1{1'b0}}, 1'b1} :
                                        priority_set[i];
    end
endgenerate

endmodule