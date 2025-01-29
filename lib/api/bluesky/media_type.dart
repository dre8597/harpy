import 'package:mime_type/mime_type.dart';

/// The [MediaType] as it is returned from Bluesky.
const kMediaImage = 'image';
const kMediaVideo = 'video';
const kMediaGif = 'gif';

/// The type of media that can be attached to a post.
enum MediaType {
  image,
  gif,
  video,
}

extension MediaTypeExtension on MediaType {
  String get toMediaCategory {
    switch (this) {
      case MediaType.image:
        return 'image';
      case MediaType.gif:
        return 'gif';
      case MediaType.video:
        return 'video';
    }
  }
}

/// Uses [mime] to find the [MediaType] from a file path.
MediaType? mediaTypeFromPath(String? path) {
  final mimeType = mime(path);

  if (mimeType == null) {
    return null;
  } else if (mimeType.startsWith('video')) {
    return MediaType.video;
  } else if (mimeType == 'image/gif') {
    return MediaType.gif;
  } else if (mimeType.startsWith('image')) {
    return MediaType.image;
  } else {
    return null;
  }
}
