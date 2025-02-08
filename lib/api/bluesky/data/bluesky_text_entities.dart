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

    // Process mentions
    if (mentions != null) {
      for (final mention in mentions!) {
        // Find the @ symbol for this mention in the text
        final mentionText = '@$mention';
        final index = text.indexOf(mentionText);
        if (index != -1) {
          entities.add(
            BlueskyTextEntity(
              start: index,
              end: index + mentionText.length,
              type: 'mention',
              value: mention,
            ),
          );
        }
      }
    }

    // Process hashtags
    if (tags != null) {
      for (final tag in tags!) {
        // Find the # symbol for this tag in the text
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

  bool get isRtlLanguage => _rtlLanguages.contains(lang);

  String? get quoteUrl {
    // In Bluesky, quotes are handled as reposts with embedded posts
    if (repostOf != null) {
      return repostOf!.uri.toString();
    }
    return null;
  }
}
