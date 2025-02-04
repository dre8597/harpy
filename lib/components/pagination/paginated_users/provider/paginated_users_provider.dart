import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

/// A class to handle paginated user data from Bluesky
class PaginatedUsers {
  PaginatedUsers({
    required this.users,
    required this.cursor,
  });

  final List<UserData> users;
  final String? cursor;
}

/// Implementation for a [PaginatedNotifierMixin] to handle [PaginatedUsers]
/// responses.
///
/// For example implementations, see:
/// * [FollowersNotifier]
/// * [FollowingNotifier]
/// * [ListsMembersNotifier]
abstract class PaginatedUsersNotifier
    extends StateNotifier<PaginatedState<BuiltList<UserData>>>
    with
        RequestLock,
        LoggerMixin,
        PaginatedNotifierMixin<PaginatedUsers, BuiltList<UserData>> {
  PaginatedUsersNotifier(super.initialState);

  @override
  Future<void> onInitialResponse(PaginatedUsers response) async {
    log.fine('received initial paginated users response');

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
    log.fine('received loading more paginated users response');

    final users = response.users;

    state = PaginatedState.data(
      data: data.rebuild((builder) => builder.addAll(users)),
      cursor: response.cursor != null ? (state.data?.length ?? 0) + 1 : null,
    );
  }
}
