/// GGUF 文件头校验（纯 Dart，无 IO，便于单测）。
///
/// GGUF 规范：文件前 4 字节为 ASCII `GGUF`，紧跟 4 字节小端无符号整数版本号。
/// 当前生态常见版本为 v2 / v3（v1 为历史格式），v4 尚未定稿，因此接受 1–3。
class GgufHeaderCheck {
  final bool valid;
  final int version;
  final String? error;

  const GgufHeaderCheck.valid(this.version)
      : valid = true,
        error = null;

  const GgufHeaderCheck.invalid(String this.error)
      : valid = false,
        version = -1;
}

/// 校验前 8 个字节。
///
/// 传入不足 8 字节时直接判为「文件过小/空文件」；做改名检测时，仅看 magic
/// 即可区分「JPEG/zip 改后缀」这类文件。
GgufHeaderCheck checkGgufHeader(List<int> bytes) {
  if (bytes.length < 8) {
    return const GgufHeaderCheck.invalid('文件过小（不足 8 字节），不是有效的 GGUF 文件');
  }
  const magic = [0x47, 0x47, 0x55, 0x46]; // "GGUF"
  for (var i = 0; i < 4; i++) {
    if (bytes[i] != magic[i]) {
      return const GgufHeaderCheck.invalid(
        '文件头不是 GGUF（很可能是改名的其它文件），请选择真正的 .gguf 模型',
      );
    }
  }
  final version = bytes[4] |
      (bytes[5] << 8) |
      (bytes[6] << 16) |
      (bytes[7] << 24);
  if (version < 1 || version > 3) {
    return GgufHeaderCheck.invalid('GGUF 版本 $version 不受支持（当前支持 v1–v3）');
  }
  return GgufHeaderCheck.valid(version);
}
