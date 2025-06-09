module single_srambank #(
    parameter DATA=18
)
(
    input  wire                 i_clk,
    input  wire [DATA-1:0]      i_write_data,
    input  wire                 i_bank_sel,
    input  wire                 i_read_en,
    input  wire                 i_write_en,
    output reg  [DATA-1:0]      o_data_out
);

reg [DATA-1:0] mem;

always @(posedge i_clk) begin
    if (i_write_en && i_bank_sel) begin
        mem <= i_write_data;
    end
    else if (i_read_en && i_bank_sel) begin
        o_data_out <= mem;
    end
end

endmodule
