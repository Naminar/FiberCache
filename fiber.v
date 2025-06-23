module fiber #(
    DATA_WIDTH=16, // double + 2 * i32
    SETS=256,
    WAYS=16,
    ADDR_WIDTH = 64,
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
    input   wire    [DATA_WIDTH*BIT_SIZE-1:0]    i_data,

    // read requests ports
    output  reg     [DATA_WIDTH*BIT_SIZE-1:0]    o_pe_data_o,
    output  wire                        o_pe_data_o_valid,
    input   wire                        i_pe_data_o_ready,

    //////////////////// DRAM CROSS BAR ////////////////////
    output   reg    [ADDR_WIDTH-1:0]    o_dram_addr,

    // inbox requests ports
    input   wire    [DATA_WIDTH*BIT_SIZE-1:0]    i_dram_data,
    input   wire                        i_dram_data_i_valid,
    output  wire                        o_dram_data_i_ready,

    // outbox requests ports
    output  wire    [DATA_WIDTH*BIT_SIZE-1:0]     o_dram_data_o,
    output  wire                        o_dram_data_o_valid,
    input   wire                        i_dram_data_o_ready
);

localparam BIT_SIZE     = 8;
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

wire [$clog2(SETS)-1:0] cur_set = (|{state,internal_state})?
                                        internal_set
                                    :
                                        incoming_set;

