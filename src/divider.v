// RV32M多周期迭代除法器
module divider (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,
    input  wire [1:0]  div_op,

    output reg         busy,
    output reg         done,
    output reg  [31:0] result
);

    reg [31:0] quotient;
    reg [31:0] remainder;
    reg [32:0] divisor_reg;
    reg [5:0]  count;
    reg        select_remainder;
    reg        quotient_negative;
    reg        remainder_negative;

    wire       signed_operation;
    wire [31:0] dividend_abs;
    wire [31:0] divisor_abs;
    wire [32:0] shifted_remainder;
    wire        subtract_enable;
    wire [32:0] next_remainder;
    wire [31:0] next_quotient;
    wire [31:0] signed_quotient;
    wire [31:0] signed_remainder;

    assign signed_operation = !div_op[0];
    assign dividend_abs = (signed_operation && dividend[31]) ?
                          (~dividend + 32'd1) : dividend;
    assign divisor_abs = (signed_operation && divisor[31]) ?
                         (~divisor + 32'd1) : divisor;

    assign shifted_remainder = {remainder, quotient[31]};
    assign subtract_enable = (shifted_remainder >= divisor_reg);
    assign next_remainder = subtract_enable ?
                            (shifted_remainder - divisor_reg) :
                            shifted_remainder;
    assign next_quotient = {quotient[30:0], subtract_enable};
    assign signed_quotient = quotient_negative ?
                             (~next_quotient + 32'd1) : next_quotient;
    assign signed_remainder = remainder_negative ?
                              (~next_remainder[31:0] + 32'd1) :
                              next_remainder[31:0];

    // start只在空闲状态接受一次，busy期间执行32轮恢复除法
    always @(posedge clk) begin
        if (reset) begin
            busy               <= 1'b0;
            done               <= 1'b0;
            result             <= 32'b0;
            quotient           <= 32'b0;
            remainder          <= 32'b0;
            divisor_reg        <= 33'b0;
            count              <= 6'b0;
            select_remainder   <= 1'b0;
            quotient_negative  <= 1'b0;
            remainder_negative <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                select_remainder <= div_op[1];

                // RV32M规定的除零和有符号溢出结果
                if (divisor == 32'b0) begin
                    busy   <= 1'b0;
                    done   <= 1'b1;
                    result <= div_op[1] ? dividend : 32'hffff_ffff;
                end else if (signed_operation &&
                             (dividend == 32'h8000_0000) &&
                             (divisor == 32'hffff_ffff)) begin
                    busy   <= 1'b0;
                    done   <= 1'b1;
                    result <= div_op[1] ? 32'b0 : 32'h8000_0000;
                end else begin
                    busy               <= 1'b1;
                    quotient           <= dividend_abs;
                    remainder          <= 32'b0;
                    divisor_reg        <= {1'b0, divisor_abs};
                    count              <= 6'b0;
                    quotient_negative  <= signed_operation &&
                                          (dividend[31] ^ divisor[31]);
                    remainder_negative <= signed_operation && dividend[31];
                end
            end else if (busy) begin
                quotient  <= next_quotient;
                remainder <= next_remainder[31:0];

                if (count == 6'd31) begin
                    busy   <= 1'b0;
                    done   <= 1'b1;
                    result <= select_remainder ? signed_remainder :
                                                 signed_quotient;
                end else begin
                    count <= count + 6'd1;
                end
            end
        end
    end

endmodule
