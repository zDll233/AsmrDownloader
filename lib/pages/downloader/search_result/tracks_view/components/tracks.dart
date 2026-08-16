import 'package:asmr_downloader/pages/components/middle_ellipsis_text.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/models/track_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Tracks extends ConsumerStatefulWidget {
  const Tracks({
    super.key,
    required this.rootFolder,
    this.tracksLPadding = 20.0,
  });
  final Folder rootFolder;
  final double tracksLPadding;

  @override
  ConsumerState<Tracks> createState() => TracksState();
}

class TracksState extends ConsumerState<Tracks> {
  @override
  Widget build(BuildContext context) {
    // watch 而非使用 widget.rootFolder: 扩展名过滤条等外部修改
    // 选中状态后需要刷新文件树
    final rootFolder = ref.watch(rootFolderProvider);
    if (rootFolder == null) return const SizedBox.shrink();

    final trackExpansionLs = trackExpansion(rootFolder);
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) => trackExpansionLs[index],
            childCount: trackExpansionLs.length,
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          // 占满剩余空间
          child: Container(),
        ),
      ],
    );
  }

  List<Widget> trackExpansion(TrackItem track) {
    List<Widget> trackWidgets = [];
    if (track is Folder) {
      trackWidgets.add(
        Padding(
          padding: EdgeInsets.only(left: widget.tracksLPadding),
          child: ExpansionTile(
            leading: Icon(Icons.folder, color: Color(0xFFF9C100)),
            trailing: Checkbox(
                tristate: true,
                value: track.selectionState,
                onChanged: (_) {
                  // 自定义三态点击行为 (Flutter 默认循环 false→true→null→false
                  // 不符合预期):
                  // 全选 -> 取消全部; 半选/全空 -> 全选
                  final next = track.selectionState == true ? false : true;
                  setState(() {
                    track.setSelection(next);
                  });
                  // 用 ref.read 取最新树 (widget.rootFolder 可能是旧引用,
                  // 深拷贝会丢失本次修改)
                  ref.read(rootFolderProvider.notifier).state =
                      (ref.read(rootFolderProvider) ?? widget.rootFolder)
                          .copyWith();
                }),
            title: Text(track.title),
            children: track.children
                .expand((child) => trackExpansion(child))
                .toList(),
          ),
        ),
      );
    } else {
      // FileAsset
      trackWidgets.add(
        Padding(
          padding: EdgeInsets.only(left: widget.tracksLPadding),
          child: CheckboxListTile(
            value: track.selected,
            onChanged: (bool? newValue) {
              if (newValue == null) return;
              setState(() {
                track.selected = newValue;
              });
              // 用 ref.read 取最新树 (widget.rootFolder 可能是旧引用,
              // 深拷贝会丢失本次修改)
              ref.read(rootFolderProvider.notifier).state =
                  (ref.read(rootFolderProvider) ?? widget.rootFolder)
                      .copyWith();
            },
            title: Row(
              children: [
                getIconFromType(track.type),
                SizedBox(width: 10.0),
                ...ellipsisInMiddle(track.title),
              ],
            ),
          ),
        ),
      );
    }
    return trackWidgets;
  }

  Icon getIconFromType(String type) {
    switch (type) {
      case 'audio':
        return Icon(Icons.music_note, color: Colors.blue);
      case 'image':
        return Icon(Icons.image, color: Colors.green);
      case 'text':
        return Icon(Icons.text_snippet, color: Colors.grey);
      default:
        return Icon(Icons.error, color: Colors.white);
    }
  }
}
