`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.02.2026 16:32:35
// Design Name: 
// Module Name: ClkDiv
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module ClkDiv (
    input  clk_100mhz,
    input  rst,
    output reg clk_out
);
    reg [1:0] cnt;

    initial begin
        cnt     = 2'b00;
        clk_out = 1'b0;
    end

    always @(posedge clk_100mhz) begin
        cnt <= cnt + 1;
        if (cnt == 2'b01)
            clk_out <= ~clk_out;
    end
endmodule


// ============================================================
// MODULE 2: INSTRUCTION MEMORY (BRAM - Single Port)
// Vivado automatically infers BRAM for this pattern.
// Populate program.mem with your assembled RISC-V hex.
// ============================================================
module InstrMem (
    input         clk,
    input  [31:0] addr,
    output reg [31:0] instr
);
    (* ram_style = "block" *)
    reg [31:0] mem [0:255];   // 256 instructions = 1KB

    initial begin
        // synthesis translate_off
        $readmemh("program.mem", mem);
        // synthesis translate_on
    end

    // SYNCHRONOUS read - mandatory for Artix-7 BRAM
    always @(posedge clk) begin
        instr <= mem[addr[9:2]];
    end
endmodule


// ============================================================
// MODULE 3: DATA MEMORY (BRAM - Simple Dual Port)
// Addresses 0-1023   : Input image pixels
// Addresses 1024-2047: Output edge-detected image
// ============================================================
module DataMem (
    input         clk,
    input  [31:0] addr,
    input  [31:0] wdata,
    input         mem_write,
    input         mem_read,
    output reg [31:0] rdata
);
    reg [31:0] mem [0:2047]; // 8KB Memory

    initial begin
        // synthesis translate_off
        $readmemh("image.mem", mem);
        // synthesis translate_on
    end

    always @(posedge clk) begin
        if (mem_write) begin
            mem[addr[12:2]] <= wdata;
        end
    end

    always @(*) begin
        if (mem_read) begin
            rdata = mem[addr[12:2]];
        end else begin
            rdata = 32'b0;
        end
    end
endmodule


// ============================================================
// MODULE 4: REGISTER FILE
// 32 x 32-bit registers.
// Vivado infers distributed RAM (LUTs) - correct for regfile.
// ============================================================
module RegFile (
    input         clk,
    input         reg_write,
    input  [4:0]  rs1, rs2, rd,
    input  [31:0] wdata,
    output [31:0] rdata1, rdata2
);
    (* ram_style = "distributed" *)
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
    end

    // Asynchronous read (combinational) - register file reads must be instant
    assign rdata1 = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
    assign rdata2 = (rs2 == 5'b0) ? 32'b0 : regs[rs2];

    // Synchronous write
    always @(posedge clk) begin
        if (reg_write && rd != 5'b0)
            regs[rd] <= wdata;
    end
endmodule


// ============================================================
// MODULE 5: ALU
// Pure combinational logic - maps to Artix-7 LUTs.
// ============================================================
module ALU (
    input  [31:0] a, b,
    input  [3:0]  alu_op,
    output reg [31:0] result,
    output wire   zero
);
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SLT  = 4'b0111;
    localparam ALU_SLTU = 4'b1000;

    always @(*) begin
        case (alu_op)
            ALU_ADD  : result = a + b;
            ALU_SUB  : result = a - b;
            ALU_AND  : result = a & b;
            ALU_OR   : result = a | b;
            ALU_XOR  : result = a ^ b;
            ALU_SLL  : result = a << b[4:0];
            ALU_SRL  : result = a >> b[4:0];
            ALU_SLT  : result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU : result = (a < b) ? 32'd1 : 32'd0;
            default  : result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);
endmodule


// ============================================================
// MODULE 6: CONTROL UNIT
// Combinational decode - maps cleanly to Artix-7 LUTs.
// ============================================================
module ControlUnit (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input  [6:0] funct7,
    output reg       mem_read,
    output reg       mem_write,
    output reg       reg_write,
    output reg       branch,
    output reg       jump,
    output reg       reram_trigger,
    output reg [3:0] alu_op,
    output reg [1:0] alu_src,
    output reg [1:0] wb_sel
);
    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_ITYPE  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_CUSTOM = 7'b0001011;  // Custom opcode - fires ReRAM MAC

    always @(*) begin
        // Safe defaults
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        reg_write     = 1'b0;
        branch        = 1'b0;
        jump          = 1'b0;
        reram_trigger = 1'b0;
        alu_op        = 4'b0000;
        alu_src       = 2'b00;
        wb_sel        = 2'b00;

        case (opcode)
            OP_RTYPE: begin
                reg_write = 1'b1;
                alu_src   = 2'b00;
                wb_sel    = 2'b00;
                case ({funct7[5], funct3})
                    4'b0_000: alu_op = 4'b0000; // ADD
                    4'b1_000: alu_op = 4'b0001; // SUB
                    4'b0_111: alu_op = 4'b0010; // AND
                    4'b0_110: alu_op = 4'b0011; // OR
                    4'b0_100: alu_op = 4'b0100; // XOR
                    4'b0_001: alu_op = 4'b0101; // SLL
                    4'b0_101: alu_op = 4'b0110; // SRL
                    4'b0_010: alu_op = 4'b0111; // SLT
                    default:  alu_op = 4'b0000;
                endcase
            end

            OP_ITYPE: begin
                reg_write = 1'b1;
                alu_src   = 2'b01;
                wb_sel    = 2'b00;
                case (funct3)
                    3'b000: alu_op = 4'b0000; // ADDI
                    3'b111: alu_op = 4'b0010; // ANDI
                    3'b110: alu_op = 4'b0011; // ORI
                    3'b100: alu_op = 4'b0100; // XORI
                    3'b001: alu_op = 4'b0101; // SLLI
                    3'b101: alu_op = 4'b0110; // SRLI
                    3'b010: alu_op = 4'b0111; // SLTI
                    default: alu_op = 4'b0000;
                endcase
            end

            OP_LOAD: begin
                mem_read  = 1'b1;
                reg_write = 1'b1;
                alu_src   = 2'b01;
                wb_sel    = 2'b01;
                alu_op    = 4'b0000;
            end

            OP_STORE: begin
                mem_write = 1'b1;
                alu_src   = 2'b01;
                alu_op    = 4'b0000;
            end

            OP_BRANCH: begin
                branch  = 1'b1;
                alu_src = 2'b00;
                case (funct3)
                    3'b000: alu_op = 4'b0001; // BEQ - SUB then check zero
                    3'b001: alu_op = 4'b0001; // BNE
                    3'b100: alu_op = 4'b0111; // BLT - SLT
                    default: alu_op = 4'b0001;
                endcase
            end

            OP_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                wb_sel    = 2'b00;
            end

            OP_LUI: begin
                reg_write = 1'b1;
                alu_src   = 2'b01;
                wb_sel    = 2'b00;
                alu_op    = 4'b0000;
            end

            OP_CUSTOM: begin
                reram_trigger = 1'b1;   // Fire ReRAM MAC accelerator
                reg_write     = 1'b1;
                wb_sel        = 2'b10;  // Writeback from ReRAM, not ALU
            end

            default: begin
                // NOP - all signals zero
            end
        endcase
    end
endmodule


// ============================================================
// MODULE 7: IMMEDIATE GENERATOR
// Sign-extends all RISC-V immediate formats.
// ============================================================
module ImmGen (
    input  [31:0] instr,
    output reg [31:0] imm
);
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            7'b0010011,
            7'b0000011,
            7'b1100111: imm = {{20{instr[31]}}, instr[31:20]};

            7'b0100011: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            7'b1100011: imm = {{19{instr[31]}}, instr[31], instr[7],
                                instr[30:25], instr[11:8], 1'b0};

            7'b1101111: imm = {{11{instr[31]}}, instr[31], instr[19:12],
                                instr[20], instr[30:21], 1'b0};

            7'b0110111,
            7'b0010111: imm = {instr[31:12], 12'b0};

            default:    imm = 32'b0;
        endcase
    end
endmodule


// ============================================================
// MODULE 8: HAZARD DETECTION UNIT
// Detects load-use hazard → stall pipeline for 1 cycle.
// ============================================================
module HazardUnit (
    input  [4:0] ex_rd,
    input        ex_mem_read,
    input  [4:0] id_rs1, id_rs2,
    output reg   stall,
    output reg   flush
);
    always @(*) begin
        if (ex_mem_read &&
            (ex_rd != 5'b0) &&
            ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
            stall = 1'b1;
            flush = 1'b1;
        end else begin
            stall = 1'b0;
            flush = 1'b0;
        end
    end
endmodule


// ============================================================
// MODULE 9: FORWARDING UNIT
// Resolves RAW data hazards without stalling.
// fwd = 00: use register file value
// fwd = 01: forward from WB stage
// fwd = 10: forward from EX/MEM boundary
// ============================================================
module ForwardUnit (
    input  [4:0] ex_rs1, ex_rs2,
    input  [4:0] mem_rd,
    input        mem_reg_write,
    input  [4:0] wb_rd,
    input        wb_reg_write,
    output reg [1:0] fwd_a,
    output reg [1:0] fwd_b
);
    always @(*) begin
        // Forward A (rs1)
        if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs1))
            fwd_a = 2'b10;
        else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs1))
            fwd_a = 2'b01;
        else
            fwd_a = 2'b00;

        // Forward B (rs2)
        if (mem_reg_write && (mem_rd != 5'b0) && (mem_rd == ex_rs2))
            fwd_b = 2'b10;
        else if (wb_reg_write && (wb_rd != 5'b0) && (wb_rd == ex_rs2))
            fwd_b = 2'b01;
        else
            fwd_b = 2'b00;
    end
endmodule


// ============================================================
// MODULE 10: IF STAGE - Instruction Fetch
// Note: BRAM has 1-cycle read latency on Artix-7.
// PC is registered; instruction arrives the next clock edge.
// ============================================================
module IF_Stage (
    input         clk, rst,
    input         stall,
    input         branch_taken,
    input  [31:0] branch_target,
    output reg [31:0] if_pc,
    output reg [31:0] if_instr
);
    reg  [31:0] PC;
    reg  [31:0] pc_reg;     // Tracks PC 1 cycle behind, matching BRAM latency
    wire [31:0] fetched_instr;

    InstrMem imem (
        .clk  (clk),
        .addr (PC),
        .instr(fetched_instr)
    );

    reg flush_delay;

    always @(posedge clk) begin
        if (rst) begin
            PC          <= 32'b0;
            pc_reg      <= 32'b0;
            if_pc       <= 32'b0;
            if_instr    <= 32'b0;
            flush_delay <= 1'b0;
        end else if (branch_taken) begin
            PC          <= branch_target;
            pc_reg      <= 32'b0;
            if_pc       <= 32'b0;
            if_instr    <= 32'b0;      // Flush cycle 1
            flush_delay <= 1'b1;       // Need 2nd cycle of flush for BRAM latency
        end else if (flush_delay) begin
            pc_reg      <= PC;
            if_pc       <= 32'b0;
            if_instr    <= 32'b0;      // Flush cycle 2 (ghost instruction from BRAM)
            PC          <= PC + 4;
            flush_delay <= 1'b0;
        end else if (!stall) begin
            pc_reg      <= PC;
            if_pc       <= pc_reg;         // Matches fetched_instr from previous PC
            if_instr    <= fetched_instr;
            PC          <= PC + 4;
        end
    end
endmodule


// ============================================================
// MODULE 11: EX STAGE - Execute
// Decode + ALU + branch resolve + ReRAM trigger.
// All pipeline registers are synchronous (Artix-7 FF style).
// ============================================================
module EX_Stage (
    input         clk, rst,

    // From IF/EX pipeline register
    input  [31:0] if_instr,
    input  [31:0] if_pc,
    input         flush,

    // Register file read data
    input  [31:0] rs1_data, rs2_data,

    // 9 pixel values from register file x10-x18 (for ReRAM)
    input  [71:0] pixel_regs,

    // Forwarded values from later stages
    input  [31:0] fwd_val_mem,     // From EX/WB boundary
    input  [31:0] fwd_val_wb,      // From WB stage
    input  [1:0]  fwd_a, fwd_b,

    // ReRAM result (returned from accelerator)
    input  [31:0] reram_result,

    // Outputs - EX/WB pipeline registers
    output reg [31:0] ex_alu_result,
    output reg [31:0] ex_store_data,
    output reg [31:0] ex_pc_plus4,
    output reg        ex_mem_read,
    output reg        ex_mem_write,
    output reg        ex_reg_write,
    output reg        ex_reram_trigger,
    output reg [1:0]  ex_wb_sel,
    output reg [4:0]  ex_rd,

    // Branch resolution - back to IF Stage
    output            branch_taken,
    output [31:0]     branch_target,

    // To Hazard and Forwarding Units
    output [4:0]  ex_rs1_out,
    output [4:0]  ex_rs2_out,

    // To ReRAM Accelerator
    output reg [71:0] pixel_window,
    output reg [71:0] filter_weights
);
    // Instruction field extraction
    wire [6:0] opcode = flush ? 7'b0 : if_instr[6:0];
    wire [4:0] rs1    = if_instr[19:15];
    wire [4:0] rs2    = if_instr[24:20];
    wire [4:0] rd_f   = if_instr[11:7];
    wire [2:0] funct3 = if_instr[14:12];
    wire [6:0] funct7 = if_instr[31:25];

    assign ex_rs1_out = rs1;
    assign ex_rs2_out = rs2;

    // Control signals
    wire mem_read_c, mem_write_c, reg_write_c;
    wire branch_c, jump_c, reram_trigger_c;
    wire [3:0] alu_op_c;
    wire [1:0] alu_src_c, wb_sel_c;

    ControlUnit ctrl (
        .opcode       (opcode),
        .funct3       (funct3),
        .funct7       (funct7),
        .mem_read     (mem_read_c),
        .mem_write    (mem_write_c),
        .reg_write    (reg_write_c),
        .branch       (branch_c),
        .jump         (jump_c),
        .reram_trigger(reram_trigger_c),
        .alu_op       (alu_op_c),
        .alu_src      (alu_src_c),
        .wb_sel       (wb_sel_c)
    );

    wire [31:0] imm_c;
    ImmGen immgen (
        .instr(if_instr),
        .imm  (imm_c)
    );

    // Forwarding muxes - select correct operand source
    reg [31:0] alu_a, alu_b_reg;
    always @(*) begin
        case (fwd_a)
            2'b10:   alu_a = fwd_val_mem;
            2'b01:   alu_a = fwd_val_wb;
            default: alu_a = rs1_data;
        endcase

        case (fwd_b)
            2'b10:   alu_b_reg = fwd_val_mem;
            2'b01:   alu_b_reg = fwd_val_wb;
            default: alu_b_reg = rs2_data;
        endcase
    end

    wire [31:0] alu_b_final = (alu_src_c == 2'b01) ? imm_c : alu_b_reg;

    wire [31:0] alu_res;
    wire        alu_zero;

    ALU alu_inst (
        .a      (alu_a),
        .b      (alu_b_final),
        .alu_op (alu_op_c),
        .result (alu_res),
        .zero   (alu_zero)
    );

    wire take_branch = jump_c | (branch_c & (
        (funct3 == 3'b000 &&  alu_zero) ||     // BEQ
        (funct3 == 3'b001 && !alu_zero) ||     // BNE
        (funct3 == 3'b100 &&  alu_res[0])      // BLT
    ));

    assign branch_taken  = take_branch;
    assign branch_target = if_pc + imm_c;

    // Sobel Gx = [-1,0,+1; -2,0,+2; -1,0,+1] packed as 9 x 8-bit 2's complement
    localparam [71:0] SOBEL_GX = {
        8'hFF, 8'h00, 8'h01,
        8'hFE, 8'h00, 8'h02,
        8'hFF, 8'h00, 8'h01
    };

    // Pipeline register - synchronous update (Artix-7)
    always @(posedge clk) begin
        if (rst || flush) begin
            ex_alu_result    <= 32'b0;
            ex_store_data    <= 32'b0;
            ex_pc_plus4      <= 32'b0;
            ex_mem_read      <= 1'b0;
            ex_mem_write     <= 1'b0;
            ex_reg_write     <= 1'b0;
            ex_reram_trigger <= 1'b0;
            ex_wb_sel        <= 2'b00;
            ex_rd            <= 5'b0;
            pixel_window     <= 72'b0;
            filter_weights   <= 72'b0;
        end else begin
            ex_alu_result    <= alu_res;
            ex_store_data    <= alu_b_reg;
            ex_pc_plus4      <= if_pc + 4;
            ex_mem_read      <= mem_read_c;
            ex_mem_write     <= mem_write_c;
            ex_reg_write     <= reg_write_c;
            ex_reram_trigger <= reram_trigger_c;
            ex_wb_sel        <= wb_sel_c;
            ex_rd            <= rd_f;

            if (reram_trigger_c) begin
                // Pack all 9 pixels from x10-x18 via pixel_regs bus
                pixel_window   <= pixel_regs;
                filter_weights <= SOBEL_GX;
            end else begin
                pixel_window   <= 72'b0;
                filter_weights <= 72'b0;
            end
        end
    end
endmodule


// ============================================================
// MODULE 12: WB STAGE - Writeback
// Synchronous BRAM read + result mux + register file write.
// ============================================================
module WB_Stage (
    input         clk, rst,

    input  [31:0] ex_alu_result,
    input  [31:0] ex_store_data,
    input         ex_mem_read,
    input         ex_mem_write,
    input         ex_reg_write,
    input  [1:0]  ex_wb_sel,
    input  [4:0]  ex_rd,
    input  [31:0] reram_result,

    output        wb_reg_write,
    output [4:0]  wb_rd,
    output [31:0] wb_wdata,
    output [31:0] fwd_val_wb
);
    wire [31:0] mem_rdata;

    DataMem dmem (
        .clk      (clk),
        .addr     (ex_alu_result),
        .wdata    (ex_store_data),
        .mem_write(ex_mem_write),
        .mem_read (ex_mem_read),
        .rdata    (mem_rdata)
    );

    reg [31:0] wb_data;
    always @(*) begin
        case (ex_wb_sel)
            2'b00: wb_data = ex_alu_result;
            2'b01: wb_data = mem_rdata;
            2'b10: wb_data = reram_result;
            default: wb_data = ex_alu_result;
        endcase
    end

    assign wb_reg_write = ex_reg_write;
    assign wb_rd        = ex_rd;
    assign wb_wdata     = wb_data;
    assign fwd_val_wb   = wb_data;
endmodule


// ============================================================
// MODULE 13: TOP MODULE - RISCV_Pipeline
// Artix-7 synthesizable top-level with board IO.
// Pins:
//   clk_100mhz - connect to W5 (Basys3) or E3 (Nexys A7)
//   rst        - connect to any pushbutton (active HIGH)
//   led[3:0]   - connect to onboard LEDs
// ============================================================
module RISCV_Pipeline (
    input        clk_100mhz,
    input        rst,
    output [3:0] led
);
    // --- 25 MHz pipeline clock ---
    wire clk;
    ClkDiv clkdiv (
        .clk_100mhz(clk_100mhz),
        .rst       (rst),
        .clk_out   (clk)
    );

    // --- Register file ---
    wire [4:0]  rf_rs1, rf_rs2, rf_rd;
    wire [31:0] rf_rdata1, rf_rdata2, rf_wdata;
    wire        rf_write;

    RegFile regfile (
        .clk      (clk),
        .reg_write(rf_write),
        .rs1      (rf_rs1),
        .rs2      (rf_rs2),
        .rd       (rf_rd),
        .wdata    (rf_wdata),
        .rdata1   (rf_rdata1),
        .rdata2   (rf_rdata2)
    );

    // --- IF Stage ---
    wire        branch_taken_w;
    wire [31:0] branch_target_w;
    wire [31:0] if_pc_w, if_instr_w;
    wire        stall_w, flush_w;

    IF_Stage if_stage (
        .clk          (clk),
        .rst          (rst),
        .stall        (stall_w),
        .branch_taken (branch_taken_w),
        .branch_target(branch_target_w),
        .if_pc        (if_pc_w),
        .if_instr     (if_instr_w)
    );

    // Register file reads driven by instruction in decode (IF output)
    assign rf_rs1 = if_instr_w[19:15];
    assign rf_rs2 = if_instr_w[24:20];

    // --- EX Stage ---
    wire [31:0] ex_alu_result_w, ex_store_data_w, ex_pc_plus4_w;
    wire        ex_mem_read_w, ex_mem_write_w, ex_reg_write_w;
    wire        ex_reram_trigger_w;
    wire [1:0]  ex_wb_sel_w;
    wire [4:0]  ex_rd_w;
    wire [71:0] pixel_window_w, filter_weights_w;
    wire [31:0] reram_result_w;
    wire [4:0]  ex_rs1_w, ex_rs2_w;
    wire [31:0] fwd_val_wb_w;
    wire [1:0]  fwd_a_w, fwd_b_w;
    wire        wb_reg_write_w;
    wire [4:0]  wb_rd_w;

    EX_Stage ex_stage (
        .clk             (clk),
        .rst             (rst),
        .if_instr        (if_instr_w),
        .if_pc           (if_pc_w),
        .flush           (flush_w),
        .rs1_data        (rf_rdata1),
        .rs2_data        (rf_rdata2),
        .pixel_regs      ({regfile.regs[10][7:0], regfile.regs[11][7:0],
                           regfile.regs[12][7:0], regfile.regs[13][7:0],
                           regfile.regs[14][7:0], regfile.regs[15][7:0],
                           regfile.regs[16][7:0], regfile.regs[17][7:0],
                           regfile.regs[18][7:0]}),
        .fwd_val_mem     (ex_alu_result_w),
        .fwd_val_wb      (fwd_val_wb_w),
        .fwd_a           (fwd_a_w),
        .fwd_b           (fwd_b_w),
        .reram_result    (reram_result_w),
        .ex_alu_result   (ex_alu_result_w),
        .ex_store_data   (ex_store_data_w),
        .ex_pc_plus4     (ex_pc_plus4_w),
        .ex_mem_read     (ex_mem_read_w),
        .ex_mem_write    (ex_mem_write_w),
        .ex_reg_write    (ex_reg_write_w),
        .ex_reram_trigger(ex_reram_trigger_w),
        .ex_wb_sel       (ex_wb_sel_w),
        .ex_rd           (ex_rd_w),
        .branch_taken    (branch_taken_w),
        .branch_target   (branch_target_w),
        .ex_rs1_out      (ex_rs1_w),
        .ex_rs2_out      (ex_rs2_w),
        .pixel_window    (pixel_window_w),
        .filter_weights  (filter_weights_w)
    );

    // --- Hazard Detection ---
    HazardUnit hazard (
        .ex_rd      (ex_rd_w),
        .ex_mem_read(ex_mem_read_w),
        .id_rs1     (if_instr_w[19:15]),
        .id_rs2     (if_instr_w[24:20]),
        .stall      (stall_w),
        .flush      (flush_w)
    );

    // --- Forwarding Unit ---
    ForwardUnit fwd_unit (
        .ex_rs1       (ex_rs1_w),
        .ex_rs2       (ex_rs2_w),
        .mem_rd       (ex_rd_w),
        .mem_reg_write(ex_reg_write_w),
        .wb_rd        (wb_rd_w),
        .wb_reg_write (wb_reg_write_w),
        .fwd_a        (fwd_a_w),
        .fwd_b        (fwd_b_w)
    );

    // --- ReRAM Accelerator (reram_accelerator.v) ---
    wire reram_done_w;

    ReRAM_Accelerator reram (
        .clk           (clk),
        .rst           (rst),
        .trigger       (ex_reram_trigger_w),
        .pixel_window  (pixel_window_w),
        .filter_weights(filter_weights_w),
        .result        (reram_result_w),
        .done          (reram_done_w)
    );

    // --- WB Stage ---
    WB_Stage wb_stage (
        .clk          (clk),
        .rst          (rst),
        .ex_alu_result(ex_alu_result_w),
        .ex_store_data(ex_store_data_w),
        .ex_mem_read  (ex_mem_read_w),
        .ex_mem_write (ex_mem_write_w),
        .ex_reg_write (ex_reg_write_w),
        .ex_wb_sel    (ex_wb_sel_w),
        .ex_rd        (ex_rd_w),
        .reram_result (reram_result_w),
        .wb_reg_write (wb_reg_write_w),
        .wb_rd        (wb_rd_w),
        .wb_wdata     (rf_wdata),
        .fwd_val_wb   (fwd_val_wb_w)
    );

    assign rf_write = wb_reg_write_w;
    assign rf_rd    = wb_rd_w;

    // --- LED Status Indicators ---
    reg        done_flag;
    reg [31:0] cycle_count;

    always @(posedge clk) begin
        if (rst) begin
            done_flag   <= 1'b0;
            cycle_count <= 32'b0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (cycle_count >= 32'd2000)
                done_flag <= 1'b1;
        end
    end

    assign led[0] = done_flag;           // Processing complete
    assign led[1] = ex_reram_trigger_w;  // ReRAM MAC firing (blinks during edge detect)
    assign led[2] = branch_taken_w;      // Branch taken
    assign led[3] = stall_w;             // Pipeline stalled
endmodule
