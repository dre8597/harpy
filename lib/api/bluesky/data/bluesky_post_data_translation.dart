import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/api/bluesky/data/translation_data.dart';
import 'package:harpy/api/bluesky/post_translation_provider.dart';

extension BlueskyPostDataTranslation on BlueskyPostData {
  bool isTranslatable(WidgetRef ref, String targetLanguage) {
    final state = ref.watch(postTranslationProvider(this));
    return state.maybeMap(
      translatable: (_) => true,
      orElse: () => false,
    );
  }

  bool get isTranslating {
    return false; // Deprecated - use provider state instead
  }

  TranslationData? get translation =>
      null; // Deprecated - use provider state instead

  void setTranslation(TranslationData translation) {
    // Deprecated - use provider state instead
  }

  void setTranslating(bool value) {
    // Deprecated - use provider state instead
  }

  void clearTranslation() {
    // Deprecated - use provider state instead
  }

  Future<bool> translatable(String targetLanguage) async {
    // Deprecated - use provider state instead
    return false;
  }
}
