#!/usr/bin/env python3
"""
Generates a MINIMAL test program.mem to verify basic pipeline operation.
Just: addi x1, x0, 42 → store to DataMem[1024] → write marker → halt
"""

def i_type(imm12, rs1, funct3, rd, opcode):
    return ((imm12 & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def s_type(imm12, rs2, rs1, funct3, opcode):
    imm = imm12 & 0xFFF
    return (((imm >> 5) & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | \
           ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           ((imm & 0x1F) << 7) | (opcode & 0x7F)

def u_type(imm20, rd, opcode):
    return ((imm20 & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def j_type(offset, rd, opcode):
    imm = offset & 0x1FFFFF
    bit20  = (imm >> 20) & 1
    b10_1  = (imm >> 1) & 0x3FF
    bit11  = (imm >> 11) & 1
    b19_12 = (imm >> 12) & 0xFF
    return (bit20 << 31) | (b10_1 << 21) | (bit11 << 20) | \
           (b19_12 << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

ADDI = lambda rd, rs1, imm: i_type(imm, rs1, 0b000, rd, 0b0010011)
LUI  = lambda rd, imm20:    u_type(imm20, rd, 0b0110111)
SW   = lambda rs2, rs1, imm: s_type(imm, rs2, rs1, 0b010, 0b0100011)
JAL  = lambda rd, off:       j_type(off, rd, 0b1101111)
NOP  = lambda: 0x00000013

prog = []
def emit(instr, comment=""):
    prog.append(instr)
    print(f"  [{len(prog)-1:3d}] 0x{instr:08X}  {comment}")

print("=== Minimal Test Program ===")
# Instruction 0: addi x1, x0, 42    → x1 = 42
emit(ADDI(1, 0, 42),         "addi x1, x0, 42       # x1 = 42")
# Instruction 1: addi x2, x0, 99    → x2 = 99
emit(ADDI(2, 0, 99),         "addi x2, x0, 99       # x2 = 99")
# Instruction 2: lui x8, 1          → x8 = 0x1000
emit(LUI(8, 1),              "lui  x8, 1            # x8 = 0x1000")
# Instruction 3: nop (pipeline bubble)
emit(NOP(),                   "nop                   # pipeline bubble")
# Instruction 4: nop
emit(NOP(),                   "nop                   # pipeline bubble")
# Instruction 5: sw x1, 0(x8)       → DataMem[0x1000] = 42
emit(SW(1, 8, 0),            "sw   x1, 0(x8)        # mem[0x1000] = 42")
# Instruction 6: sw x2, 4(x8)       → DataMem[0x1004] = 99
emit(SW(2, 8, 4),            "sw   x2, 4(x8)        # mem[0x1004] = 99")
# Instruction 7: addi x3, x0, 255   → x3 = 255
emit(ADDI(3, 0, 255),        "addi x3, x0, 255      # x3 = 0xFF")
# Instruction 8: nop
emit(NOP(),                   "nop")
# Instruction 9: sw x3, 8(x8)       → DataMem[0x1008] = 255
emit(SW(3, 8, 8),            "sw   x3, 8(x8)        # mem[0x1008] = 255")
# Instruction 10: jal x0, 0         → infinite loop
emit(JAL(0, 0),              "jal  x0, 0            # halt (infinite loop)")

# Pad to 256
while len(prog) < 256:
    prog.append(NOP())

with open("program.mem", "w") as f:
    for instr in prog:
        f.write(f"{instr:08X}\n")

print(f"\n[OK] Written program.mem ({len(prog)} instructions)")
print(f"     Expected: DataMem[1024]=0x0000002A, DataMem[1025]=0x00000063, DataMem[1026]=0x000000FF")
