import 'package:bluesky/bluesky.dart';
// import 'package:dart_twitter_api/twitter_api.dart' as v1;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/bluesky/data/models.dart';
import 'package:harpy/api/bluesky/data/entities_data.dart';
import 'package:harpy/api/bluesky/data/bluesky_text_entities.dart';
// import 'package:twitter_api_v2/twitter_api_v2.dart' as v2;

part 'user_data.freezed.dart';

@freezed
class UserData with _$UserData {
  const factory UserData({
    required String id,
    required String name,
    required String handle,
    String? description,
    BlueskyEntitiesData? descriptionEntities,
    // UrlData? url,
    UserProfileImage? profileImage,
    String? location,
    @Default(false) bool isProtected,
    @Default(false) bool isVerified,
    @Default(0) int followersCount,
    @Default(0) int followingCount,
    @Default(0) int tweetCount,
    DateTime? createdAt,
  }) = _UserData;

  // factory UserData.fromV2(v2.UserData user) {
  //   return UserData(
  //     id: user.id,
  //     name: user.name,
  //     handle: user.username,
  //     description: user.description?.isEmpty ?? false ? null : user.description,
  //     descriptionEntities: user.entities?.description != null
  //         ? EntitiesData.fromV2UserDescriptionEntity(
  //             user.entities!.description,
  //           )
  //         : null,
  //     url: user.entities?.url?.urls != null && user.entities!.url!.urls.isNotEmpty
  //         ? UrlData.fromV2(user.entities!.url!.urls.first)
  //         : null,
  //     profileImage:
  //         user.profileImageUrl != null ? UserProfileImage.fromUrl(user.profileImageUrl!) : null,
  //     location: user.location,
  //     isProtected: user.isProtected ?? false,
  //     isVerified: user.isVerified ?? false,
  //     followersCount: user.publicMetrics?.followersCount ?? 0,
  //     followingCount: user.publicMetrics?.followingCount ?? 0,
  //     tweetCount: user.publicMetrics?.tweetCount ?? 0,
  //     createdAt: user.createdAt,
  //   );
  // }
  //
  // factory UserData.fromV1(v1.User user) {
  //   final userUrl = user.entities?.url?.urls != null && user.entities!.url!.urls!.isNotEmpty
  //       ? UrlData.fromV1(user.entities!.url!.urls!.first)
  //       : null;
  //
  //   final userDescriptionUrls =
  //       user.entities?.description?.urls?.map(UrlData.fromV1).toList() ?? [];
  //
  //   return UserData(
  //     id: user.idStr ?? '',
  //     name: user.name ?? '',
  //     handle: user.screenName ?? '',
  //     description: user.description?.isEmpty ?? false ? null : user.description,
  //     descriptionEntities: _v1UserDescriptionEntities(
  //       userDescriptionUrls,
  //       user.description,
  //     ),
  //     url: userUrl,
  //     profileImage: user.profileImageUrlHttps != null
  //         ? UserProfileImage.fromUrl(user.profileImageUrlHttps!)
  //         : null,
  //     location: user.location,
  //     isProtected: user.protected ?? false,
  //     isVerified: user.verified ?? false,
  //     followersCount: user.followersCount ?? 0,
  //     followingCount: user.friendsCount ?? 0,
  //     createdAt: user.createdAt,
  //   );
  // }

  factory UserData.fromBlueskyProfile(Profile profile) {
    // Extract entities from description if available
    BlueskyEntitiesData? entities;
    if (profile.description != null) {
      final textEntities = _extractEntitiesFromText(profile.description!);
      entities = BlueskyEntitiesData(
        mentions: textEntities
            .where((e) => e.type == 'mention')
            .map(
              (e) => BlueskyMentionData(
                did: e.value,
                handle: e.value,
                start: e.start,
                end: e.end,
              ),
            )
            .toList(),
        links: textEntities
            .where((e) => e.type == 'url')
            .map(
              (e) => BlueskyLinkData(
                url: e.value,
                start: e.start,
                end: e.end,
              ),
            )
            .toList(),
        tags: textEntities
            .where((e) => e.type == 'hashtag')
            .map(
              (e) => BlueskyTagData(
                tag: e.value,
                start: e.start,
                end: e.end,
              ),
            )
            .toList(),
      );
    }

    return UserData(
      id: profile.did,
      name: profile.displayName ?? profile.handle,
      handle: profile.handle,
      description: profile.description,
      descriptionEntities: entities,
      profileImage: profile.avatar != null
          ? UserProfileImage.fromUrl(profile.avatar!)
          : null,
      followersCount: profile.followersCount ?? 0,
      followingCount: profile.followsCount ?? 0,
      tweetCount: profile.postsCount ?? 0,
      createdAt: DateTime.now(), // Bluesky doesn't provide creation date
    );
  }

