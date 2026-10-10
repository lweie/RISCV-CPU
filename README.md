# RV32IM五级流水线CPU设计

本项目实现了一个使用纯Verilog-2001编写的32位RISC-V处理器核心。处理器采用经典的IF（取指）→ ID（译码）→ EX（执行）→ MEM（访存）→ WB（写回）五级流水线，在原有RV32I基础上增加了完整RV32M整数乘除法、64项BHT+BTB动态分支预测和误预测恢复。

`core`内部继续采用分离的Instruction Memory和Data Memory接口；新增的`src/soc`层将两者接入统一Main RAM，并对Data Port完成MMIO地址译码。当前SoC不包含Cache、MMU、CSR、中断和外部总线握手，UART、Timer、Keyboard与VGA仅预留地址窗口。

---

## 🚀 核心架构特性

### 1. 五级流水线

- **IF阶段**：维护PC、查询分支预测器、完成取指并保存IF/ID流水寄存器
- **ID阶段**：完成指令译码、寄存器读取、立即数生成和冒险检测
- **EX阶段**：完成Forwarding、ALU、乘除法控制和真实控制流解析
- **MEM阶段**：完成Load/Store访问、数据扩展和byte enable生成
- **WB阶段**：在ALU结果、Load结果和PC + 4之间选择写回数据

仍然保留四组流水寄存器：

```text
IF/ID -> ID/EX -> EX/MEM -> MEM/WB
```

### 2. 数据冒险处理

- 实现EX/MEM → EX前递
- 实现MEM/WB → EX前递
- EX/MEM前递优先级高于MEM/WB
- `reg_write`有效且`rd != x0`时才允许前递
- 前递结果用于ALU、Multiplier、Divider、Branch、Store data和JALR
- Register File包含WB → ID同周期旁路
- x0始终读取为0，并禁止写入

### 3. Load-use暂停

ID阶段根据`uses_rs1`和`uses_rs2`判断当前指令是否真正使用源寄存器。当ID/EX中的Load目标寄存器产生相关时：

1. PC保持
2. IF/ID保持
3. ID/EX插入bubble
4. Load继续向后续流水级推进

LUI、JAL等不使用对应源寄存器的指令不会产生虚假暂停。

### 4. Divider暂停

DIV、DIVU、REM和REMU在EX阶段启动多周期Divider。运算期间：

- PC和IF/ID保持
- ID/EX保持当前除法指令上下文
- EX/MEM在等待周期写入bubble，防止旧指令重复提交
- Divider完成时，结果只进入EX/MEM一次
- 流水线随后恢复正常推进

`start`只在Divider空闲且当前EX指令为新的除法指令时有效。`busy`表示迭代计算进行中，`done`是结果完成事件。

### 5. 全局控制优先级

```text
reset
  > branch/jump misprediction redirect + flush
  > divider stall
  > load-use stall
  > normal pipeline advance
```

误预测恢复不会被普通Stall阻止。

---

## 🔧 指令集支持

### RV32I

| 类型 | 指令 |
| --- | --- |
| R-Type | ADD、SUB、SLL、SLT、SLTU、XOR、SRL、SRA、OR、AND |
| I-Type | ADDI、SLTI、SLTIU、XORI、ORI、ANDI、SLLI、SRLI、SRAI |
| Load | LB、LH、LW、LBU、LHU |
| Store | SB、SH、SW |
| Branch | BEQ、BNE、BLT、BGE、BLTU、BGEU |
| Jump | JAL、JALR |
| Upper Immediate | LUI、AUIPC |

### RV32M

| 类型 | 指令 | 实现方式 |
| --- | --- | --- |
| Multiply | MUL、MULH、MULHSU、MULHU | 单周期组合乘法器 |
| Divide | DIV、DIVU、REM、REMU | 32轮多周期恢复除法器 |

Multiplier使用64位乘积：

- MUL取低32位
- MULH执行signed × signed并取高32位
- MULHSU执行signed × unsigned并取高32位
- MULHU执行unsigned × unsigned并取高32位

实现中先显式计算操作数绝对值，再根据操作类型恢复64位乘积符号，避免Verilog signed/unsigned表达式自动转换造成高位错误。

