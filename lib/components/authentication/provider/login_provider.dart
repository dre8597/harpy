import 'dart:async';

import 'package:bluesky/atproto.dart';
import 'package:bluesky/bluesky.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/data/models.dart' as models;
import 'package:harpy/api/bluesky/data/profile_data.dart';
import 'package:harpy/components/authentication/provider/profiles_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';

/// Handles login using Bluesky authentication.
///
/// Authentication logic used to be split between Twitter and Bluesky, but is now
/// updated to exclusively use Bluesky authentication via loginWithBluesky.
final loginProvider = Provider.autoDispose(LoginNotifier.new);

class LoginNotifier {
  LoginNotifier(this._ref) : log = Logger('LoginNotifier');

  final Ref _ref;
  final Logger log;

  /// Initializes a Bluesky authentication.
  ///
  /// Navigates to
  /// * [HomePage] on successful authentication
  /// * [SetupPage] on successful authentication if the setup has not yet been completed
  /// * [LoginPage] when authentication was not successful.
  Future<void> loginWithBluesky({
    required String identifier,
    required String password,
  }) async {
    log.fine('logging in with Bluesky');

    _ref.read(authenticationStateProvider.notifier).state =
        const AuthenticationState.awaitingAuthentication();

    try {
      final service = _ref.read(blueskyServiceProvider);

      // Create initial session
      final session = await createSession(
        service: service,
        identifier: identifier,
        password: password,
      );

      // Get initial profile data to create StoredProfileData
      final bluesky = Bluesky.fromSession(
        session.data,
        service: service,
      );
      final profile = await bluesky.actor.getProfile(actor: identifier);

      // Create profile data
      final profileData = StoredProfileData.fromProfile(
        profile: models.Profile(
          did: profile.data.did,
          handle: profile.data.handle,
          displayName: profile.data.displayName,
          description: profile.data.description,
          avatar: profile.data.avatar,
          banner: profile.data.banner,
          followersCount: profile.data.followersCount,
          followsCount: profile.data.followsCount,
          postsCount: profile.data.postsCount,
          viewer: models.ProfileViewer(
            following: profile.data.viewer.following?.toString(),
            followedBy: profile.data.viewer.followedBy?.toString(),
            blocking: profile.data.viewer.blocking?.toString(),
          ),
        ),
        appPassword: password,
        accessJwt: session.data.accessJwt,
        refreshJwt: session.data.refreshJwt,
        isActive: true,
        mediaPreferences: _ref.read(mediaPreferencesProvider),
        feedPreferences: _ref.read(feedPreferencesProvider),
        themeMode: _ref.read(themeProvider).themeMode.name,
      );

      // Add profile and switch to it
      // This will handle setting up auth state, preferences, and API client
      await _ref.read(profilesProvider.notifier).addProfile(profileData);
      await _ref
          .read(profilesProvider.notifier)
          .switchToProfile(profile.data.did);

      // Navigate based on setup status
      if (_ref.read(setupPreferencesProvider).performedSetup) {
        _ref.read(routerProvider).goNamed(HomePage.name);
      } else {
        _ref.read(routerProvider).goNamed(SetupPage.name);
      }
    } catch (error) {
      log.severe('Failed to authenticate with Bluesky', error);
      _ref.read(authenticationStateProvider.notifier).state =
          const AuthenticationState.unauthenticated();
      _ref.read(messageServiceProvider).showText('Authentication failed');
    }
  }
}
