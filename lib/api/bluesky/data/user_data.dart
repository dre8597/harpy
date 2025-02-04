import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/data/models.dart';

part 'user_data.freezed.dart';
part 'user_data.g.dart';

/// Data class representing a Bluesky user with all its associated data.
@freezed
class BlueskyUserData with _$BlueskyUserData {
  const factory BlueskyUserData({
    required String did,
    required String handle,
    required String displayName,
    String? description,
    String? avatar,
    String? banner,
    int? followersCount,
    int? followsCount,
    int? postsCount,
    bool? isFollowing,
    bool? isFollowed,
    bool? isBlocked,
    bool? isMuted,
    List<String>? labels,
  }) = _BlueskyUserData;

  factory BlueskyUserData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyUserDataFromJson(json);

  /// Creates a [BlueskyUserData] from a Bluesky profile.
  factory BlueskyUserData.fromProfile(Profile profile) {
    return BlueskyUserData(
      did: profile.did,
      handle: profile.handle,
      displayName: profile.displayName ?? profile.handle,
      description: profile.description,
      avatar: profile.avatar,
      banner: profile.banner,
      followersCount: profile.followersCount,
      followsCount: profile.followsCount,
      postsCount: profile.postsCount,
      isFollowing: profile.viewer?.following != null,
      isFollowed: profile.viewer?.followedBy != null,
      isBlocked: profile.viewer?.blocking != null,
      isMuted: profile.viewer?.muted ?? false,
      labels: profile.labels?.map((label) => label.val).toList(),
    );
  }
}

/// Extension methods for [BlueskyUserData].
extension BlueskyUserDataExtension on BlueskyUserData {
  /// Returns the display name if available, otherwise returns the handle.
  String get effectiveDisplayName =>
      displayName.isNotEmpty ? displayName : handle;

  /// Returns true if the user has a custom avatar.
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;

  /// Returns true if the user has a custom banner.
  bool get hasBanner => banner != null && banner!.isNotEmpty;

  /// Returns true if the user has any labels.
  bool get hasLabels => labels != null && labels!.isNotEmpty;

  /// Returns true if the user has a description.
  bool get hasDescription => description != null && description!.isNotEmpty;
}
