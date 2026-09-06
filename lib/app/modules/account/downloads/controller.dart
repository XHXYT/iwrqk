import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_downloader/flutter_downloader.dart' as fd;

import '../../../utils/log_util.dart';
import '../../../data/providers/storage_provider.dart';
import '../../../data/services/download_service.dart';
import 'widgets/downloads_media_preview_list/controller.dart';

class DownloadsController extends GetxController
    with GetSingleTickerProviderStateMixin {
  final DownloadService downloadService = Get.find();

  Map<String, DownloadsMediaPreviewListController> childrenControllers = {};
  late List<String> childrenControllerTags;

  final RxBool _enableMultipleSelection = false.obs;
  bool get enableMultipleSelection => _enableMultipleSelection.value;
  set enableMultipleSelection(bool value) =>
      _enableMultipleSelection.value = value;

  List checkedList = [];

  final RxInt _checkedCount = 0.obs;
  int get checkedCount => _checkedCount.value;
  set checkedCount(int value) => _checkedCount.value = value;

  late TabController tabController;

  @override
  void onInit() {
    super.onInit();

    tabController = TabController(length: 2, vsync: this);

    childrenControllerTags = List.generate(
      2,
      (index) => "downloads_list_$index",
    );

    for (String tag in childrenControllerTags) {
      Get.lazyPut(() => DownloadsMediaPreviewListController(), tag: tag);
    }
  }

  void toggleChecked(String id, [bool all = false]) {
    if (checkedList.contains(id)) {
      checkedList.remove(id);
      checkedCount--;
    } else {
      checkedList.add(id);
      checkedCount++;
    }
    update();
  }

  void toggleCheckedAll() {
    childrenControllers[childrenControllerTags[tabController.index]]
        ?.toggleCheckedAll();
    update();
  }

  Future<void> deleteTask(String taskId) async {
    String? path = await downloadService.getTaskFilePath(taskId);
    await downloadService.deleteTaskRecord(taskId);

    if (path == null) return;

    File downloadFile = File(path);
    if (await downloadFile.exists()) {
      await downloadFile.delete();
    }
    Directory downloadDir = downloadFile.parent;
    if (await downloadDir.exists() && downloadDir.listSync().isEmpty) {
      await downloadDir.delete();
    }
  }

  Future<void> deleteChecked() async {
    for (String hash in checkedList) {
      final record = StorageProvider.downloadVideoRecords.findWhere(
        (element) => element.hash == hash,
      );
      if (record != null) {
        await deleteTask(record.taskId);
        StorageProvider.downloadVideoRecords.deleteWhere(
          (element) => element.hash == hash,
        );
      }
    }
    checkedList.clear();
    checkedCount = 0;
    await refreshDownloadsList();
  }

  Future<void> refreshDownloadsList() async {
    for (String tag in childrenControllerTags) {
      await childrenControllers[tag]?.refreshData(showSplash: true);
    }
  }

  Future<void> cleanDownloadVideoRecords() async {
    // 插件层任务也要清掉，否则残留任务会在重下时触发"任务已存在"
    try {
      final tasks = await fd.FlutterDownloader.loadTasks() ?? [];
      for (final task in tasks) {
        await downloadService.deleteTaskRecord(task.taskId);
      }
    } on Exception catch (e) {
      LogUtil.error('Clean plugin download tasks failed!', e);
    }
    await StorageProvider.downloadVideoRecords.clean();
    await refreshDownloadsList();
  }
}
