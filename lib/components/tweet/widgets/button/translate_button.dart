import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/post_translation_provider.dart';
import 'package:harpy/components/components.dart';

class TranslateButton extends ConsumerWidget {
  const TranslateButton({
    required this.post,
    this.sizeDelta = 0,
    super.key,
  });

  final BlueskyPostData post;
  final double sizeDelta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconTheme = IconTheme.of(context);
    final harpyTheme = ref.watch(harpyThemeProvider);
    final translationState = ref.watch(postTranslationProvider(post));

    final iconSize = iconTheme.size! + sizeDelta;

    final isActive = translationState.maybeMap(
      translating: (_) => true,
      translated: (_) => true,
      orElse: () => false,
    );

    return TweetActionButton(
      active: isActive,
      iconBuilder: (_) => Icon(Icons.translate, size: iconSize),
      bubblesColor: const BubblesColor(
        primary: Colors.teal,
        secondary: Colors.tealAccent,
        tertiary: Colors.lightBlue,
        quaternary: Colors.indigoAccent,
      ),
      circleColor: const CircleColor(
        start: Colors.tealAccent,
        end: Colors.lightBlueAccent,
      ),
      iconSize: iconSize,
      sizeDelta: sizeDelta,
      activeColor: harpyTheme.colors.translate,
      activate: () {
        final notifier = ref.read(postTranslationProvider(post).notifier);
        final locale = Localizations.localeOf(context);
        final translateLanguage = ref
            .read(languagePreferencesProvider)
            .activeTranslateLanguage(locale);
        notifier.translate(translateLanguage);
      },
      deactivate: () {
        final notifier = ref.read(postTranslationProvider(post).notifier);
        notifier.reset();
      },
    );
  }
}
