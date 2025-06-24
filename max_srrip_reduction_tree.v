module max_srrip_reduction_tree #(
    WAYS = 16,
    SRRIP_BITS = 3
) (
    input wire [WAYS-1:0] [SRRIP_BITS-1:0] srrip_set,
    input wire [WAYS-1:0] min_indicator,
    output wire [SRRIP_BITS-1:0] max_srrip
);
    /* verilator lint_off UNOPTFLAT */
    wire [$clog2(WAYS):0] [WAYS-1:0] [SRRIP_BITS-1:0] max_tree;
    /* verilator lint_on UNOPTFLAT */
    generate
        genvar i;
        for (i = 0; i < WAYS; i++) begin : init_level
            assign max_tree[0][i] = (min_indicator[i] == 1'b1) ? srrip_set[i] : {SRRIP_BITS{1'b0}};
        end
    endgenerate

    generate
        genvar level, j;
        for (level = 0; level < $clog2(WAYS); level++) begin : max_levels
            for (j = 0; j < (WAYS >> (level + 1)); j++) begin : compare_pairs
                assign max_tree[level+1][j] = (max_tree[level][2*j] > max_tree[level][2*j+1])
                                            ? max_tree[level][2*j] : max_tree[level][2*j+1];
            end
        end
    endgenerate

    assign max_srrip = max_tree[$clog2(WAYS)][0];

endmodule
