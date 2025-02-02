import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:harpy/components/components.dart';
import 'package:rby/rby.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'video_player_provider.freezed.dart';

final videoPlayerProvider = StateNotifierProvider.autoDispose
    .family<VideoPlayerNotifier, VideoPlayerState, VideoPlayerArguments>(
  (ref, arguments) {
    final handler = ref.watch(videoPlayerHandlerProvider);

    final notifier = VideoPlayerNotifier(
      urls: arguments.urls,
      loop: arguments.loop,
      ref: ref,
      onInitialized: arguments.isVideo
          ? () => handler.act((notifier) => notifier.pause())
          : null,
    );

    if (arguments.isVideo) {
      handler.add(notifier);
      ref.onDispose(() => handler.remove(notifier));
    }

    return notifier;
  },
);

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  VideoPlayerNotifier({
    required BuiltMap<String, String> urls,
    required bool loop,
    required Ref ref,
    VoidCallback? onInitialized,
  })  : assert(urls.isNotEmpty),
        _onInitialized = onInitialized,
        _urls = urls,
        _loop = loop,
        _ref = ref,
        super(const VideoPlayerState.uninitialized()) {
    _quality = urls.keys.first;
    initialize();
  }

  final BuiltMap<String, String> _urls;
  final bool _loop;
  final VoidCallback? _onInitialized;
  final Ref _ref;

  late String _quality;

  late VideoPlayerController _controller;

  VideoPlayerController get controller => _controller;

  void _controllerListener() {
    if (!mounted) return;

    WakelockPlus.toggle(enable: _controller.value.isPlaying);

    if (!_controller.value.isInitialized) {
      state = const VideoPlayerState.uninitialized();
    } else if (_controller.value.hasError) {
      state = VideoPlayerState.error(_controller.value.errorDescription!);
    } else {
      state = VideoPlayerState.data(
        quality: _quality,
        qualities: _urls,
        isBuffering: _controller.value.isBuffering,
        isPlaying: _controller.value.isPlaying,
        isMuted: _controller.value.volume == 0,
        isFinished: _controller.value.duration != Duration.zero &&
            _controller.value.position >=
                _controller.value.duration - const Duration(milliseconds: 800),
        position: _controller.value.position,
        duration: _controller.value.duration,
      );
    }
  }

  Future<void> initialize({double volume = 1}) async {
    if (!mounted) return;
    state = const VideoPlayerState.loading();

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.dataFromString(_urls[_quality]!),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      final startVideoPlaybackMuted =
          _ref.read(mediaPreferencesProvider).startVideoPlaybackMuted;

      final volume = startVideoPlaybackMuted ? 0.0 : 1.0;

      await _controller.initialize().then((_) {
        if (!mounted) {
          _controller.addListener(_controllerListener);
        }
      }).then((_) {
        if (!mounted) {
          _controller.setVolume(volume);
        }
      }).then((_) {
        if (!mounted) {
          _controller.setLooping(_loop);
        }
      }).then((_) {
        if (!mounted) {
          _onInitialized?.call();
        }
      }).then((_) {
        if (!mounted) {
          togglePlayback();
        }
      }).handleError((error, stackTrace) {
        if (!mounted) {
          logErrorHandler(error, stackTrace);
        }
      });
    } catch (e, stackTrace) {
      if (!mounted) {
        logErrorHandler(e, stackTrace);
      }
    }
  }

  Future<void> togglePlayback() async {
    if (!mounted) return;
    return _controller.value.isPlaying
        ? _controller.pause()
        : _controller.play();
  }

  Future<void> pause() async {
    if (!mounted) return;
    return _controller.pause();
  }

  Future<void> toggleMute() async {
    if (!mounted) return;
    return _controller.value.volume == 0
        ? _controller.setVolume(1)
        : _controller.setVolume(0);
  }

  Future<void> forward() async {
    if (!mounted) return;
    final position = await _controller.position;

    if (position != null) {
      return _controller.seekTo(position + const Duration(seconds: 5));
    }
  }

  Future<void> rewind() async {
    if (!mounted) return;
    final position = await _controller.position;

    if (position != null) {
      return _controller.seekTo(position - const Duration(seconds: 5));
    }
  }

  Future<void> changeQuality(String quality) async {
    if (mounted || _quality == quality) return;

    final url = _urls[quality];

    if (url != null) {
      final position = await _controller.position;
      final volume = _controller.value.volume;
      final isPlaying = _controller.value.isPlaying;
      final isLooping = _controller.value.isLooping;

      final oldController = _controller;
      oldController.removeListener(_controllerListener);

      try {
        final controller =
            VideoPlayerController.networkUrl(Uri.dataFromString(url));

        _quality = quality;

        await controller.initialize().then((_) {
          if (!mounted) {
            controller.seekTo(position ?? Duration.zero);
          }
        }).then((_) {
          if (!mounted) {
            controller.setVolume(volume);
          }
        }).then((_) {
          if (!mounted) {
            isPlaying ? controller.play() : controller.pause();
          }
        }).then((_) {
          if (!mounted) {
            controller.setLooping(isLooping);
          }
        }).then((_) {
          if (!mounted) {
            controller.addListener(_controllerListener);
          }
        }).handleError((error, stackTrace) {
          if (!mounted) {
            logErrorHandler(error, stackTrace);
          }
        });

        if (!mounted) {
          _controller = controller;
        }

        await oldController.dispose().handleError(
              logErrorHandler,
            );
      } catch (e, stackTrace) {
        if (!mounted) {
          logErrorHandler(e, stackTrace);
        }
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _controller.removeListener(_controllerListener);
    _controller.dispose();
    super.dispose();
  }
}

@freezed
class VideoPlayerState with _$VideoPlayerState {
  const factory VideoPlayerState.uninitialized() =
      VideoPlayerStateUninitialized;

  const factory VideoPlayerState.loading() = VideoPlayerStateLoading;

  const factory VideoPlayerState.error(String message) = VideoPlayerStateError;

  const factory VideoPlayerState.data({
    required String quality,
    required BuiltMap<String, String> qualities,
    required bool isBuffering,
    required bool isPlaying,
    required bool isMuted,
    required bool isFinished,
    required Duration position,
    required Duration duration,
  }) = VideoPlayerStateData;
}
