// 执行阶段：数据前递、ALU运算和控制转移判断
module EX_stage (
    input  wire        clk,
    input  wire        reset,

    input  wire        id_ex_valid,
    input  wire [31:0] id_ex_pc,
    input  wire [31:0] id_ex_rs1_value,
    input  wire [31:0] id_ex_rs2_value,
    input  wire [4:0]  id_ex_rs1,
    input  wire [4:0]  id_ex_rs2,
    input  wire [4:0]  id_ex_rd,
    input  wire [31:0] id_ex_imm,
    input  wire [3:0]  id_ex_alu_op,
    input  wire [1:0]  id_ex_alu_a_sel,
    input  wire        id_ex_alu_b_imm,
    input  wire        id_ex_reg_write,
    input  wire        id_ex_mem_read,
    input  wire        id_ex_mem_write,
    input  wire [2:0]  id_ex_mem_type,
    input  wire        id_ex_branch,
    input  wire [2:0]  id_ex_branch_type,
    input  wire [1:0]  id_ex_jump_type,
    input  wire [1:0]  id_ex_wb_sel,

    input  wire        forward_ex_mem_valid,
    input  wire [4:0]  forward_ex_mem_rd,
    input  wire [31:0] forward_ex_mem_data,
    input  wire        forward_mem_wb_valid,
    input  wire [4:0]  forward_mem_wb_rd,
    input  wire [31:0] forward_mem_wb_data,

    output reg         redirect_valid,
    output reg  [31:0] redirect_pc,

    output reg         ex_mem_valid,
    output reg  [4:0]  ex_mem_rd,
    output reg  [31:0] ex_mem_alu_result,
    output reg  [31:0] ex_mem_store_data,
    output reg  [31:0] ex_mem_pc4,
    output reg         ex_mem_reg_write,
    output reg         ex_mem_mem_read,
    output reg         ex_mem_mem_write,
    output reg  [2:0]  ex_mem_mem_type,
    output reg  [1:0]  ex_mem_wb_sel,

    output wire        ex_mem_forward_valid,
    output wire [4:0]  ex_mem_forward_rd,
    output wire [31:0] ex_mem_forward_data
);

    localparam ALU_ADD  = 4'd0;
    localparam ALU_SUB  = 4'd1;
    localparam ALU_SLL  = 4'd2;
    localparam ALU_SLT  = 4'd3;
    localparam ALU_SLTU = 4'd4;
    localparam ALU_XOR  = 4'd5;
    localparam ALU_SRL  = 4'd6;
    localparam ALU_SRA  = 4'd7;
    localparam ALU_OR   = 4'd8;
    localparam ALU_AND  = 4'd9;

    localparam ALU_A_RS1  = 2'b00;
    localparam ALU_A_PC   = 2'b01;
    localparam ALU_A_ZERO = 2'b10;

    localparam JUMP_JAL  = 2'b01;
    localparam JUMP_JALR = 2'b10;

    localparam WB_PC4 = 2'b10;

    reg [31:0] rs1_forwarded;
    reg [31:0] rs2_forwarded;
    reg [31:0] alu_operand_a;
    reg [31:0] alu_operand_b;
    reg [31:0] alu_result;
    reg        branch_taken;

    // Load结果在MEM/WB阶段前递，EX/MEM只前递已生成的数据
    assign ex_mem_forward_valid = ex_mem_valid && ex_mem_reg_write &&
                                  !ex_mem_mem_read &&
                                  (ex_mem_rd != 5'b0);
    assign ex_mem_forward_rd = ex_mem_rd;
    assign ex_mem_forward_data = (ex_mem_wb_sel == WB_PC4) ?
                                 ex_mem_pc4 : ex_mem_alu_result;

    // EX/MEM前递优先于MEM/WB前递
    always @(*) begin
        rs1_forwarded = id_ex_rs1_value;
        rs2_forwarded = id_ex_rs2_value;

        if (forward_ex_mem_valid && (forward_ex_mem_rd != 5'b0) &&
            (forward_ex_mem_rd == id_ex_rs1))
            rs1_forwarded = forward_ex_mem_data;
        else if (forward_mem_wb_valid && (forward_mem_wb_rd != 5'b0) &&
                 (forward_mem_wb_rd == id_ex_rs1))
            rs1_forwarded = forward_mem_wb_data;

        if (forward_ex_mem_valid && (forward_ex_mem_rd != 5'b0) &&
            (forward_ex_mem_rd == id_ex_rs2))
            rs2_forwarded = forward_ex_mem_data;
        else if (forward_mem_wb_valid && (forward_mem_wb_rd != 5'b0) &&
                 (forward_mem_wb_rd == id_ex_rs2))
            rs2_forwarded = forward_mem_wb_data;
    end

    always @(*) begin
        case (id_ex_alu_a_sel)
            ALU_A_PC:   alu_operand_a = id_ex_pc;
            ALU_A_ZERO: alu_operand_a = 32'b0;
            ALU_A_RS1:  alu_operand_a = rs1_forwarded;
            default:    alu_operand_a = rs1_forwarded;
        endcase

        if (id_ex_alu_b_imm)
            alu_operand_b = id_ex_imm;
        else
            alu_operand_b = rs2_forwarded;
    end

    // ALU组合逻辑
    always @(*) begin
        case (id_ex_alu_op)
            ALU_ADD:  alu_result = alu_operand_a + alu_operand_b;
            ALU_SUB:  alu_result = alu_operand_a - alu_operand_b;
            ALU_SLL:  alu_result = alu_operand_a << alu_operand_b[4:0];
            ALU_SLT:  alu_result = ($signed(alu_operand_a) <
                                    $signed(alu_operand_b)) ? 32'd1 : 32'd0;
            ALU_SLTU: alu_result = (alu_operand_a < alu_operand_b) ?
                                   32'd1 : 32'd0;
            ALU_XOR:  alu_result = alu_operand_a ^ alu_operand_b;
            ALU_SRL:  alu_result = alu_operand_a >> alu_operand_b[4:0];
            ALU_SRA:  alu_result = $signed(alu_operand_a) >>>
                                   alu_operand_b[4:0];
            ALU_OR:   alu_result = alu_operand_a | alu_operand_b;
            ALU_AND:  alu_result = alu_operand_a & alu_operand_b;
            default:  alu_result = 32'b0;
        endcase
    end

    // 分支比较使用前递后的两个源操作数
    always @(*) begin
        branch_taken = 1'b0;
        case (id_ex_branch_type)
            3'b000: branch_taken = (rs1_forwarded == rs2_forwarded); // BEQ
            3'b001: branch_taken = (rs1_forwarded != rs2_forwarded); // BNE
            3'b100: branch_taken = ($signed(rs1_forwarded) <
                                    $signed(rs2_forwarded));          // BLT
            3'b101: branch_taken = ($signed(rs1_forwarded) >=
                                    $signed(rs2_forwarded));          // BGE
            3'b110: branch_taken = (rs1_forwarded < rs2_forwarded);  // BLTU
            3'b111: branch_taken = (rs1_forwarded >= rs2_forwarded); // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

    // Branch、JAL和JALR均在EX阶段确定重定向地址
    always @(*) begin
        redirect_valid = 1'b0;
        redirect_pc    = 32'b0;

        if (id_ex_valid) begin
            if (id_ex_jump_type == JUMP_JAL) begin
                redirect_valid = 1'b1;
                redirect_pc    = id_ex_pc + id_ex_imm;
            end else if (id_ex_jump_type == JUMP_JALR) begin
                redirect_valid = 1'b1;
                redirect_pc    = (rs1_forwarded + id_ex_imm) &
                                 32'hffff_fffe;
            end else if (id_ex_branch && branch_taken) begin
                redirect_valid = 1'b1;
                redirect_pc    = id_ex_pc + id_ex_imm;
            end
        end
    end

    // EX/MEM流水寄存器
    always @(posedge clk) begin
        if (reset) begin
            ex_mem_valid      <= 1'b0;
            ex_mem_rd         <= 5'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_pc4        <= 32'b0;
            ex_mem_reg_write  <= 1'b0;
            ex_mem_mem_read   <= 1'b0;
            ex_mem_mem_write  <= 1'b0;
            ex_mem_mem_type   <= 3'b0;
            ex_mem_wb_sel     <= 2'b0;
        end else begin
            ex_mem_valid      <= id_ex_valid;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_alu_result <= alu_result;
            ex_mem_store_data <= rs2_forwarded;
            ex_mem_pc4        <= id_ex_pc + 32'd4;
            ex_mem_reg_write  <= id_ex_valid && id_ex_reg_write;
            ex_mem_mem_read   <= id_ex_valid && id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_valid && id_ex_mem_write;
            ex_mem_mem_type   <= id_ex_mem_type;
            ex_mem_wb_sel     <= id_ex_wb_sel;
        end
    end

endmodule
