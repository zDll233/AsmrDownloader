import 'dart:io';

import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/models/track_item.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/api_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/tracks_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/work_info_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/search_failure.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/system_proxy_reader.dart';
import 'package:asmr_downloader/utils/system_proxy_config.dart';
import 'package:asmr_downloader/utils/tool_functions.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import 'package:path/path.dart' as p;

class UIService {
  final Ref ref;
  UIService(this.ref);

  Future<void> resetProgress() async {
    ref
      ..read(processProvider.notifier).state = 0
      ..read(currentDlNoProvider.notifier).state = 0
      ..read(totalTaskCntProvider.notifier).state = 0
      ..read(currentFileNameProvider.notifier).state = '';
    await WindowsTaskbar.setProgress(0, 0);
  }

  String normalizeInput(String sourceId) => normalizeInputStatic(sourceId);

  static String normalizeInputStatic(String sourceId) {
    return sourceId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
  }

  Future<String?> search(String input) async {
    await resetProgress();
    clearFailure(ref);

    final searchText = normalizeInput(input);
    if (searchText.isEmpty) {
      setFailure(ref, SearchFailure.invalidInput(input));
      return null;
    }
    if (!isSourceIdValid(searchText)) {
      setFailure(ref, SearchFailure.invalidInput(input));
      return null;
    }

    if (searchText == ref.read(searchTextProvider)) {
      // force to refetch
      ref
        ..invalidate(workInfoProvider)
        ..invalidate(rawTracksProvider)
        ..invalidate(coverBytesProvider);

      // 同一输入再搜一次 (用户手动重试) 时搜索请求本身也要重发,
      // 否则失败会一直停在那里 (非 RJ 才需要, RJ 不走搜索接口)。
      if (!searchText.startsWith('RJ')) {
        ref.invalidate(searchResultProvider);
      }
    } else {
      ref.read(searchTextProvider.notifier).state = searchText;
    }
    return searchText;
  }

  /// 让搜索链路按当前输入重新请求一次。
  ///
  /// 已经请求失败的阶段直接重跑, 阶段之前的请求不再重复:
  /// 例如音声文件失败就只重取文件列表。
  void retry() {
    final failure = ref.read(failureProvider);
    final stage = failure?.stage;

    resetProgress();
    clearFailure(ref);

    if (stage == SearchStage.tracks && ref.read(sourceIdProvider) != null) {
      ref.invalidate(rawTracksProvider);
      return;
    }

    // 其余失败需要重取作品信息 (失败在搜索阶段时连搜索一起重跑)。
    if (ref.read(sourceIdProvider) == null || stage == SearchStage.search) {
      invalidateSearch();
      return;
    }

    ref
      ..invalidate(workInfoProvider)
      ..invalidate(rawTracksProvider);
  }

  /// 让搜索链路按当前输入重新请求一次。
  void invalidateSearch() {
    ref.invalidate(workInfoProvider);
    ref.invalidate(rawTracksProvider);

    if (ref.read(searchTextProvider)?.startsWith('RJ') ?? false) {
      return;
    }
    ref.invalidate(searchResultProvider);
  }

  /// 每个词法 token 都必须是合法的 sourceId (可被逗号/空格/换行等分隔)。
  static bool _tokenizeAsSourceId(String text) {
    final tokens = text.split(RegExp(r'[\s,，、;；/|]+'))
      ..removeWhere((e) => e.isEmpty);
    if (tokens.isEmpty) return false;

    return tokens.every((e) => isSourceIdValid(normalizeInputStatic(e)));
  }

  /// 读取剪贴板并搜索。
  ///
  /// [reportInvalid] 为 false 时, 剪贴板内容不是 sourceId 就静默忽略
  /// (启动时自动读取剪贴板用; 用户主动点"粘贴并搜索"时仍会提示)。
  Future<String?> pasteAndSearch({bool reportInvalid = true}) async {
    final clipBoardText = (await Clipboard.getData('text/plain'))?.text;
    if (clipBoardText == null) return null;

    // 剪贴板里没有合法 sourceId: 不打扰用户, 也不改搜索框;
    // 用户主动点"粘贴并搜索"时给出提示。
    if (!_tokenizeAsSourceId(clipBoardText)) {
      if (reportInvalid) {
        await search(clipBoardText);
      }
      return null;
    }

    // set old sourceId to clipboard
    final oldSourceId = ref.read(sourceIdProvider);
    if (oldSourceId != null) {
      await Clipboard.setData(ClipboardData(text: oldSourceId));
    }

    return search(clipBoardText);
  }

