import re

# Analyze key instructions in trace:
# PC=0x64: CUSTOM_RERAM instruction (rs1=x10, rs2=x11, rd=x19) => wb_sel=2'b10 => reram_result
# PC=0x68: SLLI x23, x1, 5  (compute row*32)
# PC=0x6c: ADD  x23, x23, x2 (add col offset)
# PC=0x70: SLLI x23, x23, 2  (byte address)
# PC=0x74: ADD  x23, x23, x8 (add base 0x1000)
# PC=0x78: SW   x19, 0(x23)  (store reram result)

with open('VISOR.sim/sim_1/behav/xsim/simulate.log', 'r') as f:
    lines = f.readlines()

# Find all store instructions at PC=0x78 and preceding RERAM at PC=0x64
for i, line in enumerate(lines):
    if 'PC=00000078' in line and 'CYC' in line:
        # Print the RERAM instruction and the store
        for j in range(max(0, i-8), min(len(lines), i+3)):
            l = lines[j].strip()
            if 'CYC' in l or 'REGS' in l:
                print(l)
        print("---")
        # Only print first 5
        if lines[i:].count('PC=00000078') < 2:
            break

# Also check: what does the CUSTOM instruction (PC=0x64) produce?
print("\n=== CUSTOM RERAM (PC=0x64) instructions ===")
count = 0
for line in lines:
    if 'PC=00000064' in line and 'CYC' in line:
        print(line.strip())
        count += 1
        if count > 10:
            break

# Check what x19 holds after RERAM
print("\n=== wb_sel and reram_result check ===")
print("Looking for rd=19 (x19) writes...")
count = 0
for line in lines:
    if 'rd=19' in line and 'CYC' in line:
        print(line.strip())
        count += 1
        if count > 10:
            break
