import 'dart:io';

import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/pages/window_title_bar/move_window.dart';
import 'package:asmr_downloader/services/ui/theme/theme_provider.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:asmr_downloader/services/updater/update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设置页面 (参考 Again 项目: 分组卡片 + 拖动区标题栏)。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _windowEffect = WINDOW_EFFECT_ACRYLIC;
  bool _showExtFilter = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final config = await ref.read(configFileProvider).read();
    setState(() {
      _windowEffect = resolveWindowEffect(config);
      _showExtFilter = config['showExtFilter'] != false;
      _loading = false;
    });
  }

  Future<void> _save(Map<String, dynamic> updates) async {
    final config = await ref.read(configFileProvider).read();
    await ref.read(configFileProvider).write({...config, ...updates});
  }

  /// 检查更新: 查询 GitHub 最新 Release, 有新版本时下载并重启更新。
  Future<void> _checkUpdate() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在检查更新…')),
    );
    final result = await checkForUpdate();
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('检查更新失败, 请检查网络')),
      );
      return;
    }
    if (!result.hasUpdate || result.zipUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已是最新版本 ($kAppVersion)')),
      );
      return;
    }

    final download = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('发现新版本'),
        content: Text('最新版本: ${result.latestTag}\n'
            '当前版本: $kAppVersion\n\n是否下载并更新?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('下载更新'),
          ),
        ],
      ),
    );
    if (download != true || !mounted) return;

    // 下载进度对话框 (不可关闭)
    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('正在下载更新…'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 10),
              Text('${(value * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      ),
    );
    final zipPath = await downloadUpdateZip(
      result.zipUrl!,
      onProgress: (received, total) {
        progress.value = total > 0 ? received / total : 0;
      },
    );
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (zipPath == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('下载失败, 请稍后重试')),
      );
      return;
    }

    if (!mounted) return;
    final apply = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('更新已下载'),
        content: const Text('应用将关闭并自动完成更新, 确定现在更新吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
    if (apply == true) {
      await applyUpdate(zipPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface.withValues(alpha: 0.98),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏: 返回按钮 + 拖动区
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: MoveWindow(
                      moveOnChildWidget: true,
                      child: SizedBox.expand(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '设置',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        // 窗口设置: Windows 专属
                        if (Platform.isWindows) ...[
                          _sectionTitle('窗口'),
                          _card(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.blur_on),
                                title: const Text('窗口背景效果'),
                                contentPadding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                trailing: SizedBox(
                                  width: 216,
                                  child: SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(
                                        value: WINDOW_EFFECT_TRANSPARENT,
                                        label: Text('透明'),
                                      ),
                                      ButtonSegment(
                                        value: WINDOW_EFFECT_ACRYLIC,
                                        label: Text('亚克力'),
                                      ),
                                      ButtonSegment(
                                        value: WINDOW_EFFECT_OPAQUE,
                                        label: Text('不透明'),
                                      ),
                                    ],
                                    selected: {_windowEffect},
                                    showSelectedIcon: false,
                                    style: ButtonStyle(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onSelectionChanged: (selection) async {
                                      final value = selection.first;
                                      setState(() => _windowEffect = value);
                                      await _save({'windowEffect': value});
                                      ref.invalidate(windowEffectProvider);
                                      ref
                                          .read(uiServiceProvider)
                                          .applyWindowEffect(value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        _sectionTitle('界面'),
                        _card(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.checklist),
                              title: const Text('扩展名过滤条'),
                              subtitle: const Text('按文件扩展名一键全选/取消'),
                              contentPadding:
                                  const EdgeInsets.only(left: 16, right: 16),
                              trailing: Switch(
                                value: _showExtFilter,
                                onChanged: (value) async {
                                  setState(() => _showExtFilter = value);
                                  await _save({'showExtFilter': value});
                                  ref.invalidate(showExtFilterProvider);
                                },
                              ),
                            ),
                          ],
                        ),
                        _sectionTitle('关于'),
                        _card(
                          children: [
                            // 检查更新: Windows 专属 (zip 覆盖式更新)
                            if (Platform.isWindows)
                              ListTile(
                                leading: Icon(
                                  Icons.system_update_alt,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.7),
                                ),
                                title: const Text('检查更新'),
                                subtitle: Text('当前版本 $kAppVersion'),
                                contentPadding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                onTap: _checkUpdate,
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          color: scheme.primary,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: children),
    );
  }
}
