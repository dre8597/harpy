import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/authentication/provider/profiles_provider.dart';
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

    // Set state to awaiting authentication while we restore
    _ref.read(authenticationStateProvider.notifier).state =
        const AuthenticationState.awaitingAuthentication();

    // First try to restore session from stored profiles
    if (authPreferences.hasBlueskySession) {
      log.fine('attempting to restore session from stored profiles');
      try {
        // Wait for the Bluesky API to be ready before proceeding
        await _ref.read(blueskyApiProvider.notifier).initialize();

        final autoLoginSuccessful =
            await _ref.read(profilesProvider.notifier).attemptAutoLogin();

        if (autoLoginSuccessful) {
          log.fine('session restored from stored profiles');
          return;
        } else {
          log.fine('auto-login failed, clearing session');
          await _ref
              .read(authPreferencesProvider.notifier)
              .clearBlueskySession();
          _ref.read(authenticationStateProvider.notifier).state =
              const AuthenticationState.unauthenticated();
          // Navigate back to login on failure
          _ref.read(routerProvider).goNamed(LoginPage.name);
          _ref.read(messageServiceProvider).showText(
                'Welcome back! Please sign in to continue using Harpy',
              );
        }
      } catch (e, st) {
        logErrorHandler(e, st);
        // Clear the invalid session
        await _ref.read(authPreferencesProvider.notifier).clearBlueskySession();
        _ref.read(authenticationStateProvider.notifier).state =
            const AuthenticationState.unauthenticated();
        // Navigate back to login on error
        _ref.read(routerProvider).goNamed(LoginPage.name);
        _ref.read(messageServiceProvider).showText(
              'Unable to restore your previous session. Please sign in again',
            );
      }
    } else if (authPreferences.hasBlueskyCredentials) {
      log.fine('attempting to restore session from credentials');
      try {
        _ref.read(messageServiceProvider).showText(
              'Restoring your previous session...',
            );
        await onLogin(authPreferences);
      } catch (e, st) {
        logErrorHandler(e, st);
        // Clear auth and navigate to login on error
        await _ref.read(authPreferencesProvider.notifier).clearAuth();
        _ref.read(authenticationStateProvider.notifier).state =
            const AuthenticationState.unauthenticated();
        _ref.read(routerProvider).goNamed(LoginPage.name);
        _ref.read(messageServiceProvider).showText(
              'Unable to sign you in automatically. Please try signing in again',
            );
      }
    } else {
      log.fine('no previous session exists');
      _ref.read(authenticationStateProvider.notifier).state =
          const AuthenticationState.unauthenticated();
      // Navigate to login since no session exists
      _ref.read(routerProvider).goNamed(LoginPage.name);
    }
  }

  /// Requests the authenticated user's data to finalize the login.
  Future<void> onLogin(AuthPreferences auth) async {
    log.fine('on login');

    _ref.read(authenticationStateProvider.notifier).state =
        const AuthenticationState.awaitingAuthentication();

    UserData? user;

    // Try Bluesky authentication first if credentials exist
    if (auth.hasBlueskyCredentials) {
      try {
        // First try to initialize the Bluesky API with stored session if available
        if (auth.hasBlueskySession) {
          _ref.read(messageServiceProvider).showText(
                'Checking your saved session...',
              );
          // Ensure Bluesky API is initialized
          await _ref.read(blueskyApiProvider.notifier).initialize();
          final bluesky = _ref.read(blueskyApiProvider);
          user = await _initializeBlueskyUser(auth.blueskyHandle);
        }

        // If that fails or no session exists, try creating a new session
        if (user == null) {
          _ref.read(messageServiceProvider).showText(
                'Creating a new session for you...',
              );
          await _ref.read(loginProvider).loginWithBluesky(
                identifier: auth.blueskyHandle,
                password: auth.blueskyAppPassword,
              );
          // loginWithBluesky handles setting up the user state
          return;
        }
      } catch (e, st) {
        logErrorHandler(e, st);
        user = null;
      }
    } else if (auth.isValid) {
      // Fall back to Twitter authentication
      user = await _initializeTwitterUser(auth.userId);
    }

    if (user != null) {
      log.info('authenticated user successfully initialized');
      _ref.read(messageServiceProvider).showText(
            'Welcome back, ${user.name}!',
          );

      _ref.read(authenticationStateProvider.notifier).state =
          AuthenticationState.authenticated(user: user);
    } else {
      log.info('authenticated user not initialized');
      _ref.read(messageServiceProvider).showText(
            'Unable to sign you in. Please check your connection and try again',
          );

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
        // Clear the active profile if any
        final activeProfile =
            _ref.read(profilesProvider.notifier).getActiveProfile();
        if (activeProfile != null) {
          await _ref
              .read(profilesProvider.notifier)
              .removeProfile(activeProfile.did);
        }
        log.fine('cleared active Bluesky profile');
        _ref.read(messageServiceProvider).showText(
              'You have been signed out successfully',
            );
      } catch (e, st) {
        logErrorHandler(e, st);
        _ref.read(messageServiceProvider).showText(
              'There was an issue signing you out. Please try again',
            );
      }
    }

    // clear saved session
    await _ref.read(authPreferencesProvider.notifier).clearAuth();

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
      final bluesky = _ref.read(blueskyApiProvider);
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

  const factory AuthenticationState.awaitingAuthentication() =
      _AwaitingAuthentication;
}

extension AuthenticationStateExtension on AuthenticationState {
  UserData? get user => mapOrNull(authenticated: (value) => value.user);

  bool get isAuthenticated => this is _Authenticated;

  bool get isAwaitingAuthentication => this is _AwaitingAuthentication;
}
