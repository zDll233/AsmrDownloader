import 'package:asmr_downloader/pages/components/empty_state.dart';
import 'package:asmr_downloader/pages/downloader/search_result/tracks_view/components/download_progress/download_progress.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/pages/downloader/search_result/tracks_view/components/tracks.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TracksView extends ConsumerWidget {
  const TracksView({super.key, this.horizontalPadding = 20.0});
  final double horizontalPadding;

  static const _tracksLPadding = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appWidth = MediaQuery.of(context).size.width;
    final tracksLoadingState = ref.watch(tracksLoadingStateProvider);
    return SizedBox(
      width: appWidth * 0.6,
      child: Padding(
        padding: EdgeInsets.only(right: horizontalPadding, bottom: 10.0),
        child: tracksLoadingState.when(
        data: (_) {
          final rootFolder = ref.read(rootFolderProvider);
          if (ref.read(workInfoLoadingStateProvider).value == null ||
              rootFolder == null) {
            return const EmptyState(
              icon: Icons.playlist_play,
              text: 'No tracks',
            );
          }

          return Column(
            children: [
              DownloadProgress(tracksLPadding: _tracksLPadding),
              Expanded(
                child: Tracks(
                  rootFolder: rootFolder,
                  tracksLPadding: _tracksLPadding,
                ),
              ),
            ],
          );
        },
        loading: () => Center(child: const CircularProgressIndicator()),
        error: (error, stack) => Text('Error: $error'),
      ),
      ),
    );
  }
}
