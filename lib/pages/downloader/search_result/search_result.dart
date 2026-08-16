import 'package:asmr_downloader/pages/downloader/search_result/tracks_view/tracks_view.dart';
import 'package:asmr_downloader/pages/downloader/search_result/work_info/work_info.dart';
import 'package:flutter/material.dart';

class SearchResult extends StatelessWidget {
  const SearchResult({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        // 左右边界间距
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左: 作品信息 (40%)
            Expanded(
              flex: 2,
              child: WorkInfo(horizontalPadding: 0),
            ),
            // 中间间距
            const SizedBox(width: 20),
            // 右: 音轨文件树 (60%)
            Expanded(
              flex: 3,
              child: TracksView(horizontalPadding: 0),
            ),
          ],
        ),
      ),
    );
  }
}
