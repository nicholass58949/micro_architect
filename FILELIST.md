# NPU微架构文件列表

## RTL源文件

### 核心计算模块
- `processing_element.v` - 处理单元（PE），执行MAC运算
- `matrix_multiply_unit.v` - 矩阵乘法单元，8×8 PE阵列
- `activation_unit.v` - 激活函数单元（ReLU/Sigmoid/Tanh）

### 存储模块
- `input_buffer.v` - 输入数据缓存（256×16bit）
- `weight_buffer.v` - 权重数据缓存（1024×16bit）
- `output_buffer.v` - 输出数据缓存（256×16bit）

### 控制和接口模块
- `control_unit.v` - 控制单元，状态机
- `axi_interface.v` - AXI4-Lite从设备接口
- `npu_top.v` - NPU顶层模块

## 测试文件
- `testbench/npu_tb.v` - NPU测试平台

## 文档
- `README.md` - 项目说明文档
- `FILELIST.md` - 本文件

## 目录结构
```
micro_architect/
├── rtl/                        # RTL源代码
│   ├── processing_element.v
│   ├── matrix_multiply_unit.v
│   ├── activation_unit.v
│   ├── input_buffer.v
│   ├── weight_buffer.v
│   ├── output_buffer.v
│   ├── control_unit.v
│   ├── axi_interface.v
│   └── npu_top.v
├── testbench/                  # 测试平台
│   └── npu_tb.v
├── sim/                        # 仿真脚本（待添加）
├── doc/                        # 文档（待添加）
├── README.md
└── FILELIST.md
```

## 模块依赖关系

```
npu_top
├── axi_interface
├── control_unit
├── input_buffer
├── weight_buffer
├── output_buffer
├── matrix_multiply_unit
│   └── processing_element (×64个实例)
└── activation_unit
```

## 编译顺序

如果使用不支持自动依赖解析的工具，建议按以下顺序编译：

1. `processing_element.v`
2. `matrix_multiply_unit.v`
3. `activation_unit.v`
4. `input_buffer.v`
5. `weight_buffer.v`
6. `output_buffer.v`
7. `control_unit.v`
8. `axi_interface.v`
9. `npu_top.v`
10. `testbench/npu_tb.v`

## 仿真命令

### Icarus Verilog
```bash
iverilog -o npu_sim \
    rtl/processing_element.v \
    rtl/matrix_multiply_unit.v \
    rtl/activation_unit.v \
    rtl/input_buffer.v \
    rtl/weight_buffer.v \
    rtl/output_buffer.v \
    rtl/control_unit.v \
    rtl/axi_interface.v \
    rtl/npu_top.v \
    testbench/npu_tb.v

vvp npu_sim
gtkwave npu_tb.vcd
```

### ModelSim
```bash
vlib work
vlog rtl/*.v testbench/*.v
vsim -c npu_tb -do "run -all"
```

### Vivado
```tcl
read_verilog rtl/*.v
read_verilog -sv testbench/*.v
synth_design -top npu_top -part xc7z020clg400-1
```

## 代码统计

| 模块 | 行数（估计） | 复杂度 |
|------|-------------|--------|
| processing_element.v | ~150 | 低 |
| matrix_multiply_unit.v | ~300 | 高 |
| activation_unit.v | ~250 | 中 |
| input_buffer.v | ~100 | 低 |
| weight_buffer.v | ~100 | 低 |
| output_buffer.v | ~100 | 低 |
| control_unit.v | ~250 | 中 |
| axi_interface.v | ~400 | 高 |
| npu_top.v | ~350 | 高 |
| npu_tb.v | ~300 | 中 |
| **总计** | **~2300** | - |

## 资源估计（FPGA）

基于Xilinx 7系列FPGA的资源估计：

| 资源类型 | 数量（估计） | 说明 |
|---------|-------------|------|
| LUT | ~5000 | 组合逻辑 |
| FF | ~3000 | 寄存器 |
| DSP48 | 64 | MAC运算（8×8 PE阵列） |
| BRAM | 4-6 | 缓存存储 |
| 频率 | 100-150MHz | 取决于优化 |

## 下一步工作

- [ ] 添加仿真脚本
- [ ] 完善数据路径连接
- [ ] 添加更多测试用例
- [ ] 性能优化
- [ ] 添加约束文件
- [ ] FPGA综合和实现
- [ ] 软件驱动开发
