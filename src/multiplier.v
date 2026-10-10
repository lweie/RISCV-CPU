// RV32M单周期组合乘法器
module multiplier (
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    input  wire [1:0]  mul_op,
    output reg  [31:0] result
);

    reg [31:0] operand_a_abs;
    reg [31:0] operand_b_abs;
    reg [63:0] product_uu;
    reg [63:0] product_ss_abs;
    reg [63:0] product_su_abs;
    reg [63:0] product_ss;
    reg [63:0] product_su;

    // 先计算绝对值，再显式恢复符号，避免表达式类型传播
    always @(*) begin
        operand_a_abs = operand_a[31] ? (~operand_a + 32'd1) : operand_a;
        operand_b_abs = operand_b[31] ? (~operand_b + 32'd1) : operand_b;

        product_uu     = operand_a * operand_b;
        product_ss_abs = operand_a_abs * operand_b_abs;
        product_su_abs = operand_a_abs * operand_b;

        product_ss = (operand_a[31] ^ operand_b[31]) ?
                     (~product_ss_abs + 64'd1) : product_ss_abs;
        product_su = operand_a[31] ?
                     (~product_su_abs + 64'd1) : product_su_abs;

        case (mul_op)
            2'b00: result = product_ss[31:0];   // MUL
            2'b01: result = product_ss[63:32];  // MULH
            2'b10: result = product_su[63:32];  // MULHSU
            2'b11: result = product_uu[63:32];  // MULHU
            default: result = 32'b0;
        endcase
    end

endmodule
