module fiberBank #(
    DATA_WIDTH=16, // double + 2 * i32
    SETS=256,
    WAYS=16,
    ADDR_WIDTH = 64, // 64 bit address
    SRRIP_BITS=2,
    PRIORITY_BITS=5
) (

    input i_clk,
    input i_nreset,

    //////////////////// PE CROSS BAR ////////////////////

    // request type
    input   wire    [3:0] i_request_type,
    input   wire    [ADDR_WIDTH-1:0] i_addr,
    input   wire    i_type_valid,
    output  wire    o_type_ready,

    // insert requests ports
    input   wire    [DATA_WIDTH-1:0] i_data,
    input   wire    i_data_i_valid,
    output  wire    o_data_i_ready,

    // read requests ports
    output  wire    [DATA_WIDTH-1:0] o_data_o,
    output  wire    o_data_o_valid,
    input   wire    i_data_o_ready,

    //////////////////// DRAM CROSS BAR ////////////////////
    output   reg    [ADDR_WIDTH-1:0] o_dram_addr,

    // inbox requests ports
    input   wire    [DATA_WIDTH-1:0] i_dram_data,
    input   wire    i_dram_data_i_valid,
    output  reg     o_dram_data_i_ready,

    // outbox requests ports
    output  wire    [DATA_WIDTH-1:0] o_dram_data_o,
    output  reg     o_dram_data_o_valid,
    input   wire    i_dram_data_o_ready
);

localparam FETCH_REQ    = 4'b0001;
localparam READ_REQ     = 4'b0010;
localparam WRITE_REQ    = 4'b0100;
localparam CONSUME_REQ  = 4'b1000;

localparam NONE             = 4'b0000;
localparam S_BUSY           = 4'b0001;
localparam S_WAIT_DRAM      = 4'b0010;
localparam S_WAIT_DRAM_R    = 4'b1000;
localparam S_INSERT         = 4'b0100;

//-----------------------------------------------------------
//|    |   bank     |     256 sets      | 16 bytes in line  |
//-----------------------------------------------------------
//|tag array (64-12)|      8 bits       |       4 bits      |
//-----------------------------------------------------------

