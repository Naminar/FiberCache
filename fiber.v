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
    input   wire    i_type_valid;
    output  wire    o_type_ready; 

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

    // DRAM memory
    // output  wire    [ADDR_WIDTH-1:0] o_dram_addr,
    // inout           [DATA_WIDTH-1:0] io_dram_data,
    // output  wire o_dram_read,
    // output  wire o_dram_write,
    // input   wire i_dram_ready

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


// is there any doing task?
reg i_am_busy;
reg [3:0] request;
reg dram_dir;
reg [3:0] state;

// assign io_dram_data = (dram_dir)? {DATA_WIDTH{1'b0}}: {DATA_WIDTH{1'bz}};


//=============================================================================
wire [$clog2(SETS)-1:0] cur_set = i_addr[$clog2(DATA_WIDTH) +: $clog2(SETS)];
wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] cur_tag = i_addr[ADDR_WIDTH:$clog2(DATA_WIDTH)+$clog2(SETS)];
wire [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_set [WAYS-1:0];

wire [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_set      [WAYS-1:0];
wire                                dirty_bits_set              [WAYS-1:0];
reg [PRIORITY_BITS-1:0]             priority_set                [WAYS-1:0];
reg [SRRIP_BITS-1:0]                srrip_set                   [WAYS-1:0];


wire [DATA_WIDTH-1:0] data_write_data;
wire data_bank_sel;
wire data_read_en;
wire data_write_en;
wire [DATA_WIDTH-1:0] data_set [WAYS-1:0];

reg [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_write_data;
reg tag_bank_sel [WAYS-1:0];
wire tag_read_en;
wire tag_write_en;

wire dirty_bits_write_data;
wire dirty_bits_bank_sel [WAYS-1:0];
wire dirty_bits_read_en;
wire dirty_bits_write_en;

reg [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_write_data;
reg eviction_meta_info_bank_sel [WAYS-1:0];
wire eviction_meta_info_read_en;
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
                    .i_bank_sel(data_bank_sel),
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
                    // ?? it maybe necessary to separate
                    // due to ssrip logic update!!
                    .i_write_data(eviction_meta_info_write_data),
                    .i_bank_sel(eviction_meta_info_bank_sel[i]),
                    .i_read_en(eviction_meta_info_read_en),
                    .i_write_en(eviction_meta_info_write_en),
                    .o_data_out(eviction_meta_info_set[i])
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

wire seamless_connection = o_data_i_ready & i_data_i_valid;
// assign tag_bank_sel = (i_request_type == FETCH_REQ) & seamless_connection;
assign tag_read_en = (i_request_type == FETCH_REQ)  & seamless_connection;

// assign eviction_meta_info_bank_sel = (i_request_type == FETCH_REQ) & seamless_connection;
assign eviction_meta_info_read_en = (i_request_type == FETCH_REQ) & seamless_connection;

always @(*) begin
    for(int ii = 0; ii < WAYS; ii++) begin
        tag_bank_sel[ii] = (i_request_type == FETCH_REQ) & seamless_connection;
        eviction_meta_info_bank_sel[ii] = (i_request_type == FETCH_REQ) & seamless_connection;
    end
end

wire update_priority;
wire update_srrip;

always @(*) begin
    for(int ii=0; ii < WAYS; ii++)
        {priority_set[ii], srrip_set[ii]} = eviction_meta_info_set[ii];
end

reg fetch_not_find;

always @(*) begin

    // START DEFAULT VALUE ////////////////////////////////////////////
    for(int ii = 0; ii < WAYS; ii++) begin
        eviction_meta_info_bank_sel[ii] = 1'b0;
    end

    eviction_meta_info_write_en = 1'b0;
    eviction_meta_info_write_data = {SRRIP_BITS+PRIORITY_BITS{1'b0}};
    fetch_not_find = 1'b0;
    // END DEFAULT VALUE ////////////////////////////////////////////

    if (request == FETCH_REQ) begin
        for(int ii = 0; ii < WAYS; ii++) begin
            if (tag_set[ii] == cur_tag) begin
                eviction_meta_info_write_data = {{priority_set[ii] + 1'b1}, srrip_set[ii]};
                eviction_meta_info_bank_sel[ii] = 1'b1;
                eviction_meta_info_write_en = 1'b1;
                fetch_not_find = 1'b1;
            end
        end
    end
end

always @(posedge i_clk) begin
    if (i_am_busy & (request == FETCH_REQ) & fetch_not_find) begin
        // o_dram_read <= 1'b1;
        // o_dram_addr <= i_addr;
        // necessary to make logic sending request to dram
        o_dram_addr <= i_addr;
        o_dram_data_o_valid <= 1'b1;
    end
end

always @(posedge i_clk) begin
    if (i_am_busy & (request == FETCH_REQ) & fetch_not_find) begin
        if (!i_dram_data_o_ready)
            state <= S_WAIT_DRAM;
    end

    if (state == S_WAIT_DRAM) begin
        if (i_dram_data_o_ready)
            state <= S_WAIT_DRAM_R;
            // o_dram_data_i_ready <= 1'b1;
    end
end

always @(posedge i_clk) begin
    if (state == S_WAIT_DRAM_R) begin
        o_dram_data_i_ready <= 1'b1;

        if (i_dram_data_i_valid) begin
            o_dram_data_i_ready <= 1'b0;
            // data to insert
            // i_dram_data
        end
    end
end

// collect results from memery
// always @(posedge i_clk) begin
//     if (i_am_busy) begin
//         case (request)
//             FETCH_REQ: begin

//             end
//             READ_REQ:
//             WRITE_REQ:
//             CONSUME_REQ:
//             default:
//         endcase

//     end
// end

always @(posedge i_clk or negedge i_nreset) begin
    if (!i_nreset) begin
        for (int ii=0; ii < SETS; ii++) begin
            for (int kk=0; kk < WAYS; kk++) begin
                valid_bits_sel[ii][kk] <= 1'b1;
                valid_bits_write_en[ii][kk] <= 1'b1;
            end
        end

        i_am_busy <= 1'b0;
    end else begin
        if (seamless_connection) begin
            i_am_busy <= 1'b1;
            request <= i_request_type;
            // case (i_request_type)
            //     // look up and then increase counter
            //     // if there is no c-line insert it

            //     // if dirty bit and entry evicted necessary create
            //     // request for DRAM.
            //     // load find and victim meta data, if tag is finded -> update meta, else find victim and insert.
            //     // If victed entry was with dirty bit, send DRAM update request.
            //     FETCH_REQ:

            //     // Create output data and decrease counter
            //     READ_REQ:

            //     // write and set dirty bit to 1
            //     WRITE_REQ:

            //     // send data and invalidate even if dirty bit not equal to 0
            //     CONSUME_REQ:
            //     default:
            // endcase
        end
    end
end

assign o_data_i_ready = !i_am_busy;

endmodule