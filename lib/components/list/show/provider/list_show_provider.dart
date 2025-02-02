import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/list_data.dart';
import 'package:logging/logging.dart';

import 'package:rby/rby.dart';

part 'list_show_provider.freezed.dart';

final listShowProvider = StateNotifierProvider.autoDispose
    .family<ListShowNotifier, ListShowState, String>(
  (ref, handle) => ListShowNotifier(
    handle: handle,
    ref: ref,
  ),
  name: 'ListShowProvider',
);

/// A notifier that provides list data for a user.
/// Uses the app.bsky.graph.getLists endpoint to fetch lists owned by or followed by a user.
class ListShowNotifier extends StateNotifier<ListShowState> with LoggerMixin {
  ListShowNotifier({
    required String handle,
    required Ref ref,
  })  : _handle = handle,
        _ref = ref,
        super(const ListShowState.loading()) {
    load();
  }

  final Ref _ref;
  final String _handle;
  @override
  final log = Logger('ListShowNotifier');

  Future<void> load() async {
    final _blueskyApi = _ref.read(blueskyApiProvider);

    log.fine('loading lists');
    state = const ListShowState.loading();

    try {
      // Get lists owned by the user
      final ownedLists = await _blueskyApi.graph.getLists(actor: _handle);
      final ownerships = ownedLists.data.lists
          .map(
            (list) => BlueskyListData(
              uri: list.uri.toString(),
              cid: list.cid,
              name: list.name,
              purpose: list.purpose,
              creatorDid: list.createdBy.did,
              description: list.description,
              avatar: list.avatar?.toString(),
              membersCount: 0,
              isPrivate: list.purpose == 'app.bsky.graph.defs#modlist',
              isOwner: list.createdBy.handle == _handle,
              createdAt: list.indexedAt,
            ),
          )
          .toBuiltList();

      // Get lists the user is subscribed to
      final subscribedLists = await _blueskyApi.graph
          .getLists(actor: _handle, cursor: ownedLists.data.cursor);
      final subscriptions = subscribedLists.data.lists
          .where(
            (list) => list.createdBy.handle != _handle,
          ) // Filter out owned lists
          .map(
            (list) => BlueskyListData(
              uri: list.uri.toString(),
              cid: list.cid,
              name: list.name,
              purpose: list.purpose,
              creatorDid: list.createdBy.did,
              description: list.description,
              avatar: list.avatar?.toString(),
              membersCount: 0,
              isPrivate: list.purpose == 'app.bsky.graph.defs#modlist',
              isMember: list.createdBy.handle != _handle,
              createdAt: list.indexedAt,
            ),
          )
          .toBuiltList();

      if (ownerships.isNotEmpty || subscriptions.isNotEmpty) {
        state = ListShowState.data(
          ownerships: ownerships,
          subscriptions: subscriptions,
          ownershipsCursor: ownedLists.data.cursor,
          subscriptionsCursor: subscribedLists.data.cursor,
        );
      } else {
        state = const ListShowState.noData();
      }
    } catch (e, st) {
      log.warning('error loading lists', e, st);
      state = const ListShowState.error();
    }
  }

  Future<void> loadMoreOwnerships() async {
    final currentState = state;

    if (currentState is _Data && currentState.hasMoreOwnerships) {
      state = ListShowState.loadingMoreOwnerships(
        ownerships: currentState.ownerships,
        subscriptions: currentState.subscriptions,
      );

      try {
        final _blueskyApi = _ref.read(blueskyApiProvider);

        final response = await _blueskyApi.graph.getLists(
          actor: _handle,
          cursor: currentState.ownershipsCursor,
        );

        final newOwnerships = response.data.lists
            .map(
              (list) => BlueskyListData(
                uri: list.uri.toString(),
                cid: list.cid,
                name: list.name,
                purpose: list.purpose,
                creatorDid: list.createdBy.did,
                description: list.description,
                avatar: list.avatar?.toString(),
                membersCount: 0,
                isPrivate: list.purpose == 'app.bsky.graph.defs#modlist',
                isOwner: list.createdBy.handle == _handle,
                createdAt: list.indexedAt,
              ),
            )
            .toList();

        final ownerships =
            currentState.ownerships.followedBy(newOwnerships).toBuiltList();

        state = ListShowState.data(
          ownerships: ownerships,
          subscriptions: currentState.subscriptions,
          ownershipsCursor: response.data.cursor,
          subscriptionsCursor: currentState.subscriptionsCursor,
        );
      } catch (e, st) {
        log.warning('error loading more ownerships', e, st);
        state = ListShowState.data(
          ownerships: currentState.ownerships,
          subscriptions: currentState.subscriptions,
          ownershipsCursor: null,
          subscriptionsCursor: currentState.subscriptionsCursor,
        );
      }
    }
  }

