import 'dart:io';

import 'package:asmr_downloader/common/config_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/api_providers.dart';
import 'package:asmr_downloader/services/download/download_providers.dart';
import 'package:asmr_downloader/services/asmr_repo/providers/work_info_providers.dart';
import 'package:asmr_downloader/models/track_item.dart';
import 'package:asmr_downloader/services/ui/ui_providers.dart';
import 'package:asmr_downloader/utils/log.dart';
import 'package:asmr_downloader/utils/tool_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

import 'package:path/path.dart' as p;

class DownloadManager {
  final Ref ref;
  DownloadManager(this.ref);

  Future<void> run() async {
    await ref.read(uiServiceProvider).resetProgress();

    // handle error

    final sourceId = ref.read(sourceIdProvider);
    if (sourceId == null) {
      Log.fatal('download failed\n' 'error: sourceId is null');
      return;
    }

    final voiceWorkPath = ref.read(voiceWorkPathProvider);
    if (p.basename(voiceWorkPath) == '-') {
      Log.error('download failed: $sourceId\n'
          'error: voiceWorkPath is invalid, which means you have to start downloading after work info is loaded');
      return;
    }

    // start downloading

    ref.read(dlStatusProvider.notifier).state = DownloadStatus.downloading;
    ref.read(currentDlNoProvider.notifier).state = 0;

    // root Folder cnt
    int rootFolderTaskCnt = 0;
    final rootFolderSnapshot = ref.read(rootFolderProvider)?.copyWith();
    if (rootFolderSnapshot == null) {
      Log.fatal(
          'download tracks failed: $sourceId\n' 'error: rootFolder is null');
    } else {
      rootFolderTaskCnt = countTotalTask(rootFolderSnapshot);
      ref.read(totalTaskCntProvider.notifier).state = rootFolderTaskCnt;
    }

    // download cover
    if (ref.read(dlCoverProvider)) {
      ref.read(totalTaskCntProvider.notifier).state++;
      await _downloadCover(p.join(
        voiceWorkPath,
        sourceId,
        '${sourceId}_cover.jpg',
      ));
    }

    // download root folder
    if (rootFolderTaskCnt > 0) {
      await _downloadTrackItem(rootFolderSnapshot!, voiceWorkPath);
    }

    // download completed

    ref.read(dlStatusProvider.notifier).state = DownloadStatus.completed;
    await WindowsTaskbar.setFlashTaskbarAppIcon(
      mode: TaskbarFlashMode.all | TaskbarFlashMode.timernofg,
      flashCount: 5,
      timeout: const Duration(milliseconds: 500),
    );
  }

  int countTotalTask(Folder rootFolder) {
    int totalTaskCnt = 0;
    for (final child in rootFolder.children) {
      if (child is Folder) {
        totalTaskCnt += countTotalTask(child);
      } else if (child.selected) {
        totalTaskCnt++;
      }
    }
    return totalTaskCnt;
  }

  /// 下载cover
  Future<void> _downloadCover(String savePath) async {
    final coverName = p.basename(savePath);
    final coverBytesAsync = ref.read(coverBytesProvider);
    final bytes = coverBytesAsync.value;

    if (coverBytesAsync is AsyncData && bytes != null) {
      // set download start state
      ref.read(currentFileNameProvider.notifier).state = coverName;
      ref.read(processProvider.notifier).state = 0;
      ref.read(currentDlNoProvider.notifier).state++;

      try {
        // save cover
        final coverFile = File(savePath);
        if (!await coverFile.exists()) {
          await coverFile.create(recursive: true);
        }
        if ((await coverFile.length()) != bytes.length) {
          await coverFile.writeAsBytes(bytes);
        }

        // set download completed state
        ref.read(processProvider.notifier).state = 1;
        await WindowsTaskbar.setProgress(
            ref.read(currentDlNoProvider), ref.read(totalTaskCntProvider));

        Log.info('save cover completed: $coverName' 'savePath: $savePath');
      } catch (e) {
        Log.error('save cover failed: $coverName\n'
            'error: $e');
      }
    } else {
      Log.warning('save cover failed: $coverName\n'
          'error: cover bytes is not ready');

      final coverUrl = ref.read(coverUrlProvider);
      final int? coverSize =
          await ref.read(asmrApiProvider).tryGetContentLength(coverUrl);

      if (coverSize != null) {
        FileAsset coverFileAsset = FileAsset(
          id: coverName,
          type: 'image',
          title: coverName,
          mediaStreamUrl: coverUrl,
          mediaDownloadUrl: coverUrl,
          size: coverSize,
          savePath: savePath,
        )..selected = true;
        await _downloadFileAsset(coverFileAsset);
      } else {
        Log.error('download cover failed: $coverName\n'
            'error: cover size is null');
      }
    }
  }

