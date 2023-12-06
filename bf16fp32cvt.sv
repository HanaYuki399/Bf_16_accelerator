`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/01/2023 12:33:06 AM
// Design Name: 
// Module Name: bf16fp32cvt
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


module bf16_to_fp32(
    input logic clk,
    input logic reset,
    input logic [15:0] operand_a, // BF16 input
    output logic [31:0] result,   // FP32 output
    output logic invalid,         // Invalid operation flag
    output logic overflow,        // Overflow flag
    output logic underflow,       // Underflow flag
    output logic inexact          // Inexact result flag
);

    // Extract fields from BF16 operand
    logic operand_a_sign;
    logic [7:0] operand_a_exp; // 8-bit exponent
    logic [6:0] operand_a_man;

    assign operand_a_sign = operand_a[15];
    assign operand_a_exp = operand_a[14:7];
    assign operand_a_man = operand_a[6:0];

    // Special case flags
    logic operand_a_inf, operand_a_zero, operand_a_nan;

    assign operand_a_inf = (operand_a_exp == 8'hFF) && (operand_a_man == 0);
    assign operand_a_zero = (operand_a_exp == 0) && (operand_a_man == 0);
    assign operand_a_nan = (operand_a_exp == 8'hFF) && (operand_a_man != 0);

    // Handling special cases
    always_comb begin
        invalid = operand_a_nan; // NaN input is invalid
        overflow = 0; // No overflow in BF16 to FP32 conversion
        underflow = 0; // No underflow in BF16 to FP32 conversion
        inexact = 0; // No inexact result in BF16 to FP32 conversion

        // Default output for special cases
        if (operand_a_inf) begin
            result = {operand_a_sign, 8'hFF, 23'h000000}; // Infinity
        end else if (operand_a_zero) begin
            result = {operand_a_sign, 8'h00, 23'h000000}; // Zero
        end else if (operand_a_nan) begin
            result = {1'b0, 8'hFF, {1'b1, 22'h00000}}; // NaN
        end else begin
            result = convert_to_fp32(operand_a_sign, operand_a_exp, operand_a_man);
        end
    end

    // Function to convert BF16 to FP32
    function automatic [31:0] convert_to_fp32(
        input logic sign,
        input logic [7:0] exp,
        input logic [6:0] man
    );
        logic [7:0] new_exp;
        logic [22:0] new_man;

        new_exp = exp; // Directly use exponent from BF16
        new_man = {man, 16'h0000}; // Zero-extend mantissa from BF16 to FP32

        convert_to_fp32 = {sign, new_exp, new_man}; // Assemble FP32 number
    endfunction

endmodule
