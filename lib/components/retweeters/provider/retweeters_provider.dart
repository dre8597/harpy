import 'package:bluesky/core.dart' as core;
import 'package:built_collection/built_collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';

final retweetersProvider =
    FutureProvider.autoDispose.family<BuiltList<UserData>, String>(
  (ref, postUri) async {
    final blueskyApi = ref.watch(blueskyApiProvider);
    final reposters = await blueskyApi.feed.getRepostedBy(
      uri: core.AtUri.parse(postUri),
    );

    // Get full profiles for each reposter to get accurate counts
    final profiles = await Future.wait(
      reposters.data.repostedBy.map(
        (actor) => blueskyApi.actor.getProfile(actor: actor.did),
      ),
    );

    return profiles
        .map(
          (profile) => UserData(
            id: profile.data.did,
            name: profile.data.displayName ?? profile.data.handle,
            handle: profile.data.handle,
            description: profile.data.description,
            profileImage: profile.data.avatar != null
                ? UserProfileImage.fromUrl(profile.data.avatar!)
                : null,
            followersCount: profile.data.followersCount,
            followingCount: profile.data.followsCount,
            tweetCount: profile.data.postsCount,
            createdAt: DateTime.now(), // Bluesky doesn't provide creation date
          ),
        )
        .toBuiltList();
  },
  name: 'RetweetersProvider',
);
