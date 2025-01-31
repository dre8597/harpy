import 'package:bluesky/bluesky.dart' as bsky;
import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:harpy/api/bluesky/data/bluesky_post_data.dart';
import 'package:harpy/components/components.dart';
import 'package:harpy/core/core.dart';

/// Handles a post list response in an isolate.
///
/// Only the parent [BlueskyPostData] of a reply chain will be in the returned
/// list and will include all of its replies.
Future<BuiltList<BlueskyPostData>> handlePosts(
  List<bsky.FeedView> posts, [
  TimelineFilter? filter,
]) {
  return compute<List<dynamic>, BuiltList<BlueskyPostData>>(
    _isolateHandlePosts,
    <dynamic>[posts, filter],
  );
}

BuiltList<BlueskyPostData> _isolateHandlePosts(List<dynamic> arguments) {
  final posts = arguments[0] as List<bsky.FeedView>;
  final filter = arguments[1] as TimelineFilter?;

  final postDataList = posts
      .where((post) => !_filterPost(post.post, filter))
      .map(BlueskyPostData.fromFeedView)
      .toList();

  for (var i = 0; i < postDataList.length; i++) {
    final post = postDataList[i];

    if (post.parentPostId != null && i != postDataList.length - 1) {
      // look for parent in older posts
      for (var j = i + 1; j < postDataList.length; j++) {
        final olderPost = postDataList[j];

        if (olderPost.id == post.parentPostId) {
          // found parent post, remove child post from list and add it to
          // the replies of the parent post
          postDataList[j] = olderPost.copyWith(
            replies: [...?olderPost.replies, post],
          );

          postDataList.removeAt(i);
          i--;

          break;
        }
      }
    }
  }

  // sort to make sure the posts are in chronological order with the newest
  // reply to a post pushing the parent post to the front
  postDataList.sort((a, b) {
    final targetA = a.replies?.isNotEmpty == true ? a.replies!.first : a;
    final targetB = b.replies?.isNotEmpty == true ? b.replies!.first : b;
    return targetB.createdAt.compareTo(targetA.createdAt);
  });

  return postDataList.toBuiltList();
}

bool _filterPost(bsky.Post post, TimelineFilter? filter) {
  if (filter == null) {
    return false;
  }

  // Filter reposts
  if (filter.excludes.retweets && post.record.reply != null) {
    return true;
  }

  // Filter media posts
  if (filter.includes.image || filter.includes.gif || filter.includes.video) {
    final embed = post.embed;
    if (embed == null) {
      return true;
    }

    var hasImage = false;
    const hasGif = false;
    var hasVideo = false;

    embed.map(
      images: (images) {
        hasImage = true;
      },
      external: (_) {},
      video: (_) {
        hasVideo = true;
      },
      record: (_) {},
      recordWithMedia: (_) {},
      unknown: (_) {},
    );

    if (!(filter.includes.image && hasImage ||
        filter.includes.gif && hasGif ||
        filter.includes.video && hasVideo)) {
      return true;
    }
  }

  // Handle tags and mentions through facets
  final postTags = post.record.facets
          ?.where((f) => f.features.any((feat) => feat is bsky.FacetTag))
          .map(
            (f) => (f.features.firstWhere((feat) => feat is bsky.FacetTag)
                    as bsky.FacetTag)
                .tag,
          )
          .toList() ??
      [];

  final postMentions = post.record.facets
          ?.where((f) => f.features.any((feat) => feat is bsky.FacetMention))
          .map(
            (f) => (f.features.firstWhere((feat) => feat is bsky.FacetMention)
                    as bsky.FacetMention)
                .did,
          )
          .toList() ??
      [];

  final postText = post.record.text.toLowerCase();

  // Filter included hashtags
  if (filter.includes.hashtags.isNotEmpty &&
      filter.includes.hashtags
          .map(_prepareHashtag)
          .every(postTags.containsNot)) {
    return true;
  }

  // Filter included mentions
  if (filter.includes.mentions.isNotEmpty &&
      filter.includes.mentions
          .map(_prepareMention)
          .every(postMentions.containsNot)) {
    return true;
  }

  // Filter included phrases
  if (filter.includes.phrases.isNotEmpty &&
      filter.includes.phrases
          .map((phrase) => phrase.toLowerCase())
          .every((phrase) => !postText.contains(phrase))) {
    return true;
  }

  // Filter excluded hashtags
  if (filter.excludes.hashtags.isNotEmpty &&
      filter.excludes.hashtags.map(_prepareHashtag).any(postTags.contains)) {
    return true;
  }

  // Filter excluded mentions
  if (filter.excludes.mentions.isNotEmpty &&
      filter.excludes.mentions
          .map(_prepareMention)
          .any(postMentions.contains)) {
    return true;
  }

  // Filter excluded phrases
  if (filter.excludes.phrases.isNotEmpty &&
      filter.excludes.phrases
          .map((phrase) => phrase.toLowerCase())
          .any(postText.contains)) {
    return true;
  }

  return false;
}

String? _prepareHashtag(String hashtag) {
  return removePrependedSymbol(
    hashtag.toLowerCase(),
    const {'#', '＃'},
  );
}

String? _prepareMention(String mention) {
  return removePrependedSymbol(
    mention.toLowerCase(),
    const {'@'},
  );
}

extension on Iterable<dynamic> {
  bool containsNot(Object? element) {
    return !contains(element);
  }
}
