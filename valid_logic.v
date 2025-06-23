module valid_logic #(
    // DATA_WIDTH=16, // double + 2 * i32
    SETS=256,
    WAYS=16
    // ADDR_WIDTH = 64 // 64 bit address
    // SRRIP_BITS=2,
    // PRIORITY_BITS=5
) (
    input wire i_clk,
    input wire i_nreset,
    input wire is_state_fetch,
    input wire is_state_write,
    input wire is_state_consume,
    input wire is_new_request_fetch,
    input wire is_new_request_read, 
    input wire is_new_request_write,
    input wire is_new_request_consume,
    
    input wire hit,
    input wire miss,
    input wire [$clog2(SETS)-1:0] cur_set,
    input wire [WAYS-1:0] hit_i,
    input wire [WAYS-1:0] victim_indicator_i,
    output wire [WAYS-1:0] cur_valid_bits_line

);

wire  [SETS-1:0][WAYS-1:0] valid_bits_read_en        ;
wire  [SETS-1:0][WAYS-1:0] valid_bits_write_en       ;
wire  [SETS-1:0][WAYS-1:0] valid_bits_write_data     ;
wire [WAYS-1:0] where_to_write_while_write_stage;

reg [SETS-1:0][WAYS-1:0] valid_bits_set;

genvar gen_i, gen_k;

assign cur_valid_bits_line = valid_bits_set[cur_set];

reg [SETS-1:0] [WAYS-1:0] mem;

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        for (gen_k = 0; gen_k < SETS; gen_k++) begin
            always @(posedge i_clk) begin
                if (valid_bits_write_en[gen_k][gen_i]) begin
                    mem[gen_k][gen_i] <= valid_bits_write_data[gen_k][gen_i];
                end
                else if (valid_bits_read_en[gen_k][gen_i]) begin
                    valid_bits_set[gen_k][gen_i] <= mem[gen_k][gen_i];
                end
            end
        end
    end
endgenerate

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++)
        assign where_to_write_while_write_stage[gen_i] = (hit)? hit_i[gen_i]: victim_indicator_i[gen_i];
endgenerate

generate
    for (gen_k = 0; gen_k < SETS; gen_k++) begin
        for (gen_i = 0; gen_i < WAYS; gen_i++) begin
            assign valid_bits_read_en[gen_k][gen_i] = (cur_set == gen_k) & (is_new_request_fetch | is_new_request_read | is_new_request_consume | is_new_request_write);
            assign valid_bits_write_en[gen_k][gen_i] = ~i_nreset | ((cur_set == gen_k) & ((miss & is_state_fetch & victim_indicator_i[gen_i]) | (is_state_consume & hit_i[gen_i]) | (is_state_write & where_to_write_while_write_stage[gen_i])));
            assign valid_bits_write_data[gen_k][gen_i] = 1'b1 & i_nreset & ~(is_state_consume & hit_i[gen_i]);
        end
    end
endgenerate

endmodule
