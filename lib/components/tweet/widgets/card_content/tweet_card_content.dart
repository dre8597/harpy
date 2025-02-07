import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/components/tweet/model/tweet_card_config_element.dart';
import 'package:harpy/api/bluesky/post_translation_provider.dart';
import 'package:rby/rby.dart';

class TweetCardContent extends ConsumerWidget {
  const TweetCardContent({
    required this.tweet,
    required this.delegates,
    required this.config,
    required this.outerPadding,
    required this.innerPadding,
    this.index,
  });

  final BlueskyPostData tweet;
  final TweetDelegates delegates;
  final TweetCardConfig config;
  final double outerPadding;
  final double innerPadding;
  final int? index;

  bool _shouldShowLinkPreview() {
    // Only show link preview if there are external URLs and no media
    if (tweet.media?.isNotEmpty ?? false) return false;

    // Check if there are any external URLs (not AT Protocol)
    final externalUrls = tweet.externalUrls;
    if (externalUrls == null || externalUrls.isEmpty) return false;

    // Check if any URL is external (not AT Protocol)
    return externalUrls.any((url) {
      try {
        final uri = Uri.parse(url);
        // Exclude AT Protocol and Bluesky URLs
        return !uri.host.contains('bsky.app') &&
            !uri.host.contains('atproto.com') &&
            (uri.scheme == 'http' || uri.scheme == 'https');
      } catch (_) {
        return false;
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentPreview =
        TweetCardElement.parentPreview.shouldBuild(tweet, config);
    final text = TweetCardElement.text.shouldBuild(tweet, config);
    final translation = TweetCardElement.translation.shouldBuild(tweet, config);
    final media = TweetCardElement.media.shouldBuild(tweet, config);
    final quote = TweetCardElement.quote.shouldBuild(tweet, config);
    final details = TweetCardElement.details.shouldBuild(tweet, config);
    final actionsRow = TweetCardElement.actionsRow.shouldBuild(tweet, config);
    final showLinkPreview =
        TweetCardElement.linkPreview.shouldBuild(tweet, config);
    final hasExternalLink = _shouldShowLinkPreview();
    final linkPreview = showLinkPreview && hasExternalLink;

    final isTranslatable = ref.watch(
      postTranslationProvider(tweet).select(
        (state) => state.maybeMap(
          translatable: (_) => true,
          orElse: () => false,
        ),
      ),
    );

    final content = {
      TweetCardElement.topRow: TweetCardTopRow(
        tweet: tweet,
        delegates: delegates,
        outerPadding: outerPadding,
        innerPadding: innerPadding,
        config: config,
      ),
      if (parentPreview)
        TweetCardElement.parentPreview: TweetCardParentPreview(
          tweet: tweet,
          style: TweetCardElement.parentPreview.style(config),
        ),
      if (text)
        TweetCardElement.text: TweetCardText(
          post: tweet,
          style: TweetCardElement.text.style(config),
        ),
      if (translation && isTranslatable)
        TweetCardElement.translation: TweetCardTranslation(
          post: tweet,
          outerPadding: outerPadding,
          innerPadding: innerPadding,
          requireBottomInnerPadding: media || quote || details,
          requireBottomOuterPadding: !(media || quote || actionsRow || details),
          style: TweetCardElement.translation.style(config),
        ),
      if (media)
        TweetCardElement.media: TweetCardMedia(
          tweet: tweet,
          delegates: delegates,
          index: index,
        ),
      if (quote)
        TweetCardElement.quote: TweetCardQuote(
          post: tweet,
          index: index,
        ),
      if (linkPreview)
        TweetCardElement.linkPreview: TweetCardLinkPreview(tweet: tweet),
      if (details)
        TweetCardElement.details: TweetCardDetails(
          tweet: tweet,
          style: TweetCardElement.details.style(config),
        ),
      if (actionsRow)
        TweetCardElement.actionsRow: TweetCardActions(
          tweet: tweet,
          delegates: delegates,
          actions: config.actions,
          padding: EdgeInsets.all(outerPadding),
          style: TweetCardElement.actionsRow.style(config),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content.values.toList(),
    );
  }
}
