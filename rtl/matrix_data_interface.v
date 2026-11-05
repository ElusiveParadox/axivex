// matrix_data_interface: host-side command handling.
//   * start is edge-sensitive: a rising edge while !busy is accepted
//     (start_accept); a rising edge while busy is dropped and flagged with a
//     one-cycle start_rejected pulse. Holding start high never retriggers.
//   * start_accept is the single transaction-accept strobe used by the input
//     buffers, controller and output buffer.
// Matrix A/B/C data are passed through the top level as packed vectors
// (row-major, index i*4+j), so no further logic is needed here.
`timescale 1ns/1ps
module matrix_data_interface (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire busy,
    output wire start_accept,
    output wire start_rejected
);
    reg  start_q;
    wire start_rise = start & ~start_q;

    always @(posedge clk) begin
        if (!rst_n) start_q <= 1'b0;
        else        start_q <= start;
    end

    assign start_accept   = start_rise & ~busy;
    assign start_rejected = start_rise &  busy;
endmodule
