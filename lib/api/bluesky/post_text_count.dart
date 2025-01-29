import 'package:bluesky/bluesky.dart';
import 'package:harpy/api/bluesky/parse_entities.dart';

/// The maximum length of a Bluesky post.
const kMaxPostLength = 300;

/// The length of a URL in a post.
const kUrlLength = 23;

/// Calculates the weighted length of post text.
///
/// Takes into account:
/// - URLs are counted as [kUrlLength] characters
/// - Mentions and hashtags are counted as their actual length
/// - Unicode characters are counted as their actual length
class PostTextCount {
  PostTextCount(this.text) {
    _calculateLength();
  }

  /// The text to calculate the length for.
  final String text;

  /// The weighted length of the text.
  late final int weightedLength;

  /// The remaining characters that can be added to the text.
  late final int remainingLength;

  /// Whether the text exceeds the maximum length.
  late final bool exceedsMaxLength;

  void _calculateLength() {
    final entities = parseEntities(text);
    var length = text.length;

    // Subtract the actual URL lengths and add the t.co length for each URL
    for (final url in entities['urls']!) {
      length = length - url.length + kUrlLength;
    }

    weightedLength = length;
    remainingLength = kMaxPostLength - weightedLength;
    exceedsMaxLength = weightedLength > kMaxPostLength;
  }
}

/// Calculates the weighted length of post text with facets.
///
/// Takes into account:
/// - URLs are counted as [kUrlLength] characters
/// - Mentions and hashtags are counted as their actual length
/// - Unicode characters are counted as their actual length
class PostTextCountWithFacets {
  PostTextCountWithFacets(this.text, this.post) {
    _calculateLength();
  }

  /// The text to calculate the length for.
  final String text;

  /// The post containing facets.
  final Post post;

  /// The weighted length of the text.
  late final int weightedLength;

  /// The remaining characters that can be added to the text.
  late final int remainingLength;

  /// Whether the text exceeds the maximum length.
  late final bool exceedsMaxLength;

  void _calculateLength() {
    final entities = extractFacets(post);
    var length = text.length;

    // Subtract the actual URL lengths and add the t.co length for each URL
    for (final url in entities['urls']!) {
      length = length - url.length + kUrlLength;
    }

    weightedLength = length;
    remainingLength = kMaxPostLength - weightedLength;
    exceedsMaxLength = weightedLength > kMaxPostLength;
  }
}
