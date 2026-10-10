// 访存阶段：生成存储掩码并完成加载数据扩展
module MEM_stage (
    input  wire        clk,
    input  wire        reset,

    input  wire        ex_mem_valid,
    input  wire [4:0]  ex_mem_rd,
    input  wire [31:0] ex_mem_alu_result,
    input  wire [31:0] ex_mem_store_data,
    input  wire [31:0] ex_mem_pc4,
    input  wire        ex_mem_reg_write,
    input  wire        ex_mem_mem_read,
    input  wire        ex_mem_mem_write,
    input  wire [2:0]  ex_mem_mem_type,
    input  wire [1:0]  ex_mem_wb_sel,

    output wire        dmem_valid,
    output wire [31:0] dmem_addr,
    output reg  [31:0] dmem_wdata,
    output reg  [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata,

    output reg         mem_wb_valid,
    output reg  [4:0]  mem_wb_rd,
    output reg  [31:0] mem_wb_alu_result,
    output reg  [31:0] mem_wb_load_result,
    output reg  [31:0] mem_wb_pc4,
    output reg         mem_wb_reg_write,
    output reg  [1:0]  mem_wb_wb_sel
);

    reg  [31:0] shifted_load_data;
    reg  [31:0] load_result;
    wire [4:0]  byte_shift;

    assign dmem_addr = ex_mem_alu_result;
    assign dmem_valid = ex_mem_valid &&
                        (ex_mem_mem_read || ex_mem_mem_write);
    assign byte_shift = {ex_mem_alu_result[1:0], 3'b000};

    // 地址低两位选择写数据所在的byte lane
    always @(*) begin
        dmem_wdata = 32'b0;
        dmem_wstrb = 4'b0000;

        if (ex_mem_valid && ex_mem_mem_write) begin
            case (ex_mem_mem_type)
                3'b000: begin // SB
                    dmem_wdata = {24'b0, ex_mem_store_data[7:0]} <<
                                 byte_shift;
                    dmem_wstrb = 4'b0001 << ex_mem_alu_result[1:0];
                end
                3'b001: begin // SH
                    dmem_wdata = {16'b0, ex_mem_store_data[15:0]} <<
                                 byte_shift;
                    dmem_wstrb = 4'b0011 << ex_mem_alu_result[1:0];
                end
                3'b010: begin // SW
                    dmem_wdata = ex_mem_store_data << byte_shift;
                    dmem_wstrb = 4'b1111 << ex_mem_alu_result[1:0];
                end
                default: begin
                    dmem_wdata = 32'b0;
                    dmem_wstrb = 4'b0000;
                end
            endcase
        end
    end

    // Load数据选择以及符号/零扩展
    always @(*) begin
        shifted_load_data = dmem_rdata >> byte_shift;
        load_result       = 32'b0;

        if (ex_mem_valid && ex_mem_mem_read) begin
            case (ex_mem_mem_type)
                3'b000: load_result = {{24{shifted_load_data[7]}},
                                        shifted_load_data[7:0]};   // LB
                3'b001: load_result = {{16{shifted_load_data[15]}},
                                        shifted_load_data[15:0]};  // LH
                3'b010: load_result = shifted_load_data;           // LW
                3'b100: load_result = {24'b0, shifted_load_data[7:0]};  // LBU
                3'b101: load_result = {16'b0, shifted_load_data[15:0]}; // LHU
                default: load_result = 32'b0;
            endcase
        end
    end

    // MEM/WB流水寄存器
    always @(posedge clk) begin
        if (reset) begin
            mem_wb_valid       <= 1'b0;
            mem_wb_rd          <= 5'b0;
            mem_wb_alu_result  <= 32'b0;
            mem_wb_load_result <= 32'b0;
            mem_wb_pc4         <= 32'b0;
            mem_wb_reg_write   <= 1'b0;
            mem_wb_wb_sel      <= 2'b0;
        end else begin
            mem_wb_valid       <= ex_mem_valid;
            mem_wb_rd          <= ex_mem_rd;
            mem_wb_alu_result  <= ex_mem_alu_result;
            mem_wb_load_result <= load_result;
            mem_wb_pc4         <= ex_mem_pc4;
            mem_wb_reg_write   <= ex_mem_reg_write;
            mem_wb_wb_sel      <= ex_mem_wb_sel;
        end
    end

endmodule
