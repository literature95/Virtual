/// 多选状态（纯逻辑，便于单元测试）
///
/// 只保存被选中的条目 id，不关心业务数据类型；页面在 setState 中
/// 用 [toggle] / [selectAll] / [clear] 返回的新实例替换旧状态。
class MultiSelectState {
  /// 当前选中的 id 集合（只读语义，调用方不要直接修改）
  final Set<String> selected;

  const MultiSelectState([this.selected = const {}]);

  /// 已选数量
  int get count => selected.length;

  /// 是否为空（无任何选中）
  bool get isEmpty => selected.isEmpty;

  bool contains(String id) => selected.contains(id);

  /// 切换某条目的选中状态
  MultiSelectState toggle(String id) {
    final next = Set<String>.from(selected);
    if (!next.remove(id)) next.add(id);
    return MultiSelectState(next);
  }

  /// 全选：并入给定 id 集合（已选中的保持）
  MultiSelectState selectAll(Iterable<String> ids) {
    return MultiSelectState({...selected, ...ids});
  }

  /// 清空
  MultiSelectState clear() => const MultiSelectState();
}
