`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/11/2023 01:18:15 AM
// Design Name: 
// Module Name: fma_tb
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

module testbench;

    // Testbench signals
    reg [15:0] a, b, c;
    wire [15:0] result;

    // Instantiate the bfloat16_fma module
    bfloat16_fmasv uut (
        .a(a),
        .b(b),
        .c(c),
        .result(result)
    );

    initial begin
        // Initialize inputs
        a = 0; b = 0; c = 0;

        // Normal operation: 1.0 * 2.0 + 3.0 = 5.0 (0x40A0)
        a = 16'h3F80; b = 16'h4000; c = 16'h4040;
        #10; $display("Normal Operation: Result = %h", result); // Expected: 0x40A0

        // Zero value multiplication: 0.0 * 2.0 + 3.0 = 3.0 (0x4040)
        a = 16'h0000; b = 16'h4000; c = 16'h4040;
        #10; $display("Zero Multiplication: Result = %h", result); // Expected: 0x4040

        // Infinity: Inf * 1.0 - 3.0 = Inf (0x7F80)
        a = 16'h7F80; b = 16'h3F80; c = 16'hC040;
        #10; $display("Infinity: Result = %h", result); // Expected: 0x7F80

        // NaN: NaN * 1.0 + 3.0 = NaN (0x7FC0)
        a = 16'h7FC0; b = 16'h3F80; c = 16'h4040;
        #10; $display("NaN: Result = %h", result); // Expected: 0x7FC0

        // Subnormal number: Might underflow, result depends on handling (0x0000 or small non-zero)
        a = 16'h0080; b = 16'h0100; c = 16'h3F80;
        #10; $display("Subnormal: Result = %h", result); // Expected: Depends on underflow handling

        // Overflow: Large numbers, might overflow, result is Inf (0x7F80)
        a = 16'h7F7F; b = 16'h7F7F; c = 16'h0000;
        #10; $display("Overflow: Result = %h", result); // Expected: 0x7F80

        // Underflow: Very small numbers, might underflow, result is 0x0000 or small non-zero
        a = 16'h0001; b = 16'h0001; c = 16'h0000;
        #10; $display("Underflow: Result = %h", result); // Expected: 0x0000 or small non-zero

        // Negative numbers: -1.0 * -2.0 + 2.0 = 4.0 (0x4080)
        a = 16'hBF80; b = 16'hC000; c = 16'h4000;
        #10; $display("Negative Numbers: Result = %h", result); // Expected: 0x4080

        // Rounding edge case: 0.5 * 0.25 + very small number, result close to 0.125 (0x3F00)
        a = 16'h3F00; b = 16'h3E80; c = 16'h0001;
        #10; $display("Rounding Edge Case: Result = %h", result); // Expected: ~0x3F00

        // Finish simulation
        $finish;
    end

endmodule



