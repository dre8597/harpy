import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      //
      // // Check for stored credentials
      // final authPreferences = ref.read(authPreferencesProvider);
      //
      // if (authPreferences.hasBlueskyCredentials && !mounted) {
      //   // If we have credentials but the widget is no longer mounted,
      //   // let the application provider handle navigation
      //   return;
      // }
      //
      // if (authPreferences.hasBlueskyCredentials && mounted) {
      //   // Attempt auto-login with stored credentials
      //   await ref.read(loginProvider).loginWithBluesky(
      //         identifier: authPreferences.blueskyHandle,
      //         password: authPreferences.blueskyAppPassword,
      //       );
      // } else if (mounted) {
      //   // No stored credentials, navigate to login
      //   ref.read(routerProvider).goNamed(
      //     LoginPage.name,
      //     queryParameters: {'transition': 'fade'},
      //   );
      // }
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
            child: const CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
