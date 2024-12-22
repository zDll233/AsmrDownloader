import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

List<Widget> ellipsisInMiddle(
  String nameWithExt, {
  TextStyle textStyle = const TextStyle(
    height: 1.0,
  ),
  // "Leading Distribution and Trimming"部分, https://api.flutter.dev/flutter/painting/TextStyle-class.html
  TextHeightBehavior textHeightBehavior = const TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  ),
}) {
  final ext = p.extension(nameWithExt);
  return ext.isEmpty
      ? <Widget>[
          Text(
            nameWithExt,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
            textHeightBehavior: textHeightBehavior,
          )
        ]
      : <Widget>[
          Flexible(
            child: Text(
              nameWithExt.split(ext)[0],
              overflow: TextOverflow.ellipsis,
              style: textStyle,
              textHeightBehavior: textHeightBehavior,
            ),
          ),
          Text(
            ext,
            style: textStyle,
            textHeightBehavior: textHeightBehavior,
          ),
        ];
}
