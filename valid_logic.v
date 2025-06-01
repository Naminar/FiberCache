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

wire [SETS-1:0][WAYS-1:0] valid_bits_set;

genvar gen_i, gen_k;

assign cur_valid_bits_line = valid_bits_set[cur_set];

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        for (gen_k = 0; gen_k < SETS; gen_k++) begin
            single_srambank
                #(
                    .DATA(1)
                )
                valid_bits_array
                (
                    .i_clk(i_clk),
                    .i_write_data(valid_bits_write_data[gen_k][gen_i]),
                    .i_bank_sel(1'b1),
                    .i_read_en(valid_bits_read_en[gen_k][gen_i]),
                    .i_write_en(valid_bits_write_en[gen_k][gen_i]),
                    .o_data_out(valid_bits_set[gen_k][gen_i])
                );
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


//=============================================================================
// Module: valid_logic
// Description: Valid bits management logic for cache controller
//=============================================================================

// module valid_logic #(
//     parameter SETS  = 256,    // Number of sets in cache
//     parameter WAYS  = 16      // Number of ways in cache
// ) (
//     // Clock and reset
//     input  wire                i_clk,
//     input  wire                i_nreset,
    
//     // State indicators
//     input  wire                is_state_fetch,
//     input  wire                is_state_write,
//     input  wire                is_state_consume,
    
//     // Request indicators
//     input  wire                is_new_request_fetch,
//     input  wire                is_new_request_read, 
//     input  wire                is_new_request_write,
//     input  wire                is_new_request_consume,
    
//     // Cache operation status
//     input  wire                hit,
//     input  wire                miss,
    
//     // Current operation info
//     input  wire [$clog2(SETS)-1:0] cur_set,
//     input  wire [WAYS-1:0]         hit_i,
//     input  wire [WAYS-1:0]         victim_indicator_i,
    
//     // Outputs
//     output wire [WAYS-1:0]         cur_valid_bits_line
// );

//     //=========================================================================
//     // Internal signals
//     //=========================================================================
    
//     // Valid bits memory control signals
//     wire [SETS-1:0][WAYS-1:0] valid_bits_read_en;
//     wire [SETS-1:0][WAYS-1:0] valid_bits_write_en;
//     wire [SETS-1:0][WAYS-1:0] valid_bits_write_data;
    
//     // Valid bits storage
//     wire [SETS-1:0][WAYS-1:0] valid_bits_set;
    
//     // Write selection logic
//     wire [WAYS-1:0] where_to_write_while_write_stage;

//     //=========================================================================
//     // Continuous assignments
//     //=========================================================================
    
//     // Current valid bits output
//     assign cur_valid_bits_line = valid_bits_set[cur_set];
    
//     // Write selection logic
//     assign where_to_write_while_write_stage = hit ? hit_i : victim_indicator_i;

//     //=========================================================================
//     // Valid bits memory array instantiation
//     //=========================================================================
    
//     genvar gen_i, gen_k;
    
//     generate
//         for (gen_i = 0; gen_i < WAYS; gen_i++) begin : way_loop
//             for (gen_k = 0; gen_k < SETS; gen_k++) begin : set_loop
//                 single_srambank #(
//                     .DATA(1)
//                 ) valid_bits_array (
//                     .i_clk        (i_clk),
//                     .i_write_data (valid_bits_write_data[gen_k][gen_i]),
//                     .i_bank_sel   (1'b1),
//                     .i_read_en    (valid_bits_read_en[gen_k][gen_i]),
//                     .i_write_en   (valid_bits_write_en[gen_k][gen_i]),
//                     .o_data_out   (valid_bits_set[gen_k][gen_i])
//                 );
//             end
//         end
//     endgenerate

//     //=========================================================================
//     // Control logic generation
//     //=========================================================================
    
//     generate
//         for (gen_k = 0; gen_k < SETS; gen_k++) begin : set_ctrl_loop
//             for (gen_i = 0; gen_i < WAYS; gen_i++) begin : way_ctrl_loop
//                 // Read enable logic
//                 assign valid_bits_read_en[gen_k][gen_i] = 
//                     (cur_set == gen_k) & 
//                     (is_new_request_fetch | is_new_request_read | 
//                      is_new_request_consume | is_new_request_write);
                
//                 // Write enable logic
//                 assign valid_bits_write_en[gen_k][gen_i] = 
//                     ~i_nreset | 
//                     ((cur_set == gen_k) & 
//                      ((miss & is_state_fetch & victim_indicator_i[gen_i]) | 
//                       (is_state_consume & hit_i[gen_i]) | 
//                       (is_state_write & where_to_write_while_write_stage[gen_i])));
                
//                 // Write data logic
//                 assign valid_bits_write_data[gen_k][gen_i] = 
//                     1'b1 & i_nreset & ~(is_state_consume & hit_i[gen_i]);
//             end
//         end
//     endgenerate

// endmodule