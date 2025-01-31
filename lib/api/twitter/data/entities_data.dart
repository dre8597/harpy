// import 'package:freezed_annotation/freezed_annotation.dart';
//
// part 'entities_data.freezed.dart';
//
//
// @freezed
// class EntitiesMediaData with _$EntitiesMediaData {
//   const factory EntitiesMediaData({
//     /// Wrapped Url for the media link, corresponding to the value embedded
//     /// directly into the raw tweet text.
//     required String url,
//   }) = _EntitiesMediaData;
//
//   factory EntitiesMediaData.fromV1(v1.Media media) {
//     return EntitiesMediaData(
//       url: media.url ?? '',
//     );
//   }
// }
//
// @freezed
// class UrlData with _$UrlData {
//   const factory UrlData({
//     /// Url pasted/typed into the tweet.
//     ///
//     /// Example: 'bit.ly/2so49n2'
//     required String displayUrl,
//
//     /// Expanded version of [displayUrl].
//     ///
//     /// Example: 'http://bit.ly/2so49n2'
//     required String expandedUrl,
//
//     /// Wrapped Url, corresponding to the value embedded directly into the raw
//     /// tweet text.
//     required String url,
//   }) = _UrlData;
//
//   factory UrlData.fromV1(v1.Url url) {
//     return UrlData(
//       displayUrl: url.displayUrl ?? '',
//       expandedUrl: url.expandedUrl ?? '',
//       url: url.url ?? '',
//     );
//   }
//
//   factory UrlData.fromV2(v2.Url url) {
//     return UrlData(
//       displayUrl: url.displayUrl,
//       expandedUrl: url.expandedUrl,
//       url: url.url,
//     );
//   }
// }
//
// @freezed
// class UserMentionData with _$UserMentionData {
//   const factory UserMentionData({
//     /// The handle of the user, minus the leading `@` character.
//     required String handle,
//   }) = _UserMentionData;
//
//   factory UserMentionData.fromV2(v2.Mention mention) {
//     return UserMentionData(handle: mention.username);
//   }
//
//   factory UserMentionData.fromV1(v1.UserMention userMention) {
//     return UserMentionData(
//       handle: userMention.screenName ?? '',
//     );
//   }
// }
