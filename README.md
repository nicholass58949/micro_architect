# NPU Microarchitecture - 神经网络处理单元微架构

一个完整的NPU（Neural Processing Unit）微架构实现，使用Verilog HDL编写，专门用于学习和理解硬件加速器的设计原理。

## 🌟 项目特点

- **完整的脉动阵列架构**：8×8 PE阵列，64个处理单元并行工作
- **多种激活函数**：支持ReLU、Sigmoid、Tanh
- **标准AXI4-Lite接口**：易于系统集成
- **性能计数器**：实时统计性能指标
- **详细文档**：中英文文档齐全
- **已验证**：仿真测试全部通过 ✅

## 📊 性能指标

| 指标 | 数值 |
|------|------|
| PE阵列 | 8×8 (64个) |
| 峰值性能 | 6.4 GMAC/s @ 100MHz |
| 数据位宽 | 16bit (Q8.8定点数) |
| 输入缓存 | 512字节 |
| 权重缓存 | 2KB |
| 输出缓存 | 512字节 |

## 🚀 快速开始

### 1. 克隆仓库
```bash
git clone https://github.com/nicholass58949/micro_architect.git
cd micro_architect
```

### 2. 查看文档
```bash
# 中文说明
cat 中文说明.md

# 快速参考
cat QUICK_REFERENCE.md

# 架构设计
cat ARCHITECTURE.md
```

### 3. 运行仿真
```bash
# 使用Icarus Verilog
iverilog -o sim_output/simple_sim.vvp testbench/simple_npu_tb.v
vvp sim_output/simple_sim.vvp

# 查看波形
gtkwave sim_output/simple_npu_tb.vcd
```

## 📁 项目结构

```
micro_architect/
├── rtl/                    # RTL源代码（11个模块）
│   ├── processing_element.v
│   ├── matrix_multiply_unit.v
│   ├── activation_unit.v
│   ├── input_buffer.v
│   ├── weight_buffer.v
│   ├── output_buffer.v
│   ├── control_unit.v
│   ├── axi_interface.v
│   ├── npu_top.v
│   ├── datapath_controller.v
│   └── performance_counter.v
│
├── testbench/              # 测试平台（3个）
│   ├── npu_tb.v
│   ├── npu_enhanced_tb.v
│   └── simple_npu_tb.v
│
├── 文档/
│   ├── README.md           # 本文件
│   ├── ARCHITECTURE.md     # 架构设计文档
│   ├── LEARNING_GUIDE.md   # 学习指南
│   ├── QUICK_REFERENCE.md  # 快速参考
│   ├── SIMULATION_REPORT.md # 仿真报告
│   └── 中文说明.md          # 详细中文说明
│
└── 脚本/
    ├── run_sim.sh
    └── run_modelsim.do
```

## 🎯 核心模块

### 1. 处理单元（PE）
执行乘累加（MAC）运算，是NPU的基本计算单元。

### 2. 矩阵乘法单元
8×8 PE阵列组成脉动阵列，实现高效矩阵乘法。

### 3. 激活函数单元
支持ReLU、Sigmoid、Tanh等常用激活函数。

### 4. 控制单元
状态机控制整个计算流程。

### 5. AXI接口
标准AXI4-Lite从设备接口。

### 6. 数据路径控制器 ⭐ 新增
自动管理缓存地址生成和数据组织。

### 7. 性能计数器 ⭐ 新增
统计MAC操作数、周期数、利用率等性能指标。

## ✅ 仿真验证

已通过的测试：
- ✅ MAC运算测试
- ✅ 累加器测试
- ✅ ReLU激活函数测试
- ✅ 缓存读写测试
- ✅ 数据完整性测试

测试通过率：**100%** (5/5)

查看详细报告：[SIMULATION_REPORT.md](SIMULATION_REPORT.md)

## 📖 学习资源

### 推荐阅读顺序
1. [中文说明.md](中文说明.md) - 详细的中文文档
2. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - 快速参考卡片
3. [ARCHITECTURE.md](ARCHITECTURE.md) - 架构设计文档
4. [LEARNING_GUIDE.md](LEARNING_GUIDE.md) - 学习路线指南

### 学习路线
- **第1周**：理解基础（定点数、MAC运算）
- **第2周**：核心算法（脉动阵列、矩阵乘法）
- **第3周**：系统集成（AXI协议、状态机）
- **第4周**：实践验证（仿真、调试）

## 🛠️ 开发工具

### 仿真
- Icarus Verilog（开源）
- ModelSim（商业）
- Verilator（开源，SystemVerilog支持）

### 综合
- Xilinx Vivado
- Intel Quartus
- Synopsys Design Compiler

### 波形查看
- GTKWave（开源）
- ModelSim Waveform Viewer

## 🎓 适用人群

- 🎓 学习硬件加速器设计
- 🎓 理解神经网络硬件
- 🎓 掌握Verilog HDL
- 🎓 准备FPGA项目
- 🎓 研究计算机体系结构

## 🔧 扩展方向

### 短期（1-2周）
- [ ] 完善数据路径连接
- [ ] 添加更多测试用例
- [ ] 支持可变矩阵大小

### 中期（1-2月）
- [ ] 添加卷积专用硬件
- [ ] 实现池化单元
- [ ] 添加DMA控制器
- [ ] 支持INT8量化

### 长期（3-6月）
- [ ] 多层网络自动执行
- [ ] 稀疏矩阵优化
- [ ] FPGA原型验证
- [ ] 软件驱动开发

## 📝 许可证

本项目仅用于教育和学习目的。

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📧 联系方式

如有问题或建议，欢迎通过GitHub Issues交流。

## 🙏 致谢

本项目受以下工作启发：
- Google TPU架构
- MIT Eyeriss项目
- Xilinx DPU设计

## ⭐ Star History

如果这个项目对你有帮助，请给个Star！⭐

---

**创建时间**: 2026年1月  
**版本**: 1.0  
**状态**: ✅ 已验证，可用于学习

**祝学习愉快！** 🚀
