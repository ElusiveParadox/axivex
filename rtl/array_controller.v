// array_controller: IDLE -> CLEAR -> RUN -> RETIRE -> DONE -> (IDLE | CLEAR)
//
//   IDLE   : waiting for start_accept.
//   CLEAR  : one cycle; clear_acc=1 zeroes every PE.
//   RUN    : LAST_CYCLE+1 cycles (K+M+N-2 = 10); cycle_count = 0..LAST_CYCLE.
//   RETIRE : waits until the output buffer holds (or is capturing this cycle)
//            all 16 results. The last PE result_valid appears here.
//   DONE   : one-cycle `done` pulse; busy is low so a new start may be accepted.
//
// busy = CLEAR|RUN|RETIRE. State encoding is exported for waveforms/tests.
`timescale 1ns/1ps
module array_controller #(
    parameter CNT_W      = 4,
    parameter LAST_CYCLE = 9      // K + M + N - 3
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start_accept,
    input  wire             all_captured_next,

    output wire             busy,
    output wire             done,
    output wire             clear_acc,
    output wire             run,
    output reg  [CNT_W-1:0] cycle_count,
    output reg  [2:0]       state
);
    localparam [2:0] S_IDLE = 3'd0, S_CLEAR = 3'd1, S_RUN = 3'd2,
                     S_RETIRE = 3'd3, S_DONE = 3'd4;

    reg [2:0] next_state;

    always @* begin
        next_state = state;
        case (state)
            S_IDLE:   if (start_accept)       next_state = S_CLEAR;
            S_CLEAR:                          next_state = S_RUN;
            S_RUN:    if (cycle_count == LAST_CYCLE[CNT_W-1:0]) next_state = S_RETIRE;
            S_RETIRE: if (all_captured_next)  next_state = S_DONE;
            S_DONE:   next_state = start_accept ? S_CLEAR : S_IDLE;
            default:                          next_state = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            cycle_count <= {CNT_W{1'b0}};
        end else begin
            state <= next_state;
            case (state)
                S_CLEAR:  cycle_count <= {CNT_W{1'b0}};
                S_RUN:    cycle_count <= cycle_count + 1'b1;
                S_RETIRE: if (cycle_count != {CNT_W{1'b1}}) cycle_count <= cycle_count + 1'b1;
                default:  cycle_count <= cycle_count;
            endcase
        end
    end

    assign busy      = (state == S_CLEAR) | (state == S_RUN) | (state == S_RETIRE);
    assign done      = (state == S_DONE);
    assign clear_acc = (state == S_CLEAR);
    assign run       = (state == S_RUN);
endmodule
