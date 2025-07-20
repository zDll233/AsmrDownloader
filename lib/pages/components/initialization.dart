import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/api_providers.dart';
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
  @override
  void initState() {
    super.initState();
    // init
  }

  @override
  void dispose() {
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
