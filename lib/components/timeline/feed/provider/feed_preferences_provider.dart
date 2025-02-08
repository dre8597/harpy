import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/core/core.dart';
import 'package:harpy/core/preferences/preferences.dart';
import 'package:logging/logging.dart';

part 'feed_preferences_provider.freezed.dart';

part 'feed_preferences_provider.g.dart';

final feedPreferencesProvider = StateNotifierProvider<FeedPreferencesNotifier, FeedPreferences>(
  (ref) => FeedPreferencesNotifier(
    preferences: ref.watch(encryptedPreferencesProvider(null)),
    ref: ref,
  ),
  name: 'FeedPreferencesProvider',
);

@freezed
class FeedPreference with _$FeedPreference {
  const factory FeedPreference({
    required String uri,
    required String name,
    required String did,
    String? description,
    @Default(false) bool isDefault,
  }) = _FeedPreference;

  factory FeedPreference.fromJson(Map<String, dynamic> json) => _$FeedPreferenceFromJson(json);

  factory FeedPreference.fromGeneratorView(bsky.FeedGenerator generator) {
    final view = generator.view;
    return FeedPreference(
      uri: view.uri.toString(),
      name: view.displayName,
      did: view.createdBy.did,
      description: view.description,
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

class FeedPreferencesNotifier extends StateNotifier<FeedPreferences> {
  FeedPreferencesNotifier({
    required Preferences preferences,
    required Ref ref,
  })  : _preferences = preferences,
        _ref = ref,
        super(
          FeedPreferences(
            feeds: [],
            activeFeedUri: preferences.getString('activeFeedUri'),
          ),
        );

  final Preferences _preferences;
  final Ref _ref;
  final log = Logger('FeedPreferencesNotifier');

  Future<void> loadFeeds() async {
    try {
      final blueskyApi = _ref.read(blueskyApiProvider);
      final feeds = <FeedPreference>[];

      // Add default "Following" feed
      feeds.add(
        const FeedPreference(
          uri: 'app.bsky.feed.getTimeline',
          name: 'Following',
          did: 'app.bsky.feed',
          isDefault: true,
        ),
      );

      // Get saved feed generators
      final preferences = await blueskyApi.actor.getPreferences();
      final allFeeds = preferences.data.preferences.whereType<bsky.UPreferenceSavedFeeds>();
      final savedFeeds = allFeeds.expand((pref) => pref.data.savedUris).whereType<AtUri>().toList();

      // Get feed info for each saved feed
      for (final feedUri in savedFeeds) {
        try {
          final generator = await blueskyApi.feed.getFeedGenerator(
            uri: feedUri,
          );
          feeds.add(FeedPreference.fromGeneratorView(generator.data));
        } catch (e) {
          log.warning('Failed to load feed info: $feedUri', e);
        }
      }

      state = state.copyWith(feeds: feeds);
    } catch (e) {
      log.severe('Failed to load feeds', e);
    }
  }

  Future<void> setActiveFeed(String uri) async {
    state = state.copyWith(activeFeedUri: uri);
    await _preferences.setString('activeFeedUri', uri);

  }

  Future<void> addFeed(FeedPreference feed) async {
    final feeds = List<FeedPreference>.from(state.feeds);
    if (!feeds.any((f) => f.uri == feed.uri)) {
      feeds.add(feed);
      state = state.copyWith(feeds: feeds);
    }
  }

  Future<void> removeFeed(String uri) async {
    final feeds = List<FeedPreference>.from(state.feeds);
    feeds.removeWhere((f) => f.uri == uri && !f.isDefault);
    state = state.copyWith(feeds: feeds);
  }

  Future<void> updateFromStoredPreferences(FeedPreferences preferences) async {
    state = preferences;
    if (preferences.activeFeedUri != null) {
      await setActiveFeed(preferences.activeFeedUri!);
    }
  }
}
