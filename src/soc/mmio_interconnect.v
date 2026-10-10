`include "memory_map.vh"

// Data Port地址译码和读数据选择
module mmio_interconnect (
    input  wire        cpu_valid,
    input  wire [31:0] cpu_addr,
    input  wire [31:0] cpu_wdata,
    input  wire [3:0]  cpu_wstrb,
    output reg  [31:0] cpu_rdata,

    output wire        ram_sel,
    output wire        uart_sel,
    output wire        timer_sel,
    output wire        keyboard_sel,
    output wire        vga_ctrl_sel,
    output wire        vga_fb_sel,

    output wire [31:0] device_addr,
    output wire [31:0] device_wdata,
    output wire [3:0]  device_wstrb,

    input  wire [31:0] ram_rdata,
    input  wire [31:0] uart_rdata,
    input  wire [31:0] timer_rdata,
    input  wire [31:0] keyboard_rdata,
    input  wire [31:0] vga_ctrl_rdata,
    input  wire [31:0] vga_fb_rdata
);

    assign ram_sel = cpu_valid && (cpu_addr < `RAM_END);
    assign uart_sel = cpu_valid &&
                      (cpu_addr >= `UART_BASE) && (cpu_addr < `UART_END);
    assign timer_sel = cpu_valid &&
                       (cpu_addr >= `TIMER_BASE) && (cpu_addr < `TIMER_END);
    assign keyboard_sel = cpu_valid &&
                          (cpu_addr >= `KEYBOARD_BASE) &&
                          (cpu_addr < `KEYBOARD_END);
    assign vga_ctrl_sel = cpu_valid &&
                          (cpu_addr >= `VGA_CTRL_BASE) &&
                          (cpu_addr < `VGA_CTRL_END);
    assign vga_fb_sel = cpu_valid &&
                        (cpu_addr >= `VGA_FB_BASE) &&
                        (cpu_addr < `VGA_FB_END);

    // 下游设备共享地址、写数据和byte strobe
    assign device_addr  = cpu_addr;
    assign device_wdata = cpu_wdata;
    assign device_wstrb = cpu_wstrb;

    // 未映射地址读取返回0，写入不选中任何设备
    always @(*) begin
        if (ram_sel)
            cpu_rdata = ram_rdata;
        else if (uart_sel)
            cpu_rdata = uart_rdata;
        else if (timer_sel)
            cpu_rdata = timer_rdata;
        else if (keyboard_sel)
            cpu_rdata = keyboard_rdata;
        else if (vga_ctrl_sel)
            cpu_rdata = vga_ctrl_rdata;
        else if (vga_fb_sel)
            cpu_rdata = vga_fb_rdata;
        else
            cpu_rdata = 32'b0;
    end

endmodule
