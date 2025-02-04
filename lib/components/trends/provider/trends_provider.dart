import 'dart:convert';

import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

/// A class to represent a trending topic in Bluesky
class Trend {
  Trend({
    required this.name,
    required this.url,
    required this.postCount,
  });

  final String name;
  final String url;
  final int postCount;
}

final trendsProvider = StateNotifierProvider.autoDispose<TrendsNotifier,
    AsyncValue<BuiltList<Trend>>>(
  (ref) {
    ref.cacheFor(const Duration(minutes: 5));

    return TrendsNotifier(
      ref: ref,
      blueskyApi: ref.watch(blueskyApiProvider),
      userLocation: ref.watch(userTrendsLocationProvider),
    );
  },
  name: 'TrendsProvider',
);

class TrendsNotifier extends StateNotifier<AsyncValue<BuiltList<Trend>>>
    with LoggerMixin {
  TrendsNotifier({
    required Ref ref,
    required bsky.Bluesky blueskyApi,
    required TrendsLocationData userLocation,
  })  : _ref = ref,
        _blueskyApi = blueskyApi,
        _trendsLocationData = userLocation,
        super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final bsky.Bluesky _blueskyApi;
  final TrendsLocationData _trendsLocationData;

  Future<void> load() async {
    log.fine('finding trends for ${_trendsLocationData.name}');

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async {
        final popular = await _blueskyApi.unspecced.getPopularFeedGenerators(
          limit: 25,
        );

        final trends = popular.data.feeds
            .map(
              (feed) => Trend(
                name: feed.displayName,
                url:
                    'https://bsky.app/profile/${feed.createdBy.handle}/feed/${feed.uri.rkey}',
                postCount: feed.likeCount,
              ),
            )
            .toList()
          ..sort((a, b) => b.postCount.compareTo(a.postCount));

        return trends.toBuiltList();
      },
    );
  }

  Future<void> updateLocation({
    required TrendsLocationData location,
  }) async {
    log.fine('updating trends location');

    try {
      _ref
          .read(trendsLocationPreferencesProvider.notifier)
          .setTrendsLocationData(jsonEncode(location.toJson()));
    } catch (e, st) {
      log.severe('unable to update trends location', e, st);
    }
  }
}
