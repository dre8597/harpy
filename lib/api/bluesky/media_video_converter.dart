import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harpy/core/core.dart';

/// A service to handle video conversion for Bluesky uploads.
///
/// NOTE: This is a placeholder implementation. Video upload support for Bluesky
/// is not yet available. This class will be updated once the API supports video
/// uploads.
class BlueskyMediaVideoConverter {
  BlueskyMediaVideoConverter(this._ref);

  final Ref _ref;

  /// Converts a video file to a format compatible with Bluesky's requirements.
  ///
  /// NOTE: Currently a placeholder. Will be implemented once Bluesky supports
  /// video uploads.
  Future<File> convertVideo(File videoFile) async {
    throw UnimplementedError(
      'Video upload support for Bluesky is not yet available. '
      'This feature will be implemented once the API supports video uploads.',
    );
  }

  /// Checks if a video file meets Bluesky's requirements.
  ///
  /// NOTE: Currently a placeholder. Will be implemented once Bluesky supports
  /// video uploads.
  Future<bool> meetsRequirements(File videoFile) async {
    throw UnimplementedError(
      'Video upload support for Bluesky is not yet available. '
      'This feature will be implemented once the API supports video uploads.',
    );
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

/// The provider for the [BlueskyMediaVideoConverter].
final blueskyMediaVideoConverterProvider = Provider(
  name: 'blueskyMediaVideoConverterProvider',
  BlueskyMediaVideoConverter.new,
);
