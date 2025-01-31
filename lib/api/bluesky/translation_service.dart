import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/translation_data.dart';
import 'package:translator/translator.dart';

final translationServiceProvider = Provider((ref) => TranslationService());

class TranslationService {
  final _translator = GoogleTranslator();

  Future<TranslationData> translate({
    required String text,
    required String targetLanguage,
  }) async {
    try {
      final translation = await _translator.translate(
        text,
        to: targetLanguage,
      );

      return TranslationData(
        text: translation.text,
        language: translation.targetLanguage.code,
      );
    } catch (e) {
      return TranslationData(
        text: text,
        language: targetLanguage,
        isTranslated: false,
      );
    }
  }
}
