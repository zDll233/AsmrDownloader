import 'package:asmr_downloader/models/track_item.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:path/path.dart' as p;

/// 扩展名分组 (带当前选中计数)。
class _ExtGroup {
  final String ext;
  final String type;
  int totalCount = 0;
  int selectedCount = 0;

  _ExtGroup({required this.ext, required this.type});
}

/// 扩展名过滤条: 位于进度条与文件树之间。
/// 收集文件树中所有文件扩展名, 点击复选框一键选中/取消该扩展名的所有文件。
/// 排序: 音频扩展在前, 图片其次, 其他最后 (组内按首次出现顺序)。
class ExtensionFilterBar extends ConsumerWidget {
  const ExtensionFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rootFolder = ref.watch(rootFolderProvider);
    if (rootFolder == null) return const SizedBox.shrink();

    final groups = _collectExtensionGroups(rootFolder);

    if (groups.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // 左边缘对齐文件树文件夹图标:
        // tracksLPadding(20) + ExpansionTile contentPadding(start 16)
        padding: const EdgeInsets.only(left: 36),
        child: Row(
          children: [
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => _toggleExt(g, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        tristate: true,
                        value: g.selectedCount == 0
                            ? false
                            : (g.selectedCount == g.totalCount ? true : null),
                        onChanged: (_) => _toggleExt(g, ref),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        g.ext,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 切换某扩展名的选中状态: 全选 -> 取消, 否则全选。
  void _toggleExt(_ExtGroup g, WidgetRef ref) {
    final rootFolder = ref.read(rootFolderProvider);
    if (rootFolder == null) return;
    final allSelected = g.selectedCount == g.totalCount;
    Log.info('toggle ${g.ext}: allSelected=$allSelected (${g.selectedCount}/${g.totalCount})');
    _setExtSelection(rootFolder, g.ext, !allSelected);
    _recalcFolderSelection(rootFolder);
    // copyWith 深拷贝产生新对象, 确保 StateProvider 触发所有 watch 刷新
    ref.read(rootFolderProvider.notifier).state = rootFolder.copyWith();
    Log.info('toggle done: ${g.ext}');
  }

  /// 收集所有扩展名及选中统计。
  List<_ExtGroup> _collectExtensionGroups(TrackItem root) {
    final map = <String, _ExtGroup>{};
    final order = <String>[];

    void walk(TrackItem item) {
      if (item is Folder) {
        for (final child in item.children) {
          walk(child);
        }
      } else if (item is FileAsset) {
        final ext = p.extension(item.title).toLowerCase();
        if (ext.isEmpty) return;
        final group = map.putIfAbsent(ext, () {
          order.add(ext);
          return _ExtGroup(ext: ext, type: item.type);
        });
        group.totalCount++;
        if (item.selected) {
          group.selectedCount++;
        }
      }
    }

    walk(root);

    // 排序: audio(0) < image(1) < 其他(2), 组内保持首次出现顺序
    const priority = {'audio': 0, 'image': 1};
    final index = {for (var i = 0; i < order.length; i++) order[i]: i};
    final exts = order.toList()
      ..sort((a, b) {
        final pa = priority[map[a]!.type] ?? 2;
        final pb = priority[map[b]!.type] ?? 2;
        if (pa != pb) return pa.compareTo(pb);
        return index[a]!.compareTo(index[b]!);
      });
    return exts.map((e) => map[e]!).toList();
  }

  /// 设置指定扩展名所有文件的选中状态。
  void _setExtSelection(TrackItem item, String ext, bool value) {
    if (item is Folder) {
      for (final child in item.children) {
        _setExtSelection(child, ext, value);
      }
    } else if (item is FileAsset &&
        p.extension(item.title).toLowerCase() == ext) {
      item.selected = value;
    }
  }

  /// 重新计算文件夹选中状态: 所有子项全选 -> 选中, 否则不选中。
  void _recalcFolderSelection(TrackItem item) {
    if (item is Folder) {
      for (final child in item.children) {
        _recalcFolderSelection(child);
      }
      if (item.children.isNotEmpty) {
        item.selected = item.children.every((child) => child.selected);
      }
    }
  }
}
