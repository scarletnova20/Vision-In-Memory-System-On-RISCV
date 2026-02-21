import re
with open('VISOR.sim/sim_1/behav/xsim/simulate.log', 'r') as f_in, open('regs_trace.txt', 'w', encoding='utf-8') as f_out:
    for line in f_in:
        if 'REGS' in line or 'COMPLETION' in line:
            f_out.write(line)