Divider处理RV32M规定的特殊情况：

- DIV/DIVU除数为0时返回`32'hffff_ffff`
- REM/REMU除数为0时返回原dividend
- `32'h8000_0000 / 32'hffff_ffff`时，DIV返回`32'h8000_0000`
- 对应REM返回`32'h0000_0000`

---

## 🎯 动态分支预测

### BHT

- 64项Branch History Table
- 使用`PC[7:2]`作为Index
- 每项为2-bit饱和计数器
- Reset后初始化为`01`（Weakly Not Taken）
- 使用计数器最高位作为Taken/Not Taken预测

条件分支在EX阶段得到真实结果后更新BHT：

```text
actual taken     -> counter + 1，最大为11
actual not taken -> counter - 1，最小为00
```

### BTB

- 64项Direct-Mapped Branch Target Buffer
- Index：`PC[7:2]`
- Tag：`PC[31:8]`
- 每项保存valid、tag和target PC
- BTB查询同时检查Index和Tag
- Taken Branch、JAL和JALR在EX解析后更新BTB

### Jump预测策略

- JAL在IF阶段根据完整指令立即数静态预测Taken
- JALR在BTB命中时预测Taken并使用BTB target
- JALR未命中时预测PC + 4
- 当前不包含Return Address Stack

### Prediction Metadata

IF/ID和ID/EX保存：

- `predicted_taken`
- `predicted_target`
- `predicted_next_pc`

这些信息与对应指令一起到达EX，避免使用当前IF预测结果判断另一条已进入EX的指令。

### Misprediction Recovery

EX阶段计算：

```text
actual_next_pc = actual_taken ? actual_target : ex_pc + 4
mispredict     = predicted_next_pc != actual_next_pc
```

该比较能够同时检测方向预测错误和目标地址预测错误：

- 预测正确：不Flush
- 预测错误：redirect到`actual_next_pc`
- IF/ID和ID/EX中的错误路径指令被置为无效
- 错误路径指令不能写Register File或Data Memory

---

## 📁 项目结构

```text
RISCV-CPU/
├── README.md                # 项目说明
├── src/
│   ├── soc/
│   │   ├── memory_map.vh    # RTL地址映射
│   │   ├── mmio_interconnect.v # Data Port地址译码和读数据选择
│   │   ├── main_memory.v    # IF/Data共享的64 KiB Main RAM
│   │   └── soc_top.v        # CPU、Main RAM和Interconnect顶层
│   │
│   ├── core.v               # CPU顶层和结构级连接
│   ├── IF.v                 # PC、预测next PC和IF/ID流水寄存器
│   ├── ID.v                 # Decoder、Register File和ID/EX流水寄存器
│   ├── EX.v                 # Forwarding、RV32M控制和控制流解析
│   ├── MEM.v                # Data Memory访问和MEM/WB流水寄存器
│   ├── WB.v                 # Writeback数据选择
│   ├── multiplier.v         # RV32M组合乘法器
│   ├── divider.v            # RV32M多周期迭代除法器
│   └── branch_predictor.v   # 64项BHT和BTB
└── software/
    ├── Makefile             # RV32IM裸机构建入口
    ├── linker.ld            # 64 KiB RAM链接布局
    ├── start.S              # Reset入口和最小启动代码
    ├── main.c               # 最小C程序
    ├── include/mmio.h       # 软件侧MMIO地址定义
    ├── scripts/bin2hex.py   # BIN转readmemh HEX
    └── README.md            # 软件构建和加载说明
```

`core.v`只负责CPU内部实例化和信号连接。SoC地址译码、统一主存和软件构建均位于独立目录，不把系统逻辑重新写入流水级。

---

## 📦 Pipeline Register内容

### IF/ID

- `valid`、PC、instruction
- predicted taken
- predicted target
- predicted next PC

### ID/EX

- `valid`、PC
- rs1/rs2寄存器值与索引、rd
- immediate
- ALU操作和操作数选择
- Load/Store、Branch/Jump和Writeback控制
- RV32M操作类型
- Prediction Metadata

