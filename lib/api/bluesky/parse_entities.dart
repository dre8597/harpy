import 'package:bluesky/bluesky.dart' as bsky;

/// Parses entities from a Bluesky post text.
///
/// Returns a map containing:
/// - hashtags: List of hashtag strings without the '#' symbol
/// - mentions: List of mention strings without the '@' symbol
/// - urls: List of URL strings
Map<String, List<String>> parseEntities(String text) {
  final hashtags = <String>[];
  final mentions = <String>[];
  final urls = <String>[];

  // Split text into words
  final words = text.split(' ');

  for (final word in words) {
    final trimmedWord = word.trim();

    if (trimmedWord.startsWith('#')) {
      // Handle hashtags
      final tag = trimmedWord.substring(1);
      if (tag.isNotEmpty) {
        hashtags.add(tag);
      }
    } else if (trimmedWord.startsWith('@')) {
      // Handle mentions
      final mention = trimmedWord.substring(1);
      if (mention.isNotEmpty) {
        mentions.add(mention);
      }
    } else if (_isUrl(trimmedWord)) {
      // Handle URLs
      urls.add(trimmedWord);
    }
  }

  return {
    'hashtags': hashtags,
    'mentions': mentions,
    'urls': urls,
  };
}

/// Checks if a string is a URL.
bool _isUrl(String text) {
  try {
    final uri = Uri.parse(text);
    return uri.scheme == 'http' || uri.scheme == 'https';
  } catch (_) {
    return false;
  }
}

/// Extracts facets from a Bluesky post.
///
/// Returns a map containing:
/// - hashtags: List of hashtag strings without the '#' symbol
/// - mentions: List of mention strings without the '@' symbol
/// - urls: List of URL strings
Map<String, List<String>> extractFacets(bsky.Post post) {
  final hashtags = <String>[];
  final mentions = <String>[];
  final urls = <String>[];

  if (post.record.facets != null) {
    for (final facet in post.record.facets!) {
      for (final feature in facet.features) {
        feature.map(
          tag: (tag) {
            hashtags.add(tag.data.tag);
          },
          mention: (mention) {
            mentions.add(mention.data.did);
          },
          link: (link) {
            urls.add(link.data.uri);
          },
          unknown: (_) {},
        );
      }
    }
  }

  return {
    'hashtags': hashtags,
    'mentions': mentions,
    'urls': urls,
  };
}
