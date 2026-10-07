import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/pages/components/empty_state.dart';
import 'package:asmr_downloader/pages/components/failure_panel.dart';
import 'package:asmr_downloader/pages/downloader/search_result/tracks_view/components/download_progress/download_progress.dart';
import 'package:asmr_downloader/pages/downloader/search_result/tracks_view/components/extension_filter_bar.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/tracks_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
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
    final showExtFilter = ref.watch(showExtFilterProvider).valueOrNull ?? true;
    final phase = ref.watch(searchPhaseProvider);
    final failure = ref.watch(failureProvider);
    return SizedBox(
      width: appWidth * 0.6,
      child: Padding(
        padding: EdgeInsets.only(right: horizontalPadding, bottom: 10.0),
        child: tracksLoadingState.when(
        data: (_) {
          final rootFolder = ref.read(rootFolderProvider);
          if (ref.read(workInfoLoadingStateProvider).value == null ||
              rootFolder == null) {
            // 作品信息失败时左栏已经显示了原因, 这里不重复。
            final shownOnLeft = failure != null &&
                failure.stage != SearchStage.tracks &&
                failure.kind != SearchFailureKind.emptyResult;
            if (shownOnLeft) {
              return const EmptyState(
                icon: Icons.playlist_play,
                text: '作品信息获取失败，文件列表不可用',
              );
            }
            if (failure != null &&
                failure.kind != SearchFailureKind.emptyResult) {
              return FailurePanel(failure: failure);
            }
            if (phase == SearchPhase.idle) {
              return const EmptyState(
                icon: Icons.playlist_play,
                text: '搜索后在这里选择要下载的文件',
              );
            }
            // 作品存在但服务器没有返回任何文件。
            final tracksEmpty =
                ref.read(rawTracksProvider).value?.isEmpty ?? false;
            return EmptyState(
              icon: Icons.playlist_play,
              text: tracksEmpty ? '该作品没有音声文件' : 'No tracks',
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DownloadProgress(tracksLPadding: _tracksLPadding),
              if (showExtFilter) const ExtensionFilterBar(),
              Expanded(
                child: Tracks(
                  rootFolder: rootFolder,
                  tracksLPadding: _tracksLPadding,
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: ref.watch(searchLoadingProvider)
              ? const CircularProgressIndicator()
              : const SizedBox.shrink(),
        ),
        error: (error, stack) {
          // 音频文件依赖作品信息: 左栏已经显示原因的话这里不重复。
          final failedOnLeft = failure != null &&
              failure.stage != SearchStage.tracks &&
              failure.kind != SearchFailureKind.emptyResult;
          if (failedOnLeft) {
            return const EmptyState(
              icon: Icons.playlist_play,
              text: '作品信息获取失败，文件列表不可用',
            );
          }
          return FailurePanel(
            failure: error is SearchFailureException
                ? error.failure
                : SearchFailure.of(error, stage: SearchStage.tracks),
          );
        },
      ),
      ),
    );
  }
}
