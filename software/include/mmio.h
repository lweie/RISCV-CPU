#ifndef MMIO_H
#define MMIO_H

#include <stdint.h>

/* 修改地址映射时必须同步更新src/soc/memory_map.vh。 */
#define RAM_BASE       0x00000000u
#define RAM_SIZE       0x00010000u
#define UART_BASE      0x10000000u
#define UART_SIZE      0x00001000u
#define TIMER_BASE     0x10001000u
#define TIMER_SIZE     0x00001000u
#define KEYBOARD_BASE  0x10002000u
#define KEYBOARD_SIZE  0x00001000u
#define VGA_CTRL_BASE  0x10003000u
#define VGA_CTRL_SIZE  0x00001000u
#define VGA_FB_BASE    0x20000000u
#define VGA_FB_SIZE    0x00020000u

static inline void mmio_write8(uint32_t addr, uint8_t value)
{
    *(volatile uint8_t *)(uintptr_t)addr = value;
}

static inline void mmio_write16(uint32_t addr, uint16_t value)
{
    *(volatile uint16_t *)(uintptr_t)addr = value;
}

static inline void mmio_write32(uint32_t addr, uint32_t value)
{
    *(volatile uint32_t *)(uintptr_t)addr = value;
}

static inline uint8_t mmio_read8(uint32_t addr)
{
    return *(volatile uint8_t *)(uintptr_t)addr;
}

static inline uint16_t mmio_read16(uint32_t addr)
{
    return *(volatile uint16_t *)(uintptr_t)addr;
}

static inline uint32_t mmio_read32(uint32_t addr)
{
    return *(volatile uint32_t *)(uintptr_t)addr;
}

#endif
