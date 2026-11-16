`default_nettype none
// Button conditioner: 2-FF synchronizer + debounce + one-clock rising-edge pulse.
// The input must hold a new level for DEBOUNCE_CLKS clocks before it is accepted.
// 1_000_000 clocks @ 100 MHz = 10 ms. Must stay below 2**20.
module btn_cond #(
    parameter DEBOUNCE_CLKS = 1_000_000
) (
    input  wire clk,
    input  wire btn_in,          // active-high, asynchronous
    output reg  pulse = 1'b0     // 1 clock wide, on accepted press
);

    reg        s0 = 1'b0, s1 = 1'b0;   // synchronizer
    reg        stable = 1'b0;          // debounced level
    reg [19:0] cnt = 20'd0;

    always @(posedge clk) begin
        s0    <= btn_in;
        s1    <= s0;
        pulse <= 1'b0;

        if (s1 == stable) begin
            cnt <= 20'd0;
        end else if (cnt == DEBOUNCE_CLKS - 1) begin
            stable <= s1;
            cnt    <= 20'd0;
            if (s1) pulse <= 1'b1;     // rising edge only
        end else begin
            cnt <= cnt + 20'd1;
        end
    end

endmodule
`default_nettype wire
