import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/core/core.dart';
import 'package:harpy/core/preferences/preferences.dart';

part 'media_preferences.freezed.dart';
part 'media_preferences.g.dart';

final mediaPreferencesProvider = StateNotifierProvider<MediaPreferencesNotifier, MediaPreferences>(
  (ref) => MediaPreferencesNotifier(
    preferences: ref.watch(preferencesProvider(null)),
  ),
  name: 'MediaPreferencesProvider',
);

class MediaPreferencesNotifier extends StateNotifier<MediaPreferences> {
  MediaPreferencesNotifier({
    required Preferences preferences,
  })  : _preferences = preferences,
        super(
          MediaPreferences(
            bestMediaQuality: preferences.getInt('bestMediaQuality', 2),
            cropImage: preferences.getBool('cropImage'),
            autoplayGifs: preferences.getInt('autoplayMedia', 1),
            autoplayVideos: preferences.getInt('autoplayVideos', 2),
            startVideoPlaybackMuted: preferences.getBool(
              'startVideoPlaybackMuted',
            ),
            useReelsVideoMode: preferences.getBool(
              'useReelsVideoMode',
            ),
            preloadVideos: preferences.getInt('preloadVideos', 1),
            hidePossiblySensitive: preferences.getBool(
              'hidePossiblySensitive',
            ),
            openLinksExternally: preferences.getBool(
              'openLinksExternally',
            ),
            showDownloadDialog: preferences.getBool('showDownloadDialog', true),
            downloadPathData: preferences.getString('downloadPathData'),
          ),
        );

  final Preferences _preferences;

  void defaultSettings() {
    setBestMediaQuality(2);
    setCropImage(false);
    setAutoplayGifs(1);
    setAutoplayVideos(2);
    setStartVideoPlaybackMuted(false);
    setUseReelsVideoMode(false);
    setPreloadVideos(1);
    setHidePossiblySensitive(false);
    setOpenLinksExternally(false);
    setShowDownloadDialog(true);
    setDownloadPathData('');
  }

  void setBestMediaQuality(int value) {
    state = state.copyWith(bestMediaQuality: value);
    _preferences.setInt('bestMediaQuality', value);
  }

  void setCropImage(bool value) {
    state = state.copyWith(cropImage: value);
    _preferences.setBool('cropImage', value);
  }

  void setAutoplayGifs(int value) {
    state = state.copyWith(autoplayGifs: value);
    // NOTE: `autoplayMedia` is used for gifs
    _preferences.setInt('autoplayMedia', value);
  }

  void setAutoplayVideos(int value) {
    state = state.copyWith(autoplayVideos: value);
    _preferences.setInt('autoplayVideos', value);
  }

  void setStartVideoPlaybackMuted(bool value) {
    state = state.copyWith(startVideoPlaybackMuted: value);
    _preferences.setBool('startVideoPlaybackMuted', value);
  }

  void setUseReelsVideoMode(bool value) {
    state = state.copyWith(useReelsVideoMode: value);
    _preferences.setBool('useReelsVideoMode', value);
  }

  void setPreloadVideos(int value) {
    state = state.copyWith(preloadVideos: value);
    _preferences.setInt('preloadVideos', value);
  }

  void setHidePossiblySensitive(bool value) {
    state = state.copyWith(hidePossiblySensitive: value);
    _preferences.setBool('hidePossiblySensitive', value);
  }

  void setOpenLinksExternally(bool value) {
    state = state.copyWith(openLinksExternally: value);
    _preferences.setBool('openLinksExternally', value);
  }

  void setShowDownloadDialog(bool value) {
    state = state.copyWith(showDownloadDialog: value);
    _preferences.setBool('showDownloadDialog', value);
  }

  void setDownloadPathData(String? value) {
    if(value == null) return;
    state = state.copyWith(downloadPathData: value);
    _preferences.setString('downloadPathData', value);
  }

  void updateFromStoredPreferences(MediaPreferences preferences) {
    state = preferences;

    // Update all individual preferences
    setBestMediaQuality(preferences.bestMediaQuality);
    setCropImage(preferences.cropImage);
    setAutoplayGifs(preferences.autoplayGifs);
    setAutoplayVideos(preferences.autoplayVideos);
    setStartVideoPlaybackMuted(preferences.startVideoPlaybackMuted);
    setUseReelsVideoMode(preferences.useReelsVideoMode);
    setPreloadVideos(preferences.preloadVideos);
    setHidePossiblySensitive(preferences.hidePossiblySensitive);
    setOpenLinksExternally(preferences.openLinksExternally);
    setShowDownloadDialog(preferences.showDownloadDialog);
    setDownloadPathData(preferences.downloadPathData);
  }
}

@freezed
class MediaPreferences with _$MediaPreferences {
  const factory MediaPreferences({
    @Default(2) int bestMediaQuality,
    @Default(false) bool cropImage,
    @Default(1) int autoplayGifs,
    @Default(2) int autoplayVideos,
    @Default(false) bool startVideoPlaybackMuted,
    @Default(false) bool useReelsVideoMode,
    @Default(1) int preloadVideos,
    @Default(false) bool hidePossiblySensitive,
    @Default(false) bool openLinksExternally,
    @Default(true) bool showDownloadDialog,
    String? downloadPathData,
  }) = _MediaPreferences;

  factory MediaPreferences.fromJson(Map<String, dynamic> json) => _$MediaPreferencesFromJson(json);

  const MediaPreferences._();

  /// Whether GIFs should play automatically, taking the connectivity into
  /// account.
  bool shouldAutoplayGifs(ConnectivityResult connectivity) =>
      autoplayGifs == 0 || autoplayGifs == 1 && connectivity == ConnectivityResult.wifi;

  /// Whether videos should play automatically, taking the connectivity into
  /// account.
  bool shouldAutoplayVideos(ConnectivityResult connectivity) =>
      autoplayVideos == 0 || autoplayVideos == 1 && connectivity == ConnectivityResult.wifi;

  /// Whether the best media quality should be used, taking the connectivity
  /// into account.
  bool shouldUseBestMediaQuality(ConnectivityResult connectivity) =>
      bestMediaQuality == 0 || bestMediaQuality == 1 && connectivity == ConnectivityResult.wifi;

  /// Whether videos should be preloaded, taking the connectivity into account.
  bool shouldPreloadVideos(ConnectivityResult connectivity) =>
      preloadVideos == 0 || preloadVideos == 1 && connectivity == ConnectivityResult.wifi;
}
