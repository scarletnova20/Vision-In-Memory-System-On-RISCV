#!/usr/bin/env python3
"""
mem_to_img.py
Reads output_image.mem (1024 lines of 32-bit hex) from Vivado simulation.
Extracts lower 8 bits per word → reconstructs 32x32 edge-detected image.
Usage: python mem_to_img.py [input.mem] [output.png]
"""

import sys
import os

try:
    from PIL import Image
except ImportError:
    sys.exit("[ERROR] Pillow not installed. Run: pip install Pillow")

import struct

def mem_to_img(input_path="output_image.mem", output_path="edge_detected_output.png"):
    if not os.path.exists(input_path):
        sys.exit(f"[ERROR] File not found: '{input_path}'\n"
                 f"       Make sure Vivado simulation has completed and "
                 f"$writememh was called.")

    print(f"[INFO] Reading: {input_path}")
    pixels = []

    with open(input_path, "r") as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith("//") or line.startswith("@"):
                # Skip blank lines, comments, and $readmemh address markers
                continue
            try:
                word = int(line, 16)        # Parse 32-bit hex word
                px   = word & 0xFF          # Extract lower 8 bits = pixel intensity
                pixels.append(px)
            except ValueError:
                print(f"[WARN] Skipping unparseable line {lineno}: '{line}'")

    if len(pixels) != 1024:
        print(f"[WARN] Expected 1024 pixels, got {len(pixels)}. "
              f"Image may be incomplete.")
        # Pad with zeros if short, truncate if too long
        pixels = (pixels + [0] * 1024)[:1024]

    # Reconstruct 32x32 image
    img = Image.new("L", (32, 32))
    img.putdata(pixels)

    # Scale up for visibility (32x32 is tiny) — save both sizes
    img_large = img.resize((512, 512), Image.NEAREST)   # Crisp pixel-art upscale
    img_large.save(output_path)

    # Also save a raw 32x32 version
    raw_path = output_path.replace(".png", "_32x32.png")
    img.save(raw_path)

    print(f"[OK]   Saved edge image (512x512) → 'C:\\Users\\hridd\\VISOR'")
    print(f"[OK]   Saved raw 32x32 image      → 'C:\\Users\\hridd\\VISOR'")
    print(f"       Non-zero pixels (edges detected): "
          f"{sum(1 for p in pixels if p > 0)} / 1024")
    print(f"       Max intensity: {max(pixels)}  |  Mean: {sum(pixels)/len(pixels):.1f}")

if __name__ == "__main__":
    input_path  = sys.argv[1] if len(sys.argv) > 1 else "output_image.mem"
    output_path = sys.argv[2] if len(sys.argv) > 2 else "edge_detected_output.png"
    mem_to_img(input_path, output_path)
