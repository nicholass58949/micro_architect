# NPU Microarchitecture - File List

## RTL Source Files

### Core Computation Modules
- `rtl/core/processing_element.v` - Processing Element (PE), MAC operation
- `rtl/core/matrix_multiply_unit.v` - Matrix multiplication unit with 8×8 PE array
- `rtl/core/activation_unit.v` - Activation functions (ReLU/Sigmoid/Tanh)

### Memory Modules
- `rtl/memory/input_buffer.v` - Input data buffer (256×16bit)
- `rtl/memory/weight_buffer.v` - Weight data buffer (1024×16bit)
- `rtl/memory/output_buffer.v` - Output data buffer (256×16bit)

### Control Modules
- `rtl/control/control_unit.v` - Control state machine
- `rtl/control/datapath_controller.v` - Datapath controller for address generation

### Interface Modules
- `rtl/interface/axi_interface.v` - AXI4-Lite slave interface

### Utility Modules
- `rtl/utils/performance_counter.v` - Performance counter for metrics

### Top Module
- `rtl/npu_top.v` - NPU top-level module

## Testbench Files
- `testbench/npu_tb.v` - Main testbench

## Simulation Scripts
- `sim/run_simulation.sh` - Unified simulation script

## Documentation
- `README.md` - Project overview (English & Chinese)
- `docs/ARCHITECTURE.md` - Architecture design document
- `docs/QUICK_REFERENCE.md` - Quick reference guide
- `docs/LEARNING_GUIDE.md` - Learning roadmap
- `docs/SIMULATION_REPORT.md` - Simulation test report

## Configuration Files
- `.gitignore` - Git ignore rules
- `LICENSE` - MIT License

## Total Statistics
- **RTL Modules**: 11 files
- **Testbenches**: 1 file
- **Documentation**: 5 files
- **Total Lines of Code**: ~2800 lines
