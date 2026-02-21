`timescale 1ns / 1ps

module tb_RISCV_Pipeline;
    reg  clk_100mhz;
    reg  rst;
    wire [3:0] led;

    RISCV_Pipeline dut (
        .clk_100mhz(clk_100mhz),
        .rst       (rst),
        .led       (led)
    );

    // 100 MHz clock - 10ns period
    initial clk_100mhz = 0;
    always #5 clk_100mhz = ~clk_100mhz;

    // Waveform dump for Vivado waveform viewer
    initial begin
        $dumpfile("riscv_pipeline_wave.vcd");
        $dumpvars(0, tb_RISCV_Pipeline);
    end

    // -------------------------------------------------------
    // CYCLE-BY-CYCLE DEBUG TRACE on pipeline clock
    // -------------------------------------------------------
    integer cycle_num;
    initial cycle_num = 0;

    always @(posedge dut.clk) begin
        cycle_num <= cycle_num + 1;

        // Cycle trace disabled for final verification run
        if (0) begin
            $display("CYC %0d | PC=%08h | instr=%08h | rd=%0d wr=%b | alu=%08h | mem_w=%b mem_r=%b | fwdA=%b fwdB=%b",
                cycle_num,
                dut.if_stage.if_pc,
                dut.if_stage.if_instr,
                dut.ex_stage.ex_rd,
                dut.ex_stage.ex_reg_write,
                dut.ex_stage.ex_alu_result,
                dut.ex_stage.ex_mem_write,
                dut.ex_stage.ex_mem_read,
                dut.fwd_a_w, dut.fwd_b_w);
        end

        // Print register file snapshot occasionally
        if (0) begin
            $display("  REGS: x1=%08h x2=%08h x6=%08h x9=%08h",
                dut.regfile.regs[1], dut.regfile.regs[2],
                dut.regfile.regs[6], dut.regfile.regs[9]);
        end

        // End of simulation detection
        if (dut.ex_mem_write_w && dut.ex_alu_result_w == 32'h00001FFC && dut.ex_store_data_w == 32'hDEADBEEF) begin
            $display("*** COMPLETION MARKER WRITE DETECTED at cycle %0d ***", cycle_num);
            $finish;
        end
    end

    initial begin
        rst = 1;
        // CRITICAL FIX: hold reset for 20 cycles of clk_100mhz (200ns)
        // to guarantee multiple rising edges of the divided pipeline clock
        // (pipeline clk period ~80ns, so 200ns = ~2.5 pipeline clk cycles)
        repeat(20) @(posedge clk_100mhz);
        rst = 0;

        $display("=== RISC-V Pipeline Simulation Started (rst released) ===");

        // Run 400000 cycles (4ms at 100MHz)
        repeat(400000) @(posedge clk_100mhz);

        $display("=== Done. LED[3:0] = %b ===", led);
        $display("  Register x1  = %08h", dut.regfile.regs[1]);
        $display("  Register x8  = %08h", dut.regfile.regs[8]);
        $display("  Register x19 = %08h", dut.regfile.regs[19]);
        $display("  DataMem[1024] = %08h", dut.wb_stage.dmem.mem[1024]);
        $display("  DataMem[2047] = %08h", dut.wb_stage.dmem.mem[2047]);

        // Dump output edge image for Python visualisation
        $writememh("output_image.mem",
                   dut.wb_stage.dmem.mem,
                   1024, 2047);

        $finish;
    end

endmodule
