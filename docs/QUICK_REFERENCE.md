# NPU快速参考卡片

## 一、核心参数

| 参数 | 值 | 说明 |
|------|-----|------|
| PE阵列 | 8×8 | 64个处理单元 |
| 数据位宽 | 16bit | Q8.8定点数 |
| 时钟频率 | 100MHz | 设计目标 |
| 峰值性能 | 6.4 GMAC/s | 理论值 |
| 输入缓存 | 256×16bit | 512字节 |
| 权重缓存 | 1024×16bit | 2KB |
| 输出缓存 | 256×16bit | 512字节 |

## 二、寄存器地址

| 地址 | 名称 | 类型 | 功能 |
|------|------|------|------|
| 0x000 | CTRL_REG | RW | 控制寄存器 |
| 0x004 | STATUS_REG | RO | 状态寄存器 |
| 0x008 | CONFIG_REG | RW | 配置寄存器 |
| 0x00C | INT_STATUS | RW1C | 中断状态 |
| 0x100-0x1FF | WEIGHT_MEM | WO | 权重区 |
| 0x200-0x2FF | INPUT_MEM | WO | 输入区 |
| 0x300-0x3FF | OUTPUT_MEM | RO | 输出区 |

## 三、控制位定义

### CTRL_REG (0x000)
```
[0]: RESET  - 软复位
[1]: START  - 启动计算
```

### STATUS_REG (0x004)
```
[0]: BUSY   - 忙标志
[1]: DONE   - 完成标志
[2]: ERROR  - 错误标志
[5:3]: STATE - 当前状态
```

### CONFIG_REG (0x008)
```
[7:0]: MATRIX_SIZE - 矩阵大小(1-8)
[9:8]: ACT_TYPE    - 激活函数
       00: None
       01: ReLU
       10: Sigmoid
       11: Tanh
```

## 四、使用流程

```c
// 1. 复位
write_reg(0x000, 0x01);
write_reg(0x000, 0x00);

// 2. 配置（8×8矩阵，ReLU）
write_reg(0x008, 0x0108);

// 3. 加载权重
for (i=0; i<64; i++)
    write_reg(0x100+i*4, weight[i]);

// 4. 加载输入
for (i=0; i<8; i++)
    write_reg(0x200+i*4, input[i]);

// 5. 启动
write_reg(0x000, 0x02);

// 6. 等待完成
while (read_reg(0x004) & 0x01);

// 7. 读取结果
for (i=0; i<8; i++)
    output[i] = read_reg(0x300+i*4);
```

## 五、Q8.8格式转换

### 整数 → Q8.8
```c
q88_value = int_value << 8;
// 例：1 → 0x0100
```

### 浮点 → Q8.8
```c
q88_value = (int)(float_value * 256);
// 例：1.5 → 0x0180
```

### Q8.8 → 浮点
```c
float_value = (float)q88_value / 256.0;
// 例：0x0100 → 1.0
```

## 六、常用Q8.8值

| 十进制 | Q8.8 | 说明 |
|--------|------|------|
| 0.0 | 0x0000 | 零 |
| 0.5 | 0x0080 | 一半 |
| 1.0 | 0x0100 | 单位 |
| 2.0 | 0x0200 | 二 |
| -1.0 | 0xFF00 | 负一 |
| 127.996 | 0x7FFF | 最大正数 |
| -128.0 | 0x8000 | 最小负数 |

## 七、仿真命令

### Icarus Verilog
```bash
bash run_sim.sh
gtkwave sim_output/npu_tb.vcd
```

### ModelSim
```bash
vsim -do run_modelsim.do
```

### 手动编译
```bash
iverilog -o sim rtl/*.v testbench/*.v
vvp sim
```

## 八、调试检查点

### 1. 配置阶段
- [ ] 复位信号正确
- [ ] 配置寄存器写入成功
- [ ] 矩阵大小合法（1-8）

### 2. 数据加载
- [ ] 权重数据完整
- [ ] 输入数据正确
- [ ] 地址对齐（4字节）

### 3. 计算阶段
- [ ] START位已设置
- [ ] BUSY位置高
- [ ] 无超时错误

### 4. 结果读取
- [ ] DONE位置高
- [ ] 输出数据有效
- [ ] 中断已触发

## 九、常见错误

| 错误 | 原因 | 解决方法 |
|------|------|----------|
| 超时 | 计算未完成 | 检查时钟和复位 |
| 结果错误 | 数据格式错误 | 验证Q8.8转换 |
| 无响应 | AXI握手失败 | 检查valid/ready |
| 中断未触发 | 配置错误 | 检查中断使能 |

## 十、性能优化提示

1. **数据预加载**：在计算前加载所有数据
2. **流水线**：重叠数据传输和计算
3. **批处理**：一次处理多个向量
4. **缓存重用**：权重可重复使用
5. **激活函数**：ReLU最快，Sigmoid最慢

## 十一、模块接口速查

### processing_element.v
```verilog
input  clk, rst_n, enable, clear_acc
input  [15:0] data_in, weight_in
output [15:0] data_out
output [31:0] acc_out
```

### matrix_multiply_unit.v
```verilog
input  start, clear
input  [15:0] input_data[0:7]
input  [15:0] weight_data[0:7][0:7]
output done, busy
output [31:0] output_data[0:7]
```

### activation_unit.v
```verilog
input  [1:0] activation_type
input  [31:0] data_in[0:7]
output [15:0] data_out[0:7]
```

## 十二、文件快速定位

| 需求 | 文件 |
|------|------|
| 了解项目 | README.md |
| 学习教程 | LEARNING_GUIDE.md |
| 架构设计 | ARCHITECTURE.md |
| 文件列表 | FILELIST.md |
| 项目总结 | PROJECT_SUMMARY.md |
| MAC运算 | processing_element.v |
| 矩阵乘法 | matrix_multiply_unit.v |
| 激活函数 | activation_unit.v |
| 状态机 | control_unit.v |
| AXI接口 | axi_interface.v |
| 顶层模块 | npu_top.v |
| 测试代码 | testbench/npu_tb.v |

---

**打印提示**：建议打印本卡片作为快速参考
