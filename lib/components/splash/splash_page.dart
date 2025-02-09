import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/data/profile_data.dart';
import 'package:harpy/components/authentication/provider/profiles_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({
    this.redirect,
  });

  /// The name of the route the user should be redirected to after
  /// initialization.
  final String? redirect;

  static const name = 'splash';
  static const path = '/splash';

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with LoggerMixin {
  bool _showLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // start app initialization and attempt auto-login
    _initializeAndAutoLogin();

    Timer(const Duration(seconds: 2), _timerCallback);
  }

  Future<void> _initializeAndAutoLogin() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // Initialize app
      await ref.read(applicationProvider).initialize(redirect: widget.redirect);

      if (!mounted) return;

      // First try to auto-login with stored profiles
      final profilesNotifier = ref.read(profilesProvider.notifier);
      final autoLoginSuccessful = await profilesNotifier.attemptAutoLogin();

      if (!mounted) return;

      if (autoLoginSuccessful) {
        // Successfully logged in with stored profile, navigate to home
        ref.read(routerProvider).goNamed(
          HomePage.name,
          queryParameters: {'transition': 'fade'},
        );
        return;
      }

      // If auto-login with profiles failed, check for stored credentials as fallback
      final authPreferences = ref.read(authPreferencesProvider);

      if (authPreferences.hasBlueskyCredentials) {
        // Attempt auto-login with stored credentials
        try {
          await ref.read(loginProvider).loginWithBluesky(
                identifier: authPreferences.blueskyHandle,
                password: authPreferences.blueskyAppPassword,
              );
        } catch (e) {
          log.warning('Fallback auto-login failed', e);
          if (mounted) {
            // Show login page with re-authentication message
            ref.read(messageServiceProvider).showText(
                  'Session expired, please re-authenticate',
                );
            ref.read(routerProvider).goNamed(
              LoginPage.name,
              queryParameters: {'transition': 'fade'},
            );
          }
        }
      } else {
        // No stored credentials, navigate to login
        ref.read(routerProvider).goNamed(
          LoginPage.name,
          queryParameters: {'transition': 'fade'},
        );
      }
    } catch (e) {
      log.warning('Auto-login failed', e);
      // If auto-login fails and widget is still mounted, navigate to login page
      if (mounted) {
        ref.read(routerProvider).goNamed(
          LoginPage.name,
          queryParameters: {'transition': 'fade'},
        );
      }
    }
  }

  Future<void> _timerCallback() async {
    if (mounted) setState(() => _showLoading = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return HarpyBackground(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: size.height / 2,
            child: const FractionallySizedBox(
              widthFactor: 0.66,
              child: FlareAnimation.harpyLogo(animation: 'show'),
            ),
          ),
          AnimatedOpacity(
            opacity: _showLoading ? 1 : 0,
            duration: theme.animation.long,
            curve: Curves.easeInOut,
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Loading...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
