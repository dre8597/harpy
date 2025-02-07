import 'package:bluesky/bluesky.dart' as bsky;
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';
import 'package:logging/logging.dart';
import 'package:rby/rby.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_page_provider.g.dart';

@riverpod
class UserPageNotifier extends _$UserPageNotifier {
  late LanguagePreferences _languagePreferences;
  late TranslateService _translateService;
  late bsky.Bluesky _blueskyApi;
  final log = Logger('UserPageNotifier');

  @override
  Future<UserPageData> build(String authorDid) async {
    _languagePreferences = ref.watch(languagePreferencesProvider);
    _translateService = ref.watch(translateServiceProvider);
    _blueskyApi = ref.watch(blueskyApiProvider);

    final profile = await _blueskyApi.actor.getProfile(actor: authorDid);

    BlueskyPostData? pinnedPost;
    final pinnedPosts = await _blueskyApi.feed.getAuthorFeed(actor: authorDid, includePins: true);
    if (pinnedPosts.data.feed.isNotEmpty) {
      final pinnedPostView = pinnedPosts.data.feed.firstWhereOrNull(
        (post) => post.post.viewer.pinned,
      );
      if (pinnedPostView != null) {
        pinnedPost = BlueskyPostData.fromFeedView(pinnedPostView);
      }
    }

    final relationship = BlueskyRelationshipData(
      targetDid: profile.data.did,
      targetHandle: profile.data.handle,
      targetDisplayName: profile.data.displayName,
      following: profile.data.viewer.isFollowing,
      followedBy: profile.data.viewer.isFollowedBy,
      blocking: profile.data.viewer.isBlocking,
      blockedBy: profile.data.viewer.isBlockedBy,
      muting: profile.data.viewer.isMuted,
    );

    return UserPageData(
      user: UserData.fromBlueskyActorProfile(profile.data),
      bannerUrl: profile.data.banner,
      pinnedTweet: pinnedPost,
      relationship: relationship,
    );
  }

  Future<void> translateDescription({required Locale locale}) async {
    if (state is! AsyncData) return;
    final data = state.value!;

    if (data.descriptionTranslationState
        is! DescriptionTranslationStateUntranslated) {
      return;
    }

    final translateLanguage =
        _languagePreferences.activeTranslateLanguage(locale);

    state = AsyncData(
      data.copyWith(
        descriptionTranslationState:
            const DescriptionTranslationState.translating(),
      ),
    );

    final translation = await _translateService
        .translate(text: data.user.description ?? '', to: translateLanguage)
        .handleError(logErrorHandler);

    final translationState = translation != null && translation.isTranslated
        ? DescriptionTranslationState.translated(translation: translation)
        : const DescriptionTranslationState.notTranslated();

    if (translationState is DescriptionTranslationStateNotTranslated) {
      ref.read(messageServiceProvider).showText('description not translated');
    }

    state = AsyncData(
      state.value!.copyWith(
        descriptionTranslationState: translationState,
      ),
    );
  }

  Future<void> follow() async {
    final data = state.value;
    if (data == null) return;
    if (data.relationship == null) return;

    final relationship = data.relationship as BlueskyRelationshipData;

    state = state.copyWithRelationshipField(
      following: true,
      followedBy: relationship.followedBy,
    );

    try {
      await _blueskyApi.graph.follow(did: data.user.id);
    } catch (e, st) {
      log.warning('error following user', e, st);
      ref.read(messageServiceProvider).showText('error following user');

      // assume still not following
      state = state.copyWithRelationshipField(
        following: false,
        followedBy: relationship.followedBy,
      );
    }
  }

  Future<void> unfollow() async {
    final data = state.value;
    if (data == null) return;
    if (data.relationship == null) return;

    final relationship = data.relationship as BlueskyRelationshipData;
    final profile = await _blueskyApi.actor.getProfile(actor: data.user.handle);
    final followingUri = profile.data.viewer.following;
    if (followingUri == null) return;

    state = state.copyWithRelationshipField(
      following: false,
      followedBy: relationship.followedBy,
    );

    try {
      await _blueskyApi.atproto.repo.deleteRecord(uri: followingUri);
    } catch (e, st) {
      log.warning('error unfollowing user', e, st);
      ref.read(messageServiceProvider).showText('error unfollowing user');

      // assume still following
      state = state.copyWithRelationshipField(
        following: true,
        followedBy: relationship.followedBy,
      );
    }
  }

  Future<void> block() async {
    final data = state.value;
    if (data == null) return;
    if (data.relationship == null) return;

    final relationship = data.relationship as BlueskyRelationshipData;

    state = state.copyWithRelationshipField(
      blocking: true,
      following: false,
      followedBy: relationship.followedBy,
    );

    try {
      await _blueskyApi.graph.block(did: data.user.id);
    } catch (e, st) {
      log.warning('error blocking user', e, st);
      ref.read(messageServiceProvider).showText('error blocking user');

      // assume still not blocking
      state = state.copyWithRelationshipField(
        blocking: false,
        following: relationship.following,
        followedBy: relationship.followedBy,
      );
    }
  }

  Future<void> unblock() async {
    final data = state.value;
    if (data == null) return;
    if (data.relationship == null) return;

    final relationship = data.relationship as BlueskyRelationshipData;
    final profile = await _blueskyApi.actor.getProfile(actor: data.user.handle);
    final blockingUri = profile.data.viewer.blocking;
    if (blockingUri == null) return;

    state = state.copyWithRelationshipField(
      blocking: false,
      following: false,
      followedBy: relationship.followedBy,
    );

    try {
      await _blueskyApi.atproto.repo.deleteRecord(uri: blockingUri);
    } catch (e, st) {
      log.warning('error unblocking user', e, st);
      ref.read(messageServiceProvider).showText('error unblocking user');

      // assume still blocking
      state = state.copyWithRelationshipField(
        blocking: true,
        following: relationship.following,
        followedBy: relationship.followedBy,
      );
    }
  }

  Future<void> mute() async {
    final data = state.value;
    if (data == null) return;
    if (data.relationship == null) return;

    state = state.copyWithRelationshipField(muting: true);

    try {
      await _blueskyApi.graph.muteActor(actor: data.user.handle);
    } catch (e, st) {
      log.warning('error muting user', e, st);
      ref.read(messageServiceProvider).showText('error muting user');

      // assume still not muting
      state = state.copyWithRelationshipField(muting: false);
    }
  }

  Future<void> unmute() async {
    final data = state.value;
    if (data == null) return;
    if (data.relationship == null) return;

    state = state.copyWithRelationshipField(muting: false);

    try {
      await _blueskyApi.graph.unmuteActor(actor: data.user.handle);
    } catch (e, st) {
      log.warning('error unmuting user', e, st);
      ref.read(messageServiceProvider).showText('error unmuting user');

      // assume still muting
      state = state.copyWithRelationshipField(muting: true);
    }
  }
}

extension on AsyncValue<UserPageData> {
  AsyncData<UserPageData> copyWithRelationshipField({
    bool? following,
    bool? followedBy,
    bool? muting,
    bool? blocking,
  }) {
    final relationship = asData!.value.relationship;
    if (relationship == null) return asData!;

    return AsyncData(
      asData!.value.copyWith(
        relationship: relationship.copyWith(
          following: following ?? relationship.following,
          followedBy: followedBy ?? relationship.followedBy,
          muting: muting ?? relationship.muting,
          blocking: blocking ?? relationship.blocking,
        ),
      ),
    );
  }
}
