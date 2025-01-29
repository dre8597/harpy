import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

part 'custom_api_preferences.freezed.dart';

final customApiPreferencesProvider =
    StateNotifierProvider<CustomApiPreferencesNotifier, CustomApiPreferences>(
  (ref) => CustomApiPreferencesNotifier(
    preferences: ref.watch(encryptedPreferencesProvider(null)),
  ),
  name: 'CustomApiPreferencesProvider',
);

class CustomApiPreferencesNotifier extends StateNotifier<CustomApiPreferences> {
  CustomApiPreferencesNotifier({
    required Preferences preferences,
  })  : _preferences = preferences,
        super(
          CustomApiPreferences(
            customKey: preferences.getString('customKey', ''),
            customSecret: preferences.getString('customSecret', ''),
            customBlueskyService:
                preferences.getString('customBlueskyService', ''),
          ),
        );

  final Preferences _preferences;

  void setCustomCredentials({
    required String key,
    required String secret,
  }) {
    state = state.copyWith(
      customKey: key,
      customSecret: secret,
    );
    _preferences
      ..setString('customKey', key)
      ..setString('customSecret', secret);
  }

  void setCustomBlueskyService(String service) {
    state = state.copyWith(customBlueskyService: service);
    _preferences.setString('customBlueskyService', service);
  }
}

@freezed
class CustomApiPreferences with _$CustomApiPreferences {
  const factory CustomApiPreferences({
    required String customKey,
    required String customSecret,
    required String customBlueskyService,
  }) = _CustomApiPreferences;

  CustomApiPreferences._();

  late final bool hasCustomApiKeyAndSecret =
      customKey.isNotEmpty && customSecret.isNotEmpty;
}
