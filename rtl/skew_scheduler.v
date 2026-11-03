// skew_scheduler: combinational row/column operand injection.
// With t = cycle_count (0 = first RUN cycle) and K = 4:
//   row i    presents A[i][t-i] while 0 <= t-i < K   (A[i][k] at t = i+k)
//   column j presents B[t-j][j] while 0 <= t-j < K   (B[k][j] at t = j+k)
// `last` marks k = K-1 and travels with the operand through the array.
// Outputs are 0 / invalid outside the window and whenever `run` is low.
`timescale 1ns/1ps
module skew_scheduler #(
    parameter DATA_W = 8,
    parameter CNT_W  = 4
) (
    input  wire                  run,
    input  wire [CNT_W-1:0]      cycle_count,
    input  wire [16*DATA_W-1:0]  a_mat,
    input  wire [16*DATA_W-1:0]  b_mat,

    output wire [4*DATA_W-1:0]   a_data,
    output wire [3:0]            a_valid,
    output wire [3:0]            a_last,
    output wire [4*DATA_W-1:0]   b_data,
    output wire [3:0]            b_valid,
    output wire [3:0]            b_last
);
    genvar n;
    generate
        for (n = 0; n < 4; n = n + 1) begin : g_lane
            localparam [CNT_W-1:0] OFS = n;
            // K = 4: k index is the low two bits of (t - n)
            // MSB of the widened difference is the borrow (t < n)
            wire [CNT_W:0]   diff_w    = {1'b0, cycle_count} - {1'b0, OFS};
            wire [CNT_W-1:0] diff      = diff_w[CNT_W-1:0];
            wire             in_window = run && !diff_w[CNT_W] && (diff < 4);
            wire [1:0]       k         = diff[1:0];

            wire [4*DATA_W-1:0] a_row = a_mat[n*4*DATA_W +: 4*DATA_W];
            wire [DATA_W-1:0]   a_elem = a_row[k*DATA_W +: DATA_W];
            // B column n, element k lives at (k*4+n)
            wire [DATA_W-1:0] b_elem = b_mat[(k*4+n)*DATA_W +: DATA_W];

            assign a_valid[n] = in_window;
            assign b_valid[n] = in_window;
            assign a_last [n] = in_window && (k == 2'd3);
            assign b_last [n] = in_window && (k == 2'd3);
            assign a_data[n*DATA_W +: DATA_W] = in_window ? a_elem : {DATA_W{1'b0}};
            assign b_data[n*DATA_W +: DATA_W] = in_window ? b_elem : {DATA_W{1'b0}};
        end
    endgenerate
endmodule
