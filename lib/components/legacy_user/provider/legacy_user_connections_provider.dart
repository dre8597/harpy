import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

/// Provides the [LegacyUserConnection] for a list of users.
///
/// Connections are mapped to the user handle.
final legacyUserConnectionsProvider = StateNotifierProvider<
    LegacyUserConnectionsNotifier,
    BuiltMap<String, BuiltSet<LegacyUserConnection>>>(
  (ref) => LegacyUserConnectionsNotifier(
    ref: ref,
    blueskyApi: ref.watch(blueskyApiProvider),
  ),
  name: 'legacyUserConnectionsProvider',
);

class LegacyUserConnectionsNotifier
    extends StateNotifier<BuiltMap<String, BuiltSet<LegacyUserConnection>>> {
  LegacyUserConnectionsNotifier({
    required Ref ref,
    required bsky.Bluesky blueskyApi,
  })  : _ref = ref,
        _blueskyApi = blueskyApi,
        super(BuiltMap());

  final Ref _ref;
  final bsky.Bluesky _blueskyApi;
  final log = Logger('LegacyUserConnectionsNotifier');

  Future<void> load(List<String> authorDids) async {
    try {
      final mappedConnections = <String, BuiltSet<LegacyUserConnection>>{};

      await Future.wait(
        authorDids.map((authorDid) async {
          try {
            final profile =
                await _blueskyApi.actor.getProfile(actor: authorDid);
            final connections = <LegacyUserConnection>[];

            if (profile.data.viewer.following != null) {
              connections.add(LegacyUserConnection.following);
            }

            if (profile.data.viewer.blocking != null) {
              connections.add(LegacyUserConnection.blocking);
            }

            if (profile.data.viewer.isMuted) {
              connections.add(LegacyUserConnection.muting);
            }

            mappedConnections[authorDid] = connections.toBuiltSet();
          } catch (e, st) {
            log.warning('error loading profile for $authorDid', e, st);
          }
        }),
      );

      state = BuiltMap(mappedConnections);
    } catch (e, st) {
      log.warning('error loading user connections', e, st);
      _ref
          .read(messageServiceProvider)
          .showText('error loading user connections');
    }
  }

  Future<void> follow(String handle) async {
    log.fine('follow $handle');

    state = state.rebuild(
      (builder) => builder[handle] = _addOrCreateConnection(
        builder[handle],
        LegacyUserConnection.following,
      ),
    );

    try {
      final profile = await _blueskyApi.actor.getProfile(actor: handle);
      await _blueskyApi.graph.follow(did: profile.data.did);
    } catch (e, st) {
      log.warning('error following user', e, st);
      _ref.read(messageServiceProvider).showText('error following user');

      if (!mounted) return;

      // assume still not following
      state = state.rebuild(
        (builder) => builder[handle] = _removeOrCreateConnection(
          builder[handle],
          LegacyUserConnection.following,
        ),
      );
    }
  }

  Future<void> unfollow(String handle) async {
    log.fine('unfollow $handle');

    state = state.rebuild(
      (builder) => builder[handle] = _removeOrCreateConnection(
        builder[handle],
        LegacyUserConnection.following,
      ),
    );

    try {
      final profile = await _blueskyApi.actor.getProfile(actor: handle);
      await _blueskyApi.atproto.repo
          .deleteRecord(uri: profile.data.viewer.following!);
    } catch (e, st) {
      log.warning('error unfollowing user', e, st);
      _ref.read(messageServiceProvider).showText('error unfollowing user');

      if (!mounted) return;

      // assume still following
      state = state.rebuild(
        (builder) => builder[handle] = _addOrCreateConnection(
          builder[handle],
          LegacyUserConnection.following,
        ),
      );
    }
  }

  BuiltSet<LegacyUserConnection> _addOrCreateConnection(
    BuiltSet<LegacyUserConnection>? connections,
    LegacyUserConnection connection,
  ) {
    if (connections == null) {
      return BuiltSet<LegacyUserConnection>({connection});
    } else {
      return connections.rebuild((builder) => builder.add(connection));
    }
  }

  BuiltSet<LegacyUserConnection> _removeOrCreateConnection(
    BuiltSet<LegacyUserConnection>? connections,
    LegacyUserConnection connection,
  ) {
    if (connections == null) {
      return BuiltSet<LegacyUserConnection>();
    } else {
      return connections.rebuild((builder) => builder.remove(connection));
    }
  }
}
