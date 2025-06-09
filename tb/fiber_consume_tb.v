`timescale 1ns/1ps

module fiber_consume_tb;

    // Parameters
    localparam DATA_WIDTH=16; // double + 2 * i32
    localparam SETS=256;
    localparam WAYS=16;
    localparam ADDR_WIDTH = 64; // 64 bit address
    localparam SRRIP_BITS=2;
    localparam PRIORITY_BITS=5;

    localparam FETCH_REQ    = 4'b0001;
    localparam READ_REQ     = 4'b0010;
    localparam WRITE_REQ    = 4'b0100;
    localparam CONSUME_REQ  = 4'b1000;

    //////////////////// GLOBAL TREE SIGNAL ////////////////////
    reg i_clk;
    reg i_nreset;

    //////////////////// PE CROSS BAR ////////////////////
    // request type
    reg    [3:0]                i_request_type;
    reg    [ADDR_WIDTH-1:0]     i_addr;
    reg                         i_type_valid;
    wire                        o_type_ready;
    // insert requests ports
    wire    [DATA_WIDTH-1:0]    i_data;
    wire    [DATA_WIDTH-1:0]    o_pe_data_o;
    wire                        o_pe_data_o_valid;
    reg                        i_pe_data_o_ready;
    //////////////////// DRAM CROSS BAR ////////////////////
    wire    [ADDR_WIDTH-1:0]    o_dram_addr;
    // inbox requests ports
    reg    [DATA_WIDTH-1:0]     i_dram_data;
    reg                         i_dram_data_i_valid;
    wire                        o_dram_data_i_ready;
    // outbox requests ports
    wire    [DATA_WIDTH-1:0]    o_dram_data_o;
    wire                        o_dram_data_o_valid;
    wire                        i_dram_data_o_ready;

    // Instantiate the Unit Under Test (UUT)
    fiber #(
        .DATA_WIDTH(DATA_WIDTH),
        .SETS(SETS),
        .WAYS(WAYS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SRRIP_BITS(SRRIP_BITS),
        .PRIORITY_BITS(PRIORITY_BITS)
    ) uut (
        //////////////////// GLOBAL TREE SIGNAL ////////////////////
        .i_clk(i_clk),
        .i_nreset(i_nreset),

        //////////////////// PE CROSS BAR ////////////////////
        // request type
        .i_request_type(i_request_type),
        .i_addr(i_addr),
        .i_type_valid(i_type_valid),
        .o_type_ready(o_type_ready),

        // insert requests ports
        .i_data(i_data),
        .o_pe_data_o(o_pe_data_o),
        .o_pe_data_o_valid(o_pe_data_o_valid),
        .i_pe_data_o_ready(i_pe_data_o_ready),

        //////////////////// DRAM CROSS BAR ////////////////////
        .o_dram_addr(o_dram_addr),

        // inbox requests ports
        .i_dram_data(i_dram_data),
        .i_dram_data_i_valid(i_dram_data_i_valid),
        .o_dram_data_i_ready(o_dram_data_i_ready),

        // outbox requests ports
        .o_dram_data_o(o_dram_data_o),
        .o_dram_data_o_valid(o_dram_data_o_valid),
        .i_dram_data_o_ready(i_dram_data_o_ready)
    );

    task fetch_req (input [ADDR_WIDTH-1:0] addr);
        begin
            i_type_valid = 1;
            i_request_type = FETCH_REQ;
            i_addr = addr;
            #5
            i_type_valid = 0;
        end
    endtask

    task send_data_from_dram (input ready, output valid, output [DATA_WIDTH-1:0] data);
        begin
            if (ready) begin
                data = 16'b 0000000000000000;
                valid = 1;
            end
            else begin
                data = 16'b 1111111111111111;
                valid = 0;
            end
        end
	endtask

    // Clock generation
    always #5 i_clk = ~i_clk;

    // Testbench logic
    initial begin
        $dumpfile("dump_consume.vcd");
        $dumpvars;

        // Initialize inputs
        i_clk = 0;

        i_nreset = 1;

        #2

        i_nreset = 0;
        i_type_valid = 0;
        #25

        i_nreset = 1;

        #5

        // 32: 00000000000000000000000000000000
        // 32: 11111111111111111111111111111111
        i_type_valid = 1;
        i_request_type = FETCH_REQ;
        i_addr = 64'b 0000000000000000000000000000000011111111111111111111111111111111;

        #5

        i_type_valid = 0;

        #15

        send_data_from_dram(o_dram_data_i_ready, i_dram_data_i_valid, i_dram_data);

        #20

        i_type_valid = 1;
        i_request_type = CONSUME_REQ;
        i_addr = 64'b 0000000000000000000000000000000011111111111111111111111111111111;

        #25
        i_type_valid = 0;
        i_pe_data_o_ready = 1;

        #10

        i_pe_data_o_ready = 0;

        #15
        // End simulation
        $finish;
    end

endmodule