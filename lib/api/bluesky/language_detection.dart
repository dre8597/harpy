import 'package:translator/translator.dart';

extension LanguageDetection on String {
  Future<String?> detectLanguage() async {
    try {
      final translator = GoogleTranslator();
      final result = await translator.translate(this);
      return result.sourceLanguage.code;
    } catch (_) {
      return null;
    }
  }
}
