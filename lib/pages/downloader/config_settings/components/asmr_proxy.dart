import 'dart:async';

import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/ui/system_proxy_reader.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:asmr_downloader/utils/system_proxy_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 系统代理检测间隔: 系统代理开关变化后无需鼠标交互即可同步选项状态。
const Duration kSystemProxyCheckInterval = Duration(seconds: 2);

class AsmrProxy extends ConsumerStatefulWidget {
  const AsmrProxy({super.key});

  @override
  ConsumerState<AsmrProxy> createState() => _AsmrProxyState();
}

class _AsmrProxyState extends ConsumerState<AsmrProxy> {
  Timer? _timer;
  bool _hasSystemProxy = false;
  String? _systemProxy;

  @override
  void initState() {
    super.initState();
    // 仅初始化显示状态, 不在 build 期间修改 provider
    _refreshCheck(notify: false, sync: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshCheck();
      _timer = Timer.periodic(
        kSystemProxyCheckInterval,
        (_) => _refreshCheck(),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  /// 检测系统代理并同步选项状态。
  ///
  /// 检测不到系统代理时: 取消勾选并禁用选项, 同时切回直连。
  /// 这样不会出现"已勾选但点不动"的状态。
  void _refreshCheck({bool notify = true, bool sync = true}) {
    if (!mounted) return;

    final config = ref.read(systemProxyConfigReaderProvider)();
    final systemProxy = SystemProxyConfig.formatProxy(config.proxy);
    final hasSystemProxy = systemProxy != 'DIRECT';

    if (hasSystemProxy != _hasSystemProxy || config.proxy != _systemProxy) {
      Log.info('system proxy check: proxy="${config.proxy}" '
          'autoDetect=${config.autoDetect} autoConfigUrl=${config.autoConfigUrl}');
      _hasSystemProxy = hasSystemProxy;
      _systemProxy = config.proxy;
      if (notify) setState(() {});
    }

    if (sync) _syncProxyState(hasSystemProxy, systemProxy);
  }

  /// 系统代理已关闭时取消勾选; 系统代理地址变化时同步新地址。
  void _syncProxyState(bool hasSystemProxy, String systemProxy) {
    final current = ref.read(proxyProvider);

    if (!hasSystemProxy) {
      if (current != 'DIRECT') {
        Log.info('system proxy disabled, uncheck proxy option');
        unawaited(ref.read(uiServiceProvider).onProxyChanged(false));
      }
      return;
    }

    if (current != 'DIRECT' && current != systemProxy) {
      Log.info('system proxy changed, resync: "$current" -> "$systemProxy"');
      unawaited(ref.read(uiServiceProvider).onProxyChanged(true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final proxy = ref.watch(proxyProvider);
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      // 鼠标进入时重新检测系统代理, 保证 tooltip 反映最新状态
      onEnter: (_) => _refreshCheck(),
      child: Tooltip(
        message: _hasSystemProxy
            ? '使用系统代理: $_systemProxy'
            : '检测到系统代理才可启用',
        child: Row(
          children: [
            Checkbox(
              value: _hasSystemProxy && proxy != 'DIRECT',
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
