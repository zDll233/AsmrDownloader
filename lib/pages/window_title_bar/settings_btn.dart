import 'package:asmr_downloader/pages/settings/settings_page.dart';
import 'package:flutter/material.dart';

/// 打开设置页面的按钮 (参考 Again 项目)。
class SettingsBtn extends StatelessWidget {
  const SettingsBtn({
    super.key,
    this.buttonWidth = 46.0,
    this.buttonHeight = 32.0,
  });

  final double buttonWidth;
  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      },
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: buttonWidth,
        height: buttonHeight,
      ),
      tooltip: '设置',
      icon: const Icon(
        Icons.settings_outlined,
        color: Color.fromRGBO(255, 255, 255, 0.5),
      ),
    );
  }
}
