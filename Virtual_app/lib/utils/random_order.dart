import 'dart:math';

/// 返回 [items] 的随机重排副本（不修改入参）。
///
/// 发现页只在**下拉刷新**时调用它：进入页面保持后端顺序，
/// 避免用户翻到一半时列表突然重排、或每次进屋都换一批。
/// [random] 可注入固定种子，便于单元测试断言。
List<T> shuffledOrder<T>(List<T> items, [Random? random]) {
  final copy = List<T>.of(items);
  copy.shuffle(random ?? Random());
  return copy;
}
