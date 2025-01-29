import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/bluesky_api_provider.dart';
import 'package:harpy/api/bluesky/media_type.dart';

/// A service to handle media uploads to Bluesky.
class BlueskyMediaUploadService {
  BlueskyMediaUploadService(this._ref);

  final Ref _ref;

  /// Uploads media files to Bluesky.
  ///
  /// Returns a list of blob objects that can be used when creating a post.
  Future<List<Map<String, dynamic>>> uploadMedia(List<File> mediaFiles) async {
    final bluesky = await _ref.read(blueskyApiProvider);
    final uploads = <Map<String, dynamic>>[];

    for (final file in mediaFiles) {
      final type = mediaTypeFromPath(file.path);
      if (type == null) {
        throw Exception('Unsupported media type for file: ${file.path}');
      }

      if (!isMediaSupported(file)) {
        throw Exception('File size exceeds limit or format not supported: ${file.path}');
      }

      final bytes = await file.readAsBytes();

      try {
        // Upload the blob using the Bluesky repo.uploadBlob endpoint
        if (bluesky.session == null) {
          throw Exception('Not authenticated');
        }

        final upload = await bluesky.atproto.repo.uploadBlob(bytes);

        if (upload.status.code >= 200 && upload.status.code < 300) {
          uploads.add(upload.data.toJson());
        } else {
          throw Exception('Failed to upload media: ${upload.status.code}');
        }
      } catch (e) {
        print('Failed to upload media: $e');
        rethrow;
      }
    }

    return uploads;
  }

  /// Uploads a single media file to Bluesky.
  Future<Map<String, dynamic>> uploadSingleMedia(File mediaFile) async {
    final uploads = await uploadMedia([mediaFile]);
    return uploads.first;
  }

  /// Validates if the media file is supported and within size limits
  bool isMediaSupported(File file) {
    final type = mediaTypeFromPath(file.path);
    if (type == null) return false;

    // Check file size (Bluesky limits)
    final sizeInMb = file.lengthSync() / (1024 * 1024);
    switch (type) {
      case MediaType.image:
        // Bluesky image limit is 1MB
        return sizeInMb <= 1.0;
      case MediaType.gif:
        // GIFs are treated as images in Bluesky
        return sizeInMb <= 1.0;
      case MediaType.video:
        // Video uploads not yet supported in Bluesky
        return false;
    }
  }
}

/// The provider for the [BlueskyMediaUploadService].
final blueskyMediaUploadServiceProvider = Provider(
  name: 'blueskyMediaUploadServiceProvider',
  BlueskyMediaUploadService.new,
);
