import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

/// A class to handle paginated following data from Bluesky
class PaginatedFollowing {
  PaginatedFollowing({
    required this.following,
    required this.cursor,
  });

  final List<UserData> following;
  final String? cursor;
}

final followingProvider = StateNotifierProvider.autoDispose
    .family<FollowingNotifier, PaginatedState<BuiltList<UserData>>, String>(
  (ref, handle) => FollowingNotifier(
    ref: ref,
    handle: handle,
  ),
  name: 'FollowingProvider',
);

class FollowingNotifier extends PaginatedUsersNotifier {
  FollowingNotifier({
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
    log.warning('error loading following', error, stackTrace);
    _ref.read(messageServiceProvider).showText('error loading following');
  }

  @override
  Future<PaginatedUsers> request([int? cursor]) async {
    final _blueskyApi = _ref.read(blueskyApiProvider);

    final response = await _blueskyApi.graph.getFollows(
      actor: _handle,
      cursor: cursor?.toString(),
      limit: 50,
    );

    final following = await Future.wait(
      response.data.follows.map((actor) async {
        final profile = await _blueskyApi.actor.getProfile(actor: actor.did);
        return UserData.fromBlueskyActorProfile(profile.data);
      }),
    );

    return PaginatedUsers(
      users: following,
      cursor: response.data.cursor,
    );
  }

  @override
  Future<void> onInitialResponse(PaginatedUsers response) async {
    log.fine('received initial paginated following response');

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
    log.fine('received loading more paginated following response');

    final users = response.users;

    state = PaginatedState.data(
      data: data.rebuild((builder) => builder.addAll(users)),
      cursor: response.cursor != null ? (state.data?.length ?? 0) + 1 : null,
    );
  }
}
