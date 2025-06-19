module data_logic #(
    BIT_SIZE=8,
    DATA_WIDTH=16,
    SETS=256,
    WAYS=16
) (
    input wire  i_clk,
    input wire  is_state_write,
    input wire  is_new_request_fetch,
    input wire  is_new_request_read,
    input wire  is_new_request_write,
    input wire  is_new_request_consume,
    input wire  is_internal_state_receive_data,

    input wire  [$clog2(SETS)-1:0]   cur_set,
    input wire  [WAYS-1:0]           insert_data_handler,
    input wire  [WAYS-1:0]           where_to_write_while_write_stage,

    input  wire i_dram_data_i_valid,
    input  wire o_dram_data_i_ready,

    input wire  [DATA_WIDTH*BIT_SIZE-1:0]    internal_data,
    input wire  [DATA_WIDTH*BIT_SIZE-1:0]    i_dram_data,

    output wire [WAYS-1:0] [DATA_WIDTH*BIT_SIZE-1:0] data_set
);

wire data_read_en                       = is_new_request_fetch | is_new_request_read | is_new_request_consume | is_new_request_write;
wire data_write_en                      = (i_dram_data_i_valid & o_dram_data_i_ready) | (is_state_write);

wire [DATA_WIDTH*BIT_SIZE-1:0] data_write_data   = (is_internal_state_receive_data)?
                                                i_dram_data
                                            :
                                                internal_data;

wire [WAYS-1:0] data_bank_sel;
genvar gen_i;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign data_bank_sel[gen_i]         =   is_new_request_fetch | (i_dram_data_i_valid & o_dram_data_i_ready & insert_data_handler[gen_i])
                                                | is_new_request_read
                                                | is_new_request_consume
                                                | is_new_request_write | (is_state_write & where_to_write_while_write_stage[gen_i]);
    end
endgenerate

generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        // srambank #(
        //     .ADDRESS($clog2(SETS)),
        //     .DATA(DATA_WIDTH*BIT_SIZE)
        // ) data_array (
        //     .i_clk(i_clk),
        //     .i_address(cur_set),
        //     .i_write_data(data_write_data),
        //     .i_bank_sel(data_bank_sel[gen_i]),
        //     .i_read_en(data_read_en),
        //     .i_write_en(data_write_en),
        //     .o_data_out(data_set[gen_i])
        // );
        fakeram7_128x256_data_logic data_array (
            .rd_out(data_set[gen_i]),
            .addr_in(cur_set),
            .we_in(data_write_en),
            // CAUTION: sram cell do not properly work
            .wd_in(data_write_data),
            .clk(i_clk),
            .ce_in((data_write_en | data_read_en) & data_bank_sel[gen_i])
        );
    end
endgenerate

endmodule
