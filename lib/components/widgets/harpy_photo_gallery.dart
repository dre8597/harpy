import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

//TODO: Make a forked version with all code updated to latest version
class HarpyPhotoGallery extends StatefulWidget {
  const HarpyPhotoGallery({
    required this.builder,
    required this.itemCount,
    this.initialIndex = 0,
    this.enableGestures = true,
    this.onPageChanged,
  }) : assert(itemCount > 0);

  final IndexedWidgetBuilder builder;
  final int itemCount;
  final int initialIndex;
  final bool enableGestures;
  final ValueChanged<int>? onPageChanged;

  @override
  State<HarpyPhotoGallery> createState() => _HarpyPhotoGalleryState();
}

class _HarpyPhotoGalleryState extends State<HarpyPhotoGallery> {
  late final PageController _pageController;
  final Map<int, PhotoViewController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PhotoViewController _getController(int index) {
    return _controllers.putIfAbsent(index, PhotoViewController.new);
  }

  void _handleDoubleTap(BuildContext context, int index) {
    final controller = _getController(index);
    controller.scale = controller.scale == 1.0 ? 2.0 : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      itemCount: widget.itemCount,
      pageController: _pageController,
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      onPageChanged: widget.onPageChanged,
      builder: (_, index) => PhotoViewGalleryPageOptions.customChild(
        controller: _getController(index),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        scaleStateCycle: _scaleStateCycle,
        disableGestures: !widget.enableGestures,
        child: GestureDetector(
          onTap: Navigator.of(context).pop,
          onDoubleTap: widget.enableGestures
              ? () => _handleDoubleTap(context, index)
              : null,
          child: Center(child: widget.builder(context, index)),
        ),
      ),
    );
  }
}

/// A flight shuttle builder for a [Hero] to animate the border radius of a
/// child during the transition.
Widget borderRadiusFlightShuttleBuilder(
  BorderRadius beginRadius,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final hero = flightDirection == HeroFlightDirection.push
      ? fromHeroContext.widget as Hero
      : toHeroContext.widget as Hero;

  final tween = BorderRadiusTween(
    begin: beginRadius,
    end: BorderRadius.zero,
  );

  return AnimatedBuilder(
    animation: animation,
    builder: (_, __) => ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: tween.evaluate(animation) ?? BorderRadius.zero,
      child: hero.child,
    ),
  );
}

PhotoViewScaleState _scaleStateCycle(PhotoViewScaleState actual) {
  switch (actual) {
    case PhotoViewScaleState.initial:
    case PhotoViewScaleState.covering:
    case PhotoViewScaleState.originalSize:
    case PhotoViewScaleState.zoomedOut:
      return PhotoViewScaleState.zoomedIn;
    case PhotoViewScaleState.zoomedIn:
      return PhotoViewScaleState.initial;
  }
}
