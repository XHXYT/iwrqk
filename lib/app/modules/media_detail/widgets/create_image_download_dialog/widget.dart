import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/media/image.dart';

class CreateImageDownloadDialog extends StatefulWidget {
  const CreateImageDownloadDialog({
    super.key,
    required this.image,
    required this.onSave,
  });

  final ImageModel image;
  final Future<void> Function(int index) onSave;

  @override
  State<CreateImageDownloadDialog> createState() =>
      _CreateImageDownloadDialogState();
}

class _CreateImageDownloadDialogState
    extends State<CreateImageDownloadDialog> {
  late List<bool> _selected =
      List.filled(widget.image.galleryFileUrls.length, false);

  @override
  Widget build(BuildContext context) {
    final urls = widget.image.galleryFileUrls;
    return AlertDialog(
      title: Text("${urls.length} 张图片"),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: ListView.builder(
          itemCount: urls.length,
          itemBuilder: (context, index) => CheckboxListTile(
            secondary: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: urls[index],
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            ),
            title: Text("图片 ${index + 1}"),
            value: _selected[index],
            onChanged: (v) => setState(() => _selected[index] = v!),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              setState(() => _selected = List.filled(urls.length, true)),
          child: const Text("全选"),
        ),
        FilledButton(
          onPressed: () async {
            Get.back();
            for (int i = 0; i < _selected.length; i++) {
              if (_selected[i]) await widget.onSave(i);
            }
          },
          child: const Text("保存到相册"),
        ),
      ],
    );
  }
}
