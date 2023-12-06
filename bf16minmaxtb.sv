`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/02/2023 11:59:21 PM
// Design Name: 
// Module Name: bf16minmaxtb
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

module tb_bf16_minmax;

    // Inputs
    reg clk;
    reg reset;
    reg [15:0] operand_a;
    reg [15:0] operand_b;
    reg min_max_select; // 0 for min, 1 for max

    // Outputs
    wire [15:0] result;
    wire invalid;
    wire overflow;
    wire underflow;
    wire inexact;

    // Instantiate the Unit Under Test (UUT)
    bf16_minmax uut (
        .clk(clk), 
        .reset(reset), 
        .operand_a(operand_a), 
        .operand_b(operand_b), 
        .operation(min_max_select), 
        .result(result)

    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        operand_a = 0;
        operand_b = 0;
        min_max_select = 0;

        // Wait for global reset
        #100;
        reset = 0;

        // Test case 1: Normal numbers
        operand_a = 16'h4000; // 2.0
        operand_b = 16'h3C00; // 1.0
        min_max_select = 0; // min
        #10;

        // Test case 2: Special values (Infinity and NaN)
        operand_a = 16'h7C00; // Infinity
        operand_b = 16'h7E00; // NaN
        min_max_select = 1; // max
        #10;

        // Test case 3: Subnormal numbers
        operand_a = 16'h0380; // Small subnormal
        operand_b = 16'h0400; // Slightly larger subnormal
        min_max_select = 0; // min
        #10;

        // Test case 4: Equal operands
        operand_a = 16'h3555; // Some BF16 number
        operand_b = 16'h3555; // Same number
        min_max_select = 1; // max
        #10;

        // Test case 5: Overflow and underflow
        operand_a = 16'h7F80; // Largest BF16 number
        operand_b = 16'h0080; // Smallest BF16 number
        min_max_select = 1; // max
        #10;

        // Test case 6: Sign difference
        operand_a = 16'hC000; // -2.0
        operand_b = 16'h4000; // 2.0
        min_max_select = 0; // min
        #10;

        // Add more test cases as needed

        // Finish the simulation
        $finish;
    end
      
endmodule

