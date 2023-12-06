module bfloat16_fmasv(
    input logic clk,
    input logic reset,
    input logic [15:0] operand_a,
    input logic [15:0] operand_b,
    input logic [15:0] operand_c,
    input logic [2:0] rnd_mode, // Rounding mode
    output logic [15:0] result,
    output logic invalid,       // Invalid operation flag
    output logic overflow,      // Overflow flag
    output logic underflow,     // Underflow flag
    output logic inexact        // Inexact result flag
);

    // bfloat16 specifications
    localparam EXP_BITS = 8;
    localparam MAN_BITS = 7;
    localparam TOTAL_BITS = 16; // Including sign bit
    localparam BIAS = 127;

    // Extracting fields from operands
    logic operand_a_sign, operand_b_sign, operand_c_sign;
    logic [EXP_BITS-1:0] operand_a_exp, operand_b_exp, operand_c_exp;
    logic [MAN_BITS:0] operand_a_man, operand_b_man; // Including implicit bit
    logic [MAN_BITS-1:0] operand_c_man;

    // Special case flags
    logic operand_a_inf, operand_b_inf, operand_c_inf;
    logic operand_a_zero, operand_b_zero, operand_c_zero;
    logic operand_a_nan, operand_b_nan, operand_c_nan;

    // Intermediate variables for FMA operation
    logic [2*MAN_BITS+1:0] product; // Product of mantissas
    logic [EXP_BITS:0] sum_exp;     // Sum of exponents
    logic [2*MAN_BITS+2:0] addend;  // Extended addend (operand_c)
    logic [2*MAN_BITS+2:0] sum;     // Sum of product and operand C
    logic sum_sign;
    logic [EXP_BITS-1:0] final_exp;
    logic [MAN_BITS-1:0] final_man;

    // Intermediate variables for normalization and rounding
    logic [2*MAN_BITS+2:0] normalized_sum;
    logic [MAN_BITS+1:0] rounded_man;
    logic overflow_flag, underflow_flag, inexact_flag;
    logic [EXP_BITS-1:0] normalized_exp;
    logic [2*MAN_BITS+2:0] leading_one_position;
    logic rounding_bit, sticky_bit;

    always_comb begin
        // Reset flags
        invalid = 1'b0;
        overflow_flag = 1'b0;
        underflow_flag = 1'b0;
        inexact_flag = 1'b0;

        // Extract sign, exponent, and mantissa from operands
        operand_a_sign = operand_a[TOTAL_BITS-1];
        operand_b_sign = operand_b[TOTAL_BITS-1];
        operand_c_sign = operand_c[TOTAL_BITS-1];
        operand_a_exp = operand_a[EXP_BITS+MAN_BITS-1:MAN_BITS];
        operand_b_exp = operand_b[EXP_BITS+MAN_BITS-1:MAN_BITS];
        operand_c_exp = operand_c[EXP_BITS+MAN_BITS-1:MAN_BITS];
        operand_a_man = {1'b1, operand_a[MAN_BITS-1:0]}; // Implicit leading bit for normal numbers
        operand_b_man = {1'b1, operand_b[MAN_BITS-1:0]};
        operand_c_man = operand_c[MAN_BITS-1:0];

        // Check for special cases (NaN, Infinity, Zero)
        operand_a_inf = (operand_a_exp == 8'hFF && operand_a_man[MAN_BITS-1:0] == 0);
        operand_b_inf = (operand_b_exp == 8'hFF && operand_b_man[MAN_BITS-1:0] == 0);
        operand_c_inf = (operand_c_exp == 8'hFF && operand_c_man == 0);
        operand_a_zero = (operand_a_exp == 0 && operand_a_man[MAN_BITS-1:0] == 0);
        operand_b_zero = (operand_b_exp == 0 && operand_b_man[MAN_BITS-1:0] == 0);
        operand_c_zero = (operand_c_exp == 0 && operand_c_man == 0);
        operand_a_nan = (operand_a_exp == 8'hFF) && (operand_a_man[MAN_BITS-1:0] != 0);
        operand_b_nan = (operand_b_exp == 8'hFF) && (operand_b_man[MAN_BITS-1:0] != 0);
        operand_c_nan = (operand_c_exp == 8'hFF) && (operand_c_man != 0);

        // Handle NaNs and Infinities
        if (operand_a_nan || operand_b_nan || operand_c_nan) begin
            result = 16'h7FC0; // NaN
            invalid = 1'b1;
            end
         else if (operand_a_inf || operand_b_inf || operand_c_inf) begin
            if ((operand_a_zero && (operand_b_inf || operand_a_inf)) ||
                (operand_b_zero && (operand_a_inf || operand_b_inf)) ||
                (operand_c_zero && operand_c_inf)) begin
                result = 16'h7FC0; // NaN
                invalid = 1'b1;
            end else begin
                result = {operand_a_sign ^ operand_b_sign, 8'hFF, 7'h00}; // Infinity
            end
        end else begin
            // Perform FMA operation
            // Fused Multiply-Add: (A * B) + C
            // Step 1: Multiplication
            if (operand_a_exp != 0) operand_a_man[MAN_BITS] = 1'b1; // Restore implicit bit for normal numbers
            if (operand_b_exp != 0) operand_b_man[MAN_BITS] = 1'b1;
            product = operand_a_man * operand_b_man;
            sum_exp = operand_a_exp + operand_b_exp - BIAS ; // Adjust for bias and product bit length

            // Step 2: Alignment for Addition (Handling operand C)
            // Align C to the product
            addend = {1'b0, operand_c_man, {MAN_BITS+1{1'b0}}};
            if (operand_c_exp > sum_exp) begin
                // Shift product right if C's exponent is larger
                product = product >> (operand_c_exp - sum_exp);
                sum_exp = operand_c_exp;
            end else begin
                // Shift C right if product's exponent is larger
                addend = addend >> (sum_exp - operand_c_exp);
            end

            // Step 3: Addition
            sum = product + addend;
            sum_sign = sum[2*MAN_BITS+2];

            // Step 4: Normalization
            normalized_exp = sum_exp;
            normalized_sum = sum;
            // Shift normalized_sum left until the leading bit is 1
            leading_one_position = 0;
            while (normalized_sum[2*MAN_BITS+2] == 0 && leading_one_position < 2*MAN_BITS+2) begin
                normalized_sum = normalized_sum << 1;
                leading_one_position = leading_one_position + 1;
            end
            normalized_exp = normalized_exp - leading_one_position;

            // Step 5: Rounding
            // Extract rounding and sticky bits
            rounding_bit = normalized_sum[0];
            sticky_bit = |normalized_sum[1:0];
            // Implement rounding logic based on rnd_mode
            // ...

            // Step 6: Check for overflow, underflow, and inexact
            overflow_flag = (normalized_exp >= (2**EXP_BITS - 1));
            underflow_flag = (normalized_exp <= 0);
            inexact_flag = rounding_bit | sticky_bit;

            // Set final result
            if (overflow_flag) begin
                // Overflow handling
                result = {sum_sign, {EXP_BITS{1'b1}}, {MAN_BITS{1'b0}}}; // Infinity or max representable value
                overflow = 1'b1;
            end else if (underflow_flag) begin
                // Underflow handling
                result = {sum_sign, {EXP_BITS{1'b0}}, {MAN_BITS{1'b0}}}; // Zero or min representable value
                underflow = 1'b1;
            end else begin
                final_exp = normalized_exp[EXP_BITS-1:0];
                final_man = normalized_sum[2*MAN_BITS+1:MAN_BITS+2];
                result = {sum_sign, final_exp, final_man};
            end

            // Set flags
            invalid = operand_a_nan | operand_b_nan | operand_c_nan;
            inexact = inexact_flag;
        end
    end

endmodule
