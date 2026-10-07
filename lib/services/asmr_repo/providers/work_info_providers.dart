import 'dart:typed_data';

import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/api_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final workInfoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final api = ref.watch(asmrApiProvider);

  final id = ref.watch(idProvider);
  if (id == null) {
    return null;
  }

  Log.info('fetch workInfo, id: $id');
  try {
    return await api.getWorkInfo(id);
  } on SearchFailureException catch (e) {
    setFailure(ref, e.failure);
    rethrow;
  }
});

final titleProvider = Provider<String>((ref) {
  final workInfo = ref.watch(workInfoProvider);
  return workInfo.maybeWhen(
    data: (data) {
      if (data == null) {
        return '';
      }
      return data['title'].toString();
    },
    orElse: () => '',
  );
});

final circleNameProvider = Provider<String>((ref) {
  final workInfo = ref.watch(workInfoProvider);
  return workInfo.maybeWhen(
    data: (data) {
      if (data == null) {
        return '';
      }
      return data['circle']['name'].toString();
    },
    orElse: () => '',
  );
});

final cvLsProvider = Provider<List<String>>((ref) {
  final workInfo = ref.watch(workInfoProvider);
  return workInfo.maybeWhen(
    data: (data) {
      if (data == null) {
        return [];
      }
      return (data['vas'] as List).map((e) => e['name'].toString()).toList();
    },
    orElse: () => [],
  );
});

final coverUrlProvider = Provider<String>((ref) {
  final workInfo = ref.watch(workInfoProvider);
  return workInfo.maybeWhen(
    data: (data) {
      if (data == null) {
        return '';
      }
      return data['mainCoverUrl'].toString();
    },
    orElse: () => '',
  );
});

final coverBytesProvider = FutureProvider<Uint8List?>((ref) async {
  final api = ref.watch(asmrApiProvider);
  
  final coverUrl = ref.watch(coverUrlProvider);
  if (coverUrl.isEmpty) {
    return null;
  }

  Log.info('fetch cover bytes, url: $coverUrl');
  return api.getCoverBytes(coverUrl);
});

final tagLsProvider = Provider<List<String>>((ref) {
  final workInfo = ref.watch(workInfoProvider);
  return workInfo.maybeWhen(
    data: (data) {
      if (data == null) {
        return [];
      }
      return (data['tags'] as List)
          .map((e) => e['i18n']?['zh-cn']?['name']?.toString())
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
    },
    orElse: () => [],
  );
});

final releaseDateProvider = Provider<String>((ref) {
  final workInfo = ref.watch(workInfoProvider);
  return workInfo.maybeWhen(
    data: (data) {
      if (data == null) {
        return '';
      }
      return data['release'].toString();
    },
    orElse: () => '',
  );
});

final dlCountProvider = Provider<int>((ref) {
  final workInfo = ref.watch(workInfoProvider);
  return workInfo.maybeWhen(
    data: (data) {
      if (data == null) {
        return 0;
      }
      return data['dl_count'] as int;
    },
    orElse: () => 0,
  );
});
