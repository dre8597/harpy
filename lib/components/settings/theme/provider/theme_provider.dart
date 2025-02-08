import 'dart:convert';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';
import 'package:harpy/components/settings/theme/preferences/theme_preferences.dart';
import 'package:harpy/core/preferences/preferences.dart';

final harpyThemeProvider = StateProvider(
  (ref) {
    final lightTheme = ref.watch(lightThemeProvider);
    final darkTheme = ref.watch(darkThemeProvider);

    return ref.watch(platformBrightnessProvider) == Brightness.light ? lightTheme : darkTheme;
  },
  name: 'HarpyThemeProvider',
);

final lightThemeProvider = StateProvider(
  (ref) {
    final lightThemeId = ref.watch(themePreferencesProvider).lightThemeId;
    final customThemes = ref.watch(customHarpyThemesProvider);
    final display = ref.watch(displayPreferencesProvider);

    final materialYouLight = ref.watch(materialYouLightProvider);
    final materialYouDark = ref.watch(materialYouDarkProvider);

    return HarpyTheme(
      data: _themeDataFromId(
            lightThemeId,
            customThemes: customThemes,
            materialYouLight: materialYouLight.asData?.value,
            materialYouDark: materialYouDark.asData?.value,
          ) ??
          predefinedThemes[1],
      fontSizeDelta: display.fontSizeDelta,
      displayFont: display.displayFont,
      bodyFont: display.bodyFont,
      compact: display.compactMode,
    );
  },
  name: 'LightThemeProvider',
);

final darkThemeProvider = StateProvider(
  (ref) {
    final darkThemeId = ref.watch(themePreferencesProvider).darkThemeId;
    final customThemes = ref.watch(customHarpyThemesProvider);
    final display = ref.watch(displayPreferencesProvider);

    final materialYouLight = ref.watch(materialYouLightProvider);
    final materialYouDark = ref.watch(materialYouDarkProvider);

    return HarpyTheme(
      data: _themeDataFromId(
            darkThemeId,
            customThemes: customThemes,
            materialYouLight: materialYouLight.asData?.value,
            materialYouDark: materialYouDark.asData?.value,
          ) ??
          predefinedThemes[0],
      fontSizeDelta: display.fontSizeDelta,
      displayFont: display.displayFont,
      bodyFont: display.bodyFont,
      compact: display.compactMode,
    );
  },
  name: 'DarkThemeProvider',
);

final customHarpyThemesProvider = StateProvider(
  (ref) => ref
      .watch(themePreferencesProvider.select((value) => value.customThemes))
      .map(_decodeThemeData)
      .whereType<HarpyThemeData>()
      .toBuiltList(),
  name: 'CustomThemesProvider',
);

/// Returns the appropriate theme data based on the id.
///
/// -2: material you light
/// -1: material you dark
/// 0..10: predefined theme (+ reserved)
/// 11+: custom theme
HarpyThemeData? _themeDataFromId(
  int id, {
  required BuiltList<HarpyThemeData> customThemes,
  required HarpyThemeData? materialYouLight,
  required HarpyThemeData? materialYouDark,
}) {
  if (id == -2) {
    return materialYouLight;
  } else if (id == -1) {
    return materialYouDark;
  } else if (id >= 0 && id < predefinedThemes.length) {
    return predefinedThemes[id];
  } else if (id >= 10) {
    if (id - 10 < customThemes.length) {
      return customThemes[id - 10];
    }
  }

  return null;
}

HarpyThemeData? _decodeThemeData(String themeDataJson) {
  try {
    return HarpyThemeData.fromJson(
      jsonDecode(themeDataJson) as Map<String, dynamic>,
    );
  } catch (e, st) {
    Logger.detached('_decodeThemeData').warning('unable to decode custom theme data', e, st);
    return null;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier(
    preferences: ref.watch(preferencesProvider(null)),
  );
});

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier({
    required Preferences preferences,
  })  : _preferences = preferences,
        super(ThemeState(
          themeMode: ThemeMode.values.byName(
            preferences.getString('themeMode', 'system'),
          ),
        ));

  final Preferences _preferences;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _preferences.setString('themeMode', mode.name);
  }
}

class ThemeState {
  const ThemeState({
    required this.themeMode,
  });

  final ThemeMode themeMode;

  ThemeState copyWith({
    ThemeMode? themeMode,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
