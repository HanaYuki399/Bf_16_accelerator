`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/01/2023 12:37:16 AM
// Design Name: 
// Module Name: bf16fp32cvttb
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
`timescale 1ns / 1ps

module tb_bf16_to_fp32();

    // Inputs
    reg clk;
    reg reset;
    reg instruction_enable;
    reg [15:0] operand_a;

    // Outputs
    wire [31:0] result;
    wire [3:0] fpcsr; // Updated for fpcsr register

    // Instantiate the Unit Under Test (UUT)
    bf16_to_fp32 uut (
        .clk(clk),
        .reset(reset),
        .instruction_enable(instruction_enable), // Added enable signal
        .operand_a(operand_a),
        .result(result),
        .fpcsr(fpcsr) // Updated for fpcsr register
    );

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        instruction_enable = 1; // Enable the instruction
        operand_a = 0;

        // Wait 100 ns for global reset
        #100;
        reset = 0;

        // Add stimulus here
        // Test: Zero
        operand_a = 16'h0000; // BF16 Zero
        #10;

        // Test: Infinity
        operand_a = 16'h7F80; // BF16 Positive Infinity
        #10;

        // Test: Negative Infinity
        operand_a = 16'hFF80; // BF16 Negative Infinity
        #10;

        // Test: NaN
        operand_a = 16'h7FC0; // BF16 NaN
        #10;

        // Test: Normal Number
        operand_a = 16'h3C00; // BF16 1.0
        #10;

        // Test: Another Normal Number
        operand_a = 16'h3555; // BF16 Some positive value
        #10;

        // Test: Negative Number
        operand_a = 16'hB555; // BF16 Some negative value
        #10;

        // Test: Smallest Subnormal
        operand_a = 16'h0001; // BF16 Smallest Subnormal
        #10;
    end

    // Clock generation
    always #5 clk = ~clk;

endmodule

