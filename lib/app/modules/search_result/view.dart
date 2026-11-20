import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iwrqk/app/components/search_posts/search_post.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../components/media_preview/media_preview_grid/widget.dart';
import '../../components/user_preview/users_preview_list/widget.dart';
import '../../data/enums/types.dart';
import '../../data/models/account/settings/media_search_setting.dart';
import '../../data/models/account/settings/users_sort_setting.dart';
import '../../data/models/search/search_filter_config.dart';
import 'controller.dart';
import 'widgets/advanced_filter/page.dart';

class SearchResultPage extends GetView<SearchResultController> {
  const SearchResultPage({super.key});

  List<String> get tabNameList => [
    t.sort.relevance,
    t.sort.latest,
    t.sort.most_views,
    t.sort.most_likes,
  ];

  List<OrderType> get orderTypeList => [
    OrderType.relevance,
    OrderType.date,
    OrderType.views,
    OrderType.likes,
  ];

  Widget _buildTabBar(BuildContext context,[List<Widget> Function()? tabsBuilder]) {
    return Container(
      padding: MediaQuery.of(context).padding.copyWith(bottom: 0, top: 4),
      alignment: Alignment.centerLeft,
      child: TabBar(
        tabAlignment: TabAlignment.start,
        isScrollable: true,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        splashBorderRadius: BorderRadius.circular(8),
        tabs: tabsBuilder!=null?tabsBuilder():tabNameList.map((e) => Tab(text: e)).toList(),
      ),
    );
  }

  Widget _buildVidoesTab(BuildContext context) {
    return DefaultTabController(
      length: tabNameList.length,
      child: Column(
        children: [
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              children: List.generate(
                tabNameList.length,
                (index) => MediaPreviewGrid(
                  sourceType: MediaSourceType.search,
                  searchSetting: MediaSearchSettingModel(
                    keyword: controller.composedKeyword(
                      SearchSegment.videos,
                    ),
                    searchType: SearchType.videos,
                    orderType: orderTypeList[index],
                  ),
                  isHorizontal: true,
                  tag:
                      controller.childrenMediaControllerTags[0] +
                      controller.tabTagList[index],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesTab(BuildContext context) {
    return DefaultTabController(
      length: tabNameList.length,
      child: Column(
        children: [
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              children: List.generate(
                tabNameList.length,
                (index) => MediaPreviewGrid(
                  sourceType: MediaSourceType.search,
                  searchSetting: MediaSearchSettingModel(
                    keyword: controller.composedKeyword(
                      SearchSegment.images,
                    ),
                    searchType: SearchType.images,
                    orderType: orderTypeList[index],
                  ),
                  isHorizontal: true,
                  tag:
                      controller.childrenMediaControllerTags[1] +
                      controller.tabTagList[index],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(BuildContext context) {
    return DefaultTabController(
      length: 2,  //only supports 2 sort type here
      child: Column(
        children: [
          _buildTabBar(context,
              ()=>tabNameList.sublist(0,2).map((e)=>Tab(text: e,)).toList()),
          Expanded(
            child: TabBarView(
              children: List.generate(
                    2,
                    (index) => SearchPost(
                      keyword: controller.composedKeyword(
                        SearchSegment.threads,
                      ),
                      orderType: orderTypeList[index],
                    )
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        shape: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        titleSpacing: 0,
        centerTitle: false,
        title: GestureDetector(
          onTap: () => Get.back(),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              controller.keyword,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        actions: [
          Obx(() {
            final segment = SearchSegment
                .values[controller.currentSegmentIndex.value];
            final count = controller.activeFilterCount(segment);
            return IconButton(
              tooltip: t.searchFilter.title,
              onPressed: () =>
                  Get.to(() => AdvancedFilterPage(segment: segment)),
              icon: Badge(
                isLabelVisible: count > 0,
                label: Text("$count"),
                child: const Icon(Icons.filter_list),
              ),
              );
          }),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 8),
            color: Theme.of(context).colorScheme.surface,
            child: Theme(
              data: ThemeData(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: TabBar(
                controller: controller.tabController,
                tabs: [
                  Tab(text: t.nav.videos),
                  Tab(text: t.nav.images),
                  Tab(text: t.search.users),
                  Tab(text: t.search.threads),
                ],
                isScrollable: true,
                indicatorWeight: 0,
                indicatorPadding: const EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 8,
                ),
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Theme.of(context).colorScheme.onSecondaryContainer,
                labelStyle: const TextStyle(fontSize: 13),
                dividerColor: Colors.transparent,
                unselectedLabelColor: Theme.of(context).colorScheme.outline,
                tabAlignment: TabAlignment.start,
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: controller.tabController,
              children: [
                _buildVidoesTab(context),
                _buildImagesTab(context),
                UsersPreviewList(
                  sourceType: UsersSourceType.search,
                  sortSetting: UsersSortSetting(
                    keyword: controller.composedKeyword(SearchSegment.users),
                  ),
                  tag: controller.childUsersControllerTag,
                ),
                _buildPostsTab(context)
              ],
            ),
          ),
        ],
      ),
    );
  }

}
