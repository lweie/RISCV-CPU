// 指令解码阶段：寄存器读取、立即数生成和冒险检测
module ID_stage (
    input  wire        clk,
    input  wire        reset,

    input  wire        if_id_valid,
    input  wire [31:0] if_id_pc,
    input  wire [31:0] if_id_instr,

    input  wire        flush,
    output wire        stall,

    input  wire        wb_reg_write,
    input  wire [4:0]  wb_rd,
    input  wire [31:0] wb_data,

    output reg         id_ex_valid,
    output reg  [31:0] id_ex_pc,
    output reg  [31:0] id_ex_rs1_value,
    output reg  [31:0] id_ex_rs2_value,
    output reg  [4:0]  id_ex_rs1,
    output reg  [4:0]  id_ex_rs2,
    output reg  [4:0]  id_ex_rd,
    output reg  [31:0] id_ex_imm,
    output reg  [3:0]  id_ex_alu_op,
    output reg  [1:0]  id_ex_alu_a_sel,
    output reg         id_ex_alu_b_imm,
    output reg         id_ex_reg_write,
    output reg         id_ex_mem_read,
    output reg         id_ex_mem_write,
    output reg  [2:0]  id_ex_mem_type,
    output reg         id_ex_branch,
    output reg  [2:0]  id_ex_branch_type,
    output reg  [1:0]  id_ex_jump_type,
    output reg  [1:0]  id_ex_wb_sel
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

    localparam JUMP_NONE = 2'b00;
    localparam JUMP_JAL  = 2'b01;
    localparam JUMP_JALR = 2'b10;

    localparam WB_ALU  = 2'b00;
    localparam WB_LOAD = 2'b01;
    localparam WB_PC4  = 2'b10;

    reg [31:0] regs [0:31];
    integer i;

    reg        dec_valid;
    reg [4:0]  dec_rs1;
    reg [4:0]  dec_rs2;
    reg [4:0]  dec_rd;
    reg [31:0] dec_imm;
    reg [3:0]  dec_alu_op;
    reg [1:0]  dec_alu_a_sel;
    reg        dec_alu_b_imm;
    reg        dec_reg_write;
    reg        dec_mem_read;
    reg        dec_mem_write;
    reg [2:0]  dec_mem_type;
    reg        dec_branch;
    reg [2:0]  dec_branch_type;
    reg [1:0]  dec_jump_type;
    reg [1:0]  dec_wb_sel;
    reg        dec_uses_rs1;
    reg        dec_uses_rs2;

    wire [31:0] dec_rs1_value;
    wire [31:0] dec_rs2_value;

    // WB同周期写回时直接旁路到寄存器读端口
    assign dec_rs1_value = (dec_rs1 == 5'b0) ? 32'b0 :
                           ((wb_reg_write && (wb_rd == dec_rs1)) ? wb_data :
                            regs[dec_rs1]);
    assign dec_rs2_value = (dec_rs2 == 5'b0) ? 32'b0 :
                           ((wb_reg_write && (wb_rd == dec_rs2)) ? wb_data :
                            regs[dec_rs2]);

    // 仅对指令实际使用的源寄存器检测load-use冒险
    assign stall = if_id_valid && dec_valid && id_ex_valid && id_ex_mem_read &&
                   (id_ex_rd != 5'b0) &&
                   ((dec_uses_rs1 && (id_ex_rd == dec_rs1)) ||
                    (dec_uses_rs2 && (id_ex_rd == dec_rs2)));

    // 指令译码和立即数生成
    always @(*) begin
        dec_valid       = 1'b0;
        dec_rs1         = if_id_instr[19:15];
        dec_rs2         = if_id_instr[24:20];
        dec_rd          = if_id_instr[11:7];
        dec_imm         = 32'b0;
        dec_alu_op      = ALU_ADD;
        dec_alu_a_sel   = ALU_A_RS1;
        dec_alu_b_imm   = 1'b0;
        dec_reg_write   = 1'b0;
        dec_mem_read    = 1'b0;
        dec_mem_write   = 1'b0;
        dec_mem_type    = 3'b0;
        dec_branch      = 1'b0;
        dec_branch_type = 3'b0;
        dec_jump_type   = JUMP_NONE;
        dec_wb_sel      = WB_ALU;
        dec_uses_rs1    = 1'b0;
        dec_uses_rs2    = 1'b0;

        case (if_id_instr[6:0])
            7'b0110011: begin // R-type算术指令
                dec_uses_rs1  = 1'b1;
                dec_uses_rs2  = 1'b1;
                dec_reg_write = 1'b1;
                case (if_id_instr[14:12])
                    3'b000: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_ADD;
                        end else if (if_id_instr[31:25] == 7'b0100000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SUB;
                        end
                    end
                    3'b001: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SLL;
                        end
                    end
                    3'b010: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SLT;
                        end
                    end
                    3'b011: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SLTU;
                        end
                    end
                    3'b100: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_XOR;
                        end
                    end
                    3'b101: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SRL;
                        end else if (if_id_instr[31:25] == 7'b0100000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SRA;
                        end
                    end
                    3'b110: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_OR;
                        end
                    end
                    3'b111: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_AND;
                        end
                    end
                    default: dec_valid = 1'b0;
                endcase
            end

            7'b0010011: begin // I-type算术指令
                dec_uses_rs1  = 1'b1;
                dec_reg_write = 1'b1;
                dec_alu_b_imm = 1'b1;
                dec_imm       = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
                case (if_id_instr[14:12])
                    3'b000: begin dec_valid = 1'b1; dec_alu_op = ALU_ADD;  end
                    3'b010: begin dec_valid = 1'b1; dec_alu_op = ALU_SLT;  end
                    3'b011: begin dec_valid = 1'b1; dec_alu_op = ALU_SLTU; end
                    3'b100: begin dec_valid = 1'b1; dec_alu_op = ALU_XOR;  end
                    3'b110: begin dec_valid = 1'b1; dec_alu_op = ALU_OR;   end
                    3'b111: begin dec_valid = 1'b1; dec_alu_op = ALU_AND;  end
                    3'b001: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SLL;
                        end
                    end
                    3'b101: begin
                        if (if_id_instr[31:25] == 7'b0000000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SRL;
                        end else if (if_id_instr[31:25] == 7'b0100000) begin
                            dec_valid  = 1'b1;
                            dec_alu_op = ALU_SRA;
                        end
                    end
                    default: dec_valid = 1'b0;
                endcase
            end

            7'b0000011: begin // 加载指令
                dec_uses_rs1  = 1'b1;
                dec_alu_b_imm = 1'b1;
                dec_reg_write = 1'b1;
                dec_mem_read  = 1'b1;
                dec_wb_sel    = WB_LOAD;
                dec_imm       = {{20{if_id_instr[31]}}, if_id_instr[31:20]};
                dec_mem_type  = if_id_instr[14:12];
                case (if_id_instr[14:12])
                    3'b000, 3'b001, 3'b010,
                    3'b100, 3'b101: dec_valid = 1'b1;
                    default:        dec_valid = 1'b0;
                endcase
            end

            7'b0100011: begin // 存储指令
                dec_uses_rs1  = 1'b1;
                dec_uses_rs2  = 1'b1;
                dec_alu_b_imm = 1'b1;
                dec_mem_write = 1'b1;
                dec_imm       = {{20{if_id_instr[31]}},
                                 if_id_instr[31:25], if_id_instr[11:7]};
                dec_mem_type  = if_id_instr[14:12];
                case (if_id_instr[14:12])
                    3'b000, 3'b001, 3'b010: dec_valid = 1'b1;
                    default:                 dec_valid = 1'b0;
                endcase
            end

            7'b1100011: begin // 条件分支
                dec_uses_rs1    = 1'b1;
                dec_uses_rs2    = 1'b1;
                dec_branch      = 1'b1;
                dec_branch_type = if_id_instr[14:12];
                dec_imm         = {{19{if_id_instr[31]}}, if_id_instr[31],
                                   if_id_instr[7], if_id_instr[30:25],
                                   if_id_instr[11:8], 1'b0};
                case (if_id_instr[14:12])
                    3'b000, 3'b001, 3'b100,
                    3'b101, 3'b110, 3'b111: dec_valid = 1'b1;
                    default:                 dec_valid = 1'b0;
                endcase
            end

            7'b1101111: begin // JAL
                dec_valid       = 1'b1;
                dec_reg_write   = 1'b1;
                dec_jump_type   = JUMP_JAL;
                dec_wb_sel      = WB_PC4;
                dec_alu_a_sel   = ALU_A_PC;
                dec_alu_b_imm   = 1'b1;
                dec_imm         = {{11{if_id_instr[31]}}, if_id_instr[31],
                                   if_id_instr[19:12], if_id_instr[20],
                                   if_id_instr[30:21], 1'b0};
            end

            7'b1100111: begin // JALR
                if (if_id_instr[14:12] == 3'b000) begin
                    dec_valid       = 1'b1;
                    dec_uses_rs1    = 1'b1;
                    dec_reg_write   = 1'b1;
                    dec_jump_type   = JUMP_JALR;
                    dec_wb_sel      = WB_PC4;
                    dec_alu_b_imm   = 1'b1;
                    dec_imm         = {{20{if_id_instr[31]}},
                                       if_id_instr[31:20]};
                end
            end

            7'b0110111: begin // LUI
                dec_valid       = 1'b1;
                dec_reg_write   = 1'b1;
                dec_alu_a_sel   = ALU_A_ZERO;
                dec_alu_b_imm   = 1'b1;
                dec_imm         = {if_id_instr[31:12], 12'b0};
            end

            7'b0010111: begin // AUIPC
                dec_valid       = 1'b1;
                dec_reg_write   = 1'b1;
                dec_alu_a_sel   = ALU_A_PC;
                dec_alu_b_imm   = 1'b1;
                dec_imm         = {if_id_instr[31:12], 12'b0};
            end

            default: dec_valid = 1'b0;
        endcase
    end

    // Register File和ID/EX流水寄存器
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;

            id_ex_valid       <= 1'b0;
            id_ex_pc          <= 32'b0;
            id_ex_rs1_value   <= 32'b0;
            id_ex_rs2_value   <= 32'b0;
            id_ex_rs1         <= 5'b0;
            id_ex_rs2         <= 5'b0;
            id_ex_rd          <= 5'b0;
            id_ex_imm         <= 32'b0;
            id_ex_alu_op      <= ALU_ADD;
            id_ex_alu_a_sel   <= ALU_A_RS1;
            id_ex_alu_b_imm   <= 1'b0;
            id_ex_reg_write   <= 1'b0;
            id_ex_mem_read    <= 1'b0;
            id_ex_mem_write   <= 1'b0;
            id_ex_mem_type    <= 3'b0;
            id_ex_branch      <= 1'b0;
            id_ex_branch_type <= 3'b0;
            id_ex_jump_type   <= JUMP_NONE;
            id_ex_wb_sel      <= WB_ALU;
        end else begin
            if (wb_reg_write && (wb_rd != 5'b0))
                regs[wb_rd] <= wb_data;
            regs[0] <= 32'b0;

            // redirect优先于load-use暂停
            if (flush) begin
                id_ex_valid       <= 1'b0;
                id_ex_pc          <= 32'b0;
                id_ex_rs1_value   <= 32'b0;
                id_ex_rs2_value   <= 32'b0;
                id_ex_rs1         <= 5'b0;
                id_ex_rs2         <= 5'b0;
                id_ex_rd          <= 5'b0;
                id_ex_imm         <= 32'b0;
                id_ex_alu_op      <= ALU_ADD;
                id_ex_alu_a_sel   <= ALU_A_RS1;
                id_ex_alu_b_imm   <= 1'b0;
                id_ex_reg_write   <= 1'b0;
                id_ex_mem_read    <= 1'b0;
                id_ex_mem_write   <= 1'b0;
                id_ex_mem_type    <= 3'b0;
                id_ex_branch      <= 1'b0;
                id_ex_branch_type <= 3'b0;
                id_ex_jump_type   <= JUMP_NONE;
                id_ex_wb_sel      <= WB_ALU;
            end else if (stall) begin
                id_ex_valid       <= 1'b0;
                id_ex_pc          <= 32'b0;
                id_ex_rs1_value   <= 32'b0;
                id_ex_rs2_value   <= 32'b0;
                id_ex_rs1         <= 5'b0;
                id_ex_rs2         <= 5'b0;
                id_ex_rd          <= 5'b0;
                id_ex_imm         <= 32'b0;
                id_ex_alu_op      <= ALU_ADD;
                id_ex_alu_a_sel   <= ALU_A_RS1;
                id_ex_alu_b_imm   <= 1'b0;
                id_ex_reg_write   <= 1'b0;
                id_ex_mem_read    <= 1'b0;
                id_ex_mem_write   <= 1'b0;
                id_ex_mem_type    <= 3'b0;
                id_ex_branch      <= 1'b0;
                id_ex_branch_type <= 3'b0;
                id_ex_jump_type   <= JUMP_NONE;
                id_ex_wb_sel      <= WB_ALU;
            end else begin
                id_ex_valid       <= if_id_valid && dec_valid;
                id_ex_pc          <= if_id_pc;
                id_ex_rs1_value   <= dec_rs1_value;
                id_ex_rs2_value   <= dec_rs2_value;
                id_ex_rs1         <= dec_rs1;
                id_ex_rs2         <= dec_rs2;
                id_ex_rd          <= dec_rd;
                id_ex_imm         <= dec_imm;
                id_ex_alu_op      <= dec_alu_op;
                id_ex_alu_a_sel   <= dec_alu_a_sel;
                id_ex_alu_b_imm   <= dec_alu_b_imm;
                id_ex_reg_write   <= if_id_valid && dec_valid && dec_reg_write;
                id_ex_mem_read    <= if_id_valid && dec_valid && dec_mem_read;
                id_ex_mem_write   <= if_id_valid && dec_valid && dec_mem_write;
                id_ex_mem_type    <= dec_mem_type;
                id_ex_branch      <= if_id_valid && dec_valid && dec_branch;
                id_ex_branch_type <= dec_branch_type;
                id_ex_jump_type   <= (if_id_valid && dec_valid) ?
                                     dec_jump_type : JUMP_NONE;
                id_ex_wb_sel      <= dec_wb_sel;
            end
        end
    end

endmodule
