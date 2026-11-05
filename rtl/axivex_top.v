// axivex_top: AXIVEX 4x4 output-stationary systolic matrix multiplier.
//   C(4x4, INT32) = A(4x4, INT8) x B(4x4, INT8)
//
// Packing (row-major, index(i,j) = i*4 + j):
//   A[i][k] = a_flat[(i*4+k)*8  +: 8 ]   signed
//   B[k][j] = b_flat[(k*4+j)*8  +: 8 ]   signed
//   C[i][j] = c_flat[(i*4+j)*32 +: 32]   signed
//
// Protocol: present a_flat/b_flat, raise start for >= 1 cycle (rising edge
// while busy=0 accepts; A and B are latched on that edge). busy stays high
// until done pulses for one cycle. c_valid goes high with done and stays high
// (c_flat stable) until the next accepted start or reset.
// rst_n: synchronous, active low, hold for >= 1 clock edge.
`timescale 1ns/1ps
module axivex_top #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 start,
    input  wire [16*DATA_W-1:0] a_flat,
    input  wire [16*DATA_W-1:0] b_flat,

    output wire                 busy,
    output wire                 done,
    output wire [16*ACC_W-1:0]  c_flat,
    output wire                 c_valid,
    output wire                 start_rejected,
    output wire                 result_error
);
    localparam CNT_W = 4;

    wire start_accept;
    wire clear_acc, run;
    wire [CNT_W-1:0] cycle_count;
    // state is observed by testbenches/waveforms only
    /* verilator lint_off UNUSEDSIGNAL */
    wire [2:0] state;
    /* verilator lint_on UNUSEDSIGNAL */

    wire [16*DATA_W-1:0] a_mat, b_mat;
    wire [4*DATA_W-1:0] a_data, b_data;
    wire [3:0] a_valid, a_last, b_valid, b_last;
    wire [16*ACC_W-1:0] pe_result;
    wire [15:0] pe_result_valid;
    wire all_captured_next;

    /* verilator lint_off UNUSEDSIGNAL */
    wire [15:0] c_valid_bits;
    wire [4:0]  capture_count;
    /* verilator lint_on UNUSEDSIGNAL */

    matrix_data_interface u_if (
        .clk(clk), .rst_n(rst_n), .start(start), .busy(busy),
        .start_accept(start_accept), .start_rejected(start_rejected)
    );

    input_buffers #(.DATA_W(DATA_W)) u_in (
        .clk(clk), .rst_n(rst_n), .load(start_accept),
        .a_flat_in(a_flat), .b_flat_in(b_flat), .a_mat(a_mat), .b_mat(b_mat)
    );

    array_controller #(.CNT_W(CNT_W), .LAST_CYCLE(9)) u_ctrl (
        .clk(clk), .rst_n(rst_n), .start_accept(start_accept),
        .all_captured_next(all_captured_next),
        .busy(busy), .done(done), .clear_acc(clear_acc), .run(run),
        .cycle_count(cycle_count), .state(state)
    );

    skew_scheduler #(.DATA_W(DATA_W), .CNT_W(CNT_W)) u_sched (
        .run(run), .cycle_count(cycle_count), .a_mat(a_mat), .b_mat(b_mat),
        .a_data(a_data), .a_valid(a_valid), .a_last(a_last),
        .b_data(b_data), .b_valid(b_valid), .b_last(b_last)
    );

    systolic_array_4x4 #(.DATA_W(DATA_W), .ACC_W(ACC_W)) u_array (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_data(a_data), .a_valid(a_valid), .a_last(a_last),
        .b_data(b_data), .b_valid(b_valid), .b_last(b_last),
        .result_flat(pe_result), .result_valid(pe_result_valid)
    );

    output_buffer #(.ACC_W(ACC_W)) u_out (
        .clk(clk), .rst_n(rst_n), .clear(start_accept),
        .result_flat(pe_result), .result_valid(pe_result_valid),
        .c_flat(c_flat), .c_valid_bits(c_valid_bits), .all_valid(c_valid),
        .all_captured_next(all_captured_next),
        .capture_count(capture_count), .capture_error(result_error)
    );
endmodule
