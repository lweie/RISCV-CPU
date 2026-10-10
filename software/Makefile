CROSS   ?= riscv32-unknown-elf-
ARCH    ?= rv32im
ABI     ?= ilp32
PYTHON  ?= python3

CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size

BUILD   := build
TARGET  := $(BUILD)/program
OBJECTS := $(BUILD)/start.o $(BUILD)/main.o

COMMON_FLAGS := -march=$(ARCH) -mabi=$(ABI) -mno-relax \
	-ffreestanding -fno-builtin -msmall-data-limit=0 -mstrict-align
CFLAGS  := $(COMMON_FLAGS) -O2 -Wall -Wextra -Iinclude \
	-ffunction-sections -fdata-sections
ASFLAGS := $(COMMON_FLAGS)
LDFLAGS := -march=$(ARCH) -mabi=$(ABI) -nostdlib -nostartfiles \
	-Wl,--no-relax -Wl,--gc-sections -Wl,--build-id=none \
	-Wl,-T,linker.ld -Wl,-Map,$(TARGET).map

.PHONY: all clean dump

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).dump
	$(SIZE) $(TARGET).elf

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/start.o: start.S | $(BUILD)
	$(CC) $(ASFLAGS) -c $< -o $@

$(BUILD)/main.o: main.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJECTS) linker.ld
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).bin scripts/bin2hex.py
	$(PYTHON) scripts/bin2hex.py $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -d -S $< > $@

dump: $(TARGET).dump

clean:
	rm -rf $(BUILD)
