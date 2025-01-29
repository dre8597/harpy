import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

part 'authentication_provider.freezed.dart';

final authenticationStateProvider = StateProvider(
  (ref) => const AuthenticationState.unauthenticated(),
  name: 'AuthenticationStateProvider',
);

/// Handles common authentication.
///
/// Authentication logic is split between
/// * [authenticationProvider]
/// * [loginProvider]
/// * [logoutProvider]
final authenticationProvider = Provider(
  (ref) => Authentication(ref: ref),
  name: 'AuthenticationProvider',
);

class Authentication with LoggerMixin {
  const Authentication({
    required Ref ref,
  }) : _ref = ref;

  final Ref _ref;

  /// Restores a previous session if one exists.
  Future<void> restoreSession() async {
    final authPreferences = _ref.read(authPreferencesProvider);

    if (authPreferences.isValid || authPreferences.hasBlueskyCredentials) {
      log.fine('session restored');
      await onLogin(authPreferences);
    } else {
      log.fine('no previous session exists');
    }
  }

  /// Requests the authenticated user's data to finalize the login.
  Future<void> onLogin(AuthPreferences auth) async {
    log.fine('on login');

    UserData? user;

    // Try Bluesky authentication first if credentials exist
    if (auth.hasBlueskyCredentials) {
      user = await _initializeBlueskyUser(auth.blueskyHandle);
    } else if (auth.isValid) {
      // Fall back to Twitter authentication
      user = await _initializeTwitterUser(auth.userId);
    }

    if (user != null) {
      log.info('authenticated user successfully initialized');

      _ref.read(authenticationStateProvider.notifier).state =
          AuthenticationState.authenticated(user: user);
    } else {
      log.info('authenticated user not initialized');

      // failed initializing login
      // remove retrieved session assuming it's not valid anymore
      await onLogout();
    }
  }

  /// Invalidates and removes the saved session.
  Future<void> onLogout() async {
    log.fine('on logout');

    final authPreferences = _ref.read(authPreferencesProvider);

    // Handle Twitter logout
    if (authPreferences.isValid) {
      // _ref
      //     .read(twitterApiV1Provider)
      //     .client
      //     .post(Uri.https('api.twitter.com', '1.1/oauth/invalidate_token'))
      //     .handleError(logErrorHandler)
      //     .ignore();
    }

    // Handle Bluesky logout
    if (authPreferences.hasBlueskyCredentials) {
      try {
        // No need to explicitly invalidate the session
        // The session will be cleared when we clear the auth preferences
        log.fine('clearing Bluesky session');
      } catch (e, st) {
        logErrorHandler(e, st);
      }
    }

    // clear saved session
    _ref.read(authPreferencesProvider.notifier).clearAuth();

    _ref.read(authenticationStateProvider.notifier).state =
        const AuthenticationState.unauthenticated();
  }

  /// Requests the [UserData] for the authenticated Twitter user.
  Future<UserData?> _initializeTwitterUser(String userId) async {
    // final twitterApi = _ref.read(twitterApiV1Provider);

    try {
      // final user = await twitterApi.userService.usersShow(userId: userId).then(UserData.fromV1);
      // return user;
      return null;
    } catch (e, st) {
      logErrorHandler(e, st);

      if (e is TimeoutException || e is SocketException) {
        // unable to authenticate user, allow to retry in case of temporary
        // network error
        final retry = await _ref
            .read(dialogServiceProvider)
            .show<bool>(child: const RetryAuthenticationDialog());

        if (retry ?? false) return _initializeTwitterUser(userId);
      }

      return null;
    }
  }

  /// Requests the [UserData] for the authenticated Bluesky user.
  Future<UserData?> _initializeBlueskyUser(String handle) async {
    try {
      final bluesky = await _ref.read(blueskyApiProvider);
      final actor = bluesky.actor;

      final profile = await actor.getProfile(actor: handle);
      return UserData.fromBlueskyActorProfile(profile.data);
    } catch (e, st) {
      logErrorHandler(e, st);

      if (e is TimeoutException || e is SocketException) {
        // unable to authenticate user, allow to retry in case of temporary
        // network error
        final retry = await _ref
            .read(dialogServiceProvider)
            .show<bool>(child: const RetryAuthenticationDialog());

        if (retry ?? false) return _initializeBlueskyUser(handle);
      }

      return null;
    }
  }
}

@freezed
class AuthenticationState with _$AuthenticationState {
  const factory AuthenticationState.authenticated({
    required UserData user,
  }) = _Authenticated;

  const factory AuthenticationState.unauthenticated() = _Unauthenticated;
  const factory AuthenticationState.awaitingAuthentication() = _AwaitingAuthentication;
}

extension AuthenticationStateExtension on AuthenticationState {
  UserData? get user => mapOrNull(authenticated: (value) => value.user);

  bool get isAuthenticated => this is _Authenticated;
  bool get isAwaitingAuthentication => this is _AwaitingAuthentication;
}
