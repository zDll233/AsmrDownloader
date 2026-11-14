import 'dart:io';

import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/pages/settings/components/color_picker_dialog.dart';
import 'package:asmr_downloader/pages/settings/components/settings_widgets.dart';
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
  bool _rememberWindowPos = kDefaultRememberWindowPos;
  bool _rememberWindowSize = kDefaultRememberWindowSize;
  Color _themeSeedColor = kDefaultThemeSeed;
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
      _rememberWindowPos =
          config['rememberWindowPos'] ?? kDefaultRememberWindowPos;
      _rememberWindowSize =
          config['rememberWindowSize'] ?? kDefaultRememberWindowSize;
      _themeSeedColor =
          parseHexColor(resolveThemeSeedHex(config)) ?? kDefaultThemeSeed;
      _loading = false;
    });
  }

  Future<void> _save(Map<String, dynamic> updates) async {
    final config = await ref.read(configFileProvider).read();
    await ref.read(configFileProvider).write({...config, ...updates});
  }

  /// 恢复单项设置: 移除配置键回到默认值, 并刷新相关 provider。
  Future<void> _resetToDefault(
    List<String> keys,
    VoidCallback setDefault, {
    bool reapplyWindowEffect = false,
  }) async {
    setState(setDefault);
    // 先写完配置再刷新, 避免 provider 读到旧值
    await _removeKeys(keys);
    ref.invalidate(themeSeedColorProvider);
    ref.invalidate(windowEffectProvider);
    ref.invalidate(showExtFilterProvider);
    if (reapplyWindowEffect) {
      await ref.read(uiServiceProvider).applyWindowEffect(_windowEffect);
    }
  }

  /// 从配置里删掉若干键 (回到各自的默认值)。
  Future<void> _removeKeys(List<String> keys) async {
    final config = await ref.read(configFileProvider).read();
    for (final key in keys) {
      config.remove(key);
    }
    await ref.read(configFileProvider).write(config);
  }

  /// 重置所有设置: 二次确认后清空配置并恢复全部默认值。
  Future<void> _resetAllSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重置所有设置'),
        content: const Text('将恢复所有设置的默认值, 包括主题色、窗口效果、窗口记忆等。'
            '确定继续吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // 保留下载路径 (重置应用设置, 不重置用户已选的目录)
    final config = await ref.read(configFileProvider).read();
    final dlPath = config['dlPath'] is String &&
            (config['dlPath'] as String).isNotEmpty
        ? config['dlPath'] as String
        : '';

    setState(() {
      // 全部恢复默认值 (统一取自常量, 避免与读取处的默认不一致)
      _windowEffect = WINDOW_EFFECT_ACRYLIC;
      _showExtFilter = true;
      _rememberWindowPos = kDefaultRememberWindowPos;
      _rememberWindowSize = kDefaultRememberWindowSize;
      _themeSeedColor = kDefaultThemeSeed;
    });

    // 清空其余配置 (所有键走默认), 刷新 provider 并重新应用窗口效果
    await ref.read(configFileProvider).write({'dlPath': dlPath});
    ref.invalidate(themeSeedColorProvider);
    ref.invalidate(windowEffectProvider);
    ref.invalidate(showExtFilterProvider);
    await ref.read(uiServiceProvider).applyWindowEffect(_windowEffect);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置所有设置')),
      );
    }
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
      // 检查失败: 提示网络问题, 并询问是否打开 GitHub Release 页面兜底
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('检查更新失败'),
          content: const Text('无法获取最新版本信息, 请检查网络。\n'
              '是否打开 GitHub Release 页面查看最新版本?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('打开 Release 页面'),
            ),
          ],
        ),
      );
      if (open == true && mounted) {
        try {
          await openUrl(kReleasesUrl);
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('打开浏览器失败, 请手动访问 GitHub')),
          );
        }
      }
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
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
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
                          const SettingsSectionTitle(title: '窗口'),
                          SettingsCard(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.blur_on),
                                title: const Text('窗口背景效果'),
                                contentPadding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                trailing: SizedBox(
                                  width: isNarrow ? 180 : 216,
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
                              ListTile(
                                leading: const Icon(Icons.location_on_outlined),
                                title: const Text('记住窗口位置'),
                                contentPadding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: _rememberWindowPos,
                                      onChanged: (value) {
                                        setState(
                                            () => _rememberWindowPos = value);
                                        _save({'rememberWindowPos': value});
                                      },
                                    ),
                                    SettingsResetButton(
                                      onPressed: () => _resetToDefault(
                                        ['rememberWindowPos'],
                                        () => _rememberWindowPos =
                                            kDefaultRememberWindowPos,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.aspect_ratio),
                                title: const Text('记住窗口大小'),
                                contentPadding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: _rememberWindowSize,
                                      onChanged: (value) {
                                        setState(
                                            () => _rememberWindowSize = value);
                                        _save({'rememberWindowSize': value});
                                      },
                                    ),
                                    SettingsResetButton(
                                      onPressed: () => _resetToDefault(
                                        ['rememberWindowSize'],
                                        () => _rememberWindowSize =
                                            kDefaultRememberWindowSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SettingsSectionTitle(title: '外观'),
                        SettingsCard(
                          children: [
                            ListTile(
                              leading: SettingsColorSwatch(color: _themeSeedColor),
                              title: const Text('主题色'),
                              contentPadding:
                                  const EdgeInsets.only(left: 16, right: 16),
                              trailing: SettingsResetButton(
                                onPressed: () => _resetToDefault(
                                  ['themeSeedColor'],
                                  () => _themeSeedColor = kDefaultThemeSeed,
                                ),
                              ),
                              onTap: () async {
                                final picked = await showDialog<Color>(
                                  context: context,
                                  builder: (dialogContext) => ColorPickerDialog(
                                    initial: _themeSeedColor,
                                  ),
                                );
                                if (picked == null) return;
                                setState(() => _themeSeedColor = picked);
                                // 先写完配置再刷新主题, 避免 provider 读到旧值
                                await _save(
                                    {'themeSeedColor': colorToHex(picked)});
                                ref.invalidate(themeSeedColorProvider);
                              },
                            ),
                          ],
                        ),
                        const SettingsSectionTitle(title: '界面'),
                        SettingsCard(
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
                        const SettingsSectionTitle(title: '关于'),
                        SettingsCard(
                          children: [
                            // 检查更新: Windows 专属 (zip 覆盖式更新)
                            if (Platform.isWindows)
                              ListTile(
                                leading: Icon(
                                  Icons.system_update_alt,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.7),
                                ),
                                title: const Text('检查更新'),
                                subtitle: Text('当前版本 $kAppVersion'),
                                contentPadding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                onTap: _checkUpdate,
                              ),
                          ],
                        ),
                        const SettingsSectionTitle(title: '危险操作'),
                        SettingsCard(
                          children: [
                            ListTile(
                              leading: Icon(
                                Icons.restore_from_trash_outlined,
                                color: scheme.error,
                              ),
                              title: Text(
                                '重置所有设置',
                                style: TextStyle(color: scheme.error),
                              ),
                              contentPadding:
                                  const EdgeInsets.only(left: 16, right: 16),
                              onTap: _resetAllSettings,
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
}
