`timescale 1ns/1ps
module tb_alu16;
    reg  [15:0] a, b;
    reg  [3:0]  op;
    wire [15:0] y;
    wire        zf, cf, vf, nf;
    integer     errors = 0;

    alu16 dut (.a(a), .b(b), .op(op),
               .y(y), .zf(zf), .cf(cf), .vf(vf), .nf(nf));

    task check;
        input [3:0]  op_in;
        input [15:0] a_in, b_in, y_exp;
        input        z_exp, c_exp, v_exp, n_exp;
        begin
            op = op_in; a = a_in; b = b_in;
            #1;
            if (y !== y_exp || zf !== z_exp || cf !== c_exp ||
                vf !== v_exp || nf !== n_exp) begin
                $display("FAIL op=%0d a=%h b=%h => y=%h Z=%b C=%b V=%b N=%b",
                         op_in, a_in, b_in, y, zf, cf, vf, nf);
                $display("     expected    y=%h Z=%b C=%b V=%b N=%b",
                         y_exp, z_exp, c_exp, v_exp, n_exp);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // op      A      B      expected Y   Z C V N
        check(4'd0, 16'd5,   16'd3,   16'd8,     0,0,0,0); // ADD
        check(4'd0, 16'h7fff,16'd1,   16'h8000,  0,0,1,1); // signed overflow
        check(4'd1, 16'd3,   16'd5,   16'hfffe,  0,1,0,1); // SUB borrow
        check(4'd1, 16'h8000,16'd1,   16'h7fff,  0,0,1,0); // SUB overflow (C = borrow: 0x8000 >= 1, none)
        check(4'd2, 16'hf0f0,16'h0ff0,16'h00f0,  0,0,0,0); // AND
        check(4'd3, 16'hf000,16'h000f,16'hf00f,  0,0,0,1); // OR
        check(4'd4, 16'haaaa,16'haaaa,16'h0000,  1,0,0,0); // XOR
        check(4'd5, 16'h0000,16'd0,   16'hffff,  0,0,0,1); // NOT
        check(4'd6, 16'h8001,16'd1,   16'h0002,  0,1,0,0); // SHL, carry out
        check(4'd7, 16'h8000,16'd4,   16'h0800,  0,0,0,0); // SHR
        check(4'd8, 16'h8000,16'd4,   16'hf800,  0,0,0,1); // SAR keeps sign
        check(4'd8, 16'hffff,16'd0,   16'hffff,  0,0,0,1); // shift by 0
        check(4'd9, 16'h0100,16'h0100,16'h0000,  1,0,1,0); // MUL overflow
        check(4'd9, 16'd200, 16'd3,   16'd600,   0,0,0,0); // MUL
        check(4'd10,16'h1234,16'h1234,16'd1,     0,0,0,0); // EQ
        check(4'd11,16'hffff,16'd1,   16'd1,     0,0,0,0); // -1 < 1 signed
        check(4'd12,16'hffff,16'd1,   16'd0,     1,0,0,0); // 65535 < 1 false
        check(4'd13,16'h7fff,16'd0,   16'h8000,  0,0,1,1); // INC overflow
        check(4'd14,16'h8000,16'd0,   16'h7fff,  0,0,1,0); // DEC overflow
        check(4'd15,16'hbeef,16'd0,   16'h0000,  1,0,0,0); // NOP

        if (errors == 0) $display("PASS: all 20 tests");
        else             $display("FAIL: %0d tests", errors);
        $finish;
    end
endmodule