  Future<void> loadMoreSubscriptions() async {
    final currentState = state;

    if (currentState is _Data && currentState.hasMoreSubscriptions) {
      state = ListShowState.loadingMoreSubscriptions(
        ownerships: currentState.ownerships,
        subscriptions: currentState.subscriptions,
      );

      try {
        final _blueskyApi = _ref.read(blueskyApiProvider);

        final response = await _blueskyApi.graph.getLists(
          actor: _handle,
          cursor: currentState.subscriptionsCursor,
        );

        final newSubscriptions = response.data.lists
            .where(
              (list) => list.createdBy.handle != _handle,
            ) // Filter out owned lists
            .map(
              (list) => BlueskyListData(
                uri: list.uri.toString(),
                cid: list.cid,
                name: list.name,
                purpose: list.purpose,
                creatorDid: list.createdBy.did,
                description: list.description,
                avatar: list.avatar?.toString(),
                membersCount: 0,
                isPrivate: list.purpose == 'app.bsky.graph.defs#modlist',
                isMember: list.createdBy.handle != _handle,
                createdAt: list.indexedAt,
              ),
            )
            .toList();

        final subscriptions = currentState.subscriptions
            .followedBy(newSubscriptions)
            .toBuiltList();

        state = ListShowState.data(
          ownerships: currentState.ownerships,
          subscriptions: subscriptions,
          ownershipsCursor: currentState.ownershipsCursor,
          subscriptionsCursor: response.data.cursor,
        );
      } catch (e, st) {
        log.warning('error loading more subscriptions', e, st);
        state = ListShowState.data(
          ownerships: currentState.ownerships,
          subscriptions: currentState.subscriptions,
          ownershipsCursor: currentState.ownershipsCursor,
          subscriptionsCursor: null,
        );
      }
    }
  }
}

@freezed
class ListShowState with _$ListShowState {
  const factory ListShowState.loading() = _Loading;

  const factory ListShowState.data({
    required BuiltList<BlueskyListData> ownerships,
    required BuiltList<BlueskyListData> subscriptions,
    required String? ownershipsCursor,
    required String? subscriptionsCursor,
  }) = _Data;

  const factory ListShowState.noData() = _NoData;

  const factory ListShowState.loadingMoreOwnerships({
    required BuiltList<BlueskyListData> ownerships,
    required BuiltList<BlueskyListData> subscriptions,
  }) = _LoadingMoreOwnerships;

  const factory ListShowState.loadingMoreSubscriptions({
    required BuiltList<BlueskyListData> ownerships,
    required BuiltList<BlueskyListData> subscriptions,
  }) = _LoadingMoreSubscriptions;

  const factory ListShowState.error() = _Error;
}

extension ListShowStateExtension on ListShowState {
  bool get loadingMoreOwnerships => this is _LoadingMoreOwnerships;

  bool get loadingMoreSubscriptions => this is _LoadingMoreSubscriptions;

  BuiltList<BlueskyListData> get ownerships => maybeMap(
        data: (value) => value.ownerships,
        loadingMoreOwnerships: (value) => value.ownerships,
        loadingMoreSubscriptions: (value) => value.ownerships,
        orElse: BuiltList.new,
      );

  BuiltList<BlueskyListData> get subscriptions => maybeMap(
        data: (value) => value.subscriptions,
        loadingMoreOwnerships: (value) => value.subscriptions,
        loadingMoreSubscriptions: (value) => value.subscriptions,
        orElse: BuiltList.new,
      );

  bool get hasMoreOwnerships => maybeMap(
        data: (value) => value.ownershipsCursor != null,
        orElse: () => false,
      );

  bool get hasMoreSubscriptions => maybeMap(
        data: (value) =>
            value.subscriptionsCursor != null &&
            value.subscriptionsCursor != '0',
        orElse: () => false,
      );
}
