`default_nettype none
// Urbana (Spartan-7 XC7S50) demo wrapper for alu16.
//
//   SW[15:0]  value to load
//   btn[0]    load A from SW
//   btn[1]    load B from SW
//   btn[2]    op = op + 1 (wraps 15 -> 0)
//   btn[3]    flip left display between A and B
//
//   7-seg right 4 digits : Y  (result, hex)
//   7-seg left  4 digits : A or B (see btn[3])
//   led[15:12]           : op, binary
//   led[9]               : left display shows A
//   led[8]               : left display shows B
//   led[7:4]             : live mirror of SW[3:0] (updates instantly, no button)
//   led[3:0]             : Z C V N  (led[3] = Z ... led[0] = N)
module alu16_top #(
    parameter DEBOUNCE_CLKS = 1_000_000,
    parameter BTN_ACTIVE_HIGH = 1
) (
    input  wire        clk_100mhz,
    input  wire [15:0] sw,
    input  wire [3:0]  btn,
    output wire [15:0] led,
    output wire [3:0]  d0_an,
    output wire [7:0]  d0_seg,
    output wire [3:0]  d1_an,
    output wire [7:0]  d1_seg
);

    // ---------------- inputs ----------------
    wire [3:0] btn_h = BTN_ACTIVE_HIGH ? btn : ~btn;

    wire p_a, p_b, p_op, p_view;
    btn_cond #(.DEBOUNCE_CLKS(DEBOUNCE_CLKS)) u_ba (.clk(clk_100mhz), .btn_in(btn_h[0]), .pulse(p_a));
    btn_cond #(.DEBOUNCE_CLKS(DEBOUNCE_CLKS)) u_bb (.clk(clk_100mhz), .btn_in(btn_h[1]), .pulse(p_b));
    btn_cond #(.DEBOUNCE_CLKS(DEBOUNCE_CLKS)) u_bo (.clk(clk_100mhz), .btn_in(btn_h[2]), .pulse(p_op));
    btn_cond #(.DEBOUNCE_CLKS(DEBOUNCE_CLKS)) u_bv (.clk(clk_100mhz), .btn_in(btn_h[3]), .pulse(p_view));

    // switches are asynchronous: two flops before use
    reg [15:0] sw_m = 16'h0, sw_s = 16'h0;
    always @(posedge clk_100mhz) begin
        sw_m <= sw;
        sw_s <= sw_m;
    end

    // ---------------- state ----------------
    reg [15:0] a_reg = 16'h0000;
    reg [15:0] b_reg = 16'h0000;
    reg [3:0]  op_reg = 4'd0;
    reg        view = 1'b0;           // 0: show A, 1: show B

    always @(posedge clk_100mhz) begin
        if (p_a)    a_reg  <= sw_s;
        if (p_b)    b_reg  <= sw_s;
        if (p_op)   op_reg <= op_reg + 4'd1;
        if (p_view) view   <= ~view;
    end

    // ---------------- ALU (unchanged) ----------------
    wire [15:0] y;
    wire        zf, cf, vf, nf;
    alu16 u_alu (.a(a_reg), .b(b_reg), .op(op_reg),
                 .y(y), .zf(zf), .cf(cf), .vf(vf), .nf(nf));

    // one register stage: keeps the multiply path off the display/LED pins
    reg [15:0] y_r = 16'h0000;
    reg [3:0]  flags_r = 4'h0;        // {Z, C, V, N}
    always @(posedge clk_100mhz) begin
        y_r     <= y;
        flags_r <= {zf, cf, vf, nf};
    end

    // ---------------- outputs ----------------
    // seg7_driver: data[15:0] = right four digits, data[31:16] = left four
    wire [15:0] left_val = view ? b_reg : a_reg;

    seg7_driver u_seg7 (
        .clk   (clk_100mhz),
        .rst   (1'b0),
        .data  ({left_val, y_r}),
        .dp    (8'h00),
        .d0_an (d0_an),  .d0_seg (d0_seg),
        .d1_an (d1_an),  .d1_seg (d1_seg)
    );

    // led[9]=A shown, led[8]=B shown, led[7:4] = live mirror of SW[3:0] (no button needed)
    assign led = {op_reg, 2'b00, ~view, view, sw_s[3:0], flags_r};

endmodule
`default_nettype wire
