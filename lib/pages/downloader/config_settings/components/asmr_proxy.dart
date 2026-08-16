import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsmrProxy extends ConsumerWidget {
  const AsmrProxy({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxy = ref.watch(proxyProvider);
    return Row(
      children: [
        const Text('启用代理'),
        Checkbox(
          value: proxy != 'DIRECT',
          onChanged: ref.read(uiServiceProvider).onProxyChanged,
        ),
      ],
    );
  }
}