//=============================================================================
wire [$clog2(SETS)-1:0] cur_set = i_addr[$clog2(DATA_WIDTH) +: $clog2(SETS)];
wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] cur_tag = i_addr[ADDR_WIDTH-1:$clog2(DATA_WIDTH)+$clog2(SETS)];
wire [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_set [WAYS-1:0];

wire [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_set      [WAYS-1:0];
wire                                dirty_bits_set              [WAYS-1:0];
reg [PRIORITY_BITS-1:0]             priority_set                [WAYS-1:0];
reg [SRRIP_BITS-1:0]                srrip_set                   [WAYS-1:0];


reg [DATA_WIDTH-1:0] data_write_data;
reg data_bank_sel [WAYS-1:0];
reg data_read_en;
reg data_write_en;
reg [DATA_WIDTH-1:0] data_set [WAYS-1:0];

reg [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_write_data;
reg tag_bank_sel [WAYS-1:0];
reg tag_read_en;
wire tag_write_en;

reg dirty_bits_write_data;
reg dirty_bits_bank_sel [WAYS-1:0];
reg dirty_bits_read_en;
reg dirty_bits_write_en;

reg [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_write_data [WAYS-1:0];
reg eviction_meta_info_bank_sel [WAYS-1:0];
reg eviction_meta_info_read_en;
reg eviction_meta_info_write_en;

wire valid_bits_field        [SETS-1:0][WAYS-1:0];
reg  valid_bits_sel          [SETS-1:0][WAYS-1:0];
reg  valid_bits_read_en      [SETS-1:0][WAYS-1:0];
reg  valid_bits_write_en     [SETS-1:0][WAYS-1:0];
wire valid_bits_write_data   [SETS-1:0][WAYS-1:0];
//=============================================================================

genvar i, k;
generate
    for (i = 0; i < WAYS; i++) begin:sets_blk
        srambank
                #(
                    .ADDRESS($clog2(SETS)),
                    .DATA(DATA_WIDTH)
                ) data_array
                (
                    .i_clk(i_clk),
                    .i_address(cur_set),
                    .i_write_data(data_write_data),
                    .i_bank_sel(data_bank_sel[i]),
                    .i_read_en(data_read_en),
                    .i_write_en(data_write_en),
                    .o_data_out(data_set[i])
                );

        srambank
                #(
                    .ADDRESS($clog2(SETS)),
                    .DATA(ADDR_WIDTH-$clog2(SETS)-$clog2(DATA_WIDTH))
                ) tag_array
                (
                    .i_clk(i_clk),
                    .i_address(cur_set),
                    .i_write_data(tag_write_data),
                    .i_bank_sel(tag_bank_sel[i]),
                    .i_read_en(tag_read_en),
                    .i_write_en(tag_write_en),
                    .o_data_out(tag_set[i])
                );

        srambank
                #(
                    .ADDRESS($clog2(SETS)),
                    .DATA(1)
                ) dirty_bits_array
                (
                    .i_clk(i_clk),
                    .i_address(cur_set),
                    .i_write_data(dirty_bits_write_data),
                    .i_bank_sel(dirty_bits_bank_sel[i]),
                    .i_read_en(dirty_bits_read_en),
                    .i_write_en(dirty_bits_write_en),
                    .o_data_out(dirty_bits_set[i])
                );


        srambank
                #(
                    .ADDRESS($clog2(SETS)),
                    .DATA(SRRIP_BITS+PRIORITY_BITS)
                ) eviction_meta_info_array
                (
                    .i_clk(i_clk),
                    .i_address(cur_set),
                    .i_write_data(eviction_meta_info_write_data[i]),
                    .i_bank_sel(eviction_meta_info_bank_sel[i]),
                    .i_read_en(eviction_meta_info_read_en),
                    .i_write_en(eviction_meta_info_write_en),
                    // .o_data_out(eviction_meta_info_set[i])
                    .o_data_out({priority_set[i], srrip_set[i]})
                );
    end

    for (i = 0; i < WAYS; i++) begin:valid_ways_blk
        for (k = 0; k < SETS; k++) begin:valid_sets_blk
            single_srambank
                #(
                    .DATA(1)
                )
                valid_bits_array
                (
                    .i_clk(i_clk),
                    .i_write_data(valid_bits_write_data[k][i]),
                    .i_bank_sel(valid_bits_sel[k][i]),
                    .i_read_en(valid_bits_read_en[k][i]),
                    .i_write_en(valid_bits_write_en[k][i]),
                    .o_data_out(valid_bits_field[k][i])
                );
        end
    end
endgenerate

reg i_nreset_d;
reg [3:0] i_request_type_d;
reg [ADDR_WIDTH-1:0] i_addr_d;
reg i_type_valid_d;
// reg i_data_d;
// reg i_data_i_valid_d;
// reg i_data_o_ready_d;

reg [3:0] state;

always @(posedge i_clk) begin
    i_nreset_d <= i_nreset;
    i_request_type_d <= i_request_type;
    i_addr_d <= i_addr;
    i_type_valid_d <= i_type_valid;
    // i_data_d <= i_data;
    // i_data_i_valid_d <= i_data_i_valid;
end


wire [3:0] new_request = i_request_type_d & ({4{i_type_valid_d}} & {4{o_type_ready}});

always @(posedge i_clk) begin
    if (~|state)
        state <= new_request;
end

wire is_new_request_fetch = new_request == FETCH_REQ;
always @(*) begin
    for (int i = 0; i < WAYS; i++) begin
        tag_bank_sel[i] = is_new_request_fetch | (state == FETCH_REQ & victim_indicator_i[i]);
        // anyway update even if there's no dirty victim
        eviction_meta_info_bank_sel[i] = is_new_request_fetch | (state == FETCH_REQ);
        dirty_bits_bank_sel[i] = is_new_request_fetch | (state == FETCH_REQ & victim_indicator_i[i]);
        // It's updated after data would be received
        data_bank_sel[i] = is_new_request_fetch;

        eviction_meta_info_write_data[i] = {new_priority_set[i], new_srrip_set[i]};
    end

    tag_read_en = is_new_request_fetch;
    eviction_meta_info_read_en = is_new_request_fetch;
    dirty_bits_read_en = is_new_request_fetch;
    data_read_en = is_new_request_fetch;

    for (int i = 0; i < WAYS; i++)
        for (int k = 0; k < SETS; k++) begin
            // valid_bits_read_en[k][i] = (k == cur_set) & is_new_request_fetch;
            valid_bits_read_en[k][i] = 1'b0;
            valid_bits_write_en[k][i] = 1'b0;

            valid_bits_write_data[k][i] = 1'b1;
            // TODO: enable bank!!!!
        end

    for (int i = 0; i < WAYS; i++) begin
        valid_bits_read_en[cur_set][i] = is_new_request_fetch;
        valid_bits_write_en[cur_set][i] = victim_indicator_i[i];
        // TODO: | (state == FETCH_REQ & is_victim_dirty)
    end

    tag_write_en = state == FETCH_REQ;
    dirty_bits_write_en = state == FETCH_REQ;

    tag_write_data = cur_tag;
    dirty_bits_write_data = 1'b0;

