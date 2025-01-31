import 'package:flutter/material.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/bluesky_text_entities.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/widgets/bluesky_text.dart';

class TweetCardText extends StatelessWidget {
  const TweetCardText({
    required this.post,
    required this.style,
    super.key,
  });

  final BlueskyPostData post;
  final TweetCardElementStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: post.isRtlLanguage ? TextDirection.rtl : TextDirection.ltr,
      child: BlueskyText(
        post.text,
        entities: post.entities,
        urlToIgnore: post.quoteUrl,
        style: theme.textTheme.bodyMedium!.apply(
          fontSizeDelta: style.sizeDelta,
        ),
        onMentionTap: (mention) {
          // Handle mention tap - navigate to profile
        },
        onHashtagTap: (hashtag) {
          // Handle hashtag tap - search for hashtag
        },
        onUrlTap: (url) {
          // Handle URL tap - open in browser or webview
        },
      ),
    );
  }
}
