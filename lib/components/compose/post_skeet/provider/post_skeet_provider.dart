import 'dart:convert';
import 'dart:io';

import 'package:bluesky/bluesky.dart';
import 'package:built_collection/built_collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/api/api.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/media_upload_service.dart';
import 'package:harpy/api/bluesky/media_video_converter.dart';
import 'package:http/http.dart';
import 'package:humanizer/humanizer.dart';
import 'package:rby/rby.dart';

part 'post_skeet_provider.freezed.dart';

final postTweetProvider =
    StateNotifierProvider<PostSkeetNotifier, PostTweetState>(
  (ref) => PostSkeetNotifier(
    ref: ref,
    blueskyApi: ref.watch(blueskyApiProvider),
  ),
  name: 'PostTweetProvider',
);

class PostSkeetNotifier extends StateNotifier<PostTweetState> with LoggerMixin {
  PostSkeetNotifier({
    required Ref ref,
    // required TwitterApi twitterApi,
    required Bluesky blueskyApi,
  })  : _ref = ref,
        // _blueskyApi = twitterApi,
        _blueskyApi = blueskyApi,
        super(const PostTweetState.inProgress());

  final Ref _ref;
  final Bluesky _blueskyApi;

  Future<void> post(
    String text, {
    /// The tweet hyperlink of the quoted tweet if this tweet is a quote.
    String? attachmentUrl,

    /// The id of the parent tweet if this tweet is a reply.
    String? inReplyToStatusId,
    BuiltList<PlatformFile>? media,
    MediaType? mediaType,
  }) async {
    if (state is PostTweetError) return;

    if (media != null && media.isNotEmpty && mediaType != null) {
      await _uploadmedia(media, mediaType);

      if (state is PostTweetError) return;
    }

    log.fine('posting tweet');

    state = const PostTweetState.inProgress(message: 'posting tweet...');

    String? additionalInfo;

    final status = await _blueskyApi.feed
        .post(
      text: text,
      createdAt: DateTime.now(),
    )
        .handleError((e, st) {
      if (e is Response) {
        final message = _responseErrorMessage(e.body);
        log.info(
          'handling error while sending status with message $message',
          e,
        );
        additionalInfo = message;
      } else {
        logErrorHandler(e, st);
      }
    });

    if (status != null) {
      state = PostTweetState.success(
        message: 'tweet sent successfully!',
        tweet: BlueskyPostData(
          authorAvatar: '',
          authorDid: _blueskyApi.session!.did,
          id: status.data.cid,
          uri: status.data.uri,
          text: text,
          author: _blueskyApi.session!.did,
          handle: _blueskyApi.session!.handle,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      state = PostTweetState.error(
        message: 'error sending tweet',
        additionalInfo: additionalInfo != null
            ? 'Twitter error message:\n'
                '$additionalInfo'
            : null,
      );
    }
  }

  Future<List<String>?> _uploadmedia(
    BuiltList<PlatformFile> media,
    MediaType type,
  ) async {
    log.fine('uploading media');

    final mediaFiles = <File>[];
    final mediaIds = <String>[];

    if (type == MediaType.video) {
      state = const PostTweetState.inProgress(
        message: 'preparing video...',
        additionalInfo: 'this may take a moment',
      );

      final converted =
          await _ref.read(blueskyMediaVideoConverterProvider).convertVideo(
                media.single.path,
                media.single.extension,
              );

      if (converted != null) {
        mediaFiles.add(converted);
      } else {
        state = const PostTweetState.error(
          message: 'error preparing video',
          additionalInfo: 'The video format may not be supported.',
        );
      }
    } else {
      mediaFiles.addAll(media.map((media) => File(media.path!)));
    }

    try {
      for (var i = 0; i < mediaFiles.length; i++) {
        state = PostTweetState.inProgress(
          message: type.asMessage(i, mediaFiles.length > 1),
          additionalInfo: 'this may take a moment',
        );

        final uploadResponse = await _ref
            .read(blueskyMediaUploadServiceProvider)
            .uploadSingleMedia(mediaFiles[i]);

        if (uploadResponse.isNotEmpty) mediaIds.addAll(uploadResponse.keys);
      }

      log.fine('${mediaIds.length} media uploaded');
      return mediaIds;
    } catch (e, st) {
      log.severe('error while uploading media', e, st);

      state = const PostTweetState.error(message: 'error uploading media');

      return null;
    }
  }
}

@freezed
class PostTweetState with _$PostTweetState {
  const factory PostTweetState.inProgress({
    String? message,
    String? additionalInfo,
  }) = PostTweetInProgress;

  const factory PostTweetState.success({
    required BlueskyPostData tweet,
    String? message,
    String? additionalInfo,
  }) = PostTweetSuccess;

  const factory PostTweetState.error({
    String? message,
    String? additionalInfo,
  }) = PostTweetError;
}

extension PostTweetStateExtension on PostTweetState {
  BlueskyPostData? get tweet => maybeMap(
        success: (value) => value.tweet,
        orElse: () => null,
      );
}

extension on MediaType {
  String asMessage(int index, bool multiple) {
    switch (this) {
      case MediaType.image:
        return multiple
            ? 'uploading ${(index + 1).toOrdinalNumerical()} image...'
            : 'uploading image...';
      case MediaType.gif:
        return 'uploading gif...';
      case MediaType.video:
        return 'uploading video...';
    }
  }
}

/// Returns the error message of an error response or `null` if the error was
/// unable to be parsed.
///
/// Example response:
/// {"errors":[{"code":324,"message":"Duration too long, maximum:30000,
/// actual:30528 (MediaId: snf:1338982061273714688)"}]}
String? _responseErrorMessage(String body) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final errors = json['errors'] as List<dynamic>;
    return (errors[0] as Map<String, dynamic>)['message'] as String;
  } catch (e, st) {
    logErrorHandler(e, st);
    return null;
  }
}
