from PIL import Image
import numpy as np
from pathlib import Path

src = Path(r"D:\Documents\Desktop\Virtual\Virtual_app\assets\images\app_icon.png")
dst = Path(r"D:\Documents\Desktop\Virtual\Virtual_web\src\assets\app_icon.png")
dst.parent.mkdir(parents=True, exist_ok=True)

img = Image.open(src).convert("RGBA")
arr = np.array(img, dtype=np.int16)
r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
lum = 0.299 * r + 0.587 * g + 0.114 * b
chroma = np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)

hard_bg = (lum >= 235) & (chroma <= 28)
soft_bg = (lum >= 210) & (lum < 235) & (chroma <= 28)

alpha = arr[..., 3].copy()
alpha[hard_bg] = 0
soft_a = ((235 - lum[soft_bg]) / 25.0 * 255).clip(0, 255).astype(np.int16)
alpha[soft_bg] = np.minimum(alpha[soft_bg], soft_a)
arr[..., 3] = alpha

out = Image.fromarray(arr.astype(np.uint8), "RGBA")
bbox = out.getbbox()
if bbox:
    pad = 8
    x0 = max(0, bbox[0] - pad)
    y0 = max(0, bbox[1] - pad)
    x1 = min(out.width, bbox[2] + pad)
    y1 = min(out.height, bbox[3] + pad)
    out = out.crop((x0, y0, x1, y1))

out.save(dst, "PNG")
chk = Image.open(dst).convert("RGBA")
a = np.array(chk)[..., 3]
print("size", chk.size)
print("alpha_zero_ratio", float((a == 0).mean()))
print("alpha_opaque_ratio", float((a == 255).mean()))
print("corner_rgba", chk.getpixel((0, 0)))
print("dst", dst)
