bool isSourceIdValid(String sourceId) =>
    RegExp(r'^(RJ|VJ|BJ)?\d+$', caseSensitive: false).hasMatch(sourceId);

String getLegalWindowsName(String name) {
  return name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // 移除非法字符
      .replaceAll(RegExp(r'\.+$'), '') // 移除末尾句点
      .trim(); // 移除前后空格
}

String getSizeString(int bytes) {
  final kb = 1024;
  final mb = kb * 1024;
  final gb = mb * 1024;

  if (bytes < kb) {
    return '$bytes B';
  } else if (bytes < mb) {
    return '${(bytes / kb).toStringAsFixed(2)} KB';
  } else if (bytes < gb) {
    return '${(bytes / mb).toStringAsFixed(2)} MB';
  } else {
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }
}
