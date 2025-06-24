module reduction_tree #(
    WAYS=16,
    PRIORITY_BITS=5
) (

input wire [WAYS-1:0] [PRIORITY_BITS-1:0] priority_set,
output wire [PRIORITY_BITS-1:0] min_priority
);
/* verilator lint_off UNOPTFLAT */
wire [$clog2(WAYS):0] [WAYS-1:0] [PRIORITY_BITS-1:0] min_tree;
/* verilator lint_on UNOPTFLAT */
generate
    genvar i;
    for (i = 0; i < WAYS; i++) begin : init_level
        assign min_tree[0][i] = priority_set[i];
    end
endgenerate

generate
    genvar level, j;
    for (level = 0; level < $clog2(WAYS); level++) begin : min_levels
        for (j = 0; j < (WAYS >> (level + 1)); j++) begin : compare_pairs
            assign min_tree[level+1][j] = (min_tree[level][2*j] < min_tree[level][2*j+1])
                                        ? min_tree[level][2*j] : min_tree[level][2*j+1];
        end
    end
endgenerate

assign min_priority = min_tree[$clog2(WAYS)][0];

endmodule
