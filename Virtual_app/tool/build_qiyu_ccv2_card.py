# -*- coding: utf-8 -*-
"""制作完美 Character Card V2 PNG 角色卡。

规范对齐 Virtual App / SillyTavern：
- PNG tEXt keyword = chara 与 ccv3（两块同值）
- value = base64(UTF-8 JSON)，JSON 为 {"spec":"chara_card_v2","data":{...}}
- 底图 = 用户提供的立绘
- character_book.entries 为数组（CCv2/ccv3 形态，不是 SillyTavern World Info 对象）
"""
from __future__ import annotations

import base64
import json
import struct
import zlib
from pathlib import Path

from PIL import Image
from PIL.PngImagePlugin import PngInfo

SRC_JSON = Path(r"D:\Documents\Desktop\deepseek_json_20260918_9f836f.json")
SRC_IMG = Path(r"D:\Documents\Desktop\恋与深空祁煜.png")
OUT_PNG = Path(r"D:\Documents\Desktop\祁煜_CCv2角色卡.png")
OUT_JSON = Path(r"D:\Documents\Desktop\祁煜_CCv2角色卡.json")


def polish_card(raw: dict) -> dict:
    """补齐/规范字段，保证 Virtual 与 SillyTavern 都能完整吃下。"""
    data = dict(raw.get("data") or {})
    name = data.get("name") or "祁煜"

    # 元信息
    data.setdefault("creator", "Virtual User")
    data.setdefault("character_version", "1.0")
    data.setdefault("nickname", "Rafayel")
    data.setdefault("creator_notes_multilingual", {})
    data.setdefault("group_only_greetings", [])
    data.setdefault("extensions", {})
    # PNG 已是立绘；卡内 avatar 不再重复嵌 data URL（体积/兼容）
    if not data.get("avatar") or data["avatar"] in ("", "none", "null"):
        data["avatar"] = "none"

    # 示例对话：确保说话人宏可被 App 解析
    if data.get("mes_example") and not data["mes_example"].lstrip().startswith("<START>"):
        data["mes_example"] = "<START>\n" + data["mes_example"].lstrip()

    # 世界书：CCv2 条目数组 + Virtual 可识别字段
    book = data.get("character_book")
    if isinstance(book, dict):
        book = dict(book)
        book.setdefault("name", f"{name}世界书")
        book.setdefault("scan_depth", 4)
        book.setdefault("token_budget", 800)
        book.setdefault("recursive_scanning", True)
        book.setdefault("extensions", {})
        entries = []
        for i, e in enumerate(book.get("entries") or []):
            e = dict(e)
            e.setdefault("keys", [])
            if isinstance(e["keys"], str):
                e["keys"] = [e["keys"]]
            e.setdefault("enabled", True)
            e.setdefault("insertion_order", 100 - i * 10)
            # CCv2/CCv3 语义字符串；Virtual 映射 before_char→beforeSystem 等
            e.setdefault("position", "after_char")
            e.setdefault("selective", False)
            e.setdefault("constant", False)
            e.setdefault("extensions", {})
            e.setdefault("comment", "")
            e.setdefault("case_sensitive", False)
            e.setdefault("priority", 50)
            e.setdefault("probability", 100)
            e.setdefault("use_probability", True)
            e.setdefault("order", e["insertion_order"])
            entries.append(e)
        book["entries"] = entries
        data["character_book"] = book

    # 关键字段非空校验（完美卡的底线）
    required = ["name", "description", "personality", "scenario", "first_mes", "mes_example"]
    missing = [k for k in required if not str(data.get(k) or "").strip()]
    if missing:
        raise SystemExit(f"关键字段缺失: {missing}")

    return {
        "spec": "chara_card_v2",
        "spec_version": "2.0",
        "data": data,
    }


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(
        ">I", zlib.crc32(tag + data) & 0xFFFFFFFF
    )


def write_png_with_text(src_img: Path, payload_b64: str, out_png: Path) -> None:
    """底图 + tEXt(chara/ccv3)。优先走 Pillow；同时保证可被二进制探针读到。"""
    im = Image.open(src_img)
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGBA")
    # 统一转 PNG 像素（去 JPEG 等源格式的隐式压缩损失在所难免，源已是 png）
    info = PngInfo()
    # Pillow: latin-1 可表示的 ASCII base64 走 tEXt
    info.add_text("chara", payload_b64)
    info.add_text("ccv3", payload_b64)
    im.save(out_png, format="PNG", pnginfo=info, optimize=True)


def verify_png(path: Path) -> None:
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", "PNG 签名错误"
    found = {}
    off = 8
    while off + 8 <= len(raw):
        (ln,) = struct.unpack(">I", raw[off : off + 4])
        ctype = raw[off + 4 : off + 8]
        data = raw[off + 8 : off + 8 + ln]
        if ctype in (b"tEXt", b"zTXt", b"iTXt"):
            nul = data.find(b"\x00")
            kw = data[:nul].decode("latin1")
            if ctype == b"tEXt":
                val = data[nul + 1 :]
            elif ctype == b"zTXt":
                val = zlib.decompress(data[nul + 2 :])
            else:
                # iTXt: flag method lang\0 key\0 value
                p = nul + 1
                flag, method = data[p], data[p + 1]
                p += 2
                p = data.find(b"\x00", p) + 1
                p = data.find(b"\x00", p) + 1
                val = data[p:]
                if flag == 1:
                    val = zlib.decompress(val)
            if kw in ("chara", "ccv3"):
                js = json.loads(base64.b64decode(val).decode("utf-8"))
                found[kw] = js
        off = off + 8 + ln + 4
        if ctype == b"IEND":
            break

    assert "chara" in found and "ccv3" in found, f"文本块不齐: {list(found)}"
    assert found["chara"] == found["ccv3"], "chara/ccv3 内容不一致"
    card = found["chara"]
    assert card.get("spec") == "chara_card_v2", card.get("spec")
    d = card["data"]
    print("VERIFY_OK")
    print("  name:", d["name"])
    print("  spec:", card["spec"], card["spec_version"])
    print("  description:", len(d["description"]), "chars")
    print("  first_mes:", len(d["first_mes"]), "chars")
    print("  mes_example:", len(d["mes_example"]), "chars")
    print("  alternate_greetings:", len(d.get("alternate_greetings") or []))
    print("  tags:", d.get("tags"))
    book = d.get("character_book") or {}
    print("  lorebook:", book.get("name"), "entries=", len(book.get("entries") or []))
    print("  creator:", d.get("creator"), "version:", d.get("character_version"))


def main() -> None:
    raw = json.loads(SRC_JSON.read_text(encoding="utf-8"))
    card = polish_card(raw)
    js = json.dumps(card, ensure_ascii=False, separators=(",", ":"))
    # 规范：紧凑 JSON 亦可；这里用 ensure_ascii=False + 紧凑，减小 base64 体积
    payload = base64.b64encode(js.encode("utf-8")).decode("ascii")
    OUT_JSON.write_text(
        json.dumps(card, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    write_png_with_text(SRC_IMG, payload, OUT_PNG)
    print(f"PNG  -> {OUT_PNG}  ({OUT_PNG.stat().st_size:,} bytes)")
    print(f"JSON -> {OUT_JSON}")
    print(f"base64 payload: {len(payload):,} chars")
    verify_png(OUT_PNG)

    im = Image.open(OUT_PNG)
    print(f"image: {im.size[0]}x{im.size[1]} mode={im.mode}")


if __name__ == "__main__":
    main()
