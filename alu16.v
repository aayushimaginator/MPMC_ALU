`default_nettype none
module alu16 (
    input  wire [15:0] a, b,
    input  wire [3:0]  op,
    output reg  [15:0] y,
    output reg  zf, cf, vf, nf
);

    localparam OP_ADD  = 4'd0,  OP_SUB  = 4'd1,
               OP_AND  = 4'd2,  OP_OR   = 4'd3,
               OP_XOR  = 4'd4,  OP_NOT  = 4'd5,
               OP_SHL  = 4'd6,  OP_SHR  = 4'd7,
               OP_SAR  = 4'd8,  OP_MUL  = 4'd9,
               OP_EQ   = 4'd10, OP_LT_S = 4'd11,
               OP_LT_U = 4'd12, OP_INC  = 4'd13,
               OP_DEC  = 4'd14, OP_NOP  = 4'd15;

    reg [15:0] b_eff;          // effective adder operand
    reg        cin;
    reg [16:0] sum;            // extra bit for carry-out
    reg [31:0] product;
    reg [15:0] shifted;
    reg        last_out;
    integer    i;
    reg        is_arith;

    always @* begin
        // Defaults: no latches, clean flags on every path.
        y = 16'h0000;
        cf = 1'b0;  vf = 1'b0;
        b_eff = b;  cin = 1'b0;
        sum = 17'h0; product = 32'h0;
        shifted = a; last_out = 1'b0;

        // One adder serves ADD, SUB, INC, DEC.
        // SUB uses two's complement: A + ~B + 1. DEC is A + 0xFFFF (cin = 0).
        case (op)
            OP_ADD: begin b_eff = b;            cin = 1'b0; end
            OP_SUB: begin b_eff = ~b;           cin = 1'b1; end
            OP_INC: begin b_eff = 16'h0000;     cin = 1'b1; end
            OP_DEC: begin b_eff = 16'hffff;     cin = 1'b0; end   // A + (-1); cin=1 would give A + 0x10000 = A
            default: begin b_eff = b;           cin = 1'b0; end
        endcase
        sum = {1'b0, a} + {1'b0, b_eff} + {16'b0, cin};

        is_arith = (op == OP_ADD) || (op == OP_SUB) ||
                   (op == OP_INC) || (op == OP_DEC);

        case (op)
            OP_ADD, OP_SUB, OP_INC, OP_DEC: begin
                y  = sum[15:0];
                cf = (op == OP_SUB || op == OP_DEC) ? ~sum[16] : sum[16];
                // Overflow: same-sign operands, different-sign result.
                vf = (a[15] == b_eff[15]) && (sum[15] != a[15]);
            end

            OP_AND:  y = a & b;
            OP_OR:   y = a | b;
            OP_XOR:  y = a ^ b;
            OP_NOT:  y = ~a;

            OP_SHL, OP_SHR, OP_SAR: begin
                shifted = a;
                for (i = 0; i < 16; i = i + 1) begin
                    if (i < b[3:0]) begin
                        case (op)
                            OP_SHL: begin
                                last_out = shifted[15];
                                shifted  = {shifted[14:0], 1'b0};
                            end
                            OP_SHR: begin
                                last_out = shifted[0];
                                shifted  = {1'b0, shifted[15:1]};
                            end
                            OP_SAR: begin
                                last_out = shifted[0];
                                shifted  = $signed(shifted) >>> 1;
                            end
                            default: shifted = shifted;
                        endcase
                    end
                end
                y = shifted;
                if (b[3:0] != 4'd0) cf = last_out;
            end

            OP_MUL: begin
                product = a * b;          // 32-bit context
                y       = product[15:0];
                vf      = (product[31:16] != {16{y[15]}});
            end

            OP_EQ:   y = {15'b0, (a == b)};
            OP_LT_S: y = {15'b0, ($signed(a) < $signed(b))};
            OP_LT_U: begin
                y  = {15'b0, (a < b)};
                cf = (a < b);
            end

            OP_NOP:  y = 16'h0000;
            default: y = 16'h0000;
        endcase

        zf = (y == 16'h0000);
        nf = y[15];
        if (!is_arith && op != OP_MUL) vf = 1'b0;
    end

endmodule
`default_nettype wire