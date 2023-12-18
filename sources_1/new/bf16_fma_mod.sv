`timescale 1ns / 1ps

module bf16_fma(
    input logic clk,
    input logic reset,
    input logic enable,
    input logic [15:0] operand_a,
    input logic [15:0] operand_b,
    input logic [15:0] operand_c,
    input logic [2:0] operation, // Operation code
    output logic [15:0] result,
    output logic [3:0] fpcsr
);

    // bfloat16 specifications
    localparam EXP_BITS = 8;
    localparam MAN_BITS = 7;
    localparam TOTAL_MAN_BITS = 2 * MAN_BITS + 16 + 2; // Total bits for extended mantissa
    localparam BIAS = 127;

    // Decompose operands
    logic [EXP_BITS-1:0] exp_a, exp_b, exp_c;
    logic [MAN_BITS:0] man_a, man_b; // Including implicit bit
    logic [MAN_BITS-1:0] man_c;
    logic sign_a, sign_b, sign_c;
    logic effective_subtraction;

    // Product and Sum variables
    logic [TOTAL_MAN_BITS-1:0] aligned_product_mantissa; // Extended product mantissa
    logic [2*MAN_BITS+1:0] product_mantissa;
    logic [TOTAL_MAN_BITS-1:0] aligned_addend_mantissa;
    logic [TOTAL_MAN_BITS:0] sum_mantissa; //In case off overflow
    logic [TOTAL_MAN_BITS+1:0] aligned_sum_mantissa; //for ground bit
    logic [MAN_BITS:0] result_mantissa; //MSB for overflow
    logic [EXP_BITS:0] product_exp, aligned_addend_exp, sum_exp;
    logic product_sign, sum_sign;

    // Rounding variables
    logic round_bit, sticky_bit;
    reg [4:0] i;

    always @(posedge clk or posedge reset) begin
    
    if (reset) begin
            result = 16'b0;
            fpcsr = 4'b0000;
        end
        // Decompose operands
        else if (enable) begin
        exp_a = operand_a[14:7];
        exp_b = operand_b[14:7];
        exp_c = operand_c[14:7];
        man_a = {1'b1, operand_a[6:0]}; // Include implicit bit
        man_b = {1'b1, operand_b[6:0]};
        man_c = operand_c[6:0];
        sign_a = operand_a[15];
        sign_b = operand_b[15];
        sign_c = operand_c[15];
        i = 0;

        // Adjust operands based on the operation
        case (operation)
            4'b0111: ; // FMADD: Do nothing
            4'b1000: sign_c = ~sign_c; // FMSUB: Invert sign of operand C
            4'b1010: sign_a = ~sign_a; // FNMSUB: Invert sign of operand A
            4'b1001: begin // FNMADD: Invert sign of operands A and C
                sign_a = ~sign_a;
                sign_c = ~sign_c;
            end
            4'b0100: begin // ADD: Set operand A to +1.0
                exp_a = BIAS;
                man_a = {1'b1, {MAN_BITS{1'b0}}};
                sign_a = 1'b0;
            end
            4'b0110: begin // SUB: Set operand A to +1.0, invert sign of operand C
                exp_a = BIAS;
                man_a = {1'b1, {MAN_BITS{1'b0}}};
                sign_a = 1'b0;
                sign_c = ~sign_c;
            end
            4'b0101: begin // MUL: Set operand C to +0.0
                exp_c = 0;
                man_c = {MAN_BITS{1'b0}};
                sign_c = 1'b0;
            end
            default: ; // Other operations: no change
        endcase

        // Calculate product of a and b with extended mantissa
        product_mantissa = man_a * man_b;
        product_exp = exp_a + exp_b - BIAS;
        if (product_mantissa[2*MAN_BITS+1] == 1) begin
            product_exp = product_exp + 1;
        end
        else begin
            product_mantissa = product_mantissa << 1;
        end
        aligned_product_mantissa = {product_mantissa, 16'b0};
        //product_exp = exp_a + exp_b - BIAS;
        product_sign = sign_a ^ sign_b;

        // Align addend (operand_c) with product
        aligned_addend_exp = exp_c;
        aligned_addend_mantissa = {1'b1, man_c, {(TOTAL_MAN_BITS - MAN_BITS - 1){1'b0}}}; // Extend addend mantissa

        // Align addend exponent with product exponent
        if (aligned_addend_exp < product_exp) begin
            aligned_addend_mantissa = aligned_addend_mantissa >> (product_exp - aligned_addend_exp);
            aligned_addend_exp = product_exp;
        end else if (aligned_addend_exp > product_exp) begin
            aligned_product_mantissa = aligned_product_mantissa >> (aligned_addend_exp - product_exp);
            product_exp = aligned_addend_exp;
        end

        // Determine if operation is effectively a subtraction
        effective_subtraction = (product_sign != sign_c);
        
        // Add/Subtract product and addend
        if (effective_subtraction) begin
            if (aligned_product_mantissa >= aligned_addend_mantissa) begin
                sum_mantissa = aligned_product_mantissa - aligned_addend_mantissa;
                sum_sign = product_sign;
            end else begin
                sum_mantissa = aligned_addend_mantissa - aligned_product_mantissa;
                sum_sign = sign_c;
            end
        end else begin
            sum_mantissa = aligned_product_mantissa + aligned_addend_mantissa;
            sum_sign = product_sign;
        end
        sum_exp = product_exp;
        aligned_sum_mantissa =  {sum_mantissa, 1'b0};
        // Normalize result
        if (aligned_sum_mantissa[TOTAL_MAN_BITS+1] == 1'b1) begin
            sum_exp = sum_exp + 1;
            aligned_sum_mantissa = aligned_sum_mantissa >> 1;
        end
        else if (aligned_sum_mantissa == 0) begin
            sum_exp = 0;
        end
        
        else begin
//        while (i < TOTAL_MAN_BITS && sum_exp > 0 && !aligned_sum_mantissa[TOTAL_MAN_BITS]) begin
//             aligned_sum_mantissa = aligned_sum_mantissa << 1;
//             sum_exp = sum_exp - 1;
//             i = i + 1;
//        end
        for (i = 0; i < TOTAL_MAN_BITS && sum_exp > 0 && !aligned_sum_mantissa[TOTAL_MAN_BITS]; i = i + 1) begin
        aligned_sum_mantissa = aligned_sum_mantissa << 1;
        sum_exp = sum_exp - 1;
        end
        end
        
//        while (sum_mantissa[TOTAL_MAN_BITS - 1] == 0 && sum_exp > 0 ) begin
//            sum_mantissa = sum_mantissa << 1;
//            sum_exp = sum_exp - 1;
//        end

        // Round (Round to Nearest, ties to Even)
        round_bit = aligned_sum_mantissa[0];
        sticky_bit = |aligned_sum_mantissa[TOTAL_MAN_BITS - 1:0]; // OR all bits below round bit
        result_mantissa = aligned_sum_mantissa[TOTAL_MAN_BITS - 1:TOTAL_MAN_BITS - 7];
        if (round_bit && (aligned_sum_mantissa[MAN_BITS] || sticky_bit)) begin
            result_mantissa = result_mantissa + 1;
            if (result_mantissa[MAN_BITS]) begin               
                sum_exp = sum_exp + 1;
            end
        end

        // Handle overflow and underflow
        if (sum_exp >= 2**EXP_BITS) begin
            fpcsr[2] = 1'b1;
            result = {sum_sign, 8'hFF, 7'h00}; // Infinity
        end else if (sum_exp <= 0) begin
            fpcsr[1] = 1'b1;
            result = {sum_sign, 8'h00, 7'h00}; // Zero (subnormals flushed to zero)
        end else begin
            result = {sum_sign, sum_exp[7:0], result_mantissa[6:0]};
        end

        // Set inexact flag if any of the lower bits were non-zero
        fpcsr[0] = round_bit || sticky_bit;
        //invalid = 0; // No invalid operation in simple FMA
    end
    end
endmodule
