import 'package:asmr_downloader/services/asmr_repo/providers/tracks_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/work_info_providers.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/ui_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final uiServiceProvider = Provider((ref) => UIService(ref));

/// 依次合并两个异步状态: 先传播错误, 再传播加载中。
///
/// 之前 error 只由第一个状态决定, 上游返回 `data(null)` 时错误会丢失,
/// 界面就停在"没有内容"而看不到失败原因。
AsyncValue combineStates(AsyncValue asyncValue1, AsyncValue asyncValue2) {
  if (asyncValue1.hasError) return asyncValue1;
  if (asyncValue2.hasError) return asyncValue2;
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

/// 搜索链路是否正在请求 (搜索接口 / 作品信息任一在跑)。
///
/// 失败后再次搜索时, 失败状态会先被清掉, 此时还没有"作品信息"请求
/// (非 RJ 输入要先拿到 id), 只看 [workInfoLoadingStateProvider] 会
/// 短暂落空; 这里把搜索接口本身的加载也算进来。
final searchLoadingProvider = Provider<bool>((ref) {
  return ref.watch(searchResultProvider).isLoading ||
      ref.watch(workInfoLoadingStateProvider).isLoading;
});