# RV32I五级流水线CPU设计

本项目实现了一个使用纯Verilog-2001编写的32位RISC-V处理器核心。处理器采用经典的IF（取指）→ ID（译码）→ EX（执行）→ MEM（访存）→ WB（写回）五级流水线，并实现数据前递、load-use暂停以及分支跳转冲刷。

当前版本以RV32I普通整数指令和基础流水线控制为核心，采用Harvard结构，指令存储器与数据存储器接口相互独立。项目暂不包含Cache、MMU、CSR、中断、总线握手和动态分支预测等系统级功能。

---

## 🚀 核心架构特性

### 1. 五级流水线

- **IF阶段**：维护PC、完成取指和next PC选择，并保存IF/ID流水寄存器
- **ID阶段**：完成指令译码、寄存器读取、立即数生成和控制信号生成
- **EX阶段**：完成ALU运算、数据前递、分支比较和跳转目标计算
- **MEM阶段**：完成Load/Store数据选择、扩展和byte enable生成
- **WB阶段**：在ALU结果、Load结果和PC + 4之间选择写回数据

### 2. 数据冒险处理

- 实现EX/MEM → EX前递
- 实现MEM/WB → EX前递
- EX/MEM前递优先级高于MEM/WB
- 前递后的操作数同时用于ALU、Branch比较、Store data和JALR目标计算
- Register File包含WB → ID同周期旁路，避免写回与读取同周期产生旧值
- x0始终读取为0，并禁止写入

### 3. Load-use暂停

ID阶段根据当前指令的`uses_rs1`和`uses_rs2`进行有效源寄存器判断。当ID/EX中的Load目标寄存器被当前ID指令使用时：

1. PC保持不变
2. IF/ID流水寄存器保持不变
3. ID/EX流水寄存器插入bubble
4. Load继续向EX/MEM和MEM/WB推进

该检测不会因为LUI、JAL等不使用源寄存器的指令位域而产生虚假暂停。

### 4. 控制冒险处理

当前采用Predict Not Taken策略。Branch、JAL和JALR均在EX阶段确定是否重定向PC：

- taken Branch：`redirect_pc = PC + B-immediate`
- JAL：`redirect_pc = PC + J-immediate`
- JALR：`redirect_pc = (rs1 + I-immediate) & 32'hffff_fffe`

发生重定向时，IF/ID和ID/EX中的年轻指令被置为无效。控制优先级为：

```text
reset > EX redirect / flush > load-use stall > normal advance
```

---

## 🔧 RV32I指令支持

### R-Type

- ADD、SUB
- SLL、SLT、SLTU
- XOR、SRL、SRA
- OR、AND

### I-Type算术指令

- ADDI、SLTI、SLTIU
- XORI、ORI、ANDI
- SLLI、SRLI、SRAI

### Load / Store

- Load：LB、LH、LW、LBU、LHU
- Store：SB、SH、SW

MEM阶段根据地址低两位选择byte lane，并对Load结果进行符号扩展或零扩展。Store通过`dmem_wstrb[3:0]`给出有效字节掩码。

### Branch / Jump

- Branch：BEQ、BNE、BLT、BGE、BLTU、BGEU
- Jump：JAL、JALR

有符号比较使用`$signed(...)`，无符号比较保持普通32位比较。JAL和JALR均将PC + 4写入rd。

### Upper Immediate

- LUI
- AUIPC

---

## 📁 项目结构

```text
RISCV-CPU/
├── README.md           # 项目说明
└── src/
    ├── core.v          # CPU顶层和五级流水连接
    ├── IF.v            # PC与IF/ID流水寄存器
    ├── ID.v            # Decoder、Register File与ID/EX流水寄存器
    ├── EX.v            # Forwarding、ALU、Branch/Jump与EX/MEM流水寄存器
    ├── MEM.v           # Data Memory访问与MEM/WB流水寄存器
    └── WB.v            # Writeback数据选择
```

`core.v`只负责结构级连接，不包含完整Decoder、ALU、Register File或Immediate Generator实现。

---

## 📦 Pipeline Register内容

### IF/ID

- `valid`
- `PC`
- `instruction`

### ID/EX

- `valid`、`PC`
- rs1/rs2寄存器值与索引
- rd索引和immediate
- ALU操作及操作数选择
- Register File写使能
- Load/Store控制和访问类型
- Branch/Jump控制
- Writeback选择

### EX/MEM

- `valid`、rd
- ALU结果和Store data
- PC + 4
- Register File写使能
- Load/Store控制和访问类型
- Writeback选择

### MEM/WB

- `valid`、rd
- ALU结果
- Load结果
- PC + 4
- Register File写使能
- Writeback选择

---

## 🔌 顶层接口

顶层模块为`core`，使用分离的Instruction Memory和Data Memory接口：

```verilog
module core (
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] imem_addr,
    input  wire [31:0] imem_rdata,

    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    output wire [3:0]  dmem_wstrb,
    input  wire [31:0] dmem_rdata
);
```

当前接口不包含`valid`、`ready`或可变等待周期握手，默认指令和数据存储器能够在当前访问周期提供结果。

Reset为高有效同步复位。复位时PC清零，所有pipeline valid和可能产生副作用的流水控制状态失效。

---
当前项目保持为一个结构清晰、功能范围明确的RV32I五级流水线CPU基础实现，便于继续进行验证和后续功能扩展。
