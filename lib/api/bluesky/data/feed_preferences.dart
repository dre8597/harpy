import 'package:bluesky/bluesky.dart' as bsky;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_preferences.freezed.dart';
part 'feed_preferences.g.dart';

@freezed
class FeedPreference with _$FeedPreference {
  const factory FeedPreference({
    required String uri,
    required String name,
    required String did,
    String? avatar,
    String? description,
    @Default(false) bool isDefault,
  }) = _FeedPreference;

  factory FeedPreference.fromJson(Map<String, dynamic> json) => _$FeedPreferenceFromJson(json);

  /// Creates a [FeedPreference] from a Bluesky feed generator view
  factory FeedPreference.fromGeneratorView(bsky.FeedGeneratorView generator) {
    return FeedPreference(
      uri: generator.uri.toString(),
      name: generator.displayName,
      did: generator.did ?? '',
      avatar: generator.avatar,
      description: generator.description,
    );
  }
}

@freezed
class FeedPreferences with _$FeedPreferences {
  const factory FeedPreferences({
    @Default([]) List<FeedPreference> feeds,
    String? activeFeedUri,
  }) = _FeedPreferences;

  factory FeedPreferences.fromJson(Map<String, dynamic> json) => _$FeedPreferencesFromJson(json);
}
