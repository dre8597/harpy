import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/data/user_data.dart';

part 'list_data.freezed.dart';
part 'list_data.g.dart';

/// Data class representing a Bluesky list.
/// NOTE: This is a placeholder implementation. List functionality for Bluesky
/// is not yet available. This class will be updated once the API supports lists.
@freezed
class BlueskyListData with _$BlueskyListData {
  const factory BlueskyListData({
    required String uri,
    required String cid,
    required String name,
    required String purpose,
    required String creatorDid,
    String? description,
    String? avatar,
    List<BlueskyUserData>? members,
    int? membersCount,
    bool? isPrivate,
    bool? isMember,
    bool? isOwner,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BlueskyListData;

  factory BlueskyListData.fromJson(Map<String, dynamic> json) => _$BlueskyListDataFromJson(json);

  /// Creates a [BlueskyListData] from a Bluesky list.
  /// NOTE: This is a placeholder implementation. List functionality for Bluesky
  /// is not yet available. This factory will be updated once the API supports lists.
  factory BlueskyListData.fromList(list) {
    throw UnimplementedError(
      'List functionality for Bluesky is not yet available. '
      'This feature will be implemented once the API supports lists.',
    );
  }
}

/// Extension methods for [BlueskyListData].
extension BlueskyListDataExtension on BlueskyListData {
  /// Returns true if the list has a description.
  bool get hasDescription => description != null && description!.isNotEmpty;

  /// Returns true if the list has an avatar.
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;

  /// Returns true if the list has members.
  bool get hasMembers => members != null && members!.isNotEmpty;

  /// Returns true if the list has been updated since creation.
  bool get hasBeenUpdated => updatedAt != null && createdAt != null && updatedAt != createdAt;
}
