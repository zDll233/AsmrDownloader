import 'package:asmr_downloader/pages/components/empty_state.dart';
import 'package:asmr_downloader/pages/components/failure_panel.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_cv.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_misc_info.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_tags.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_circle_name.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_cover.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_title.dart';
import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkInfo extends ConsumerWidget {
  const WorkInfo({super.key, this.horizontalPadding = 20.0});
  final double horizontalPadding;

  static const _verticalPadding = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appWidth = MediaQuery.of(context).size.width;
    final workInfoLoadingState = ref.watch(workInfoLoadingStateProvider);
    final phase = ref.watch(searchPhaseProvider);
    final failure = ref.watch(failureProvider);
    return SizedBox(
      width: appWidth * 0.4,
      child: Padding(
        padding:
            EdgeInsets.only(left: horizontalPadding, right: horizontalPadding),
        child: workInfoLoadingState.when(
          data: (data) {
            if (data == null) {
              if (failure != null &&
                  failure.kind != SearchFailureKind.emptyResult) {
                return FailurePanel(failure: failure);
              }
              if (phase == SearchPhase.idle) {
                return const EmptyState(
                  icon: Icons.search,
                  text: '输入 sourceId 开始搜索',
                );
              }
              return const EmptyState(
                icon: Icons.album_outlined,
                text: 'No work info',
              );
            }
          return ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AsmrCover(),
                  AsmrTitle(verticalPadding: _verticalPadding),
                  AsmrCircleName(verticalPadding: _verticalPadding),
                  AsmrMiscInfo(verticalPadding: _verticalPadding),
                  AsmrTags(verticalPadding: _verticalPadding),
                  AsmrCv(verticalPadding: _verticalPadding),
                ],
              ),
            ),
          );
          },
          loading: () => Center(
            child: ref.watch(searchLoadingProvider)
                ? const CircularProgressIndicator()
                : const SizedBox.shrink(),
          ),
          error: (error, stack) => FailurePanel(
            failure: error is SearchFailureException
                ? error.failure
                : SearchFailure.of(error, stage: SearchStage.workInfo),
          ),
        ),
      ),
    );
  }
}
