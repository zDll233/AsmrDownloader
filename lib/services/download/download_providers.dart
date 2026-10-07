import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/models/track_item.dart';
import 'package:asmr_downloader/services/asmr_repo/parse_tracks.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/api_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/tracks_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/work_info_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
import 'package:asmr_downloader/services/download/download_manager.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:asmr_downloader/utils/tool_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;

final downloadManagerProvider = Provider((ref) => DownloadManager(ref));

/// 当前搜索失败的原因 (null 表示没有失败)。
final failureProvider = StateProvider<SearchFailure?>((ref) => null);

/// 记录失败。
///
/// provider 若已被销毁 (容器销毁 / 重新搜索), 写入会被忽略:
/// 请求还在飞的时候界面已经换了新的搜索, 旧结果不该再弹错误。
void setFailure(Ref ref, SearchFailure failure) {
  Log.error('failure: ${failure.title}\n${failure.technicalDetail}');
  try {
    ref.read(failureProvider.notifier).state = failure;
  } catch (_) {
    // provider 已销毁
  }
}

/// 清除失败 (开始新的搜索 / 主动重试时)。
void clearFailure(Ref ref) {
  try {
    if (ref.read(failureProvider) != null) {
      ref.read(failureProvider.notifier).state = null;
    }
  } catch (_) {
    // provider 已销毁
  }
}

/// 从搜索响应里取出 works 列表 (结构异常时返回空列表)。
List<dynamic> worksOf(Map<String, dynamic>? data) {
  final works = data?['works'];
  return works is List ? works : const [];
}

/// 结果面板当前该展示什么。
enum SearchPhase { idle, invalidInput, active }

final searchPhaseProvider = Provider<SearchPhase>((ref) {
  final searchText = ref.watch(searchTextProvider);
  if (searchText == null) return SearchPhase.idle;
  return isSourceIdValid(searchText)
      ? SearchPhase.active
      : SearchPhase.invalidInput;
});

final voiceWorkPathProvider = Provider<String>((ref) {
  final downloadPath = ref.watch(downloadPathProvider);
  final title = ref.watch(titleProvider);
  final cvLs = ref.watch(cvLsProvider);

  // cv1&cv2&...&cvn-title
  final dirName = getLegalWindowsName('${cvLs.join('&')}-$title');
  return p.join(downloadPath, dirName);
});

final searchTextProvider = StateProvider<String?>((ref) => null);

final searchResultProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final searchText = ref.watch(searchTextProvider);
  if (searchText == null || searchText.startsWith('RJ')) {
    return null;
  }

  Log.info('search $searchText');
  final api = ref.watch(asmrApiProvider);
  try {
    final data = await api.search(content: searchText);
    if (worksOf(data).isEmpty) {
      // 请求成功但服务器没有返回任何作品。
      setFailure(ref, SearchFailure.emptyResult(searchText));
      return null;
    }
    return data;
  } on SearchFailureException catch (e) {
    setFailure(ref, e.failure);
    return null;
  }
});

final idProvider = Provider<String?>((ref) {
  final searchText = ref.watch(searchTextProvider);
  if (searchText == null) {
    return null;
  }
  if (searchText.startsWith('RJ')) {
    return searchText.replaceAll(RegExp(r'[^0-9]'), '');
  }

  final searchResult = ref.watch(searchResultProvider);
  if (!searchResult.hasValue) return null;

  final works = worksOf(searchResult.value);
  if (works.isEmpty) return null;

  final first = works.first;
  return first is Map ? first['id']?.toString() : null;
});

final sourceIdProvider = Provider<String?>((ref) {
  final searchText = ref.watch(searchTextProvider);
  if (searchText == null) {
    return null;
  }
  if (searchText.startsWith('RJ')) {
    return searchText;
  }

  final searchResult = ref.watch(searchResultProvider);
  if (!searchResult.hasValue) return null;

  final works = worksOf(searchResult.value);
  if (works.isEmpty) return null;

  final first = works.first;
  return first is Map ? first['source_id']?.toString() : null;
});

final rootFolderProvider = StateProvider<Folder?>((ref) {
  final rawTracks = ref.watch(rawTracksProvider);
  final sourceId = ref.watch(sourceIdProvider);
  if (sourceId == null) {
    return null;
  }

  return rawTracks.maybeWhen(
      data: (data) {
        if (data == null || data.isEmpty) {
          return null;
        }
        return Folder(id: sourceId, title: sourceId)
          ..children = getTrackItems(data);
      },
      orElse: () => null);
});

final dlStatusProvider = StateProvider((ref) => DownloadStatus.notStarted);

final processProvider = StateProvider<double>((ref) => 0);

final currentFileNameProvider = StateProvider<String>((ref) => '');

final currentDlNoProvider = StateProvider<int>((ref) => 0);
final totalTaskCntProvider = StateProvider<int>((ref) => 0);
