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
    input   wire    [3:0]               i_request_type,
    input   wire    [ADDR_WIDTH-1:0]    i_addr,
    input   wire                        i_type_valid,
    output  wire                        o_type_ready,

    // insert requests ports
    input   wire    [DATA_WIDTH-1:0]    i_data,

    // read requests ports
    output  reg     [DATA_WIDTH-1:0]    o_pe_data_o,
    output  reg                         o_pe_data_o_valid,
    input   wire                        i_pe_data_o_ready,

    //////////////////// DRAM CROSS BAR ////////////////////
    output   reg    [ADDR_WIDTH-1:0]    o_dram_addr,

    // inbox requests ports
    input   wire    [DATA_WIDTH-1:0]    i_dram_data,
    input   wire                        i_dram_data_i_valid,
    output  wire                        o_dram_data_i_ready,

    // outbox requests ports
    output  reg    [DATA_WIDTH-1:0]     o_dram_data_o,
    output  wire                        o_dram_data_o_valid,
    input   wire                        i_dram_data_o_ready
);

localparam FETCH_REQ    = 4'b0001;
localparam READ_REQ     = 4'b0010;
localparam WRITE_REQ    = 4'b0100;
localparam CONSUME_REQ  = 4'b1000;

localparam SEND_DIRTY_VICTIM        = 4'b0001;
localparam RECEIVE_DATA             = 4'b0010;
localparam SEND_TO_PE               = 4'b0100;
localparam ONLY_SEND_DIRTY_VICTIM   = 4'b1000;

localparam NONE                     = 4'b0000;

