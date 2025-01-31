import 'dart:async';

import 'package:bluesky/atproto.dart';
import 'package:bluesky/bluesky.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

import 'package:rby/rby.dart';
import 'package:twitter_webview_auth/twitter_webview_auth.dart';

/// Handles login.
///
/// Authentication logic is split between
/// * [authenticationProvider]
/// * [loginProvider]
/// * [logoutProvider]
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

  /// Initializes a web based twitter authentication.
  ///
  /// Navigates to
  /// * [HomePage] on successful authentication
  /// * [SetupPage] on successful authentication if the setup has not yet been
  ///   completed
  /// * [LoginPage] when authentication was not successful.
  Future<void> login() async {
    if (!_environment.validateAppConfig()) {
      _ref
          .read(messageServiceProvider)
          .showText('invalid twitter key / secret');
      return;
    }

    log.fine('logging in');

    _ref.read(authenticationStateProvider.notifier).state =
        const AuthenticationState.awaitingAuthentication();

    final key = _ref.read(consumerKeyProvider);
    final secret = _ref.read(consumerSecretProvider);

    final result = await TwitterAuth(
      consumerKey: key,
      consumerSecret: secret,
      callbackUrl: 'harpy://',
    ).authenticateWithTwitter(
      webviewNavigation: _webviewNavigation,
    );

    await result.when(
      success: (token, secret, userId) async {
        log.fine('successfully authenticated');

        _ref.read(authPreferencesProvider.notifier).setAuth(
              token: token,
              secret: secret,
              userId: userId,
            );

        await _ref
            .read(authenticationProvider)
            .onLogin(_ref.read(authPreferencesProvider));

        if (_ref.read(authenticationStateProvider).isAuthenticated) {
          if (_ref.read(setupPreferencesProvider).performedSetup) {
            _ref.read(routerProvider).goNamed(
              HomePage.name,
              queryParameters: {'transition': 'fade'},
            );
          } else {
            _ref.read(routerProvider).goNamed(SetupPage.name);
          }
        } else {
          _ref.read(routerProvider).goNamed(LoginPage.name);
        }
      },
      failure: (e, st) {
        log.warning(
          'login failed\n\n'
          'If this issue is persistent, see\n'
          'https://github.com/robertodoering/harpy/wiki/Troubleshooting',
          e,
          st,
        );

        _ref.read(messageServiceProvider).showSnackbar(
              const SnackBar(
                content: Text('authentication failed, please try again'),
              ),
            );

        _ref.read(authenticationStateProvider.notifier).state =
            const AuthenticationState.unauthenticated();

        _ref.read(routerProvider).goNamed(LoginPage.name);
      },
      cancelled: () {
        log.fine('login cancelled by user');

        _ref.read(authenticationStateProvider.notifier).state =
            const AuthenticationState.unauthenticated();

        _ref.read(routerProvider).goNamed(LoginPage.name);
      },
    );
  }

  /// Used by [TwitterAuth] to navigate to the login webview page.
  Future<Uri?> _webviewNavigation(TwitterLoginWebview webview) async {
    final context =
        _ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
    if (context == null) return null;

    return Navigator.of(context).push<Uri?>(
      MaterialPageRoute<Uri?>(
        builder: (_) => LoginWebview(webview: webview),
      ),
    );
  }

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

      // Create session
      final session = await createSession(
        service: service,
        identifier: identifier,
        password: password,
      );

      // Store credentials
      _ref.read(authPreferencesProvider.notifier).setBlueskyAuth(
            handle: identifier,
            password: password,
          );

      log.fine('successfully authenticated with Bluesky');

      // Get authenticated instance
      final bluesky = Bluesky.fromSession(
        session.data,
        service: service,
      );

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
