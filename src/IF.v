// 取指阶段：维护PC并保存IF/ID流水寄存器
module IF_stage (
    input  wire        clk,
    input  wire        reset,

    input  wire        stall,          // load-use暂停
    input  wire        flush,          // 冲刷流水线
    input  wire        redirect_valid, // EX阶段重定向请求
    input  wire [31:0] redirect_pc,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    output reg         if_id_valid,
    output reg  [31:0] if_id_pc,
    output reg  [31:0] if_id_instr
);

    reg [31:0] pc;

    assign imem_addr = pc;

    // PC和IF/ID流水寄存器
    always @(posedge clk) begin
        if (reset) begin
            pc          <= 32'b0;
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'b0;
            if_id_instr <= 32'b0;
        end else if (redirect_valid) begin
            pc          <= redirect_pc;
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'b0;
            if_id_instr <= 32'b0;
        end else if (flush) begin
            if_id_valid <= 1'b0;
            if_id_pc    <= 32'b0;
            if_id_instr <= 32'b0;
        end else if (stall) begin
            pc          <= pc;
            if_id_valid <= if_id_valid;
            if_id_pc    <= if_id_pc;
            if_id_instr <= if_id_instr;
        end else begin
            pc          <= pc + 32'd4;
            if_id_valid <= 1'b1;
            if_id_pc    <= pc;
            if_id_instr <= imem_rdata;
        end
    end

endmodule
