# NPU仿真脚本 - ModelSim
# 使用方法：vsim -do run_modelsim.do

# 创建工作库
vlib work

# 编译所有Verilog文件
echo "Compiling Verilog files..."

vlog rtl/processing_element.v
vlog rtl/matrix_multiply_unit.v
vlog rtl/activation_unit.v
vlog rtl/input_buffer.v
vlog rtl/weight_buffer.v
vlog rtl/output_buffer.v
vlog rtl/control_unit.v
vlog rtl/axi_interface.v
vlog rtl/npu_top.v
vlog testbench/npu_tb.v

# 启动仿真
echo "Starting simulation..."
vsim -c npu_tb -do "run -all; quit"

# 如果要打开GUI，使用：
# vsim npu_tb
# add wave -r /*
# run -all
