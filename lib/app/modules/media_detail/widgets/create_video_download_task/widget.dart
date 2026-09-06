import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iwrqk/i18n/strings.g.dart';
import '../../../../data/models/offline/offline_media.dart';
import '../../../../data/models/resolution.dart';
import 'controller.dart';

// GetWidget 依赖全局 Get.find，实例未注册会抛异常导致弹窗空白，
// 改为 StatefulWidget 在 initState 里 Get.put 私有实例，随弹窗销毁
class CreateVideoDownloadDialog extends StatefulWidget {
  final List<ResolutionModel> resolutions;
  final OfflineMediaModel previewData;

  const CreateVideoDownloadDialog({
    super.key,
    required this.resolutions,
    required this.previewData,
  });

  @override
  State<CreateVideoDownloadDialog> createState() =>
      _CreateVideoDownloadDialogState();
}

class _CreateVideoDownloadDialogState
    extends State<CreateVideoDownloadDialog> {
  late final CreateVideoDownloadDialogController controller =
      Get.put(CreateVideoDownloadDialogController());

  @override
  void initState() {
    super.initState();
    controller.init(widget.resolutions, widget.previewData);
  }

  @override
  void dispose() {
    Get.delete<CreateVideoDownloadDialogController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.download.create_download_task),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      content: Container(
        width: Get.width * 0.8,
        constraints: const BoxConstraints(maxHeight: 400),
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        // AlertDialog 内部用 IntrinsicWidth 自适应宽度，
        // ListView/viewport 不支持 intrinsic 查询会导致布局异常、弹窗空白，
        // 因此改用 SingleChildScrollView
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(
              widget.resolutions.length,
              (index) => Obx(
                () => RadioListTile(
                  value: index,
                  title: Text(widget.resolutions[index].name),
                  groupValue: controller.currentResolutionIndex,
                  onChanged: (_) {
                    if (controller.currentResolutionIndex != index) {
                      controller.currentResolutionIndex = index;
                    } else {
                      Clipboard.setData(
                        ClipboardData(
                          text: widget.resolutions[index].src.downloadUrl,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        Obx(
          () => TextButton(
            onPressed: controller.creatingDownloadTask
                ? null
                : () {
                    Get.back();
                  },
            child: Text(
              t.notifications.cancel,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        ),
        Obx(
          () => TextButton(
            onPressed: controller.creatingDownloadTask
                ? null
                : () {
                    controller.createVideoDownloadTask();
                  },
            child: Text(t.notifications.confirm),
          ),
        ),
      ],
    );
  }
}
