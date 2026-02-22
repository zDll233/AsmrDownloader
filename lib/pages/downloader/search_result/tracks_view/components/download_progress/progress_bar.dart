import 'package:asmr_downloader/pages/components/middle_ellipsis_text.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressBar extends ConsumerWidget {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appWidth = MediaQuery.of(context).size.width;
    final process = ref.watch(processProvider);
    final currentFileName = ref.watch(currentFileNameProvider);
    return SizedBox(
      width: appWidth * 0.35,
      child: Stack(children: [
        LinearProgressIndicator(
          minHeight: 30,
          borderRadius: BorderRadius.circular(10),
          value: process,
        ),
        Positioned.fill(
          left: 10,
          right: 10,
          bottom: 1,
          child: Row(children: ellipsisInMiddle(currentFileName)),
        ),
      ]),
    );
  }
}
