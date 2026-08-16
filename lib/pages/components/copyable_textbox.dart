import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyableTextBox extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final Color backgroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const CopyableTextBox({
    super.key,
    required this.text,
    this.textStyle,
    this.backgroundColor = Colors.transparent,
    this.borderRadius = 5.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
  });

  @override
  Widget build(BuildContext context) {
    // 波纹颜色跟随文字颜色: 浅色标签(黑字)用深色波纹, 深色背景(浅字)用浅色波纹
    final inkColor =
        textStyle?.color ?? Theme.of(context).colorScheme.onSurface;
    return Tooltip(
      message: '复制',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async =>
              await Clipboard.setData(ClipboardData(text: text)),
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: inkColor.withValues(alpha: 0.18),
          hoverColor: inkColor.withValues(alpha: 0.08),
          child: Ink(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Text(text, style: textStyle),
          ),
        ),
      ),
    );
  }
}
