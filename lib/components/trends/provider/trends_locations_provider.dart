import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

final trendsLocationsProvider = StateNotifierProvider.autoDispose<
    TrendsLocationsNotifier, AsyncValue<BuiltList<TrendsLocationData>>>(
  (ref) {
    ref.cacheFor(const Duration(minutes: 5));

    return TrendsLocationsNotifier(
      blueskyApi: ref.watch(blueskyApiProvider),
    );
  },
  name: 'TrendsLocationsProvider',
);

class TrendsLocationsNotifier
    extends StateNotifier<AsyncValue<BuiltList<TrendsLocationData>>>
    with LoggerMixin {
  TrendsLocationsNotifier({
    required bsky.Bluesky blueskyApi,
  })  : _blueskyApi = blueskyApi,
        super(const AsyncValue.loading()) {
    load();
  }

  final bsky.Bluesky _blueskyApi;

  Future<void> load() async {
    log.fine('loading popular feed generators');

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final popular = await _blueskyApi.unspecced.getPopularFeedGenerators(
        limit: 25,
      );

      final feedGenerators = popular.data.feeds
          .map(
            (feed) => TrendsLocationData(
              woeid: feed.hashCode,
              name: feed.displayName,
              placeType: 'feed',
              country: feed.description ?? '',
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      return feedGenerators.toBuiltList();
    });
  }
}
