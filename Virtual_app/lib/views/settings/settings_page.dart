import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/metadata_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          _buildSection(context, '后端', [
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => ListTile(
                title: const Text('后端地址'),
                subtitle: Text(settings.backendBaseUrl),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBackendUrlDialog(context, settings),
              ),
            ),
          ]),
          _buildSection(context, '外观', [
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => ListTile(
                title: const Text('主题模式'),
                subtitle: Text(_themeModeText(settings.themeMode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeModeDialog(context, settings),
              ),
            ),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => ListTile(
                title: const Text('主题色'),
                subtitle: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Color(settings.primaryColorLight),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Color(settings.primaryColorDark),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/theme'),
              ),
            ),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => ListTile(
                title: const Text('语言'),
                subtitle: Text(_localeText(settings.locale)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(context, settings),
              ),
            ),
          ]),
          _buildSection(context, '聊天', [
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => ListTile(
                title: const Text('气泡样式'),
                subtitle:
                    Text(settings.bubbleStyle == 'bubble' ? '气泡模式' : '平板模式'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBubbleStyleDialog(context, settings),
              ),
            ),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => ListTile(
                title: const Text('列表模式'),
                subtitle:
                    Text(settings.listMode == 'message' ? '消息模式' : '视觉模式'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showListModeDialog(context, settings),
              ),
            ),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => SwitchListTile(
                title: const Text('显示推理过程'),
                value: settings.showReasoning,
                onChanged: (v) => settings.setShowReasoning(v),
              ),
            ),
          ]),
          _buildSection(context, '语音', [
            Consumer<SettingsProvider>(
              builder: (context, settings, _) => SwitchListTile(
                title: const Text('自动播放 TTS'),
                subtitle: const Text('收到消息后自动朗读'),
                value: settings.autoPlayTts,
                onChanged: (v) => settings.setAutoPlayTts(v),
              ),
            ),
            ListTile(
              title: const Text('TTS 引擎'),
              subtitle: const Text('系统 TTS'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/tts'),
            ),
            ListTile(
              title: const Text('语音识别'),
              subtitle: const Text('系统语音识别'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/asr'),
            ),
          ]),
          _buildSection(context, '工具', [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('网络搜索'),
              subtitle: const Text('Tavily API'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/web-search'),
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('图像生成'),
              subtitle: const Text('OpenAI / Gemini / NovelAI'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/image-gen'),
            ),
          ]),
          _buildSection(context, '数据', [
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('数据备份与恢复'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/backup'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('数据迁移'),
              subtitle: const Text('跨设备迁移角色与聊天记录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/backup'),
            ),
          ]),
          _buildSection(context, '扩展', [
            ListTile(
              leading: const Icon(Icons.extension_outlined),
              title: const Text('插件管理'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/plugins'),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('调试'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/debug'),
            ),
          ]),
          _buildSection(context, '关于', [
            Consumer<MetadataProvider>(
              builder: (context, metadata, _) {
                final uris = metadata.uris;
                return Column(
                  children: [
                    ListTile(
                      title: const Text('版本'),
                      trailing: const Text('1.0.0'),
                    ),
                    if (uris != null) ...[
                      ListTile(
                        leading: const Icon(Icons.home_outlined),
                        title: const Text('官方网站'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _openUrl(uris.homepage),
                      ),
                      ListTile(
                        leading: const Icon(Icons.help_outline),
                        title: const Text('帮助文档'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _openUrl(uris.help),
                      ),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined),
                        title: const Text('隐私政策'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _openUrl(uris.privacyPolicy),
                      ),
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: const Text('服务条款'),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => _openUrl(uris.termsOfService),
                      ),
                      ListTile(
                        leading: const Icon(Icons.mail_outline),
                        title: const Text('联系客服'),
                        subtitle: Text(uris.customerServiceEmail),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () async {
                          final email = Uri(
                            scheme: 'mailto',
                            path: uris.customerServiceEmail,
                          );
                          if (await canLaunchUrl(email)) {
                            await launchUrl(email);
                          }
                        },
                      ),
                      for (final entry in metadata.socials.entries)
                        ListTile(
                          leading: const Icon(Icons.link),
                          title: Text(_socialTitle(entry.key)),
                          subtitle: Text(entry.value.url),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => _openUrl(entry.value.url),
                        ),
                    ],
                  ],
                );
              },
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _socialTitle(String key) {
    switch (key) {
      case 'discord':
        return 'Discord 社区';
      case 'reddit':
        return 'Reddit';
      default:
        return key;
    }
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: children),
        ),
      ],
    );
  }

  String _themeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
      case ThemeMode.system:
        return '跟随系统';
    }
  }

  String _localeText(Locale? locale) {
    if (locale == null) return '跟随系统';
    switch ('${locale.languageCode}_${locale.countryCode}') {
      case 'zh_CN':
        return '简体中文';
      case 'en_US':
        return 'English';
      case 'ja_JP':
        return '日本語';
      default:
        return locale.toString();
    }
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('语言'),
        children: [
          RadioGroup<Locale?>(
            groupValue: settings.locale,
            onChanged: (value) {
              settings.setLocale(value);
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RadioListTile<Locale?>(
                  title: Text('跟随系统'),
                  value: null,
                ),
                for (final entry in const [
                  ('zh', 'CN', '简体中文'),
                  ('en', 'US', 'English'),
                  ('ja', 'JP', '日本語'),
                ])
                  RadioListTile<Locale?>(
                    title: Text(entry.$3),
                    value: Locale(entry.$1, entry.$2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('主题模式'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (value) {
              if (value != null) settings.setThemeMode(value);
              Navigator.pop(context);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    title: Text(_themeModeText(mode)),
                    value: mode,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBubbleStyleDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('气泡样式'),
        children: [
          RadioGroup<String>(
            groupValue: settings.bubbleStyle,
            onChanged: (value) {
              if (value != null) settings.setBubbleStyle(value);
              Navigator.pop(context);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text('气泡模式'),
                  value: 'bubble',
                ),
                RadioListTile<String>(
                  title: Text('平板模式'),
                  value: 'flat',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showListModeDialog(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('列表模式'),
        children: [
          RadioGroup<String>(
            groupValue: settings.listMode,
            onChanged: (value) {
              if (value != null) settings.setListMode(value);
              Navigator.pop(context);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text('消息模式'),
                  value: 'message',
                ),
                RadioListTile<String>(
                  title: Text('视觉模式'),
                  value: 'visual',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBackendUrlDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.backendBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('后端地址'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://localhost:8080',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        actions: [
          TextButton(
            onPressed: () {
              settings.setBackendBaseUrl('http://localhost:8080');
              Navigator.pop(ctx);
            },
            child: const Text('重置'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              settings.setBackendBaseUrl(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
