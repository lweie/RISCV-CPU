// 五级流水线RV32I处理器核心模块
module core (
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata
);

    // IF/ID流水寄存器
    wire        if_id_valid;
    wire [31:0] if_id_pc;
    wire [31:0] if_id_instr;

    // ID/EX流水寄存器
    wire        id_ex_valid;
    wire [31:0] id_ex_pc;
    wire [31:0] id_ex_rs1_value;
    wire [31:0] id_ex_rs2_value;
    wire [4:0]  id_ex_rs1;
    wire [4:0]  id_ex_rs2;
    wire [4:0]  id_ex_rd;
    wire [31:0] id_ex_imm;
    wire [3:0]  id_ex_alu_op;
    wire [1:0]  id_ex_alu_a_sel;
    wire        id_ex_alu_b_imm;
    wire        id_ex_reg_write;
    wire        id_ex_mem_read;
    wire        id_ex_mem_write;
    wire [2:0]  id_ex_mem_type;
    wire        id_ex_branch;
    wire [2:0]  id_ex_branch_type;
    wire [1:0]  id_ex_jump_type;
    wire [1:0]  id_ex_wb_sel;

    // EX/MEM流水寄存器
    wire        ex_mem_valid;
    wire [4:0]  ex_mem_rd;
    wire [31:0] ex_mem_alu_result;
    wire [31:0] ex_mem_store_data;
    wire [31:0] ex_mem_pc4;
    wire        ex_mem_reg_write;
    wire        ex_mem_mem_read;
    wire        ex_mem_mem_write;
    wire [2:0]  ex_mem_mem_type;
    wire [1:0]  ex_mem_wb_sel;

    // MEM/WB流水寄存器
    wire        mem_wb_valid;
    wire [4:0]  mem_wb_rd;
    wire [31:0] mem_wb_alu_result;
    wire [31:0] mem_wb_load_result;
    wire [31:0] mem_wb_pc4;
    wire        mem_wb_reg_write;
    wire [1:0]  mem_wb_wb_sel;

    // 反向控制和数据通路
    wire        stall;
    wire        flush;
    wire        redirect_valid;
    wire [31:0] redirect_pc;

    wire        ex_mem_forward_valid;
    wire [4:0]  ex_mem_forward_rd;
    wire [31:0] ex_mem_forward_data;

    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    assign flush = redirect_valid;

    // Instruction Fetch
    IF_stage u_if_stage (
        .clk            (clk),
        .reset          (reset),
        .stall          (stall),
        .flush          (flush),
        .redirect_valid (redirect_valid),
        .redirect_pc    (redirect_pc),
        .imem_addr      (imem_addr),
        .imem_rdata     (imem_rdata),
        .if_id_valid    (if_id_valid),
        .if_id_pc       (if_id_pc),
        .if_id_instr    (if_id_instr)
    );

    // Instruction Decode
    ID_stage u_id_stage (
        .clk               (clk),
        .reset             (reset),
        .if_id_valid       (if_id_valid),
        .if_id_pc          (if_id_pc),
        .if_id_instr       (if_id_instr),
        .flush             (flush),
        .stall             (stall),
        .wb_reg_write      (wb_reg_write),
        .wb_rd             (wb_rd),
        .wb_data           (wb_data),
        .id_ex_valid       (id_ex_valid),
        .id_ex_pc          (id_ex_pc),
        .id_ex_rs1_value   (id_ex_rs1_value),
        .id_ex_rs2_value   (id_ex_rs2_value),
        .id_ex_rs1         (id_ex_rs1),
        .id_ex_rs2         (id_ex_rs2),
        .id_ex_rd          (id_ex_rd),
        .id_ex_imm         (id_ex_imm),
        .id_ex_alu_op      (id_ex_alu_op),
        .id_ex_alu_a_sel   (id_ex_alu_a_sel),
        .id_ex_alu_b_imm   (id_ex_alu_b_imm),
        .id_ex_reg_write   (id_ex_reg_write),
        .id_ex_mem_read    (id_ex_mem_read),
        .id_ex_mem_write   (id_ex_mem_write),
        .id_ex_mem_type    (id_ex_mem_type),
        .id_ex_branch      (id_ex_branch),
        .id_ex_branch_type (id_ex_branch_type),
        .id_ex_jump_type   (id_ex_jump_type),
        .id_ex_wb_sel      (id_ex_wb_sel)
    );

    // Execute
    EX_stage u_ex_stage (
        .clk                    (clk),
        .reset                  (reset),
        .id_ex_valid            (id_ex_valid),
        .id_ex_pc               (id_ex_pc),
        .id_ex_rs1_value        (id_ex_rs1_value),
        .id_ex_rs2_value        (id_ex_rs2_value),
        .id_ex_rs1              (id_ex_rs1),
        .id_ex_rs2              (id_ex_rs2),
        .id_ex_rd               (id_ex_rd),
        .id_ex_imm              (id_ex_imm),
        .id_ex_alu_op           (id_ex_alu_op),
        .id_ex_alu_a_sel        (id_ex_alu_a_sel),
        .id_ex_alu_b_imm        (id_ex_alu_b_imm),
        .id_ex_reg_write        (id_ex_reg_write),
        .id_ex_mem_read         (id_ex_mem_read),
        .id_ex_mem_write        (id_ex_mem_write),
        .id_ex_mem_type         (id_ex_mem_type),
        .id_ex_branch           (id_ex_branch),
        .id_ex_branch_type      (id_ex_branch_type),
        .id_ex_jump_type        (id_ex_jump_type),
        .id_ex_wb_sel           (id_ex_wb_sel),
        .forward_ex_mem_valid   (ex_mem_forward_valid),
        .forward_ex_mem_rd      (ex_mem_forward_rd),
        .forward_ex_mem_data    (ex_mem_forward_data),
        .forward_mem_wb_valid   (wb_reg_write),
        .forward_mem_wb_rd      (wb_rd),
        .forward_mem_wb_data    (wb_data),
        .redirect_valid         (redirect_valid),
        .redirect_pc            (redirect_pc),
        .ex_mem_valid           (ex_mem_valid),
        .ex_mem_rd              (ex_mem_rd),
        .ex_mem_alu_result      (ex_mem_alu_result),
        .ex_mem_store_data      (ex_mem_store_data),
        .ex_mem_pc4             (ex_mem_pc4),
        .ex_mem_reg_write       (ex_mem_reg_write),
        .ex_mem_mem_read        (ex_mem_mem_read),
        .ex_mem_mem_write       (ex_mem_mem_write),
        .ex_mem_mem_type        (ex_mem_mem_type),
        .ex_mem_wb_sel          (ex_mem_wb_sel),
        .ex_mem_forward_valid   (ex_mem_forward_valid),
        .ex_mem_forward_rd      (ex_mem_forward_rd),
        .ex_mem_forward_data    (ex_mem_forward_data)
    );

    // Memory Access
    MEM_stage u_mem_stage (
        .clk                (clk),
        .reset              (reset),
        .ex_mem_valid       (ex_mem_valid),
        .ex_mem_rd          (ex_mem_rd),
        .ex_mem_alu_result  (ex_mem_alu_result),
        .ex_mem_store_data  (ex_mem_store_data),
        .ex_mem_pc4         (ex_mem_pc4),
        .ex_mem_reg_write   (ex_mem_reg_write),
        .ex_mem_mem_read    (ex_mem_mem_read),
        .ex_mem_mem_write   (ex_mem_mem_write),
        .ex_mem_mem_type    (ex_mem_mem_type),
        .ex_mem_wb_sel      (ex_mem_wb_sel),
        .dmem_addr          (dmem_addr),
        .dmem_wdata         (dmem_wdata),
        .dmem_wstrb         (dmem_wstrb),
        .dmem_rdata         (dmem_rdata),
        .mem_wb_valid       (mem_wb_valid),
        .mem_wb_rd          (mem_wb_rd),
        .mem_wb_alu_result  (mem_wb_alu_result),
        .mem_wb_load_result (mem_wb_load_result),
        .mem_wb_pc4         (mem_wb_pc4),
        .mem_wb_reg_write   (mem_wb_reg_write),
        .mem_wb_wb_sel      (mem_wb_wb_sel)
    );

    // Write Back
    WB_stage u_wb_stage (
        .mem_wb_valid       (mem_wb_valid),
        .mem_wb_rd          (mem_wb_rd),
        .mem_wb_alu_result  (mem_wb_alu_result),
        .mem_wb_load_result (mem_wb_load_result),
        .mem_wb_pc4         (mem_wb_pc4),
        .mem_wb_reg_write   (mem_wb_reg_write),
        .mem_wb_wb_sel      (mem_wb_wb_sel),
        .wb_reg_write       (wb_reg_write),
        .wb_rd              (wb_rd),
        .wb_data            (wb_data)
    );

endmodule
