import 'package:asmr_downloader/pages/components/empty_state.dart';
import 'package:asmr_downloader/pages/components/failure_panel.dart';
import 'package:asmr_downloader/pages/downloader/search_result/tracks_view/tracks_view.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/work_info.dart';
import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchResult extends ConsumerWidget {
  const SearchResult({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = ref.watch(failureProvider);
    final phase = ref.watch(searchPhaseProvider);
    final loading = ref.watch(searchLoadingProvider);

    // 输入不合法, 或搜索本身失败 (还没有作品): 整块显示原因。
    // "没有搜到结果"不是错误, 走下面的空状态文案。
    final wholeAreaFailure = phase == SearchPhase.invalidInput ||
        (failure != null &&
            failure.stage == SearchStage.search &&
            failure.kind != SearchFailureKind.emptyResult);

    final Widget content;
    if (loading && failure == null) {
      // 重新搜索时先回到加载状态, 不要停在失败提示上。
      content = const Center(child: CircularProgressIndicator());
    } else if (wholeAreaFailure) {
      content = FailurePanel(
        failure: failure ??
            SearchFailure.invalidInput(ref.read(searchTextProvider) ?? ''),
      );
    } else if (failure?.kind == SearchFailureKind.emptyResult) {
      content = const EmptyState(
        icon: Icons.library_books_outlined,
        text: '没有搜索到匹配的作品',
      );
    } else if (phase == SearchPhase.idle) {
      content = const EmptyState(
        icon: Icons.search,
        text: '输入 sourceId 开始搜索',
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左: 作品信息 (40%)
          Expanded(
            flex: 2,
            child: WorkInfo(horizontalPadding: 0),
          ),
          // 中间间距
          const SizedBox(width: 20),
          // 右: 音轨文件树 (60%)
          Expanded(
            flex: 3,
            child: TracksView(horizontalPadding: 0),
          ),
        ],
      );
    }

    return Expanded(
      child: Padding(
        // 左右边界间距
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: content,
      ),
    );
  }
}
