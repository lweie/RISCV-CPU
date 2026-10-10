// 五级流水线RV32IM处理器核心模块
module core (
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    output wire        dmem_valid,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata
);

    // IF/ID流水寄存器
    wire        if_id_valid;
    wire [31:0] if_id_pc;
    wire [31:0] if_id_instr;
    wire        if_id_predicted_taken;
    wire [31:0] if_id_predicted_target;
    wire [31:0] if_id_predicted_next_pc;

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
    wire        id_ex_is_mul;
    wire [1:0]  id_ex_mul_op;
    wire        id_ex_is_div;
    wire [1:0]  id_ex_div_op;
    wire        id_ex_predicted_taken;
    wire [31:0] id_ex_predicted_target;
    wire [31:0] id_ex_predicted_next_pc;

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

    // Stall、Flush和Redirect
    wire        load_use_stall;
    wire        divider_stall;
    wire        pipeline_stall;
    wire        flush;
    wire        redirect_valid;
    wire [31:0] redirect_pc;

    // Forwarding数据通路
    wire        ex_mem_forward_valid;
    wire [4:0]  ex_mem_forward_rd;
    wire [31:0] ex_mem_forward_data;
    wire        wb_reg_write;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    // Branch Predictor接口
    wire [31:0] fetch_pc;
    wire        predicted_taken;
    wire [31:0] predicted_target;
    wire [31:0] predicted_next_pc;
    wire        predictor_update_valid;
    wire [1:0]  predictor_update_type;
    wire [31:0] predictor_update_pc;
    wire        predictor_actual_taken;
    wire [31:0] predictor_actual_target;

    // RV32M运算单元接口
    wire [31:0] mul_operand_a;
    wire [31:0] mul_operand_b;
    wire [1:0]  mul_op;
    wire [31:0] mul_result;
    wire        div_start;
    wire [31:0] div_dividend;
    wire [31:0] div_divisor;
    wire [1:0]  div_op;
    wire        div_busy;
    wire        div_done;
    wire [31:0] div_result;

    assign flush          = redirect_valid;
    assign pipeline_stall = divider_stall || load_use_stall;

    branch_predictor u_branch_predictor (
        .clk               (clk),
        .reset             (reset),
        .lookup_pc         (fetch_pc),
        .lookup_instr      (imem_rdata),
        .predicted_taken   (predicted_taken),
        .predicted_target  (predicted_target),
        .predicted_next_pc (predicted_next_pc),
        .update_valid      (predictor_update_valid),
        .update_type       (predictor_update_type),
        .update_pc         (predictor_update_pc),
        .actual_taken      (predictor_actual_taken),
        .actual_target     (predictor_actual_target)
    );

    multiplier u_multiplier (
        .operand_a (mul_operand_a),
        .operand_b (mul_operand_b),
        .mul_op    (mul_op),
        .result    (mul_result)
    );

    divider u_divider (
        .clk      (clk),
        .reset    (reset),
        .start    (div_start),
        .dividend (div_dividend),
        .divisor  (div_divisor),
        .div_op   (div_op),
        .busy     (div_busy),
        .done     (div_done),
        .result   (div_result)
    );

    // Instruction Fetch
    IF_stage u_if_stage (
        .clk                       (clk),
        .reset                     (reset),
        .stall                     (pipeline_stall),
        .flush                     (flush),
        .redirect_valid            (redirect_valid),
        .redirect_pc               (redirect_pc),
        .predicted_taken           (predicted_taken),
        .predicted_target          (predicted_target),
        .predicted_next_pc         (predicted_next_pc),
        .imem_addr                 (imem_addr),
        .imem_rdata                (imem_rdata),
        .fetch_pc                  (fetch_pc),
        .if_id_valid               (if_id_valid),
        .if_id_pc                  (if_id_pc),
        .if_id_instr               (if_id_instr),
        .if_id_predicted_taken     (if_id_predicted_taken),
        .if_id_predicted_target    (if_id_predicted_target),
        .if_id_predicted_next_pc   (if_id_predicted_next_pc)
    );

    // Instruction Decode
    ID_stage u_id_stage (
        .clk                       (clk),
        .reset                     (reset),
        .if_id_valid               (if_id_valid),
        .if_id_pc                  (if_id_pc),
        .if_id_instr               (if_id_instr),
        .if_id_predicted_taken     (if_id_predicted_taken),
        .if_id_predicted_target    (if_id_predicted_target),
        .if_id_predicted_next_pc   (if_id_predicted_next_pc),
        .flush                     (flush),
        .divider_stall             (divider_stall),
        .stall                     (load_use_stall),
        .wb_reg_write              (wb_reg_write),
        .wb_rd                     (wb_rd),
        .wb_data                   (wb_data),
        .id_ex_valid               (id_ex_valid),
        .id_ex_pc                  (id_ex_pc),
        .id_ex_rs1_value           (id_ex_rs1_value),
        .id_ex_rs2_value           (id_ex_rs2_value),
        .id_ex_rs1                 (id_ex_rs1),
        .id_ex_rs2                 (id_ex_rs2),
        .id_ex_rd                  (id_ex_rd),
        .id_ex_imm                 (id_ex_imm),
        .id_ex_alu_op              (id_ex_alu_op),
        .id_ex_alu_a_sel           (id_ex_alu_a_sel),
        .id_ex_alu_b_imm           (id_ex_alu_b_imm),
        .id_ex_reg_write           (id_ex_reg_write),
        .id_ex_mem_read            (id_ex_mem_read),
        .id_ex_mem_write           (id_ex_mem_write),
        .id_ex_mem_type            (id_ex_mem_type),
        .id_ex_branch              (id_ex_branch),
        .id_ex_branch_type         (id_ex_branch_type),
        .id_ex_jump_type           (id_ex_jump_type),
        .id_ex_wb_sel              (id_ex_wb_sel),
        .id_ex_is_mul              (id_ex_is_mul),
        .id_ex_mul_op              (id_ex_mul_op),
        .id_ex_is_div              (id_ex_is_div),
        .id_ex_div_op              (id_ex_div_op),
        .id_ex_predicted_taken     (id_ex_predicted_taken),
        .id_ex_predicted_target    (id_ex_predicted_target),
        .id_ex_predicted_next_pc   (id_ex_predicted_next_pc)
    );

    // Execute
    EX_stage u_ex_stage (
        .clk                     (clk),
        .reset                   (reset),
        .id_ex_valid             (id_ex_valid),
        .id_ex_pc                (id_ex_pc),
        .id_ex_rs1_value         (id_ex_rs1_value),
        .id_ex_rs2_value         (id_ex_rs2_value),
        .id_ex_rs1               (id_ex_rs1),
        .id_ex_rs2               (id_ex_rs2),
        .id_ex_rd                (id_ex_rd),
        .id_ex_imm               (id_ex_imm),
        .id_ex_alu_op            (id_ex_alu_op),
        .id_ex_alu_a_sel         (id_ex_alu_a_sel),
        .id_ex_alu_b_imm         (id_ex_alu_b_imm),
        .id_ex_reg_write         (id_ex_reg_write),
        .id_ex_mem_read          (id_ex_mem_read),
        .id_ex_mem_write         (id_ex_mem_write),
        .id_ex_mem_type          (id_ex_mem_type),
        .id_ex_branch            (id_ex_branch),
        .id_ex_branch_type       (id_ex_branch_type),
        .id_ex_jump_type         (id_ex_jump_type),
        .id_ex_wb_sel            (id_ex_wb_sel),
        .id_ex_is_mul            (id_ex_is_mul),
        .id_ex_mul_op            (id_ex_mul_op),
        .id_ex_is_div            (id_ex_is_div),
        .id_ex_div_op            (id_ex_div_op),
        .id_ex_predicted_taken   (id_ex_predicted_taken),
        .id_ex_predicted_target  (id_ex_predicted_target),
        .id_ex_predicted_next_pc (id_ex_predicted_next_pc),
        .forward_ex_mem_valid    (ex_mem_forward_valid),
        .forward_ex_mem_rd       (ex_mem_forward_rd),
        .forward_ex_mem_data     (ex_mem_forward_data),
        .forward_mem_wb_valid    (wb_reg_write),
        .forward_mem_wb_rd       (wb_rd),
        .forward_mem_wb_data     (wb_data),
        .mul_operand_a           (mul_operand_a),
        .mul_operand_b           (mul_operand_b),
        .mul_op                  (mul_op),
        .mul_result              (mul_result),
        .div_start               (div_start),
        .div_dividend            (div_dividend),
        .div_divisor             (div_divisor),
        .div_op                  (div_op),
        .div_busy                (div_busy),
        .div_done                (div_done),
        .div_result              (div_result),
        .divider_stall           (divider_stall),
        .predictor_update_valid  (predictor_update_valid),
        .predictor_update_type   (predictor_update_type),
        .predictor_update_pc     (predictor_update_pc),
        .predictor_actual_taken  (predictor_actual_taken),
        .predictor_actual_target (predictor_actual_target),
        .redirect_valid          (redirect_valid),
        .redirect_pc             (redirect_pc),
        .ex_mem_valid            (ex_mem_valid),
        .ex_mem_rd               (ex_mem_rd),
        .ex_mem_alu_result       (ex_mem_alu_result),
        .ex_mem_store_data       (ex_mem_store_data),
        .ex_mem_pc4              (ex_mem_pc4),
        .ex_mem_reg_write        (ex_mem_reg_write),
        .ex_mem_mem_read         (ex_mem_mem_read),
        .ex_mem_mem_write        (ex_mem_mem_write),
        .ex_mem_mem_type         (ex_mem_mem_type),
        .ex_mem_wb_sel           (ex_mem_wb_sel),
        .ex_mem_forward_valid    (ex_mem_forward_valid),
        .ex_mem_forward_rd       (ex_mem_forward_rd),
        .ex_mem_forward_data     (ex_mem_forward_data)
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
        .dmem_valid         (dmem_valid),
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
