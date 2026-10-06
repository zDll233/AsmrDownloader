import 'package:asmr_downloader/utils/system_proxy_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 系统代理配置读取器 (测试可替换)。
typedef SystemProxyConfigReader = SystemProxyConfig Function();

/// 读取当前系统代理配置。
///
/// 单独放在这里, 让"检测系统代理" (设置界面) 与"应用代理设置"
/// (UIService.onProxyChanged) 走同一次读取, 行为保持一致。
final systemProxyConfigReaderProvider =
    Provider<SystemProxyConfigReader>((ref) => SystemProxyConfig.getConfig);
