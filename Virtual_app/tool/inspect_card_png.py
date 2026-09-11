# -*- coding: utf-8 -*-
"""只读探针：列出 PNG 的全部 chunk，并尝试解析角色卡元数据。"""
import base64, json, os, struct, sys, zlib

CARD_KEYS = {"chara", "ccv3", "chara_card_v2", "chara_card_v3"}
SIG = b"\x89PNG\r\n\x1a\n"


def iter_chunks(b):
    off = 8
    while off + 8 <= len(b):
        (ln,) = struct.unpack(">I", b[off:off + 4])
        ctype = b[off + 4:off + 8].decode("latin1")
        s = off + 8
        e = s + ln
        if e + 4 > len(b):
            yield ctype, ln, b[s:e], True
            return
        yield ctype, ln, b[s:e], False
        crc = struct.unpack(">I", b[e:e + 4])[0]
        yield ("__crc__", crc, ctype, None) if False else None
        off = e + 4
        if ctype == "IEND":
            return


def try_json(text):
    try:
        return json.loads(text)
    except Exception as e:
        return f"<jsonDecode 失败: {e}>"


path = sys.argv[1]
raw = open(path, "rb").read()
print(f"文件: {os.path.basename(path)}")
print(f"大小: {len(raw):,} 字节")
print(f"PNG 签名: {'OK' if raw[:8] == SIG else '不匹配!'}")
print()

print(f"{'类型':<8}{'长度':>10}  说明")
print("-" * 60)
meta = []
for item in iter_chunks(raw):
    if item is None:
        continue
    ctype, ln, data, truncated = item
    note = ""
    if ctype == "IHDR":
        w, h, depth, color = struct.unpack(">IIBB", data[:10])
        note = f"{w}x{h} depth={depth} colorType={color}"
    elif ctype in ("tEXt", "iTXt"):
        nul = data.find(b"\x00")
        kw = data[:nul].decode("latin1") if nul >= 0 else "?"
        note = f'keyword="{kw}"'
        meta.append((ctype, kw, data))
    elif ctype == "IDAT":
        note = f"zlib 压缩块（'\\x78' 头？{data[:1] == b'\x78'}）"
    print(f"{ctype:<8}{ln:>10}  {note}")
    if truncated:
        print("  !! 文件在 chunk 中途截断")
        break

print()
if not meta:
    print("结论: 没有任何 tEXt / iTXt 文本块 —— 该 PNG 不含角色卡元数据。")
    sys.exit(0)

print(f"共 {len(meta)} 个文本块，逐个尝试解码：")
for ctype, kw, data in meta:
    print()
    print(f"── {ctype} keyword={kw!r} ──")
    nul = data.find(b"\x00")
    if ctype == "tEXt":
        value = data[nul + 1:]
        enc = "latin1(直读)"
    else:
        p = nul + 1
        flag, method = data[p], data[p + 1]
        p += 2
        def after(b, i):
            return b.find(b"\x00", i)
        p = after(data, p) + 1
        p = after(data, p) + 1
        value = data[p:]
        enc = f"iTXt(flag={flag} method={method})"
    print(f"  编码: {enc}  值长度: {len(value)}")
    head = value[:60]
    print(f"  前 60 字节: {head!r}")

    if value[:1] == b"{":
        print("  形态: 直写 JSON（非规范）")
        card = try_json(value.decode("utf-8", "replace"))
        print(f"  jsonDecode: {'OK' if isinstance(card, dict) else card}")
    else:
        b64 = value.strip()
        pad = len(b64) % 4
        if pad:
            b64 += b"=" * (4 - pad)
        try:
            dec = base64.b64decode(b64, validate=False)
            print(f"  形态: base64 → 解出 {len(dec):,} 字节")
            print(f"  解码后前 80 字节: {dec[:80]!r}")
            card = try_json(dec.decode("utf-8", "replace"))
            print(f"  jsonDecode: {'OK' if isinstance(card, dict) else card}")
            if isinstance(card, dict):
                print(f"  顶层键: {list(card.keys())}")
                d = card.get("data", card)
                print(f"  spec={card.get('spec')} spec_version={card.get('spec_version')}")
                print(f"  name={d.get('name')!r}  字段数={len(d)}")
                print(f"  mes_example 非空={bool(str(d.get('mes_example') or '').strip())}"
                      f"  character_book={'有' if d.get('character_book') else '无'}"
                      f"  alternate_greetings={len(d.get('alternate_greetings') or [])}")
        except Exception as e:
            print(f"  base64 解码失败: {e}")
