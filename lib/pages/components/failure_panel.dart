import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
import 'package:flutter/material.dart';

/// 失败提示: 与 [EmptyState] 完全一致的居中排版 (图标 + 文案),
/// 只说清楚问题出在哪, 不带任何操作。
///
/// 技术详情写进日志 (exe 同级 `debug/asmr_downloader.log`),
/// 需要时可调用 [showFailureDetail] 弹窗查看。
class FailurePanel extends StatelessWidget {
  const FailurePanel({
    super.key,
    required this.failure,
    this.icon,
  });

  final SearchFailure failure;

  /// 自定义图标; 默认按失败类型选择。
  final IconData? icon;

  /// 与 [EmptyState] 共用的排版尺寸 (两边保持完全一致)。
  static const double iconSize = 42;
  static const double gapAfterIcon = 10;
  static const double titleFontSize = 14;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? iconOf(failure.kind),
            size: iconSize,
            color: scheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: gapAfterIcon),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              failure.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleFontSize,
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹出技术详情 (可选中复制)。
void showFailureDetail(BuildContext context, SearchFailure failure) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('技术详情'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: SelectableText(
            '${failure.title}\n\n${failure.technicalDetail}',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 失败类型对应的图标。
IconData iconOf(SearchFailureKind kind) => switch (kind) {
      SearchFailureKind.invalidInput => Icons.search,
      SearchFailureKind.emptyResult => Icons.library_books_outlined,
      SearchFailureKind.noNetwork => Icons.wifi_off,
      SearchFailureKind.timeout => Icons.hourglass_empty,
      SearchFailureKind.proxyFailed => Icons.lan_outlined,
      SearchFailureKind.badCertificate => Icons.gpp_maybe_outlined,
      SearchFailureKind.badData => Icons.help_outline,
      SearchFailureKind.unknown => Icons.error_outline,
      _ => Icons.cloud_off,
    };
