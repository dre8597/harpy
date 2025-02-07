import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';

enum TweetCardElement {
  topRow,
  pinned,
  retweeter,
  avatar,
  name,
  handle,
  text,
  translation,
  quote,
  media,
  actionsButton,
  actionsRow,
  details,
  linkPreview,
  parentPreview,
}

/// The actions used in the [TweetCardElement.actionsRow].
enum TweetCardActionElement {
  retweet,
  favorite,
  showReplies,
  reply,
  openExternally,
  copyText,
  share,
  translate,
  spacer,
}

extension TweetCardElementExtension on TweetCardElement {
  bool shouldBuild(BlueskyPostData tweet, TweetCardConfig config) {
    return switch (this) {
      TweetCardElement.topRow =>
        config.elements.contains(TweetCardElement.topRow),
      TweetCardElement.pinned => false,
      TweetCardElement.retweeter =>
        config.elements.contains(TweetCardElement.retweeter) &&
            tweet.repostOf != null,
      TweetCardElement.avatar =>
        config.elements.contains(TweetCardElement.avatar),
      TweetCardElement.name => config.elements.contains(TweetCardElement.name),
      TweetCardElement.handle =>
        config.elements.contains(TweetCardElement.handle),
      TweetCardElement.text =>
        config.elements.contains(TweetCardElement.text) &&
            tweet.text.isNotEmpty,
      TweetCardElement.translation =>
        config.elements.contains(TweetCardElement.translation),
      TweetCardElement.quote =>
        config.elements.contains(TweetCardElement.quote),
      TweetCardElement.media =>
        config.elements.contains(TweetCardElement.media) &&
            (tweet.media?.isNotEmpty ?? false),
      TweetCardElement.actionsButton =>
        config.elements.contains(TweetCardElement.actionsButton),
      TweetCardElement.actionsRow =>
        config.elements.contains(TweetCardElement.actionsRow),
      TweetCardElement.details =>
        config.elements.contains(TweetCardElement.details),
      TweetCardElement.linkPreview =>
        config.elements.contains(TweetCardElement.linkPreview) &&
            (tweet.externalUrls?.isNotEmpty ?? true),
      TweetCardElement.parentPreview =>
        config.elements.contains(TweetCardElement.parentPreview) &&
            tweet.parentPostId != null,
    };
  }

  /// Whether the element requires padding to be builds around it.
  bool get requiresPadding {
    return switch (this) {
      TweetCardElement.topRow => false,
      TweetCardElement.pinned => true,
      TweetCardElement.retweeter => true,
      TweetCardElement.avatar => false,
      TweetCardElement.name => false,
      TweetCardElement.handle => false,
      TweetCardElement.text => true,
      TweetCardElement.translation => true,
      TweetCardElement.quote => true,
      TweetCardElement.media => true,
      TweetCardElement.actionsButton => false,
      TweetCardElement.actionsRow => true,
      TweetCardElement.details => true,
      TweetCardElement.linkPreview => true,
      TweetCardElement.parentPreview => true,
    };
  }

  /// Build padding below when:
  /// * this element requires padding and
  /// * this is the last element or the next element also requires padding
  bool buildBottomPadding(int index, Iterable<TweetCardElement> elements) {
    return requiresPadding &&
        (index == elements.length - 1 ||
            elements.elementAt(index + 1).requiresPadding);
  }

  TweetCardElementStyle style(TweetCardConfig config) {
    return config.styles[this] ?? TweetCardElementStyle.empty;
  }
}

class TweetCardElementStyle {
  const TweetCardElementStyle({
    this.sizeDelta = 0,
  });

  static const TweetCardElementStyle empty = TweetCardElementStyle();

  final double sizeDelta;
}
