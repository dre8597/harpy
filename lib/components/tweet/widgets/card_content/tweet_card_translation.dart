import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/post_translation_provider.dart';
import 'package:harpy/api/translate/data/languages.dart';
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

  String _getLanguageName(String languageCode) {
    return kTranslateLanguages[languageCode.toLowerCase()] ?? languageCode;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final translationState = ref.watch(postTranslationProvider(post));

    final buildTranslation = translationState.maybeMap(
      translated: (_) => true,
      orElse: () => false,
    );

    final sourceLanguage = translationState.maybeMap(
      translatable: (state) => _getLanguageName(state.detectedLanguage),
      translated: (state) => _getLanguageName(state.translation.language),
      orElse: () => '',
    );

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
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Translated from $sourceLanguage',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
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
