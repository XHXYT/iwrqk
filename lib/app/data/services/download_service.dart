import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_downloader/flutter_downloader.dart' as fd;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:iwrqk/i18n/strings.g.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import '../../utils/directory_extension.dart';
import '../../utils/log_util.dart';
import '../../utils/path_util.dart';
import '../enums/download_task_status.dart';
import '../models/download_task.dart';
import '../models/offline/download_task_media.dart';
import '../providers/storage_provider.dart';

/// 后台 isolate 回调：转发到主 isolate
@pragma('vm:entry-point')
void iwrDownloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName(
    'iwr_downloader_port',
  );
  send?.send([id, status, progress]);
}

class IwrDownloadTaskStatus {
  DownloadTaskStatus status;
  int progress;
  IwrDownloadTaskStatus({required this.status, required this.progress});
}

class DownloadService extends GetxService {
  static DownloadService? _instance;
  static DownloadService? get instance => _instance;

  final int maxDownloadingCount = 5;
  final RxMap<String, Rx<IwrDownloadTaskStatus>> _downloadTasksStatus =
      <String, Rx<IwrDownloadTaskStatus>>{}.obs;
  RxMap<String, Rx<IwrDownloadTaskStatus>> get downloadTasksStatus =>
      _downloadTasksStatus;

  RxInt currentDownloading = 0.obs;

  final ReceivePort _port = ReceivePort();
  bool _initialized = false;

  @override
  void onInit() {
    super.onInit();
    _instance = this;
    resetAllowMediaScan();
    _initDownloader();
  }

  @override
  void onClose() {
    _instance = null;
    IsolateNameServer.removePortNameMapping('iwr_downloader_port');
    _port.close();
    super.onClose();
  }

  void resetAllowMediaScan() {
    allowMediaScan(
      StorageProvider.config.get(
        StorageKey.allowMediaScan,
        defaultValue: false,
      ),
    );
  }

