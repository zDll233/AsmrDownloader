import 'package:asmr_downloader/models/track_item.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadButton extends ConsumerWidget {
  const DownloadButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloading =
        ref.watch(dlStatusProvider) == DownloadStatus.downloading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: ShapeDecoration(
        color: downloading ? Colors.grey : Colors.pink[200],
        shape: const StadiumBorder(),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: downloading ? null : ref.read(downloadManagerProvider).run,
          splashColor: Colors.pinkAccent.withValues(alpha: 0.3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            alignment: Alignment.center,
            child: Text(
              downloading ? '下载中' : '下载',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}
