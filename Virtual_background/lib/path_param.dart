/// 解码 dart_frog 捕获到的路径参数。
///
/// 背景（2026-09-11 实测定位）：dart_frog 用 `request.url.path` 去匹配路由并捕获
/// `[param]`（见 dart_frog `router.dart` 的 `Invocation.match`），**全程不做解码**。
/// 而 Dart 的 `Uri.path` 只对 **ASCII 安全字符**的转义做归一化解码：
///
/// - `%63har-001` → `char-001`（`%63` 是 `c`，被归一化）→ 能命中
/// - `%E5%B8%8C%E9%9C%B2%E5%A6%B2` → **保留百分号编码**（非 ASCII 不归一化）
///
/// 于是对含汉字的 id（`slugify` 故意保留 `\u4e00-\u9fff`），捕获到的参数是字面量
/// `%E5%B8%8C…`，与库中的 `希露妲` 不相等 → 详情/导出端点恒返 404。
///
/// 这里统一补一次解码。非法转义（客户端手写畸形 `%`）时**退回原串**而不是抛错，
/// 避免畸形请求把路由打成 500。
String decodePathParam(String raw) {
  try {
    return Uri.decodeComponent(raw);
  } catch (_) {
    return raw;
  }
}
