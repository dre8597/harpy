import 'package:bluesky/atproto.dart';
import 'package:bluesky/bluesky.dart';
import 'package:bluesky/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';

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

  @override
  Bluesky build() {
    // Initialize with anonymous client
    final service = ref.read(blueskyServiceProvider);
    final client = Bluesky.anonymous(service: service);

    // Start initialization process
    _initialize();

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
        final client = await _createAuthenticatedClient(
          service: service,
          identifier: authPreferences.blueskyHandle,
          password: authPreferences.blueskyAppPassword,
        );
        state = client;
      }

      _status = BlueskyStatus.ready;
    } catch (e) {
      _error = e;
      _status = BlueskyStatus.error;
      // Keep the anonymous client in error state
      final service = ref.read(blueskyServiceProvider);
      state = Bluesky.anonymous(service: service);
    }
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
  }

  /// Reinitializes the Bluesky client.
  /// Useful for handling login/logout or when credentials change.
  Future<void> reinitialize() async {
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
