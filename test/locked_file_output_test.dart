import 'dart:convert';
import 'dart:io';

import 'package:asmr_downloader/utils/locked_file_output.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

void main() {
  late Directory dir;
  late File logFile;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('asmr_locked_log_');
    logFile = File('${dir.path}${Platform.pathSeparator}asmr_downloader.log');
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {
      // 临时目录清理失败不影响测试结果。
    }
  });

  Logger createLogger({int maxBytes = 5 * 1024 * 1024}) => Logger(
        filter: ProductionFilter(),
        printer: PrettyPrinter(methodCount: 0, colors: false),
        output: LockedFileOutput(file: logFile, maxBytes: maxBytes),
        level: Level.info,
      );

  /// 日志正文行 (带 💡 标记)。
  List<String> bodyLines(File file) =>
      file.readAsLinesSync().where((line) => line.contains('💡')).toList();

  test('写入完整且顺序正确, 中文不会乱码', () async {
    final logger = createLogger();
    for (var i = 0; i < 30; i++) {
      logger.i('第 $i 行 中文日志');
    }
    await logger.close();

    final bodies = bodyLines(logFile);
    expect(bodies, hasLength(30));
    for (var i = 0; i < 30; i++) {
      expect(bodies[i], contains('第 $i 行 中文日志'));
    }

    // 严格 UTF-8 解码, 多字节字符不能被切开。
    expect(
      () => utf8.decode(logFile.readAsBytesSync()),
      returnsNormally,
    );

    // 跨进程锁文件已创建。
    expect(File('${logFile.path}.lock').existsSync(), isTrue);
  });

  test('超过阈值时轮转成 .old, 只保留一代', () async {
    // maxBytes 为 0: 每次写入前都会把上一代轮转成 .old,
    // 因此最终 .old 里只有倒数第二条, 当前文件里只有最后一条。
    final logger = createLogger(maxBytes: 0);
    for (var i = 0; i < 5; i++) {
      logger.i('事件 $i');
    }
    await logger.close();

    final oldFile = File('${logFile.path}.old');
    expect(oldFile.existsSync(), isTrue);

    final oldBodies = bodyLines(oldFile);
    final nowBodies = bodyLines(logFile);
    expect(oldBodies, hasLength(1));
    expect(nowBodies, hasLength(1));
    expect(oldBodies.single, contains('事件 3'));
    expect(nowBodies.single, contains('事件 4'));
  });

  test('目录不存在时会自动创建', () async {
    final nested = File(
      '${dir.path}${Platform.pathSeparator}debug${Platform.pathSeparator}a.log',
    );
    final logger = Logger(
      filter: ProductionFilter(),
      printer: PrettyPrinter(methodCount: 0, colors: false),
      output: LockedFileOutput(file: nested),
      level: Level.info,
    );
    logger.i('nested');
    await logger.close();

    expect(nested.existsSync(), isTrue);
    expect(bodyLines(nested), hasLength(1));
  });
}
