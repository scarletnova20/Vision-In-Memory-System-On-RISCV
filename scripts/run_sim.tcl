# =============================================================
# run_sim.tcl — Vivado Batch Simulation Script
# Runs the RISC-V pipeline simulation headlessly (no GUI).
#
# Usage from terminal:
#   vivado -mode batch -source run_sim.tcl
#
# Adjust PROJECT_DIR and PROJECT_NAME to match your Vivado project.
# =============================================================

# -------------------------------------------------------
# USER CONFIGURATION — edit these paths
# -------------------------------------------------------
set PROJECT_DIR  "C:/Users/hridd/VISOR"           ;# Folder containing your .xpr
set PROJECT_NAME "VISOR"                           ;# Your Vivado project name (without .xpr)
set SIM_TOP      "tb_RISCV_Pipeline"               ;# Top-level testbench module name
set SIM_RUNTIME  "4ms"                             ;# Simulation runtime - enough for full Sobel

# -------------------------------------------------------
# Open the project
# -------------------------------------------------------
set XPR_FILE [file join $PROJECT_DIR "${PROJECT_NAME}.xpr"]

if {![file exists $XPR_FILE]} {
    puts "\[ERROR\] Project file not found: $XPR_FILE"
    puts "        Set PROJECT_DIR and PROJECT_NAME at the top of this script."
    exit 1
}

puts "\[INFO\]  Opening project: $XPR_FILE"
open_project $XPR_FILE

# -------------------------------------------------------
# Set simulation properties
# -------------------------------------------------------
set_property top            $SIM_TOP  [get_filesets sim_1]
set_property top_lib        xil_defaultlib [get_filesets sim_1]

# Ensure memory files are found in the sim run directory
# Copy .mem files to the simulation working directory
set sim_run_dir [file join $PROJECT_DIR "${PROJECT_NAME}.sim" "sim_1" "behav" "xsim"]

# Copy image.mem from output/ and program.mem from mem/ to sim working dir
foreach {mem_file src_subdir} {image.mem output program.mem mem} {
    set src [file join $PROJECT_DIR $src_subdir $mem_file]
    if {[file exists $src]} {
        file copy -force $src $sim_run_dir
        puts "\[INFO\]  Copied $src_subdir/$mem_file → $sim_run_dir"
    } else {
        puts "\[WARN\]  $src_subdir/$mem_file not found — simulation may fail on \$readmemh"
    }
}

# -------------------------------------------------------
# Launch, run, and close the simulation
# -------------------------------------------------------
puts "\[INFO\]  Launching simulation (runtime: $SIM_RUNTIME) ..."
launch_simulation -mode behavioral

run $SIM_RUNTIME

puts "\[INFO\]  Simulation complete."

# -------------------------------------------------------
# Copy output memory file back to project root for Python
# -------------------------------------------------------
set output_mem [file join $sim_run_dir "output_image.mem"]
set output_dir [file join $PROJECT_DIR "output"]
file mkdir $output_dir
if {[file exists $output_mem]} {
    file copy -force $output_mem $output_dir
    puts "\[OK\]    output_image.mem copied to: $output_dir"
} else {
    puts "\[WARN\]  output_image.mem not found — check that \$writememh executed."
}

close_sim
close_project

puts "\[DONE\]  Batch simulation finished."
