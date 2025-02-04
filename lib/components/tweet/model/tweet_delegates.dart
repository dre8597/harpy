import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:harpy/components/likes/likes_page.dart';

part 'tweet_delegates.freezed.dart';

typedef TweetActionCallback = void Function(WidgetRef ref);

typedef MediaActionCallback = void Function(
  WidgetRef ref,
  BlueskyMediaData media,
);

/// Delegates used by the [TweetCard] and its content.
@freezed
class TweetDelegates with _$TweetDelegates {
  const factory TweetDelegates({
    TweetActionCallback? onShowTweet,
    TweetActionCallback? onShowUser,
    TweetActionCallback? onShowRetweeter,
    TweetActionCallback? onFavorite,
    TweetActionCallback? onUnfavorite,
    TweetActionCallback? onShowLikes,
    TweetActionCallback? onRetweet,
    TweetActionCallback? onUnretweet,
    TweetActionCallback? onTranslate,
    TweetActionCallback? onShowRetweeters,
    TweetActionCallback? onComposeQuote,
    TweetActionCallback? onComposeReply,
    TweetActionCallback? onDelete,
    TweetActionCallback? onOpenTweetExternally,
    TweetActionCallback? onCopyText,
    TweetActionCallback? onShareTweet,
    MediaActionCallback? onOpenMediaExternally,
    MediaActionCallback? onDownloadMedia,
    MediaActionCallback? onShareMedia,
  }) = _TweetDelegates;
}

TweetDelegates defaultTweetDelegates(
  BlueskyPostData tweet,
  TweetNotifier notifier,
) {
  return TweetDelegates(
    onShowTweet: (ref) => ref.read(routerProvider).pushNamed(
          TweetDetailPage.name,
          pathParameters: {'authorDid': tweet.authorDid, 'id': tweet.id},
          extra: tweet,
        ),
    onShowUser: (ref) {
      final router = ref.read(routerProvider);

      if (!(router.state.fullPath?.endsWith(tweet.author) ?? false)) {
        router.pushNamed(
          UserPage.name,
          pathParameters: {'authorDid': tweet.authorDid},
        );
      }
    },
    onShowRetweeter: (ref) {
      final router = ref.read(routerProvider);

      if (!(router.state.fullPath?.endsWith(tweet.author) ?? false)) {
        router.pushNamed(
          UserPage.name,
          pathParameters: {'authorDid': tweet.authorDid},
        );
      }
    },
    onFavorite: (_) {
      HapticFeedback.lightImpact();
      notifier.like();
    },
    onUnfavorite: (_) {
      HapticFeedback.lightImpact();
      notifier.unlike();
    },
    onShowLikes: tweet.likeCount > 0
        ? (ref) => ref.read(routerProvider).pushNamed(
              LikesPage.name,
              pathParameters: {
                'authorDid': tweet.authorDid,
                'id': tweet.uri.toString(),
              },
            )
        : null,
    onRetweet: (_) {
      HapticFeedback.lightImpact();
      notifier.repost();
    },
    onUnretweet: (_) {
      HapticFeedback.lightImpact();
      notifier.unrepost();
    },
    onTranslate: (ref) {
      HapticFeedback.lightImpact();
      notifier.translate(locale: Localizations.localeOf(ref.context));
    },
    onShowRetweeters: tweet.repostCount > 0
        ? (ref) => ref.read(routerProvider).pushNamed(
              RetweetersPage.name,
              pathParameters: {
                'authorDid': tweet.authorDid,
                'id': tweet.uri.toString(),
              },
            )
        : null,
    onComposeQuote: (ref) => ref.read(routerProvider).pushNamed(
      ComposePage.name,
      extra: {'quotedTweet': tweet},
    ),
    onComposeReply: (ref) => ref.read(routerProvider).pushNamed(
      ComposePage.name,
      extra: {'parentTweet': tweet},
    ),
    onDelete: (ref) {
      HapticFeedback.lightImpact();
      notifier.delete(
        onDeleted: () => ref.read(homeTimelineProvider.notifier).removeTweet(tweet),
      );
    },
    onOpenTweetExternally: (ref) {
      HapticFeedback.lightImpact();
      ref.read(launcherProvider)(
        tweet.uri.toString(),
        alwaysOpenExternally: true,
      );
    },
    onCopyText: (ref) {
      HapticFeedback.lightImpact();
      Clipboard.setData(ClipboardData(text: tweet.text));
      ref.read(messageServiceProvider).showText('copied tweet text');
    },
    onShareTweet: (ref) {
      HapticFeedback.lightImpact();
      Share.share(tweet.uri.toString());
    },
    onOpenMediaExternally: (ref, media) {
      HapticFeedback.lightImpact();
      ref.read(launcherProvider)(media.url, alwaysOpenExternally: true);
    },
    onDownloadMedia: _downloadMedia,
    onShareMedia: (_, media) {
      HapticFeedback.lightImpact();
      Share.share(media.url);
    },
  );
}

Future<void> _downloadMedia(
  WidgetRef ref,
  BlueskyMediaData media,
) async {
  var name = filenameFromUrl(media.url) ?? 'media';

  final storagePermission = await Permission.storage.request();

  if (!storagePermission.isGranted) {
    ref.read(messageServiceProvider).showText('storage permission not granted');
    return;
  }

  if (ref.read(mediaPreferencesProvider).showDownloadDialog) {
    final mediaType = mediaTypeFromPath(media.type.toMediaCategory);
    if (mediaType == null) {
      assert(false);
      return;
    }

    final customName = await showDialog<String>(
      context: ref.context,
      builder: (_) => DownloadDialog(
        initialName: name,
        type: mediaType,
      ),
    );

    if (customName != null) {
      name = customName;
    } else {
      // user cancelled the download dialog
      return;
    }
  }

  await ref.read(downloadPathProvider.notifier).initialize();
  final mediaType = mediaTypeFromPath(media.type.toMediaCategory);

  if (mediaType == null) {
    assert(false);
    return;
  }

  final path = ref.read(downloadPathProvider).fullPathForType(mediaType);

  if (path == null) {
    assert(false);
    return;
  }

  await ref.read(downloadServiceProvider).download(
        url: media.url,
        name: name,
        path: path,
      );

  ref.read(messageServiceProvider).showText('download started');
}
