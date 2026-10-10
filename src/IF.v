// 取指阶段：维护PC并保存IF/ID流水寄存器
module IF_stage (
    input  wire        clk,
    input  wire        reset,

    input  wire        stall,          // 全局流水线暂停
    input  wire        flush,          // 误预测冲刷
    input  wire        redirect_valid, // EX阶段重定向请求
    input  wire [31:0] redirect_pc,

    input  wire        predicted_taken,
    input  wire [31:0] predicted_target,
    input  wire [31:0] predicted_next_pc,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    output wire [31:0] fetch_pc,

    output reg         if_id_valid,
    output reg  [31:0] if_id_pc,
    output reg  [31:0] if_id_instr,
    output reg         if_id_predicted_taken,
    output reg  [31:0] if_id_predicted_target,
    output reg  [31:0] if_id_predicted_next_pc
);

    reg [31:0] pc;

    assign imem_addr = pc;
    assign fetch_pc  = pc;

    // PC和IF/ID流水寄存器
    always @(posedge clk) begin
        if (reset) begin
            pc          <= 32'b0;
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'b0;
            if_id_instr <= 32'b0;
            if_id_predicted_taken   <= 1'b0;
            if_id_predicted_target  <= 32'b0;
            if_id_predicted_next_pc <= 32'b0;
        end else if (redirect_valid) begin
            pc          <= redirect_pc;
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'b0;
            if_id_instr <= 32'b0;
            if_id_predicted_taken   <= 1'b0;
            if_id_predicted_target  <= 32'b0;
            if_id_predicted_next_pc <= 32'b0;
        end else if (flush) begin
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'b0;
            if_id_instr <= 32'b0;
            if_id_predicted_taken   <= 1'b0;
            if_id_predicted_target  <= 32'b0;
            if_id_predicted_next_pc <= 32'b0;
        end else if (stall) begin
            pc          <= pc;
            if_id_valid <= if_id_valid;
            if_id_pc    <= if_id_pc;
            if_id_instr <= if_id_instr;
            if_id_predicted_taken   <= if_id_predicted_taken;
            if_id_predicted_target  <= if_id_predicted_target;
            if_id_predicted_next_pc <= if_id_predicted_next_pc;
        end else begin
            pc          <= predicted_next_pc;
            if_id_valid <= 1'b1;
            if_id_pc    <= pc;
            if_id_instr <= imem_rdata;
            if_id_predicted_taken   <= predicted_taken;
            if_id_predicted_target  <= predicted_target;
            if_id_predicted_next_pc <= predicted_next_pc;
        end
    end

endmodule