//-----------------------------------------------------------
//|    |   bank     |     256 sets      | 16 bytes in line  |
//-----------------------------------------------------------
//|tag array (64-12)|      8 bits       |       4 bits      |
//-----------------------------------------------------------
//|      [63:12]    |      [11:4]       |        [3:0]      |
//-----------------------------------------------------------
//=============================================================================
// wire [$clog2(SETS)-1:0] cur_set = i_addr_d[$clog2(DATA_WIDTH) +: $clog2(SETS)];
wire [$clog2(SETS)-1:0] cur_set = (|{state,internal_state})? internal_set: incoming_set;
wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] cur_tag = internal_addr[ADDR_WIDTH-1:$clog2(DATA_WIDTH)+$clog2(SETS)];
wire [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_set [WAYS-1:0];


reg [$clog2(SETS)-1:0] set_to_write;
wire [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_set      [WAYS-1:0];
wire                                dirty_bits_set              [WAYS-1:0];
reg [PRIORITY_BITS-1:0]             priority_set                [WAYS-1:0];
reg [SRRIP_BITS-1:0]                srrip_set                   [WAYS-1:0];


reg [DATA_WIDTH-1:0] data_write_data;
reg [WAYS-1:0] data_bank_sel;
reg data_read_en;
reg data_write_en;
reg [DATA_WIDTH-1:0] data_set [WAYS-1:0];

reg [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_write_data;
reg [WAYS-1:0] tag_bank_sel;
reg tag_read_en;
reg tag_write_en;

reg dirty_bits_write_data;
reg [WAYS-1:0] dirty_bits_bank_sel;
reg dirty_bits_read_en;
reg dirty_bits_write_en;

reg [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_write_data [WAYS-1:0];
reg [WAYS-1:0] eviction_meta_info_bank_sel;
reg eviction_meta_info_read_en;
reg eviction_meta_info_write_en;

wire valid_bits_set        [SETS-1:0][WAYS-1:0];
reg  valid_bits_sel          [SETS-1:0][WAYS-1:0];
reg  valid_bits_read_en      [SETS-1:0][WAYS-1:0];
reg  valid_bits_write_en     [SETS-1:0][WAYS-1:0];
reg  valid_bits_write_data   [SETS-1:0][WAYS-1:0];
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
                    .i_bank_sel(1'b1),
                    .i_read_en(valid_bits_read_en[k][i]),
                    .i_write_en(valid_bits_write_en[k][i]),
                    .o_data_out(valid_bits_set[k][i])
                );
        end
    end
endgenerate

wire [SETS-1:0][WAYS-1:0] dump_valid_bits_write_en;
wire [SETS-1:0][WAYS-1:0] dump_valid_bits_write_data;
wire [WAYS-1:0] dump_valid_bits_set;
wire [WAYS-1:0][SRRIP_BITS+PRIORITY_BITS-1:0] dump_eviction_meta_info_write_data;
wire [WAYS-1:0][SRRIP_BITS+PRIORITY_BITS-1:0] dump_old_eviction_meta_info;

// DEBUG GENERATE
generate
    for (genvar i = 0; i < SETS; i++) begin
        for (genvar j = 0; j < WAYS; j++) begin
            assign dump_valid_bits_write_en[i][j] = valid_bits_write_en[i][j];
            assign dump_valid_bits_write_data[i][j] = valid_bits_write_data[i][j];
        end
    end

    for (genvar i = 0; i < WAYS; i++) begin
        assign dump_valid_bits_set[i] = valid_bits_set[cur_set][i];
        assign dump_eviction_meta_info_write_data[i] = eviction_meta_info_write_data[i];
        assign dump_old_eviction_meta_info[i] = {priority_set[i], srrip_set[i]};
    end
endgenerate
// END DEBUG GENERATE

// reg [3:0] i_request_type_d;
// reg i_type_valid_d;
reg [ADDR_WIDTH-1:0]    internal_addr;

reg [3:0] state;
reg [3:0] internal_state;
reg [WAYS-1:0] insert_data_handler;
reg [DATA_WIDTH-1:0] internal_data;

always @(posedge i_clk) begin
    if (o_type_ready) begin
        internal_addr <= i_addr;
        internal_data <= i_data;
    end
end

assign o_type_ready = ~|state & ~|internal_state;

wire [3:0] nreset_line = {4{i_nreset}};

wire [3:0] new_request = i_request_type & ({4{i_type_valid & o_type_ready & i_nreset}});

always @(posedge i_clk) begin
    if (~i_nreset)
        state <= nreset_line;
    else if (~|state)
        state <= new_request;
    else
        state <= NONE;
end

assign o_pe_data_o_valid = internal_state == SEND_TO_PE;

always @(posedge i_clk) begin
    if (~i_nreset)
        internal_state <= NONE;
    else if (miss & is_victim_dirty & state == FETCH_REQ)
        internal_state <= SEND_DIRTY_VICTIM;
    else if (miss & is_victim_dirty & state == WRITE_REQ)
        internal_state <= ONLY_SEND_DIRTY_VICTIM;
    else if (miss & state == FETCH_REQ)
        internal_state <= RECEIVE_DATA;
    else if (i_pe_data_o_ready & o_pe_data_o_valid)
        internal_state <= NONE;
    else if (state == READ_REQ | state == CONSUME_REQ)
        internal_state <= SEND_TO_PE;
    else if (internal_state == SEND_DIRTY_VICTIM & i_dram_data_o_ready)
        internal_state <= RECEIVE_DATA;
    else if (internal_state == ONLY_SEND_DIRTY_VICTIM & i_dram_data_o_ready)
        internal_state <= NONE;
    else if (internal_state == RECEIVE_DATA & i_dram_data_i_valid)
        internal_state <= NONE;
end

reg [DATA_WIDTH-1:0] victim_data_i [WAYS-1:0];

reg [DATA_WIDTH-1:0] pe_data_comb;

always @(*) begin
    pe_data_comb = 0;
    for (int i = 0; i < WAYS; i++)
        pe_data_comb = pe_data_comb | (data_set[i] & {DATA_WIDTH{hit_i[i]}});
end

always @(posedge i_clk) begin
    if (state == READ_REQ | state == CONSUME_REQ) begin
        o_pe_data_o <= pe_data_comb;
    end
end

assign o_dram_data_o_valid = (internal_state == SEND_DIRTY_VICTIM) | (internal_state == ONLY_SEND_DIRTY_VICTIM);

assign o_dram_data_i_ready = internal_state == RECEIVE_DATA;

always @(posedge i_clk) begin
    // if (miss & (state == FETCH_REQ | state == WRITE_REQ))
    
    for (int i = 0; i < WAYS; i++)
        if (miss & state == FETCH_REQ)
            insert_data_handler[i] = victim_indicator_i[i];
        // else if (state == WRITE_REQ)
        //     if (miss)
        //         insert_data_handler[i] = victim_indicator_i[i];
        //     else if (hit)
        //         insert_data_handler[i] = hit_i[i];
end


reg [WAYS-1:0] where_to_write_while_write_stage;
always @(*) begin
    for (int i = 0; i < WAYS; i++)
        if (hit)
            where_to_write_while_write_stage[i] = hit_i[i];
        else
            where_to_write_while_write_stage[i] = victim_indicator_i[i];
end

wire is_new_request_fetch = new_request == FETCH_REQ;
wire is_new_request_read = new_request == READ_REQ;
wire is_new_request_write = new_request == WRITE_REQ;
wire is_new_request_consume = new_request == CONSUME_REQ;

always @(*) begin
    // for (int i = 0; i < WAYS; i++) begin
    //     tag_bank_sel[i] = is_new_request_fetch | is_new_request_read | is_new_request_write | is_new_request_consume | (state == WRITE_REQ & victim_indicator_i[i]) | (state == FETCH_REQ & victim_indicator_i[i]);
    //     // anyway update even if there's no dirty victim
    //     eviction_meta_info_bank_sel[i] = is_new_request_fetch | is_new_request_read | is_new_request_write | (state == WRITE_REQ & victim_indicator_i[i]) |(state == FETCH_REQ);
    //     // TODO: modify special for
    //     dirty_bits_bank_sel[i] = is_new_request_fetch | is_new_request_write | (state == WRITE_REQ & hit_i[i]) | (state == WRITE_REQ & victim_indicator_i[i]) | (state == FETCH_REQ & victim_indicator_i[i]);
    //     // It's updated after data would be received
    //     data_bank_sel[i] = is_new_request_fetch | is_new_request_read | is_new_request_write | is_new_request_consume | (state == WRITE_REQ & (hit_i[i] | victim_indicator_i[i])) | (internal_state == RECEIVE_DATA & victim_indicator_i[i]);

    //     eviction_meta_info_write_data[i] = {new_priority_set[i], new_srrip_set[i]};
    // end

    //////////////////// SEL PORTS SIGNING ////////////////////
    for (int i = 0; i < WAYS; i++) begin
        tag_bank_sel[i]                 = is_new_request_fetch | (miss & state == FETCH_REQ & victim_indicator_i[i])
                                          | is_new_request_read
                                          | is_new_request_consume
                                          | is_new_request_write | (miss & state == WRITE_REQ & victim_indicator_i[i]);
        data_bank_sel[i]                = is_new_request_fetch | (i_dram_data_i_valid & o_dram_data_i_ready & insert_data_handler[i])
                                          | is_new_request_read
                                          | is_new_request_consume
                                          | is_new_request_write | (state == WRITE_REQ & where_to_write_while_write_stage[i]);
        eviction_meta_info_bank_sel[i]  = is_new_request_fetch      | (state == FETCH_REQ)
                                          | is_new_request_read     | (state == READ_REQ)
                                          | is_new_request_consume  | (state == CONSUME_REQ)
                                          | is_new_request_write    | (state == WRITE_REQ);
        dirty_bits_bank_sel[i]          = is_new_request_fetch | (miss & state == FETCH_REQ & victim_indicator_i[i])
                                          | is_new_request_write | (state == WRITE_REQ & where_to_write_while_write_stage[i]);
    end
    //////////////////// END SEL PORTS SIGNING ////////////////////

    //////////////////// VALID BITS SIGNING ////////////////////
    for (int k = 0; k < SETS; k++) begin
        for (int i = 0; i < WAYS; i++) begin
            valid_bits_read_en[k][i] = 1'b0;
            valid_bits_write_en[k][i] = 1'b0 | ~i_nreset;
            
            // CAUTION (maybe need to be changed special for [cur_set][i])
            valid_bits_write_data[k][i] = 1'b1 & i_nreset & ~(state == CONSUME_REQ & hit_i[i]);
        end
    end

    for (int i = 0; i < WAYS; i++) begin
        valid_bits_read_en[cur_set][i] = is_new_request_fetch | is_new_request_read | is_new_request_consume | is_new_request_write; // | is_new_request_write  | is_new_request_consume;
        valid_bits_write_en[cur_set][i] = i_nreset & ((miss & state == FETCH_REQ & victim_indicator_i[i]) | (state == CONSUME_REQ & hit_i[i]) | (state == WRITE_REQ & where_to_write_while_write_stage[i])); //(victim_indicator_i[i] | (state == CONSUME_REQ & hit_i[i])) & i_nreset;
    end
    //////////////////// END VALID BITS SIGNING ////////////////////

    //////////////////// READ ENABLE SIGNING ////////////////////
    tag_read_en                 = is_new_request_fetch | is_new_request_read | is_new_request_consume | is_new_request_write;// | is_new_request_read | is_new_request_write | is_new_request_consume;
    data_read_en                = is_new_request_fetch | is_new_request_read | is_new_request_consume | is_new_request_write;// | is_new_request_read | is_new_request_write | is_new_request_consume;
    eviction_meta_info_read_en  = is_new_request_fetch | is_new_request_read | is_new_request_consume | is_new_request_write;// | is_new_request_read | is_new_request_write;
    dirty_bits_read_en          = is_new_request_fetch | is_new_request_write;// | is_new_request_write;
    //////////////////// END READ ENABLE SIGNING ////////////////////

    //////////////////// WRITE ENABLE SIGNING ////////////////////
    tag_write_en = (miss & state == FETCH_REQ) | (miss & state == WRITE_REQ); // | state == WRITE_REQ);
    // CAUTION (for fetch stage is done)
    data_write_en = (i_dram_data_i_valid & o_dram_data_i_ready) | (state == WRITE_REQ);
    // CAUTION
    eviction_meta_info_write_en = (state == FETCH_REQ) | (state == READ_REQ) | (state == WRITE_REQ);
    dirty_bits_write_en = (miss & state == FETCH_REQ) | (state == WRITE_REQ);
    //////////////////// END WRITE ENABLE SIGNING ////////////////////

    //////////////////// WRITE DATA SIGNING ////////////////////
    for (int i = 0; i < WAYS; i++) begin
        eviction_meta_info_write_data[i] = {new_priority_set[i], new_srrip_set[i]};
    end
    // CAUTION
    tag_write_data = cur_tag;
    // CAUTION
    dirty_bits_write_data = state == WRITE_REQ;

    // CAUTION
    if (internal_state == RECEIVE_DATA)
        data_write_data = i_dram_data;
    else
        data_write_data = internal_data;
    //////////////////// END WRITE DATA SIGNING ////////////////////
end

reg [WAYS-1:0] hit_i;
reg hit;
/* verilator lint_off UNOPTFLAT */
reg miss;
/* verilator lint_on UNOPTFLAT */


reg [PRIORITY_BITS-1:0] new_priority_set    [WAYS-1:0];
reg [SRRIP_BITS-1:0]    new_srrip_set_inc   [WAYS-1:0];
reg [SRRIP_BITS-1:0]    new_srrip_set_hit   [WAYS-1:0];
reg [SRRIP_BITS-1:0]    new_srrip_set_miss  [WAYS-1:0];
reg [SRRIP_BITS-1:0]    new_srrip_set       [WAYS-1:0];

wire [$clog2(SETS)-1:0] incoming_set = i_addr[$clog2(DATA_WIDTH) +: $clog2(SETS)];
wire [$clog2(SETS)-1:0] internal_set = internal_addr[$clog2(DATA_WIDTH) +: $clog2(SETS)];

always @(*) begin
    for (int i = 0; i < WAYS; i++) begin
        hit_i[i] = (cur_tag == tag_set[i]) & valid_bits_set[cur_set][i];
    end
    hit = |hit_i;
    miss = ~hit;
end

always @(*) begin
    for (int i = 0; i < WAYS; i++)
        if (hit_i[i]) begin
            // CAUTION
            if (state == FETCH_REQ)
                new_priority_set[i] = priority_set[i] + 1;
            else if (state == READ_REQ)
                new_priority_set[i] = priority_set[i] - 1;
            // else if (state == WRITE_REQ)
            //     new_priority_set[i] = {{PRIORITY_BITS-1{1'b0}}, 1'b1};
            else
                new_priority_set[i] = priority_set[i];
        end
        // else if (miss & victim_indicator_i[i] & (state == FETCH_REQ | state == WRITE_REQ)) begin
        else if (miss & victim_indicator_i[i] & state == FETCH_REQ) begin
        // else if (victim_indicator_i[i]) begin
            new_priority_set[i] = {{PRIORITY_BITS-1{1'b0}}, 1'b1};
            // if (state == WRITE_REQ & miss)
            //     new_priority_set[i] = {PRIORITY_BITS{~victim_indicator_i[i]}};
            // else
                // new_priority_set[i] = priority_set[i];
        end else
            new_priority_set[i] = priority_set[i];
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
reg [WAYS-1:0]          min_indicator;
reg [SRRIP_BITS-1:0]    max_srrip;
reg [WAYS-1:0]          max_srrip_indicator;

always @(*) begin
    min_priority = {PRIORITY_BITS{1'b1}};
    for (int i = 0; i < WAYS; i++) begin
        if (priority_set[i] < min_priority)
            min_priority = priority_set[i];
    end

    for (int i = 0; i < WAYS; i++) begin
        // without if ?
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

reg [WAYS-1:0] invalid_bits_line;
wire is_smth_invalid = |invalid_bits_line;

int first_invalid;
always @(*) begin
    first_invalid = 0;

    for (int i = 0; i < WAYS; i++) begin
        invalid_bits_line[i] = ~valid_bits_set[cur_set][i];
        if (invalid_bits_line[i] && first_invalid == 0)
            first_invalid = i + 1;
    end
end

reg is_victim_dirty;
reg [WAYS-1:0] is_victim_dirty_i;
reg [WAYS-1:0] victim_indicator_i;
always @(*) begin
    for (int i = 0; i < WAYS; i++)
        if (is_smth_invalid)
            victim_indicator_i[i] = (i == (first_invalid-1));
        else
            victim_indicator_i[i] = (max_srrip_indicator[i]);
            // CAUTION
            //?? victim_indicator_i[i] = (miss & max_srrip_indicator[i]);

    for (int i = 0; i < WAYS; i++)
        is_victim_dirty_i[i] = victim_indicator_i[i] & dirty_bits_set[i] & valid_bits_set[cur_set][i];
    is_victim_dirty = |is_victim_dirty_i;
end

always @(*) begin
    for (int i = 0; i < WAYS; i++) begin
        if (victim_indicator_i[i])
            new_srrip_set_miss[i] = {{SRRIP_BITS-1{1'b1}}, 1'b0};
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

reg [DATA_WIDTH-1:0] dirty_data;
reg [ADDR_WIDTH-1:0] dirty_addr;

reg [DATA_WIDTH-1:0] dirty_data_comb;
reg [ADDR_WIDTH-1:0] dirty_addr_comb;

always @(*) begin
    dirty_data_comb = 0;
    dirty_addr_comb = 0;

    for (int i = 0; i < WAYS; i++) begin
        dirty_data_comb = dirty_data_comb | (data_set[i] & {DATA_WIDTH{victim_indicator_i[i]}});
        dirty_addr_comb = dirty_addr_comb | {tag_set[i] & {ADDR_WIDTH-$clog2(SETS)-$clog2(DATA_WIDTH){victim_indicator_i[i]}}, cur_set, {$clog2(DATA_WIDTH){1'b0}}};
    end
end

always @(posedge i_clk) begin
    if (miss & is_victim_dirty & (state == FETCH_REQ | state == WRITE_REQ)) begin // | miss
        dirty_data <= dirty_data_comb;
        dirty_addr <= dirty_addr_comb;
    end
end

// CAUTION
always @(*) begin
    o_dram_data_o = dirty_data;
    o_dram_addr = dirty_addr;

    if (internal_state == RECEIVE_DATA)
        o_dram_addr = internal_addr;
end

// always @(*) begin
//     for (int i = 0; i < WAYS; i++)
//         if (state == WRITE_REQ) begin
//             if (hit)
//                 new_srrip_set[i] = srrip_set[i];
//             else
//                 new_srrip_set[i] = srrip_set[i] & {SRRIP_BITS{~victim_indicator_i[i]}};
//         end else begin
//             if (hit)
//                 new_srrip_set[i] = new_srrip_set_hit[i];
//             else
//                 new_srrip_set[i] = new_srrip_set_miss[i];
//         end
// end

endmodule