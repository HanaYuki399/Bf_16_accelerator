`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/18/2023 09:58:43 PM
// Design Name: 
// Module Name: bfloatup_fmatb
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

module tb_bfloat16_fma;

    // Inputs
    reg clk;
    reg reset;
    reg [15:0] operand_a;
    reg [15:0] operand_b;
    reg [15:0] operand_c;
    reg [2:0] rnd_mode;

    // Outputs
    wire [15:0] result;
    wire invalid;
    wire overflow;
    wire underflow;
    wire inexact;

    // Instantiate the bfloat16_fma module
    bfloat16_fmasv uut (
        .clk(clk),
        .reset(reset),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .operand_c(operand_c),
        .rnd_mode(rnd_mode),
        .result(result),
        .invalid(invalid),
        .overflow(overflow),
        .underflow(underflow),
        .inexact(inexact)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock
    end

    // Reset pulse
    initial begin
        reset = 1;
        #20;
        reset = 0;
        #20;
        reset = 1;
        #20;
    end

    // Test scenarios
    initial begin
        // Initialize Inputs
        operand_a = 16'h3F80; // 1.0 in bfloat16
        operand_b = 16'h4000; // 2.0 in bfloat16
        operand_c = 16'h4040; // 3.0 in bfloat16
        
        
        #40
        
        operand_a = 16'hBE99; // 1.0 in bfloat16
        operand_b = 16'h43FA; // 2.0 in bfloat16
        operand_c = 16'h0;

        // Basic Functionality Test
        rnd_mode = 3'b000; // RNE: Round to Nearest, ties to Even
        #40;

        // Zero Test Cases
        operand_a = 16'h0000; // 0.0 in bfloat16
        operand_b = 16'h3F80; // 1.0 in bfloat16
        operand_c = 16'h4000; // 2.0 in bfloat16
        #40;

        // Infinity Test Cases
        operand_a = 16'h7F80; // Infinity in bfloat16
        operand_b = 16'h4000; // 2.0 in bfloat16
        operand_c = 16'hC000; // -2.0 in bfloat16
        #40;

        // NaN Test Cases
        operand_a = 16'h7FC0; // NaN in bfloat16
        operand_b = 16'h4000; // 2.0 in bfloat16
        operand_c = 16'h4040; // 3.0 in bfloat16
        #40;

        // Subnormal Number Test Cases
        operand_a = 16'h0080; // Smallest positive subnormal number in bfloat16
        operand_b = 16'h0080;
        operand_c = 16'h0080;
        #40;

        // Overflow and Underflow Test Cases
        operand_a = 16'h7F7F; // Largest normal number in bfloat16
        operand_b = 16'h7F7F;
        operand_c = 16'h7F7F;
        #40;

        // Rounding Test Cases
        // RNE: Round to Nearest, ties to Even
        rnd_mode = 3'b000;
        operand_a = 16'h3F00; // Just below 0.5 in bfloat16
        operand_b = 16'h3F00;
        operand_c = 16'h3F00;
        #40;

        // RTZ: Round towards Zero
        rnd_mode = 3'b001;
        operand_a = 16'h3F40; // Just above 0.75 in bfloat16
        operand_b = 16'h3F40;
        operand_c = 16'h3F40;
        #40;

        // RDN: Round Down (towards -∞)
        rnd_mode = 3'b010;
        operand_a = 16'hBF40; // Negative value just below -0.75 in bfloat16
        operand_b = 16'hBF40;
        operand_c = 16'hBF40;
        #40;

        // RUP: Round Up (towards +∞)
        rnd_mode = 3'b011;
        operand_a = 16'hBF00; // Negative value just above -0.5 in bfloat16
        operand_b = 16'hBF00;
        operand_c = 16'hBF00;
        #40;

        // RMM: Round to Nearest, ties to Max Magnitude
        rnd_mode = 3'b100;
        operand_a = 16'h3F80; // Exactly 0.5 in bfloat16
        operand_b = 16'h3F80;
        operand_c = 16'h3F80;
        #40;

        // ROD: Round towards odd
        rnd_mode = 3'b101;
        operand_a = 16'h3FC0; // Just below 1.0 in bfloat16
        operand_b = 16'h3FC0;
        operand_c = 16'h3FC0;
        #40;

        // Complete the tests
        $display("Testbench completed.");
        $finish;
    end

endmodule

