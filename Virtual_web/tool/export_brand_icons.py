import base64
import shutil
from pathlib import Path
from PIL import Image

src = Path(r"D:\Documents\Desktop\Virtual\Virtual_web\src\assets\app_icon_grad.png")
pub = Path(r"D:\Documents\Desktop\Virtual\Virtual_web\public")
img = Image.open(src).convert("RGBA")

# 带版本后缀的新文件名，强制浏览器放弃旧缓存
brand = pub / "brand-mark-v2.png"
shutil.copy2(src, brand)
print("brand-mark-v2.png", brand.stat().st_size)

for name, size in [
    ("favicon-32.png", 32),
    ("favicon-16.png", 16),
    ("favicon.png", 64),
    ("apple-touch-icon.png", 180),
    ("icon-192.png", 192),
    ("icon-512.png", 512),
    ("favicon-brand-32.png", 32),
    ("favicon-brand-16.png", 16),
]:
    out = img.resize((size, size), Image.Resampling.LANCZOS)
    path = pub / name
    out.save(path, "PNG")
    print(name, out.size, path.stat().st_size)

b64 = base64.b64encode(src.read_bytes()).decode("ascii")
svg = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">\n'
    f'  <image href="data:image/png;base64,{b64}" width="64" height="64" '
    'preserveAspectRatio="xMidYMid meet"/>\n'
    "</svg>\n"
)
(pub / "favicon.svg").write_text(svg, encoding="utf-8")
(pub / "favicon-v2.svg").write_text(svg, encoding="utf-8")
print("svg ok")
# 抽样：32px 图左上/中心色，确认是紫→橙而不是旧蓝色
s = Image.open(pub / "favicon-brand-32.png").convert("RGBA")
print("center", s.getpixel((16, 16)), "topleft_nonzero", next(
    (s.getpixel((x, y)) for y in range(32) for x in range(32) if s.getpixel((x, y))[3] > 200),
    None,
))
