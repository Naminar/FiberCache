module emi_update #(
    WAYS=16,
    SRRIP_BITS=2,
    PRIORITY_BITS=5
) (

    input wire [WAYS-1:0]                       dirty_bits_set,
    input wire [WAYS-1:0]                       cur_valid_bits_line,
    
    input wire [WAYS-1:0] [SRRIP_BITS-1:0]      srrip_set,
    input wire [WAYS-1:0] [PRIORITY_BITS-1:0]   priority_set,
    
    output wire             is_victim_dirty,
    output wire [WAYS-1:0]  victim_indicator_i
);
wire    [WAYS-1:0]          min_indicator;
wire    [WAYS-1:0]          max_srrip_indicator;
wire    [WAYS-1:0] is_victim_dirty_i;
reg     [PRIORITY_BITS-1:0] min_priority;
reg     [SRRIP_BITS-1:0]    max_srrip;
reg     [WAYS-1:0]          invalid_bits_line;

wire    is_smth_invalid = |invalid_bits_line;
assign  is_victim_dirty = |is_victim_dirty_i;

always @(*) begin
    min_priority = {PRIORITY_BITS{1'b1}};
    for (int i = 0; i < WAYS; i++) begin
        if (priority_set[i] < min_priority)
            min_priority = priority_set[i];
    end
end

always @(*) begin
    max_srrip = {SRRIP_BITS{1'b0}};
    for (int i = 0; i < WAYS; i++) begin
        if ((srrip_set[i] > max_srrip) & min_indicator[i] == 1'b1)
            max_srrip = srrip_set[i];
    end
end

genvar gen_i;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign max_srrip_indicator[gen_i] = ((srrip_set[gen_i] == max_srrip) & min_indicator[gen_i] == 1'b1);
        assign min_indicator[gen_i] = (priority_set[gen_i] == min_priority);
    end
endgenerate

int first_invalid;
always @(*) begin
    first_invalid = 0;
    for (int i = 0; i < WAYS; i++) begin
        invalid_bits_line[i] = ~cur_valid_bits_line[i];
        if (invalid_bits_line[i] && first_invalid == 0)
            first_invalid = i + 1;
    end
end

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign victim_indicator_i[gen_i] = (is_smth_invalid)? (gen_i == (first_invalid-1)): (max_srrip_indicator[gen_i]);
        assign is_victim_dirty_i[gen_i] = victim_indicator_i[gen_i] & dirty_bits_set[gen_i] & cur_valid_bits_line[gen_i];
    end
endgenerate

endmodule
