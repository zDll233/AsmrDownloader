import 'package:asmr_downloader/pages/components/empty_state.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_cv.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_misc_info.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_tags.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_circle_name.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_cover.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/components/asmr_title.dart';
import 'package:asmr_downloader/pages/window_title_bar/move_window.dart';
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
    return SizedBox(
      width: appWidth * 0.4,
      child: Padding(
        padding:
            EdgeInsets.only(left: horizontalPadding, right: horizontalPadding),
        child: workInfoLoadingState.when(
          data: (data) {
            if (data == null) {
              return const EmptyState(
                icon: Icons.album_outlined,
                text: 'No work info',
              );
            }
            return MoveWindow(
              moveOnChildWidget: true,
              child: ScrollConfiguration(
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
              ),
            );
          },
          loading: () => Center(child: const CircularProgressIndicator()),
          error: (error, stack) => Text('Error: $error'),
        ),
      ),
    );
  }
}
