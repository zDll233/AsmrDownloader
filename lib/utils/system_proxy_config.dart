// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'package:asmr_downloader/utils/log.dart';
import 'package:ffi/ffi.dart';

// https://learn.microsoft.com/en-us/windows/win32/api/winhttp/nf-winhttp-winhttpgetieproxyconfigforcurrentuser

base class WINHTTP_CURRENT_USER_IE_PROXY_CONFIG extends Struct {
  @Int32()
  external int fAutoDetect;

  external Pointer<Utf16> lpszAutoConfigUrl;
  external Pointer<Utf16> lpszProxy;
  external Pointer<Utf16> lpszProxyBypass;
}

class SystemProxyConfig {
  bool? autoDetect;
  String? autoConfigUrl;
  String? proxy;
  String? proxyBypass;

  SystemProxyConfig({
    this.autoDetect,
    this.autoConfigUrl,
    this.proxy,
    this.proxyBypass,
  });

  static final _WinHttpGetIEProxyConfigForCurrentUser =
      DynamicLibrary.open('winhttp.dll').lookupFunction<
              Int32 Function(
                  Pointer<WINHTTP_CURRENT_USER_IE_PROXY_CONFIG> pProxyConfig),
              int Function(
                  Pointer<WINHTTP_CURRENT_USER_IE_PROXY_CONFIG> pProxyConfig)>(
          'WinHttpGetIEProxyConfigForCurrentUser');

  static final _GlobalFree = DynamicLibrary.open('kernel32.dll').lookupFunction<
      Pointer<Void> Function(Pointer<Void> mem),
      Pointer<Void> Function(Pointer<Void> mem)>('GlobalFree');

  factory SystemProxyConfig.getConfig() {
    final pUserIEProxyConfig = calloc<WINHTTP_CURRENT_USER_IE_PROXY_CONFIG>();

    try {
      final result = _WinHttpGetIEProxyConfigForCurrentUser(pUserIEProxyConfig);
      final systemProxyConfig = SystemProxyConfig();

      if (result != 0) {
        systemProxyConfig.autoDetect = pUserIEProxyConfig.ref.fAutoDetect != 0;

        final lpszAutoConfigUrl = pUserIEProxyConfig.ref.lpszAutoConfigUrl;
        if (lpszAutoConfigUrl != nullptr) {
          systemProxyConfig.autoConfigUrl = lpszAutoConfigUrl.toDartString();
          _GlobalFree(lpszAutoConfigUrl.cast());
        }

        final lpszProxy = pUserIEProxyConfig.ref.lpszProxy;
        if (lpszProxy != nullptr) {
          systemProxyConfig.proxy = lpszProxy.toDartString();
          _GlobalFree(lpszProxy.cast());
        }

        final lpszProxyBypass = pUserIEProxyConfig.ref.lpszProxyBypass;
        if (lpszProxyBypass != nullptr) {
          systemProxyConfig.proxyBypass = lpszProxyBypass.toDartString();
          _GlobalFree(lpszProxyBypass.cast());
        }
      } else {
        Log.error('failed to get system proxy config.\n'
            'error: `WinHttpGetIEProxyConfigForCurrentUser` failed to execute.');
      }

      return systemProxyConfig;
    } catch (e) {
      Log.error('failed to get system proxy config.\n' 'error: $e');
      return SystemProxyConfig();
    } finally {
      calloc.free(pUserIEProxyConfig);
    }
  }

  /// 将系统代理地址 (如 `127.0.0.1:7890;127.0.0.1:7891`) 转换为
  /// HttpClient.findProxy 需要的格式; 未配置代理时返回 DIRECT。
  static String formatProxy(String? proxy) {
    if (proxy == null) return 'DIRECT';

    final entries =
        proxy.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty);
    if (entries.isEmpty) return 'DIRECT';

    return '${entries.map((e) => 'PROXY $e').join('; ')}; DIRECT';
  }

  /// 返回代理配置 PROXY host:port; PROXY host2:port2; DIRECT, 如果代理地址获取失败则直接返回 DIRECT
  static String get systemProxy =>
      formatProxy(SystemProxyConfig.getConfig().proxy);
}
