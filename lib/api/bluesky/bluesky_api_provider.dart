import 'package:bluesky/atproto.dart';
import 'package:bluesky/bluesky.dart';
import 'package:bluesky/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'dart:async';

/// Status of the Bluesky client initialization
enum BlueskyStatus {
  initial,
  loading,
  error,
  ready,
}

/// Provider for the Bluesky client.
/// The client is initialized automatically when first accessed.
final blueskyApiProvider = NotifierProvider<BlueskyClientNotifier, Bluesky>(
  BlueskyClientNotifier.new,
  name: 'blueskyClientNotifier',
);

/// Notifier that manages a single Bluesky client instance.
/// Automatically initializes when accessed and maintains the client state.
class BlueskyClientNotifier extends Notifier<Bluesky> {
  BlueskyStatus _status = BlueskyStatus.initial;
  Object? _error;
  Timer? _refreshTimer;

  @override
  Bluesky build() {
    // Cancel timer when notifier is disposed
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    // Initialize with anonymous client
    final service = ref.read(blueskyServiceProvider);
    final client = Bluesky.anonymous(service: service);

    return client;
  }

  Future<void> _initialize() async {
    if (_status == BlueskyStatus.ready) return;

    _status = BlueskyStatus.loading;
    _error = null;

    try {
      final authPreferences = ref.read(authPreferencesProvider);
      final service = ref.read(blueskyServiceProvider);

      if (!authPreferences.hasBlueskyCredentials) {
        state = Bluesky.anonymous(service: service);
      } else {
        Bluesky client;

        // Try to restore from stored session first
        if (authPreferences.hasBlueskySession) {
          client = await _restoreSession(service);
        } else {
          // No stored session, create new one
          client = await _createAuthenticatedClient(
            service: service,
            identifier: authPreferences.blueskyHandle,
            password: authPreferences.blueskyAppPassword,
          );
        }

        state = client;
        _scheduleTokenRefresh();
      }

      _status = BlueskyStatus.ready;
    } catch (e) {
      _error = e;
      _status = BlueskyStatus.error;
      // Keep the anonymous client in error state and clear auth
      final service = ref.read(blueskyServiceProvider);
      state = Bluesky.anonymous(service: service);
      ref.read(authPreferencesProvider.notifier).clearAuth();
      // Navigate back to login
      ref.read(routerProvider).goNamed(LoginPage.name);
    }
  }

  Future<void> setBlueskySession(Bluesky client) async {
    state = client;
    _scheduleTokenRefresh();
  }

  Future<Bluesky> _restoreSession(String service) async {
    final authPreferences = ref.read(authPreferencesProvider);

    try {
      final client = Bluesky.fromSession(
        Session(
          accessJwt: authPreferences.blueskyAccessJwt,
          refreshJwt: authPreferences.blueskyRefreshJwt,
          did: authPreferences.blueskyDid,
          handle: authPreferences.blueskyHandle,
        ),
        service: service,
      );

      // Verify session is still valid
      try {
        await client.actor.getProfile(actor: authPreferences.blueskyHandle);
        return client;
      } catch (e) {
        // Try to refresh the session first
        try {
          return await _refreshSession(
            service: service,
            refreshJwt: authPreferences.blueskyRefreshJwt,
          );
        } catch (refreshError) {
          // If refresh fails, create new session
          return await _createAuthenticatedClient(
            service: service,
            identifier: authPreferences.blueskyHandle,
            password: authPreferences.blueskyAppPassword,
          );
        }
      }
    } catch (e) {
      throw Exception('Failed to restore session: $e');
    }
  }

  Future<Bluesky> _refreshSession({
    required String service,
    required String refreshJwt,
  }) async {
    try {
      final session = await refreshSession(
        service: service,
        refreshJwt: refreshJwt,
      );

      // Store new session data
      await ref.read(authPreferencesProvider.notifier).setBlueskySession(
            accessJwt: session.data.accessJwt,
            refreshJwt: session.data.refreshJwt,
            did: session.data.did,
          );

      _scheduleTokenRefresh();

      return Bluesky.fromSession(
        session.data,
        service: service,
      );
    } catch (e) {
      throw Exception('Failed to refresh session: $e');
    }
  }

  void _scheduleTokenRefresh() {
    _refreshTimer?.cancel();

    // Schedule refresh 5 minutes before token expiration (tokens typically last 2 hours)
    _refreshTimer = Timer(const Duration(hours: 1, minutes: 55), () async {
      try {
        final authPreferences = ref.read(authPreferencesProvider);
        final service = ref.read(blueskyServiceProvider);

        if (authPreferences.hasBlueskySession) {
          state = await _refreshSession(
            service: service,
            refreshJwt: authPreferences.blueskyRefreshJwt,
          );
        }
      } catch (e) {
        // If refresh fails, force reinitialization
        await reinitialize();
      }
    });
  }

  Future<Bluesky> _createAuthenticatedClient({
    required String service,
    required String identifier,
    required String password,
  }) async {
    try {
      final session = await _createSessionWithRetry(
        service: service,
        identifier: identifier,
        password: password,
      );

      // Store session data
      await ref.read(authPreferencesProvider.notifier).setBlueskySession(
            accessJwt: session.data.accessJwt,
            refreshJwt: session.data.refreshJwt,
            did: session.data.did,
          );

      _scheduleTokenRefresh();

      return Bluesky.fromSession(
        session.data,
        service: service,
      );
    } catch (e) {
      throw Exception('Failed to create Bluesky session: $e');
    }
  }

  /// Reinitializes the Bluesky client.
  Future<void> reinitialize() async {
    _refreshTimer?.cancel();
    _status = BlueskyStatus.initial;
    await _initialize();
  }

  /// Returns the current initialization status
  BlueskyStatus get status => _status;

  /// Returns true if the client is currently loading
  bool get isLoading => _status == BlueskyStatus.loading;

  /// Returns true if the client is ready for use
  bool get isReady => _status == BlueskyStatus.ready;

  /// Returns the current error if any
  Object? get error => _error;
}

/// Provider for the Bluesky service URL.
/// Returns the custom service URL if configured, otherwise returns the default.
final blueskyServiceProvider = Provider<String>(
  name: 'blueskyServiceProvider',
  (ref) {
    final customApiPreferences = ref.watch(customApiPreferencesProvider);
    return customApiPreferences.customBlueskyService;
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
