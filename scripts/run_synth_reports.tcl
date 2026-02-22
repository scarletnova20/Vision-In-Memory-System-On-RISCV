# =============================================================
# run_synth_reports.tcl — Vivado Synthesis + Implementation + Reports
# Runs synthesis, implementation, and generates power/utilization
# reports for the hackathon demo.
#
# Usage:
#   vivado -mode batch -source scripts/run_synth_reports.tcl -nojournal -nolog
#
# Or open Vivado GUI and run:
#   source scripts/run_synth_reports.tcl
# =============================================================

# -------------------------------------------------------
# USER CONFIGURATION
# -------------------------------------------------------
set PROJECT_DIR  "C:/Users/hridd/VISOR"
set PROJECT_NAME "VISOR"
set REPORT_DIR   "$PROJECT_DIR/reports"

# -------------------------------------------------------
# Open the project
# -------------------------------------------------------
set XPR_FILE [file join $PROJECT_DIR "${PROJECT_NAME}.xpr"]

if {![file exists $XPR_FILE]} {
    puts "\[ERROR\] Project file not found: $XPR_FILE"
    exit 1
}

puts "\[INFO\]  Opening project: $XPR_FILE"
open_project $XPR_FILE

# -------------------------------------------------------
# Create reports directory
# -------------------------------------------------------
file mkdir $REPORT_DIR
puts "\[INFO\]  Reports will be saved to: $REPORT_DIR"

# -------------------------------------------------------
# STEP 1: Run Synthesis
# -------------------------------------------------------
puts "\n============================================================"
puts "  STEP 1: Running Synthesis..."
puts "============================================================"

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property STATUS [get_runs synth_1]] != "synth_design Complete!"} {
    puts "\[ERROR\] Synthesis failed!"
    puts "        Status: [get_property STATUS [get_runs synth_1]]"
    close_project
    exit 1
}
puts "\[OK\]    Synthesis completed successfully."

# -------------------------------------------------------
# STEP 2: Open Synthesized Design & Generate Reports
# -------------------------------------------------------
puts "\n============================================================"
puts "  STEP 2: Generating Synthesis Reports..."
puts "============================================================"

open_run synth_1

# Utilization report (post-synthesis)
report_utilization -file "$REPORT_DIR/utilization_synth.txt"
puts "\[OK\]    Saved: utilization_synth.txt"

# Timing summary (post-synthesis)
report_timing_summary -file "$REPORT_DIR/timing_synth.txt"
puts "\[OK\]    Saved: timing_synth.txt"

# -------------------------------------------------------
# STEP 3: Run Implementation (Place & Route)
# -------------------------------------------------------
puts "\n============================================================"
puts "  STEP 3: Running Implementation (Place & Route)..."
puts "============================================================"

launch_runs impl_1 -jobs 4
wait_on_run impl_1

if {[get_property STATUS [get_runs impl_1]] != "route_design Complete!"} {
    puts "\[ERROR\] Implementation failed!"
    puts "        Status: [get_property STATUS [get_runs impl_1]]"
    close_project
    exit 1
}
puts "\[OK\]    Implementation completed successfully."

# -------------------------------------------------------
# STEP 4: Open Implemented Design & Generate Reports
# -------------------------------------------------------
puts "\n============================================================"
puts "  STEP 4: Generating Implementation Reports..."
puts "============================================================"

open_run impl_1

# Utilization report (post-implementation)
report_utilization -file "$REPORT_DIR/utilization_impl.txt"
puts "\[OK\]    Saved: utilization_impl.txt"

# Timing summary (post-implementation)
report_timing_summary -file "$REPORT_DIR/timing_impl.txt"
puts "\[OK\]    Saved: timing_impl.txt"

# POWER REPORT — the key report for hackathon judges
report_power -file "$REPORT_DIR/power_report.txt"
puts "\[OK\]    Saved: power_report.txt"

# Resource usage summary
report_utilization -hierarchical -file "$REPORT_DIR/utilization_hierarchical.txt"
puts "\[OK\]    Saved: utilization_hierarchical.txt"

# Clock networks
report_clocks -file "$REPORT_DIR/clock_report.txt"
puts "\[OK\]    Saved: clock_report.txt"

# Design rule checks
report_drc -file "$REPORT_DIR/drc_report.txt"
puts "\[OK\]    Saved: drc_report.txt"

# -------------------------------------------------------
# STEP 5: Print Summary to Console
# -------------------------------------------------------
puts "\n============================================================"
puts "  SUMMARY — Key Results for Judges"
puts "============================================================"

puts "\n--- Resource Utilization ---"
report_utilization -return_string

puts "\n--- Power Summary ---"
report_power -return_string

puts "\n--- Timing ---"
report_timing_summary -return_string

# -------------------------------------------------------
# Done
# -------------------------------------------------------
close_project

puts "\n============================================================"
puts "  ALL REPORTS GENERATED SUCCESSFULLY"
puts "============================================================"
puts "  Reports saved to: $REPORT_DIR/"
puts "  Key files for judges:"
puts "    - power_report.txt         (total power consumption)"
puts "    - utilization_impl.txt     (LUT/FF/BRAM/DSP usage)"
puts "    - timing_impl.txt          (clock frequency achieved)"
puts "    - utilization_hierarchical.txt (per-module breakdown)"
puts "============================================================"
