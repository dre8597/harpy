import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/data/models.dart';

part 'relationship_data.freezed.dart';
part 'relationship_data.g.dart';

/// Data class representing the relationship between two Bluesky users.
@freezed
class BlueskyRelationshipData with _$BlueskyRelationshipData {
  const factory BlueskyRelationshipData({
    required String targetDid,
    required String targetHandle,
    required bool following,
    required bool followedBy,
    required bool blocking,
    required bool blockedBy,
    required bool muting,
    String? targetDisplayName,
  }) = _BlueskyRelationshipData;

  factory BlueskyRelationshipData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyRelationshipDataFromJson(json);

  /// Creates a [BlueskyRelationshipData] from a Bluesky profile.
  factory BlueskyRelationshipData.fromProfile(Profile profile) {
    final viewer = profile.viewer;

    return BlueskyRelationshipData(
      targetDid: profile.did,
      targetHandle: profile.handle,
      targetDisplayName: profile.displayName,
      following: viewer?.following != null,
      followedBy: viewer?.followedBy != null,
      blocking: viewer?.blocking != null,
      blockedBy: viewer?.blockedBy != null,
      muting: viewer?.muted ?? false,
    );
  }
}

/// Extension methods for [BlueskyRelationshipData].
extension BlueskyRelationshipDataExtension on BlueskyRelationshipData {
  /// Returns true if there is any relationship between the users.
  bool get hasRelationship => following || followedBy || blocking || blockedBy || muting;

  /// Returns true if there is a mutual follow relationship.
  bool get isMutualFollow => following && followedBy;

  /// Returns true if there is a mutual block relationship.
  bool get isMutualBlock => blocking && blockedBy;
}
