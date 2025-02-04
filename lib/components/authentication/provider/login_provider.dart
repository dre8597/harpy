import 'dart:async';

import 'package:bluesky/atproto.dart';
import 'package:bluesky/bluesky.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

import 'package:rby/rby.dart';

/// Handles login using Bluesky authentication.
///
/// Authentication logic used to be split between Twitter and Bluesky, but is now
/// updated to exclusively use Bluesky authentication via loginWithBluesky.
final loginProvider = Provider(
  (ref) => _Login(
    ref: ref,
    environment: ref.watch(environmentProvider),
  ),
  name: 'LoginProvider',
);

class _Login with LoggerMixin {
  const _Login({
    required Ref ref,
    required Environment environment,
  })  : _ref = ref,
        _environment = environment;

  final Ref _ref;
  final Environment _environment;

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

    final environment = _ref.read(environmentProvider);
    log.fine(
      'Using AES key: ${environment.aesKey.substring(0, 10)}...',
    ); // Only log part of the key for security

    _ref.read(authenticationStateProvider.notifier).state =
        const AuthenticationState.awaitingAuthentication();

    try {
      final service = _ref.read(blueskyServiceProvider);

      // Create session
      final session = await createSession(
        service: service,
        identifier: identifier,
        password: password,
      );

      // Store credentials and session data
      await _ref.read(authPreferencesProvider.notifier).setBlueskyAuth(
            handle: identifier,
            password: password,
          );

      await _ref.read(authPreferencesProvider.notifier).setBlueskySession(
            accessJwt: session.data.accessJwt,
            refreshJwt: session.data.refreshJwt,
            did: session.data.did,
          );

      log.fine('successfully authenticated with Bluesky');

      // Get authenticated instance
      final bluesky = Bluesky.fromSession(
        session.data,
        service: service,
      );

      await _ref.read(blueskyApiProvider.notifier).setBlueskySession(bluesky);

      // Get user profile
      final profile = await bluesky.actor.getProfile(actor: identifier);

      final userData = UserData.fromBlueskyActorProfile(profile.data);
      _ref.read(authenticationStateProvider.notifier).state =
          AuthenticationState.authenticated(user: userData);

      // Navigate based on setup status
      if (_ref.read(setupPreferencesProvider).performedSetup) {
        _ref.read(routerProvider).goNamed(HomePage.name);
      } else {
        _ref.read(routerProvider).goNamed(SetupPage.name);
      }
    } catch (e) {
      log.warning('error authenticating with Bluesky', e);
      _ref.read(authenticationStateProvider.notifier).state =
          const AuthenticationState.unauthenticated();
      _ref.read(messageServiceProvider).showText('authentication failed');
    }
  }
}
