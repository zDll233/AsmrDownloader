import 'package:asmr_downloader/pages/downloader/config_settings/components/asmr_api_channel.dart';
import 'package:asmr_downloader/pages/downloader/config_settings/components/asmr_proxy.dart';
import 'package:asmr_downloader/pages/downloader/config_settings/components/dl_cover_check.dart';
import 'package:asmr_downloader/pages/downloader/config_settings/components/dl_path_picker.dart';
import 'package:asmr_downloader/pages/downloader/search_box/search_box.dart';
import 'package:asmr_downloader/pages/downloader/search_result/search_result.dart';
import 'package:flutter/material.dart';

class Downloader extends StatelessWidget {
  const Downloader({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Row(
              children: [
                SearchBox(),
                const ToolbarDivider(),
                DownloadPathPicker(),
                const ToolbarDivider(),
                DlCoverCheck(),
                const SizedBox(width: 10),
                AsmrProxy(),
                const SizedBox(width: 10),
                AsmrApiChannel(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SearchResult(),
        ],
      ),
    );
  }
}

/// 工具栏分组之间的细线分隔。
class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        width: 1,
        height: 24,
        color: scheme.onSurface.withValues(alpha: 0.15),
      ),
    );
  }
}
