import 'package:flutter/material.dart';

/// 设置页分区标题。
class SettingsSectionTitle extends StatelessWidget {
  final String title;

  const SettingsSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }
}

/// 设置卡片容器 (圆角 + 子项间分隔线)。
class SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 小号"恢复默认"按钮。
class SettingsResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SettingsResetButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_backup_restore, size: 18),
      tooltip: '恢复默认',
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

/// 颜色圆点。
class SettingsColorSwatch extends StatelessWidget {
  final Color color;

  const SettingsColorSwatch({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
