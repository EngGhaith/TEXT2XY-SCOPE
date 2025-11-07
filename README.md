![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/wokwi_test/badge.svg) ![](../../workflows/fpga/badge.svg)

# 4-Bit ALU with TinyTapeout

This project implements a small 4-bit ALU in Verilog for TinyTapout.
It supports arithmetic and logic operations and additionally contains an internal 8x4-bit register file to store values.

## How it works

Inputs:
- `ui_in[3:0]` = A operand (4 bit)
- `ui_in[7:4]` = B operand (4 bit)
- `uio[3:0]` = opcode

Outputs:
- `uo_out[3:0]` = ALU result (4 bit)

- `uo_out[4]` = Carry flag

- `uo_out[5]` = Overflow flag

- `uo_out[6]` = Sign flag

- `uo_out[7]` = Zero flag

The ALU executes operations every clock cycle and the result is latched on rising edge of `clk`.
There are two opcode ranges:

opcode (4 bit)		Function
`0000-0111`			ALU core operations (ADD, SUB, AND, OR, XOR, SHIFT, PASS)
`1xxx`				register read/write operations

The internal register file consists of 8 registers à 4 bit.	

## How to test

This ALU is easy to test with DIP switches:
1. set A on `ui[3:0]`
2. set B on `ui[7:4]`
3. choose opcode on `uio[3:0]`
4. read result and flags on `uo[7:0]`

Example: ADD 3 + 5
- A = 0011
- B = 0101
- opcode = 0000

result -> `uo_out` = `00001000`

## External hardware
No external hardware required.
You can however attach LEDs for output and DIP switches for input.
Lower 4 LEDs = result. Upper 4 LEDs = flags.
Register file can be used to store values step-by-step to build tiny assembly-like programs.

## Purpose
The goal is to demonstrate that TinyTapout can be used to build a small but fully functional CPU datapath element.
