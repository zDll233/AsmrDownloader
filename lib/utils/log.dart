import 'dart:io';

import 'package:asmr_downloader/utils/locked_file_output.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import 'package:path/path.dart' as p;

class Log {
  // named constructor
  Log._internal() {
    _logger = kDebugMode
        ? Logger(
            printer: PrettyPrinter(
              methodCount: 0,
              dateTimeFormat: DateTimeFormat.dateAndTime,
            ),
          )
        : Logger(
            filter: ProductionFilter(),
            printer: PrettyPrinter(
                methodCount: 0,
                colors: false,
                dateTimeFormat: DateTimeFormat.dateAndTime),
            output: LockedFileOutput(file: _logFile()),
            level: Level.info,
          );
  }

  /// 日志文件: exe 同级的 `debug/asmr_downloader.log`。
  ///
  /// 多开时所有实例共用这一个文件, 写入由 [LockedFileOutput] 加跨进程锁
  /// 串行化; 超过 5 MB 时持锁轮转成 `.old` (只保留一代)。
  static File _logFile() {
    final logFile = File(p.join('debug', 'asmr_downloader.log'));
    try {
      logFile.parent.createSync(recursive: true);
    } catch (_) {
      // 目录创建失败留给写入时再报, 不影响启动。
    }
    return logFile;
  }

  late final Logger _logger;

  static final Log _instance = Log._internal();
  static Logger get logger => _instance._logger;

  static void trace(String message) {
    _instance._logger.t(message);
  }

  static void debug(String message) {
    _instance._logger.d(message);
  }

  static void info(String message) {
    _instance._logger.i(message);
  }

  static void warning(String message) {
    _instance._logger.w(message);
  }

  static void error(
    String message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _instance._logger.e(
      message,
      time: time,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void fatal(String message) {
    _instance._logger.f(message);
  }
}