  /// flutter_downloader 初始化（只能成功调用一次）
  Future<void> _initDownloader() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // ignoreSsl: ohos 上默认 false 即可
      await fd.FlutterDownloader.initialize(debug: kDebugMode);
      IsolateNameServer.registerPortWithName(
        _port.sendPort,
        'iwr_downloader_port',
      );
      fd.FlutterDownloader.registerCallback(iwrDownloadCallback, step: 10);
      _port.listen(_handleEvent);
      await _getTasksStatusFromRecords();
    } catch (e) {
      _initialized = false;
      LogUtil.error('FlutterDownloader initialize failed!', e);
    }
  }

  void _handleEvent(Object? data) {
    if (data is! List || data.length < 3) return;
    _handleStatusUpdate(data[0] as String, data[1] as int, data[2] as int);
  }

  void _handleStatusUpdate(String taskId, int statusIndex, int progress) {
    final status = _convertFdStatus(statusIndex);
    final existing = _downloadTasksStatus[taskId];
    if (existing != null) {
      existing.value = IwrDownloadTaskStatus(
        status: status,
        progress: existing.value.progress,
      );
    } else {
      _downloadTasksStatus[taskId] = IwrDownloadTaskStatus(
        status: status,
        progress: progress,
      ).obs;
    }
    _recalculateCurrentDownloading();
    _downloadTasksStatus.refresh();
  }

  void _handleProgressEvent(String taskId, int progress) {
    _downloadTasksStatus.putIfAbsent(
      taskId,
      () => IwrDownloadTaskStatus(
        status: DownloadTaskStatus.running,
        progress: progress,
      ).obs,
    );
    _downloadTasksStatus[taskId]?.value.progress = progress;
    _downloadTasksStatus.refresh();
  }

  void _recalculateCurrentDownloading() {
    currentDownloading.value = _downloadTasksStatus.values
        .where(
          (status) =>
              status.value.status == DownloadTaskStatus.enqueued ||
              status.value.status == DownloadTaskStatus.running,
        )
        .length;
  }

  Future<void> allowMediaScan(bool allow) async {
    final downloadPath = downloadDirectory;
    if (downloadPath == null) {
      return;
    }
    final File noMediaFile = downloadPath.file('.nomedia');
    if (allow && await noMediaFile.exists()) {
      noMediaFile.delete(recursive: true);
    } else if (!allow && !await noMediaFile.exists()) {
      noMediaFile.create(recursive: true);
    }
  }

  Directory? get downloadDirectory {
    final String? savedDir = StorageProvider.config.get(
      StorageKey.downloadDirectory,
      defaultValue: null,
    );
    if (savedDir != null) {
      return Directory(savedDir);
    }
    return PathUtil.getVisibleDir().dir('downloads');
  }

  Future<void> _getTasksStatusFromRecords() async {
    try {
      final tasks = await fd.FlutterDownloader.loadTasks() ?? [];
      for (final task in tasks) {
        _downloadTasksStatus[task.taskId] = IwrDownloadTaskStatus(
          status: _convertFdStatus(task.status.index),
          progress: task.progress,
        ).obs;
      }
    } catch (e) {
      LogUtil.error('Load download task records failed!', e);
    }
    _recalculateCurrentDownloading();
    _downloadTasksStatus.refresh();
  }

  /// fd.DownloadTaskStatus -> 项目枚举
  DownloadTaskStatus _convertFdStatus(int statusIndex) {
    // fd 顺序: undefined, enqueued, running, complete, failed, canceled, paused
    switch (statusIndex) {
      case 1:
        return DownloadTaskStatus.enqueued;
      case 2:
        return DownloadTaskStatus.running;
      case 3:
        return DownloadTaskStatus.complete;
      case 4:
      case 0:
        return DownloadTaskStatus.failed;
      case 5:
        return DownloadTaskStatus.canceled;
      case 6:
        return DownloadTaskStatus.paused;
      default:
        return DownloadTaskStatus.failed;
    }
  }

  Future<bool> checkPermission() async {
    if (!GetPlatform.isAndroid) return true;
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        await Permission.manageExternalStorage.request();
        LogUtil.info(await Permission.manageExternalStorage.status);
        return await Permission.manageExternalStorage.isGranted;
      }
    } on Exception catch (e) {
      LogUtil.error('Request manageExternalStorage permission failed!', e);
      return false;
    }
    try {
      await Permission.storage.request();
      LogUtil.info(await Permission.storage.status);
      return await Permission.storage.isGranted;
    } on Exception catch (e) {
      LogUtil.error('Request storage permission failed!', e);
      return false;
    }
  }

  bool checkPermissionForPath(String path) {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final testFile = dir.file('.iwrqktest');
      testFile.writeAsStringSync('');
      testFile.deleteSync();
    } on FileSystemException catch (e) {
      LogUtil.error('${'invalidPath'.tr}:$path', e);
      return false;
    }
    return true;
  }

  Future<String?> addDownloadTask({
    required String downloadUrl,
    required String fileName,
    required String subDirectory,
  }) async {
    bool hasPermission = await checkPermission();
    if (!hasPermission) {
      SmartDialog.showToast(t.message.download.no_provide_storage_permission);
      return null;
    }
    final bool isOhos = !kIsWeb && defaultTargetPlatform == TargetPlatform.ohos;

    Directory? directory = downloadDirectory;
    if (directory == null) {
      SmartDialog.showToast(t.message.download.no_provide_storage_permission);
      return null;
    }

    Directory path = directory.dir(subDirectory);
    if (!path.existsSync()) {
      path.createSync(recursive: true);
    }

    // 查重：仅当磁盘上实际存在同名文件时才拦截，
    // 避免插件库残留记录（删除失败/只删应用层记录）导致无法重新下载
    try {
      final tasks = await fd.FlutterDownloader.loadTasks() ?? [];
      bool hasExisted = false;
      for (final task in tasks) {
        if (basename(task.savedDir) != subDirectory) continue;
        if (task.filename != fileName) continue;
        // ohos 上 savedDir 存的是相对子目录，需拼回完整路径再验证
        final String dirPath = isAbsolute(task.savedDir)
            ? task.savedDir
            : join(directory.path, task.savedDir);
        final file = Directory(dirPath).file(task.filename ?? '');
        if (file.existsSync()) {
          hasExisted = true;
          break;
        }
      }
      if (hasExisted) {
        SmartDialog.showToast(t.message.download.task_already_exists);
        return null;
      }
    } on Exception catch (e) {
      LogUtil.error('Check existed download tasks failed!', e);
    }

    final taskId = await fd.FlutterDownloader.enqueue(
      url: downloadUrl,
      savedDir: isOhos ? subDirectory : path.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: false,
      // ohos 上 false = 写应用沙箱，无需额外存储权限
      saveInPublicStorage: false,
      allowCellular: true,
    );

    if (taskId != null) {
      _downloadTasksStatus[taskId] = IwrDownloadTaskStatus(
        status: DownloadTaskStatus.enqueued,
        progress: 0,
      ).obs;
      _recalculateCurrentDownloading();
      _downloadTasksStatus.refresh();
    }
    return taskId;
  }

  Future<VideoDownloadTask?> createVideoDownloadTask({
    required String url,
    required String resolutionName,
    required DownloadTaskMediaModel offlineMedia,
  }) async {
    String? downloadTaskId;
    DateTime now = DateTime.now();
    Uri uri = Uri.parse(url);
    int expireTime = int.parse(uri.queryParameters['expires']!);
    String fileName = uri.queryParameters['filename']!;

    downloadTaskId = await addDownloadTask(
      downloadUrl: url,
      fileName: resolutionName + extension(fileName),
      subDirectory: offlineMedia.title,
    );

    if (downloadTaskId != null) {
      VideoDownloadTask task = VideoDownloadTask(
        taskId: downloadTaskId,
        createTime: now,
        expireTime: expireTime,
        resolutionName: resolutionName,
        offlineMedia: offlineMedia,
      );
      return task;
    } else {
      return null;
    }
  }

  Future<bool> addVideoDownloadTask({
    required String url,
    required String resolutionName,
    required DownloadTaskMediaModel offlineMedia,
  }) async {
    var task = await createVideoDownloadTask(
      url: url,
      resolutionName: resolutionName,
      offlineMedia: offlineMedia,
    );
    if (task != null) {
      _downloadTasksStatus.putIfAbsent(
        task.taskId,
        () => IwrDownloadTaskStatus(
          status: DownloadTaskStatus.enqueued,
          progress: 0,
        ).obs,
      );
      _recalculateCurrentDownloading();
      _downloadTasksStatus.refresh();
      StorageProvider.downloadVideoRecords.add(task);
      return true;
    } else {
      return false;
    }
  }

  /// 注意：返回类型从 bg.TaskRecord? 改为 fd.DownloadTask?
  Future<fd.DownloadTask?> getTask(String taskId) async {
    try {
      final tasks = await fd.FlutterDownloader.loadTasks() ?? [];
      for (final task in tasks) {
        if (task.taskId == taskId) return task;
      }
    } on Exception catch (e) {
      LogUtil.error('Get download task failed!', e);
    }
    return null;
  }

  Future<int> get currentDownloadingCount async {
    try {
      final tasks = await fd.FlutterDownloader.loadTasks() ?? [];
      return tasks
          .where((task) => task.status == fd.DownloadTaskStatus.running)
          .length;
    } on Exception catch (e) {
      LogUtil.error('Get currentDownloadingCount failed!', e);
      return 0;
    }
  }

  Future<String?> getTaskFilePath(String taskId) async {
    final task = await getTask(taskId);
    if (task == null) return null;
    final String dirPath = isAbsolute(task.savedDir)
        ? task.savedDir
        : join(downloadDirectory?.path ?? '', task.savedDir);
    return Directory(dirPath).file(task.filename ?? '').path;
  }

  Future<void> pauseTask(String taskId) async {
    try {
      await fd.FlutterDownloader.pause(taskId: taskId);
    } on Exception catch (e) {
      LogUtil.error('Pause download task failed!', e);
    }
  }

  void refreshTask(String taskId, String newTaskId) {
    _downloadTasksStatus.addAll({
      newTaskId: IwrDownloadTaskStatus(
        status: DownloadTaskStatus.enqueued,
        progress: 0,
      ).obs,
    });
    _downloadTasksStatus.remove(taskId);
    _recalculateCurrentDownloading();
    _downloadTasksStatus.refresh();
  }

  Future<String?> resumeTask(String taskId) async {
    try {
      // ohos/Android 上 resume 成功会返回新 taskId，必须同步本地映射
      final newId = await fd.FlutterDownloader.resume(taskId: taskId);
      if (newId != null) {
        refreshTask(taskId, newId);
        return newId;
      }
      return taskId;
    } on Exception catch (e) {
      LogUtil.error('Resume download task failed!', e);
      return null;
    }
  }

  Future<String?> retryTask(String taskId) async {
    try {
      final newId = await fd.FlutterDownloader.retry(taskId: taskId);
      if (newId != null) {
        refreshTask(taskId, newId);
        return newId;
      }
      return taskId;
    } on Exception catch (e) {
      LogUtil.error('Retry download task failed!', e);
      return null;
    }
  }

  Future<void> cancelTask(String taskId) async {
    try {
      await fd.FlutterDownloader.cancel(taskId: taskId);
    } on Exception catch (e) {
      LogUtil.error('Cancel download task failed!', e);
    }
  }

  Future<void> deleteTaskRecord(String taskId) async {
    try {
      // shouldDeleteContent: false = 只删记录，保留已下载文件
      await fd.FlutterDownloader.remove(
        taskId: taskId,
        shouldDeleteContent: false,
      );
    } on Exception catch (e) {
      LogUtil.error('Delete download task record failed!', e);
    }
    _downloadTasksStatus.remove(taskId);
    _recalculateCurrentDownloading();
    _downloadTasksStatus.refresh();
  }
}
