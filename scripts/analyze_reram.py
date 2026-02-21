with open('VISOR.sim/sim_1/behav/xsim/simulate.log', 'r') as f:
    for line in f:
        if 'CYC' in line and ('PC=00000064' in line or 'PC=00000068' in line):
            print(line.strip())
            # rd=19 at PC=0x64 is CUSTOM RERAM -> check alu= value 
            # rd=19 at PC=0x68 is SLLI result
