import 'dart:io';

import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/api_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:asmr_downloader/services/window_size_guard.dart';
import 'package:asmr_downloader/utils/system_proxy_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Initialization extends ConsumerStatefulWidget {
  const Initialization({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<Initialization> createState() => _InitializationState();
}

class _InitializationState extends ConsumerState<Initialization> {
  WindowSizeGuard? _windowSizeGuard;

  @override
  void initState() {
    super.initState();
    // Windows 偶发 view/窗口尺寸不同步, 启动后自愈一次
    if (Platform.isWindows) {
      _windowSizeGuard = WindowSizeGuard();
    }
    // init
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // startup search: 剪贴板内容不是 sourceId 时静默忽略
      await Future.delayed(const Duration(milliseconds: PASTE_SEARCH_DELAY_MS));
      ref.read(uiServiceProvider).pasteAndSearch(reportInvalid: false);
    });
  }

  @override
  void dispose() {
    _windowSizeGuard?.dispose();
    // dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(_initProvider);

    if (result.isLoading) {
      return const Center(
        child: SizedBox(
          width: 50.0,
          height: 50.0,
          child: CircularProgressIndicator(),
        ),
      );
    } else if (result.hasError) {
      return const Text('Error initializing');
    }

    return widget.child;
  }
}

final _initProvider = FutureProvider.autoDispose((ref) async {
  final config = await ref.read(configFileProvider).read();

  // api channel and proxy

  ref.read(apiChannelProvider.notifier).state =
      config['apiChannel'] as String? ?? 'asmr-200';

  final savedProxy = config['proxy'] as String? ?? 'DIRECT';
  if (savedProxy != 'DIRECT') {
    final proxy = SystemProxyConfig.systemProxy;
    ref.read(proxyProvider.notifier).state = proxy;
    ref.read(configFileProvider).addOrUpdate({'proxy': proxy});
  }

  ref.read(asmrApiProvider)
    ..setApiChannel(ref.read(apiChannelProvider))
    ..proxy = ref.read(proxyProvider);

  // misc

  ref.read(downloadPathProvider.notifier).state =
      config['dlPath'] as String? ?? '';
  ref.read(dlCoverProvider.notifier).state =
      config['dlCover'] as bool? ?? false;
});
