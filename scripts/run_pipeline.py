#!/usr/bin/env python3
"""
run_pipeline.py
Full automation: image → .mem → Vivado sim → output PNG
Runs all three steps in sequence from one terminal command.

Usage (from project root):
    python scripts/run_pipeline.py test_data/test_image.png

Requirements:
    - Pillow:  pip install Pillow
    - Vivado must be on your PATH, OR set VIVADO_PATH below.
"""

import sys
import os
import subprocess
import shutil

# -------------------------------------------------------
# USER CONFIGURATION
# -------------------------------------------------------
VIVADO_PATH = "C:/Xilinx/2025.1/Vivado/bin/vivado.bat"  # Full path to Vivado executable

# -------------------------------------------------------
# PATH SETUP — resolve project root from script location
# -------------------------------------------------------
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)  # scripts/ → project root

TCL_SCRIPT  = os.path.join(SCRIPT_DIR, "run_sim.tcl")
IMG_TO_MEM  = os.path.join(SCRIPT_DIR, "img_to_mem.py")
MEM_TO_IMG  = os.path.join(SCRIPT_DIR, "mem_to_img.py")

INPUT_MEM   = os.path.join(PROJECT_ROOT, "output", "image.mem")
OUTPUT_MEM  = os.path.join(PROJECT_ROOT, "output", "output_image.mem")
OUTPUT_PNG  = os.path.join(PROJECT_ROOT, "output", "edge_detected_output.png")
# -------------------------------------------------------

def banner(msg):
    print(f"\n{'='*60}")
    print(f"  {msg}")
    print(f"{'='*60}")

def check_file(path, label):
    if not os.path.exists(path):
        sys.exit(f"[ERROR] {label} not found: '{path}'")

def run_step(cmd, label, cwd=None):
    banner(f"STEP: {label}")
    print(f"[CMD] {' '.join(cmd)}\n")
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    if result.returncode != 0:
        sys.exit(f"[ERROR] '{label}' failed with exit code {result.returncode}")
    print(f"[OK]  {label} completed successfully.")

def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts/run_pipeline.py <input_image.png>")
        sys.exit(1)

    input_image = os.path.abspath(sys.argv[1])
    check_file(input_image, "Input image")

    # Ensure output directory exists
    os.makedirs(os.path.join(PROJECT_ROOT, "output"), exist_ok=True)

    # -------------------------------------------------------
    # STEP 1: Convert image → image.mem
    # -------------------------------------------------------
    run_step(
        [sys.executable, IMG_TO_MEM, input_image, INPUT_MEM],
        "Image → image.mem conversion"
    )
    check_file(INPUT_MEM, "image.mem (output of step 1)")

    # -------------------------------------------------------
    # STEP 2: Run Vivado simulation in batch mode
    # -------------------------------------------------------
    check_file(TCL_SCRIPT, "run_sim.tcl")

    vivado_exe = shutil.which(VIVADO_PATH) or VIVADO_PATH
    if not shutil.which(vivado_exe):
        print(f"[WARN] Vivado not found at '{vivado_exe}'.")
        print("       Skipping simulation step. You can run manually:")
        print(f"         vivado -mode batch -source {TCL_SCRIPT}")
    else:
        run_step(
            [vivado_exe, "-mode", "batch", "-source", TCL_SCRIPT,
             "-nojournal", "-nolog"],
            "Vivado batch simulation",
            cwd=PROJECT_ROOT
        )

    # -------------------------------------------------------
    # STEP 3: Convert output_image.mem → edge PNG
    # -------------------------------------------------------
    check_file(OUTPUT_MEM, "output_image.mem (output of simulation)")

    run_step(
        [sys.executable, MEM_TO_IMG, OUTPUT_MEM, OUTPUT_PNG],
        "output_image.mem → edge PNG"
    )

    banner("ALL STEPS COMPLETE")
    print(f"  Input image:       {input_image}")
    print(f"  Simulation input:  {INPUT_MEM}")
    print(f"  Simulation output: {OUTPUT_MEM}")
    print(f"  Edge result PNG:   {OUTPUT_PNG}")

if __name__ == "__main__":
    main()
