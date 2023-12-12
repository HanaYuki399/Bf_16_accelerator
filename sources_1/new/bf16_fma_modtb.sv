`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/10/2023 03:18:40 AM
// Design Name: 
// Module Name: bf16_fma_modtb
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

module tb_bf16_fma;

    // Inputs
    reg clk;
    reg reset;
    reg [15:0] operand_a;
    reg [15:0] operand_b;
    reg [15:0] operand_c;

    // Outputs
    wire [15:0] result;
    wire invalid;
    wire overflow;
    wire underflow;
    wire inexact;

    // Instantiate the Unit Under Test (UUT)
    bf16_fma uut (
        .clk(clk),
        .reset(reset),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .operand_c(operand_c),
        .result(result),
        .invalid(invalid),
        .overflow(overflow),
        .underflow(underflow),
        .inexact(inexact)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        reset = 1;
        operand_a = 0;
        operand_b = 0;
        operand_c = 0;

        // Wait for global reset
        #100;
        reset = 0;

        // Test case 1: Normal operation
        operand_a = 16'h3f80; // 1.0
        operand_b = 16'h4000; // 2.0
        operand_c = 16'h40a0; // 3.0
        #10; // Result should be 1.0*2.0 + 5.0 = 7.0 (0x40e0)

        // Explanation:
        // a = 1.0 (3C00), b = 2.0 (4000), c = 3.0 (4200)
        // product = 1.0 * 2.0 = 2.0
        // sum = product + c = 2.0 + 3.0 = 5.0
        // result = 5.0 (4500)
        
        // Test case 1: Normal operation
        operand_a = 16'h4080; // 1.0
        operand_b = 16'h4000; // 2.0
        operand_c = 16'h40c0; // 3.0
        #10; // Result should be 1.0*2.0 + 5.0 = 7.0 (0x40e0)

        // Test case 2: Underflow
        operand_a = 16'h0001; // Smallest subnormal number
        operand_b = 16'h0001; // Smallest subnormal number
        operand_c = 16'h0001; // Smallest subnormal number
        #10; // Result should be underflow to zero

        // Explanation:
        // a = smallest subnormal, b = smallest subnormal, c = smallest subnormal
        // product = subnormal * subnormal = underflow (flushed to zero)
        // sum = product + c = 0 + subnormal = subnormal
        // result = underflow (flushed to zero)

        // Test case 3: Overflow
        operand_a = 16'h7F80; // Infinity
        operand_b = 16'h3C00; // 1.0
        operand_c = 16'h4200; // 3.0
        #10; // Result should be infinity (0x7F80)

        // Explanation:
        // a = infinity, b = 1.0, c = 3.0
        // product = infinity * 1.0 = infinity
        // sum = product + c = infinity + 3.0 = infinity
        // result = infinity (7F80)

        // Finish the simulation
        $finish;
    end

endmodule

