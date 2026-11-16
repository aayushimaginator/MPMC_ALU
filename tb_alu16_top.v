`timescale 1ns/1ps
// Top-level test: drives switches/buttons like a human and checks LEDs + internal state.
module tb_alu16_top;
    localparam DEB = 4;

    reg         clk = 1'b0;
    reg  [15:0] sw  = 16'h0000;
    reg  [3:0]  btn = 4'b0000;
    wire [15:0] led;
    wire [3:0]  d0_an, d1_an;
    wire [7:0]  d0_seg, d1_seg;
    integer     errors = 0;

    alu16_top #(.DEBOUNCE_CLKS(DEB), .BTN_ACTIVE_HIGH(1)) dut (
        .clk_100mhz(clk), .sw(sw), .btn(btn), .led(led),
        .d0_an(d0_an), .d0_seg(d0_seg), .d1_an(d1_an), .d1_seg(d1_seg));

    always #5 clk = ~clk;

    task press;
        input integer idx;
        begin
            btn[idx] = 1'b1;
            repeat (DEB + 6) @(posedge clk);
            btn[idx] = 1'b0;
            repeat (DEB + 6) @(posedge clk);
        end
    endtask

    task load_a; input [15:0] v; begin sw = v; repeat (3) @(posedge clk); press(0); end endtask
    task load_b; input [15:0] v; begin sw = v; repeat (3) @(posedge clk); press(1); end endtask

    task expect_out;
        input [15:0] y_exp;
        input [3:0]  flags_exp;   // {Z,C,V,N}
        input [3:0]  op_exp;
        input [255:0] name;
        begin
            repeat (3) @(posedge clk);
            if (dut.y_r !== y_exp || led[3:0] !== flags_exp || led[15:12] !== op_exp) begin
                $display("FAIL %0s: y=%h flags=%b op=%0d  expected y=%h flags=%b op=%0d",
                         name, dut.y_r, led[3:0], led[15:12], y_exp, flags_exp, op_exp);
                errors = errors + 1;
            end else
                $display("ok   %0s: y=%h flags=%b op=%0d", name, dut.y_r, led[3:0], led[15:12]);
        end
    endtask

    integer k;
    initial begin
        repeat (10) @(posedge clk);

        // ADD 7fff + 1 -> 8000, V and N
        load_a(16'h7fff);
        load_b(16'h0001);
        expect_out(16'h8000, 4'b0011, 4'd0, "ADD overflow");

        // op+1 -> SUB 7fff - 1 -> 7ffe, no flags
        press(2);
        expect_out(16'h7ffe, 4'b0000, 4'd1, "SUB");

        // MUL 0x100 * 0x100 = 0x10000 -> y=0, Z and V
        load_a(16'h0100);
        load_b(16'h0100);
        for (k = 0; k < 8; k = k + 1) press(2);
        expect_out(16'h0000, 4'b1010, 4'd9, "MUL overflow");

        // switches alone must not change A
        sw = 16'hffff;
        repeat (20) @(posedge clk);
        if (dut.a_reg !== 16'h0100) begin
            $display("FAIL: A changed without a button press (a=%h)", dut.a_reg);
            errors = errors + 1;
        end else $display("ok   switches alone do not load A");

        // ...but SW[3:0] must show live on led[7:4]
        if (led[7:4] !== 4'hf) begin
            $display("FAIL: led[7:4]=%h, expected live mirror of SW[3:0]=f", led[7:4]);
            errors = errors + 1;
        end else $display("ok   SW[3:0] mirrors to led[7:4]");

        // view flip: A shown (led9) -> B shown (led8)
        if (led[9:8] !== 2'b10) begin $display("FAIL: view LEDs at start = %b", led[9:8]); errors = errors + 1; end
        press(3);
        if (led[9:8] !== 2'b01) begin $display("FAIL: view LEDs after flip = %b", led[9:8]); errors = errors + 1; end
        else $display("ok   view flip");

        // op wraps 15 -> 0 : 7 more presses from 9 -> 0, ADD 0x100+0x100 = 0x200
        for (k = 0; k < 7; k = k + 1) press(2);
        expect_out(16'h0200, 4'b0000, 4'd0, "op wrap to ADD");

        if (errors == 0) $display("PASS: top-level");
        else             $display("FAIL: %0d top-level checks", errors);
        $finish;
    end
endmodule
