// import 'package:bluesky/bluesky.dart';
// import 'package:freezed_annotation/freezed_annotation.dart';
//
// part 'relationship_data.freezed.dart';
//
// @freezed
// class RelationshipData with _$RelationshipData {
//   const factory RelationshipData({
//     @Default(false) bool blockedBy,
//     @Default(false) bool blocking,
//     @Default(false) bool canDm,
//     @Default(false) bool followedBy,
//     @Default(false) bool following,
//     @Default(false) bool followingReceived,
//     @Default(false) bool followingRequested,
//     @Default(false) bool markedSpam,
//     @Default(false) bool muting,
//     @Default(false) bool wantRetweets,
//   }) = _RelationshipData;
//
//   factory RelationshipData.fromV1(Relationship relationship) {
//     return RelationshipData(
//       blockedBy: relationship.blockedBy ?? false,
//       blocking: relationship.source?.blocking ?? false,
//       canDm: relationship.source?.canDm ?? false,
//       followedBy: relationship.source?.followedBy ?? false,
//       following: relationship.source?.following ?? false,
//       followingReceived: relationship.source?.followingReceived ?? false,
//       followingRequested: relationship.source?.followingRequested ?? false,
//       markedSpam: relationship.source?.markedSpam ?? false,
//       muting: relationship.source?.muting ?? false,
//       wantRetweets: relationship.source.wantRetweets ?? false,
//     );
//   }
// }
