import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transparent_image/transparent_image.dart';

class AsmrCover extends ConsumerWidget {
  const AsmrCover({super.key});

  static const _radius = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverLoadingState = ref.watch(coverLoadingStateProvider);
    return coverLoadingState.when(
      data: (bytes) {
        if (bytes == null) {
          return const Icon(Icons.error, color: Colors.red);
        }
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: FadeInImage(
              placeholder: MemoryImage(kTransparentImage),
              image: MemoryImage(bytes)),
        );
      },
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.0),
      ),
      error: (error, stack) {
        Log.error('load cover image failed\n'
            'sourceId: ${ref.read(sourceIdProvider)}\n'
            'error: ');
        return const Icon(Icons.error, color: Colors.red);
      },
    );
  }
}
