import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iwrqk/i18n/strings.g.dart';

import '../../../components/plugin/pl_player/index.dart';
import '../../../data/models/download_task.dart';
import '../../../data/models/resolution.dart';
import '../../../data/providers/storage_provider.dart';
import '../../../data/services/plugin/pl_player/service_locator.dart';
import '../../../routes/pages.dart';
import '../controller.dart';

class HeaderControl extends StatefulWidget implements PreferredSizeWidget {
  const HeaderControl({
    this.controller,
    this.videoDetailCtr,
    this.floating,
    super.key,
  });
  final PlPlayerController? controller;
  final MediaDetailController? videoDetailCtr;
  final Floating? floating;

  @override
  State<HeaderControl> createState() => _HeaderControlState();

  @override
  Size get preferredSize => throw UnimplementedError();
}

class _HeaderControlState extends State<HeaderControl> {
  List<ResolutionModel> resolutions = [];
  List<PlaySpeed> playSpeed = PlaySpeed.values;
  static const TextStyle subTitleStyle = TextStyle(fontSize: 14);
  static const TextStyle titleStyle = TextStyle(fontSize: 16);
  Size get preferredSize => const Size(double.infinity, kToolbarHeight);
  late List<double> speedsList;
  double buttonSpace = 8;
  GStorageConfig setting = StorageProvider.config;

