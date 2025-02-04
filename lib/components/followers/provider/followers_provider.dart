import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

/// A class to handle paginated followers data from Bluesky
class PaginatedFollowers {
  PaginatedFollowers({
    required this.followers,
    required this.cursor,
  });

  final List<UserData> followers;
  final String? cursor;
}

final followersProvider = StateNotifierProvider.autoDispose
    .family<FollowersNotifier, PaginatedState<BuiltList<UserData>>, String>(
  (ref, handle) => FollowersNotifier(
    ref: ref,
    handle: handle,
  ),
  name: 'FollowersProvider',
);

class FollowersNotifier extends PaginatedUsersNotifier {
  FollowersNotifier({
    required Ref ref,
    required String handle,
  })  : _ref = ref,
        _handle = handle,
        super(const PaginatedState.loading()) {
    loadInitial();
  }

  final Ref _ref;
  final String _handle;

  @override
  Future<void> onRequestError(Object error, StackTrace stackTrace) async {
    log.warning('error loading followers', error, stackTrace);
    _ref.read(messageServiceProvider).showText('error loading followers');
  }

  @override
  Future<PaginatedUsers> request([int? cursor]) async {
    final blueskyApi = _ref.read(blueskyApiProvider);
    final response = await blueskyApi.graph.getFollowers(
      actor: _handle,
      cursor: cursor?.toString(),
      limit: 50,
    );

    final followers = await Future.wait(
      response.data.followers.map((actor) async {
        final profile = await blueskyApi.actor.getProfile(actor: actor.did);
        return UserData.fromBlueskyActorProfile(profile.data);
      }),
    );

    return PaginatedUsers(
      users: followers,
      cursor: response.data.cursor,
    );
  }

  @override
  Future<void> onInitialResponse(PaginatedUsers response) async {
    log.fine('received initial paginated followers response');

    final users = response.users.toBuiltList();

    if (users.isEmpty) {
      state = const PaginatedState.noData();
    } else {
      state = PaginatedState.data(
        data: users,
        cursor: response.cursor != null ? 1 : null,
      );
    }
  }

  @override
  Future<void> onMoreResponse(
    PaginatedUsers response,
    BuiltList<UserData> data,
  ) async {
    log.fine('received loading more paginated followers response');

    final users = response.users;

    state = PaginatedState.data(
      data: data.rebuild((builder) => builder.addAll(users)),
      cursor: response.cursor != null ? (state.data?.length ?? 0) + 1 : null,
    );
  }
}
