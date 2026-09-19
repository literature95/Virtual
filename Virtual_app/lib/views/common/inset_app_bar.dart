import 'package:flutter/material.dart';

/// 自带状态栏避让的 AppBar（供 shell 隐藏顶栏后的页面使用）。
///
/// `HomeShell` 用零高 AppBar 藏壳层顶栏时，body 的 `MediaQuery.padding.top`
/// 会被清成 0，页面内层普通 AppBar 会从 y=0 起画、压进状态栏。
/// 这里改读**不会被 removePadding 清掉的** `viewPadding.top`，把工具栏
/// 下推状态栏高度；`transparent=true` 时状态栏区域留给页面全屏背景
/// （对话背景铺到状态栏后面），工具栏本身仍避开状态栏。
class InsetAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool? centerTitle;

  /// true：状态栏+工具栏区域透明，供全屏背景透出（顶栏内容仍下推）。
  /// false：状态栏条与工具栏同色，观感对齐首页 AppBar。
  final bool transparent;
  final Color? backgroundColor;

  const InsetAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.transparent = false,
    this.backgroundColor,
  });

  /// 状态栏高度。
  ///
  /// 🔴 不能只信 `MediaQuery.of(context)`：`Scaffold` 只要挂了 `appBar`
  /// （壳层隐藏顶栏时用的是 0 高 `PreferredSize`），body 里的
  /// `removePadding(removeTop: true)` 会把 **`padding.top` 与
  /// `viewPadding.top` 一并清成 0**（viewPadding.top = max(0, viewPadding.top - padding.top)）。
  /// 因此页面自避让必须以**窗口/平台指标**为准，MediaQuery 仅作回退。
  static double statusBarTopFromWindow() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return 0;
    final data = MediaQueryData.fromView(views.first);
    final top = data.viewPadding.top > 0 ? data.viewPadding.top : data.padding.top;
    return top;
  }

  static double statusBarTop(BuildContext context) {
    final fromWindow = statusBarTopFromWindow();
    if (fromWindow > 0) return fromWindow;
    final data = MediaQuery.of(context);
    final top = data.viewPadding.top;
    if (top > 0) return top;
    return data.padding.top;
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(statusBarTopFromWindow() + kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final top = statusBarTop(context);
    final theme = Theme.of(context);
    final Color barColor;
    if (transparent) {
      barColor = Colors.transparent;
    } else {
      barColor = backgroundColor ??
          theme.appBarTheme.backgroundColor ??
          theme.colorScheme.surface;
    }

    return Material(
      color: barColor,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: AppBar(
          primary: false,
          automaticallyImplyLeading: false,
          leading: leading,
          title: title,
          actions: actions,
          centerTitle: centerTitle ?? theme.appBarTheme.centerTitle,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
    );
  }
}
