import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/tavo_brand.dart';
import '../common/app_dialogs.dart';

/// 允许鼠标/触控板拖拽翻页（Web 端 Flutter 默认禁用鼠标拖拽 PageView）
class _MouseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

/// Onboarding 引导页 — 精确还原官方 5 屏设计
class OnboardingPage extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingPage({super.key, required this.onFinished});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

// ── 数据模型：支持每屏的灵活布局 ──────────────────────────────────

class _ScreenData {
  // ── 顶部区域 ──

  /// 统计数字行（仅第 1 屏）
  final List<String>? statLines;
  final String? statSubtitle;

  /// 大标题行（支持 [紫]/[橙] 渐变标记，\n 换行）
  /// 例: "为AI角色扮演而生\n为[紫]Agent[橙]时代进化"
  final String? headline;

  // ── 封面图 ──
  final String? coverAsset;

  // ── 底部文字区 ──

  /// 说明文字（\n 换行，普通字重）
  final String? captionNormal;

  /// 说明文字（加粗，如 "还能触摸这个世界"）
  final String? captionBold;

  /// 副标题行（如 "- 敬请期待 -"）
  final String? subLabel;

  /// 署名（如 "Virtual 团队谨呈"）
  final String? attribution;

  /// 品牌标签（如 "只为今天带来"）
  final String? brandLabel;

  /// 品牌大标题（支持渐变标记）
  final String? brandTitle;

  /// 是否最后一屏（显示 CTA 按钮）
  final bool isLast;

  const _ScreenData({
    this.statLines,
    this.statSubtitle,
    this.headline,
    this.coverAsset,
    this.captionNormal,
    this.captionBold,
    this.subLabel,
    this.attribution,
    this.brandLabel,
    this.brandTitle,
    this.isLast = false,
  });
}

/// ── 5 屏数据 — 逐屏对照官方截图 ────────────────────────────────

const List<_ScreenData> _screens = [
  // ══════════════════════════════════════
  // 第 1 屏：里程碑（截图：世界地图+500天+Virtual 1.0）
  // ══════════════════════════════════════
  _ScreenData(
    statLines: ['500 天', '158 次发布'],
    statSubtitle: '平均每 3.2 天一次更新',
    coverAsset: 'assets/images/version_new_cover_1.png',
    brandLabel: '只为今天带来',
    brandTitle: 'Virtual 1.0',
  ),

  // ══════════════════════════════════════
  // 第 2 屏：使命（截图#1：为AI角色扮演而生 / Agent紫 / 聊天气泡封面）
  // ══════════════════════════════════════
  _ScreenData(
    headline: '为AI角色扮演而生\n为[紫]Agent[橙]时代进化',
    coverAsset: 'assets/images/version_new_cover_2_zh.png',
    captionNormal: 'Virtual 现在不仅仅是聊天',
    captionBold: '还能触摸这个世界',
  ),

  // ══════════════════════════════════════
  // 第 3 屏：插件中心（截图#2：玩法(紫)不再由 / Virtual独自定义 / 插件面板）
  // ══════════════════════════════════════
  _ScreenData(
    headline: '[紫]玩法不再由\nVirtual独自定义',
    coverAsset: 'assets/images/version_new_cover_3_zh.png',
    captionNormal: '有了插件中心',
    captionBold: 'Virtual 的可能，由你和社区一起定义',
  ),

  // ══════════════════════════════════════
  // 第 4 屏：路线图（截图#3：一切才刚刚开始 / SKILL云 / 敬请期待）
  // ══════════════════════════════════════
  _ScreenData(
    headline: '一切才\n刚刚开始',
    coverAsset: 'assets/images/version_new_cover_4_zh.png',
    subLabel: '- 敬请期待 -',
    captionNormal: '愿角色与你的世界相连',
    attribution: 'Virtual 团队谨呈',
    isLast: true,
  ),
];