  Future<void> _downloadTrackItem(
      TrackItem trackItem, String targetDirPath) async {
    final targetPath = p.join(
      targetDirPath,
      getLegalWindowsName(trackItem.title),
    );
    if (trackItem is Folder) {
      for (final child in trackItem.children) {
        await _downloadTrackItem(child, targetPath);
      }
    } else if (trackItem is FileAsset) {
      if (trackItem.selected) {
        trackItem.savePath = targetPath;
        await _downloadFileAsset(trackItem);
      }
    }
  }

  // 开始下载任务
  /// need to specify task.savePath otherwise it will be empty
  Future<void> _downloadFileAsset(FileAsset task) async {
    ref.read(currentFileNameProvider.notifier).state = task.title;
    ref.read(processProvider.notifier).state = 0;
    ref.read(currentDlNoProvider.notifier).state++;

    final dlFlag = await _resumableDownload(
      task.mediaDownloadUrl,
      task.savePath,
      task.size,
      cancelToken: task.cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final progress = received / total;
          // task.progress = progress;
          ref.read(processProvider.notifier).state = progress;
        }
      },
    );

    if (dlFlag) {
      // 如果文件已存在，不会调用onReceiveProgress，需要手动设置进度

      // task.status = DownloadStatus.completed;
      // task.progress = 1;

      ref.read(processProvider.notifier).state = 1;
      await WindowsTaskbar.setProgress(
          ref.read(currentDlNoProvider), ref.read(totalTaskCntProvider));
    }
  }

  Future<void> mergeFile(File file, File tmpFile) async {
    if (await tmpFile.exists()) {
      await file.writeAsBytes(
        await tmpFile.readAsBytes(),
        mode: FileMode.append,
      );
      await tmpFile.delete();
    }
  }

  Future<bool> _resumableDownload(
    String url,
    String savePath,
    int fileSize, {
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final fileName = p.basename(savePath);
    final file = File(savePath);

    final downloadingPath = '$savePath.downloading';
    final downloadingFile = File(downloadingPath);

    final tmpSavePath = '$savePath.downloading.part';
    final tmpFile = File(tmpSavePath);

    // 本地已经下载的文件大小
    int downloadedBytes = 0;
    int tmpFileLen = 0;

    while (true) {
      try {
        if (await file.exists()) {
          Log.info('file already downloaded: $fileName\n'
              'savePath: $savePath');
          return true;
        }

        if (await downloadingFile.exists()) {
          downloadedBytes = await downloadingFile.length();
        }

        if (await tmpFile.exists()) {
          tmpFileLen = await tmpFile.length();
          if (tmpFileLen > 0 && tmpFileLen + downloadedBytes <= fileSize) {
            downloadedBytes += tmpFileLen;
            await mergeFile(downloadingFile, tmpFile);
          } else {
            await tmpFile.delete();
          }
        }

        if (downloadedBytes < fileSize) {
          if (downloadedBytes == 0) {
            Log.info('start downloading: $fileName\n'
                'fileSize: $fileSize\n'
                'url: $url\n'
                'savePath: $savePath');
            await ref.read(asmrApiProvider).download(
                  url,
                  downloadingPath,
                  cancelToken: cancelToken,
                  deleteOnError: false,
                  onReceiveProgress: onReceiveProgress,
                );
          } else {
            Log.info('resume downloading: $fileName\n'
                'downloadedBytes: $downloadedBytes, fileSize: $fileSize\n'
                'url: $url\n'
                'savePath: $savePath');
            await ref.read(asmrApiProvider).download(
              url,
              tmpSavePath,
              cancelToken: cancelToken,
              deleteOnError: false,
              onReceiveProgress: (received, total) {
                onReceiveProgress!(received + downloadedBytes, fileSize);
              },
              options: Options(
                  headers: {'range': 'bytes=$downloadedBytes-$fileSize'}),
            );
          }
        } else if (downloadedBytes == fileSize) {
          if (downloadedBytes == 0) {
            await file.create();
          } else {
            await downloadingFile.rename(savePath);
          }

          Log.info('download completed: $fileName');
          return true;
        } else {
          // downloadedBytes > fileSize

          Log.error('download failed: $fileName\n'
              'error: downloadedBytes > fileSize');
          return false;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 416) {
          Log.error('download failed: $fileName\n'
              'statusCode = 416, range incorrect\n'
              'error: $e');
          return false;
        }

        Log.warning('download failed: $fileName\n' 'error: $e');
        await Future.delayed(Duration(seconds: 3));
      } catch (e) {
        Log.error('download failed: $fileName\n' 'unhandled error: $e');
        return false;
      } finally {
        await mergeFile(downloadingFile, tmpFile);
      }
    }
  }

  // 取消下载任务
  void cancelDownload(FileAsset task) {
    if (!task.cancelToken.isCancelled) {
      task.cancelToken.cancel('下载已取消');
    }
  }
}
