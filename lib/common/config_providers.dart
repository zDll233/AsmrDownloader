import 'package:asmr_downloader/utils/json_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final configFileProvider = Provider<JsonStorage>((ref) {
  return JsonStorage(filePath: 'asmr_dl_config.json');
});

/// 扩展名过滤条显示开关 (config.json `showExtFilter`, 默认显示)。
final showExtFilterProvider = FutureProvider.autoDispose<bool>((ref) async {
  final config = await ref.read(configFileProvider).read();
  return config['showExtFilter'] != false;
});

final downloadPathProvider = StateProvider<String>((ref) => '');

final dlCoverProvider = StateProvider<bool>((ref) => false);

final proxyProvider = StateProvider<String>((ref) => 'DIRECT');

final apiChannelProvider = StateProvider<String>((ref) => 'asmr-200');
