import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

final listMembersProvider = StateNotifierProvider.autoDispose
    .family<ListsMembersNotifier, PaginatedState<BuiltList<UserData>>, String>(
  (ref, listId) => ListsMembersNotifier(
    ref: ref,
    listId: listId,
  ),
  name: 'ListMembersProvider',
);

/// A notifier that provides paginated list members data.
/// NOTE: List functionality is not yet available in the Bluesky API.
/// This class will be updated once the API supports lists.
class ListsMembersNotifier extends PaginatedUsersNotifier {
  ListsMembersNotifier({
    required Ref ref,
    required String listId,
  })  : _ref = ref,
        super(const PaginatedState.loading()) {
    loadInitial();
  }

  final Ref _ref;

  @override
  Future<void> onRequestError(Object error, StackTrace stackTrace) async {
    log.warning('error loading list members', error, stackTrace);
    _ref.read(messageServiceProvider).showText('error loading list members');
  }

  @override
  Future<PaginatedUsers> request([
    int? cursor,
  ]) async {
    // TODO: Implement once Bluesky API supports lists
    throw UnimplementedError(
      'List functionality is not yet available in the Bluesky API. '
      'This feature will be implemented once the API supports lists.',
    );
  }
}
