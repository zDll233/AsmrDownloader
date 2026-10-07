import 'package:asmr_downloader/pages/components/failure_panel.dart';
import 'package:flutter/material.dart';

/// 空状态占位 (图标 + 文案, 克制配色)。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.detailLines = const [],
  });

  final IconData icon;
  final String text;

  /// 补充说明 (逐行小字)。
  final List<String> detailLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: FailurePanel.iconSize,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: FailurePanel.gapAfterIcon),
          Text(
            text,
            style: TextStyle(
              fontSize: FailurePanel.titleFontSize,
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          for (final line in detailLines) ...[
            const SizedBox(height: 4),
            Text(
              line,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
