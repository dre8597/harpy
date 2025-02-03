import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

void showMediaActionsBottomSheet(
  WidgetRef ref, {
  required BlueskyMediaData media,
  required TweetDelegates delegates,
}) {
  final theme = Theme.of(ref.context);
  final onBackground = theme.colorScheme.onSurface;

  showRbyBottomSheet<void>(
    ref.context,
    children: [
      RbyListTile(
        leading: const Icon(CupertinoIcons.square_arrow_left),
        title: Text(
          'open externally',
          style: TextStyle(color: onBackground),
        ),
        onTap: () {
          delegates.onOpenMediaExternally?.call(ref, media);
          Navigator.of(ref.context).pop();
        },
      ),
      RbyListTile(
        leading: const Icon(CupertinoIcons.arrow_down_to_line),
        title: Text(
          'download',
          style: TextStyle(color: onBackground),
        ),
        onTap: () {
          delegates.onDownloadMedia?.call(ref, media);
          Navigator.of(ref.context).pop();
        },
      ),
      RbyListTile(
        leading: const Icon(CupertinoIcons.share),
        title: Text(
          'share',
          style: TextStyle(color: onBackground),
        ),
        onTap: () {
          delegates.onShareMedia?.call(ref, media);
          Navigator.of(ref.context).pop();
        },
      ),
    ],
  );
}
