import 'package:bluesky/bluesky.dart' as bsky;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'entities_data.freezed.dart';
part 'entities_data.g.dart';

/// Data class representing entities in a Bluesky post.
@freezed
class BlueskyEntitiesData with _$BlueskyEntitiesData {
  const factory BlueskyEntitiesData({
    List<BlueskyMentionData>? mentions,
    List<BlueskyLinkData>? links,
    List<BlueskyTagData>? tags,
  }) = _BlueskyEntitiesData;

  factory BlueskyEntitiesData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyEntitiesDataFromJson(json);

  /// Creates a [BlueskyEntitiesData] from a Bluesky post's facets.
  factory BlueskyEntitiesData.fromFacets(List<bsky.Facet>? facets) {
    if (facets == null) return const BlueskyEntitiesData();

    final mentions = <BlueskyMentionData>[];
    final links = <BlueskyLinkData>[];
    final tags = <BlueskyTagData>[];

    for (final facet in facets) {
      for (final feature in facet.features) {
        feature.map(
          mention: (mention) {
            mentions.add(
              BlueskyMentionData(
                did: mention.data.did,
                handle: '', // Handle needs to be resolved separately
                start: facet.index.byteStart,
                end: facet.index.byteEnd,
              ),
            );
          },
          link: (link) {
            links.add(
              BlueskyLinkData(
                url: link.data.uri,
                start: facet.index.byteStart,
                end: facet.index.byteEnd,
              ),
            );
          },
          tag: (tag) {
            tags.add(
              BlueskyTagData(
                tag: tag.data.tag,
                start: facet.index.byteStart,
                end: facet.index.byteEnd,
              ),
            );
          },
          unknown: (_) {},
        );
      }
    }

    return BlueskyEntitiesData(
      mentions: mentions,
      links: links,
      tags: tags,
    );
  }

  /// Creates a list of Bluesky facets from this entity data.
  /// This is useful when creating posts.
  List<bsky.Facet> toFacets() {
    final facets = <bsky.Facet>[];

    mentions?.forEach((mention) {
      facets.add(
        bsky.Facet(
          index: bsky.ByteSlice(
            byteStart: mention.start,
            byteEnd: mention.end,
          ),
          features: [
            bsky.FacetFeature.mention(
              data: bsky.FacetMention(
                did: mention.did,
              ),
            ),
          ],
        ),
      );
    });

    links?.forEach((link) {
      facets.add(
        bsky.Facet(
          index: bsky.ByteSlice(
            byteStart: link.start,
            byteEnd: link.end,
          ),
          features: [
            bsky.FacetFeature.link(
              data: bsky.FacetLink(
                uri: link.url,
              ),
            ),
          ],
        ),
      );
    });

    tags?.forEach((tag) {
      facets.add(
        bsky.Facet(
          index: bsky.ByteSlice(
            byteStart: tag.start,
            byteEnd: tag.end,
          ),
          features: [
            bsky.FacetFeature.tag(
              data: bsky.FacetTag(
                tag: tag.tag,
              ),
            ),
          ],
        ),
      );
    });

    return facets;
  }
}

/// Data class representing a mention entity in a Bluesky post.
@freezed
class BlueskyMentionData with _$BlueskyMentionData {
  const factory BlueskyMentionData({
    required String did,
    String? handle,
    required int start,
    required int end,
  }) = _BlueskyMentionData;

  factory BlueskyMentionData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyMentionDataFromJson(json);
}

/// Data class representing a link entity in a Bluesky post.
@freezed
class BlueskyLinkData with _$BlueskyLinkData {
  const factory BlueskyLinkData({
    required String url,
    required int start,
    required int end,
  }) = _BlueskyLinkData;

  factory BlueskyLinkData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyLinkDataFromJson(json);
}

/// Data class representing a tag entity in a Bluesky post.
@freezed
class BlueskyTagData with _$BlueskyTagData {
  const factory BlueskyTagData({
    required String tag,
    required int start,
    required int end,
  }) = _BlueskyTagData;

  factory BlueskyTagData.fromJson(Map<String, dynamic> json) =>
      _$BlueskyTagDataFromJson(json);
}
