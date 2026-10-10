`include "memory_map.vh"

// IF和Data Port共享的64 KiB主存
module main_memory #(
    parameter INIT_FILE = ""
) (
    input  wire        clk,

    input  wire [31:0] imem_addr,
    output wire [31:0] imem_rdata,

    input  wire        dmem_sel,
    input  wire [31:0] dmem_addr,
    input  wire [31:0] dmem_wdata,
    input  wire [3:0]  dmem_wstrb,
    output wire [31:0] dmem_rdata
);

    reg [31:0] memory [0:16383];
    integer i;

    initial begin
        for (i = 0; i < 16384; i = i + 1)
            memory[i] = 32'b0;

        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

    // 当前Core要求固定时序组合读，写入在时钟上升沿完成
    assign imem_rdata = (imem_addr < `RAM_END) ?
                        memory[imem_addr[15:2]] : 32'b0;
    assign dmem_rdata = dmem_sel ? memory[dmem_addr[15:2]] : 32'b0;

    always @(posedge clk) begin
        if (dmem_sel) begin
            if (dmem_wstrb[0])
                memory[dmem_addr[15:2]][7:0] <= dmem_wdata[7:0];
            if (dmem_wstrb[1])
                memory[dmem_addr[15:2]][15:8] <= dmem_wdata[15:8];
            if (dmem_wstrb[2])
                memory[dmem_addr[15:2]][23:16] <= dmem_wdata[23:16];
            if (dmem_wstrb[3])
                memory[dmem_addr[15:2]][31:24] <= dmem_wdata[31:24];
        end
    end

endmodule