### EX/MEM

- `valid`、rd
- ALU或RV32M结果
- Store data
- PC + 4
- Register File、Memory和Writeback控制

### MEM/WB

- `valid`、rd
- ALU/RV32M结果
- Load结果
- PC + 4
- Register File和Writeback控制

---

## 🔌 顶层接口

CPU顶层模块仍为`core`，Data Port增加`dmem_valid`访问指示：

```verilog
module core (
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    output wire        dmem_valid,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata
);
```

`dmem_valid`仅在MEM阶段存在有效Load或Store时拉高。`dmem_wstrb != 0`表示写访问，`dmem_valid && dmem_wstrb == 0`表示读访问；接口没有`ready`，仍按固定时序、零等待模型工作。

可直接集成的系统顶层为`soc_top`：

```text
core
  ├── Instruction Port ──────────────┐
  └── Data Port ── MMIO Interconnect ├── Main RAM
                       ├──────────────┴── UART window
                       ├───────────────── Timer window
                       ├───────────────── Keyboard window
                       ├───────────────── VGA CTRL window
                       └───────────────── VGA FB window
```

Instruction Port和RAM Data Port访问`main_memory.v`中的同一数组。外设窗口当前只输出Select及共享的地址、写数据和byte strobe，读数据固定为0，写入不产生副作用。

Reset为高有效同步复位。复位时PC、Pipeline valid、Divider状态、BHT和BTB均回到初始状态。

---

## 🗺️ SoC Memory Map

| 区域 | 起始地址 | 结束地址 | 大小 | 当前状态 |
| --- | --- | --- | --- | --- |
| Main RAM | `0x0000_0000` | `0x0000_FFFF` | 64 KiB | 已实现 |
| UART | `0x1000_0000` | `0x1000_0FFF` | 4 KiB | 仅预留译码 |
| Timer | `0x1000_1000` | `0x1000_1FFF` | 4 KiB | 仅预留译码 |
| Keyboard | `0x1000_2000` | `0x1000_2FFF` | 4 KiB | 仅预留译码 |
| VGA CTRL | `0x1000_3000` | `0x1000_3FFF` | 4 KiB | 仅预留译码 |
| VGA Framebuffer | `0x2000_0000` | `0x2001_FFFF` | 128 KiB | 仅预留译码 |

RTL地址常量集中在`src/soc/memory_map.vh`，软件侧镜像位于`software/include/mmio.h`。修改地址映射时应同时更新两处。未映射地址读取返回0，写入不选中任何Slave。

---

## 💻 Bare-metal软件

`software/`使用RISC-V GCC交叉工具链把C和启动汇编链接到地址`0x0000_0000`。默认编译选项与当前硬件一致：

```text
-march=rv32im -mabi=ilp32
```

构建命令：

```bash
cd software
make
```

输出包括`program.elf`、`program.bin`、`program.hex`、`program.dump`和`program.map`。`start.S`设置栈顶、清零`.bss`并调用`main`；工程不依赖操作系统、标准C运行库或CSR。

仿真时将HEX传给SoC顶层：

```verilog
soc_top #(
    .MEM_INIT_FILE("software/build/program.hex")
) dut (...);
```

HEX每行保存一个little-endian 32位word，可由`main_memory.v`的`$readmemh`直接加载。详细工具链配置和文件说明见`software/README.md`。

---

## ✅ 当前实现进度

### 已完成

- ✅ RV32I五级流水线
- ✅ 完整RV32M整数乘除法指令
- ✅ EX/MEM和MEM/WB Forwarding
- ✅ Forwarding覆盖ALU、MUL、DIV、Store、Branch和JALR
- ✅ Load-use Stall和bubble插入
- ✅ Divider Stall及一次性start/done交接
- ✅ 64项2-bit BHT
- ✅ 64项带Tag的Direct-Mapped BTB
- ✅ JAL静态预测和JALR BTB预测
- ✅ Prediction Metadata随指令传递
- ✅ EX真实控制流解析
- ✅ 仅在Misprediction时Redirect和Flush
- ✅ Load符号/零扩展和Store byte enable
- ✅ x0保护和同步Reset
- ✅ Data Port有效访问指示`dmem_valid`
- ✅ 统一Memory Map和MMIO Interconnect
- ✅ 64 KiB IF/Data共享Main RAM
- ✅ UART、Timer、Keyboard和VGA地址窗口预留
- ✅ RV32IM Bare-metal C启动、链接和HEX转换环境

