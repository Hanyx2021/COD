# 中断与异常的实现

## 概念

### RISC-V 特权等级

| 编码 | 缩写 | 名称               |
| ---- | ---- | ------------------ |
| 00   | U    | User / Application |
| 01   | S    | Supervisor         |
| 10   | -    | -                  |
| 11   | M    | Machine            |

由上到下权限依次增加。

### 中断、异常与陷阱

注：文档中的 RISC-V hart 即为硬件线程。参考：[cpu architecture - RISC-V spec references the word 'hart' - what does 'hart' mean? - Stack Overflow](https://stackoverflow.com/questions/42676827/risc-v-spec-references-the-word-hart-what-does-hart-mean)

| 中文 | 英文      | 解释                                                         |
| ---- | --------- | ------------------------------------------------------------ |
| 异常 | exception | 线程内部发生的异常情况，与一条具体的指令相关                 |
| 中断 | interrupt | 来自外部的异步事件，可能导致控制流发生变化<br/>（experience an unexpected transfer of control） |
| 陷阱 | trap      | 由中断或异常引起，将控制交给一个陷阱句柄（trap handler）的过程 |

## CSR 寄存器与指令

### 编码规则与读写权限

- 编码：每个 CSR 对应一个 12-bit 数；
- 读写权限（不用考虑）：
  - 每个 CSR 可能为可读可写（RW）或只读（RO），由最高两位标识，RO 对应 11，其余情况均为 RW；
  - 每个 CSR 的读写亦与特权等级相关，`csr[9:8]` 为访问该寄存器的最低权限。

### 需要实现的 CSR 寄存器

| 编号    | 名字                                  | 权限 | 描述                                                         |
| ------- | ------------------------------------- | ---- | ------------------------------------------------------------ |
| `0x300` | `mstatus` 的 MPP 字段                 | MRW  | Machine status register.<br/>两个比特均需实现，只接受 00 (U) 或 11 (M)。 |
| `0x304` | [`mie` 的 MTIE 字段](#`mip` 与 `mie`) | MRW  | Machine interrupt-enable register.                           |
| `0x305` | [`mtvec`](#`mtvec`)                   | MRW  | Machine trap-handler base address.                           |
| `0x340` | [`mscratch`](#`mscratch`)             | MRW  | Scratch register for machine trap handlers.                  |
| `0x341` | [`mepc`](#`mepc`)                     | MRW  | Machine exception program counter.                           |
| `0x342` | [`mcause`](#`mcause`)                 | MRW  | Machine trap cause.                                          |
| `0x343` | `mtval`                               | MRW  | Machine bad address or instruction.<br/>本实验中恒为 0，无需实现。 |
| `0x344` | [`mip` 的 MTIP 字段](#`mip` 与 `mie`) | MRW  | Machine interrupt pending.                                   |
| `0x3A0` | `pmpcfg0`                             | MRW  | Physical memory protection configuration.                    |
| `0x3B0` | `pmpaddr0`                            | MRW  | Physical memory protection address register.                 |

具体实现规则见 privileged 文档 3.1.x 节。

#### `mip` 与 `mie`

`mip` 标记目前有何种中断等待处理，`mie` 标记何种中断需要/可以处理。

- 结构：
  - `mip[7]: MTIP, WARL`，是否有 M 态时钟中断待处理；及
  - `mie[7]: MTIE, WARL`，是否处理 M 态时钟中断。
- 何时写？
  - `mip`：TODO（检测到中断时如何处理）；及
  - `mie`：显式写，位于 `init.S:126-128`

#### `mtvec`

用于给出发生中断或异常时向何处跳转。

- 结构：
  - `[31:2]: BASE address, WARL`，中断或异常处理程序的基地址；及
  - `[1:0]: MODE, WARL`，决定跳转至何处，详见“何时读”。
- 何时写？
  - 显式写，位于 `init.S:112-123`
- 何时读？
  - 检测到中断或异常
  - 对于异常，将 `pc` 设为 `BASE`
  - 对于中断
    - 若 `MODE` 为 0（Direct），将 `pc` 设为 `BASE`
    - 若 `MODE` 为 1（Vectorized），将 `pc` 设为 `BASE + 4*cause`
    - 其余 `MODE` 非法

#### `mscratch`

用于标记 M 态上下文（寄存器的值）的地址空间。在进入 trap 时与 `pc` 发生交换，从而切换上下文。

- 结构：
  - `[31:0]: mscratch`，存储上下文的地址空间。
- 显式读写，见 `init.S:201`, `trap.S:9-14`, `trap.S:132`

#### `mepc`

用于标记发生中断或异常的位置，以便异常处理结束后恢复运行。

- 结构：
  - `[31:0]: mepc, WARL`，产生异常的地址。
- 何时写？
  - 发生中断或异常时，将 `mepc` 写为发生中断或异常的指令的【虚拟地址】；及
  - 显式写
- 何时读？
  - 执行 `mret` 时；及
  - TODO：其他情况？

#### `mcause`

用于给出中断或异常产生的原因。

- 结构：
  - `[31]: Interrupt`，产生中断设为 1，产生异常时设为 0；及
  - `[30:0]: Exception Code`，记录中断或异常的产生原因，见 `exception.h`。
- 何时写？
  - TODO：检测到中断时如何处理？
  - 发生异常时，将 `[31]` 置为 0，将 `[30:0]` 置为 `exception.h` 中规定的值。
  - TODO：执行 `mret` 时，是否要清空此寄存器？
- 何时读？
  - 显式读，用于跳转至不同的异常处理代码段，`trap.S:49`

### CSR 寄存器字段

| 名称 | 缩写                        | 写入要求                       | 读取结果                                                     | 异常                         |
| ---- | --------------------------- | ------------------------------ | ------------------------------------------------------------ | ---------------------------- |
| WPRI | Write Preserve, Read Ignore | 不修改该字段                   | 忽略该字段                                                   |                              |
| WLRL | Write Legal, Read Legal     | 可写入任意值，但不应写入非法值 | 非法写后可返回任意值，但该值由【非法写入的值】和【非法写入之前该字段的值】唯一确定。 | 可以但不必对非法写抛出异常。 |
| WARL | Write Any, Read Legal       | 可写入任意值                   | 返回合法值。但非法写后返回的合法值由【非法写入的值】和【hart 的体系结构状态】唯一确定。 | 对非法写不抛出异常。         |

### 需要额外实现的 CSR 指令

| 名称    | 编码                              | 功能                                                         |
| ------- | --------------------------------- | ------------------------------------------------------------ |
| `csrrc` | `funct3=011`<br/>`opcode=1110011` | 将 `csr` 的值符号扩展后写入 `rd`，然后将 `csr & ~rs1` 写入 `csr` |
| `csrrs` | `funct3=010`<br/>`opcode=1110011` | 将 `csr` 的值符号扩展后写入 `rd`，然后将 `csr | rs1` 写入 `csr` |
| `csrrw` | `funct3=001`<br/>`opcode=1110011` | 将 `csr` 的值符号扩展后写入 `rd`，然后将 `rs1` 写入 `csr`    |

注意：CSR 规范要求部分情况不进行读写，详情如下：

| 指令      | `rd`  | `rs1` | 读   | 写   |
| --------- | ----- | ----- | ---- | ---- |
| `CSRRW`   | `x0`  | -     | no   | yes  |
| `CSRRW`   | `!x0` | -     | yes  | yes  |
| `CSRRS/C` | -     | `x0`  | yes  | no   |
| `CSRRS/C` | -     | `!x0` | yes  | yes  |

### 其他 CSR 相关指令

#### EBREAK

1. 切换至 M 态；
2. 在 EXE 段将 `mcause` 改写为 3；
3. 在 EXE 段将 `mepc` 改写为该指令的地址；及
4. 在 EXE 段跳转至 `{mtvec[31:2], 2'b00}`。

#### ECALL

1. 切换至 M 态；
2. 在 EXE 段将 `mcause` 改写为 8, 9 或 11（取决于当前运行在何状态）；
3. 在 EXE 段将 `mepc` 改写为该指令的地址；及
4. 在 EXE 段跳转至 `{mtvec[31:2], 2'b00}`。

#### MRET

1. 切换至 U 态；及
2. 在 EXE 段跳转至 `mepc`。

## 特权等级的切换

初始状态为 M 模式，由 `mret` 指令（位于 `shell.S:252`）转换为 U 模式，然后通过 `ecall` 可以切换到高一级的模式。