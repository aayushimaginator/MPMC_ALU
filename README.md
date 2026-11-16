# 16-bit ALU on the Urbana (Spartan-7)

A 16-operation, 16-bit ALU with Z/C/V/N flags, demonstrated on a Real Digital Urbana
board (XC7S50-CSGA324). Switches and buttons load operands, the 7-segment display
shows the operand and the result, LEDs show the opcode and the flags.

## Files

| File | Purpose |
|---|---|
| `alu16.v` | The ALU (combinational, 16 ops, flags) |
| `alu16_top.v` | Board wrapper: inputs, registers, output stage |
| `btn_cond.v` | Button synchronizer, debouncer, one-clock pulse |
| `seg7_driver.v` | 8-digit hex display driver (reused from the RV32I project) |
| `alu16_urbana.xdc` | Pin constraints |
| `tb_alu16.v` | ALU testbench (20 vectors) |
| `tb_alu16_top.v` | Top-level testbench (switches, buttons, LEDs) |
| `build_alu16.tcl` | Vivado batch build |
| `program.tcl` | Program the board |

## Operations

| op | name | result | op | name | result |
|---|---|---|---|---|---|
| 0 | ADD | A + B | 8 | SAR | A >>> B[3:0] (arithmetic) |
| 1 | SUB | A - B | 9 | MUL | low 16 bits of A * B |
| 2 | AND | A & B | 10 | EQ | A == B |
| 3 | OR | A \| B | 11 | LT_S | A < B (signed) |
| 4 | XOR | A ^ B | 12 | LT_U | A < B (unsigned) |
| 5 | NOT | ~A | 13 | INC | A + 1 |
| 6 | SHL | A << B[3:0] | 14 | DEC | A - 1 |
| 7 | SHR | A >> B[3:0] (logical) | 15 | NOP | 0 |

Flags: **Z** result is zero, **C** carry out (borrow for SUB/DEC, shifted-out bit for
shifts, A < B for LT_U), **V** signed overflow for ADD/SUB/INC/DEC (for MUL: the upper
16 bits of the unsigned 32-bit product differ from the sign extension of Y[15]; see
Known limitations), **N** result bit 15.

## Board controls

| Control | Function |
|---|---|
| `SW[15:0]` | Value to load |
| BTN0 | Load A from the switches |
| BTN1 | Load B from the switches |
| BTN2 | Opcode + 1 (wraps 15 to 0) |
| BTN3 | Flip the left display between A and B |
| Right 4 digits | Result Y (hex) |
| Left 4 digits | A or B |
| LD15..LD12 | Opcode, binary |
| LD9 / LD8 | Left display shows A / shows B |
| LD7..LD4 | Live mirror of SW3..SW0 (no button needed) |
| LD3..LD0 | Z C V N |

Power-up state: A = B = 0, op = ADD, display `0000 0000`, LD9 and LD3 lit.

## Pins

Clock N15 (100 MHz). Switches SW0..SW15: G1 F2 F1 E2 E1 D2 D1 C2 B2 A4 A5 A6 C7 A7 B7 A8.
Buttons BTN0..BTN3 (active high): J2 J1 G2 H2. LEDs and 7-segment pins are in
`alu16_urbana.xdc` (copied from the RV32I project, proven on hardware).
These are FPGA package pins, not board silkscreen labels.

## Build, program, simulate

```
vivado -mode batch -source build_alu16.tcl
vivado -mode batch -source program.tcl -tclargs vivado_alu16/alu16.runs/impl_1/alu16_top.bit
```

The bitstream is volatile: reprogram after any power cycle.

Simulation (Icarus Verilog):

```
iverilog -g2005 -o alu.vvp alu16.v tb_alu16.v && vvp alu.vvp
iverilog -g2005 -o top.vvp alu16.v btn_cond.v seg7_driver.v alu16_top.v tb_alu16_top.v && vvp top.vvp
```

Expected: `PASS: all 20 tests` and `PASS: top-level`.

## Results

- Post-route timing at 100 MHz: setup slack +3.632 ns, hold slack +0.095 ns, no failing endpoints.
- DRC: 0 errors. Synthesis: 0 errors, 0 critical warnings, 3 warnings (LED10 and LED11 are unused and driven low; the rest are tool-flow notices).
- Resources: 500 LUTs, 203 flip-flops, 1 DSP48E1.
- The multiplier maps to one DSP48.
- Hardware check: every switch, button, LED and display digit verified on the board.

## Bugs found by testing

1. **DEC returned A unchanged.** It was implemented as `A + 0xFFFF + 1`; the carry-in
   must be 0. Found by running the original testbench in simulation.
2. **Wrong testbench expectation for `SUB 0x8000 - 1`.** The test expected C = 1, but with
   C defined as borrow (as in `3 - 5`), 0x8000 - 1 has no borrow, so C = 0.
3. **Buttons were first documented by FPGA pin name** (J2, J1, G2, H2), and J2 is also the
   name of an unrelated connector on the board. All documentation now uses the silkscreen
   labels BTN0 to BTN3.

## Known limitations

- **The MUL overflow flag is not a signed-overflow flag.** The multiplier is unsigned, so
  V is also set for negative products that fit in 16 signed bits (for example
  0xFFFF x 1, which is -1 x 1, and 0x0003 x 0xFFFE, which is 3 x -2). Treat V after MUL
  as an unsigned-overflow indicator only.
- The opcode only counts up; returning to an earlier operation takes up to 15 presses.
- The bitstream is volatile and must be reprogrammed after power loss.

## Design notes

- Switches and buttons are asynchronous: both go through two-flop synchronizers, and
  buttons are debounced for 10 ms before producing a single-clock pulse.
- Results and flags are registered once before the display, which keeps the multiply
  path off the output pins.
- `seg7_driver` expects `data[15:0]` on the right four digits and `data[31:16]` on the left.