// ── State ───────────────────────────────────────────────────────────

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _current = 0;

  bool get _isLast => _current == _screens.length - 1;

  void _next() {
    if (_current < _screens.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final settings = context.read<SettingsProvider>();
    final accepted = await showPrivacyDialog(context);
    if (!mounted) return;
    // 同意则进入主应用；拒绝则停留在引导页
    if (accepted) {
      settings.setOnboardingCompleted(true);
      settings.setPrivacyAccepted(true);
      widget.onFinished();
    }
  }

  // ── 解析带渐变标记的文本 ────────────────────────────────────────

  /// 将含 [紫]/[橙] 标记的字符串拆成 TextSpan 列表
  static List<TextSpan> _parseMarkedText(
    String raw, {
    double fontSize = 36,
    FontWeight fontWeight = FontWeight.w800,
    Color defaultColor = Colors.white,
  }) {
    const pTag = '[紫]';
    const oTag = '[橙]';
    if (!raw.contains(pTag) && !raw.contains(oTag)) {
      return [
        TextSpan(
          text: raw,
          style: TextStyle(
              color: defaultColor, fontSize: fontSize, fontWeight: fontWeight),
        ),
      ];
    }

    final spans = <TextSpan>[];
    final parts = raw.split(RegExp(r'\[紫\]|\[橙\]'));
    final tags =
        RegExp(r'\[紫\]|\[橙\]').allMatches(raw).map((m) => m.group(0)!).toList();

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      Color c = defaultColor;
      if (i > 0 && i - 1 < tags.length) {
        c = tags[i - 1] == pTag
            ? TavoColors.brandPurple
            : TavoColors.brandOrange;
      }
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(color: c, fontSize: fontSize, fontWeight: fontWeight),
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: _MouseScrollBehavior(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0A12), Color(0xFF1A1025), Color(0xFF0D0D18)],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── 顶部栏：跳过 ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildSkipButton(),
                    ],
                  ),
                ),

                // ── 可滑动内容 ──
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _screens.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (_, idx) => _buildScreenContent(_screens[idx]),
                  ),
                ),

                // ── 页面指示器（4 个点） ──
                _buildPageIndicator(),

                const SizedBox(height: 16),

                // ── CTA 按钮（仅最后一屏显示） ──
                if (_isLast) _buildCtaButton(),

                // 底部安全间距
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom > 0 ? 8 : 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 跳过按钮 ─────────────────────────────────────────────────────

  Widget _buildSkipButton() {
    return GestureDetector(
      onTap: _finish,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          '跳过',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── 页面指示器 ───────────────────────────────────────────────────

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_screens.length, (i) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            width: _current == i ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _current == i
                  ? Colors.white.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  // ── CTA 按钮："开启 Virtual 1.0 时代 >" ────────────────────────────

  Widget _buildCtaButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: _next,
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28))),
            padding: WidgetStatePropertyAll(
                const EdgeInsets.symmetric(horizontal: 24)),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return const Color(0xFF6A5DAE);
              }
              return const Color(0xFF7F77DD);
            }),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            elevation: const WidgetStatePropertyAll(0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '开启 Virtual 1.0 时代',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 20, color: Colors.white.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }

  // ── 单屏内容构建 ──────────────────────────────────────────────────

  Widget _buildScreenContent(_ScreenData d) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 统计数字（第 1 屏） ──
          if (d.statLines != null) ...[
            const SizedBox(height: 16),
            ...d.statLines!.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(line, style: _statStyle),
                )),
            if (d.statSubtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(d.statSubtitle!, style: _statSubStyle),
              ),
          ],

          // ── 大标题（第 2~4 屏） ──
          if (d.headline != null) ...[
            const SizedBox(height: 24),
            RichText(
              text: TextSpan(
                style: const TextStyle(height: 1.2),
                children: _parseMarkedText(d.headline!),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // ── 封面图 ──
          if (d.coverAsset != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                d.coverAsset!,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
            )
          else
            Image.asset(
              'assets/images/app_logo.png',
              width: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => TavoBrand.logo(size: 160),
            ),

          const SizedBox(height: 32),

          // ── 副标签（"- 敬请期待 -"） ──
          if (d.subLabel != null)
            Center(
              child: Text(
                d.subLabel!,
                style: TextStyle(
                  color: TavoColors.brandPurple.withValues(alpha: 0.6),
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          if (d.subLabel != null) const SizedBox(height: 16),

          // ── 普通说明文字 ──
          if (d.captionNormal != null)
            Text(d.captionNormal!,
                style: _captionNormalStyle, textAlign: TextAlign.left),

          // ── 加粗说明文字 ──
          if (d.captionBold != null) ...[
            const SizedBox(height: 6),
            Text(d.captionBold!,
                style: _captionBoldStyle, textAlign: TextAlign.left),
          ],

          // ── 署名 ──
          if (d.attribution != null) ...[
            const SizedBox(height: 10),
            Text(d.attribution!, style: _attrStyle, textAlign: TextAlign.left),
          ],

          // ── 品牌区（第 1 屏） ──
          if (d.brandLabel != null) ...[
            const SizedBox(height: 28),
            Text(d.brandLabel!, style: _brandLabelStyle),
            const SizedBox(height: 10),
            if (d.brandTitle != null)
              RichText(
                textAlign: TextAlign.left,
                text: TextSpan(
                  style: const TextStyle(height: 1.15),
                  children: _parseMarkedText(
                    d.brandTitle!,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── 占位图 ───────────────────────────────────────────────────────

  Widget _placeholder() {
    return Container(
      width: 260,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.image_outlined,
          size: 56, color: Colors.white.withValues(alpha: 0.2)),
    );
  }

  // ── 文字样式常量 ─────────────────────────────────────────────────

  static final TextStyle _statStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.92),
    fontSize: 42,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static final TextStyle _statSubStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.45),
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
  );

  static final TextStyle _captionNormalStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.55),
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle _captionBoldStyle = TextStyle(
    color: Colors.white,
    fontSize: 17,
    height: 1.5,
    fontWeight: FontWeight.w700,
  );

  static final TextStyle _attrStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.4),
    fontSize: 13,
    height: 1.5,
  );

  static final TextStyle _brandLabelStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.5),
    fontSize: 14,
    letterSpacing: 1,
    fontWeight: FontWeight.w400,
  );
}
