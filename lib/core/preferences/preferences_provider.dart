import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/core/core.dart';
import 'package:harpy/core/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides access to the [SharedPreferences] instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Initialize SharedPreferences in main.dart'),
  name: 'SharedPreferencesProvider',
);

/// Provides access to a basic [Preferences] instance.
/// The [prefix] parameter is used to namespace the preferences.
final preferencesProvider = Provider.family<Preferences, String?>(
  (ref, prefix) => Preferences.basic(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    prefix: prefix,
  ),
  name: 'PreferencesProvider',
);

/// Provides access to an encrypted [Preferences] instance.
/// The [prefix] parameter is used to namespace the preferences.
final encryptedPreferencesProvider = Provider.family<Preferences, String?>(
  (ref, prefix) => Preferences.encrypted(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    aesKey: ref.watch(environmentProvider).aesKey,
    prefix: prefix,
  ),
  name: 'EncryptedPreferencesProvider',
);
