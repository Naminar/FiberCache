
module dff #(
    DATA_WIDTH = 8
) (
    input wire i_clk,
    input wire i_reset,
    input wire [DATA_WIDTH-1:0] i_d,
    output reg [DATA_WIDTH-1:0] o_q
);

always @(posedge i_clk) begin
    if (i_reset) begin
        o_q <= 0;
    end else begin
        o_q <= i_d;
    end
end

endmodule
