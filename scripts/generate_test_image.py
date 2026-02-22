#!/usr/bin/env python3
"""
generate_test_image.py
Creates a recognizable 32x32 grayscale test image with bold geometric shapes
that produce clear, impressive edge detection results.
"""
from PIL import Image, ImageDraw
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)

img = Image.new('L', (32, 32), 0)  # Black background
draw = ImageDraw.Draw(img)

# Large bright rectangle (house body) — strong vertical & horizontal edges
draw.rectangle([4, 10, 27, 28], fill=180)

# Roof triangle — strong diagonal edges
draw.polygon([(2, 10), (15, 2), (29, 10)], fill=220)

# Door — inner rectangle creates nested edges
draw.rectangle([12, 18, 19, 28], fill=60)

# Window 1 — bright square on dark body
draw.rectangle([6, 13, 10, 17], fill=255)

# Window 2
draw.rectangle([21, 13, 25, 17], fill=255)

# Chimney
draw.rectangle([22, 2, 25, 8], fill=200)

# Ground line
draw.line([(0, 29), (31, 29)], fill=120, width=1)

# Sun (small circle in top-left)
draw.ellipse([1, 1, 6, 6], fill=255)

output_path = os.path.join(PROJECT_ROOT, "test_data", "test_image.png")
img.save(output_path)
print(f"[OK] Saved 32x32 test image → {output_path}")

# Also save a preview upscaled version
img_preview = img.resize((512, 512), Image.NEAREST)
preview_path = os.path.join(PROJECT_ROOT, "test_data", "test_image_preview.png")
img_preview.save(preview_path)
print(f"[OK] Saved 512x512 preview → {preview_path}")
