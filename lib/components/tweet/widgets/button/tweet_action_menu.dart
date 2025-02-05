import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

/// Shows a like action menu with options to like/unlike and show likes.
Future<void> showLikeActionMenu({
  required BuildContext context,
  required WidgetRef ref,
  required BlueskyPostData tweet,
  required TweetDelegates delegates,
  required RenderBox renderBox,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final theme = Theme.of(context);
  final onBackground = theme.colorScheme.onSurface;

  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      renderBox.localToGlobal(
        renderBox.size.bottomLeft(Offset.zero),
        ancestor: overlay,
      ),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );

  final result = await showRbyMenu(
    context: context,
    position: position,
    items: [
      RbyPopupMenuListTile(
        value: 0,
        leading: const Icon(CupertinoIcons.heart_fill),
        title: Text(
          tweet.isLiked ? 'unlike' : 'like',
          style: TextStyle(color: onBackground),
        ),
      ),
      if (delegates.onShowLikes != null)
        RbyPopupMenuListTile(
          value: 1,
          leading: const Icon(CupertinoIcons.person_2_fill),
          title: Text(
            'show likes',
            style: TextStyle(color: onBackground),
          ),
        ),
    ],
  );

  if (result == 0) {
    tweet.isLiked ? delegates.onUnfavorite?.call(ref) : delegates.onFavorite?.call(ref);
  } else if (result == 1) {
    delegates.onShowLikes?.call(ref);
  }
}

/// Shows a repost action menu with options to repost/unrepost, quote, and view retweeters.
Future<void> showRepostActionMenu({
  required BuildContext context,
  required WidgetRef ref,
  required BlueskyPostData tweet,
  required TweetDelegates delegates,
  required RenderBox renderBox,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final theme = Theme.of(context);
  final onBackground = theme.colorScheme.onSurface;

  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      renderBox.localToGlobal(
        renderBox.size.bottomLeft(Offset.zero),
        ancestor: overlay,
      ),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );

  final result = await showRbyMenu(
    context: context,
    position: position,
    items: [
      RbyPopupMenuListTile(
        value: 0,
        leading: const Icon(CupertinoIcons.repeat),
        title: Text(
          tweet.isReposted ? 'unretweet' : 'retweet',
          style: TextStyle(color: onBackground),
        ),
      ),
      if (delegates.onComposeQuote != null)
        RbyPopupMenuListTile(
          value: 1,
          leading: const Icon(CupertinoIcons.pencil),
          title: Text(
            'quote tweet',
            style: TextStyle(color: onBackground),
          ),
        ),
      if (delegates.onShowRetweeters != null)
        RbyPopupMenuListTile(
          value: 2,
          leading: const Icon(CupertinoIcons.person_2_fill),
          title: Text(
            'view retweeters',
            style: TextStyle(color: onBackground),
          ),
        ),
    ],
  );

  if (result == 0) {
    tweet.isReposted ? delegates.onUnretweet?.call(ref) : delegates.onRetweet?.call(ref);
  } else if (result == 1) {
    delegates.onComposeQuote?.call(ref);
  } else if (result == 2) {
    delegates.onShowRetweeters?.call(ref);
  }
}

/// Helper function to calculate the menu position relative to a render box.
RelativeRect getMenuPosition(RenderBox renderBox, RenderBox overlay) {
  return RelativeRect.fromRect(
    Rect.fromPoints(
      renderBox.localToGlobal(
        renderBox.size.bottomLeft(Offset.zero),
        ancestor: overlay,
      ),
      renderBox.localToGlobal(
        renderBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    ),
    Offset.zero & overlay.size,
  );
}
