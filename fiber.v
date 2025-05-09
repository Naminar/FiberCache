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

    // request type
    input   wire [3:0] i_request_type,
    input   wire [ADDR_WIDTH-1:0] i_addr,

    // insert requests ports
    input   wire [DATA_WIDTH-1:0] i_data,
    input   wire i_data_i_valid,
    output  wire o_data_i_ready,

    // read requests ports
    output  wire [DATA_WIDTH-1:0] o_data_o,
    output   wire o_data_o_valid,
    input  wire i_data_o_ready
);

localparam FETCH_REQ    = 4'b0001;
localparam READ_REQ     = 4'b0010;
localparam WRITE_REQ    = 4'b0100;
localparam CONSUME_REQ  = 4'b1000;

//-----------------------------------------------------------
//|    |   bank     |     256 sets      | 16 bytes in line  |
//-----------------------------------------------------------
//|tag array (64-12)|      8 bits       |       4 bits      |
//-----------------------------------------------------------

wire [$clog2(SETS)-1:0] cur_set = i_addr[$clog2(DATA_WIDTH) +: $clog2(SETS)];
wire [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_set [WAYS-1:0];

wire [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_set    [WAYS-1:0];
wire                                dirty_bits_set            [WAYS-1:0];
reg [PRIORITY_BITS-1:0]             priority_set    [WAYS-1:0];
reg [SRRIP_BITS-1:0]                srrip_set       [WAYS-1:0];

wire [SRRIP_BITS+PRIORITY_BITS-1:0] eviction_meta_info_write_data;
wire [ADDR_WIDTH-1-$clog2(SETS)-$clog2(DATA_WIDTH):0] tag_write_data;

always @(*) begin
    for(int ii=0; ii < WAYS; ii++)
        {priority_set[ii], srrip_set[ii]} = eviction_meta_info_set[ii];
end

genvar i;
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
                    .i_bank_sel(tag_bank_sel),
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
endgenerate


wire [DATA_WIDTH-1:0] data_write_data;
wire data_bank_sel;
wire data_read_en;
wire data_write_en;
wire [DATA_WIDTH-1:0] data_set [WAYS-1:0];

wire tag_bank_sel;
wire tag_read_en;
wire tag_write_en;

wire dirty_bits_write_data;
wire dirty_bits_bank_sel [WAYS-1:0];
wire dirty_bits_read_en;
wire dirty_bits_write_en;

wire eviction_meta_info_bank_sel [WAYS-1:0];
wire eviction_meta_info_read_en;
wire eviction_meta_info_write_en;

wire valid_bits_field       [SETS-1:0][WAYS-1:0];
wire valid_bits_sel         [SETS-1:0][WAYS-1:0];
wire valid_bits_read_en     [SETS-1:0][WAYS-1:0];
wire valid_bits_write_en    [SETS-1:0][WAYS-1:0];
wire valid_bits_write_data  [SETS-1:0][WAYS-1:0];

genvar k;
generate
    for (i = 0; i < WAYS; i++) begin
        for (k = 0; k < SETS; k++) begin
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

endmodule