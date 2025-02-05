import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/translation_notifier.dart';
import 'package:harpy/components/components.dart';

class TweetCardContent extends ConsumerWidget {
  const TweetCardContent({
    required this.tweet,
    required this.notifier,
    required this.delegates,
    required this.outerPadding,
    required this.innerPadding,
    required this.config,
    this.index,
  });

  final BlueskyPostData tweet;
  final TweetNotifier notifier;
  final TweetDelegates delegates;
  final double outerPadding;
  final double innerPadding;
  final TweetCardConfig config;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = TweetCardElement.text.shouldBuild(tweet, config);
    final translation = TweetCardElement.translation.shouldBuild(tweet, config);
    final media = TweetCardElement.media.shouldBuild(tweet, config);
    final quote = TweetCardElement.quote.shouldBuild(tweet, config);
    final linkPreview = TweetCardElement.linkPreview.shouldBuild(tweet, config);
    final details = TweetCardElement.details.shouldBuild(tweet, config);
    final actionsRow = TweetCardElement.actionsRow.shouldBuild(tweet, config);
    final parentPreview = TweetCardElement.parentPreview.shouldBuild(tweet, config);
    final isTranslatable = ref.watch(translationNotifierProvider(tweet));

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
      if (translation &&
          isTranslatable.when(
            data: (data) => details,
            loading: () => false,
            error: (error, stackTrace) => false,
          ))
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
      if (linkPreview) TweetCardElement.linkPreview: TweetCardLinkPreview(tweet: tweet),
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

    return Padding(
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < content.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: content.keys.elementAt(i).buildBottomPadding(
                          i,
                          content.keys,
                        )
                    ? outerPadding
                    : 0,
              ),
              child: content.values.elementAt(i),
            ),
        ],
      ),
    );
  }
}
