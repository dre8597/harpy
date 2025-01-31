import 'package:bluesky/bluesky.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';

part 'find_trends_location_provider.freezed.dart';

final findTrendsLocationProvider = StateNotifierProvider.autoDispose<
    FindTrendsLocationNotifier, FindTrendsLocationState>(
  (ref) => FindTrendsLocationNotifier(
    blueskyApi: ref.watch(blueskyApiProvider),
  ),
  name: 'FindTrendsLocationProvider',
);

class FindTrendsLocationNotifier extends StateNotifier<FindTrendsLocationState>
    with LoggerMixin {
  FindTrendsLocationNotifier({
    required Bluesky blueskyApi,
  })  : _blueskyApi = blueskyApi,
        super(const FindTrendsLocationState.initial());

  final Bluesky _blueskyApi;

  Future<void> search({
    required String query,
  }) async {
    log.fine('searching for feed generators with query: $query');

    state = const FindTrendsLocationState.loading();

    try {
      final generators = await _blueskyApi.unspecced.getPopularFeedGenerators(
        query: query,
        limit: 25,
      );

      if (generators.data.feeds.isNotEmpty) {
        final feedGenerators = generators.data.feeds
            .map(
              (feed) => TrendsLocationData(
                woeid: feed.hashCode,
                name: feed.displayName,
                placeType: 'feed',
                country: feed.description ?? '',
              ),
            )
            .toList();

        log.fine('found ${feedGenerators.length} feed generators');

        state = FindTrendsLocationState.data(
          locations: feedGenerators.toBuiltList(),
        );
      } else {
        log.info('no feed generators found');
        state = const FindTrendsLocationState.error();
      }
    } catch (e, st) {
      log.warning('error searching feed generators', e, st);
      state = const FindTrendsLocationState.error();
    }
  }

  Future<void> nearby() async {
    log.fine('finding popular feed generators');

    state = const FindTrendsLocationState.loading();

    try {
      final popular = await _blueskyApi.unspecced.getPopularFeedGenerators(
        limit: 25,
      );

      if (popular.data.feeds.isNotEmpty) {
        final feedGenerators = popular.data.feeds
            .map(
              (feed) => TrendsLocationData(
                woeid: feed.hashCode,
                name: feed.displayName,
                placeType: 'feed',
                country: feed.description ?? '',
              ),
            )
            .toList();

        log.fine('found ${feedGenerators.length} popular feed generators');

        state = FindTrendsLocationState.data(
          locations: feedGenerators.toBuiltList(),
        );
      } else {
        log.info('no popular feed generators found');
        state = const FindTrendsLocationState.error();
      }
    } catch (e, st) {
      log.warning('error getting popular feed generators', e, st);
      state = const FindTrendsLocationState.error();
    }
  }
}

@freezed
class FindTrendsLocationState with _$FindTrendsLocationState {
  const factory FindTrendsLocationState.initial() = _Initial;

  const factory FindTrendsLocationState.loading() = _Loading;

  const factory FindTrendsLocationState.data({
    required BuiltList<TrendsLocationData> locations,
  }) = _Data;

  const factory FindTrendsLocationState.error() = _Error;

  const factory FindTrendsLocationState.serviceDisabled() = _ServiceDisabled;

  const factory FindTrendsLocationState.permissionDenied() = _PermissionDenied;
}
