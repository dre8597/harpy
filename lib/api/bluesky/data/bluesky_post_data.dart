import 'package:bluesky/bluesky.dart' as bsky;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bluesky_post_data.freezed.dart';
part 'bluesky_post_data.g.dart';

/// Data class representing a Bluesky post with all its associated data.
@freezed
class BlueskyPostData with _$BlueskyPostData {
  const factory BlueskyPostData({
    required String id,
    required String uri,
    required String cid,
    required String text,
    required String author,
    required String handle,
    required DateTime createdAt,
    String? parentPostId,
    String? rootPostId,
    List<String>? tags,
    List<String>? mentions,
    List<BlueskyMediaData>? media,
    List<BlueskyPostData>? replies,
    BlueskyPostData? repostOf,
    int? replyCount,
    int? repostCount,
    int? likeCount,
    bool? isReposted,
    bool? isLiked,
  }) = _BlueskyPostData;

  factory BlueskyPostData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyPostDataFromJson(json);

  /// Creates a [BlueskyPostData] from a Bluesky FeedView.
  factory BlueskyPostData.fromFeedView(bsky.FeedView feedView) {
    final post = feedView.post;
    final embed = post.embed;
    List<BlueskyMediaData>? media;

    if (embed != null) {
      embed.map(
        images: (images) {
          media = images.data.images
              .map(
                (img) => BlueskyMediaData(
                  type: 'image',
                  url: img.fullsize,
                  alt: img.alt,
                ),
              )
              .toList();
        },
        external: (external) {
          media = [
            BlueskyMediaData(
              type: 'external',
              url: external.data.external.uri,
              alt: external.data.external.title,
            ),
          ];
        },
        video: (video) {
          // Skip video handling for now as the video structure is unclear
          // TODO: Implement video handling once the structure is clear
        },
        record: (_) {},
        recordWithMedia: (_) {},
        unknown: (_) {},
      );
    }

    final uriParts = post.uri.toString().split('/');
    final id = uriParts.isNotEmpty ? uriParts.last : post.uri.toString();

    return BlueskyPostData(
      id: id,
      uri: post.uri.toString(),
      cid: post.cid,
      text: post.record.text,
      author: post.author.did,
      handle: post.author.handle,
      createdAt: post.indexedAt,
      parentPostId: post.record.reply?.parent.uri.toString(),
      rootPostId: post.record.reply?.root.uri.toString(),
      tags: post.record.facets
          ?.where((f) => f.features.any((feat) => feat is bsky.FacetTag))
          .map((f) => (f.features.firstWhere((feat) => feat is bsky.FacetTag)
                  as bsky.FacetTag)
              .tag)
          .toList(),
      mentions: post.record.facets
          ?.where((f) => f.features.any((feat) => feat is bsky.FacetMention))
          .map(
            (f) => (f.features.firstWhere((feat) => feat is bsky.FacetMention)
                    as bsky.FacetMention)
                .did,
          )
          .toList(),
      media: media,
      replyCount: post.replyCount,
      repostCount: post.repostCount,
      likeCount: post.likeCount,
      isReposted: post.isReposted,
      isLiked: post.isLiked,
    );
  }
}

/// Data class representing media in a Bluesky post.
@freezed
class BlueskyMediaData with _$BlueskyMediaData {
  const factory BlueskyMediaData({
    required String type,
    required String url,
    String? alt,
  }) = _BlueskyMediaData;

  factory BlueskyMediaData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyMediaDataFromJson(json);
}
