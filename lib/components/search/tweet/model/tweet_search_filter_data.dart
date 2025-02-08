import 'package:freezed_annotation/freezed_annotation.dart';

part 'tweet_search_filter_data.freezed.dart';

enum TweetSearchResultType {
  mixed,
  recent,
  popular,
}

@freezed
class TweetSearchFilterData with _$TweetSearchFilterData {
  factory TweetSearchFilterData({
    @Default('') String author,
    @Default('') String url,
    @Default('') String replyingTo,
    @Default(TweetSearchResultType.mixed) TweetSearchResultType resultType,
    @Default(<String>[]) List<String> includesPhrases,
    @Default(<String>[]) List<String> includesHashtags,
    @Default(<String>[]) List<String> includesMentions,
    @Default(<String>[]) List<String> includesUrls,
    @Default(false) bool includesRetweets,
    @Default(false) bool includesImages,
    @Default(false) bool includesVideo,
    @Default(<String>[]) List<String> excludesPhrases,
    @Default(<String>[]) List<String> excludesHashtags,
    @Default(<String>[]) List<String> excludesMentions,
    @Default(false) bool excludesRetweets,
    @Default(false) bool excludesImages,
    @Default(false) bool excludesVideo,
  }) = _TweetSearchFilterData;

  TweetSearchFilterData._();

  late final isValid = author.isNotEmpty ||
      url.isNotEmpty ||
      includesPhrases.isNotEmpty ||
      includesHashtags.isNotEmpty ||
      includesMentions.isNotEmpty;

  bool isEmpty() => this == TweetSearchFilterData();

  String buildQuery() {
    final filters = <String>[];

    // Add phrases & keywords
    for (final phrase in includesPhrases) {
      if (phrase.contains(' ')) {
        // multi word phrase
        filters.add('"$phrase"');
      } else {
        // single key word
        filters.add(phrase);
      }
    }

    for (final phrase in excludesPhrases) {
      if (phrase.contains(' ')) {
        // multi word phrase
        filters.add('-"$phrase"');
      } else {
        // single key word
        filters.add('-$phrase');
      }
    }

    // Add hashtags & mentions
    includesHashtags.forEach(filters.add);
    for (final tag in excludesHashtags) {
      filters.add('-$tag');
    }
    includesMentions.forEach(filters.add);
    for (final mention in excludesMentions) {
      filters.add('-$mention');
    }

    return filters.join(' ').trim();
  }
}
