`ifndef MEMORY_MAP_VH
`define MEMORY_MAP_VH

// 修改地址映射时必须同步更新software/include/mmio.h
`define RAM_BASE       32'h0000_0000
`define RAM_SIZE       32'h0001_0000
`define RAM_END        32'h0001_0000

`define UART_BASE      32'h1000_0000
`define UART_SIZE      32'h0000_1000
`define UART_END       32'h1000_1000

`define TIMER_BASE     32'h1000_1000
`define TIMER_SIZE     32'h0000_1000
`define TIMER_END      32'h1000_2000

`define KEYBOARD_BASE  32'h1000_2000
`define KEYBOARD_SIZE  32'h0000_1000
`define KEYBOARD_END   32'h1000_3000

`define VGA_CTRL_BASE  32'h1000_3000
`define VGA_CTRL_SIZE  32'h0000_1000
`define VGA_CTRL_END   32'h1000_4000

`define VGA_FB_BASE    32'h2000_0000
`define VGA_FB_SIZE    32'h0002_0000
`define VGA_FB_END     32'h2002_0000

`endif
