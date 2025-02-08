import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:bluesky/core.dart';
import 'package:rby/theme/spacing_theme.dart';
import 'package:sliver_tools/sliver_tools.dart';

class UserPageAvatar extends StatefulWidget {
  const UserPageAvatar({
    super.key,
    required this.url,
    this.borderRadius,
  });

  static const double maxAvatarRadius = 48;
  static const double minAvatarRadius = 36;

  final String url;
  final BorderRadius? borderRadius;

  @override
  State<UserPageAvatar> createState() => _UserPageAvatarState();
}

class _UserPageAvatarState extends State<UserPageAvatar> {
  ScrollController? _controller;
  final _radiusNotifier = ValueNotifier(UserPageAvatar.maxAvatarRadius);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= PrimaryScrollController.of(context)..addListener(_scrollListener);
  }

  @override
  void dispose() {
    _controller?.removeListener(_scrollListener);
    _radiusNotifier.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final theme = Theme.of(context);
    final maxExtent = -UserPageAvatar.minAvatarRadius * 2 - theme.spacing.base * 2;

    // interpolate from min radius to max radius when scrolling from 0 to maxExtent
    _radiusNotifier.value = lerpDouble(
      UserPageAvatar.maxAvatarRadius,
      UserPageAvatar.minAvatarRadius,
      (_controller!.offset / (maxExtent.abs() - UserPageAvatar.maxAvatarRadius)).clamp(0, 1),
    )!;
  }

  void _showAvatarOverlay(BuildContext context) {
    final media = BlueskyMediaData(
      alt: 'Profile picture',
      url: widget.url,
    );

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;

    // Leave comfortable margins at top and bottom for interaction
    // Use 15% of screen height for margins
    final verticalMargin = screenSize.height * 0.15;
    final availableHeight = screenSize.height - (verticalMargin * 2) - padding.top - padding.bottom;
    final availableWidth = screenSize.width - (mediaQuery.padding.left + mediaQuery.padding.right);

    // Set aspect ratio to fill available space while maintaining square or portrait orientation
    final aspectRatio = availableWidth / availableHeight;

    Navigator.of(context).push<void>(
      HeroDialogRoute(
        builder: (_) => MediaGalleryOverlay(
          tweet: BlueskyPostData(
            id: '',
            text: '',
            uri: AtUri.parse('at://did:plc:123/app.bsky.feed.post/123'),
            author: '',
            handle: '',
            authorDid: '',
            authorAvatar: '',
            createdAt: DateTime.now(),
          ),
          media: media.copyWith(aspectRatio: aspectRatio),
          delegates: const TweetDelegates(),
          actions: const {MediaOverlayActions.download},
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 300) {
                Navigator.of(context).pop();
              }
            },
            child: Hero(
              tag: 'avatar_${widget.url}',
              child: Container(
                margin: EdgeInsets.only(
                  top: verticalMargin + padding.top,
                  bottom: verticalMargin + padding.bottom,
                  left: padding.left,
                  right: padding.right,
                ),
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverPositioned(
      bottom: -UserPageAvatar.maxAvatarRadius,
      left: theme.spacing.base * 2,
      child: GestureDetector(
        onTap: () => _showAvatarOverlay(context),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _radiusNotifier,
              builder: (_, __) => HarpyCircleAvatar(
                radius: _radiusNotifier.value,
                imageUrl: widget.url,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
