import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/bluesky_text_entities.dart';
import 'package:harpy/api/bluesky/post_translation_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/widgets/bluesky_text.dart';
import 'package:harpy/core/core.dart';

class TweetCardText extends ConsumerWidget {
  const TweetCardText({
    required this.post,
    required this.style,
    super.key,
  });

  final BlueskyPostData post;
  final TweetCardElementStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final translationState = ref.watch(postTranslationProvider(post));
    final router = ref.watch(routerProvider);
    final launcher = ref.watch(launcherProvider);

    final text = translationState.maybeMap(
      translated: (state) => state.translation.text,
      orElse: () => post.text,
    );

    final entities = translationState.maybeMap(
      translated: (_) => <BlueskyTextEntity>[], // No entities in translated text
      orElse: () => post.entities,
    );

    return Directionality(
      textDirection: post.isRtlLanguage ? TextDirection.rtl : TextDirection.ltr,
      child: BlueskyText(
        text,
        entities: entities,
        urlToIgnore: post.quoteUrl,
        style: theme.textTheme.bodyMedium!.apply(
          fontSizeDelta: style.sizeDelta,
        ),
        entityStyle: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
        onMentionTap: (mention) {
          // Navigate to user profile
          router.push('/user/$mention');
        },
        onHashtagTap: (hashtag) {
          // Navigate to hashtag search using AT Protocol's tag filter
          router.push(
            '/harpy_search/tweets?query=%23$hashtag',
            extra: {
              'hashTag': hashtag,
            },
          );
        },
        onUrlTap: launcher,
      ),
    );
  }
}
