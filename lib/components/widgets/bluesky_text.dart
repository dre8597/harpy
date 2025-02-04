import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:harpy/api/bluesky/data/bluesky_text_entities.dart';
import 'package:url_launcher/url_launcher.dart';

class BlueskyText extends StatelessWidget {
  const BlueskyText(
    this.text, {
    this.entities,
    this.urlToIgnore,
    this.style,
    this.onMentionTap,
    this.onHashtagTap,
    this.onUrlTap,
    super.key,
  });

  final String text;
  final List<BlueskyTextEntity>? entities;
  final String? urlToIgnore;
  final TextStyle? style;
  final void Function(String)? onMentionTap;
  final void Function(String)? onHashtagTap;
  final void Function(String)? onUrlTap;

  @override
  Widget build(BuildContext context) {
    if (entities == null || entities!.isEmpty) {
      return SelectableText(text, style: style);
    }

    final spans = <TextSpan>[];
    var currentIndex = 0;

    // Sort entities by start index
    final sortedEntities = List<BlueskyTextEntity>.from(entities!)
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final entity in sortedEntities) {
      if (entity.start > currentIndex) {
        // Add text before the entity
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, entity.start),
            style: style,
          ),
        );
      }

      // Skip if this is the URL we want to ignore
      if (entity.type == 'url' && entity.value == urlToIgnore) {
        currentIndex = entity.end;
        continue;
      }

      final entityText = text.substring(entity.start, entity.end);
      final entityStyle = style?.copyWith(
        color: _getEntityColor(context, entity.type),
      );

      spans.add(
        TextSpan(
          text: entityText,
          style: entityStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleEntityTap(entity),
        ),
      );

      currentIndex = entity.end;
    }

    // Add remaining text
    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: style,
        ),
      );
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Color _getEntityColor(BuildContext context, String type) {
    final theme = Theme.of(context);
    switch (type) {
      case 'mention':
        return theme.colorScheme.primary;
      case 'hashtag':
        return theme.colorScheme.secondary;
      case 'url':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.primary;
    }
  }

  void _handleEntityTap(BlueskyTextEntity entity) {
    switch (entity.type) {
      case 'mention':
        onMentionTap?.call(entity.value);
      case 'hashtag':
        onHashtagTap?.call(entity.value);
      case 'url':
        onUrlTap?.call(entity.value);
        // If no custom URL handler, open in browser
        if (onUrlTap == null) {
          launchUrl(Uri.parse(entity.value));
        }
    }
  }
}
