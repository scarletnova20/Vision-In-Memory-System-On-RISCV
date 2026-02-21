# ============================================================
# sobel_program.s — RISC-V Sobel Edge Detection for ReRAM
# 32x32 image, custom opcode 0001011 for ReRAM accelerator
# Input:  DataMem 0x000-0xFFC   (1024 pixels, 8-bit in 32-bit words)
# Output: DataMem 0x1000-0x1FFC (1024 edge pixels)
# Completion marker: 0xDEADBEEF at 0x1FFC
# ============================================================

  # 0x000  00001437  lui   x8, 1            # x8 = 0x1000 (output base)
  # 0x004  01F00313  addi  x6, x0, 31       # x6 = 31 (loop bound)
  # 0x008  40000493  addi  x9, x0, 1024     # x9 = 1024 (pixel count)
  # 0x00C  00000093  addi  x1, x0, 0        # x1 = 0 (zero-fill counter)
  # 0x010  00209193  slli  x3, x1, 2        # ZERO_LOOP: offset = counter*4
  # 0x014  008181B3  add   x3, x3, x8       # addr = output_base + offset
  # 0x018  0001A023  sw    x0, 0(x3)        # output[i] = 0
  # 0x01C  00108093  addi  x1, x1, 1        # counter++
  # 0x020  FE90C8E3  blt   x1, x9, -16      # if counter<1024, loop (->0x10)
  # 0x024  00100093  addi  x1, x0, 1        # row = 1
  # 0x028  00100113  addi  x2, x0, 1        # ROW_LOOP: col = 1
  # 0x02C  FFF08A13  addi  x20, x1, -1      # COL_LOOP: x20 = row-1
  # 0x030  005A1A13  slli  x20, x20, 5      # x20 = (row-1)*32
  # 0x034  FFF10A93  addi  x21, x2, -1      # x21 = col-1
  # 0x038  015A0A33  add   x20, x20, x21    # x20 = (row-1)*32+(col-1)
  # 0x03C  002A1A13  slli  x20, x20, 2      # x20 = byte addr of top-left
  # 0x040  000A2503  lw    x10, 0(x20)      # pix[r-1][c-1]
  # 0x044  004A2583  lw    x11, 4(x20)      # pix[r-1][c  ]
  # 0x048  008A2603  lw    x12, 8(x20)      # pix[r-1][c+1]
  # 0x04C  080A2683  lw    x13, 128(x20)    # pix[r  ][c-1]  (+32*4)
  # 0x050  084A2703  lw    x14, 132(x20)    # pix[r  ][c  ]
  # 0x054  088A2783  lw    x15, 136(x20)    # pix[r  ][c+1]
  # 0x058  100A2803  lw    x16, 256(x20)    # pix[r+1][c-1]  (+64*4)
  # 0x05C  104A2883  lw    x17, 260(x20)    # pix[r+1][c  ]
  # 0x060  108A2903  lw    x18, 264(x20)    # pix[r+1][c+1]
  # 0x064  00B5098B  .word 0x00B5098B       # CUSTOM: rd=x19 rs1=x10 rs2=x11 op=0001011
  # 0x068  00509B93  slli  x23, x1, 5       # x23 = row*32
  # 0x06C  002B8BB3  add   x23, x23, x2     # x23 = row*32+col
  # 0x070  002B9B93  slli  x23, x23, 2      # x23 = byte offset
  # 0x074  008B8BB3  add   x23, x23, x8     # x23 = output addr
  # 0x078  013BA023  sw    x19, 0(x23)      # store Sobel result
  # 0x07C  00110113  addi  x2, x2, 1        # col++
  # 0x080  FA6146E3  blt   x2, x6, -84      # if col<31, loop (->0x2C)
  # 0x084  00108093  addi  x1, x1, 1        # row++
  # 0x088  FA60C0E3  blt   x1, x6, -96      # if row<31, loop (->0x28)
  # 0x08C  000024B7  lui   x9, 2            # x9 = 0x2000
  # 0x090  FFC48493  addi  x9, x9, -4       # x9 = 0x1FFC
  # 0x094  DEADC537  lui   x10, 0xDEADC     # x10 = 0xDEADC000
  # 0x098  EEF50513  addi  x10, x10, -273   # x10 = 0xDEADBEEF
  # 0x09C  00A4A023  sw    x10, 0(x9)       # mem[0x1FFC] = 0xDEADBEEF
  # 0x0A0  0000006F  jal   x0, 0            # infinite loop (halt)

# Remaining 215 slots: NOP (0x00000013)
