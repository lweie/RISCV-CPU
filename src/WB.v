// 写回阶段：选择最终写回数据
module WB_stage (
    input  wire        mem_wb_valid,
    input  wire [4:0]  mem_wb_rd,
    input  wire [31:0] mem_wb_alu_result,
    input  wire [31:0] mem_wb_load_result,
    input  wire [31:0] mem_wb_pc4,
    input  wire        mem_wb_reg_write,
    input  wire [1:0]  mem_wb_wb_sel,

    output wire        wb_reg_write,
    output wire [4:0]  wb_rd,
    output reg  [31:0] wb_data
);

    localparam WB_ALU  = 2'b00;
    localparam WB_LOAD = 2'b01;
    localparam WB_PC4  = 2'b10;

    assign wb_reg_write = mem_wb_valid && mem_wb_reg_write &&
                          (mem_wb_rd != 5'b0);
    assign wb_rd = mem_wb_rd;

    always @(*) begin
        case (mem_wb_wb_sel)
            WB_LOAD: wb_data = mem_wb_load_result;
            WB_PC4:  wb_data = mem_wb_pc4;
            WB_ALU:  wb_data = mem_wb_alu_result;
            default: wb_data = 32'b0;
        endcase
    end

endmodule