end

reg [WAYS-1:0] hit_i;
reg hit;
reg [PRIORITY_BITS-1:0] new_priority_set [WAYS-1:0];
reg [SRRIP_BITS-1:0] new_srrip_set_inc [WAYS-1:0];
reg [SRRIP_BITS-1:0] new_srrip_set_hit [WAYS-1:0];
reg [SRRIP_BITS-1:0] new_srrip_set_miss [WAYS-1:0];
reg [SRRIP_BITS-1:0] new_srrip_set [WAYS-1:0];
// new_priority_set for eviction should be updated as srrip in miss case!!!!
// but which one to chose???
always @(*) begin
    for (int i = 0; i < WAYS; i++)
        hit_i[i] = cur_tag == tag_set[i];
    hit = |hit_i;

    for (int i = 0; i < WAYS; i++)
        if (hit_i)
            new_priority_set = priority_set[i] + 1;
        else
            new_priority_set = priority_set[i];
end

always @(*) begin
    for (int i = 0; i < WAYS; i++) begin
        if (srrip_set[i] == {SRRIP_BITS{1'b1}})
            new_srrip_set_inc[i] = srrip_set[i];
        else
            new_srrip_set_inc[i] = srrip_set[i] + 1;

        new_srrip_set_hit[i] = new_srrip_set_inc[i] & {SRRIP_BITS{~hit_i[i]}};
    end
end

reg [PRIORITY_BITS-1:0] min_priority;
reg [WAYS-1:0] min_indicator;
reg [SRRIP_BITS-1:0] max_srrip;
reg [WAYS-1:0] max_srrip_indicator;

always @(*) begin
    min_priority = {PRIORITY_BITS{1'b1}};
    for (int i = 0; i < WAYS; i++) begin
        if (priority_set[i] < min_priority)
            min_priority = priority_set[i];
    end

    for (int i = 0; i < WAYS; i++) begin
        if (priority_set[i] == min_priority)
            min_indicator[i] = 1'b1;
        else
            min_indicator[i] = 1'b0;
    end

    max_srrip = {SRRIP_BITS{1'b0}};
    for (int i = 0; i < WAYS; i++) begin
        if ((srrip_set[i] > max_srrip) & min_indicator[i] == 1'b1)
            max_srrip = srrip_set[i];
    end

    for (int i = 0; i < WAYS; i++) begin
        if ((srrip_set[i] == max_srrip) & min_indicator[i] == 1'b1)
            max_srrip_indicator[i] = 1'b1;
        else
            max_srrip_indicator[i] = 1'b0;
    end
end

always @(*) begin
    for (int i = 0; i < WAYS; i++) begin
        if (max_srrip_indicator[i])
            new_srrip_set_miss[i] = {SRRIP_BITS-1{1'b1}, 1'b0};
        else
            new_srrip_set_miss[i] = new_srrip_set_inc[i];
    end
end

always @(*) begin
    for (int i = 0; i < WAYS; i++)
        if (hit)
            new_srrip_set[i] = new_srrip_set_hit[i];
        else
            new_srrip_set[i] = new_srrip_set_miss[i];
end

reg is_victim_dirty;
reg [WAYS-1:0] is_victim_dirty_i;
reg [WAYS-1:0] victim_indicator_i;
always @(*) begin
    for (int i = 0; i < WAYS; i++)
        victim_indicator_i[i] = miss & max_srrip_indicator[i];

    for (int i = 0; i < WAYS; i++)
        is_victim_dirty_i[i] = victim_indicator_i[i] & dirty_bits_set[i]
    is_victim_dirty = |is_victim_dirty_i;
end
endmodule