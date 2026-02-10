# 简化版NPU微架构

这是一个用于学习的**极简NPU实现**，重点关注于理解硬件设计的核心概念。

## 项目特点

✅ **Verilog-95兼容** - 使用标准Verilog编写，完全兼容iverilog编译器  
✅ **最小化设计** - 移除了复杂的性能计数器和不必要的模块  
✅ **可工作的电路** - 包含完整的TCL仿真脚本，一键运行  
✅ **易于学习** - 清晰的代码注释和逻辑流程

## 架构概览

```
┌─────────────────────────────────────┐
│         AXI4-Lite 接口              │
│   (寄存器读写、中断处理)             │
└────────────┬────────────────────────┘
             │
    ┌────────▼─────────┐
    │  输入/权重/输出缓存│
    │   (Dual-Port RAM) │
    └────────┬─────────┘
             │
    ┌────────▼─────────────────────┐
    │  矩阵乘法单元                  │
    │  (8个16bit输入,64个权重)       │
    │  输出: 8个32bit积累结果        │
    └────────┬─────────────────────┘
             │
    ┌────────▼─────────────────┐
    │  激活函数（ReLU/Sig/Tanh)│
    │  Q8.8定点数工作          │
    └───────────────────────────┘
```

## 项目结构

```
rtl/
├── npu_top.v                    # 顶层模块
├── core/
│   ├── matrix_multiply_unit.v   # 8x8矩阵乘法（无数组）
│   └── activation_unit.v        # 激活函数单元
├── memory/
│   ├── input_buffer.v           # 输入缓存
│   ├── weight_buffer.v          # 权重缓存
│   └── output_buffer.v          # 输出缓存
├── control/
│   ├── control_unit.v           # 状态机控制
│   └── datapath_controller.v    # 数据路径（简化）
└── interface/
    └── axi_interface.v          # AXI4-Lite接口

testbench/
└── npu_tb.v                     # 测试平台

sim/
├── run_simulation.tcl           # TCL仿真脚本
└── sim_output/
    ├── simulation.log           # 仿真日志
    └── npu_tb.vcd               # 波形文件
```

## 快速开始

### 运行仿真

```bash
cd sim
tclsh run_simulation.tcl
```

**输出**：
- ✓ 编译状态
- ✓ 仿真完成通知
- ✓ 生成的文件：`npu_tb.vcd`（用于波形查看）

### 手动编译和运行

如果你有iverilog和vvp：

```bash
cd sim
iverilog -o npu_sim.vvp -I ../rtl \
  ../rtl/npu_top.v \
  ../rtl/core/*.v \
  ../rtl/control/*.v \
  ../rtl/memory/*.v \
  ../rtl/interface/*.v \
  ../testbench/npu_tb.v

vvp npu_sim.vvp
```

## 数据格式

**定点数格式**：Q8.8（8位整数 + 8位小数）

- 16位有符号数值范围: $[-128, 127.99609375]$
- 乘法结果: Q16.16（32位），最后右移8位恢复到Q8.8

## 关键模块说明

### matrix_multiply_unit.v
- **端口**：8个16bit输入，64个16bit权重，8个32bit输出
- **操作**：并行计算8个点积，无需遍历
- **使用Verilog-95**：完全避免SystemVerilog数组语法

### activation_unit.v
- **激活函数**：None, ReLU, Sigmoid, Tanh
- **Sigmoid实现**：使用16项LUT（查找表）近似
- **延迟**：单时钟周期

### axi_interface.v
- **寄存器映射**：
  - 0x000：控制寄存器（启动/复位）
  - 0x004：状态寄存器
  - 0x008：配置寄存器
  - 0x00C：中断状态

## 简化的设计决定

| 特性 | 原始设计 | 简化版本 | 原因 |
|------|---------|--------|------|
| 性能计数器 | 支持 | ❌ 移除 | 学习项目不需要 |
| 矩阵大小 | 可配置 | 固定8×8 | 降低复杂度 |
| 数据接口 | 宽度可配置 | 固定16bit | 简化实现 |
| 循环引擎 | 硬件循环 | 组合逻辑 | 易于理解 |
| datapath_controller | 完整状态机 | 简化/直通 | 最小化设计 |

## 后续扩展方向

- [ ] 支持可变矩阵大小（通过广播参数）  
- [ ] 添加更多激活函数  
- [ ] 性能计数器（用于学习cache设计）  
- [ ] 浮点数支持  
- [ ] 多个矩阵乘法单元（并行处理）

## 学习资源

建议学习顺序：
1. 阅读 [npu_top.v](rtl/npu_top.v) - 理解模块集成
2. 阅读 [matrix_multiply_unit.v](rtl/core/matrix_multiply_unit.v) - 核心计算
3. 查看 [npu_tb.v](testbench/npu_tb.v) - 理解测试验证
4. 运行仿真并查看 `npu_tb.vcd` 波形

## 工具需求

- **编译**：iverilog（开源Verilog编译器）
- **仿真**：vvp（iverilog虚拟机）
- **脚本**：TCL（Tool Command Language）

## 许可证

MIT License - 自由使用和修改

  ../rtl/core/activation_unit.v \
  ../rtl/memory/input_buffer.v \
  ../rtl/memory/weight_buffer.v \
  ../rtl/memory/output_buffer.v \
  ../rtl/control/control_unit.v \
  ../rtl/control/datapath_controller.v \
  ../rtl/interface/axi_interface.v \
  ../rtl/npu_top.v \
  ../testbench/npu_tb.v

vvp ../sim_output/npu_sim.vvp
```

查看波形：

```bash
gtkwave ../sim_output/npu_tb.vcd
```

## 寄存器与地址映射

- 0x000 CTRL_REG
  - bit[0] 软复位
  - bit[1] 启动计算
- 0x004 STATUS_REG (只读)
  - bit[0] busy
  - bit[1] done
  - bit[2] error
  - bit[5:3] state
- 0x008 CONFIG_REG
  - bit[7:0] matrix_size
  - bit[9:8] activation_type
- 0x00C INT_STATUS (W1C)
  - bit[0] done中断
  - bit[1] error中断

数据区：
- 0x100-0x1FF 权重数据
- 0x200-0x2FF 输入数据
- 0x300-0x3FF 输出数据

## 说明

- 数据格式为Q8.8定点数
- 输出缓存为单端口写入，因此输出写回按行依次完成

