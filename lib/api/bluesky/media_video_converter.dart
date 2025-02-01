import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/api/bluesky/media_type.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rby/rby.dart';

/// Provider for the [BlueskyMediaVideoConverter].
final blueskyMediaVideoConverterProvider = Provider(
  name: 'blueskyMediaVideoConverterProvider',
  BlueskyMediaVideoConverter.new,
);

/// A service to handle video conversion for Bluesky uploads.
///
/// Note: Currently, Bluesky has limited support for video uploads.
/// This implementation will be updated as Bluesky's video support evolves.
class BlueskyMediaVideoConverter with LoggerMixin {
  BlueskyMediaVideoConverter(this._ref);

  final Ref _ref;

  /// Maximum video file size allowed by Bluesky (currently theoretical)
  static const int _maxVideoSizeBytes = 100 * 1024 * 1024; // 100MB

  /// Validates and potentially converts a video file for Bluesky upload.
  ///
  /// Returns the processed video file if successful, null otherwise.
  /// Currently, this is a placeholder that only validates file size and format.
  Future<File?> convertVideo(String? sourcePath, String? extension) async {
    if (sourcePath == null || extension == null) {
      log.warning('Invalid source path or extension');
      return null;
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      log.warning('Source file does not exist: $sourcePath');
      return null;
    }

    // Check if the file is actually a video
    final mediaType = mediaTypeFromPath(sourcePath);
    if (mediaType != MediaType.video) {
      log.warning('File is not a video: $sourcePath');
      return null;
    }

    // Check file size
    final fileSize = await sourceFile.length();
    if (fileSize > _maxVideoSizeBytes) {
      log.warning(
        'Video file size ($fileSize bytes) exceeds maximum allowed '
        'size ($_maxVideoSizeBytes bytes)',
      );
      return null;
    }

    // For now, we just copy the file to a temporary location
    // In the future, this is where we would implement video conversion
    // based on Bluesky's specifications
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/bluesky_video.$extension';

    try {
      final outputFile = await sourceFile.copy(outputPath);
      log.fine('Video file prepared at: $outputPath');
      return outputFile;
    } catch (e, stack) {
      log.severe('Error preparing video file', e, stack);
      return null;
    }
  }

  /// Checks if a video file meets Bluesky's requirements.
  ///
  /// Returns true if the video file is valid for upload.
  Future<bool> meetsRequirements(File videoFile) async {
    final mediaType = mediaTypeFromPath(videoFile.path);
    if (mediaType != MediaType.video) {
      return false;
    }

    final fileSize = await videoFile.length();
    return fileSize <= _maxVideoSizeBytes;
  }

  /// Gets video metadata.
  ///
  /// NOTE: Currently a placeholder. Will be implemented once Bluesky supports
  /// video uploads.
  Future<Map<String, dynamic>> getMetadata(File videoFile) async {
    throw UnimplementedError(
      'Video upload support for Bluesky is not yet available. '
      'This feature will be implemented once the API supports video uploads.',
    );
  }
}
