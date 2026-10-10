// CPU、统一主存和MMIO Interconnect顶层
module soc_top #(
    parameter MEM_INIT_FILE = ""
) (
    input  wire        clk,
    input  wire        reset,

    output wire        ram_sel,
    output wire        uart_sel,
    output wire        timer_sel,
    output wire        keyboard_sel,
    output wire        vga_ctrl_sel,
    output wire        vga_fb_sel,
    output wire [31:0] peripheral_addr,
    output wire [31:0] peripheral_wdata,
    output wire [3:0]  peripheral_wstrb
);

    wire [31:0] imem_addr;
    wire [31:0] imem_rdata;
    wire        dmem_valid;
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_wstrb;
    wire [31:0] dmem_rdata;
    wire [31:0] ram_rdata;

    // 外设Slave尚未实现，当前读取统一返回0
    wire [31:0] uart_rdata;
    wire [31:0] timer_rdata;
    wire [31:0] keyboard_rdata;
    wire [31:0] vga_ctrl_rdata;
    wire [31:0] vga_fb_rdata;

    assign uart_rdata     = 32'b0;
    assign timer_rdata    = 32'b0;
    assign keyboard_rdata = 32'b0;
    assign vga_ctrl_rdata = 32'b0;
    assign vga_fb_rdata   = 32'b0;

    core u_core (
        .clk        (clk),
        .reset      (reset),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_valid (dmem_valid),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_wstrb (dmem_wstrb),
        .dmem_rdata (dmem_rdata)
    );

    mmio_interconnect u_mmio_interconnect (
        .cpu_valid       (dmem_valid),
        .cpu_addr        (dmem_addr),
        .cpu_wdata       (dmem_wdata),
        .cpu_wstrb       (dmem_wstrb),
        .cpu_rdata       (dmem_rdata),
        .ram_sel         (ram_sel),
        .uart_sel        (uart_sel),
        .timer_sel       (timer_sel),
        .keyboard_sel    (keyboard_sel),
        .vga_ctrl_sel    (vga_ctrl_sel),
        .vga_fb_sel      (vga_fb_sel),
        .device_addr     (peripheral_addr),
        .device_wdata    (peripheral_wdata),
        .device_wstrb    (peripheral_wstrb),
        .ram_rdata       (ram_rdata),
        .uart_rdata      (uart_rdata),
        .timer_rdata     (timer_rdata),
        .keyboard_rdata  (keyboard_rdata),
        .vga_ctrl_rdata  (vga_ctrl_rdata),
        .vga_fb_rdata    (vga_fb_rdata)
    );

    main_memory #(
        .INIT_FILE (MEM_INIT_FILE)
    ) u_main_memory (
        .clk         (clk),
        .imem_addr   (imem_addr),
        .imem_rdata  (imem_rdata),
        .dmem_sel    (ram_sel),
        .dmem_addr   (peripheral_addr),
        .dmem_wdata  (peripheral_wdata),
        .dmem_wstrb  (peripheral_wstrb),
        .dmem_rdata  (ram_rdata)
    );

endmodule
