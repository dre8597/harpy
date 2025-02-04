import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/data/translation_data.dart';

part 'post_translation_state.freezed.dart';

@freezed
class PostTranslationState with _$PostTranslationState {
  const factory PostTranslationState.initial() = _Initial;

  const factory PostTranslationState.checking() = _Checking;

  const factory PostTranslationState.translatable({
    required String targetLanguage,
    required String detectedLanguage,
  }) = _Translatable;

  const factory PostTranslationState.notTranslatable({
    required String targetLanguage,
    required String detectedLanguage,
  }) = _NotTranslatable;

  const factory PostTranslationState.translating() = _Translating;

  const factory PostTranslationState.translated({
    required TranslationData translation,
  }) = _Translated;

  const factory PostTranslationState.error({
    required String message,
  }) = _Error;
}
