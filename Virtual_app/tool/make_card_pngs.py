# -*- coding: utf-8 -*-
"""生成符合 Character Card V2/V3 规范的 PNG 角色卡样本，用于实测 App 的 PNG 导入路径。

规范：PNG 文本块 keyword='chara'（或 'ccv3'），value = base64(UTF-8 JSON)。
本脚本同时产出「变体」，用于区分失败根因：

  - 规范 base64 / 缺 '=' 填充 / 紧凑 JSON
  - 非规范：块内直写原始 JSON
  - 容器变体：tEXt / zTXt（zlib 压缩）/ iTXt（未压缩与压缩两种）
"""
import base64, json, os, struct, zlib

HERE = os.path.dirname(os.path.abspath(__file__))
# 用仓库内已有的真实 CCv2 夹具作内容源，产出的样本可复现
CARD = os.path.abspath(
    os.path.join(HERE, "..", "..", "Virtual_background", "test", "fixtures",
                 "cricket_card_v2.json")
)
# 产物是生成物，落在已被 .gitignore 忽略的 build/ 下
OUT = os.path.abspath(os.path.join(HERE, "..", "build", "card_samples"))
os.makedirs(OUT, exist_ok=True)

card_bytes = open(CARD, "rb").read()
card_json = json.loads(card_bytes.decode("utf-8"))


def chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def build_text_chunk(keyword: bytes, payload: bytes, chunk_type: bytes) -> bytes:
    """按块类型拼装 PNG 文本块的数据段。

    tEXt : keyword \\0 value
    zTXt : keyword \\0 compressionMethod(0) zlib(value)
    iTXt : keyword \\0 compressionFlag(1) compressionMethod(1) \\
           langTag \\0 translatedKeyword \\0 value
    """
    if chunk_type == b"zTXt":
        return keyword + b"\x00" + b"\x00" + zlib.compress(payload, 9)
    if chunk_type == b"iTXt":
        return keyword + b"\x00" + b"\x00" + b"\x00" + b"\x00" + b"\x00" + payload
    return keyword + b"\x00" + payload


def make_png(path: str, payload: bytes, keyword: bytes = b"chara",
             chunk_type: bytes = b"tEXt") -> None:
    """最小合法 PNG：IHDR + 文本块 + IDAT + IEND（1x1 像素）。"""
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)  # 1x1 RGB8
    raw = b"\x00\x00\x00\x00"  # filter byte + 1 RGB pixel
    idat = zlib.compress(raw, 9)
    # 压缩容器的样本文件带后缀，便于肉眼区分
    if chunk_type != b"tEXt":
        base, ext = os.path.splitext(path)
        path = f"{base}_{chunk_type.decode()}{ext}"
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(chunk_type, build_text_chunk(keyword, payload, chunk_type))
        + chunk(b"IDAT", idat)
        + chunk(b"IEND", b"")
    )
    with open(path, "wb") as f:
        f.write(png)
    print(f"{os.path.basename(path):<40} {len(png):>7} bytes")


# A) 规范写法：base64 编码（SillyTavern / chub.ai 实际导出方式）
make_png(os.path.join(OUT, "ccv2_spec_base64.png"),
         base64.b64encode(card_bytes))

# B) 变体：tEXt 里直接存原始 JSON（非规范，但部分工具会这么写）
make_png(os.path.join(OUT, "ccv2_raw_json.png"), card_bytes)

# C) 变体：CCv3 关键字 ccv3 + base64
make_png(os.path.join(OUT, "ccv3_spec_base64.png"),
         base64.b64encode(card_bytes), keyword=b"ccv3")

# D) 单行压缩 JSON 变体（去掉所有空白，模拟紧凑导出）
compact = json.dumps(card_json, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
make_png(os.path.join(OUT, "ccv2_compact_base64.png"), base64.b64encode(compact))

# E) zTXt 容器：base64 文本再经 zlib 压缩（规范允许，导出工具偶用）
make_png(os.path.join(OUT, "ccv2_spec_base64.png"),
         base64.b64encode(card_bytes), chunk_type=b"zTXt")

# F) iTXt 容器：未压缩载荷
make_png(os.path.join(OUT, "ccv2_spec_base64.png"),
         base64.b64encode(card_bytes), chunk_type=b"iTXt")

# G) 纯 JSON 文件（对照，走裸 JSON 分支）
with open(os.path.join(OUT, "ccv2_card.json"), "wb") as f:
    f.write(card_bytes)
print(f"{'ccv2_card.json':<40} {len(card_bytes):>7} bytes")
print(f"\n输出目录: {OUT}")
print("用法：dart run tool/card_png_probe.dart " + OUT)