wire [ADDR_WIDTH-$clog2(DATA_WIDTH)-$clog2(SETS)-1:0] cur_tag = internal_addr[ADDR_WIDTH-1:$clog2(DATA_WIDTH)+$clog2(SETS)];
wire [WAYS-1:0] [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_set;

wire [WAYS-1:0]                         dirty_bits_set;
wire [WAYS-1:0] [PRIORITY_BITS-1:0]     priority_set;
wire [WAYS-1:0] [SRRIP_BITS-1:0]        srrip_set;

reg     [WAYS-1:0] [DATA_WIDTH*BIT_SIZE-1:0] data_set;
wire    [WAYS-1:0] cur_valid_bits_line;

genvar gen_i;
reg [3:0] state;
reg [3:0] internal_state;
reg [WAYS-1:0] insert_data_handler;

assign o_type_ready = ~|state & ~|internal_state;

wire [3:0] new_request = i_request_type & ({4{i_type_valid & o_type_ready & i_nreset}});

always @(posedge i_clk) begin
    if (~i_nreset)
        state <= NONE;
    else if (~|state)
        state <= new_request;
    else
        state <= NONE;
end

assign o_pe_data_o_valid = internal_state == SEND_TO_PE;
wire is_victim_dirty;

always @(posedge i_clk) begin
    if (~i_nreset)
        internal_state <= NONE;
    else case (state)
        FETCH_REQ: begin
            if (miss)
                if (is_victim_dirty)
                    internal_state <= SEND_DIRTY_VICTIM;
                else
                    internal_state <= RECEIVE_DATA;
        end

        READ_REQ, CONSUME_REQ: begin
            internal_state <= SEND_TO_PE;
        end

        WRITE_REQ: begin
            if (miss & is_victim_dirty)
                internal_state <= ONLY_SEND_DIRTY_VICTIM;
        end

        default: case (internal_state)
            SEND_TO_PE: begin
                if (i_pe_data_o_ready)
                    internal_state <= NONE;
            end
            SEND_DIRTY_VICTIM: begin
                if (i_dram_data_o_ready)
                    internal_state <= RECEIVE_DATA;
            end
            ONLY_SEND_DIRTY_VICTIM: begin
                if (i_dram_data_o_ready)
                    internal_state <= NONE;
            end
            RECEIVE_DATA: begin
                if (i_dram_data_i_valid)
                    internal_state <= NONE;
            end

            default:
                internal_state <= internal_state;
        endcase
    endcase
end

assign o_dram_data_o_valid = (internal_state == SEND_DIRTY_VICTIM) | (internal_state == ONLY_SEND_DIRTY_VICTIM);
assign o_dram_data_i_ready = internal_state == RECEIVE_DATA;

wire [WAYS-1:0] victim_indicator_i;

always @(posedge i_clk) begin
    for (int i = 0; i < WAYS; i++)
        if (miss & state == FETCH_REQ)
            insert_data_handler[i] <= victim_indicator_i[i];
end

wire is_new_request_fetch   = new_request[0]; // == FETCH_REQ;
wire is_new_request_read    = new_request[1]; // == READ_REQ;
wire is_new_request_write   = new_request[2]; // == WRITE_REQ;
wire is_new_request_consume = new_request[3]; // == CONSUME_REQ;

wire is_it_new_request    =   is_new_request_fetch
                            | is_new_request_read
                            | is_new_request_consume
                            | is_new_request_write;


wire is_state_fetch     = state[0]; // == FETCH_REQ;
wire is_state_read      = state[1]; // == READ_REQ;
wire is_state_write     = state[2]; // == WRITE_REQ;
wire is_state_consume   = state[3]; // == CONSUME_REQ;

wire is_internal_state_receive_data = internal_state == RECEIVE_DATA;

wire [WAYS-1:0] hit_i;

reg     [WAYS-1:0] [PRIORITY_BITS-1:0]  new_priority_set;
wire    [WAYS-1:0] [SRRIP_BITS-1:0]     new_srrip_set;

wire [$clog2(SETS)-1:0] incoming_set = i_addr[$clog2(DATA_WIDTH) +: $clog2(SETS)];
wire [$clog2(SETS)-1:0] internal_set = internal_addr[$clog2(DATA_WIDTH) +: $clog2(SETS)];

wire [WAYS-1:0] where_to_write_while_write_stage;
generate
    for (gen_i = 0; gen_i < WAYS; gen_i++) begin
        assign hit_i[gen_i] = (cur_tag == tag_set[gen_i]) & cur_valid_bits_line[gen_i];
    end
endgenerate

wire hit = |hit_i;
wire miss = ~hit;

reg [ADDR_WIDTH-1:0] internal_addr;
reg [DATA_WIDTH*BIT_SIZE-1:0] internal_data;

always @(posedge i_clk) begin
    if (o_type_ready) begin
        internal_addr <= i_addr;
        internal_data <= i_data;
    end
end


data_logic #(
    .BIT_SIZE(BIT_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .SETS(SETS),
    .WAYS(WAYS)
) data_logic_u (
    .i_clk(i_clk),
    .is_state_write(is_state_write),
    .is_new_request_fetch(is_new_request_fetch),
    .is_new_request_read(is_new_request_read),
    .is_new_request_write(is_new_request_write),
    .is_new_request_consume(is_new_request_consume),
    .is_internal_state_receive_data(is_internal_state_receive_data),

    .cur_set(cur_set),
    .data_set(data_set),
    .insert_data_handler(insert_data_handler),
    .where_to_write_while_write_stage(where_to_write_while_write_stage),

    .i_dram_data_i_valid(i_dram_data_i_valid),
    .o_dram_data_i_ready(o_dram_data_i_ready),

    .internal_data(internal_data),
    .i_dram_data(i_dram_data)
);

inout_handler #(
    .BIT_SIZE(BIT_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .SETS(SETS),
    .WAYS(WAYS),
    .ADDR_WIDTH(ADDR_WIDTH)
) inout_handler_u (
    .i_clk(i_clk),
    .is_state_fetch(is_state_fetch),
    .is_state_read(is_state_read),
    .is_state_write(is_state_write),
    .is_state_consume(is_state_consume),
    .is_internal_state_receive_data(is_internal_state_receive_data),

    .miss(miss),
    .is_victim_dirty(is_victim_dirty),
    .hit_i(hit_i),
    .cur_set(cur_set),
    .victim_indicator_i(victim_indicator_i),
    .internal_addr(internal_addr),
    .data_set(data_set),
    .tag_set(tag_set),

    .o_pe_data_o(o_pe_data_o),
    .o_dram_data_o(o_dram_data_o),
    .o_dram_addr(o_dram_addr)
);


endmodule
