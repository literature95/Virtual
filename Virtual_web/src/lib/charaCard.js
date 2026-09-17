// ── PNG 角色卡（CCv2 / CCv3 chara 元数据）解析 ──
//
// 规范把角色卡 JSON 存进 PNG 的文本块，关键字 `chara`，负载为 base64。各工具
// 写出的负载形式并不统一，实测至少三种：
//   ① 明文 JSON 的 base64            —— SillyTavern 导出的 v2 卡（最常见）
//   ② zlib 包装的 deflate 的 base64  —— 首字节 0x78（部分转换工具）
//   ③ 裸 deflate 的 base64           —— 无 zlib 头（少数）
// 块类型除 tEXt 外，还可能遇到 zTXt（块级 zlib）与 iTXt（UTF-8，可压缩）。
//
// 🔴 踩坑记录：早期实现无条件按 ③（deflate-raw）解压。遇到 ① 时解压流直接报错，
// 而浏览器会把「响应体流出错」统一抛成 `TypeError: Failed to fetch`，看起来像
// 网络故障（其实本地解析、根本没发请求），极难定位。
// 故这里改为：先按首字节嗅探格式 → 再逐个格式退化尝试，并把失败原因写清。

const PNG_SIG = [137, 80, 78, 71, 13, 10, 26, 10];

/// Uint8Array → 二进制字符串（分块，避免 apply 参数过多爆栈）
function asciiOf(bytes) {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    s += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  }
  return s;
}

/// base64 → Uint8Array
/// 兼容：夹带换行、URL-safe 字符（- _）、缺失尾部 padding（少数工具会丢 `=`）
function b64ToBytes(b64) {
  let s = b64.replace(/\s+/g, '').replace(/-/g, '+').replace(/_/g, '/');
  const pad = s.length % 4;
  if (pad) s += '='.repeat(4 - pad);
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/// 按首字节嗅探压缩格式
export function sniffFormat(bytes) {
  if (bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b) return 'gzip';
  if (bytes.length >= 1 && bytes[0] === 0x78) return 'deflate'; // zlib: 78 01 / 78 9c / 78 da
  return 'deflate-raw';
}

const looksLikeJson = (text) => {
  const t = text.replace(/^\uFEFF/, '').trimStart();
  return t.startsWith('{') || t.startsWith('[');
};

const decodeText = (bytes) =>
  new TextDecoder('utf-8').decode(bytes).replace(/\0+$/, '');

async function decompressBytes(bytes, format) {
  const stream = new Blob([bytes])
    .stream()
    .pipeThrough(new DecompressionStream(format));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/// 负载字节 → JSON 文本：明文直接用；压缩的按嗅探结果解压，失败则退化尝试。
export async function payloadToJsonText(bytes) {
  const plain = decodeText(bytes);
  if (looksLikeJson(plain)) {
    try {
      JSON.parse(plain);
      return plain;
    } catch {
      // 看起来像 JSON 却 parse 不通过 → 继续走解压分支
    }
  }

  const first = sniffFormat(bytes);
  const order = [first, 'deflate', 'deflate-raw', 'gzip'].filter(
    (f, i, a) => a.indexOf(f) === i,
  );

  let lastErr = null;
  for (const fmt of order) {
    try {
      const text = decodeText(await decompressBytes(bytes, fmt));
      if (looksLikeJson(text) && JSON.parse(text)) return text;
    } catch (e) {
      lastErr = e;
    }
  }
  throw new Error(
    `角色卡数据无法解析：既不是明文 JSON，按 ${order.join(' / ')} 解压也均失败` +
      (lastErr?.message ? `（${lastErr.message}）` : ''),
  );
}

/// 读取一个文本块，命中 chara 时返回负载字节（尚未 base64 解码），否则返回 null
async function readCharaChunk(bytes, type, start, len) {
  const end = start + len;
  let p = start;
  while (p < end && bytes[p] !== 0) p++;
  if (p >= end) return null;

  const keyword = asciiOf(bytes.subarray(start, p)).toLowerCase();
  if (keyword !== 'chara' && keyword !== 'ccv3') return null;

  let cursor = p + 1;
  if (type === 'tEXt') return bytes.subarray(cursor, end);

  if (type === 'zTXt') {
    // keyword \0 compressionMethod(1) compressedText
    return decompressBytes(bytes.subarray(cursor + 1, end), 'deflate');
  }

  // iTXt: keyword \0 flag(1) method(1) languageTag \0 translatedKeyword \0 text
  const flag = bytes[cursor];
  cursor += 2;
  while (cursor < end && bytes[cursor] !== 0) cursor++;
  cursor++;
  while (cursor < end && bytes[cursor] !== 0) cursor++;
  cursor++;
  const payload = bytes.subarray(cursor, end);
  return flag === 1 ? decompressBytes(payload, 'deflate') : payload;
}

/// 从 PNG 文件中提取角色卡对象（兼容 .png File / Blob）
export async function extractCharaFromPng(file) {
  const bytes = new Uint8Array(await file.arrayBuffer());
  for (let i = 0; i < PNG_SIG.length; i++) {
    if (bytes[i] !== PNG_SIG[i]) {
      throw new Error('不是有效的 PNG 文件（缺少 PNG 签名）');
    }
  }

  let off = 8;
  let sawTextChunk = false;

  while (off + 12 <= bytes.length) {
    const len =
      ((bytes[off] << 24) |
        (bytes[off + 1] << 16) |
        (bytes[off + 2] << 8) |
        bytes[off + 3]) >>>
      0;
    if (off + 12 + len > bytes.length) break;

    const type = asciiOf(bytes.subarray(off + 4, off + 8));
    const dataStart = off + 8;

    if (type === 'tEXt' || type === 'zTXt' || type === 'iTXt') {
      sawTextChunk = true;
      const raw = await readCharaChunk(bytes, type, dataStart, len);
      if (raw != null && raw.length > 0) {
        let payload = raw;
        try {
          payload = b64ToBytes(asciiOf(raw));
        } catch {
          // 少数工具把 JSON 明文直接写进 tEXt（不做 base64），此时原样使用
        }
        const obj = JSON.parse(await payloadToJsonText(payload));
        // 内置立绘多为 data URI，体积巨大且后端不抓取，落库前剔除
        return stripDataAvatar(obj);
      }
    }

    if (type === 'IEND') break;
    off = dataStart + len + 4;
  }

  throw new Error(
    sawTextChunk
      ? 'PNG 中没有角色卡数据（未找到 chara 元数据块）'
      : 'PNG 中没有任何文本元数据块，这似乎只是一张普通图片',
  );
}

/// 剔除 data URI 立绘（含 v2 信封内的 data.avatar）
export function stripDataAvatar(obj) {
  if (obj && typeof obj.avatar === 'string' && obj.avatar.startsWith('data:')) {
    delete obj.avatar;
  }
  if (
    obj?.data &&
    typeof obj.data.avatar === 'string' &&
    obj.data.avatar.startsWith('data:')
  ) {
    delete obj.data.avatar;
  }
  return obj;
}
