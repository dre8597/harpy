import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';

class BlueskyTextEntity {
  const BlueskyTextEntity({
    required this.start,
    required this.end,
    required this.type,
    required this.value,
  });

  final int start;
  final int end;
  final String type;
  final String value;
}

extension BlueskyPostTextData on BlueskyPostData {
  static final _rtlLanguages = {
    'ar', // Arabic
    'fa', // Persian
    'he', // Hebrew
    'ur', // Urdu
  };

  List<BlueskyTextEntity> get entities {
    final entities = <BlueskyTextEntity>[];

    // Find all @ mentions in text using regex
    final mentionRegex = RegExp(r'@[\w.-]+');
    if (mentions != null) {
      for (final match in mentionRegex.allMatches(text)) {
        entities.add(
          BlueskyTextEntity(
            start: match.start,
            end: match.end,
            type: 'mention',
            value: text.substring(match.start + 1, match.end),
          ),
        );
      }
    }

    // Process hashtags
    if (tags != null) {
      for (final tag in tags!) {
        // Find the '#tag' in the text
        final tagText = '#$tag';
        final index = text.indexOf(tagText);
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              start: index,
              end: index + tagText.length,
              type: 'hashtag',
              value: tag,
            ),
          );
        }
      }
    }

    // Process URLs
    if (externalUrls != null) {
      for (final url in externalUrls!) {
        final index = text.indexOf(url);
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              start: index,
              end: index + url.length,
              type: 'url',
              value: url,
            ),
          );
        }
      }
    }

    // Sort entities by start position
    entities.sort((a, b) => a.start.compareTo(b.start));
    return entities;
  }

  bool get isRtlLanguage {
    // A simple implementation - you might want to use a more sophisticated
    // language detection method
    final text = this.text.trim();
    if (text.isEmpty) return false;

    // Check for RTL markers
    if (text.contains(RegExp(r'@[\w.-]+'))) {
      return true;
    }

    return false;
  }

  String? get quoteUrl {
    // In Bluesky, quotes are handled as reposts with embedded posts
    if (repostOf != null) {
      return repostOf!.uri.toString();
    }
    return null;
  }
}
