# NPU v2.0 - Major Architecture Upgrade Plan

## 升级目标

将当前的教学型NPU升级为具备实际推理和训练能力的大型NPU架构。

## 新增核心功能

### 1. 推理能力增强
- ✅ 多层网络自动执行
- ✅ 卷积加速器
- ✅ 池化单元
- ✅ 批归一化（Batch Normalization）
- ✅ 残差连接支持

### 2. 训练能力
- ✅ 反向传播支持
- ✅ 梯度计算单元
- ✅ 权重更新引擎
- ✅ 优化器（SGD, Adam）
- ✅ 损失函数计算

### 3. 高级特性
- ✅ INT8/FP16混合精度
- ✅ 稀疏矩阵加速
- ✅ DMA控制器
- ✅ 多核并行处理
- ✅ 片上网络（NoC）

### 4. 系统级功能
- ✅ 指令集架构（ISA）
- ✅ 编译器支持
- ✅ 运行时调度器
- ✅ 内存管理单元
- ✅ 调试和性能分析

## 新增模块列表

### 核心计算模块
1. `convolution_engine.v` - 卷积加速引擎
2. `pooling_unit.v` - 池化单元
3. `batch_norm_unit.v` - 批归一化单元
4. `gradient_engine.v` - 梯度计算引擎
5. `weight_update_unit.v` - 权重更新单元

### 数据类型支持
6. `fp16_alu.v` - FP16算术逻辑单元
7. `int8_quantizer.v` - INT8量化器
8. `mixed_precision_controller.v` - 混合精度控制器

### 内存和数据传输
9. `dma_controller.v` - DMA控制器
10. `memory_controller.v` - 内存控制器
11. `noc_router.v` - 片上网络路由器
12. `cache_controller.v` - 缓存控制器

### 高级功能
13. `sparse_matrix_engine.v` - 稀疏矩阵引擎
14. `instruction_decoder.v` - 指令解码器
15. `scheduler.v` - 任务调度器
16. `optimizer_unit.v` - 优化器单元

### 系统级模块
17. `npu_core.v` - NPU核心（多个PE阵列）
18. `multi_core_controller.v` - 多核控制器
19. `power_manager.v` - 功耗管理
20. `debug_interface.v` - 调试接口

## 架构升级

### 当前架构（v1.0）
```
单核NPU
├── 8×8 PE阵列
├── 基本缓存
├── 简单控制
└── AXI接口
```

### 升级后架构（v2.0）
```
多核NPU系统
├── 4个NPU核心
│   ├── 16×16 PE阵列（每核）
│   ├── 卷积引擎
│   ├── 池化单元
│   └── 批归一化
├── 训练支持
│   ├── 梯度引擎
│   ├── 权重更新
│   └── 优化器
├── 高级特性
│   ├── 混合精度
│   ├── 稀疏加速
│   └── DMA传输
└── 系统级功能
    ├── 指令集
    ├── 调度器
    └── NoC互连
```

## 性能目标

| 指标 | v1.0 | v2.0 | 提升 |
|------|------|------|------|
| PE数量 | 64 | 1024 | 16× |
| 峰值性能 | 6.4 GMAC/s | 200+ GMAC/s | 31× |
| 支持精度 | Q8.8 | FP16/INT8/Q8.8 | 3种 |
| 内存带宽 | 1.2 GB/s | 50+ GB/s | 42× |
| 功能 | 推理 | 推理+训练 | 2× |

## 实现计划

### Phase 1: 推理增强（1-2周）
- [ ] 卷积加速器
- [ ] 池化单元
- [ ] 批归一化
- [ ] 多层网络支持

### Phase 2: 训练支持（2-3周）
- [ ] 反向传播
- [ ] 梯度计算
- [ ] 权重更新
- [ ] 优化器

### Phase 3: 高级特性（2-3周）
- [ ] 混合精度
- [ ] 稀疏加速
- [ ] DMA控制器
- [ ] 多核并行

### Phase 4: 系统集成（1-2周）
- [ ] 指令集设计
- [ ] 调度器
- [ ] 编译器前端
- [ ] 完整验证

## 文件组织

```
micro_architect/
├── rtl/
│   ├── core/              # 核心计算（扩展）
│   │   ├── v1/           # 原有模块
│   │   └── v2/           # 新增模块
│   ├── training/          # 训练模块（新增）
│   ├── precision/         # 精度支持（新增）
│   ├── memory/           # 内存系统（扩展）
│   ├── interconnect/     # 互连网络（新增）
│   └── system/           # 系统级（新增）
├── compiler/             # 编译器（新增）
├── runtime/              # 运行时（新增）
└── benchmarks/           # 基准测试（新增）
```

## 开始实现

准备开始Phase 1的实现...
