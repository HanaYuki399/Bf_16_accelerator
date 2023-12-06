`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/27/2023 12:59:18 PM
// Design Name: 
// Module Name: fp32bf16cvt
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


module fp32_to_bf16(
    input logic clk,
    input logic reset,
    input logic [31:0] operand_a, // FP32 input
    output logic [15:0] result,   // BF16 output
    output logic invalid,         // Invalid operation flag
    output logic overflow,        // Overflow flag
    output logic underflow,       // Underflow flag
    output logic inexact          // Inexact result flag
);

    // Extract fields from FP32 operand
    logic operand_a_sign;
    logic [8:0] operand_a_exp;  // 8-bit exponent plus one for overflow
    logic [22:0] operand_a_man;

    assign operand_a_sign = operand_a[31];
    assign operand_a_exp = {1'b0, operand_a[30:23]}; // Zero-extended for calculations
    assign operand_a_man = operand_a[22:0];

    // Special case flags
    logic operand_a_inf, operand_a_zero, operand_a_nan, operand_a_subnormal;

    assign operand_a_inf = (operand_a_exp == 9'h0FF) && (operand_a_man == 0);
    assign operand_a_zero = (operand_a_exp == 0) && (operand_a_man == 0);
    assign operand_a_nan = (operand_a_exp == 9'h0FF) && (operand_a_man != 0);
    assign operand_a_subnormal = (operand_a_exp == 0) && (operand_a_man != 0);

    // Handling special cases
    always_comb begin
        invalid = operand_a_nan; // NaN input is invalid
        overflow = operand_a_inf;            
        underflow = operand_a_subnormal; // Subnormal input may underflow
        inexact = 0;             // Default to no inexact result

        // Default output for special cases
        if (operand_a_inf) begin
            result = {operand_a_sign, 8'hFF, 7'h00}; // Infinity
            overflow = 1; // Set overflow flag
        end else if (operand_a_zero) begin
            result = {operand_a_sign, 8'h00, 7'h00}; // Zero
        end else if (operand_a_nan) begin
            result = {1'b0, 8'hFF, 7'hc0}; // NaN
            
        end else begin
            result = convert_to_bf16(operand_a_sign, operand_a_exp, operand_a_man);
        end
    end

    // Function to convert FP32 to BF16 with RNE rounding
function automatic [15:0] convert_to_bf16(
    input logic sign,
    input logic [9:0] exp,
    input logic [22:0] man
);
    logic [9:0] new_exp;
    logic [6:0] new_man;
    logic rounding_bit, sticky_bit, guard_bit, round_up;

    // Alignment for BF16 mantissa (truncate 16 LSBs, keep guard bit)
    guard_bit = man[15];
    rounding_bit = man[14];
    sticky_bit = |man[13:0]; // OR all truncated bits for sticky bit

    // Check for rounding using RNE
    round_up = guard_bit & (sticky_bit | guard_bit | new_man[0]);

    new_exp = exp; // Adjust exponent from FP32 to BF16 bias
    new_man = man[22:16]; // Truncate mantissa to BF16 precision

    // Apply rounding
    if (round_up) begin
        // Check for overflow in mantissa before incrementing
        if (new_man == 7'h7F) begin
            new_exp = new_exp + 1; // Increment exponent due to mantissa overflow
            new_man = 0; // Reset mantissa to 0 because of overflow
        end else begin
            new_man = new_man + 1; // Increment mantissa
        end
    end

    // Check for exponent overflow or underflow
    if (new_exp >= 9'h0FF) begin
        overflow = 1; // Set overflow flag
        new_exp = 9'h0FF; // Cap at largest normal value
        //new_man = 7'h7F; // Set mantissa to max
    end else if (new_exp <= 0) begin
        underflow = 1; // Set underflow flag
        new_exp = 0; // Subnormals and zero
        new_man = 0;
    end

    // Set inexact if any LSBs are truncated or guard, round, sticky bits are set
    inexact = guard_bit | rounding_bit | sticky_bit;

    convert_to_bf16 = {sign, new_exp[7:0], new_man[6:0]}; // Assemble BF16 number
endfunction

endmodule
