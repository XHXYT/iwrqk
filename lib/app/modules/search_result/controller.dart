import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../components/media_preview/media_preview_grid/controller.dart';
import '../../components/search_posts/search_post_controller.dart';
import '../../components/user_preview/users_preview_list/controller.dart';
import '../../data/enums/types.dart';
import '../../data/models/search/search_filter.dart';
import '../../data/models/search/search_filter_config.dart';
import '../../utils/search_syntax.dart';

class SearchResultController extends GetxController
    with GetTickerProviderStateMixin {
  late UsersPreviewListController childUsersController;

  late String keyword;

  late TabController tabController;

  final RxBool _showToTopButton = false.obs;
  bool get showToTopButton => _showToTopButton.value;
  set showToTopButton(bool value) => _showToTopButton.value = value;

  final RxInt currentSegmentIndex = 0.obs;

  final Map<SearchSegment, RxList<SearchFilter>> activeFilters = {
    for (final segment in SearchSegment.values) segment: <SearchFilter>[].obs,
  };

  final List<String> childrenMediaControllerTags = [
    "search_result_videos",
    "search_result_images",
  ];

  List<String> get tabTagList => [
    "_latest",
    "_trending",
    "_popularity",
    "_most_views",
    "_most_likes",
  ];

  final String childUsersControllerTag = "search_result_users";

  @override
  void onInit() {
    super.onInit();

    keyword = Get.arguments;

    tabController = TabController(length: 4, vsync: this);
    tabController.addListener(() {
      currentSegmentIndex.value = tabController.index;
    });

    for (String tag in childrenMediaControllerTags) {
      for (String tabTag in tabTagList) {
        Get.lazyPut(() => MediaPreviewGridController(), tag: tag + tabTag);
      }
    }

    Get.lazyPut(
      () => UsersPreviewListController(),
      tag: childUsersControllerTag,
    );

    childUsersController = Get.find<UsersPreviewListController>(
      tag: childUsersControllerTag,
    );
  }

  SearchSegment get currentSegment =>
      SearchSegment.values[currentSegmentIndex.value];

  /// Keyword + active filters of [segment] → the `query` string for /search.
  String composedKeyword(SearchSegment segment) {
    return composeSearchQuery(keyword, activeFilters[segment]!);
  }

  int activeFilterCount(SearchSegment segment) {
    return activeFilters[segment]!
        .where((f) => f.toQueryString() != null)
        .length;
  }

  void applyFilters(SearchSegment segment, List<SearchFilter> filters) {
    activeFilters[segment]!.assignAll(filters);
    final query = composedKeyword(segment);

    switch (segment) {
      case SearchSegment.videos:
      case SearchSegment.images:
        final baseTag =
            segment == SearchSegment.videos
                ? childrenMediaControllerTags[0]
                : childrenMediaControllerTags[1];
        for (final tabTag in tabTagList) {
          final tag = baseTag + tabTag;
          if (Get.isRegistered<MediaPreviewGridController>(tag: tag)) {
            Get.find<MediaPreviewGridController>(
              tag: tag,
            ).resetSearchKeyword(query);
          }
        }
        break;
      case SearchSegment.users:
        childUsersController.resetKeyword(query);
        break;
      case SearchSegment.threads:
        for (final orderType in [OrderType.relevance, OrderType.date]) {
          final tag = "search_post_${orderType.value}";
          if (Get.isRegistered<SearchPostsController>(tag: tag)) {
            Get.find<SearchPostsController>(tag: tag).resetKeyword(query);
          }
        }
        break;
    }
  }
}
