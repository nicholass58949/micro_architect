# NPU Microarchitecture - 神经网络处理单元微架构

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Verilog](https://img.shields.io/badge/language-Verilog-orange.svg)](https://en.wikipedia.org/wiki/Verilog)
[![Status](https://img.shields.io/badge/status-verified-brightgreen.svg)](SIMULATION_REPORT.md)

一个完整的NPU（Neural Processing Unit）微架构实现，使用Verilog HDL编写，专门用于学习和理解硬件加速器的设计原理。

[English](#english) | [中文](#中文)

---

## 中文

### 🌟 项目特点

- **完整的脉动阵列架构**：8×8 PE阵列，64个处理单元并行工作
- **多种激活函数**：支持ReLU、Sigmoid、Tanh
- **标准AXI4-Lite接口**：易于系统集成
- **性能计数器**：实时统计性能指标
- **数据路径控制器**：自动管理数据流
- **详细文档**：中英文文档齐全
- **已验证**：仿真测试全部通过 ✅

### 📊 性能指标

| 指标 | 数值 | 说明 |
|------|------|------|
| **PE阵列** | 8×8 (64个) | 脉动阵列架构 |
| **峰值性能** | 6.4 GMAC/s | @ 100MHz |
| **数据位宽** | 16bit | Q8.8定点数格式 |
| **输入缓存** | 512字节 | 256×16bit |
| **权重缓存** | 2KB | 1024×16bit |
| **输出缓存** | 512字节 | 256×16bit |
| **测试通过率** | 100% | 5/5测试通过 |

### 🚀 快速开始

#### 1. 克隆仓库
```bash
git clone https://github.com/nicholass58949/micro_architect.git
cd micro_architect
```

#### 2. 运行仿真
```bash
# 创建输出目录
mkdir -p sim_output

# 编译并运行仿真
bash run_simulation.sh

# 查看波形（需要GTKWave）
gtkwave sim_output/npu_tb.vcd
```

#### 3. 查看文档
```bash
# 快速参考
cat docs/QUICK_REFERENCE.md

# 详细架构
cat docs/ARCHITECTURE.md

# 学习指南
cat docs/LEARNING_GUIDE.md
```

### 📁 项目结构

```
micro_architect/
├── rtl/                        # RTL源代码
│   ├── core/                   # 核心计算模块
│   │   ├── processing_element.v
│   │   ├── matrix_multiply_unit.v
│   │   └── activation_unit.v
│   ├── memory/                 # 存储模块
│   │   ├── input_buffer.v
│   │   ├── weight_buffer.v
│   │   └── output_buffer.v
│   ├── control/                # 控制模块
│   │   ├── control_unit.v
│   │   └── datapath_controller.v
│   ├── interface/              # 接口模块
│   │   └── axi_interface.v
│   ├── utils/                  # 工具模块
│   │   └── performance_counter.v
│   └── npu_top.v              # 顶层模块
│
├── testbench/                  # 测试平台
│   ├── npu_tb.v               # 主测试平台
│   └── test_utils.vh          # 测试工具
│
├── sim/                        # 仿真脚本
│   └── run_simulation.sh      # 统一仿真脚本
│
├── docs/                       # 文档
│   ├── ARCHITECTURE.md        # 架构设计
│   ├── QUICK_REFERENCE.md     # 快速参考
│   ├── LEARNING_GUIDE.md      # 学习指南
│   └── SIMULATION_REPORT.md   # 仿真报告
│
├── README.md                   # 本文件
├── LICENSE                     # 许可证
└── .gitignore                 # Git忽略文件
```

### 🎯 核心模块说明

#### 1. 处理单元（Processing Element）
- **文件**: `rtl/core/processing_element.v`
- **功能**: 执行乘累加（MAC）运算
- **特点**: 16位定点数，32位累加器

#### 2. 矩阵乘法单元（Matrix Multiply Unit）
- **文件**: `rtl/core/matrix_multiply_unit.v`
- **功能**: 8×8 PE阵列实现矩阵乘法
- **架构**: 脉动阵列（Systolic Array）

#### 3. 激活函数单元（Activation Unit）
- **文件**: `rtl/core/activation_unit.v`
- **功能**: 支持ReLU、Sigmoid、Tanh
- **优化**: 查找表（LUT）实现

#### 4. 控制单元（Control Unit）
- **文件**: `rtl/control/control_unit.v`
- **功能**: 状态机控制计算流程
- **保护**: 超时检测、错误处理

#### 5. AXI接口（AXI Interface）
- **文件**: `rtl/interface/axi_interface.v`
- **协议**: AXI4-Lite标准
- **功能**: 寄存器访问、数据传输

#### 6. 数据路径控制器（Datapath Controller）
- **文件**: `rtl/control/datapath_controller.v`
- **功能**: 自动地址生成和数据组织
- **优势**: 简化顶层设计

#### 7. 性能计数器（Performance Counter）
- **文件**: `rtl/utils/performance_counter.v`
- **功能**: 统计性能指标
- **指标**: MAC操作数、周期数、利用率

### ✅ 验证状态

已通过的测试：
- ✅ MAC运算测试
- ✅ 累加器测试  
- ✅ ReLU激活函数测试
- ✅ 缓存读写测试
- ✅ 数据完整性测试

**测试通过率**: 100% (5/5)

详细报告：[SIMULATION_REPORT.md](docs/SIMULATION_REPORT.md)

### 📖 学习资源

#### 推荐阅读顺序
1. **本README** - 项目概述
2. [快速参考](docs/QUICK_REFERENCE.md) - 常用命令和参数
3. [架构设计](docs/ARCHITECTURE.md) - 详细设计文档
4. [学习指南](docs/LEARNING_GUIDE.md) - 学习路线

#### 学习路线（4周计划）
- **第1周**: 基础概念（定点数、MAC运算、PE设计）
- **第2周**: 核心算法（脉动阵列、矩阵乘法）
- **第3周**: 系统集成（AXI协议、状态机、控制流）
- **第4周**: 实践验证（仿真、调试、优化）

### 🛠️ 开发工具

#### 仿真工具
- **Icarus Verilog** (开源) - 推荐用于学习
- **ModelSim** (商业) - 专业仿真
- **Verilator** (开源) - 高性能仿真

#### 综合工具
- **Xilinx Vivado** - FPGA综合
- **Intel Quartus** - FPGA综合
- **Synopsys DC** - ASIC综合

#### 波形查看
- **GTKWave** (开源) - 推荐
- **ModelSim Waveform Viewer**

### 🎓 适用人群

- 🎓 学习硬件加速器设计
- 🎓 理解神经网络硬件实现
- 🎓 掌握Verilog HDL编程
- 🎓 准备FPGA项目开发
- 🎓 研究计算机体系结构
- 🎓 准备芯片设计工作

### 🔧 扩展方向

#### 短期改进（1-2周）
- [ ] 支持可变矩阵大小
- [ ] 添加更多测试用例
- [ ] 优化时序性能
- [ ] 添加断言验证

#### 中期扩展（1-2月）
- [ ] 卷积加速器
- [ ] 池化单元
- [ ] DMA控制器
- [ ] INT8量化支持

#### 长期目标（3-6月）
- [ ] 多层网络自动执行
- [ ] 稀疏矩阵优化
- [ ] FPGA原型验证
- [ ] 软件驱动开发
- [ ] 完整SoC集成

### 📝 贡献指南

欢迎贡献！请遵循以下步骤：

1. Fork本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

### 📄 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件

### 🙏 致谢

本项目受以下工作启发：
- **Google TPU** - 脉动阵列架构
- **MIT Eyeriss** - 能效优化设计
- **Xilinx DPU** - FPGA加速器实现

### 📧 联系方式

- **GitHub Issues**: [提交问题](https://github.com/nicholass58949/micro_architect/issues)
- **Discussions**: [讨论区](https://github.com/nicholass58949/micro_architect/discussions)

### ⭐ Star History

如果这个项目对你有帮助，请给个Star！⭐

---

## English

### 🌟 Features

- **Complete Systolic Array Architecture**: 8×8 PE array with 64 processing elements
- **Multiple Activation Functions**: ReLU, Sigmoid, Tanh support
- **Standard AXI4-Lite Interface**: Easy system integration
- **Performance Counter**: Real-time performance metrics
- **Datapath Controller**: Automatic data flow management
- **Comprehensive Documentation**: Both English and Chinese
- **Verified**: All simulation tests passed ✅

### 📊 Performance Metrics

| Metric | Value | Description |
|--------|-------|-------------|
| **PE Array** | 8×8 (64 PEs) | Systolic array |
| **Peak Performance** | 6.4 GMAC/s | @ 100MHz |
| **Data Width** | 16-bit | Q8.8 fixed-point |
| **Input Buffer** | 512 bytes | 256×16bit |
| **Weight Buffer** | 2KB | 1024×16bit |
| **Output Buffer** | 512 bytes | 256×16bit |
| **Test Pass Rate** | 100% | 5/5 tests passed |

### 🚀 Quick Start

#### 1. Clone Repository
```bash
git clone https://github.com/nicholass58949/micro_architect.git
cd micro_architect
```

#### 2. Run Simulation
```bash
# Create output directory
mkdir -p sim_output

# Compile and run simulation
bash run_simulation.sh

# View waveform (requires GTKWave)
gtkwave sim_output/npu_tb.vcd
```

#### 3. Read Documentation
```bash
# Quick reference
cat docs/QUICK_REFERENCE.md

# Architecture details
cat docs/ARCHITECTURE.md

# Learning guide
cat docs/LEARNING_GUIDE.md
```

### 📖 Documentation

- [Architecture Design](docs/ARCHITECTURE.md) - Detailed architecture
- [Quick Reference](docs/QUICK_REFERENCE.md) - Command reference
- [Learning Guide](docs/LEARNING_GUIDE.md) - Learning roadmap
- [Simulation Report](docs/SIMULATION_REPORT.md) - Test results

### 🎓 Target Audience

- Students learning hardware accelerator design
- Engineers understanding neural network hardware
- Developers mastering Verilog HDL
- Researchers in computer architecture
- FPGA/ASIC designers

### 📝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

### 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file

### 🙏 Acknowledgments

Inspired by:
- **Google TPU** - Systolic array architecture
- **MIT Eyeriss** - Energy-efficient design
- **Xilinx DPU** - FPGA accelerator implementation

---

**Created**: January 2026  
**Version**: 1.0  
**Status**: ✅ Verified and ready for learning

**Happy Learning!** 🚀
