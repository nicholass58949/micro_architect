# NPU增强仿真脚本
# 使用方法：bash run_enhanced_sim.sh

#!/bin/bash

echo "========================================="
echo "NPU Enhanced Simulation"
echo "========================================="

# 创建输出目录
mkdir -p sim_output

# 编译
echo "[1/3] Compiling Verilog files..."

iverilog -o sim_output/npu_enhanced_sim \
    -I rtl \
    rtl/processing_element.v \
    rtl/matrix_multiply_unit.v \
    rtl/activation_unit.v \
    rtl/input_buffer.v \
    rtl/weight_buffer.v \
    rtl/output_buffer.v \
    rtl/control_unit.v \
    rtl/axi_interface.v \
    rtl/datapath_controller.v \
    rtl/performance_counter.v \
    rtl/npu_top.v \
    testbench/npu_enhanced_tb.v

if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

echo "Compilation successful!"

# 运行仿真
echo "[2/3] Running simulation..."

cd sim_output
vvp npu_enhanced_sim | tee simulation.log

if [ $? -ne 0 ]; then
    echo "Simulation failed!"
    cd ..
    exit 1
fi

cd ..

echo "Simulation completed!"

# 显示结果
echo "[3/3] Simulation results:"
echo "========================================"
cat sim_output/simulation.log
echo "========================================"

# 检查波形文件
if [ -f sim_output/npu_enhanced_tb.vcd ]; then
    echo ""
    echo "Waveform file generated: sim_output/npu_enhanced_tb.vcd"
    echo "View with: gtkwave sim_output/npu_enhanced_tb.vcd"
fi

echo ""
echo "Simulation finished!"
