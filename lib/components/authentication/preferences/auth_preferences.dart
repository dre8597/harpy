import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/core/core.dart';
import 'package:harpy/core/preferences/preferences.dart';
import 'package:rby/rby.dart' hide Preferences;

part 'auth_preferences.freezed.dart';

/// Handles storing and updating the authentication data for sessions.
final authPreferencesProvider = StateNotifierProvider<AuthPreferencesNotifier, AuthPreferences>(
  (ref) => AuthPreferencesNotifier(
    preferences: ref.watch(encryptedPreferencesProvider(null)),
  ),
  name: 'AuthPreferencesProvider',
);

class AuthPreferencesNotifier extends StateNotifier<AuthPreferences> with LoggerMixin {
  AuthPreferencesNotifier({
    required Preferences preferences,
  })  : _preferences = preferences,
        super(
          AuthPreferences(
            userToken: preferences.getString('userToken'),
            userSecret: preferences.getString('userSecret'),
            userId: preferences.getString('userId'),
            blueskyHandle: preferences.getString('blueskyHandle'),
            blueskyAppPassword: preferences.getString('blueskyAppPassword'),
            blueskyAccessJwt: preferences.getString('blueskyAccessJwt'),
            blueskyRefreshJwt: preferences.getString('blueskyRefreshJwt'),
            blueskyDid: preferences.getString('blueskyDid'),
          ),
        ) {
    log.fine('Initialized AuthPreferences with handle: ${state.blueskyHandle}');
    log.fine('Has Bluesky credentials: ${state.hasBlueskyCredentials}');
    log.fine('Has Bluesky session: ${state.hasBlueskySession}');
  }

  final Preferences _preferences;

  void setAuth({
    required String token,
    required String secret,
    required String userId,
  }) {
    state = state.copyWith(
      userToken: token,
      userSecret: secret,
      userId: userId,
    );

    _preferences
      ..setString('userToken', token)
      ..setString('userSecret', secret)
      ..setString('userId', userId);
  }

  Future<void> setBlueskyAuth({
    required String handle,
    required String password,
  }) async {
    log.fine('Setting Bluesky auth for handle: $handle');
    state = state.copyWith(
      blueskyHandle: handle,
      blueskyAppPassword: password,
    );

    await _preferences.setString('blueskyHandle', handle);
    await _preferences.setString('blueskyAppPassword', password);

    log.fine('Stored Bluesky auth preferences');
  }

  Future<void> setBlueskySession({
    required String accessJwt,
    required String refreshJwt,
    required String did,
  }) async {
    log.fine('Setting Bluesky session for did: $did');
    state = state.copyWith(
      blueskyAccessJwt: accessJwt,
      blueskyRefreshJwt: refreshJwt,
      blueskyDid: did,
    );

    await _preferences.setString('blueskyAccessJwt', accessJwt);
    await _preferences.setString('blueskyRefreshJwt', refreshJwt);
    await _preferences.setString('blueskyDid', did);

    log.fine('Stored Bluesky session preferences');
  }

  Future<void> clearAuth() async {
    log.fine('Clearing all auth preferences');
    state = AuthPreferences.empty();

    await Future.wait([
      _preferences.remove('userToken'),
      _preferences.remove('userSecret'),
      _preferences.remove('userId'),
      _preferences.remove('blueskyHandle'),
      _preferences.remove('blueskyAppPassword'),
      _preferences.remove('blueskyAccessJwt'),
      _preferences.remove('blueskyRefreshJwt'),
      _preferences.remove('blueskyDid'),
    ]);
    log.fine('Cleared all auth preferences');
  }

  Future<void> clearBlueskySession() async {
    log.fine('Clearing Bluesky session only');
    state = state.copyWith(
      blueskyAccessJwt: '',
      blueskyRefreshJwt: '',
      blueskyDid: '',
    );

    await Future.wait([
      _preferences.remove('blueskyAccessJwt'),
      _preferences.remove('blueskyRefreshJwt'),
      _preferences.remove('blueskyDid'),
    ]);
    log.fine('Cleared Bluesky session preferences');
  }
}

@freezed
class AuthPreferences with _$AuthPreferences {
  factory AuthPreferences({
    required String userToken,
    required String userSecret,
    required String userId,
    required String blueskyHandle,
    required String blueskyAppPassword,
    required String blueskyAccessJwt,
    required String blueskyRefreshJwt,
    required String blueskyDid,
  }) = _AuthPreferences;

  factory AuthPreferences.empty() => AuthPreferences(
        userToken: '',
        userSecret: '',
        userId: '',
        blueskyHandle: '',
        blueskyAppPassword: '',
        blueskyAccessJwt: '',
        blueskyRefreshJwt: '',
        blueskyDid: '',
      );

  AuthPreferences._();

  late final bool isValid = userToken.isNotEmpty && userSecret.isNotEmpty && userId.isNotEmpty;

  late final bool hasBlueskyCredentials = blueskyHandle.isNotEmpty && blueskyAppPassword.isNotEmpty;

  late final bool hasBlueskySession =
      blueskyAccessJwt.isNotEmpty && blueskyRefreshJwt.isNotEmpty && blueskyDid.isNotEmpty;
}
