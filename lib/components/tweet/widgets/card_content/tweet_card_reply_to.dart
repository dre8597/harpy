import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

/// A widget that shows when a post is a reply to another post.
class TweetCardReplyTo extends ConsumerWidget {
  const TweetCardReplyTo({
    required this.tweet,
    required this.onReplyToTap,
    required this.style,
    super.key,
  });

  final BlueskyPostData tweet;
  final TweetActionCallback? onReplyToTap;
  final TweetCardElementStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final display = ref.watch(displayPreferencesProvider);

    final textStyle = theme.textTheme.bodyMedium!;

    return GestureDetector(
      onTap: () => onReplyToTap?.call(ref),
      child: IntrinsicWidth(
        child: Row(
          children: [
            SizedBox(
              width: TweetCardAvatar.defaultRadius(display.fontSizeDelta) * 2,
              child: Icon(
                FeatherIcons.messageCircle,
                size: textStyle.fontSize! + style.sizeDelta,
              ),
            ),
            HorizontalSpacer.normal,
            Flexible(
              child: FittedBox(
                child: Text(
                  'Replying to post',
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  style: textStyle
                      .copyWith(
                        color: textStyle.color?.withOpacity(.8),
                        height: 1,
                      )
                      .apply(fontSizeDelta: style.sizeDelta),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
