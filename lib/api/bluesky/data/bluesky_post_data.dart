import 'package:bluesky/bluesky.dart' as bsky;
import 'package:bluesky/core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  factory BlueskyPostData.fromJson(Map<String, dynamic> json) => _$BlueskyPostDataFromJson(json);

  /// Improved factory that creates a [BlueskyPostData] from a Bluesky [bsky.FeedView] and
  /// handles both image and video embeds.
  factory BlueskyPostData.fromFeedView(bsky.FeedView post) {
    final embed = post.post.embed;
    List<BlueskyMediaData>? mediaData;

    if (embed != null) {
      // Map on embed using the provided union-like API
      embed.map(
        images: (images) {
          mediaData =
              images.data.images.map(BlueskyMediaData.fromImage).cast<BlueskyMediaData>().toList();
        },
        video: (video) {
          mediaData = [BlueskyMediaData.fromVideo(video)];
        },
        external: (_) {},
        record: (_) {},
        recordWithMedia: (_) {},
        unknown: (_) {},
      );
    }

    // Extract mentions from facets
    final mentions = post.post.record.facets
        ?.where((f) => f.features.any((feat) => feat is bsky.FacetMention))
        .map((f) {
      final mention =
          f.features.firstWhere((feat) => feat is bsky.FacetMention) as bsky.FacetMention;
      return mention.did;
    }).toList();

    // Extract tags from facets
    final tags = post.post.record.facets
        ?.where((f) => f.features.any((feat) => feat is bsky.FacetTag))
        .map((f) {
      final tag = f.features.firstWhere((feat) => feat is bsky.FacetTag) as bsky.FacetTag;
      return tag.tag;
    }).toList();

    return BlueskyPostData(
      id: post.post.cid,
      text: post.post.record.text,
      uri: post.post.uri,
      author: post.post.author.displayName ?? post.post.author.handle,
      handle: post.post.author.handle,
      authorDid: post.post.author.did,
      authorAvatar: post.post.author.avatar ?? '',
      createdAt: post.post.indexedAt,
      parentPostId: post.post.record.reply?.parent.cid,
      rootPostId: post.post.record.reply?.root.cid,
      media: mediaData,
      tags: tags,
      mentions: mentions,
      replyCount: post.post.replyCount ?? 0,
      repostCount: post.post.repostCount ?? 0,
      likeCount: post.post.likeCount ?? 0,
      isReposted: post.post.viewer.repost != null,
      isLiked: post.post.viewer.like != null,
      labels: post.post.labels
          ?.map(
            (l) => Label(
              val: l.value,
              src: l.src,
              uri: l.uri,
              cts: l.createdAt,
              neg: l.isNegate,
            ),
          )
          .toList(),
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
    Duration? duration,
    @Default([]) List<String> variants,
  }) = _BlueskyMediaData;

  factory BlueskyMediaData.fromUEmbedViewMediaVideo(bsky.UEmbedViewMediaVideo video) {
    return BlueskyMediaData(
      alt: video.data.alt ?? '',
      url: video.data.playlist,
      thumb: video.data.thumbnail,
      type: MediaType.video,
      aspectRatio: (video.data.aspectRatio?.width ?? 1) / (video.data.aspectRatio?.height ?? 1),
      variants: [video.data.playlist], // Add video URL as the only variant
    );
  }

  const BlueskyMediaData._();

  factory BlueskyMediaData.fromJson(Map<String, dynamic> json) => _$BlueskyMediaDataFromJson(json);

  /// Converts an image embed into a [BlueskyMediaData] object.
  factory BlueskyMediaData.fromImage(bsky.EmbedViewImagesView image) {
    final ratio = image.aspectRatio;
    double? aspectRatioValue;
    if (ratio != null) {
      aspectRatioValue = ratio.width / ratio.height;
    }
    return BlueskyMediaData(
      alt: image.alt,
      url: image.fullsize,
      thumb: image.thumbnail,
      aspectRatio: aspectRatioValue,
      variants: [],
    );
  }

  /// Converts a video embed into a [BlueskyMediaData] object.
  factory BlueskyMediaData.fromVideo(bsky.UEmbedViewVideo video) {
    return BlueskyMediaData(
      alt: video.data.alt ?? '',
      url: video.data.playlist,
      thumb: video.data.thumbnail,
      type: MediaType.video,
      aspectRatio: (video.data.aspectRatio?.width ?? 1) / (video.data.aspectRatio?.height ?? 1),
      variants: [video.data.playlist], // Add video URL as the only variant
      duration: const Duration(), // TODO: Get actual duration when available
    );
  }

  /// Returns the appropriate URL based on media preferences and connectivity.
  @override
  String appropriateUrl(
    MediaPreferences mediaPreferences,
    ConnectivityResult connectivity,
  ) {
    return url;
  }

  /// Returns the aspect ratio of the media.
  @override
  double get aspectRatioDouble => aspectRatio ?? 1.0;

  /// Returns the best URL (simply the URL in this implementation).
  @override
  String get bestUrl => url;

  /// Convert this BlueskyMediaData to VideoMediaData if it's a video
  VideoMediaData? toVideoMediaData() {
    if (type != MediaType.video) return null;

    final thumbnailData = ImageMediaData(
      baseUrl: thumb ?? url,
      aspectRatioDouble: aspectRatioDouble,
    );

    return VideoMediaData(
      aspectRatioDouble: aspectRatioDouble,
      duration: duration,
      variants: variants.isNotEmpty ? variants : [url],
      thumbnail: thumbnailData,
      type: type,
    );
  }
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

  factory EmbedRecord.fromJson(Map<String, dynamic> json) => _$EmbedRecordFromJson(json);
}
