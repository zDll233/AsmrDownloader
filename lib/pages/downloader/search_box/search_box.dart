import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/models/track_item.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SearchBox extends ConsumerStatefulWidget {
  const SearchBox({super.key});

  @override
  SearchBoxState createState() => SearchBoxState();
}

class SearchBoxState extends ConsumerState<SearchBox> {
  final TextEditingController _controller = TextEditingController();
  String _inputText = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(
          const Duration(milliseconds: PASTE_SEARCH_DELAY_MS + 20));
      final currentSearchText = ref.read(searchTextProvider);
      if (currentSearchText != null) {
        _controller.text = currentSearchText;
        _inputText = currentSearchText;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 下载中 / 搜索请求进行中都不接受新的搜索。
    final busy = ref.watch(dlStatusProvider) == DownloadStatus.downloading ||
        ref.watch(workInfoLoadingStateProvider).isLoading;

    void submit() {
      if (busy) return;
      ref.read(uiServiceProvider).search(_inputText);
    }

    return SizedBox(
      height: 50.0,
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '输入sourceId',
              ),
              onChanged: (value) => _inputText = value,
              onSubmitted: (_) => submit(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2.0),
            child: IconButton(
              onPressed: busy ? null : submit,
              tooltip: '搜索',
              icon: Icon(Icons.search),
            ),
          ),
          IconButton(
            onPressed: busy
                ? null
                : () async {
                    final newSearchText =
                        await ref.read(uiServiceProvider).pasteAndSearch();
                    if (newSearchText != null) {
                      _controller.text = newSearchText;
                      _inputText = newSearchText;
                    }
                  },
            tooltip: '粘贴并搜索',
            icon: Icon(Icons.content_paste_go),
          ),
        ],
      ),
    );
  }
}
