# VISOR — RISC-V ReRAM Sobel Edge Detection SoC

A 3-stage in-order RISC-V (RV32I) pipeline on Artix-7 FPGA with a custom
instruction that triggers a simulated ReRAM In-Memory Computing accelerator
for real-time Sobel edge detection on 32×32 grayscale images.

## Folder Structure

```
rtl/           → Verilog RTL source files (pipeline + accelerator)
sim/           → Testbenches (pipeline + ReRAM standalone)
scripts/       → Python utilities and Vivado TCL automation
mem/           → program.mem (RISC-V hex) + sobel_program.s (assembly source)
test_data/     → Sample input images
output/        → Generated at runtime, gitignored
```

## Requirements

- Vivado 2022.x or later (xsim simulator)
- Python 3.8+
- Pillow: `pip install Pillow`

## How To Run — Step by Step

### Step 1 — Convert your image to simulation input

```bash
python scripts/img_to_mem.py test_data/test_image.png output/image.mem
```

What you should see:
```
[OK] Written 1024 pixels to output/image.mem
Sample (first 5): ['00000053', '00000051', ...]
```

### Step 2 — Configure the TCL script

Open `scripts/run_sim.tcl` and set:
- `PROJECT_DIR`  → full absolute path to this project folder
- `PROJECT_NAME` → `VISOR`
- `SIM_TOP`      → `tb_RISCV_Pipeline`

### Step 3 — Run Vivado simulation

```bash
vivado -mode batch -source scripts/run_sim.tcl -nojournal -nolog
```

What you should see:
```
[INFO]  Launching simulation...
[OK]    output_image.mem copied to output/
[DONE]  Batch simulation finished.
```
Runtime: ~30 seconds

### Step 4 — Convert simulation output to image

```bash
python scripts/mem_to_img.py output/output_image.mem output/edge_detected_output.png
```

What you should see:
```
[OK]  Saved edge image (512×512) → output/edge_detected_output.png
[OK]  Saved raw 32×32 image      → output/edge_detected_output_32x32.png
Non-zero pixels (edges detected): ~200-400 / 1024
```

Open `output/edge_detected_output.png` — you should see white edges on black background.

### (Optional) Run all 4 steps in one command

```bash
python scripts/run_pipeline.py test_data/test_image.png
```

## Troubleshooting

| Problem | Fix |
|---|---|
| `vivado: command not found` | Set `VIVADO_PATH` in `scripts/run_pipeline.py` to your Vivado install path |
| `image.mem not found in sim` | Check that `output/` folder exists and Step 1 ran successfully |
| `output_image.mem is empty or missing` | Check sim log — look for `$writememh` errors |
| `0 non-zero pixels in output` | `program.mem` may not have loaded — verify `mem/` path in `run_sim.tcl` |
| `Edge image looks wrong` | Check `test_image.png` has clear edges — try a high contrast image |
