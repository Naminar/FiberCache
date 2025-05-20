`timescale 1ns/1ps

module fiber_tb;

    // Parameters
    localparam DATA_WIDTH=16; // double + 2 * i32
    localparam SETS=256;
    localparam WAYS=16;
    localparam ADDR_WIDTH = 64; // 64 bit address
    localparam SRRIP_BITS=2;
    localparam PRIORITY_BITS=5;
    
    // Inputs

    // Outputs

    // Instantiate the Unit Under Test (UUT)
    fiberBank (
        .DATA_WIDTH(DATA_WIDTH),
        .SETS(SETS),
        .WAYS(WAYS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .SRRIP_BITS(SRRIP_BITS),
        .PRIORITY_BITS(PRIORITY_BITS)
    ) uut (
        
    );

    // Clock generation
    always #5 i_clk = ~i_clk;

    // Testbench logic
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars;

        // Initialize inputs
        i_clk = 0;

        // End simulation
        $finish;
    end

endmodule