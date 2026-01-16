#!/bin/bash
# =============================================================================
# NPU Microarchitecture - Unified Simulation Script
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM_OUTPUT_DIR="${PROJECT_ROOT}/sim_output"
RTL_DIR="${PROJECT_ROOT}/rtl"
TB_DIR="${PROJECT_ROOT}/testbench"

# Default simulator
SIMULATOR="iverilog"  # Options: iverilog, modelsim, verilator

# =============================================================================
# Functions
# =============================================================================

print_header() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_simulator() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 not found!"
        return 1
    fi
    print_success "$1 found"
    return 0
}

# =============================================================================
# Main Simulation Flow
# =============================================================================

main() {
    print_header "NPU Microarchitecture Simulation"
    
    # Step 1: Create output directory
    print_info "Creating output directory..."
    mkdir -p "${SIM_OUTPUT_DIR}"
    print_success "Output directory ready: ${SIM_OUTPUT_DIR}"
    
    # Step 2: Check simulator
    print_info "Checking simulator..."
    if ! check_simulator "${SIMULATOR}"; then
        print_error "Please install Icarus Verilog"
        print_info "Ubuntu/Debian: sudo apt-get install iverilog"
        print_info "macOS: brew install icarus-verilog"
        print_info "Windows: Download from http://bleyer.org/icarus/"
        exit 1
    fi
    
    # Step 3: Compile
    print_info "Compiling Verilog files..."
    
    iverilog -o "${SIM_OUTPUT_DIR}/npu_sim.vvp" \
        -I "${RTL_DIR}" \
        "${RTL_DIR}/core/processing_element.v" \
        "${RTL_DIR}/core/matrix_multiply_unit.v" \
        "${RTL_DIR}/core/activation_unit.v" \
        "${RTL_DIR}/memory/input_buffer.v" \
        "${RTL_DIR}/memory/weight_buffer.v" \
        "${RTL_DIR}/memory/output_buffer.v" \
        "${RTL_DIR}/control/control_unit.v" \
        "${RTL_DIR}/control/datapath_controller.v" \
        "${RTL_DIR}/interface/axi_interface.v" \
        "${RTL_DIR}/utils/performance_counter.v" \
        "${RTL_DIR}/npu_top.v" \
        "${TB_DIR}/npu_tb.v"
    
    if [ $? -ne 0 ]; then
        print_error "Compilation failed!"
        exit 1
    fi
    print_success "Compilation successful"
    
    # Step 4: Run simulation
    print_info "Running simulation..."
    
    cd "${SIM_OUTPUT_DIR}"
    vvp npu_sim.vvp | tee simulation.log
    
    if [ $? -ne 0 ]; then
        print_error "Simulation failed!"
        cd "${PROJECT_ROOT}"
        exit 1
    fi
    cd "${PROJECT_ROOT}"
    print_success "Simulation completed"
    
    # Step 5: Check results
    print_info "Checking results..."
    
    if grep -q "ALL TESTS PASSED" "${SIM_OUTPUT_DIR}/simulation.log"; then
        print_success "All tests passed!"
    else
        print_error "Some tests failed. Check ${SIM_OUTPUT_DIR}/simulation.log"
    fi
    
    # Step 6: Report waveform file
    if [ -f "${SIM_OUTPUT_DIR}/npu_tb.vcd" ]; then
        print_success "Waveform file generated: ${SIM_OUTPUT_DIR}/npu_tb.vcd"
        print_info "View with: gtkwave ${SIM_OUTPUT_DIR}/npu_tb.vcd"
    fi
    
    # Summary
    print_header "Simulation Summary"
    echo -e "${BLUE}Log file:${NC} ${SIM_OUTPUT_DIR}/simulation.log"
    echo -e "${BLUE}Waveform:${NC} ${SIM_OUTPUT_DIR}/npu_tb.vcd"
    echo ""
    print_success "Simulation finished successfully!"
}

# =============================================================================
# Run main function
# =============================================================================

main "$@"