  factory UserData.fromBlueskyActorProfile(ActorProfile profile) {
    // Extract entities from description if available
    BlueskyEntitiesData? entities;
    if (profile.description != null) {
      final textEntities = _extractEntitiesFromText(profile.description!);
      entities = BlueskyEntitiesData(
        mentions: textEntities
            .where((e) => e.type == 'mention')
            .map(
              (e) => BlueskyMentionData(
                did: e.value,
                handle: e.value,
                start: e.start,
                end: e.end,
              ),
            )
            .toList(),
        links: textEntities
            .where((e) => e.type == 'url')
            .map(
              (e) => BlueskyLinkData(
                url: e.value,
                start: e.start,
                end: e.end,
              ),
            )
            .toList(),
        tags: textEntities
            .where((e) => e.type == 'hashtag')
            .map(
              (e) => BlueskyTagData(
                tag: e.value,
                start: e.start,
                end: e.end,
              ),
            )
            .toList(),
      );
    }

    return UserData(
      id: profile.did,
      name: profile.displayName ?? profile.handle,
      handle: profile.handle,
      description: profile.description,
      descriptionEntities: entities,
      profileImage: profile.avatar != null
          ? UserProfileImage.fromUrl(profile.avatar!)
          : null,
      followersCount: profile.followersCount,
      followingCount: profile.followsCount,
      tweetCount: profile.postsCount,
      createdAt: DateTime.now(), // Bluesky doesn't provide creation date
    );
  }
}

@freezed
class UserProfileImage with _$UserProfileImage {
  const factory UserProfileImage({
    required Uri? mini,
    required Uri? normal,
    required Uri? bigger,
    required Uri? original,
  }) = _UserProfileImage;

  factory UserProfileImage.fromUrl(String profileImageUrl) {
    return UserProfileImage(
      mini: Uri.tryParse(profileImageUrl.replaceAll('_normal', '_mini')),
      normal: Uri.tryParse(profileImageUrl),
      bigger: Uri.tryParse(profileImageUrl.replaceAll('_normal', '_bigger')),
      original: Uri.tryParse(profileImageUrl.replaceAll('_normal', '')),
    );
  }
}

List<BlueskyTextEntity> _extractEntitiesFromText(String text) {
  final entities = <BlueskyTextEntity>[];

  // Find mentions
  final mentionRegex = RegExp(r'@[\w.-]+');
  for (final match in mentionRegex.allMatches(text)) {
    entities.add(
      BlueskyTextEntity(
        start: match.start,
        end: match.end,
        type: 'mention',
        value: text.substring(match.start + 1, match.end), // Remove @ symbol
      ),
    );
  }

  // Find URLs
  final urlRegex = RegExp(
    r'https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  );
  for (final match in urlRegex.allMatches(text)) {
    entities.add(
      BlueskyTextEntity(
        start: match.start,
        end: match.end,
        type: 'url',
        value: text.substring(match.start, match.end),
      ),
    );
  }

  // Find hashtags
  final hashtagRegex = RegExp(r'#[\w-]+');
  for (final match in hashtagRegex.allMatches(text)) {
    entities.add(
      BlueskyTextEntity(
        start: match.start,
        end: match.end,
        type: 'hashtag',
        value: text.substring(match.start + 1, match.end), // Remove # symbol
      ),
    );
  }

  return entities;
}

// EntitiesData _v1UserDescriptionEntities(
//   List<UrlData> userDescriptionUrls,
//   String? description,
// ) {
//   if (description != null) {
//     final descriptionEntities = parseEntities(description);
//
//     return descriptionEntities.copyWith(
//       urls: userDescriptionUrls.toList(),
//     );
//   } else {
//     return EntitiesData(
//       urls: userDescriptionUrls.toList(),
//     );
//   }
// }