### 已执行检查

- Icarus Verilog Verilog-2001编译检查
- Verilator Verilog-2001 lint
- 禁止的SystemVerilog关键字扫描
- MUL、MULH、MULHSU、MULHU定向运算检查
- DIV、DIVU、REM、REMU定向运算检查
- Division by zero和`INT_MIN / -1`检查
- BHT状态更新、BTB Tag alias和JAL预测检查
- SoC顶层Icarus Verilog编译和Verilator lint
- MMIO各地址窗口边界、Select互斥和Read Data Mux检查
- `dmem_valid`有效项门控和Store byte strobe透传检查
- Main RAM整字、单字节、半字写入以及IF/Data共享读取检查
- RTL/C Memory Map一致性和BIN转HEX little-endian/补零检查

基础编译命令：

```bash
iverilog -g2001 -Wall -s core -tnull \
  src/core.v src/IF.v src/ID.v src/EX.v src/MEM.v src/WB.v \
  src/multiplier.v src/divider.v src/branch_predictor.v
```

---

## 🧪 建议的后续Testbench场景

### RV32M和Forwarding

1. `add -> mul`：验证ALU结果前递到Multiplier
2. `mul -> add`：验证乘法结果从EX/MEM前递
3. `add -> div`：验证前递后的操作数进入Divider
4. `div -> add`：验证Divider Stall和完成后的结果依赖
5. DIV/REM除数为0
6. `INT_MIN / -1`
7. 连续两条DIV/REM
8. `mul/div -> store、branch、jalr`

### Branch Predictor

1. 连续Taken Branch
2. 连续Not Taken Branch
3. Taken/Not Taken交替
4. 同一Branch循环执行，观察2-bit计数器学习
5. BTB Index相同但Tag不同
6. 方向预测正确
7. 方向预测错误
8. 方向正确但BTB target错误
9. `add -> branch` Forwarding
10. `load -> branch` Load-use Stall
11. JAL静态预测
12. JALR首次未命中和后续BTB命中

---

## ⚠️ 当前限制

- 不支持FENCE、ECALL、EBREAK和CSR指令
- 不支持A/F/D/C/V等扩展
- 不包含异常、中断和特权级处理
- UART、Timer、Keyboard和VGA尚未实现实际寄存器或存储，仅完成地址译码
- 不包含AXI、Wishbone、MMU、TLB和Cache
- 分支预测器不包含RAS、GShare、Tournament或TAGE
- 不处理非法指令异常，未支持编码作为无效流水项处理
- 没有非对齐访问异常或跨32位边界拆分机制，LH/LW/SH/SW应自然对齐
- Memory接口不支持wait state
- 当前Main RAM采用组合读、同步byte write，以匹配Core的固定零等待时序；映射到特定FPGA同步Block RAM时可能需要调整CPU/Memory时序
- Instruction Port只从Main RAM取指，不允许从MMIO区域执行代码
- Divider固定执行32轮迭代，当前没有提前结束优化
- Bare-metal构建需要另行安装`riscv32-unknown-elf-`或兼容的RISC-V GCC工具链
- 当前仍缺少完整SoC程序级Testbench、外设模型和差分测试

---

## 🎯 后续优化方向

1. 建立能够加载`program.hex`的SoC程序级Testbench
2. 在预留Select端口后接入UART、Timer、Keyboard和VGA Slave
3. 增加RISC-V汇编测试与参考模型比对
4. 统计BHT/BTB命中率和Misprediction率
5. 为Divider增加前导零检测或提前结束
6. 完成FPGA RAM适配、综合、资源占用和时序检查

当前项目保持经典五级流水CPU边界，在Core之外完成了统一Main RAM、MMIO地址空间和Bare-metal C构建链路，为后续逐个接入实际外设提供了稳定接口。
