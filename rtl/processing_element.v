// processing_element: one PE of the output-stationary systolic array.
//
// Timing contract (all registers update on posedge clk):
//   * a_out/b_out and their valid/last metadata are registered copies of the
//     inputs: one hop per clock, east (A) and south (B).
//   * If a_valid_in && b_valid_in during a cycle, the MAC result is written to
//     acc at the end of that cycle (inputs are used combinationally).
//   * If additionally a_last_in && b_last_in, the same sum is written to
//     `result` and result_valid is high for exactly the following cycle.
//   * clear_acc (one cycle) zeroes acc, result, result_valid and the forwarding
//     pipeline registers. rst_n is synchronous, active low, and does the same.
`timescale 1ns/1ps
module processing_element #(
    parameter DATA_W = 8,
    parameter ACC_W  = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     clear_acc,

    input  wire signed [DATA_W-1:0] a_in,
    input  wire signed [DATA_W-1:0] b_in,
    input  wire                     a_valid_in,
    input  wire                     b_valid_in,
    input  wire                     a_last_in,
    input  wire                     b_last_in,

    output reg  signed [DATA_W-1:0] a_out,
    output reg  signed [DATA_W-1:0] b_out,
    output reg                      a_valid_out,
    output reg                      b_valid_out,
    output reg                      a_last_out,
    output reg                      b_last_out,

    output reg  signed [ACC_W-1:0]  result,
    output reg                      result_valid
);
    reg  signed [ACC_W-1:0]    acc;
    // product is a debug tap (testbench / waveform); not used inside the PE
    /* verilator lint_off UNUSEDSIGNAL */
    wire signed [2*DATA_W-1:0] product;
    /* verilator lint_on UNUSEDSIGNAL */
    wire signed [ACC_W-1:0]    acc_next;

    mac_unit #(.DATA_W(DATA_W), .ACC_W(ACC_W)) u_mac (
        .a(a_in), .b(b_in), .acc_in(acc), .product(product), .acc_out(acc_next)
    );

    wire fire = a_valid_in & b_valid_in;
    wire last = a_last_in  & b_last_in;

    always @(posedge clk) begin
        if (!rst_n || clear_acc) begin
            a_out        <= {DATA_W{1'b0}};
            b_out        <= {DATA_W{1'b0}};
            a_valid_out  <= 1'b0;
            b_valid_out  <= 1'b0;
            a_last_out   <= 1'b0;
            b_last_out   <= 1'b0;
            acc          <= {ACC_W{1'b0}};
            result       <= {ACC_W{1'b0}};
            result_valid <= 1'b0;
        end else begin
            a_out        <= a_in;
            b_out        <= b_in;
            a_valid_out  <= a_valid_in;
            b_valid_out  <= b_valid_in;
            a_last_out   <= a_last_in;
            b_last_out   <= b_last_in;
            result_valid <= 1'b0;
            if (fire) begin
                acc <= acc_next;
                if (last) begin
                    result       <= acc_next;
                    result_valid <= 1'b1;
                end
            end
        end
    end
endmodule