  void onApiChannelChoosed(String? newValue) {
    if (newValue == null || newValue == ref.read(apiChannelProvider)) return;

    ref
      ..read(apiChannelProvider.notifier).state = newValue
      ..read(configFileProvider).addOrUpdate({'apiChannel': newValue})
      ..read(asmrApiProvider).setApiChannel(newValue);

    // 换频道多半是为了绕开失败, 直接清掉错误并按当前输入重搜。
    if (ref.read(searchPhaseProvider) == SearchPhase.active) {
      retry();
    }
  }

  Future<void> onProxyChanged(bool? value) async {
    if (value == null) return;

    // 与设置界面的可用性检测使用同一个读取器, 保证行为一致
    final proxy = value
        ? SystemProxyConfig.formatProxy(
            ref.read(systemProxyConfigReaderProvider)().proxy)
        : 'DIRECT';

    if (proxy == ref.read(proxyProvider)) return;

    ref
      ..read(proxyProvider.notifier).state = proxy
      ..read(configFileProvider).addOrUpdate({'proxy': proxy})
      ..read(asmrApiProvider).proxy = proxy;
  }

  void onDlCoverChanged(bool? value) {
    if (value == null) return;

    ref
      ..read(dlCoverProvider.notifier).state = value
      ..read(configFileProvider).addOrUpdate({'dlCover': value});
    Log.info('dlCover: $value');
  }

  Future<void> pickDlPath() async {
    final dlPath = await FilePicker.platform.getDirectoryPath();
    if (dlPath == null) return;

    ref
      ..read(downloadPathProvider.notifier).state = dlPath
      ..read(configFileProvider).addOrUpdate({'dlPath': dlPath});
    Log.info('dlPath: $dlPath');
  }

  void openFolder() async {
    final vkSourceIdPath =
        p.join(ref.read(voiceWorkPathProvider), ref.read(sourceIdProvider));

    final path = Directory(vkSourceIdPath).existsSync()
        ? vkSourceIdPath
        : ref.read(downloadPathProvider);

    Process.run('explorer "$path"', []);
    Log.info('open folder: "$path"');
  }

  /// 应用窗口背景效果: transparent 全透明 / acrylic 毛玻璃 / opaque 不透明。
  /// 仅 Windows 生效 (系统级 acrylic 窗口效果, 参考 Again 项目)。
  Future<void> applyWindowEffect(String effect) async {
    if (!Platform.isWindows) return;
    try {
      Log.info('applyWindowEffect: $effect');
      switch (effect) {
        case WINDOW_EFFECT_TRANSPARENT:
          await Window.setEffect(
            effect: WindowEffect.transparent,
            color: const Color(0xCC222222),
          );
        case WINDOW_EFFECT_OPAQUE:
          await Window.setEffect(
            effect: WindowEffect.solid,
            color: const Color(0xFF1E1E28),
          );
        default: // WINDOW_EFFECT_ACRYLIC
          await Window.setEffect(
            effect: WindowEffect.acrylic,
            // tint 很浅 (25%), 模糊的桌面背景清晰透出。
            color: const Color(0x40262A33),
          );
      }
      Log.info('applyWindowEffect: $effect done');
    } catch (e, s) {
      Log.error('applyWindowEffect failed.\n$e.\n$s');
    }
  }

  Future<void> onExit(BuildContext context) async {
    if (DownloadStatus.downloading == ref.read(dlStatusProvider)) {
      await windowManager.show();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('文件下载中'),
              content: const Text('你确定要关闭吗？下载将被取消，再次下载会继承已下载的部分。'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    // 不要用windowManager.destroy()，有明显的卡顿
                    windowManager
                      ..setPreventClose(false)
                      ..close();
                  },
                  child: const Text('关闭'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      }
    } else {
      windowManager
        ..setPreventClose(false)
        ..close();
    }
  }
}
