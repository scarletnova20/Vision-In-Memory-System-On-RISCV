#!/usr/bin/env python3
"""
generate_program_mem.py
Generates program.mem (256 lines of 8-char hex) for RISC-V Sobel edge detection.
Also writes sobel_program.s assembly source for reference.

Usage (from project root):
    python scripts/generate_program_mem.py
"""
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
MEM_DIR = os.path.join(PROJECT_ROOT, "mem")
os.makedirs(MEM_DIR, exist_ok=True)

# ====== RV32I Instruction Encoders ======

def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | \
           ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)

def i_type(imm12, rs1, funct3, rd, opcode):
    return ((imm12 & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def s_type(imm12, rs2, rs1, funct3, opcode):
    imm = imm12 & 0xFFF
    return (((imm >> 5) & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | \
           ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           ((imm & 0x1F) << 7) | (opcode & 0x7F)

def b_type(offset, rs2, rs1, funct3, opcode):
    imm = offset & 0x1FFF
    bit12  = (imm >> 12) & 1
    b10_5  = (imm >> 5) & 0x3F
    b4_1   = (imm >> 1) & 0xF
    bit11  = (imm >> 11) & 1
    return (bit12 << 31) | (b10_5 << 25) | ((rs2 & 0x1F) << 20) | \
           ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           (b4_1 << 8) | (bit11 << 7) | (opcode & 0x7F)

def u_type(imm20, rd, opcode):
    return ((imm20 & 0xFFFFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def j_type(offset, rd, opcode):
    imm = offset & 0x1FFFFF
    bit20   = (imm >> 20) & 1
    b10_1   = (imm >> 1) & 0x3FF
    bit11   = (imm >> 11) & 1
    b19_12  = (imm >> 12) & 0xFF
    return (bit20 << 31) | (b10_1 << 21) | (bit11 << 20) | \
           (b19_12 << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

# Opcodes
OP_LUI    = 0b0110111
OP_JAL    = 0b1101111
OP_BRANCH = 0b1100011
OP_LOAD   = 0b0000011
OP_STORE  = 0b0100011
OP_IMM    = 0b0010011
OP_REG    = 0b0110011

# Instruction helpers
def LUI(rd, imm20):       return u_type(imm20, rd, OP_LUI)
def ADDI(rd, rs1, imm):   return i_type(imm, rs1, 0b000, rd, OP_IMM)
def SLLI(rd, rs1, shamt): return i_type(shamt, rs1, 0b001, rd, OP_IMM)
def ADD(rd, rs1, rs2):    return r_type(0, rs2, rs1, 0b000, rd, OP_REG)
def LW(rd, rs1, imm):     return i_type(imm, rs1, 0b010, rd, OP_LOAD)
def SW(rs2, rs1, imm):    return s_type(imm, rs2, rs1, 0b010, OP_STORE)
def BLT(rs1, rs2, off):   return b_type(off, rs2, rs1, 0b100, OP_BRANCH)
def JAL(rd, off):          return j_type(off, rd, OP_JAL)
def NOP():                 return 0x00000013

# Custom ReRAM Sobel instruction: R-type, opcode=0001011
# funct7=0000000, rs2=x11, rs1=x10, funct3=000, rd=x19
CUSTOM_RERAM = 0x00B5098B

# ====== Build Program ======
# Register allocation:
#   x1  = row / zero-fill counter     x2  = col
#   x3  = temp (zero-fill addr)       x6  = 31 (loop bound)
#   x8  = 0x1000 (output base)        x9  = temp
#   x10-x18 = 3x3 pixel neighborhood  x19 = Sobel result
#   x20 = base address for loads      x21 = temp (col-1)
#   x23 = output address temp

program = []
asm_lines = []

def emit(instr, comment=""):
    program.append(instr)
    addr = (len(program) - 1) * 4
    asm_lines.append(f"  # 0x{addr:03X}  {instr:08X}  {comment}")

# --- Initialization ---
emit(LUI(8, 1),             "lui   x8, 1            # x8 = 0x1000 (output base)")
emit(ADDI(6, 0, 31),        "addi  x6, x0, 31       # x6 = 31 (loop bound)")
emit(ADDI(9, 0, 1024),      "addi  x9, x0, 1024     # x9 = 1024 (pixel count)")
emit(ADDI(1, 0, 0),         "addi  x1, x0, 0        # x1 = 0 (zero-fill counter)")

# --- Zero-fill output region (border pixels get 0) ---
# ZERO_LOOP at addr 0x10
emit(SLLI(3, 1, 2),         "slli  x3, x1, 2        # ZERO_LOOP: offset = counter*4")
emit(ADD(3, 3, 8),          "add   x3, x3, x8       # addr = output_base + offset")
emit(SW(0, 3, 0),           "sw    x0, 0(x3)        # output[i] = 0")
emit(ADDI(1, 1, 1),         "addi  x1, x1, 1        # counter++")
emit(BLT(1, 9, -16),        "blt   x1, x9, -16      # if counter<1024, loop (->0x10)")

# --- Main processing loops ---
emit(ADDI(1, 0, 1),         "addi  x1, x0, 1        # row = 1")
# ROW_LOOP at addr 0x28
emit(ADDI(2, 0, 1),         "addi  x2, x0, 1        # ROW_LOOP: col = 1")

# COL_LOOP at addr 0x2C — compute base addr of pixel(row-1, col-1)
emit(ADDI(20, 1, -1),       "addi  x20, x1, -1      # COL_LOOP: x20 = row-1")
emit(SLLI(20, 20, 5),       "slli  x20, x20, 5      # x20 = (row-1)*32")
emit(ADDI(21, 2, -1),       "addi  x21, x2, -1      # x21 = col-1")
emit(ADD(20, 20, 21),       "add   x20, x20, x21    # x20 = (row-1)*32+(col-1)")
emit(SLLI(20, 20, 2),       "slli  x20, x20, 2      # x20 = byte addr of top-left")

# Load 3x3 neighborhood into x10-x18
emit(LW(10, 20, 0),         "lw    x10, 0(x20)      # pix[r-1][c-1]")
emit(LW(11, 20, 4),         "lw    x11, 4(x20)      # pix[r-1][c  ]")
emit(LW(12, 20, 8),         "lw    x12, 8(x20)      # pix[r-1][c+1]")
emit(LW(13, 20, 128),       "lw    x13, 128(x20)    # pix[r  ][c-1]  (+32*4)")
emit(LW(14, 20, 132),       "lw    x14, 132(x20)    # pix[r  ][c  ]")
emit(LW(15, 20, 136),       "lw    x15, 136(x20)    # pix[r  ][c+1]")
emit(LW(16, 20, 256),       "lw    x16, 256(x20)    # pix[r+1][c-1]  (+64*4)")
emit(LW(17, 20, 260),       "lw    x17, 260(x20)    # pix[r+1][c  ]")
emit(LW(18, 20, 264),       "lw    x18, 264(x20)    # pix[r+1][c+1]")

# Fire custom ReRAM Sobel accelerator
emit(CUSTOM_RERAM,           ".word 0x00B5098B       # CUSTOM: rd=x19 rs1=x10 rs2=x11 op=0001011")

# Compute output address = 0x1000 + (row*32+col)*4
emit(SLLI(23, 1, 5),        "slli  x23, x1, 5       # x23 = row*32")
emit(ADD(23, 23, 2),        "add   x23, x23, x2     # x23 = row*32+col")
emit(SLLI(23, 23, 2),       "slli  x23, x23, 2      # x23 = byte offset")
emit(ADD(23, 23, 8),        "add   x23, x23, x8     # x23 = output addr")
emit(SW(19, 23, 0),         "sw    x19, 0(x23)      # store Sobel result")

# Col loop: col++, branch back to COL_LOOP
emit(ADDI(2, 2, 1),         "addi  x2, x2, 1        # col++")
emit(BLT(2, 6, -84),        "blt   x2, x6, -84      # if col<31, loop (->0x2C)")

# Row loop: row++, branch back to ROW_LOOP
emit(ADDI(1, 1, 1),         "addi  x1, x1, 1        # row++")
emit(BLT(1, 6, -96),        "blt   x1, x6, -96      # if row<31, loop (->0x28)")

# --- Completion marker: 0xDEADBEEF at 0x1FFC ---
emit(LUI(9, 2),             "lui   x9, 2            # x9 = 0x2000")
emit(ADDI(9, 9, -4),        "addi  x9, x9, -4       # x9 = 0x1FFC")
# 0xDEADBEEF: upper20=0xDEADC (compensate for sign-ext), lower12=-273
emit(LUI(10, 0xDEADC),      "lui   x10, 0xDEADC     # x10 = 0xDEADC000")
emit(ADDI(10, 10, -273),    "addi  x10, x10, -273   # x10 = 0xDEADBEEF")
emit(SW(10, 9, 0),          "sw    x10, 0(x9)       # mem[0x1FFC] = 0xDEADBEEF")

# --- Infinite loop ---
emit(JAL(0, 0),             "jal   x0, 0            # infinite loop (halt)")

# ====== Output ======
print(f"[INFO] Program: {len(program)} instructions")

# Pad to 256 with NOP
while len(program) < 256:
    program.append(NOP())

# Write program.mem
program_path = os.path.join(MEM_DIR, "program.mem")
with open(program_path, "w") as f:
    for instr in program:
        f.write(f"{instr:08X}\n")
print(f"[OK]   Written {program_path} (256 lines)")

# Write assembly source
asm_path = os.path.join(MEM_DIR, "sobel_program.s")
with open(asm_path, "w") as f:
    f.write("# ============================================================\n")
    f.write("# sobel_program.s — RISC-V Sobel Edge Detection for ReRAM\n")
    f.write("# 32x32 image, custom opcode 0001011 for ReRAM accelerator\n")
    f.write("# Input:  DataMem 0x000-0xFFC   (1024 pixels, 8-bit in 32-bit words)\n")
    f.write("# Output: DataMem 0x1000-0x1FFC (1024 edge pixels)\n")
    f.write("# Completion marker: 0xDEADBEEF at 0x1FFC\n")
    f.write("# ============================================================\n\n")
    for line in asm_lines:
        f.write(line + "\n")
    f.write(f"\n# Remaining {256 - len(asm_lines)} slots: NOP (0x00000013)\n")
print(f"[OK]   Written {asm_path} ({len(asm_lines)} instructions)")

# Verify critical encodings
assert program[25] == 0x00B5098B, f"Custom instr mismatch: {program[25]:08X}"
# Verify 0xDEADBEEF construction
lui_val = (0xDEADC << 12) & 0xFFFFFFFF  # 0xDEADC000
addi_val = (-273) & 0xFFFFFFFF           # 0xFFFFFEEF
result = (lui_val + addi_val) & 0xFFFFFFFF
assert result == 0xDEADBEEF, f"DEADBEEF mismatch: {result:08X}"
print("[OK]   Encoding verification passed")
