
module priority_update_logic #(
    WAYS=16,
    PRIORITY_BITS=5
) (
    input wire is_state_fetch,
    input wire is_state_read,
    input wire miss,
    input wire [WAYS-1:0] hit_i,
    input wire [WAYS-1:0] victim_indicator_i,

    output reg [WAYS-1:0] [PRIORITY_BITS-1:0] new_priority_set    ,
    input wire [WAYS-1:0] [PRIORITY_BITS-1:0] priority_set 
);
    always @(*) begin
    for (int i = 0; i < WAYS; i++)
        if (hit_i[i]) begin
            // CAUTION
            if (is_state_fetch)
                new_priority_set[i] = priority_set[i] + 1;
            else if (is_state_read)
                new_priority_set[i] = priority_set[i] - 1;
            // else if (state == WRITE_REQ)
            //     new_priority_set[i] = {{PRIORITY_BITS-1{1'b0}}, 1'b1};
            else
                new_priority_set[i] = priority_set[i];
        end
        // else if (miss & victim_indicator_i[i] & (state == FETCH_REQ | state == WRITE_REQ)) begin
        else if (miss & victim_indicator_i[i] & is_state_fetch) begin
        // else if (victim_indicator_i[i]) begin
            new_priority_set[i] = {{PRIORITY_BITS-1{1'b0}}, 1'b1};
            // if (state == WRITE_REQ & miss)
            //     new_priority_set[i] = {PRIORITY_BITS{~victim_indicator_i[i]}};
            // else
                // new_priority_set[i] = priority_set[i];
        end else
            new_priority_set[i] = priority_set[i];
end
endmodule
