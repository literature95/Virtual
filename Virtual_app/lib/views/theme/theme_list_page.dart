import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';

class ThemeListPage extends StatelessWidget {
  const ThemeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主题选择'),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _buildSection(context, '预设主题', kPresetThemes, settings),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<PresetTheme> themes,
    SettingsProvider settings,
  ) {
    final currentSeedLight = settings.primaryColorLight;

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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: themes.length,
          itemBuilder: (context, index) {
            final theme = themes[index];
            final isSelected = currentSeedLight == theme.lightSeed.toARGB32();

            return _ThemeCard(
              theme: theme,
              isSelected: isSelected,
              onTap: () {
                settings.setPrimaryColor(theme.lightSeed, theme.darkSeed);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已应用「${theme.name}」主题'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final PresetTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: bgColor,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.previewColor.withValues(alpha: 0.15),
                    theme.previewColor.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.previewColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(theme.id),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      theme.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String id) {
    switch (id) {
      case 'sakura':
        return Icons.local_florist;
      case 'ocean':
        return Icons.waves;
      case 'forest':
        return Icons.forest;
      case 'sunset':
        return Icons.wb_sunny;
      case 'purple_night':
        return Icons.nights_stay;
      case 'midnight':
        return Icons.dark_mode;
      case 'default_dark':
        return Icons.contrast;
      default:
        return Icons.brightness_7;
    }
  }
}
