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
  final Color _color = Colors.white70;
  String _inputText = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloading =
        ref.watch(dlStatusProvider) == DownloadStatus.downloading;
    return SizedBox(
      height: 50.0,
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: TextField(
                controller: _controller,
                cursorColor: _color,
                decoration: InputDecoration(
                  hintText: '输入sourceId',
                  border: OutlineInputBorder(),
                  focusedBorder:
                      OutlineInputBorder(borderSide: BorderSide(color: _color)),
                ),
                onChanged: (value) => _inputText = value,
                onSubmitted: (_) =>
                    ref.read(uiServiceProvider).search(_inputText),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5.0),
              child: IconButton(
                onPressed: downloading
                    ? null
                    : () => ref.read(uiServiceProvider).search(_inputText),
                icon: Icon(Icons.search),
              ),
            ),
            IconButton(
              onPressed: downloading
                  ? null
                  : () async {
                      final newSearchText =
                          await ref.read(uiServiceProvider).pasteAndSearch();
                      if (newSearchText != null) {
                        _controller.text = newSearchText;
                        _inputText = newSearchText;
                      }
                    },
              icon: Icon(Icons.content_paste_go),
            ),
          ],
        ),
      ),
    );
  }
}
