#!/usr/bin/env tclsh
# =============================================================================
# NPU Microarchitecture - Verilog Simulation Script (TCL version)
# =============================================================================

# Get the project root directory
set script_dir [file dirname [info script]]
set project_root [file normalize "$script_dir/.."]
set rtl_dir "$project_root/rtl"
set tb_dir "$project_root/testbench"
set sim_output_dir "$project_root/sim_output"

# Create output directory if it doesn't exist
if {![file exists $sim_output_dir]} {
    file mkdir $sim_output_dir
    puts "Created output directory: $sim_output_dir"
}

# Get absolute paths for all Verilog files
set verilog_files [list \
    "$rtl_dir/core/matrix_multiply_unit.v" \
    "$rtl_dir/core/activation_unit.v" \
    "$rtl_dir/memory/input_buffer.v" \
    "$rtl_dir/memory/weight_buffer.v" \
    "$rtl_dir/memory/output_buffer.v" \
    "$rtl_dir/control/control_unit.v" \
    "$rtl_dir/control/datapath_controller.v" \
    "$rtl_dir/interface/axi_interface.v" \
    "$rtl_dir/npu_top.v" \
    "$tb_dir/npu_tb.v"
]

# Check that all files exist
puts "Checking Verilog files..."
foreach file $verilog_files {
    if {![file exists $file]} {
        puts "ERROR: File not found: $file"
        exit 1
    }
    puts "  ✓ [file tail $file]"
}

# Prepare compilation command for iverilog
puts "\n========================================="
puts "NPU Microarchitecture Simulation"
puts "========================================="
puts "Compiling Verilog files..."

# Build the iverilog command
set compile_cmd [list iverilog -o "$sim_output_dir/npu_sim.vvp" -I "$rtl_dir"]
foreach file $verilog_files {
    lappend compile_cmd $file
}

# Execute compilation
puts "Running: iverilog -o npu_sim.vvp -I rtl \[verilog files...\]"
set compile_result [catch {exec {*}$compile_cmd} compile_output]

if {$compile_result != 0} {
    puts "ERROR: Compilation failed!"
    puts $compile_output
    exit 1
}

puts "✓ Compilation successful"

# Run simulation
puts "\nRunning simulation..."
set sim_result [catch {exec vvp "$sim_output_dir/npu_sim.vvp"} sim_output]

# Save simulation log
set log_file "$sim_output_dir/simulation.log"
set log_fd [open $log_file w]
puts $log_fd $sim_output
close $log_fd

puts $sim_output

if {$sim_result != 0} {
    puts "ERROR: Simulation execution failed!"
    puts "Check log file: $log_file"
    exit 1
}

puts "\n========================================="
puts "Simulation Summary"
puts "========================================="
puts "Log file: $log_file"

# Check for waveform file
if {[file exists "$sim_output_dir/npu_tb.vcd"]} {
    puts "Waveform file: $sim_output_dir/npu_tb.vcd"
    puts "View with: gtkwave $sim_output_dir/npu_tb.vcd"
}

puts "✓ Simulation completed successfully!"
puts ""

exit 0
