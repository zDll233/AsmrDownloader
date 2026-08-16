import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/pages/window_title_bar/caption_buttons/window_caption_buttons.dart';
// ignore: unused_import
import 'package:asmr_downloader/pages/window_title_bar/move_window.dart';
import 'package:flutter/material.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({
    super.key,
    this.title,
  });

  final Text? title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.transparent),
      child: MoveWindow(
        child: SizedBox(
          width: double.infinity,
          height: TITLEBAR_HEIGHT,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 11),
                child: Text(
                  'AsmrDownloader',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(child: Container()),
              CaptionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
