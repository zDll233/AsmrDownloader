import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadPathPicker extends ConsumerWidget {
  const DownloadPathPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dlPath = ref.watch(downloadPathProvider);
    return SizedBox(
      height: 50.0,
      child: Row(
        children: [
          SizedBox(
            width: 250,
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: dlPath.isEmpty ? '选择下载路径' : dlPath,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2.0),
            child: IconButton(
              onPressed: ref.read(uiServiceProvider).pickDlPath,
              tooltip: '选择下载路径',
              icon: const Icon(Icons.folder),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2.0),
            child: IconButton(
              onPressed: ref.read(uiServiceProvider).openFolder,
              tooltip: '打开文件夹',
              icon: const Icon(Icons.folder_open),
            ),
          ),
        ],
      ),
    );
  }
}
