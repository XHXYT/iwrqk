import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class IwrGallery extends StatefulWidget {
  final List<String> imageUrls;
  final bool isfullScreen;
  final int? lastPage;
  final void Function(int index)? onPageChanged;
  final Future<void> Function(String url)? onSaveImage;

  const IwrGallery({
    super.key,
    required this.imageUrls,
    this.isfullScreen = false,
    this.lastPage,
    this.onPageChanged,
    this.onSaveImage,
  });

  @override
  State<IwrGallery> createState() => _IwrGalleryState();
}

class _IwrGalleryState extends State<IwrGallery> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _barsVisible = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.lastPage ?? 0);
    _currentIndex = widget.lastPage ?? 0;
    if (widget.isfullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    if (widget.isfullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _pageController.dispose();
    super.dispose();
  }

  void _enterFullScreen() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          body: IwrGallery(
            isfullScreen: true,
            imageUrls: widget.imageUrls,
            lastPage: _currentIndex,
            onSaveImage: widget.onSaveImage,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _pageController.jumpToPage(_currentIndex);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGallery() {
    return PhotoViewGallery.builder(
      customSize: widget.isfullScreen
          ? null
          : Size.copy(MediaQuery.of(context).size),
      builder: (BuildContext context, int index) {
        var imageProvider = CachedNetworkImageProvider(widget.imageUrls[index]);
        return PhotoViewGalleryPageOptions(
          imageProvider: imageProvider,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: widget.imageUrls[index]),
          filterQuality: FilterQuality.high,
          onTapUp: (context, details, controllerValue) {
            if (widget.isfullScreen) {
              setState(() => _barsVisible = !_barsVisible);
            } else {
              _enterFullScreen();
            }
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(Icons.image_not_supported, color: Colors.white),
            );
          },
        );
      },
      itemCount: widget.imageUrls.length,
      loadingBuilder: (context, event) =>
          const Center(child: CircularProgressIndicator()),
      pageController: _pageController,
      onPageChanged: (index) {
        widget.onPageChanged?.call(index);
        setState(() {
          _currentIndex = index;
        });
      },
    );
  }

  Widget _buildDotPageFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.3 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.imageUrls.length, (index) {
          return GestureDetector(
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 150),
                curve: Curves.bounceIn,
              );
            },
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentIndex == index
                    ? Colors.white
                    : Colors.white.withAlpha((0.4 * 255).round()),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTextPageFooter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((0.5 * 255).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        "${_currentIndex + 1} / ${widget.imageUrls.length}",
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isfullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            _buildGallery(),

            // 顶栏：返回按钮（点击图片可隐藏）
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_barsVisible,
                child: AnimatedOpacity(
                  opacity: _barsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Get.back(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 底栏：页码 + 右下角下载按钮（点击图片可隐藏）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_barsVisible,
                child: AnimatedOpacity(
                  opacity: _barsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_currentIndex + 1} / ${widget.imageUrls.length}",
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (widget.onSaveImage != null)
                            IconButton(
                              onPressed: () => widget.onSaveImage!(
                                widget.imageUrls[_currentIndex],
                              ),
                              icon: const Icon(
                                Icons.download,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return GestureDetector(
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildGallery(),
              Positioned(
                left: 4,
                top: 4,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withAlpha(
                      (0.3 * 255).round(),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: Theme.of(context).appBarTheme.iconTheme?.size,
                  ),
                ),
              ),
              if (widget.onSaveImage != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha(
                        (0.3 * 255).round(),
                      ),
                    ),
                    onPressed: () =>
                        widget.onSaveImage!(widget.imageUrls[_currentIndex]),
                    icon: const Icon(Icons.download, color: Colors.white),
                  ),
                ),
              if (widget.imageUrls.length > 15)
                Positioned(bottom: 10, child: _buildTextPageFooter()),
              if (widget.imageUrls.length <= 15 && widget.imageUrls.length > 1)
                Positioned(bottom: 10, child: _buildDotPageFooter()),
            ],
          ),
        ),
      );
    }
  }
}
