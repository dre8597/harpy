import 'dart:ui';

import 'package:bluesky/bluesky.dart';
import 'package:bluesky/cardyb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:rby/rby.dart';

final tweetProvider = StateNotifierProvider.autoDispose
    .family<TweetNotifier, BlueskyPostData?, String>(
  (ref, id) {
    ref.cacheFor(const Duration(minutes: 5));

    return TweetNotifier(
      ref: ref,
      blueskyApi: ref.watch(blueskyApiProvider),
      translateService: ref.watch(translateServiceProvider),
      messageService: ref.watch(messageServiceProvider),
      languagePreferences: ref.watch(languagePreferencesProvider),
    );
  },
);

class TweetNotifier extends StateNotifier<BlueskyPostData?> with LoggerMixin {
  TweetNotifier({
    required Ref ref,
    required Bluesky blueskyApi,
    required TranslateService translateService,
    required MessageService messageService,
    required LanguagePreferences languagePreferences,
  })  : _ref = ref,
        _blueskyApi = blueskyApi,
        _translateService = translateService,
        _messageService = messageService,
        _languagePreferences = languagePreferences,
        super(null);

  final Ref _ref;
  final Bluesky _blueskyApi;
  final TranslateService _translateService;
  final MessageService _messageService;
  final LanguagePreferences _languagePreferences;

  void initialize(BlueskyPostData post) {
    if (mounted && state == null) state = post;
  }

  Future<void> repost() async {
    final post = state;
    if (post == null || (post.isReposted)) return;

    state = post.copyWith(
      isReposted: true,
      repostCount: (post.repostCount) + 1,
    );

    try {
      await _blueskyApi.feed.repost(
        uri: post.uri,
        cid: post.id,
      );
      log.fine('reposted ${post.id}');
    } catch (e, st) {
      log.warning('error reposting ${post.id}', e, st);
      state = post;
      _messageService.showText('Failed to repost');
    }
  }

  Future<void> unrepost() async {
    final post = state;
    if (post == null || !post.isReposted) return;

    state = post.copyWith(
      isReposted: false,
      repostCount: post.repostCount - 1,
    );

    try {
      await _blueskyApi.atproto.repo.deleteRecord(
        uri: post.uri,
      );
      log.fine('un-reposted ${post.id}');
    } catch (e, st) {
      log.warning('error un-reposting ${post.id}', e, st);
      state = post;
      _messageService.showText('Failed to remove repost');
    }
  }

  Future<void> like() async {
    final post = state;
    if (post == null || post.isLiked) return;

    state = post.copyWith(
      isLiked: true,
      likeCount: (post.likeCount) + 1,
    );

    try {
      await _blueskyApi.feed.like(
        uri: post.uri,
        cid: post.id,
      );
      log.fine('liked ${post.id}');
    } catch (e, st) {
      log.warning('error liking ${post.id}', e, st);
      state = post;
      _messageService.showText('Failed to like post');
    }
  }

  Future<void> unlike() async {
    final post = state;
    if (post == null || !post.isLiked) return;

    state = post.copyWith(
      isLiked: false,
      likeCount: (post.likeCount) - 1,
    );

    try {
      await _blueskyApi.atproto.repo.deleteRecord(
        uri: post.uri,
      );
      log.fine('un-liked ${post.id}');
    } catch (e, st) {
      log.warning('error un-liking ${post.id}', e, st);
      state = post;
      _messageService.showText('Failed to remove like');
    }
  }

  Future<void> translate({
    required Locale locale,
  }) async {
    final post = state;
    if (post == null) return;

    final translateLanguage =
        _languagePreferences.activeTranslateLanguage(locale);

    if (post.text.isEmpty) {
      log.fine('post not translatable');
      return;
    }

    if (post.text.isNotEmpty) {
      // also translate quoted post if one exists
      _ref
          .read(tweetProvider(post.text).notifier)
          .translate(locale: locale)
          .ignore();
    }

    // state = post.copyWith(translating: true);

    final translation = await _translateService
        .translate(text: post.text, to: translateLanguage)
        .handleError(logErrorHandler);

    if (translation != null && !translation.isTranslated) {
      _messageService.showText('post not translated');
    }

    //TODO: Add back translating
    // state = post.copyWith(
    //   translating: false,
    //   translatedText: translation?.translatedText,
    // );
  }

  Future<void> delete({
    VoidCallback? onDeleted,
  }) async {
    final post = state;
    if (post == null) return;

    log.fine('deleting post');

    try {
      await _blueskyApi.atproto.repo.deleteRecord(
        uri: post.uri,
      );
      _messageService.showText('post deleted');
      onDeleted?.call();
    } catch (e, st) {
      log.warning('error deleting post', e, st);
      _messageService.showText('Failed to delete post');
    }
  }
}

/// Returns `true` if the error contains any of the following error codes:
///
/// 139: already favorited
/// 327: already retweeted
/// 144: tweet with id not found (trying to unfavorite a tweet twice) or
/// trying to delete a tweet that has already been deleted before.
bool _actionPerformed(Object error) {
  if (error is Response) {
    try {
      final body = error.data as Map<String, dynamic>;
      final errors = body['errors'] as List<dynamic>?;

      return errors?.any(
            (error) =>
                error is Map<String, dynamic> &&
                (error['code'] == 139 ||
                    error['code'] == 327 ||
                    error['code'] == 144),
          ) ??
          false;
    } catch (e) {
      // ignore unexpected error format
    }
  }

  return false;
}
