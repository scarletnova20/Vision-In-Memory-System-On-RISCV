#!/usr/bin/env python3
"""
img_to_mem.py
Converts any PNG/JPG image → 32x32 grayscale → image.mem
Each line is a 32-bit zero-padded hex value (e.g., 000000FF for pixel=255).
Usage: python img_to_mem.py <input_image> [output.mem]
"""

import sys
import os

try:
    from PIL import Image
except ImportError:
    sys.exit("[ERROR] Pillow not installed. Run: pip install Pillow")

def img_to_mem(input_path, output_path="image.mem"):
    if not os.path.exists(input_path):
        sys.exit(f"[ERROR] File not found: {input_path}")

    print(f"[INFO] Loading image: {input_path}")
    img = Image.open(input_path)

    # Convert to grayscale and resize to 32x32
    img = img.convert("L")              # Grayscale (0–255)
    img = img.resize((32, 32), Image.LANCZOS)

    pixels = list(img.getdata())        # Flat list of 1024 pixel values
    assert len(pixels) == 1024, f"Expected 1024 pixels, got {len(pixels)}"

    with open(output_path, "w") as f:
        for px in pixels:
            # 32-bit zero-padded hex — lower 8 bits = pixel intensity
            f.write(f"{px:08X}\n")

    print(f"[OK]   Written {len(pixels)} pixels to '{output_path}'")
    print(f"       Sample (first 5): {[f'{p:08X}' for p in pixels[:5]]}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python img_to_mem.py <input_image> [output.mem]")
        sys.exit(1)
    input_path  = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else "image.mem"
    img_to_mem(input_path, output_path)
