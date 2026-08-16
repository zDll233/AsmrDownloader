import 'package:asmr_downloader/common/const.dart';
import 'package:asmr_downloader/pages/window_title_bar/caption_buttons/window_caption_buttons.dart';
import 'package:asmr_downloader/pages/window_title_bar/move_window.dart';
import 'package:asmr_downloader/pages/window_title_bar/settings_btn.dart';
import 'package:flutter/material.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({
    super.key,
    this.title,
  });

  final Text? title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.transparent),
      child: MoveWindow(
        child: SizedBox(
          width: double.infinity,
          height: TITLEBAR_HEIGHT,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Container()),
              SettingsBtn(),
              CaptionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
