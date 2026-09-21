import 'package:flutter/material.dart';

import '../../theme/tavo_brand.dart';

/// 法律文档类型
enum LegalDocType {
  userAgreement('用户协议', 'assets/legal/user_agreement.md'),
  privacyPolicy('隐私政策', 'assets/legal/privacy_policy.md'),
  productTerms('产品服务协议', 'assets/legal/product_terms.md');

  final String title;
  final String assetPath;
  const LegalDocType(this.title, this.assetPath);
}

/// 全屏阅读法律条款（注册勾选后的链接目标）
class LegalDocPage extends StatelessWidget {
  final LegalDocType doc;

  const LegalDocPage({super.key, required this.doc});

  static Future<void> open(BuildContext context, LegalDocType doc) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocPage(doc: doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: FutureBuilder<String>(
        // 用 DefaultAssetBundle 便于测试；失败时给本地兜底摘要
        future: DefaultAssetBundle.of(context).loadString(doc.assetPath),
        builder: (context, snap) {
          final text = snap.data ?? _fallback(doc);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: SelectableText(
              text,
              style: const TextStyle(fontSize: 13.5, height: 1.65),
            ),
          );
        },
      ),
    );
  }

  static String _fallback(LegalDocType doc) {
    switch (doc) {
      case LegalDocType.userAgreement:
        return '使用 Virtual 即表示您同意遵守用户协议：合法使用、尊重知识产权、'
            '理解 AI 输出为虚构演绎，并自行保管账号与 API 密钥。'
            '完整文本见官网 docs/legal/user_agreement.md。';
      case LegalDocType.privacyPolicy:
        return 'Virtual 本地优先：对话与角色卡默认保存在设备本地。'
            '注册社区时我们会处理邮箱与昵称；发动态定位仅在您主动授权后使用。'
            '我们不会出售个人信息。完整文本见 docs/legal/privacy_policy.md。';
      case LegalDocType.productTerms:
        return '产品服务协议说明功能范围、模型 BYOK、自托管后端、社区规则与位置服务等。'
            '完整文本见 docs/legal/product_terms.md。';
    }
  }
}

/// 注册/登录页协议勾选行：□ 我已阅读并同意 用户协议、隐私政策、产品服务协议
class LegalAgreementRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool dense;

  const LegalAgreementRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '我已阅读并同意 ',
                style: TextStyle(
                  fontSize: dense ? 12.5 : 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              _link(context, LegalDocType.userAgreement),
              Text('、',
                  style: TextStyle(
                      fontSize: dense ? 12.5 : 13,
                      color: scheme.onSurfaceVariant)),
              _link(context, LegalDocType.privacyPolicy),
              Text('、',
                  style: TextStyle(
                      fontSize: dense ? 12.5 : 13,
                      color: scheme.onSurfaceVariant)),
              _link(context, LegalDocType.productTerms),
            ],
          ),
        ),
      ],
    );
  }

  Widget _link(BuildContext context, LegalDocType doc) {
    return GestureDetector(
      onTap: () => LegalDocPage.open(context, doc),
      child: Text(
        doc.title,
        style: TextStyle(
          fontSize: dense ? 12.5 : 13,
          color: TavoColors.brandPurple,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: TavoColors.brandPurple.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