  @override
  void initState() {
    super.initState();
    resolutions = widget.videoDetailCtr!.resolutions;
    speedsList = widget.controller!.speedsList;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller!;
    final RxBool showWindowsPipButton =
        (GetPlatform.isWindows &&
        (widget.videoDetailCtr?.canUseWindowsPip ?? false)).obs;
    const TextStyle textStyle = TextStyle(color: Colors.white, fontSize: 12);
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      primary: false,
      centerTitle: false,
      automaticallyImplyLeading: false,
      titleSpacing: 8,
      title: Row(
        children: [
          ComBtn(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            fuc: () => <Set<void>>{
              if (widget.controller!.isFullScreen.value)
                <void>{widget.controller!.triggerFullScreen(status: false)}
              else
                <void>{
                  if (MediaQuery.of(context).orientation ==
                      Orientation.landscape)
                    {
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                      ]),
                    },
                  Get.back(),
                },
            },
          ),
          SizedBox(width: buttonSpace),
          ComBtn(
            icon: const Icon(Icons.home, color: Colors.white),
            fuc: () async {
              // 播放器销毁交给 MediaDetailPage.dispose 的正常卸载路径，
              // 此处提前 dispose 会导致仍挂载的 VideoTexture 访问已销毁的 notifier 而崩溃
              if (widget.controller!.isFullScreen.value) {
                await widget.controller!.triggerFullScreen(status: false);
              }
              if (!context.mounted) return;
              Navigator.popUntil(context, ModalRoute.withName(AppRoutes.home));
            },
          ),
          SizedBox(width: buttonSpace),
          Expanded(
            child: Text(widget.videoDetailCtr?.media.title??"",
                style: titleStyle,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.left,   ),
          ),
          SizedBox(width: buttonSpace),
          if (GetPlatform.isAndroid || showWindowsPipButton.value) ...<Widget>[
            Obx(
              () => ComBtn(
                icon: Icon(
                  showWindowsPipButton.value &&
                          (widget.videoDetailCtr?.isWindowsPipMode ?? false)
                      ? Icons.close_fullscreen
                      : Icons.picture_in_picture,
                  size: 20,
                  color: Colors.white,
                ),
                fuc: () async {
                  widget.controller!.hiddenControls(false);
                  if (showWindowsPipButton.value) {
                    await widget.videoDetailCtr!.toggleWindowsPip();
                    return;
                  }

                  bool canUsePiP = false;
                  try {
                    canUsePiP = await widget.floating!.isPipAvailable;
                  } on PlatformException catch (_) {
                    canUsePiP = false;
                  }
                  if (canUsePiP) {
                    final Rational aspectRatio =
                        widget.videoDetailCtr?.aspectRatio ??
                        const Rational(16, 9);
                    await widget.floating!.enable(
                      ImmediatePiP(aspectRatio: aspectRatio),
                    );
                  }
                },
              ),
            ),
            SizedBox(width: buttonSpace),
          ],
          if (MediaQuery.of(context).orientation == Orientation.landscape) ...[
            Obx(
              () => SizedBox(
                height: 34,
                child: TextButton(
                  onPressed: () => showSetSpeedSheet(),
                  child: Text('${controller.playbackSpeed}X', style: textStyle),
                ),
              ),
            ),
            SizedBox(width: buttonSpace),
            SizedBox(
              height: 34,
              child: TextButton(
                onPressed: widget.videoDetailCtr!.isOffline
                    ? null
                    : () => showResolutionSheet(),
                child: Text(
                  widget.videoDetailCtr!.isOffline
                      ? (widget.videoDetailCtr!.taskData as VideoDownloadTask)
                            .resolutionName
                      : widget
                            .videoDetailCtr!
                            .resolutions[widget.videoDetailCtr!.resolutionIndex]
                            .name,
                  style: textStyle,
                ),
              ),
            ),
          ],
          ComBtn(
            icon: const Icon(Icons.more_vert_outlined, color: Colors.white),
            fuc: () => showSettingSheet(),
          ),
        ],
      ),
    );
  }

  /// 半模态在根 Navigator 上，拿不到详情页的动态取色 Theme，
  /// 需显式套一层与详情页一致的 ColorScheme
  ColorScheme get sheetColorScheme =>
      widget.videoDetailCtr?.dominantColorScheme.value ??
      Theme.of(context).colorScheme;

  Widget sheetThemeWrapper(Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: sheetColorScheme),
      child: child,
    );
  }

  /// 设置面板
  void showSettingSheet() {
    showModalBottomSheet(
      elevation: 0,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return sheetThemeWrapper(
          Container(
            height: Get.height * 0.6,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: sheetColorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 36,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sheetColorScheme.onSecondaryContainer.withAlpha(
                          (0.5 * 255).round(),
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Material(
                    color: sheetColorScheme.surface,
                    child: ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.hd),
                          title: Text(t.player.quality, style: titleStyle),
                          subtitle: Text(
                            t.player.current_item(
                              item: widget.videoDetailCtr!.isOffline
                                  ? (widget.videoDetailCtr!.taskData
                                              as VideoDownloadTask)
                                          .resolutionName
                                  : widget
                                        .videoDetailCtr!
                                        .resolutions[widget
                                            .videoDetailCtr!
                                            .resolutionIndex]
                                        .name,
                            ),
                            style: subTitleStyle,
                          ),
                          onTap: widget.videoDetailCtr!.isOffline
                              ? null
                              : () => {Get.back(), showResolutionSheet()},
                        ),
                        ListTile(
                          leading: const Icon(Icons.speed),
                          title: Text(
                            t.player.playback_speed,
                            style: titleStyle,
                          ),
                          subtitle: Text(
                            t.player.current_item(
                              item: '${widget.controller!.playbackSpeed}X',
                            ),
                            style: subTitleStyle,
                          ),
                          onTap: () => {Get.back(), showSetSpeedSheet()},
                        ),
                        ListTile(
                          leading: const Icon(Icons.rectangle),
                          title: Text(t.player.aspect_ratio, style: titleStyle),
                          subtitle: Text(
                            t.player.current_item(
                              item: widget.controller!.videoFitDEsc.value,
                            ),
                            style: subTitleStyle,
                          ),
                          onTap: () => {Get.back(), showVideoFitSheet()},
                        ),
                        StatefulBuilder(
                          builder: (context, setState) {
                            return SwitchListTile(
                              secondary: const Icon(Icons.music_video),
                              title: Text(
                                t.settings.background_play,
                                style: titleStyle,
                              ),
                              subtitle: Text(
                                t.settings.background_play_desc,
                                style: subTitleStyle,
                              ),
                              value:
                                  videoPlayerServiceHandler
                                      .enableBackgroundPlay
                                      .value,
                              onChanged: (value) {
                                if (!value) {
                                  // 关闭前先同步播控状态，避免系统播控残留"播放中"
                                  videoPlayerServiceHandler.clear();
                                }
                                videoPlayerServiceHandler
                                    .enableBackgroundPlay
                                    .value = value;
                                StorageProvider.config[PLPlayerConfigKey
                                    .enableBackgroundPlay] = value;
                                if (value) {
                                  // 重新开启：用当前视频重建播控会话
                                  widget.videoDetailCtr?.refreshMediaSession();
                                }
                                setState(() {});
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      clipBehavior: Clip.hardEdge,
      isScrollControlled: true,
    );
  }

  void showSetSpeedSheet() {
    final double currentSpeed = widget.controller!.playbackSpeed;
    showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return sheetThemeWrapper(
          Container(
            height: Get.height * 0.6,
            padding: EdgeInsets.only(bottom: Get.mediaQuery.padding.bottom),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: sheetColorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    t.player.select_playback_speed,
                    style: titleStyle,
                  ),
                ),
                Expanded(
                  child: Material(
                    color: sheetColorScheme.surface,
                    child: ListView(
                      children: [
                        for (final double i in speedsList) ...<Widget>[
                          if (i == currentSpeed) ...<Widget>[
                            ListTile(
                              title: Text(i.toString()),
                              trailing: Icon(
                                Icons.check,
                                color: sheetColorScheme.primary,
                              ),
                              onTap: () async {
                                await widget.controller!.setPlaybackSpeed(i);
                                Get.back();
                              },
                            ),
                          ] else ...[
                            ListTile(
                              title: Text(i.toString()),
                              onTap: () async {
                                await widget.controller!.setPlaybackSpeed(i);
                                Get.back();
                              },
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showVideoFitSheet() {
    showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return sheetThemeWrapper(
          Container(
            height: Get.height * 0.6,
            padding: EdgeInsets.only(bottom: Get.mediaQuery.padding.bottom),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: sheetColorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    t.player.select_aspect_ratio,
                    style: titleStyle,
                  ),
                ),
                Expanded(
                  child: Material(
                    color: sheetColorScheme.surface,
                    child: ListView(
                      children: [
                        for (final i in widget.controller!.videoFitType)
                          ListTile(
                            title: Text(i['desc']),
                            trailing:
                                i['attr'] == widget.controller!.videoFit.value
                                ? Icon(
                                    Icons.check,
                                    color: sheetColorScheme.primary,
                                  )
                                : null,
                            onTap: () async {
                              widget.controller!.videoFit.value = i['attr'];
                              widget.controller!.videoFitDEsc.value = i['desc'];
                              widget.controller!.setVideoFit();
                              Get.back();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showResolutionSheet() {
    List<ResolutionModel> resolutions = widget.videoDetailCtr!.resolutions;

    showModalBottomSheet(
      context: context,
      elevation: 0,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return sheetThemeWrapper(
          Container(
            height: 300,
            padding: EdgeInsets.only(bottom: Get.mediaQuery.padding.bottom),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: sheetColorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(t.player.select_quality, style: titleStyle),
                ),
                Expanded(
                  child: Material(
                    color: sheetColorScheme.surface,
                    child: ListView(
                      children: [
                        for (final ResolutionModel i in resolutions) ...<
                          Widget
                        >[
                          ListTile(
                            title: Text(i.name),
                            trailing:
                                i ==
                                    widget.videoDetailCtr!.resolutions[widget
                                        .videoDetailCtr!
                                        .resolutionIndex]
                                ? Icon(
                                    Icons.check,
                                    color: sheetColorScheme.primary,
                                  )
                                : null,
                            onTap: () async {
                              int index = resolutions.indexOf(i);

                              widget.videoDetailCtr!.resolutionIndex = index;
                              widget.videoDetailCtr!.updatePlayer();

                              setting[PLPlayerConfigKey.qualityIndexSaved] =
                                  index == resolutions.length - 1
                                  ? 99 /* Source is always the last, use 99 to represent it */
                                  : index;

                              Get.back();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
