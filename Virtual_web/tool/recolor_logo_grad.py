"""用品牌签名渐变重着色透明 logo（保留原 alpha 外形）"""
from PIL import Image
import numpy as np
from pathlib import Path

src = Path(r"D:\Documents\Desktop\Virtual\Virtual_web\src\assets\app_icon.png")
dst = Path(r"D:\Documents\Desktop\Virtual\Virtual_web\src\assets\app_icon_grad.png")

# 与 App.css var(--grad) 一致：linear-gradient(100deg, #7e4df1 0%, #e3756e 78%, #e58029 100%)
stops = [
    (0.00, (0x7E, 0x4D, 0xF1)),  # violet
    (0.78, (0xE3, 0x75, 0x6E)),  # coral
    (1.00, (0xE5, 0x80, 0x29)),  # amber
]

img = Image.open(src).convert("RGBA")
arr = np.array(img)
h, w = arr.shape[:2]
alpha = arr[..., 3]

# 对角渐变（左上 → 右下），贴近 CSS linear-gradient(135deg, ...)
yy, xx = np.mgrid[0:h, 0:w]
t = (xx / max(w - 1, 1) + yy / max(h - 1, 1)) / 2.0

def sample(t):
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,), dtype=np.float64)
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        m = (t >= t0) & (t <= t1)
        u = (t[m] - t0) / max(t1 - t0, 1e-9)
        for ch in range(3):
            out[..., ch][m] = c0[ch] + (c1[ch] - c0[ch]) * u
    # t 处理端点
    out[t < stops[0][0]] = stops[0][1]
    out[t > stops[-1][0]] = stops[-1][1]
    return out

rgb = sample(t)
out = np.zeros_like(arr)
out[..., 0] = rgb[..., 0]
out[..., 1] = rgb[..., 1]
out[..., 2] = rgb[..., 2]
out[..., 3] = alpha
Image.fromarray(out.astype(np.uint8), "RGBA").save(dst, "PNG")
print("wrote", dst, dst.stat().st_size)
chk = Image.open(dst)
print("size", chk.size, "corner", chk.convert("RGBA").getpixel((0, 0)))
