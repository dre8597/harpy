import 'package:bluesky/bluesky.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

part 'auth_preferences.freezed.dart';

/// Handles storing and updating the authentication data for sessions.
final authPreferencesProvider = StateNotifierProvider<AuthPreferencesNotifier, AuthPreferences>(
  (ref) => AuthPreferencesNotifier(
    preferences: ref.watch(encryptedPreferencesProvider(null)),
  ),
  name: 'AuthPreferencesProvider',
);

class AuthPreferencesNotifier extends StateNotifier<AuthPreferences> {
  AuthPreferencesNotifier({
    required Preferences preferences,
  })  : _preferences = preferences,
        super(
          AuthPreferences(
            userToken: preferences.getString('userToken', ''),
            userSecret: preferences.getString('userSecret', ''),
            userId: preferences.getString('userId', ''),
            blueskyHandle: preferences.getString('blueskyHandle', ''),
            blueskyAppPassword: preferences.getString('blueskyAppPassword', ''),
          ),
        );

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

  void setBlueskyAuth({
    required String handle,
    required String password,
  }) {
    state = state.copyWith(
      blueskyHandle: handle,
      blueskyAppPassword: password,
    );

    _preferences
      ..setString('blueskyHandle', handle)
      ..setString('blueskyAppPassword', password);
  }

  void clearAuth() {
    state = AuthPreferences.empty();

    _preferences
      ..remove('userToken')
      ..remove('userSecret')
      ..remove('userId')
      ..remove('blueskyHandle')
      ..remove('blueskyAppPassword');
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
  }) = _AuthPreferences;

  factory AuthPreferences.empty() => AuthPreferences(
        userToken: '',
        userSecret: '',
        userId: '',
        blueskyHandle: '',
        blueskyAppPassword: '',
      );

  AuthPreferences._();

  late final bool isValid = userToken.isNotEmpty && userSecret.isNotEmpty && userId.isNotEmpty;

  late final bool hasBlueskyCredentials = blueskyHandle.isNotEmpty && blueskyAppPassword.isNotEmpty;
}
