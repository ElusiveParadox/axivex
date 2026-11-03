// input_buffers: latches the packed A and B matrices when a transaction is
// accepted, so the host may change its input ports while the array runs.
// Row-major packing: A[i][k] = a_mat[(i*4+k)*DATA_W +: DATA_W],
//                    B[k][j] = b_mat[(k*4+j)*DATA_W +: DATA_W].
`timescale 1ns/1ps
module input_buffers #(
    parameter DATA_W = 8
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  load,
    input  wire [16*DATA_W-1:0]  a_flat_in,
    input  wire [16*DATA_W-1:0]  b_flat_in,
    output reg  [16*DATA_W-1:0]  a_mat,
    output reg  [16*DATA_W-1:0]  b_mat
);
    always @(posedge clk) begin
        if (!rst_n) begin
            a_mat <= {16*DATA_W{1'b0}};
            b_mat <= {16*DATA_W{1'b0}};
        end else if (load) begin
            a_mat <= a_flat_in;
            b_mat <= b_flat_in;
        end
    end
endmodule
