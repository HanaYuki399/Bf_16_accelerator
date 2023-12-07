`timescale 1ns / 1ps

module tb_fp32_to_bf16();

    // Testbench Signals
    reg clk;
    reg reset;
    reg instruction_enable; // Added enable signal
    reg [31:0] operand_a;
    wire [15:0] result;
    wire [3:0] fpcsr; // Updated for fpcsr register

    // Instantiate the Unit Under Test (UUT)
    fp32_to_bf16 uut (
        .clk(clk),
        .reset(reset),
        .instruction_enable(instruction_enable), // Added enable signal
        .operand_a(operand_a),
        .result(result),
        .fpcsr(fpcsr) // Updated for fpcsr register
    );

    // Clock generation
    always begin
        clk = 1; #10; clk = 0; #10;
    end

    // Test cases
    initial begin
        // Reset
        reset = 1; #20;
        reset = 0; #20;
        instruction_enable = 1; // Enable the instruction

        // Test 1: Normal number conversion
        operand_a = 32'h40490FDB; // PI in FP32
        #20; check_result("Normal Conversion");

        // Test 2: Zero
        operand_a = 32'h80000000; // Zero in FP32
        #20; check_result("Zero");

        // Test 3: Infinity
        operand_a = 32'hFF800000; // Positive Infinity in FP32
        #20; check_result("Positive Infinity");

        // Test 4: NaN
        operand_a = 32'hFFC00000; // NaN in FP32
        #20; check_result("NaN");

        // Test 5: Subnormal number
        operand_a = 32'h007FFFFF; // Max subnormal in FP32
        #20; check_result("Max Subnormal");

        // Test 6: Overflow
        operand_a = 32'h7F7FFFFF; // Largest normal FP32 number
        #20; check_result("Overflow");

        // Test 7: Underflow
        operand_a = 32'h00800000; // Smallest normal FP32 number
        #20; check_result("Underflow");

        // Test 8: Inexact due to rounding
        operand_a = 32'h3EAAAAAB; // Inexact due to rounding
        #20; check_result("Inexact Rounding");

        // End of test
        $finish;
    end

    // Check results and print messages
    task check_result;
        input [128*8:1] test_name;
        begin
            $display("%s: Result = %h, FPCSR = %b", test_name, result, fpcsr);
        end
    endtask

endmodule
