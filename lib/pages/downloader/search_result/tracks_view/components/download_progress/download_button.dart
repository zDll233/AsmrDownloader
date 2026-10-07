import 'package:asmr_downloader/models/track_item.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadButton extends ConsumerWidget {
  const DownloadButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloading =
        ref.watch(dlStatusProvider) == DownloadStatus.downloading;
    // 搜索失败 / 还没有作品信息时不能开始下载。
    final hasWork = ref.watch(sourceIdProvider) != null &&
        ref.watch(workInfoLoadingStateProvider).value != null;
    final disabled = downloading || !hasWork;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: disabled ? Colors.grey : Colors.pink[200],
        shape: const StadiumBorder(),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: disabled ? null : ref.read(downloadManagerProvider).run,
          splashColor: Colors.pinkAccent.withValues(alpha: 0.3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            alignment: Alignment.center,
            child: Transform.translate(
              offset: const Offset(0, -1.5),
              child: Text(
                downloading ? '下载中' : '下载',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
