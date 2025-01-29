import 'package:bluesky/atproto.dart';
import 'package:bluesky/bluesky.dart';
import 'package:bluesky/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';

/// Provider for the Bluesky API client.
/// Returns an anonymous client if no credentials are available.
final blueskyApiProvider = Provider<Future<Bluesky>>(
  name: 'blueskyApiProvider',
  (ref) async {
    final authPreferences = ref.watch(authPreferencesProvider);
    final service = ref.watch(blueskyServiceProvider);

    // Return anonymous instance if no credentials
    if (!authPreferences.hasBlueskyCredentials) {
      return Bluesky.anonymous(service: service);
    }

    try {
      // Create session with retry logic
      final session = await _createSessionWithRetry(
        service: service,
        identifier: authPreferences.blueskyHandle,
        password: authPreferences.blueskyAppPassword,
      );

      // Create authenticated instance
      return Bluesky.fromSession(
        session.data,
        service: service,
      );
    } catch (e) {
      // Log error for debugging
      print('Failed to create Bluesky session: $e');
      // If session creation fails, return anonymous instance
      return Bluesky.anonymous(service: service);
    }
  },
);

/// Provider for the Bluesky service URL.
/// Returns the custom service URL if configured, otherwise returns the default.
final blueskyServiceProvider = Provider<String>(
  name: 'blueskyServiceProvider',
  (ref) {
    final customApiPreferences = ref.watch(customApiPreferencesProvider);
    return customApiPreferences.customBlueskyService ?? 'https://bsky.social';
  },
);

/// Helper function to create a session with retry logic
Future<XRPCResponse<Session>> _createSessionWithRetry({
  required String service,
  required String identifier,
  required String password,
  int maxAttempts = 3,
}) async {
  var attempts = 0;
  late Exception lastError;

  while (attempts < maxAttempts) {
    try {
      return await createSession(
        service: service,
        identifier: identifier,
        password: password,
      );
    } catch (e) {
      lastError = e as Exception;
      attempts++;
      if (attempts < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempts));
      }
    }
  }
  throw lastError;
}
