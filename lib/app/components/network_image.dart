import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../const/iwara.dart';
import '../data/services/config_service.dart';

class NetworkImg extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final double? aspectRatio;
  final BoxFit? fit;
  final bool isAdult;
  final int? memCacheWidth;

  const NetworkImg({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    this.aspectRatio,
    this.isAdult = false,
    this.memCacheWidth,
  });

  @override
  State<NetworkImg> createState() => _NetworkImgState();
}

class _NetworkImgState extends State<NetworkImg>
    with AutomaticKeepAliveClientMixin {
  final ConfigService _configService = Get.find();

  Widget _buildFilterImage(Widget child) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
      child: child,
    );
  }

  int _resolveMemCacheWidth(BuildContext context, BoxConstraints constraints) {
    if (widget.memCacheWidth != null) {
      return widget.memCacheWidth!;
    }

    double logicalWidth = widget.width ??
        (constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width);

    return (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final int memCacheWidth =
            _resolveMemCacheWidth(context, constraints);

        final errorWidget = SizedBox(
          width: widget.width,
          height: widget.height,
          child: const Center(child: Icon(Icons.image_not_supported)),
        );

        if (widget.aspectRatio != null) {
          return AspectRatio(
            aspectRatio: widget.aspectRatio!,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              memCacheWidth: memCacheWidth,
              httpHeaders: const {"referer": IwaraConst.referer},
              imageBuilder: widget.isAdult && _configService.workMode
                  ? (context, imageProvider) {
                      Widget image = Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: imageProvider,
                            fit: widget.fit,
                          ),
                        ),
                      );
                      return _buildFilterImage(image);
                    }
                  : null,
              fit: widget.fit,
              progressIndicatorBuilder: (context, url, progress) {
                return Center(
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    child: const CircularProgressIndicator(),
                  ),
                );
              },
              errorWidget: (_, _, _) {
                return errorWidget;
              },
            ),
          );
        } else {
          return CachedNetworkImage(
            imageUrl: widget.imageUrl,
            memCacheWidth: memCacheWidth,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            httpHeaders: const {"referer": IwaraConst.referer},
            imageBuilder: widget.isAdult && _configService.workMode
                ? (context, imageProvider) {
                    Widget image = Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: imageProvider,
                          fit: widget.fit,
                        ),
                      ),
                    );
                    return _buildFilterImage(image);
                  }
                : null,
            progressIndicatorBuilder: (context, url, progress) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.all(5),
                  child: const CircularProgressIndicator(),
                ),
              );
            },
            errorWidget: (_, _, _) {
              return errorWidget;
            },
          );
        }
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
