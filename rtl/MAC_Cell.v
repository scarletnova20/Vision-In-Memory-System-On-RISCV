`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.02.2026 16:33:39
// Design Name: 
// Module Name: MAC_Cell
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

module MAC_Cell (
    input  [7:0]  pixel,    // Unsigned 8-bit pixel value (0-255)
    input  [7:0]  weight,   // Signed 8-bit Sobel weight (2's complement)
    output [15:0] product   // Signed 16-bit result
);
    // Sign-extend pixel to 16-bit signed before multiply
    wire signed [15:0] pixel_s  = {1'b0, pixel, 7'b0} >> 7; // zero-extend
    wire signed [7:0]  weight_s = weight;

    assign product = $signed({1'b0, pixel}) * $signed(weight_s);
endmodule


// ============================================================
// MODULE 2: 9-INPUT ADDER TREE
// Adds 9 signed 16-bit products → signed 20-bit sum
// Tree structure: 9 → 5 → 3 → 2 → 1
// Vivado maps this to carry-chain LUTs efficiently
// ============================================================
module AdderTree9 (
    input  signed [15:0] p0, p1, p2,
    input  signed [15:0] p3, p4, p5,
    input  signed [15:0] p6, p7, p8,
    output signed [19:0] sum
);
    // Level 1: add pairs
    wire signed [16:0] s01 = {p0[15], p0} + {p1[15], p1};
    wire signed [16:0] s23 = {p2[15], p2} + {p3[15], p3};
    wire signed [16:0] s45 = {p4[15], p4} + {p5[15], p5};
    wire signed [16:0] s67 = {p6[15], p6} + {p7[15], p7};

    // Level 2: add pairs of pairs
    wire signed [17:0] s0123 = {s01[16], s01} + {s23[16], s23};
    wire signed [17:0] s4567 = {s45[16], s45} + {s67[16], s67};

    // Level 3: add with p8
    wire signed [18:0] s01234567 = {s0123[17], s0123} + {s4567[17], s4567};

    // Final: add last element
    assign sum = {s01234567[18], s01234567} + {{4{p8[15]}}, p8};
endmodule


// ============================================================
// MODULE 3: ReRAM ACCELERATOR - MAIN MODULE
// State machine: IDLE → LOAD → MAC_GX → MAC_GY → DONE
// ============================================================
module ReRAM_Accelerator (
    input         clk,
    input         rst,
    input         trigger,          // From EX stage pipeline register
    input  [71:0] pixel_window,     // 9 pixels packed: p00..p22 (MSB=p00)
    input  [71:0] filter_weights,   // unused - weights are hardcoded
    output [31:0] result,           // Edge strength (combinational)
    output        done              // mirrors trigger
);

    // Unpack pixels directly from the 72-bit bus (combinational)
    wire [7:0] p00 = pixel_window[71:64];
    wire [7:0] p01 = pixel_window[63:56];
    wire [7:0] p02 = pixel_window[55:48];
    wire [7:0] p10 = pixel_window[47:40];
    wire [7:0] p11 = pixel_window[39:32];
    wire [7:0] p12 = pixel_window[31:24];
    wire [7:0] p20 = pixel_window[23:16];
    wire [7:0] p21 = pixel_window[15:8];
    wire [7:0] p22 = pixel_window[7:0];

    // Hardcoded Sobel Gx weights
    wire signed [7:0] gx00 = -8'sd1, gx01 = 8'sd0, gx02 = 8'sd1;
    wire signed [7:0] gx10 = -8'sd2, gx11 = 8'sd0, gx12 = 8'sd2;
    wire signed [7:0] gx20 = -8'sd1, gx21 = 8'sd0, gx22 = 8'sd1;

    // Hardcoded Sobel Gy weights
    wire signed [7:0] gy00 = -8'sd1, gy01 = -8'sd2, gy02 = -8'sd1;
    wire signed [7:0] gy10 =  8'sd0, gy11 =  8'sd0, gy12 =  8'sd0;
    wire signed [7:0] gy20 =  8'sd1, gy21 =  8'sd2, gy22 =  8'sd1;

    // 9 parallel MAC cells for Gx
    wire [15:0] gx_p00, gx_p01, gx_p02;
    wire [15:0] gx_p10, gx_p11, gx_p12;
    wire [15:0] gx_p20, gx_p21, gx_p22;

    MAC_Cell mac_gx00 (.pixel(p00), .weight(gx00), .product(gx_p00));
    MAC_Cell mac_gx01 (.pixel(p01), .weight(gx01), .product(gx_p01));
    MAC_Cell mac_gx02 (.pixel(p02), .weight(gx02), .product(gx_p02));
    MAC_Cell mac_gx10 (.pixel(p10), .weight(gx10), .product(gx_p10));
    MAC_Cell mac_gx11 (.pixel(p11), .weight(gx11), .product(gx_p11));
    MAC_Cell mac_gx12 (.pixel(p12), .weight(gx12), .product(gx_p12));
    MAC_Cell mac_gx20 (.pixel(p20), .weight(gx20), .product(gx_p20));
    MAC_Cell mac_gx21 (.pixel(p21), .weight(gx21), .product(gx_p21));
    MAC_Cell mac_gx22 (.pixel(p22), .weight(gx22), .product(gx_p22));

    // 9 parallel MAC cells for Gy
    wire [15:0] gy_p00, gy_p01, gy_p02;
    wire [15:0] gy_p10, gy_p11, gy_p12;
    wire [15:0] gy_p20, gy_p21, gy_p22;

    MAC_Cell mac_gy00 (.pixel(p00), .weight(gy00), .product(gy_p00));
    MAC_Cell mac_gy01 (.pixel(p01), .weight(gy01), .product(gy_p01));
    MAC_Cell mac_gy02 (.pixel(p02), .weight(gy02), .product(gy_p02));
    MAC_Cell mac_gy10 (.pixel(p10), .weight(gy10), .product(gy_p10));
    MAC_Cell mac_gy11 (.pixel(p11), .weight(gy11), .product(gy_p11));
    MAC_Cell mac_gy12 (.pixel(p12), .weight(gy12), .product(gy_p12));
    MAC_Cell mac_gy20 (.pixel(p20), .weight(gy20), .product(gy_p20));
    MAC_Cell mac_gy21 (.pixel(p21), .weight(gy21), .product(gy_p21));
    MAC_Cell mac_gy22 (.pixel(p22), .weight(gy22), .product(gy_p22));

    // Adder trees (combinational)
    wire signed [19:0] gx_sum, gy_sum;

    AdderTree9 adder_gx (
        .p0(gx_p00), .p1(gx_p01), .p2(gx_p02),
        .p3(gx_p10), .p4(gx_p11), .p5(gx_p12),
        .p6(gx_p20), .p7(gx_p21), .p8(gx_p22),
        .sum(gx_sum)
    );

    AdderTree9 adder_gy (
        .p0(gy_p00), .p1(gy_p01), .p2(gy_p02),
        .p3(gy_p10), .p4(gy_p11), .p5(gy_p12),
        .p6(gy_p20), .p7(gy_p21), .p8(gy_p22),
        .sum(gy_sum)
    );

    // |Gx| + |Gy|, clamp to 255
    wire signed [19:0] gx_abs = gx_sum[19] ? (-gx_sum) : gx_sum;
    wire signed [19:0] gy_abs = gy_sum[19] ? (-gy_sum) : gy_sum;
    wire        [20:0] edge_sum = {1'b0, gx_abs} + {1'b0, gy_abs};
    wire [7:0] edge_clamped = (edge_sum > 21'd255) ? 8'hFF : edge_sum[7:0];

    // Result is available immediately (combinational)
    assign result = trigger ? {24'b0, edge_clamped} : 32'b0;
    assign done   = trigger;

endmodule


// ============================================================
// TESTBENCH - ReRAM Accelerator only
// Use this to verify accelerator independently before
// integrating with the full pipeline.
// Add as Simulation Source in Vivado.
// ============================================================
module tb_ReRAM_Accelerator;

    reg         clk, rst, trigger;
    reg  [71:0] pixel_window;
    reg  [71:0] filter_weights;
    wire [31:0] result;
    wire        done;

    ReRAM_Accelerator dut (
        .clk           (clk),
        .rst           (rst),
        .trigger       (trigger),
        .pixel_window  (pixel_window),
        .filter_weights(filter_weights),
        .result        (result),
        .done          (done)
    );

    // 25 MHz clock (40ns period - matches pipeline clock)
    initial clk = 0;
    always #20 clk = ~clk;

    // Waveform dump
    initial begin
        $dumpfile("reram_wave.vcd");
        $dumpvars(0, tb_ReRAM_Accelerator);
    end

    initial begin
        // -----------------------------------------------
        // Reset
        // -----------------------------------------------
        rst            = 1;
        trigger        = 0;
        pixel_window   = 72'b0;
        filter_weights = 72'b0;

        repeat(3) @(posedge clk);
        rst = 0;

        // -----------------------------------------------
        // TEST 1: Vertical edge
        // Image patch (3x3):
        //   0   0  255
        //   0   0  255
        //   0   0  255
        // Expected: Strong Gx, Gy≈0 → large edge value
        // -----------------------------------------------
        @(posedge clk);
        pixel_window = {
            8'd0,   8'd0,   8'd255,   // Row 0
            8'd0,   8'd0,   8'd255,   // Row 1
            8'd0,   8'd0,   8'd255    // Row 2
        };
        filter_weights = 72'b0;   // Not used - weights hardcoded in module
        trigger = 1;

        @(posedge clk);
        trigger = 0;

        // Wait for done
        wait(done == 1);
        @(posedge clk);
        $display("TEST 1 - Vertical Edge");
        $display("  Pixel window: 0,0,255 | 0,0,255 | 0,0,255");
        $display("  Result (edge strength) = %0d  (expected ~1020)", result);
        $display("  done = %b", done);

        repeat(2) @(posedge clk);

        // -----------------------------------------------
        // TEST 2: Horizontal edge
        // Image patch:
        //   0    0    0
        //   0    0    0
        //  255  255  255
        // Expected: Gy large, Gx≈0
        // -----------------------------------------------
        @(posedge clk);
        pixel_window = {
            8'd0,   8'd0,   8'd0,
            8'd0,   8'd0,   8'd0,
            8'd255, 8'd255, 8'd255
        };
        trigger = 1;

        @(posedge clk);
        trigger = 0;

        wait(done == 1);
        @(posedge clk);
        $display("TEST 2 - Horizontal Edge");
        $display("  Pixel window: 0,0,0 | 0,0,0 | 255,255,255");
        $display("  Result (edge strength) = %0d  (expected ~1020)", result);

        repeat(2) @(posedge clk);

        // -----------------------------------------------
        // TEST 3: Flat region (no edge)
        // All pixels = 128
        // Expected: Gx=0, Gy=0, result=0
        // -----------------------------------------------
        @(posedge clk);
        pixel_window = {
            8'd128, 8'd128, 8'd128,
            8'd128, 8'd128, 8'd128,
            8'd128, 8'd128, 8'd128
        };
        trigger = 1;

        @(posedge clk);
        trigger = 0;

        wait(done == 1);
        @(posedge clk);
        $display("TEST 3 - Flat Region (no edge)");
        $display("  All pixels = 128");
        $display("  Result (edge strength) = %0d  (expected 0)", result);

        repeat(2) @(posedge clk);

        // -----------------------------------------------
        // TEST 4: Diagonal edge
        // -----------------------------------------------
        @(posedge clk);
        pixel_window = {
            8'd255, 8'd128, 8'd0,
            8'd128, 8'd128, 8'd128,
            8'd0,   8'd128, 8'd255
        };
        trigger = 1;

        @(posedge clk);
        trigger = 0;

        wait(done == 1);
        @(posedge clk);
        $display("TEST 4 - Diagonal Pattern");
        $display("  Result (edge strength) = %0d", result);

        repeat(2) @(posedge clk);

        // -----------------------------------------------
        // TEST 5: Maximum contrast
        // Checkerboard: 0,255,0 / 255,0,255 / 0,255,0
        // Expected: clamped to 255
        // -----------------------------------------------
        @(posedge clk);
        pixel_window = {
            8'd0,   8'd255, 8'd0,
            8'd255, 8'd0,   8'd255,
            8'd0,   8'd255, 8'd0
        };
        trigger = 1;

        @(posedge clk);
        trigger = 0;

        wait(done == 1);
        @(posedge clk);
        $display("TEST 5 - Maximum Contrast Checkerboard");
        $display("  Result (edge strength) = %0d  (expected 255, clamped)", result);

        $display("=== All ReRAM Accelerator Tests Complete ===");
        $finish;
    end

    // Per-cycle monitor
    initial begin
        $monitor("t=%0t | state=%0d | trigger=%b | done=%b | result=%0d",
                  $time,
                  dut.state,
                  trigger,
                  done,
                  result);
    end

endmodule
