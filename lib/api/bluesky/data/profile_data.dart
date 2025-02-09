import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/data/models.dart';
import 'package:harpy/components/components.dart';

part 'profile_data.freezed.dart';
part 'profile_data.g.dart';

/// Data class representing a stored Bluesky profile with its preferences.
@freezed
class StoredProfileData with _$StoredProfileData {
  const factory StoredProfileData({
    required String did,
    required String handle,
    required String displayName,
    required String appPassword,
    required String accessJwt,
    required String refreshJwt,
    String? avatar,
    @Default(false) bool isActive,
    MediaPreferences? mediaPreferences,
    FeedPreferences? feedPreferences,
    String? themeMode,
    Map<String, dynamic>? additionalPreferences,
  }) = _StoredProfileData;

  factory StoredProfileData.fromJson(Map<String, dynamic> json) =>
      _$StoredProfileDataFromJson(json);

  /// Creates a [StoredProfileData] from a Bluesky profile and authentication data.
  factory StoredProfileData.fromProfile({
    required Profile profile,
    required String appPassword,
    required String accessJwt,
    required String refreshJwt,
    required bool isActive,
    MediaPreferences? mediaPreferences,
    FeedPreferences? feedPreferences,
    String? themeMode,
    Map<String, dynamic>? additionalPreferences,
  }) {
    return StoredProfileData(
      did: profile.did,
      handle: profile.handle,
      displayName: profile.displayName ?? profile.handle,
      appPassword: appPassword,
      accessJwt: accessJwt,
      refreshJwt: refreshJwt,
      avatar: profile.avatar,
      isActive: isActive,
      mediaPreferences: mediaPreferences,
      feedPreferences: feedPreferences,
      themeMode: themeMode,
      additionalPreferences: additionalPreferences,
    );
  }
}

/// Data class representing all stored profiles.
@freezed
class StoredProfiles with _$StoredProfiles {
  const factory StoredProfiles({
    @Default([]) List<StoredProfileData> profiles,
    @Default(false) bool isProfileSwitching,
  }) = _StoredProfiles;

  factory StoredProfiles.fromJson(Map<String, dynamic> json) =>
      _$StoredProfilesFromJson(json);
}
