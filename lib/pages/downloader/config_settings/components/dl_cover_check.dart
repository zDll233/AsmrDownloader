import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DlCoverCheck extends ConsumerWidget {
  const DlCoverCheck({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dlCover = ref.watch(dlCoverProvider);
    return Row(
      children: [
        const Text('下载封面'),
        Checkbox(
          value: dlCover,
          onChanged: ref.read(uiServiceProvider).onDlCoverChanged,
        ),
      ],
    );
  }
}
