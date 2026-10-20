import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../components/media_preview/media_preview_grid/controller.dart';

class MediaGridTabController extends GetxController
    with GetTickerProviderStateMixin {
  late TabController tabController;
  late List<ScrollController> scrollControllers;

  late List<String> _tabTagList;

  /// [init] 尚未被调用时（对应页面从未构建过）为 false，
  /// 此时刷新/滚动相关方法直接跳过，避免 LateInitializationError
  bool _initialized = false;

  void init({required List<String> tagList}) {
    _tabTagList = tagList;
    tabController = TabController(length: tagList.length, vsync: this);
    scrollControllers = List.generate(
      tagList.length,
      (index) => ScrollController(),
    );
    for (String tag in _tabTagList) {
      Get.lazyPut(() => MediaPreviewGridController(), tag: tag);
    }
    _initialized = true;
  }

  void scrollToTop() {
    if (!_initialized) {
      return;
    }
    ScrollController controller = scrollControllers[tabController.index];
    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
  }

  void scrollToTopRefresh() {
    if (!_initialized) {
      return;
    }
    ScrollController controller = scrollControllers[tabController.index];
    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    }
    refreshCurrentTab();
  }

  void refreshCurrentTab() {
    if (!_initialized) {
      return;
    }
    MediaPreviewGridController targetController =
        Get.find<MediaPreviewGridController>(
          tag: _tabTagList[tabController.index],
        );

    targetController.resetScrollPosition();
    targetController.refreshData(showSplash: true);
  }
}
