import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/post_translation_state.dart';
import 'package:harpy/api/bluesky/language_detection.dart';
import 'package:harpy/api/bluesky/translation_service.dart';

final postTranslationProvider = NotifierProvider.family<PostTranslationNotifier,
    PostTranslationState, BlueskyPostData>(
  PostTranslationNotifier.new,
  name: 'PostTranslationProvider',
);

class PostTranslationNotifier
    extends FamilyNotifier<PostTranslationState, BlueskyPostData> {
  @override
  PostTranslationState build(BlueskyPostData arg) {
    return const PostTranslationState.initial();
  }

  Future<bool> checkTranslatability(String targetLanguage) async {
    state = const PostTranslationState.checking();

    try {
      final detectedLanguage = await arg.text.detectLanguage() ?? 'unknown';

      if (detectedLanguage == targetLanguage) {
        state = PostTranslationState.notTranslatable(
          targetLanguage: targetLanguage,
          detectedLanguage: detectedLanguage,
        );
        return false;
      }

      state = PostTranslationState.translatable(
        targetLanguage: targetLanguage,
        detectedLanguage: detectedLanguage,
      );
      return true;
    } catch (e) {
      state = PostTranslationState.error(
        message: 'Failed to detect language: $e',
      );
      return false;
    }
  }

  Future<void> translate(String targetLanguage) async {
    final currentState = state;
    if (!currentState.maybeMap(
      translatable: (_) => true,
      orElse: () => false,
    )) {
      final isTranslatable = await checkTranslatability(targetLanguage);
      if (!isTranslatable) return;
    }

    state = const PostTranslationState.translating();

    try {
      final translationService = ref.read(translationServiceProvider);
      final translation = await translationService.translate(
        text: arg.text,
        targetLanguage: targetLanguage,
      );

      state = PostTranslationState.translated(translation: translation);
    } catch (e) {
      state = PostTranslationState.error(
        message: 'Translation failed: $e',
      );
    }
  }

  void reset() {
    state = const PostTranslationState.initial();
  }
}
