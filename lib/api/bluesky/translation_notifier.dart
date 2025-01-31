import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data_translation.dart';
import 'package:harpy/api/bluesky/translation_service.dart';

final translationNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<TranslationNotifier, void, BlueskyPostData>(
  TranslationNotifier.new,
);

class TranslationNotifier extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  FutureOr<void> build(String arg) {}

  Future<void> translate(BlueskyPostData post, String targetLanguage) async {
    if (post.isTranslating || post.translation != null) return;

    post.setTranslating(true);
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final translationService = ref.read(translationServiceProvider);
      final translation = await translationService.translate(
        text: post.text,
        targetLanguage: targetLanguage,
      );

      post.setTranslation(translation);
      post.setTranslating(false);
    });
  }
}
