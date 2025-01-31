import 'package:freezed_annotation/freezed_annotation.dart';

part 'translation_data.freezed.dart';
part 'translation_data.g.dart';

@freezed
class TranslationData with _$TranslationData {
  const factory TranslationData({
    required String text,
    required String language,
    @Default(true) bool isTranslated,
  }) = _TranslationData;

  factory TranslationData.fromJson(Map<String, dynamic> json) =>
      _$TranslationDataFromJson(json);
}
