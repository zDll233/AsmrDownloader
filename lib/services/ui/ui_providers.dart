import 'package:asmr_downloader/services/asmr_repo/providers/tracks_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/work_info_providers.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/selection_reader.dart';
import 'package:asmr_downloader/services/ui/ui_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
final uiServiceProvider = Provider((ref) => UIService(ref));

/// 读取"当前选中文本" (用户主动点"粘贴并搜索"时用)。
///
/// 入参是调用方那一刻的前台窗口句柄; 测试里可以替换成假实现。
final selectedTextReaderProvider = Provider<SelectedTextReader>(
  (ref) => (windowHandle) => readSelectedText(windowHandle: windowHandle),
);


/// 依次合并两个异步状态: 已落定的错误优先, 其次传播加载中, 最后取数据。
///
/// 注意"刷新中的旧错误"不能算错误: `invalidate` 触发的重算里, Riverpod
/// 会把上一次的错误带进新的 state (`AsyncError(isLoading: true)`), 而
/// `when` 默认 `skipLoadingOnRefresh: true` 会跳过 loading、直接渲染旧
/// error。若把它当错误, 重新搜索时面板就会一直停在旧提示上, 看不到转圈。
/// 所以只有 `!isLoading` 的错误才向下传播。
///
/// 已经落定的错误仍然优先于另一个正在加载的状态 (之前"上游返回 data(null)
/// 时错误丢失"的问题由下面的错误分支兜住)。
AsyncValue combineStates(AsyncValue asyncValue1, AsyncValue asyncValue2) {
  final error1 = asyncValue1.hasError && !asyncValue1.isLoading;
  final error2 = asyncValue2.hasError && !asyncValue2.isLoading;
  if (error1) return asyncValue1;
  if (error2) return asyncValue2;

  if (asyncValue1.isLoading ||
      asyncValue2.isLoading ||
      asyncValue1.isRefreshing ||
      asyncValue2.isRefreshing) {
    return const AsyncLoading();
  }
  return asyncValue2.hasValue ? asyncValue2 : asyncValue1;
}

final workInfoLoadingStateProvider = Provider<AsyncValue>(
  (ref) => combineStates(
    ref.watch(searchResultProvider),
    ref.watch(workInfoProvider),
  ),
);

final tracksLoadingStateProvider = Provider<AsyncValue>(
  (ref) => combineStates(
    ref.watch(workInfoLoadingStateProvider),
    ref.watch(rawTracksProvider),
  ),
);

final coverLoadingStateProvider = Provider<AsyncValue>(
  (ref) => combineStates(
    ref.watch(workInfoLoadingStateProvider),
    ref.watch(coverBytesProvider),
  ),
);
