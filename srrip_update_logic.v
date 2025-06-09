module srrip_update_logic #(
    WAYS=16,
    SRRIP_BITS=2
) (
    input wire hit,
    input wire [WAYS-1:0]   hit_i,
    input wire [WAYS-1:0]   victim_indicator_i,
    input wire [WAYS-1:0]   [SRRIP_BITS-1:0]  srrip_set,

    output wire [WAYS-1:0]  [SRRIP_BITS-1:0] new_srrip_set
);

wire [WAYS-1:0] [SRRIP_BITS-1:0]    new_srrip_set_inc;
wire [WAYS-1:0] [SRRIP_BITS-1:0]    new_srrip_set_hit;
wire [WAYS-1:0] [SRRIP_BITS-1:0]    new_srrip_set_miss;

genvar gen_i;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign new_srrip_set_inc[gen_i] = (srrip_set[gen_i] == {SRRIP_BITS{1'b1}})? 
                                                srrip_set[gen_i]
                                            : 
                                                srrip_set[gen_i] + 1;
        
        assign new_srrip_set_hit[gen_i] = new_srrip_set_inc[gen_i] 
                                            & {SRRIP_BITS{~hit_i[gen_i]}};
        
        assign new_srrip_set_miss[gen_i] = (victim_indicator_i[gen_i])? 
                                                {{SRRIP_BITS-1{1'b1}}, 1'b0}
                                             : 
                                                new_srrip_set_inc[gen_i];
        
        assign new_srrip_set[gen_i] = (hit)? 
                                            new_srrip_set_hit[gen_i]
                                        : 
                                            new_srrip_set_miss[gen_i];
    end
endgenerate

endmodule
