import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

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
  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      itemCount: widget.itemCount,
      pageController: PageController(initialPage: widget.initialIndex),
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      onPageChanged: widget.onPageChanged,
      builder: (_, index) => PhotoViewGalleryPageOptions.customChild(
        initialScale: PhotoViewComputedScale.covered,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        scaleStateCycle: _scaleStateCycle,
        disableGestures: !widget.enableGestures,
        child: Stack(
          children: [
            GestureDetector(onTap: Navigator.of(context).pop),
            Center(child: widget.builder(context, index)),
          ],
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
      borderRadius: tween.evaluate(animation),
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
      return PhotoViewScaleState.zoomOne;
    case PhotoViewScaleState.zoomOne:
    case PhotoViewScaleState.zoomTwo:
    case PhotoViewScaleState.zoomedIn:
      return PhotoViewScaleState.initial;
  }
}
