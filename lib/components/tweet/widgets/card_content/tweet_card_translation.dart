import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';

class TweetCardTranslation extends ConsumerWidget {
  const TweetCardTranslation({
    required this.post,
    required this.outerPadding,
    required this.innerPadding,
    required this.requireBottomInnerPadding,
    required this.requireBottomOuterPadding,
    required this.style,
    super.key,
  });

  final BlueskyPostData post;
  final double outerPadding;
  final double innerPadding;
  final bool requireBottomInnerPadding;
  final bool requireBottomOuterPadding;
  final TweetCardElementStyle style;

  static const _animationDuration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final buildTranslation =
        post.translation != null && post.translation!.isTranslated;

    final bottomPadding = requireBottomInnerPadding
        ? innerPadding
        : requireBottomOuterPadding
            ? outerPadding
            : 0.0;

    return AnimatedSize(
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: buildTranslation ? 1 : 0,
        duration: _animationDuration,
        curve: Curves.easeOut,
        child: buildTranslation
            ? Padding(
                padding: EdgeInsets.symmetric(horizontal: outerPadding)
                    .copyWith(top: innerPadding)
                    .copyWith(bottom: bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Translated from ${post.translation!.language}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      post.translation!.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: theme.textTheme.bodyMedium!.fontSize! +
                            style.sizeDelta,
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                width: double.infinity,
                height: bottomPadding,
              ),
      ),
    );
  }
}
