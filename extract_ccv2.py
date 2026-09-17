import struct, zlib, base64, json, sys

path = r"D:\Documents\Desktop\331a8ebde0831a1ab1f69b51419c97db.png"

def extract_text_chunks(path):
    out = {}
    with open(path, "rb") as f:
        sig = f.read(8)
        assert sig == b"\x89PNG\r\n\x1a\n", "not a png"
        while True:
            hdr = f.read(8)
            if len(hdr) < 8:
                break
            length = struct.unpack(">I", hdr[:4])[0]
            ctype = hdr[4:8].decode("latin-1")
            data = f.read(length)
            f.read(4)  # crc
            if ctype in ("tEXt", "iTXt", "zTXt"):
                if ctype == "tEXt":
                    kw, _, txt = data.partition(b"\x00")
                    out[kw.decode("latin-1")] = txt.decode("latin-1")
                elif ctype == "iTXt":
                    # keyword\0 comp_flag comp_method lang\0 trans\0 text...
                    kw, rest = data.split(b"\x00", 1)
                    comp = rest[0]
                    # method rest[1]; then lang\0 trans\0 then text
                    p = 2
                    # lang
                    e = rest.index(b"\x00", p)
                    p = e + 1
                    # translated keyword
                    e = rest.index(b"\x00", p)
                    p = e + 1
                    txt = rest[p:]
                    if comp == 1:
                        txt = zlib.decompress(txt)
                    out[kw.decode("latin-1")] = txt.decode("utf-8")
                elif ctype == "zTXt":
                    kw, _, rest = data.partition(b"\x00")
                    # method rest[0], then compressed text
                    txt = zlib.decompress(rest[1:])
                    out[kw.decode("latin-1")] = txt.decode("latin-1")
            if ctype == "IEND":
                break
    return out

chunks = extract_text_chunks(path)
print("=== chunk keywords ===")
for k in chunks:
    print(repr(k), "len=", len(chunks[k]))

raw = chunks.get("chara")
if not raw:
    print("NO 'chara' chunk found.")
    sys.exit(0)

print("\n=== chara raw (first 200 chars) ===")
print(raw[:200])

# decode base64
try:
    blob = base64.b64decode(raw)
except Exception as e:
    print("base64 decode failed:", e)
    sys.exit(0)

print("decoded bytes len:", len(blob), "first bytes:", blob[:4])

# try gzip
data = None
if blob[:2] == b"\x1f\x8b":
    try:
        data = zlib.decompress(blob, 16 + zlib.MAX_WBITS)
        print("gzip decompressed, len:", len(data))
    except Exception as e:
        print("gzip failed:", e)
else:
    data = blob

if data is None:
    print("could not decode payload")
    sys.exit(0)

try:
    obj = json.loads(data.decode("utf-8"))
    print("\n=== JSON parsed OK ===")
    print("top keys:", list(obj.keys()))
    if isinstance(obj, dict) and "data" in obj:
        print("spec:", obj.get("spec"), "version:", obj.get("spec_version"))
        d = obj["data"]
        print("data keys:", list(d.keys()))
        for k in ("name", "creator", "character_version", "description", "personality", "scenario", "first_mes", "mes_example", "system_prompt", "creator_notes", "tags", "post_history_instructions", "alternate_greetings", "group_only_greetings"):
            v = d.get(k)
            if isinstance(v, str):
                print(f"  {k}: {v[:120]!r}{'...' if len(v) > 120 else ''}")
            else:
                print(f"  {k}: {type(v).__name__} {str(v)[:120]}")
        cb = d.get("character_book")
        if cb:
            print("  character_book keys:", list(cb.keys()))
            print("  character_book entries:", len(cb.get("entries", [])))
        ext = d.get("extensions")
        if ext:
            print("  extensions keys:", list(ext.keys()))
    # full dump
    with open(r"D:\Documents\Desktop\Virtual\ccv2_extracted.json", "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
    print("\nFULL JSON written to D:\\Documents\\Desktop\\Virtual\\ccv2_extracted.json")
except Exception as e:
    print("json parse failed:", e)
    print("decoded text head:", data[:300].decode("utf-8", "replace"))
