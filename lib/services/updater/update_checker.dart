import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:asmr_downloader/utils/log.dart';
import 'package:ffi/ffi.dart';
import 'package:http/http.dart' as http;

DynamicLibrary? _shell32;

DynamicLibrary get _shell32Lib {
  return _shell32 ??= DynamicLibrary.open('shell32.dll');
}

typedef _ShellExecuteWNative = Pointer<Void> Function(Pointer<Void>,
    Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Int32);
typedef _ShellExecuteWDart = Pointer<Void> Function(Pointer<Void>,
    Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, int);
final _ShellExecuteWDart _shellExecuteW =
    _shell32Lib.lookupFunction<_ShellExecuteWNative, _ShellExecuteWDart>(
        'ShellExecuteW');

/// 隐藏窗口启动程序 (SW_HIDE), 无 PowerShell/cmd 中间层, 参数直传。
void _launchHidden(String file, String arguments) {
  final filePtr = file.toNativeUtf16();
  final argsPtr = arguments.toNativeUtf16();
  final verbPtr = 'open'.toNativeUtf16();
  try {
    _shellExecuteW(nullptr, verbPtr, filePtr, argsPtr, nullptr, 0 /*SW_HIDE*/);
  } finally {
    calloc.free(filePtr);
    calloc.free(argsPtr);
    calloc.free(verbPtr);
  }
}

/// 当前应用版本 (CI 构建时通过 --dart-define=APP_VERSION 注入, 本地为 dev)。
const String kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// 检查更新结果。
class UpdateCheckResult {
  final String latestTag; // 如 v0.2.9
  final String? zipUrl; // Release 压缩包资产 URL
  final String? releaseUrl; // Release 页面

  const UpdateCheckResult({
    required this.latestTag,
    this.zipUrl,
    this.releaseUrl,
  });

  /// 最新版本是否比当前版本新。
  bool get hasUpdate => compareVersions(latestTag, kAppVersion) > 0;
}

/// 比较版本号 (v1.2.3 风格, 忽略 v 前缀), 返回正数/0/负数。
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final na = i < pa.length ? pa[i] : 0;
    final nb = i < pb.length ? pb[i] : 0;
    if (na != nb) return na - nb;
  }
  return 0;
}

List<int> _parts(String version) {
  return version
      .replaceFirst('v', '')
      .split('.')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList();
}

/// 清理历史更新残留的临时目录 (asmr_update_*)。
Future<void> cleanStaleUpdateDirs() async {
  try {
    final tempDir = await Directory.systemTemp.createTemp('asmr_update_');
    final tempRoot = tempDir.parent;
    await tempDir.delete(recursive: true);
    await for (final entity in tempRoot.list()) {
      if (entity is Directory &&
          entity.path.contains('asmr_update_')) {
        await entity.delete(recursive: true);
      }
    }
  } catch (e) {
    Log.error('Clean stale update dirs error: $e');
  }
}

/// 查询 GitHub 最新 Release。
Future<UpdateCheckResult?> checkForUpdate() async {
  // 顺手清理历史下载残留
  unawaited(cleanStaleUpdateDirs());
  try {
    final resp = await http.get(
      Uri.parse(
          'https://api.github.com/repos/zDll233/AsmrDownloader/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      Log.info('Check update failed: HTTP ${resp.statusCode}');
      return null;
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String?) ?? '';
    final assets = (json['assets'] as List<dynamic>?) ?? [];
    String? zipUrl;
    for (final asset in assets) {
      final name = (asset as Map<String, dynamic>)['name'] as String? ?? '';
      if (name.endsWith('.zip')) {
        zipUrl = asset['browser_download_url'] as String?;
        break;
      }
    }
    return UpdateCheckResult(
      latestTag: tag,
      zipUrl: zipUrl,
      releaseUrl: json['html_url'] as String?,
    );
  } catch (e) {
    Log.error('Check update error: $e');
    return null;
  }
}

/// 流式下载 zip 到临时目录, 返回本地路径; [onProgress] 回调已下载/总字节。
Future<String?> downloadUpdateZip(
  String url, {
  void Function(int received, int total)? onProgress,
}) async {
  final client = http.Client();
  try {
    final resp = await client
        .send(http.Request('GET', Uri.parse(url)))
        .timeout(const Duration(minutes: 10));
    if (resp.statusCode != 200) {
      Log.error('Download update failed: HTTP ${resp.statusCode}');
      return null;
    }
    final total = resp.contentLength ?? 0;
    final tempDir = await Directory.systemTemp.createTemp('asmr_update_');
    final zipPath =
        '${tempDir.path}${Platform.pathSeparator}update.zip';
    final sink = File(zipPath).openWrite();
    var received = 0;
    try {
      await for (final chunk in resp.stream) {
        received += chunk.length;
        sink.add(chunk);
        onProgress?.call(received, total);
      }
      await sink.close();
    } catch (e) {
      await sink.close();
      Log.error('Download update error: $e');
      return null;
    }
    return zipPath;
  } catch (e) {
    Log.error('Download update error: $e');
    return null;
  } finally {
    client.close();
  }
}

/// 启动更新安装脚本并退出应用。
/// 脚本等待应用退出后解压覆盖 Release 目录, 再重启应用。
/// 执行过程写入 update_log.txt 便于排查。
/// 仅 Windows 支持 (zip 覆盖模式对 Android APK 无意义)。
Future<void> applyUpdate(String zipPath) async {
  if (!Platform.isWindows) return;
  final exePath = Platform.resolvedExecutable;
  final appDir = File(exePath).parent.path;
  final batPath = '$appDir${Platform.pathSeparator}update_asmr.bat';
  final logPath = '$appDir${Platform.pathSeparator}update_log.txt';
  final script = '''
@echo off
echo %date% %time% start >> "%LOG%"
timeout /t 2 /nobreak > nul
taskkill /f /im AsmrDownloader.exe > nul 2>&1
ping -n 3 127.0.0.1 > nul
echo %date% %time% killed >> "%LOG%"
powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath '%ZIP%' -DestinationPath '%DIR%'" >> "%LOG%" 2>&1
echo %date% %time% extracted >> "%LOG%"
if exist "%DIR%\\AsmrDownloader.exe" (
  echo %date% %time% done >> "%LOG%"
  del "%LOG%"
) else (
  echo %date% %time% FAILED: exe missing >> "%LOG%"
)
start "" "%DIR%\\AsmrDownloader.exe"
del "%~f0"
''';
  Log.info('applyUpdate: zip=$zipPath appDir=$appDir');
  try {
    await File(batPath).writeAsString(
      script
          .replaceAll('%ZIP%', zipPath)
          .replaceAll('%DIR%', appDir)
          .replaceAll('%LOG%', logPath),
    );
    // 隐藏窗口启动 cmd 执行脚本 (ShellExecuteW SW_HIDE, 无黑窗口);
    // 必须等待子进程启动, 否则 exit(0) 会杀死尚未创建的子进程
    _launchHidden('cmd.exe', '/c "$batPath"');
    await Future<void>.delayed(const Duration(milliseconds: 800));
  } catch (e) {
    Log.error('applyUpdate failed: $e');
  }
  exit(0);
}
