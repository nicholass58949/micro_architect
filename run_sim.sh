# NPU仿真脚本 - Icarus Verilog
# 使用方法：bash run_sim.sh

#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "NPU Microarchitecture Simulation"
echo "========================================="

# 检查Icarus Verilog是否安装
if ! command -v iverilog &> /dev/null
then
    echo -e "${RED}Error: Icarus Verilog not found!${NC}"
    echo "Please install Icarus Verilog:"
    echo "  Ubuntu/Debian: sudo apt-get install iverilog"
    echo "  macOS: brew install icarus-verilog"
    echo "  Windows: Download from http://bleyer.org/icarus/"
    exit 1
fi

# 创建输出目录
mkdir -p sim_output

# 编译
echo -e "${YELLOW}[1/3] Compiling Verilog files...${NC}"

iverilog -o sim_output/npu_sim \
    -I rtl \
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

if [ $? -ne 0 ]; then
    echo -e "${RED}Compilation failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Compilation successful!${NC}"

# 运行仿真
echo -e "${YELLOW}[2/3] Running simulation...${NC}"

cd sim_output
vvp npu_sim > simulation.log

if [ $? -ne 0 ]; then
    echo -e "${RED}Simulation failed!${NC}"
    cd ..
    exit 1
fi

cd ..

echo -e "${GREEN}Simulation completed!${NC}"

# 显示结果
echo -e "${YELLOW}[3/3] Simulation results:${NC}"
cat sim_output/simulation.log

# 检查波形文件
if [ -f sim_output/npu_tb.vcd ]; then
    echo ""
    echo -e "${GREEN}Waveform file generated: sim_output/npu_tb.vcd${NC}"
    echo "View with: gtkwave sim_output/npu_tb.vcd"
fi

echo ""
echo "========================================="
echo "Simulation finished!"
echo "========================================="
