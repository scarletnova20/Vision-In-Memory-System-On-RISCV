with open('VISOR.sim/sim_1/behav/xsim/simulate.log', 'r') as f_in, open('trace.txt', 'w', encoding='utf-8') as f_out:
    for line in f_in:
        if 'CYC ' in line or 'REGS' in line:
            f_out.write(line)
