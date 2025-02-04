import 'package:bluesky/bluesky.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'models.freezed.dart';
part 'models.g.dart';

/// Represents a byte slice in a text.
class ByteSlice {
  ByteSlice({required this.byteStart, required this.byteEnd});
  final int byteStart;
  final int byteEnd;
}

/// Base class for rich text features.
abstract class RichTextFeature {}

/// Represents a mention feature in rich text.
class MentionFeature extends RichTextFeature {
  MentionFeature({required this.did, required this.handle});
  final String did;
  final String handle;
}

/// Represents a link feature in rich text.
class LinkFeature extends RichTextFeature {
  LinkFeature({required this.uri});
  final String uri;
}

/// Represents a tag feature in rich text.
class TagFeature extends RichTextFeature {
  TagFeature({required this.tag});
  final String tag;
}

/// Represents a Bluesky post.
class Post {
  Post({
    required this.uri,
    required this.cid,
    required this.author,
    required this.createdAt,
    this.text,
    this.facets,
    this.embed,
    this.repostOf,
    this.replyParent,
    this.replyRoot,
    this.tags,
    this.mentions,
    this.replyCount,
    this.repostCount,
    this.likeCount,
    this.viewer,
  });
  final String uri;
  final String cid;
  final String? text;
  final List<Facet>? facets;
  final PostEmbed? embed;
  final Post? repostOf;
  final PostReply? replyParent;
  final PostReply? replyRoot;
  final List<String>? tags;
  final List<MentionFeature>? mentions;
  final int? replyCount;
  final int? repostCount;
  final int? likeCount;
  final PostViewer? viewer;
  final Profile author;
  final DateTime createdAt;
}

/// Represents a post embed (media, etc).
class PostEmbed {
  PostEmbed({this.images, this.media});
  final List<EmbedImage>? images;
  final EmbedMedia? media;
}

/// Represents an embedded image.
class EmbedImage {
  EmbedImage({required this.fullsize, this.alt, this.isAnimated = false});
  final String fullsize;
  final String? alt;
  final bool isAnimated;
}

/// Represents embedded media.
class EmbedMedia {
  EmbedMedia({required this.type, required this.url, this.alt});
  final String type;
  final String url;
  final String? alt;
}

/// Represents a post reply reference.
class PostReply {
  PostReply({required this.uri, required this.cid});
  final String uri;
  final String cid;
}

/// Represents a post viewer state.
class PostViewer {
  PostViewer({this.repost, this.like});
  final String? repost;
  final String? like;
}

/// Represents a Bluesky user profile.
class Profile {
  Profile({
    required this.did,
    required this.handle,
    this.displayName,
    this.description,
    this.avatar,
    this.banner,
    this.followersCount,
    this.followsCount,
    this.postsCount,
    this.viewer,
    this.labels,
  });
  final String did;
  final String handle;
  final String? displayName;
  final String? description;
  final String? avatar;
  final String? banner;
  final int? followersCount;
  final int? followsCount;
  final int? postsCount;
  final ProfileViewer? viewer;
  final List<Label>? labels;
}

/// Represents a profile viewer state.
class ProfileViewer {
  ProfileViewer({
    this.following,
    this.followedBy,
    this.blocking,
    this.blockedBy,
    this.muted,
  });
  final String? following;
  final String? followedBy;
  final String? blocking;
  final String? blockedBy;
  final bool? muted;
}

/// Represents a label.
@freezed
class Label with _$Label {
  const factory Label({
    required String val,
    required String src,
    required String uri,
    required DateTime cts,
    @Default(false) bool neg,
  }) = _Label;

  const Label._();

  factory Label.fromJson(Map<String, dynamic> json) => _$LabelFromJson(json);

  factory Label.fromBsky(Label label) => Label(
        val: label.val,
        src: label.src,
        uri: label.uri,
        cts: label.cts,
        neg: label.neg,
      );
}
