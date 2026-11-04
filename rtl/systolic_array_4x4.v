// systolic_array_4x4: 4x4 mesh of processing elements, output-stationary.
// A enters on the west edge of each row and moves east; B enters on the north
// edge of each column and moves south. Every inter-PE hop is registered inside
// the PE. Flattened index of PE(i,j) and of C[i][j] is i*4+j.
//
// Link vectors (flat):
//   A link (i,j), j=0..N : index i*(N+1)+j   -- (i,0) is the west edge input
//   B link (i,j), i=0..M : index i*N+j       -- (0,j) is the north edge input
`timescale 1ns/1ps
module systolic_array_4x4 #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
) (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    clear_acc,

    input  wire [4*DATA_W-1:0]     a_data,    // lane i = a_data[i*DATA_W +: DATA_W]
    input  wire [3:0]              a_valid,
    input  wire [3:0]              a_last,
    input  wire [4*DATA_W-1:0]     b_data,    // lane j = b_data[j*DATA_W +: DATA_W]
    input  wire [3:0]              b_valid,
    input  wire [3:0]              b_last,

    output wire [16*ACC_W-1:0]     result_flat,
    output wire [15:0]             result_valid
);
    localparam M = 4;
    localparam N = 4;

    // East/south edge outputs are intentionally unconnected downstream.
    /* verilator lint_off UNUSEDSIGNAL */
    wire [M*(N+1)*DATA_W-1:0] a_link;
    wire [M*(N+1)-1:0]        av_link;
    wire [M*(N+1)-1:0]        al_link;
    wire [(M+1)*N*DATA_W-1:0] b_link;
    wire [(M+1)*N-1:0]        bv_link;
    wire [(M+1)*N-1:0]        bl_link;
    /* verilator lint_on UNUSEDSIGNAL */

    genvar i, j;
    generate
        for (i = 0; i < M; i = i + 1) begin : g_west
            assign a_link [(i*(N+1))*DATA_W +: DATA_W] = a_data[i*DATA_W +: DATA_W];
            assign av_link[i*(N+1)] = a_valid[i];
            assign al_link[i*(N+1)] = a_last[i];
        end
        for (j = 0; j < N; j = j + 1) begin : g_north
            assign b_link [j*DATA_W +: DATA_W] = b_data[j*DATA_W +: DATA_W];
            assign bv_link[j] = b_valid[j];
            assign bl_link[j] = b_last[j];
        end

        for (i = 0; i < M; i = i + 1) begin : g_row
            for (j = 0; j < N; j = j + 1) begin : g_col
                processing_element #(.DATA_W(DATA_W), .ACC_W(ACC_W)) u_pe (
                    .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
                    .a_in       (a_link [(i*(N+1)+j)*DATA_W +: DATA_W]),
                    .a_valid_in (av_link[i*(N+1)+j]),
                    .a_last_in  (al_link[i*(N+1)+j]),
                    .a_out      (a_link [(i*(N+1)+j+1)*DATA_W +: DATA_W]),
                    .a_valid_out(av_link[i*(N+1)+j+1]),
                    .a_last_out (al_link[i*(N+1)+j+1]),
                    .b_in       (b_link [(i*N+j)*DATA_W +: DATA_W]),
                    .b_valid_in (bv_link[i*N+j]),
                    .b_last_in  (bl_link[i*N+j]),
                    .b_out      (b_link [((i+1)*N+j)*DATA_W +: DATA_W]),
                    .b_valid_out(bv_link[(i+1)*N+j]),
                    .b_last_out (bl_link[(i+1)*N+j]),
                    .result      (result_flat[(i*N+j)*ACC_W +: ACC_W]),
                    .result_valid(result_valid[i*N+j])
                );
            end
        end
    endgenerate
endmodule
