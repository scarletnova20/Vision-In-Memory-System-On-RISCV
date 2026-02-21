import sys, re
with open('VISOR.sim/sim_1/behav/xsim/simulate.log', 'r') as f_in, open('trace_end.txt', 'w', encoding='utf-8') as f_out:
    for line in f_in:
        m = re.search(r'CYC (\d+)', line)
        if m:
            cyc = int(m.group(1))
            if 7190 <= cyc <= 8000:
                f_out.write(line)
        elif 'REGS' in line or 'COMPLETION' in line:
            f_out.write(line)
