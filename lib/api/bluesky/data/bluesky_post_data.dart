import 'package:bluesky/atproto.dart' as at;
import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/core.dart';
import 'package:connectivity_plus_platform_interface/src/enums.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/data/models.dart';
import 'package:harpy/api/bluesky/data/translation_data.dart';
import 'package:harpy/api/twitter/data/media_data.dart';
import 'package:harpy/api/twitter/media_type.dart';
import 'package:harpy/components/settings/media/preferences/media_preferences.dart';

part 'bluesky_post_data.freezed.dart';
part 'bluesky_post_data.g.dart';

/// JSON converter for AtUri type
class AtUriConverter implements JsonConverter<AtUri, String> {
  const AtUriConverter();

  @override
  AtUri fromJson(String json) => AtUri.parse(json);

  @override
  String toJson(AtUri uri) => uri.toString();
}

/// Data class representing a Bluesky post with all its associated data.
@freezed
class BlueskyPostData with _$BlueskyPostData {
  const factory BlueskyPostData({
    required String id,
    required String text,
    @AtUriConverter() required AtUri uri,
    required String author,
    required String handle,
    required String authorDid,
    required String authorAvatar,
    required DateTime createdAt,
    String? parentPostId,
    String? rootPostId,
    BlueskyPostData? repostOf,
    BlueskyPostData? quoteOf,
    List<BlueskyMediaData>? media,
    List<String>? tags,
    List<String>? mentions,
    List<BlueskyPostData>? replies,
    @Default(0) int replyCount,
    @Default(0) int repostCount,
    @Default(0) int likeCount,
    @Default(false) bool isReposted,
    @Default(false) bool isLiked,
    List<Label>? labels,
    TranslationData? translation,
    @Default(false) bool isTranslating,
    EmbedRecord? embed,
    List<String>? externalUrls,
  }) = _BlueskyPostData;

  const BlueskyPostData._();

  factory BlueskyPostData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyPostDataFromJson(json);

  /// Creates a [BlueskyPostData] from a Bluesky FeedView.
  factory BlueskyPostData.fromFeedView(bsky.FeedView post) {
    final embed = post.post.embed;
    final postRecord = post.post.record;
    final author = post.post.author;
    final viewer = post.post.viewer;
    final labels = post.post.labels
            ?.map(
              (l) => Label(
                val: l.value,
                src: l.src,
                uri: l.uri,
                cts: l.createdAt,
                neg: l.isNegate,
              ),
            )
            .toList() ??
        <Label>[];

    // Extract external URLs from record facets
    final externalUrls = postRecord.facets
        ?.where((f) => f.features.any((feat) => feat is bsky.FacetLink))
        .map(
          (f) => (f.features.firstWhere((feat) => feat is bsky.FacetLink)
                  as bsky.FacetLink)
              .uri,
        )
        .toList();

    // Handle reply references
    final reply = post.reply;
    String? parentId;
    String? rootId;
    if (reply != null) {
      if (reply.parent is at.StrongRef) {
        parentId = (reply.parent as at.StrongRef).cid;
      }
      if (reply.root is at.StrongRef) {
        rootId = (reply.root as at.StrongRef).cid;
      }
    }

    // Handle repost
    BlueskyPostData? repostData;
    if (post.reason is bsky.ReasonRepost) {
      final repost = post.reason as bsky.ReasonRepost;
      if (repost.by is bsky.FeedView) {
        repostData = BlueskyPostData.fromFeedView(repost.by as bsky.FeedView);
      }
    }

    // Handle quote post
    BlueskyPostData? quoteData;
    if (embed is bsky.EmbedView) {
      final embedView = embed;
      embedView.maybeWhen(
        record: (data) {
          if (data.record is bsky.FeedView) {
            quoteData =
                BlueskyPostData.fromFeedView(data.record as bsky.FeedView);
          }
        },
        orElse: () {},
      );
    }

    // Handle media
    List<BlueskyMediaData>? mediaData;
    if (embed is bsky.EmbedImages) {
      final images = (embed as bsky.EmbedImages).images;
      mediaData = images.map(BlueskyMediaData.fromImage).toList();
    }

    return BlueskyPostData(
      id: post.post.cid,
      text: postRecord.text,
      uri: post.post.uri,
      author: author.displayName ?? author.handle,
      handle: author.handle,
      authorDid: author.did,
      authorAvatar: author.avatar ?? '',
      createdAt: post.post.indexedAt,
      parentPostId: parentId,
      rootPostId: rootId,
      repostOf: repostData,
      quoteOf: quoteData,
      media: mediaData,
      tags: postRecord.facets
          ?.where((f) => f.features.any((feat) => feat is bsky.FacetTag))
          .map(
            (f) => (f.features.firstWhere((feat) => feat is bsky.FacetTag)
                    as bsky.FacetTag)
                .tag,
          )
          .toList(),
      mentions: postRecord.facets
          ?.where((f) => f.features.any((feat) => feat is bsky.FacetMention))
          .map(
            (f) => (f.features.firstWhere((feat) => feat is bsky.FacetMention)
                    as bsky.FacetMention)
                .did,
          )
          .toList(),
      replyCount: post.post.replyCount,
      repostCount: post.post.repostCount,
      likeCount: post.post.likeCount,
      isReposted: viewer.repost != null,
      isLiked: viewer.like != null,
      labels: labels,
      externalUrls: externalUrls,
    );
  }
}

/// Data class representing media in a Bluesky post.
@freezed
class BlueskyMediaData with _$BlueskyMediaData implements MediaData {
  const factory BlueskyMediaData({
    required String alt,
    required String url,
    String? thumb,
    @Default(MediaType.image) MediaType type,
    double? aspectRatio,
  }) = _BlueskyMediaData;

  const BlueskyMediaData._();

  factory BlueskyMediaData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyMediaDataFromJson(json);

  factory BlueskyMediaData.fromImage(bsky.Image image) {
    final imageRef = image.image.ref.toString();
    final ratio = image.aspectRatio;
    double? aspectRatioValue;
    if (ratio != null) {
      aspectRatioValue = ratio.width / ratio.height;
    }
    return BlueskyMediaData(
      alt: image.alt,
      url: imageRef,
      thumb:
          imageRef, // Use same URL for thumb since Bluesky doesn't provide thumbnails yet
      aspectRatio: aspectRatioValue,
    );
  }

  @override
  String appropriateUrl(
    MediaPreferences mediaPreferences,
    ConnectivityResult connectivity,
  ) {
    return bestUrl;
  }

  @override
  double get aspectRatioDouble => aspectRatio ?? 1.0;

  @override
  String get bestUrl => url;

  @override
  MediaType get type => MediaType.image;
}

/// Represents an embedded record in a post
@freezed
class EmbedRecord with _$EmbedRecord {
  const factory EmbedRecord({
    required String cid,
    @AtUriConverter() required AtUri uri,
    String? author,
    String? text,
    required BlueskyPostData value,
  }) = _EmbedRecord;

  const EmbedRecord._();

  factory EmbedRecord.fromJson(Map<String, dynamic> json) =>
      _$EmbedRecordFromJson(json);
}
