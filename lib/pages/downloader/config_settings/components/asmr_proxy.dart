import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:asmr_downloader/utils/system_proxy_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsmrProxy extends ConsumerStatefulWidget {
  const AsmrProxy({super.key});

  @override
  ConsumerState<AsmrProxy> createState() => _AsmrProxyState();
}

class _AsmrProxyState extends ConsumerState<AsmrProxy> {
  late bool _hasSystemProxy;
  late String? _systemProxy;

  @override
  void initState() {
    super.initState();
    _refreshCheck();
  }

  /// 重新检测系统代理 (点击"启用代理"区域时调用, 支持代理开关后即时刷新)。
  void _refreshCheck() {
    final config = SystemProxyConfig.getConfig();
    Log.info('system proxy check: proxy="${config.proxy}" '
        'autoDetect=${config.autoDetect} autoConfigUrl=${config.autoConfigUrl}');
    _hasSystemProxy = config.proxy != null && config.proxy!.isNotEmpty;
    _systemProxy = config.proxy;
  }

  @override
  Widget build(BuildContext context) {
    final proxy = ref.watch(proxyProvider);
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      // 鼠标进入时重新检测系统代理, 保证 tooltip 反映最新状态
      onEnter: (_) => setState(_refreshCheck),
      child: Tooltip(
        message: _hasSystemProxy
            ? '使用系统代理: $_systemProxy'
            : '检测到系统代理才可启用',
        child: Row(
          children: [
            Checkbox(
              value: proxy != 'DIRECT',
              onChanged: _hasSystemProxy
                  ? ref.read(uiServiceProvider).onProxyChanged
                  : null,
            ),
            Text(
              '启用代理',
              style: TextStyle(
                color: _hasSystemProxy
                    ? scheme.onSurface.withValues(alpha: 0.85)
                    : scheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
