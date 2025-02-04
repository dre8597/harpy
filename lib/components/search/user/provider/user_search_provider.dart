import 'package:built_collection/built_collection.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';
import 'package:rby/rby.dart';

part 'user_search_provider.freezed.dart';

final userSearchProvider = StateNotifierProvider.autoDispose<UserSearchNotifier,
    PaginatedState<UsersSearchData>>(
  (ref) => UserSearchNotifier(
    ref: ref,
  ),
  name: 'UserSearchProvider',
);

class UserSearchNotifier extends StateNotifier<PaginatedState<UsersSearchData>>
    with RequestLock, LoggerMixin {
  UserSearchNotifier({
    required Ref ref,
  })  : _ref = ref,
        super(const PaginatedState.initial());

  final Ref _ref;
  @override
  final log = Logger('UserSearchNotifier');

  Future<void> _load({
    required String query,
    required int cursor,
    required Iterable<UserData> oldUsers,
  }) async {
    try {
      final blueskyApi = _ref.read(blueskyApiProvider);

      final response = await blueskyApi.actor.searchActors(
        term: query,
        limit: 20,
        cursor: cursor > 1 ? cursor.toString() : null,
      );

      final newUsers = await Future.wait(
        response.data.actors
            .whereNot(
          (actor) => oldUsers.any((oldUser) => actor.did == oldUser.id),
        )
            .map((actor) async {
          // Get full profile for each actor to get counts
          final profile = await blueskyApi.actor.getProfile(actor: actor.did);
          return UserData(
            id: actor.did,
            name: actor.displayName ?? actor.handle,
            handle: actor.handle,
            description: actor.description,
            profileImage: actor.avatar != null
                ? UserProfileImage.fromUrl(actor.avatar!)
                : null,
            followersCount: profile.data.followersCount,
            followingCount: profile.data.followsCount,
            tweetCount: profile.data.postsCount,
            createdAt: DateTime.now(), // Bluesky doesn't provide creation date
          );
        }),
      );

      log.fine('found ${newUsers.length} new users');

      final data = UsersSearchData(
        query: query,
        users: oldUsers.followedBy(newUsers).toBuiltList(),
      );

      state = PaginatedState.data(
        data: data,
        cursor: response.data.cursor != null ? cursor + 1 : null,
      );
    } catch (e, st) {
      log.warning('error searching users', e, st);
      if (oldUsers.isEmpty) {
        state = const PaginatedState.error();
      } else {
        // re-emit old data and disable loading more
        state = PaginatedState.data(
          data: UsersSearchData(
            users: oldUsers.toBuiltList(),
            query: query,
          ),
        );
      }
    }
  }

  Future<void> search(String query) async {
    state = const PaginatedState.loading();

    await _load(query: query, oldUsers: [], cursor: 1);
  }

  Future<void> loadMore() async {
    if (lock()) return;

    if (state.canLoadMore) {
      await state.mapOrNull(
        data: (value) async {
          state = PaginatedState.loadingMore(data: value.data);

          await _load(
            query: value.data.query,
            oldUsers: value.data.users,
            cursor: value.cursor!,
          );
        },
      );
    }
  }

  void clear() {
    state = const PaginatedState.initial();
  }
}

@freezed
class UsersSearchData with _$UsersSearchData {
  const factory UsersSearchData({
    required BuiltList<UserData> users,
    required String query,
  }) = _Data;
}
