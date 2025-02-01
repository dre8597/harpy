import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A wrapper around [SharedPreferences] that provides a type-safe way to store
/// and retrieve preferences.
class Preferences {
  const Preferences._({
    required this.sharedPreferences,
    required this.prefix,
    this.encrypter,
  });

  /// Creates a basic preferences instance without encryption.
  factory Preferences.basic({
    required SharedPreferences sharedPreferences,
    String? prefix,
  }) =>
      Preferences._(
        sharedPreferences: sharedPreferences,
        prefix: prefix ?? '',
      );

  /// Creates an encrypted preferences instance.
  factory Preferences.encrypted({
    required SharedPreferences sharedPreferences,
    required String aesKey,
    String? prefix,
  }) {
    final encrypter = Encrypter(
      AES(Key.fromBase64(aesKey), mode: AESMode.cbc),
    );

    return Preferences._(
      sharedPreferences: sharedPreferences,
      prefix: prefix ?? '',
      encrypter: encrypter,
    );
  }

  final SharedPreferences sharedPreferences;
  final String prefix;
  final Encrypter? encrypter;

  String _buildKey(String key) => prefix.isEmpty ? key : '$prefix.$key';

  String? _encrypt(String value) {
    if (encrypter == null) return value;
    final iv = IV.fromSecureRandom(16);
    final encrypted = encrypter!.encrypt(value, iv: iv);
    // Store both IV and encrypted data in format: <iv>:<encrypted>
    return '${iv.base64}:${encrypted.base64}';
  }

  String? _decrypt(String? value) {
    if (value == null || encrypter == null) return value;
    try {
      final parts = value.split(':');
      if (parts.length != 2) return value;
      final iv = IV.fromBase64(parts[0]);
      return encrypter!.decrypt64(parts[1], iv: iv);
    } catch (_) {
      return value;
    }
  }

  /// Gets a value from preferences.
  T? get<T>(String key) {
    final fullKey = _buildKey(key);
    final value = sharedPreferences.get(fullKey);

    if (value == null) return null;

    if (encrypter != null && value is String) {
      final decrypted = _decrypt(value);
      if (decrypted == null) return null;

      try {
        return json.decode(decrypted) as T;
      } catch (_) {
        return decrypted as T;
      }
    }

    return value as T;
  }

  /// Sets a value in preferences.
  Future<bool> set<T>(String key, T value) async {
    final fullKey = _buildKey(key);

    if (value == null) {
      return sharedPreferences.remove(fullKey);
    }

    if (encrypter != null) {
      final encrypted = _encrypt(
        value is String ? value : json.encode(value),
      );
      if (encrypted == null) return false;
      return sharedPreferences.setString(fullKey, encrypted);
    }

    switch (T) {
      case const (bool):
        return sharedPreferences.setBool(fullKey, value as bool);
      case const (int):
        return sharedPreferences.setInt(fullKey, value as int);
      case const (double):
        return sharedPreferences.setDouble(fullKey, value as double);
      case const (String):
        return sharedPreferences.setString(fullKey, value as String);
      case const (List<String>):
        return sharedPreferences.setStringList(
          fullKey,
          value as List<String>,
        );
      default:
        final jsonString = json.encode(value);
        return sharedPreferences.setString(fullKey, jsonString);
    }
  }

  /// Gets a boolean value from preferences.
  bool getBool(String key, [bool defaultValue = false]) => get<bool>(key) ?? defaultValue;

  /// Gets an integer value from preferences.
  int getInt(String key, [int defaultValue = 0]) => get<int>(key) ?? defaultValue;

  /// Gets a double value from preferences.
  double getDouble(String key, [double defaultValue = 0.0]) => get<double>(key) ?? defaultValue;

  /// Gets a string value from preferences.
  String getString(String key, [String defaultValue = '']) => get<String>(key) ?? defaultValue;

  /// Gets a list of strings from preferences.
  List<String> getStringList(
    String key, [
    List<String> defaultValue = const [],
  ]) =>
      get<List<String>>(key) ?? defaultValue;

  /// Sets a boolean value in preferences.
  Future<bool> setBool(String key, bool value) => set<bool>(key, value);

  /// Sets an integer value in preferences.
  Future<bool> setInt(String key, int value) => set<int>(key, value);

  /// Sets a double value in preferences.
  Future<bool> setDouble(String key, double value) => set<double>(key, value);

  /// Sets a string value in preferences.
  Future<bool> setString(String key, String value) => set<String>(key, value);

  /// Sets a list of strings in preferences.
  Future<bool> setStringList(String key, List<String> value) => set<List<String>>(key, value);

  /// Removes a value from preferences.
  Future<bool> remove(String key) => sharedPreferences.remove(_buildKey(key));

  /// Clears all preferences with the current prefix.
  Future<void> clear() async {
    final keys = sharedPreferences.getKeys();
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await sharedPreferences.remove(key);
      }
    }
  }
}
