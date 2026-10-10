# RV32IM裸机软件环境

该目录提供当前CPU使用的最小Bare-metal C构建环境。软件在开发主机上通过RISC-V GCC交叉编译，生成ELF、BIN、HEX、反汇编和Map文件；CPU本身不运行编译器，也不依赖操作系统或C运行库。

## 工具链

默认工具链前缀为：

```text
riscv32-unknown-elf-
```

编译参数与当前CPU实际支持的ISA一致：

```text
-march=rv32im
-mabi=ilp32
```

如果环境只安装了64位前缀的交叉工具链，可以使用：

```bash
make CROSS=riscv64-unknown-elf-
```

不要把`ARCH`改为包含C、A、F、D、V或Zicsr等当前CPU未实现的扩展。

## 构建

```bash
make
make dump
make clean
```

Windows环境如果命令名为`python`，可以执行：

```bash
make PYTHON=python
```

构建完成后生成：

```text
build/program.elf
build/program.bin
build/program.hex
build/program.dump
build/program.map
```

`program.dump`由`objdump -d -S`生成，应检查其中不存在当前CPU未支持的指令。

## 启动流程

`start.S`中的`_start`位于地址`0x00000000`，依次完成：

1. 将`sp`设置为`_stack_top`
2. 清零`_bss_start`到`_bss_end`
3. 调用`main`
4. `main`返回后进入无限循环

不包含CSR、异常、中断或操作系统初始化。

## Memory Layout

`linker.ld`将完整程序链接到64 KiB Main RAM：

```text
0x00000000  .text / .rodata / .data / .bss
             ...
0x0000F000  4 KiB stack reserved area
0x00010000  _stack_top
```

Instruction Port和Data Port访问同一个Main Memory数组，因此软件使用统一地址空间。`program.bin`包含已经位于最终RAM地址的`.text/.rodata/.data`内容，启动代码不执行ROM到RAM的`.data`复制；`.bss`仍由`start.S`清零。

## BIN转HEX

`scripts/bin2hex.py`每次读取4个little-endian byte并输出一个32位`$readmemh` word。例如：

```text
13 05 00 00 -> 00000513
```

最后不足4字节时自动补零。

## 加载program.hex

SoC仿真顶层通过参数指定初始化文件：

```verilog
soc_top #(
    .MEM_INIT_FILE("software/build/program.hex")
) dut (
    .clk   (clk),
    .reset (reset)
    // 其余预留端口按仿真需要连接
);
```

`$readmemh`路径相对于仿真器工作目录。FPGA工程中应将同一个HEX文件加入工程，并把参数或Memory初始化路径指向该文件。

## MMIO

`include/mmio.h`提供8/16/32位volatile MMIO访问函数和与RTL一致的地址常量。当前UART、Timer、Keyboard和VGA仍是预留区域，读取返回0、写入忽略；示例`main.c`不会访问这些未实现外设。
